# PauloFlix Video Stuttering — Investigação v2

> **Status:** Em investigação. Não há fix de código aplicado ainda. Os patches anteriores (bufferSize 100MB) **não resolveram** e foram revertidos. Restam apenas mudanças cosméticas (User-Agent Android + remoção do `Connection: keep-alive`).

**Goal:** Eliminar travamentos durante playback de vídeos PauloFlix no **Android TV** (ambiente de produção).

**Hipótese principal após logs:** bottleneck de **taxa de transferência** do Tailscale, não de configuração de player. O log de DIAG mostrou que o buffer do libmpv drena consistentemente abaixo do consumo do player — então aumentar cache não resolve.

---

## O que os logs revelaram (2026-06-23)

Coletados via timer de DIAG a cada 5s, num vídeo 1280x720 (HD, ~24 min):

```
pos=2s   buffering=false  bufPct=100    ← cache cheio, ok
pos=4s   buffering=false  bufPct=100    ← ainda ok
         (sem DIAG no pos=6s → player rodou)
pos=8s   buffering=true   bufPct=25     ← cache drenou pra 25% em 4s
pos=11s  buffering=true   bufPct=49     ← enchendo devagar (~8%/s)
```

**Interpretação:**
- Cache começa em 100% (saudável)
- Em 4 segundos, drainou para 25% — player consome ~18%/s
- Em 3 segundos, recuperou 25% → ~8%/s (enchimento = Tailscale entregando)
- **Player consome ~2x mais rápido do que Tailscale entrega**

Conclusão: aumentar `bufferSize` de 32 MB → 100 MB não muda nada, porque o problema é a **taxa**, não o **tamanho máximo do cache**. O cache enche até onde a banda permite, e drena consistentemente.

---

## Ambiente do usuário (relevante)

| Item | Valor | Implicação |
|---|---|---|
| Device de produção | Android TV (TV box) | libmpv Android, MediaCodec HW decoder |
| Ambiente de dev atual | Windows debug (Flutter hot-reload) | libmpv Windows + ANGLE/D3D11 — **stack completamente diferente** |
| Tailscale | Ativo entre dev Windows e VPS | Latência WireGuard + relay |
| Servidor VPS | HTTP simples (Caddy/nginx) com range requests | OK do lado do server |
| Resolução típica | 1280x720 (pode ter mistura) | ~2-4 Mbps de bitrate |

**Crítico:** otimizar para Windows debug é esforço desperdiçado. O comportamento de buffer/demuxer/decoder no Android TV é diferente (MediaCodec, surface nativa, sem ANGLE). Qualquer fix de código precisa ser **validado na TV**.

---

## Hipóteses em ordem de probabilidade (revisadas pós-logs)

### H1: Tailscale relay lento entre cliente e VPS (60% chance)

O log mostrou consumo > oferta. Causas possíveis:
- Relay do Tailscale (DERP) entre você e a VPS está em região distante
- VPS tem banda limitada de upload (comum em VPS barata: 100-500 Mbps compartilhados, mas em prática podem ser 10-50 Mbps)
- Outros dispositivos no Tailscale consumindo banda

**Como validar:**
```bash
# No Windows
tailscale ping <vps>
# Tempo esperado: <10ms (mesma cidade) ou 20-80ms (relay DERP)
# Se > 100ms, relay está em região distante

# Medir taxa real
curl -o /dev/null -w "%{speed_download}\n" \
  http://100.95.105.113:8300/tvshows/<arquivo>.mp4
# Esperado: > 5 MB/s (40 Mbps) para playback 720p sem stutter
# Se < 1 MB/s (8 Mbps), Tailscale está gargalando
```

**Fix (se H1 confirmada):**
- Tailscale: configurar `exit node` próprio, evitar relay DERP
- VPS: verificar plano de banda, considerar upgrade
- Caddy: habilitar HTTP/2 ou HTTP/3 (melhor paralelismo de range requests)

### H2: Caddy/nginx configurado inadequadamente (25% chance)

O servidor pode estar com:
- `worker_connections` muito baixo
- `keepalive_timeout` muito curto (libmpv reconecta a cada range)
- Sem `sendfile` ou `tcp_nopush` habilitado

**Como validar (na VPS):**
```bash
# Ver config do Caddy
cat /etc/caddy/Caddyfile
# Procurar: rate-limit, workers, keepalive
```

**Fix (se H2 confirmada):** Tunar Caddy para streaming (snippet dedicado para `/tvshows/*`).

### H3: Range requests não estão sendo respeitados (10% chance)

O servidor pode estar retornando 200 OK completo em vez de 206 Partial Content, o que impossibilita seek e força o libmpv a sempre baixar do início.

**Como validar (do Windows):**
```bash
curl -I -H "Range: bytes=1000000-2000000" \
  http://100.95.105.113:8300/tvshows/<arquivo>.mp4
# Esperado: HTTP/1.1 206 Partial Content
# Se vier 200, range requests não funcionam
```

### H4: Codec do MP4 exige HW decoder que falta (5% chance)

O log mostrou `Cannot load nvcuda.dll` no Windows — mas no Android TV o decoder é MediaCodec (não CUDA). Improvável, mas vale verificar se os vídeos PauloFlix têm codec exótico.

**Como validar:**
- No Android TV com `adb logcat` filtrando por `mediacodec` ou `libmpv` durante playback

---

## Plano de ação recomendado (sem fix de código ainda)

### Passo 1: Validar H1 com medições objetivas (10 min)

**No Windows:**
```bash
# Latência Tailscale
tailscale ping <vps-tailnet-ip>

# Taxa real de download da VPS
# Substitua pelo caminho real de um episódio PauloFlix
curl -o /dev/null -w "tempo: %{time_total}s\nvelocidade: %{speed_download} bytes/s\n" \
  --max-time 30 \
  http://100.95.105.113:8300/tvshows/Tensei%20Shitara%20Slime%20Datta%20Ken%20Dublado/Season%2004/S04E08.mp4
```

**Anotar os números e me mandar.** Se `speed_download` for menor que 500 KB/s (4 Mbps), **o problema é Tailscale/VPS, não o app**.

### Passo 2: Validar H3 com curl (2 min)

**No Windows:**
```bash
curl -I -H "Range: bytes=1000000-2000000" \
  http://100.95.105.113:8300/tvshows/Tensei%20Shitara%20Slime%20Datta%20Ken%20Dublado/Season%2004/S04E08.mp4
```

**Esperado:** `HTTP/1.1 206 Partial Content`. Se vier `200 OK`, o servidor não suporta range e isso explica o stutter.

### Passo 3: Testar no Android TV real (20 min)

**Build:**
```bash
cd "C:/Users/pr02n/developer/goanime-mobile"
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

**Observar:** o mesmo stutter acontece na TV? Se **sim** → problema é app + rede. Se **não** → era só artifact do debug no Windows.

### Passo 4: Coletar logs na TV (se stutter persistir)

```bash
adb logcat | grep -i "mediacodec\|libmpv\|demuxer\|buffer" 
```

**Me mandar os logs.** Com números de velocidade + range check + logcat da TV, eu consigo mirar o fix certo.

---

## Decisões validadas

✅ **Decisão 1:** Reverter `bufferSize: 100 MB` e `logLevel: MPVLogLevel.info` (não resolveram e atrapalham leitura). **Aplicado.**

✅ **Decisão 2:** Manter User-Agent Android + remoção do `Connection: keep-alive` (boas práticas, baixo risco, sem impacto funcional). **Aplicado.**

✅ **Decisão 3:** NÃO aplicar fix de código até ter medições objetivas de rede. Evitar ciclo "patch → não funciona → reverter → patch diferente" sem dados. **Aplicado.**

---

## Mudanças atuais (working tree)

| Arquivo | LOC | Status |
|---|---|---|
| `lib/ui/player/widgets/video_player_screen.dart` | +7/-2 | User-Agent Android + remoção `Connection`. Pronto pra commit. |

**NÃO fiz commit** — você comita quando quiser.

---

## Próximos passos (dependem das medições)

| Se medir X | Então |
|---|---|
| `speed_download < 500 KB/s` | Problema é VPS/Tailscale. Considerar: (a) proxy local no celular que pré-baixe, (b) upgrade de banda da VPS, (c) Caddy com HTTP/2 |
| Range retorna 200 em vez de 206 | Servidor mal configurado. Corrigir Caddy/nginx para `add_header Accept-Ranges bytes` |
| Stutter NÃO acontece na TV | Era artifact do Windows debug. Fechar este plano como "não é bug" |
| Stutter acontece na TV com banda OK | Investigar MediaCodec/decoder no Android, possível codec HEVC/AV1 sem HW |

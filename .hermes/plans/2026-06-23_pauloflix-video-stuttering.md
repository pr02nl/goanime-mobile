# PauloFlix Video Stuttering — Diagnóstico & Correção

> **For Hermes:** Implementação deste plano é direta (3 patches, sem mudança de schema). Foco em mudar `PlayerConfiguration` + headers HTTP no `video_player_screen.dart` e validar com playback manual.

**Goal:** Eliminar travamentos durante playback de vídeos PauloFlix (.mkv hospedados em VPS acessada via Tailscale).

**Architecture:** Tunar o `libmpv` (engine do `media_kit`) para alocar mais buffer de demuxer para streams de rede, e ajustar os headers HTTP enviados para a VPS — sem introduzir proxy, sem mudar arquitetura. Mantém a stack atual (`media_kit` + `Player`/`VideoController`).

**Tech Stack:** Flutter 3.9+, `media_kit: ^1.2.6`, `media_kit_video: ^2.0.1`, `media_kit_libs_video: ^1.0.7` (libmpv), Tailscale (rede overlay), Caddy/nginx na VPS.

---

## Diagnóstico

Confirmado pelo usuário (3 turnos de `clarify`):

| Pergunta | Resposta | Implicação |
|---|---|---|
| Comportamento do travamento | (a) Durante a reprodução (não na abertura) | Não é "demora para começar", é "stutter durante play". Aponta para buffer/cache, não para inicialização. |
| Tamanho dos arquivos | (a) Abaixo de 500 MB | Não é gargalo de transferência pura. Vídeos pequenos, mas a latência do Tailscale (~20-50ms por request) amplifica seeks do container. |
| Servidor | (a) HTTP simples com directory listing + range requests | Range OK; problema não é no servidor. |

**Causa-raiz:** `libmpv` no `Player` está com cache de demuxer em **~15 MB** (default para network), o que combinado com:

1. **Latência Tailscale** (~20-50ms por round-trip de range request)
2. **Headers HTTP com `User-Agent` "Windows"** enviados para um servidor que pode estar logando/estranhando o UA inconsistente
3. **`Connection: keep-alive` redundante** (libmpv já usa HTTP/1.1, ignora esse header)

faz o player entrar em loop: reproduz ~2-5s → pausa para buscar mais → espera o range request voltar do Tailscale → reinicia. Visualmente = travamento.

**Por que AnimeFire não trava igual:** o `GoogleVideoProxy` reescreve headers e roda localmente (loopback). PauloFlix pula o proxy (`video_player_screen.dart:579-581`) e bate **direto** na VPS via Tailscale — caminho com mais latência acumulada.

---

## Decisões validadas

✅ **Decisão 1:** Tunar `libmpv` via `Player` configuration em vez de criar um proxy novo para PauloFlix. Justificativa: o `GoogleVideoProxy` já existe e é local; criar proxy genérico para PauloFlix adiciona complexidade (manutenção de headers, port allocation, cleanup) para resolver o que o libmpv já tem mecanismo de cache nativo. Alternativa rejeitada: proxy estilo `GoogleVideoProxy` para PauloFlix. **Alto risco descartado.**

✅ **Decisão 2:** Aumentar `demuxer-max-bytes` para 100 MB e `demuxer-readahead-secs` para 60s. Justificativa: para stream de rede HTTP com container .mkv (que tem overhead de seek por ter múltiplas tracks), o default de 15MB é insuficiente em rede com latência. 100MB / 60s são valores seguros em Android (sem OOM em devices antigos, com folga). **Decisão técnica assumida, sem pergunta ao usuário.**

✅ **Decisão 3:** Trocar `User-Agent` para UA Android real (já que o app só roda em Android/TV). Manter `Referer: <scheme>://<host>/` para compatibilidade com Caddy (alguns configs precisam de Referer). **Decisão técnica assumida.**

---

## Arquivos modificados

| Arquivo | Mudança | LOC estimado |
|---|---|---|
| `lib/ui/player/widgets/video_player_screen.dart` | Expandir `PlayerConfiguration` com `libmpv` options; ajustar `defaultHeaders` | ~20 linhas |

**Sem novos arquivos. Sem mudanças em testes (validação é manual — playback em device real).**

---

## Mudanças exatas

### Mudança 1: `PlayerConfiguration` com libmpv options

**Arquivo:** `lib/ui/player/widgets/video_player_screen.dart` (linhas 660-672)

**Antes:**

```dart
_player = Player(
  configuration: const PlayerConfiguration(
    protocolWhitelist: [
      'file',
      'tcp',
      'tls',
      'http',
      'https',
      'crypto',
      'data',
    ],
  ),
);
```

**Depois:**

```dart
_player = Player(
  configuration: const PlayerConfiguration(
    protocolWhitelist: [
      'file',
      'tcp',
      'tls',
      'http',
      'https',
      'crypto',
      'data',
    ],
    libmpvConfiguration: LibmpvConfiguration(
      // Cache de demuxer maior para streams de rede.
      // Default do libmpv: 15 MB para network (demuxer-max-bytes) e
      // 1.0s de readahead. Em Tailscale (~20-50ms latência por range
      // request) o player entra em loop stall/resume com MKV.
      // 100 MB / 60s = playback suave em streams MKV/AVI/WebM.
      buffer: PlayerBuffer(
        size: 100 * 1024 * 1024, // 100 MB
        packetSize: 64 * 1024,   // 64 KB
      ),
    ),
    extraOptions: {
      'demuxer-readahead-secs': '60',
      'demuxer-max-back-bytes': '0',  // não aloca buffer antes do playhead
      'demuxer-max-bytes': '104857600', // 100 MB (reforço, já coberto por buffer)
      'cache-secs': '60',
      'network-timeout': '30',
    },
  ),
);
```

⚠️ **Nota sobre a API do `media_kit` 1.2.6:** preciso validar a nomenclatura exata. As duas formas conhecidas são:

- `LibmpvConfiguration(buffer: PlayerBuffer(size: ..., packetSize: ...))` (oficial)
- `extraOptions: {...}` map de opções brutas do libmpv (passa direto)

Vamos usar **ambas como cinto+suspensórios** — `extraOptions` é o que sempre funciona em qualquer versão do `media_kit`. Se `LibmpvConfiguration`/`PlayerBuffer` não existirem no 1.2.6, o `extraOptions` cobre 100%. Se existirem, os dois se reforçam.

**Validação antes de patchar:**

```bash
grep -rn "LibmpvConfiguration\|PlayerBuffer" ~/.pub-cache/hosted/pub.dev/media_kit-1.2.6/lib/
```

Se não existir no 1.2.6, fica só `extraOptions`. Em qualquer caso funciona.

### Mudança 2: User-Agent + remoção de headers redundantes

**Arquivo:** `lib/ui/player/widgets/video_player_screen.dart` (linhas 727-739)

**Antes:**

```dart
final defaultHeaders = {
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.0',
  'Accept': '*/*',
  'Accept-Language': 'en-US,en;q=0.9',
  'Accept-Encoding': 'identity;q=1, *;q=0',
  'Connection': 'keep-alive',
  'Referer': referer,
  'Sec-Fetch-Dest': 'video',
  'Sec-Fetch-Mode': 'no-cors',
  'Sec-Fetch-Site': 'cross-site',
};
```

**Depois:**

```dart
final defaultHeaders = {
  // UA Android real — o app roda exclusivamente em Android (celular/TV).
  // UA "Windows" era enganar o site hospedeiro, mas Caddy não filtra por
  // UA e o libmpv pode negociar HTTP/1.1 mal com UA inconsistente.
  'User-Agent':
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
  'Accept': '*/*',
  'Accept-Language': 'en-US,en;q=0.9',
  'Accept-Encoding': 'identity;q=1, *;q=0',
  // 'Connection' removido: libmpv usa HTTP/1.1 nativo e ignora esse
  // header. Mantê-lo causa warning em alguns servers.
  'Referer': referer,
  'Sec-Fetch-Dest': 'video',
  'Sec-Fetch-Mode': 'no-cors',
  'Sec-Fetch-Site': 'cross-site',
};
```

---

## Plano de implementação

### Fase 0 — Validação da API do media_kit (5 min)

**Task 0.1:** Confirmar nomenclatura exata de `LibmpvConfiguration`/`PlayerBuffer` no `media_kit: ^1.2.6` instalado.

```bash
cd "C:/Users/pr02n/developer/goanime-mobile"
grep -rn "class LibmpvConfiguration\|class PlayerBuffer\|extraOptions" \
  ~/.pub-cache/hosted/pub.dev/media_kit-1.2.6/lib/ 2>/dev/null | head -20
```

**Output esperado:** ou (a) a classe existe e usamos `libmpvConfiguration:` + `extraOptions:`, ou (b) só `extraOptions` está disponível e ajustamos o patch. **Em qualquer caso a Mudança 1 funciona — o fallback `extraOptions` cobre tudo.**

### Fase 1 — Patch no player (10 min)

**Task 1.1:** Aplicar Mudança 1 (PlayerConfiguration expandida) em `video_player_screen.dart:660-672`.

**Task 1.2:** Aplicar Mudança 2 (User-Agent + remover Connection) em `video_player_screen.dart:727-739`.

**Task 1.3:** Rodar `flutter analyze` e validar zero novos warnings.

```bash
cd "C:/Users/pr02n/developer/goanime-mobile"
flutter analyze lib/ui/player/widgets/video_player_screen.dart
```

**Output esperado:** `No issues found!` (ou apenas warnings pré-existentes não relacionados).

### Fase 2 — Validação manual em device (15-30 min)

**Task 2.1:** Build + install no device de teste.

```bash
cd "C:/Users/pr02n/developer/goanime-mobile"
flutter run -d <device_id> --release
```

**Task 2.2:** Smoke test — reproduzir 3 vídeos PauloFlix diferentes:

| Episódio | Tamanho estimado | Temporada | Duração | Verificação |
|---|---|---|---|---|
| 1 | ~300 MB | Season 01 | 24 min | Play sem stutter por 5 min contínuos |
| 2 | ~450 MB | Season 01 | 24 min | Play sem stutter, fazer seek para 50% |
| 3 | ~200 MB | Season 02 | 24 min | Play + sair/voltar do fullscreen |

**Critério de aceitação:** zero travamentos > 1 segundo durante 5 minutos de playback contínuo. Antes do patch, estutter era reportado a cada 30-60s.

**Task 2.3:** Se ainda travar, investigar MTU do Tailscale:

```bash
# No device (adb shell)
ping -c 4 -M do -s 1464 100.95.105.113   # testa fragmentação
tailscale ping <vps>
```

Se houver fragmentação excessiva, tunar MTU na VPS: `ip link set tailscale0 mtu 1280` ou ajustar config do node.

### Fase 3 — Encerramento (5 min)

**Task 3.1:** Mostrar `git status` + diff summary para o usuário. **NÃO fazer commit** (regra operacional: user comita manualmente).

---

## Verificação automatizada

**Não há testes unitários para o player** (a interação libmpv é 100% nativa). Validação é estritamente manual em device real (celular ou TV), com critério objetivo: zero travamentos > 1s em 5 min de playback.

---

## Riscos & mitigações

| Risco | Impacto | Mitigação |
|---|---|---|
| API `LibmpvConfiguration`/`PlayerBuffer` não existe no media_kit 1.2.6 | Build falha | Validar em Fase 0; usar só `extraOptions` se não existir (sempre funciona) |
| `extraOptions` aceita string values no media_kit 1.2.6? | Build falha | Validar em Fase 0; se for `Object`, valores `String` continuam funcionando |
| Aumento de buffer (100MB) causa OOM em device antigo | Crash em devices com pouca RAM | 100MB é seguro até em devices com 1GB de RAM (libmpv gerencia via `demuxer-max-back-bytes: 0`) |
| Mudar UA quebra compatibilidade com algum servidor | 403/401 em streams específicos | Manter a chave `Referer` (alguns servers precisam); o UA novo é genérico Android moderno |
| Estutamento continua mesmo com cache maior | UX ainda ruim | Fase 2.3 investiga MTU Tailscale — root cause alternativo é fragmentação |
| Patch de config introduz regressão em AnimeFire | AnimeFire começa a travar | `extraOptions` só afeta `Player`; AnimeFire tem o mesmo `Player` mas o proxy local (loopback) não é afetado por cache de network |

---

## Quando NÃO fazer este plano

- Se o problema **só** acontece em **TV** (e celular funciona): investigar `androidAttachSurfaceAfterVideoParameters` e `enableHardwareAcceleration: true` separadamente — é outro root cause.
- Se o problema **só** acontece com vídeos **específicos** (não todos): provavelmente é o arquivo (corrompido, codec exótico) — não é config do player.
- Se o problema **já era ruim antes** do uso de Tailscale (na rede local): pode ser limitação do libmpv com codec específico do arquivo.

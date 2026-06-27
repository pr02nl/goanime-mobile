# PauloFlix — Migração de Tailscale para HTTPS+Token (Decisões Finais)

> **Status:** Aguardando migração de DNS pelo provedor + emissão do certificado TLS. Enquanto isso, eu preparo offline tudo que dá (código Flutter, scripts de validação).
>
> **Domínio final:** `media.oliveira.braga.nom.br`
> **TLS:** Certificado `.crt` + `.key` fornecido pelo provedor (instalação manual)
> **VPS:** Ubuntu root via SSH (InterServer)
> **device_id:** UUID v4 aleatório gerado no primeiro launch
> **Geração de chaves Ed25519:** direto na VPS via OpenSSL

**Goal:** Eliminar stuttering do player PauloFlix removendo o relay DERP do Tailscale (que entrega só 2.1 Mbps) e substituindo por HTTPS direto via domínio próprio com autenticação JWT Ed25519.

**Architecture:** nginx na VPS escuta 443, valida JWT em cada request via subrequest (`auth_request`), serve `/tvshows/*` e `/movies/*` se válido. App Flutter gera token Ed25519 no primeiro launch (chave privada embutida), envia `Authorization: Bearer *** em toda request.

**Tech Stack:**
- **VPS:** nginx 1.24 (já instalado), OpenSSL, Python 3 (validador CGI)
- **Flutter:** `cryptography` (ou implementação Dart Ed25519 via `pointycastle`), `shared_preferences`, `uuid`
- **Geração de chave:** `openssl genpkey -algorithm Ed25519` rodando na VPS via SSH

---

## Decisões validadas (finais)

✅ **Decisão 1:** JWT Ed25519 (chave privada no app, pública no nginx). Se nginx for comprometido, atacante não forja tokens.

✅ **Decisão 2:** Token payload `{device_id, iat, exp, jti}` com `exp = iat + 365 dias`. App renova automaticamente 7 dias antes de expirar. `jti` (JWT ID) garante unicidade mesmo se iat/exp forem idênticos (dois tokens no mesmo segundo).

✅ **Decisão 3:** `device_id` = UUID v4 aleatório, gerado no primeiro launch, salvo em SharedPreferences. Sem hardware binding (mais simples, sem dependência de `device_info_plus`).

✅ **Decisão 4:** Validador Python CGI (mínimo: decode JWT, verify signature, check `exp`). Sem DB, sem dependência externa. Roda via `proxy_pass` para um servidor HTTP local (porta 8301 interna) OU direto como FastCGI.

✅ **Decisão 5:** Rate limit nginx: 10 req/s por IP, burst 20, fail2ban bloqueia após 100 reqs em 5min.

✅ **Decisão 6:** Manter Tailscale ativo paralelo por 7 dias, depois desliga.

✅ **Decisão 7:** **SEM Cloudflare proxy**. IP da VPS fica público (aceitável com token + rate limit). Adicionar Cloudflare depois se quiser DDoS protection.

✅ **Decisão 8:** Path `/tvshows/*` e `/movies/*` (mesma estrutura de hoje). Apenas troca scheme (http→https) e host.

✅ **Decisão 9 (estratégia de auth):** **Chave privada hardcoded no APK** (Fase 0). Justificativa: projeto pessoal/MVP, objetivo é eliminar stutter, não construir auth enterprise. Cada instalação gera `device_id` único → base para revogação futura via allowlist no servidor. Rotação = regenerar par + rebuildar APK (10 min). Evoluir para Play Integrity / DeviceCheck só se virar produto comercial sério.

---

## Estrutura de arquivos finais

### VPS (criar via SSH)

```
/etc/nginx/sites-available/pauloflix              # config nginx com auth_request
/etc/nginx/auth/validate.py                       # validador JWT Ed25519
/etc/nginx/auth/pauloflix_public.pem              # chave pública Ed25519
/etc/systemd/system/jwt-validator.service         # systemd unit pro validador
/etc/fail2ban/filter.d/nginx-pauloflix.conf       # filtro fail2ban custom
/etc/fail2ban/jail.d/pauloflix.conf               # jail fail2ban
```

Certificado TLS vai em:
```
/etc/nginx/ssl/media.oliveira.braga.nom.br.crt
/etc/nginx/ssl/media.oliveira.braga.nom.br.key
```

(caminhos exatos serão ajustados conforme o que o provedor enviar)

### Flutter (criar/modificar)

**Novos:**
```
lib/data/services/auth/jwt_token_manager.dart          # gera/renova token, persiste
lib/data/services/auth/authenticated_http_client.dart # wrapper que injeta Bearer
```

**Modificados:**
| Arquivo | Mudança |
|---|---|
| `lib/core/constants/api_constants.dart` | `animePauloFlix` → `https://media.oliveira.braga.nom.br/tvshows/`, `moviePauloFlix` → `https://media.oliveira.braga.nom.br/movies/` |
| `lib/data/services/pauloflix_service.dart` | Injetar `AuthenticatedHttpClient` |
| `lib/data/services/pauloflix_movies_service.dart` | Injetar `AuthenticatedHttpClient` |
| `lib/app.dart` | Inicializar `JwtTokenManager` no startup (gera device_id + token) |

**Novos testes:**
```
test/data/services/auth/jwt_token_manager_test.dart
test/data/services/auth/authenticated_http_client_test.dart
```

---

## Dependências Flutter a adicionar

```yaml
# pubspec.yaml
dependencies:
  cryptography: ^2.7.0       # Ed25519 sign/verify em Dart puro
  uuid: ^4.5.0               # UUID v4
  shared_preferences: ^2.3.0 # já deve estar no projeto
```

`cryptography` é o pacote recomendado pela Dart team para crypto moderna, sem deps nativas.

---

## Algoritmos críticos

### 1. Gerar par de chaves Ed25519 (rodar 1x na VPS via SSH)

```bash
ssh root@<ip-vps>

# Cria diretório para chaves
mkdir -p /etc/nginx/auth
cd /etc/nginx/auth

# Gera chave privada (formato PEM)
openssl genpkey -algorithm Ed25519 -out pauloflix_private.pem

# Extrai chave pública
openssl pkey -in pauloflix_private.pem -pubout -out pauloflix_public.pem

# Converte privada para RAW 32 bytes (formato que Ed25519 usa para assinar)
openssl pkey -in pauloflix_private.pem -outform DER | tail -c 32 > pauloflix_private.raw

# Converte RAW para base64 (cola no app)
base64 -w 0 pauloflix_private.raw
# Output: <32-bytes-em-base64>
# Copie esse valor — vai ser a chave privada do app

# Permissões: nginx precisa ler a pública, mas só root pode ler a privada
chmod 644 pauloflix_public.pem
chmod 600 pauloflix_private.pem pauloflix_private.raw
```

**Saída importante:** o base64 da chave privada raw (32 bytes) vai ser colado em `jwt_token_manager.dart` como constante.

### 2. JWT Validator (Python rodando como serviço)

Eu vou usar **FastAPI + uvicorn** em vez de CGI puro — é 10x mais simples de configurar e dá mais controle:

```python
# /etc/nginx/auth/validate.py
from fastapi import FastAPI, Header, HTTPException
import base64
import json
import time
import os
from cryptography.hazmat.primitives.serialization import load_pem_public_key

app = FastAPI()
PUBLIC_KEY_PATH = '/etc/nginx/auth/pauloflix_public.pem'
_public_key = None

@app.on_event("startup")
def load_key():
    global _public_key
    with open(PUBLIC_KEY_PATH, 'rb') as f:
        _public_key = load_pem_public_key(f.read())

def b64decode(s: str) -> bytes:
    return base64.urlsafe_b64decode(s + '=' * (-len(s) % 4))

@app.get("/validate")
def validate(authorization: str = Header(None)):
    if not authorization or not authorization.startswith('Bearer '):
        raise HTTPException(status_code=401, detail="Missing Bearer token")
    
    token = authorization[7:]
    parts = token.split('.')
    if len(parts) != 3:
        raise HTTPException(status_code=401, detail="Malformed JWT")
    
    try:
        header = json.loads(b64decode(parts[0]))
        payload = json.loads(b64decode(parts[1]))
        signature = b64decode(parts[2])
        
        if header.get('alg') != 'EdDSA':
            raise HTTPException(status_code=401, detail="Invalid alg")
        
        if 'exp' in payload and payload['exp'] < time.time():
            raise HTTPException(status_code=401, detail="Token expired")
        
        signed_data = f'{parts[0]}.{parts[1]}'.encode('utf-8')
        _public_key.verify(signature, signed_data)  # raises InvalidSignature
        
        return {'device_id': payload.get('device_id'), 'exp': payload.get('exp')}
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid: {type(e).__name__}")
```

Roda via systemd unit em `127.0.0.1:8301` (loopback only).

### 3. nginx config (esqueleto — vai precisar ajustar paths dos certs)

```nginx
# /etc/nginx/sites-available/pauloflix

# Rate limit zone (10 req/s por IP, com memória de 10MB)
limit_req_zone $binary_remote_addr zone=pauloflix_limit:10m rate=10r/s;

# Upstream do validador JWT
upstream jwt_validator {
    server 127.0.0.1:8301;
    keepalive 16;
}

server {
    listen 443 ssl http2;
    server_name media.oliveira.braga.nom.br;

    # Certificados (paths ajustados conforme o que o provedor enviar)
    ssl_certificate /etc/nginx/ssl/media.oliveira.braga.nom.br.crt;
    ssl_certificate_key /etc/nginx/ssl/media.oliveira.braga.nom.br.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;

    # Validador (acesso via auth_request, não público)
    location = /auth/validate {
        internal;
        proxy_pass http://jwt_validator/validate;
        proxy_pass_request_body off;
        proxy_set_header Content-Length "";
        proxy_set_header Authorization $http_authorization;
    }

    # Streaming: TV Shows
    location /tvshows/ {
        limit_req zone=pauloflix_limit burst=20 nodelay;
        auth_request /auth/validate;
        auth_request_set $device_id $upstream_http_x_device_id;
        
        alias /var/www/pauloflix/tvshows/;
        add_header Accept-Ranges bytes;
        add_header X-Device-Id $device_id;
        try_files $uri =404;
    }

    # Streaming: Movies
    location /movies/ {
        limit_req zone=pauloflix_limit burst=20 nodelay;
        auth_request /auth/validate;
        alias /var/www/pauloflix/movies/;
        add_header Accept-Ranges bytes;
    }

    # Health check (sem auth, pra você monitorar)
    location = /health {
        access_log off;
        return 200 "ok\n";
        add_header Content-Type text/plain;
    }
}
```

**Ativação:**
```bash
ln -s /etc/nginx/sites-available/pauloflix /etc/nginx/sites-enabled/
nginx -t              # validar config
systemctl reload nginx
```

### 4. Flutter JwtTokenManager (esqueleto)

```dart
// lib/data/services/auth/jwt_token_manager.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class JwtTokenManager {
  // Chave privada Ed25519 (32 bytes) em base64, gerada via openssl na VPS
  // SUBSTITUA pelo valor real após gerar na VPS!
  static const String _kPrivateKeyB64 = 'COLE_AQUI_O_BASE64_DE_32_BYTES';
  
  static const String _kTokenKey = 'jwt_token';
  static const String _kTokenExpKey = 'jwt_token_exp';
  static const String _kDeviceIdKey = 'device_id';
  
  late final Ed25519 _signer;
  late final String _deviceId;
  bool _initialized = false;
  
  Future<void> initialize() async {
    if (_initialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_kDeviceIdKey) ?? _generateAndStoreDeviceId(prefs);
    
    final privateKeyBytes = base64Decode(_kPrivateKeyB64);
    _signer = Ed25519();
    // cryptography package: store key in NewKeyPairData
    // (api específica do pacote, vou validar durante implementação)
    
    _initialized = true;
  }
  
  Future<String> getValidToken() async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kTokenKey);
    final exp = prefs.getInt(_kTokenExpKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    if (stored != null && exp > now + 86400 * 7) {
      return stored;
    }
    
    // Gera novo token
    final newExp = now + 365 * 86400;
    final token = await _generateToken(now, newExp);
    await prefs.setString(_kTokenKey, token);
    await prefs.setInt(_kTokenExpKey, newExp);
    return token;
  }
  
  Future<String> _generateToken(int iat, int exp) async {
    final header = {'alg': 'EdDSA', 'typ': 'JWT'};
    final payload = {
      'device_id': _deviceId,
      'iat': iat,
      'exp': exp,
    };
    
    final headerB64 = _b64UrlEncode(utf8.encode(jsonEncode(header)));
    final payloadB64 = _b64UrlEncode(utf8.encode(jsonEncode(payload)));
    final signingInput = '$headerB64.$payloadB64';
    
    // Assina com Ed25519 (api do cryptography package)
    final signature = await _signer.sign(
      utf8.encode(signingInput),
      keyPair: ...,
    );
    
    final sigB64 = _b64UrlEncode(signature.bytes);
    return '$signingInput.$sigB64';
  }
  
  String _b64UrlEncode(List<int> bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
  
  String _generateAndStoreDeviceId(SharedPreferences prefs) {
    final id = const Uuid().v4();
    prefs.setString(_kDeviceIdKey, id);
    return id;
  }
}
```

### 5. AuthenticatedHttpClient (wrapper)

```dart
// lib/data/services/auth/authenticated_http_client.dart
import 'package:http/http.dart' as http;
import 'jwt_token_manager.dart';

class AuthenticatedHttpClient extends http.BaseClient {
  final http.Client _inner;
  final JwtTokenManager _tokenManager;
  
  AuthenticatedHttpClient({
    required http.Client inner,
    required JwtTokenManager tokenManager,
  }) : _inner = inner, _tokenManager = tokenManager;
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _tokenManager.getValidToken();
    request.headers['Authorization'] = 'Bearer *** final response = await _inner.send(request);
    
    // Se 401, tenta renovar + retry 1x
    if (response.statusCode == 401) {
      // força regeneração
      final newToken = await _tokenManager.forceRenew();
      request.headers['Authorization'] = 'Bearer *** return _inner.send(request);
    }
    
    return response;
  }
}
```

---

## Plano de implementação (sequência exata)

### Fase 0 — **AGORA: Trabalho offline em paralelo** (Flutter + scripts)

**Não depende do provedor terminar migração DNS nem emitir certificado.**

- [ ] Adicionar deps no `pubspec.yaml`: `cryptography`, `uuid`
- [ ] Criar `lib/data/services/auth/jwt_token_manager.dart` (com placeholder pra chave privada)
- [ ] Criar `lib/data/services/auth/authenticated_http_client.dart`
- [ ] Criar `test/data/services/auth/jwt_token_manager_test.dart` (gera token, decodifica, valida estrutura)
- [ ] Criar script `tools/generate_jwt_keypair.sh` (gera par de chaves, printa base64 da privada)
- [ ] `flutter analyze` + `flutter test`

**Status:** Posso começar imediatamente. Você me dá "ok" e eu vou.

### Fase 1 — **Quando DNS propagar:** Setup VPS (você roda via SSH)

**Depende de:** provedor terminar migração de DNS apontando `media.oliveira.braga.nom.br` para o IP da VPS.

- [ ] Verificar DNS: `dig media.oliveira.braga.nom.br +short` (deve retornar IP da VPS)
- [ ] Instalar certificado TLS que o provedor enviar:
  ```bash
  mkdir -p /etc/nginx/ssl
  # colocar arquivos do certificado aqui
  chmod 600 /etc/nginx/ssl/*.key
  chmod 644 /etc/nginx/ssl/*.crt
  ```
- [ ] Instalar deps Python:
  ```bash
  apt install -y python3-pip
  pip3 install fastapi uvicorn cryptography
  ```
- [ ] Gerar par Ed25519 (script `generate_jwt_keypair.sh` que vou criar)
- [ ] Salvar chave privada como **segredo seu** (vai colar no app)
- [ ] Deploy validador `validate.py` + chave pública
- [ ] Criar systemd unit `jwt-validator.service` rodando em `127.0.0.1:8301`
- [ ] Deploy nginx config `pauloflix`
- [ ] Ativar site: `ln -s ... && nginx -t && systemctl reload nginx`
- [ ] Configurar fail2ban
- [ ] Testar com curl:
  ```bash
  # Sem token (deve dar 401)
  curl -I https://media.oliveira.braga.nom.br/tvshows/test.mp4
  
  # Com token válido gerado pelo script (deve dar 404 pq arquivo não existe, mas passa do auth)
  curl -I -H "Authorization: Bearer *** https://media.oliveira.braga.nom.br/tvshows/test.mp4
  ```

**Status:** Aguardando você terminar migração DNS + receber certificado. Eu te passo um **guia passo-a-passo** com todos os comandos exatos quando chegar a hora.

### Fase 2 — **Integração Flutter** (quando Fase 1 estiver OK)

- [ ] Atualizar `api_constants.dart` com nova URL
- [ ] Inicializar `JwtTokenManager` em `app.dart` (chamar `initialize()` no startup)
- [ ] Injetar `AuthenticatedHttpClient` em `PauloFlixService` e `PauloFlixMoviesService`
- [ ] `flutter analyze` + `flutter test` + build APK
- [ ] Instalar em device, testar sync + playback

### Fase 3 — Cutover gradual (1 semana)

- [ ] Manter Tailscale ativo paralelo por 7 dias
- [ ] Monitorar logs nginx: `tail -f /var/log/nginx/access.log | grep -E ' 4[0-9][0-9] '`
- [ ] Se zero erros: desligar Tailscale na VPS, fechar porta 41641/UDP
- [ ] Atualizar `AGENTS.md` com nova arquitetura

---

## Verificação

### VPS (após Fase 1)

```bash
# DNS resolveu?
dig media.oliveira.braga.nom.br +short
# Esperado: <ip-da-vps>

# TLS válido?
openssl s_client -connect media.oliveira.braga.nom.br:443 -servername media.oliveira.braga.nom.br < /dev/null 2>&1 | grep "Verify return code"
# Esperado: Verify return code: 0 (ok)

# Sem token = 401
curl -I https://media.oliveira.braga.nom.br/tvshows/qualquer.mp4
# Esperado: HTTP/1.1 401 Unauthorized

# Com token = 200/206
TOKEN=*** ./generate_test_token.sh)"
curl -I -H "Authorization: Bearer *** https://media.oliveira.braga.nom.br/tvshows/S04E08.mp4
# Esperado: HTTP/1.1 206 Partial Content (se arquivo existe) ou 404 (se não existe, mas auth passou)
```

### Flutter (após Fase 2)

```bash
# Testes unitários
flutter test test/data/services/auth/

# Build
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk

# Smoke test
# 1. Abrir app, ir em PauloFlix
# 2. Sincronizar (deve funcionar via HTTPS+token)
# 3. Reproduzir 3 episódios (deve ser stutter-free)
# 4. Verificar logs: zero 401/403/429
```

---

## Riscos & mitigações

| Risco | Impacto | Mitigação |
|---|---|---|
| Chave privada vaza do APK | Atacante gera tokens válidos | Aceitável para MVP. Pra produção: rotação periódica + Play Integrity binding |
| nginx exposto a scanner/bot | Tentativas de brute force | rate limit + fail2ban |
| Validador Python cai | Auth falha, app para de funcionar | systemd auto-restart + `Restart=on-failure` |
| `cryptography` package do Flutter tem bugs | Token não assina direito | Validação cruzada: gerar token no app, verificar com `jwt` CLI no Python |
| `dns propagation` demora | Fase 1 bloqueada | Aguardar (24-48h típico) |
| Tailscale conflita com HTTPS (porta diferente) | Sem conflito: 8300/TCP vs 443/TCP | Sem problema |
| Falta de espaço em disco pra logs | nginx para de logar | logrotate padrão + monitorar com `df -h` |

---

## Próximo passo AGORA

**Fase 0 (não depende do provedor):**

Me dê "ok" e eu começo pelo Flutter:
1. Adicionar deps no `pubspec.yaml`
2. Criar `JwtTokenManager` + `AuthenticatedHttpClient`
3. Criar testes
4. Criar script `generate_jwt_keypair.sh` pra você rodar na VPS quando chegar a hora

Você pode comitar a qualquer momento as 2 mudanças cosméticas já no working tree (User-Agent + remoção Connection) — são independentes dessa migração.

**Working tree atual (do que você pode comitar já):**
- `lib/ui/player/widgets/video_player_screen.dart`: +7/-2 (User-Agent + Connection)

**Working tree futuro (após Fase 0):**
- `pubspec.yaml`: +3 deps
- `lib/data/services/auth/jwt_token_manager.dart`: novo (~100 linhas)
- `lib/data/services/auth/authenticated_http_client.dart`: novo (~50 linhas)
- `test/data/services/auth/jwt_token_manager_test.dart`: novo
- `tools/generate_jwt_keypair.sh`: novo
- `lib/core/constants/api_constants.dart`: URLs mudam
- `lib/app.dart`: init JwtTokenManager

Me dá "ok" pra começar a Fase 0?

# PauloFlix — Fase 1: Setup VPS (Guia Passo-a-Passo)

> **Status:** Pronto para execução. DNS já propagou (`media.oliveira.braga.nom.br` resolve para o IP da VPS).
>
> **Você vai precisar de:** acesso SSH root na VPS, ~30 minutos.
>
> **Estratégia:** Vamos usar **Let's Encrypt via certbot** (gratuito, auto-renovável) em vez do certificado do provedor. Se você preferir usar o do provedor, pule o passo 2 e me diga os paths.

---

## TL;DR — Sequência

1. SSH na VPS
2. Instalar certbot + gerar certificado Let's Encrypt
3. Instalar Python deps (FastAPI + uvicorn + cryptography)
4. Gerar par de chaves Ed25519 (script que eu criei na Fase 0)
5. Deploy do validador JWT (FastAPI app)
6. Criar systemd unit pro validador
7. Deploy do nginx config
8. Ativar site + reload
9. Configurar fail2ban
10. Smoke test com curl

**Tempo total:** ~30 min (depende da velocidade da VPS).

---

## Passo 1 — Conectar na VPS

```bash
ssh root@<ip-da-vps>
```

Substitua `<ip-da-vps>` pelo IP real. Se você usa uma porta customizada: `ssh -p 2222 root@<ip-da-vps>`.

**Verificação rápida do ambiente:**
```bash
cat /etc/os-release | head -3
nginx -v
python3 --version
which certbot || echo "certbot não instalado (vamos instalar)"
```

Esperado: Ubuntu 22.04+, nginx 1.18+, python 3.10+.

---

## Passo 2 — Certificado TLS via Let's Encrypt

Vamos rodar certbot no modo `nginx` (mais simples, ele configura tudo automaticamente):

```bash
apt update
apt install -y certbot python3-certbot-nginx

# Gera certificado + configura nginx básico pra validação HTTP-01
certbot --nginx -d media.oliveira.braga.nom.br
```

**O certbot vai pedir:**
- Email (para notificações de expiração) → coloque seu email
- Aceitar Terms of Service → Y
- Compartilhar email com EFF → sua escolha (geralmente N)

**Verificação:**
```bash
ls -la /etc/letsencrypt/live/media.oliveira.braga.nom.br/
# Esperado: fullchain.pem, privkey.pem, cert.pem, chain.pem
```

**Teste de renovação automática:**
```bash
certbot renew --dry-run
# Esperado: Congratulations, all simulated renewals succeeded
```

O certbot já configura um systemd timer que renova 30 dias antes de expirar. Sem ação sua depois.

---

## Passo 3 — Dependências Python para o validador

```bash
apt install -y python3-pip python3-venv
```

Vamos usar um virtualenv isolado (boa prática, não conflita com system Python):

```bash
mkdir -p /opt/jwt-validator
cd /opt/jwt-validator
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install fastapi 'uvicorn[standard]' cryptography
```

**Verificação:**
```bash
/opt/jwt-validator/venv/bin/uvicorn --version
# Esperado: uvicorn 0.x.x
```

---

## Passo 4 — Gerar par de chaves Ed25519

O script `tools/generate_jwt_keypair.sh` está no seu **PC de dev**, mas ele usa OpenSSL padrão e funciona em qualquer Linux. Vamos copiá-lo pra VPS (ou rodar os comandos direto):

### Opção A: Copiar o script

Do seu PC (não da VPS):
```bash
scp "C:/Users/pr02n/developer/goanime-mobile/tools/generate_jwt_keypair.sh" root@<ip-da-vps>:/root/generate_jwt_keypair.sh
```

Depois na VPS:
```bash
ssh root@<ip-da-vps>
bash /root/generate_jwt_keypair.sh
```

### Opção B: Rodar os comandos direto (sem script)

Na VPS:
```bash
mkdir -p /etc/nginx/auth
chmod 700 /etc/nginx/auth
cd /etc/nginx/auth

# Gera chave privada PEM
openssl genpkey -algorithm Ed25519 -out pauloflix_private.pem
chmod 600 pauloflix_private.pem

# Extrai chave pública PEM
openssl pkey -in pauloflix_private.pem -pubout -out pauloflix_public.pem
chmod 644 pauloflix_public.pem

# Converte privada para raw 32 bytes
openssl pkey -in pauloflix_private.pem -outform DER | tail -c 32 > pauloflix_private.raw
chmod 600 pauloflix_private.raw

# Imprime base64 (esse é o valor que vai pro app)
echo "=================================================================="
echo "COLE ESTE BASE64 NO APP (em _kPrivateKeyB64 do jwt_token_manager.dart):"
echo "=================================================================="
base64 -w 0 pauloflix_private.raw
echo ""
echo "=================================================================="
```

**⚠️ IMPORTANTE:** Copie o base64 que apareceu entre os `==========` marcadores. Esse valor vai substituir o placeholder em `_kPrivateKeyB64` do arquivo `lib/data/services/auth/jwt_token_manager.dart` no seu PC.

**Anote o base64 em algum lugar seguro** (password manager, encrypted file, etc.). Você vai precisar dele pra Fase 2.

**Após colar no app e rebuildar, delete o raw file na VPS:**
```bash
rm /etc/nginx/auth/pauloflix_private.raw
```

(Não deletar o `pauloflix_private.pem` ainda — pode ser útil pra debug, mas com permissão 600 só root lê.)

---

## Passo 5 — Deploy do validador JWT

Crie o arquivo do validador:

```bash
cat > /opt/jwt-validator/validate.py << 'PYEOF'
"""JWT Ed25519 validator para PauloFlix.

Roda em loopback (127.0.0.1:8301). Acessado via nginx `auth_request`.
Valida assinatura Ed25519, expiração e estrutura do token.
"""
import base64
import json
import time
from pathlib import Path

from cryptography.hazmat.primitives.serialization import load_pem_public_key
from cryptography.exceptions import InvalidSignature
from fastapi import FastAPI, Header, HTTPException

PUBLIC_KEY_PATH = Path('/etc/nginx/auth/pauloflix_public.pem')
app = FastAPI()
_public_key = None


@app.on_event("startup")
def load_key():
    """Carrega chave pública uma vez no startup."""
    global _public_key
    _public_key = load_pem_public_key(PUBLIC_KEY_PATH.read_bytes())
    print(f"[jwt-validator] Chave pública carregada de {PUBLIC_KEY_PATH}")


def _b64decode(s: str) -> bytes:
    """Base64url decode com padding automático."""
    return base64.urlsafe_b64decode(s + '=' * (-len(s) % 4))


@app.get("/validate")
def validate(authorization: str = Header(None)):
    """Valida JWT Ed25519. Retorna device_id se OK, 401 se inválido.

    Header esperado: Authorization: Bearer <jwt>
    """
    if not authorization or not authorization.startswith('Bearer '):
        raise HTTPException(status_code=401, detail="Missing Bearer token")

    token = authorization[7:]
    parts = token.split('.')
    if len(parts) != 3:
        raise HTTPException(status_code=401, detail="Malformed JWT (not 3 parts)")

    try:
        header = json.loads(_b64decode(parts[0]))
        payload = json.loads(_b64decode(parts[1]))
        signature = _b64decode(parts[2])
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Base64/json decode failed: {e}")

    # 1. Algoritmo deve ser EdDSA
    if header.get('alg') != 'EdDSA':
        raise HTTPException(status_code=401, detail=f"Invalid alg: {header.get('alg')}")

    # 2. Expiração
    if 'exp' not in payload:
        raise HTTPException(status_code=401, detail="Missing exp claim")
    if payload['exp'] < time.time():
        raise HTTPException(status_code=401, detail="Token expired")

    # 3. Assinatura Ed25519
    try:
        signing_input = f"{parts[0]}.{parts[1]}".encode('utf-8')
        _public_key.verify(signature, signing_input)
    except InvalidSignature:
        raise HTTPException(status_code=401, detail="Invalid signature")

    # 4. device_id presente (usado pra logging/auditoria)
    device_id = payload.get('device_id')
    if not device_id:
        raise HTTPException(status_code=401, detail="Missing device_id claim")

    print(f"[jwt-validator] OK device_id={device_id} exp={payload['exp']}")
    return {"device_id": device_id, "exp": payload['exp']}


@app.get("/health")
def health():
    """Health check (sem auth, pra monitoramento)."""
    return {"status": "ok"}
PYEOF
```

**Verificação:**
```bash
python3 -c "import ast; ast.parse(open('/opt/jwt-validator/validate.py').read())"
# Esperado: sem output (parse OK)
```

---

## Passo 6 — Systemd unit pro validador

```bash
cat > /etc/systemd/system/jwt-validator.service << 'SVCEOF'
[Unit]
Description=PauloFlix JWT Validator (FastAPI on 127.0.0.1:8301)
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/jwt-validator
Environment="PATH=/opt/jwt-validator/venv/bin"
ExecStart=/opt/jwt-validator/venv/bin/uvicorn validate:app --host 127.0.0.1 --port 8301 --log-level info
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

# Hardening mínimo
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/opt/jwt-validator
ProtectHome=true

[Install]
WantedBy=multi-user.target
SVCEOF
```

**Por que `User=www-data`?** O validador só precisa ler a chave pública (que tem `chmod 644`, world-readable). Rodar como `www-data` (não-root) reduz superfície de ataque.

**Ativar e iniciar:**
```bash
systemctl daemon-reload
systemctl enable jwt-validator
systemctl start jwt-validator
systemctl status jwt-validator
```

**Esperado:** `active (running)`. Se der erro, veja os logs:
```bash
journalctl -u jwt-validator -n 30 --no-pager
```

**Smoke test do validador isolado:**
```bash
curl http://127.0.0.1:8301/health
# Esperado: {"status":"ok"}

curl -I http://127.0.0.1:8301/validate
# Esperado: HTTP/1.1 401 Unauthorized (sem Authorization header)
```

---

## Passo 7 — Deploy do nginx config

Primeiro, vamos descobrir o que o certbot criou pra gente e ajustar:

```bash
ls /etc/nginx/sites-enabled/
cat /etc/nginx/sites-enabled/default | head -20
```

Provavelmente o certbot modificou o site default. Vamos criar um config limpo pro PauloFlix:

```bash
cat > /etc/nginx/sites-available/pauloflix << 'NGINXEOF'
# PauloFlix — Streaming autenticado via JWT Ed25519

# Rate limit por IP: 10 req/s com burst 20
limit_req_zone $binary_remote_addr zone=pauloflix_limit:10m rate=10r/s;

# Upstream do validador JWT (loopback)
upstream jwt_validator {
    server 127.0.0.1:8301;
    keepalive 16;
}

# HTTP → HTTPS redirect
server {
    listen 80;
    server_name media.oliveira.braga.nom.br;
    return 301 https://$host$request_uri;
}

# HTTPS
server {
    listen 443 ssl http2;
    server_name media.oliveira.braga.nom.br;

    # Certificados Let's Encrypt (paths padrão do certbot)
    ssl_certificate /etc/letsencrypt/live/media.oliveira.braga.nom.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/media.oliveira.braga.nom.br/privkey.pem;

    # SSL hardening
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy no-referrer;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Logs separados pra ficar fácil de monitorar
    access_log /var/log/nginx/pauloflix_access.log;
    error_log /var/log/nginx/pauloflix_error.log;

    # Validador (só nginx pode chamar, via auth_request)
    location = /auth/validate {
        internal;
        proxy_pass http://jwt_validator/validate;
        proxy_pass_request_body off;
        proxy_set_header Content-Length "";
        proxy_set_header Authorization $http_authorization;
    }

    # Health check público (sem auth, pra você monitorar uptime)
    location = /health {
        access_log off;
        return 200 "ok\n";
        add_header Content-Type text/plain;
    }

    # TV Shows streaming
    location /tvshows/ {
        limit_req zone=pauloflix_limit burst=20 nodelay;
        auth_request /auth/validate;
        auth_request_set $device_id $upstream_http_device_id;

        # Path real na VPS
        alias /home/pr02nl/tvshows/;

        # IMPORTANTE: range requests pra player
        add_header Accept-Ranges bytes;
        add_header Cache-Control "public, max-age=3600";

        # Para o player conseguir seek
        try_files $uri =404;
    }

    # Movies streaming
    location /movies/ {
        limit_req zone=pauloflix_limit burst=20 nodelay;
        auth_request /auth/validate;

        alias /home/pr02nl/movies/;
        add_header Accept-Ranges bytes;
        add_header Cache-Control "public, max-age=3600";

        try_files $uri =404;
    }

    # Bloqueia qualquer outro path
    location / {
        return 404;
    }
}
NGINXEOF
```

**⚠️ Ajuste o path do alias** para o caminho real dos seus arquivos:
- TV Shows: `/home/pr02nl/tvshows/`
- Movies: `/home/pr02nl/movies/`

O config que vou te passar já usa esses paths.

**Desabilita o site default** (que o certbot modificou):
```bash
rm -f /etc/nginx/sites-enabled/default
```

**Ativa o site novo:**
```bash
ln -sf /etc/nginx/sites-available/pauloflix /etc/nginx/sites-enabled/
nginx -t
```

**Esperado:** `syntax is ok` e `test is successful`.

**Reload:**
```bash
systemctl reload nginx
```

---

## Passo 8 — fail2ban (proteção contra brute force)

```bash
cat > /etc/fail2ban/filter.d/nginx-pauloflix.conf << 'F2BEOF'
[Definition]
failregex = ^<HOST> .* (401|403|429) .*$
ignoreregex =
F2BEOF

cat > /etc/fail2ban/jail.d/pauloflix.conf << 'JAILEOF'
[pauloflix]
enabled  = true
port     = https,http
filter   = nginx-pauloflix
logpath  = /var/log/nginx/pauloflix_access.log
maxretry = 50
findtime = 300
bantime  = 3600
JAILEOF

systemctl restart fail2ban
systemctl status fail2ban
```

---

## Passo 9 — Smoke test end-to-end

### Teste 1: DNS + TLS

```bash
dig +short media.oliveira.braga.nom.br
# Esperado: IP da VPS

openssl s_client -connect media.oliveira.braga.nom.br:443 -servername media.oliveira.braga.nom.br < /dev/null 2>&1 | grep "Verify return code"
# Esperado: Verify return code: 0 (ok)
```

### Teste 2: Health check

```bash
curl https://media.oliveira.braga.nom.br/health
# Esperado: ok
```

### Teste 3: Sem token (deve dar 401)

```bash
curl -I https://media.oliveira.braga.nom.br/tvshows/
# Esperado: HTTP/1.1 401 Unauthorized
```

### Teste 4: Range request sem token (deve dar 401)

```bash
curl -I -H "Range: bytes=0-1023" https://media.oliveira.braga.nom.br/tvshows/S04E08.mp4
# Esperado: HTTP/1.1 401 Unauthorized
```

### Teste 5: Gerar token de teste e validar

Vamos criar um pequeno script Python pra gerar um token de teste usando a chave privada que geramos:

```bash
# No PC de dev (não VPS), cria o script:
cat > /tmp/gen_test_token.py << 'PYEOF'
"""Gera token de teste usando a chave privada gerada no Passo 4.

Uso: python3 gen_test_token.py <base64-da-chave-privada>
"""
import sys
import json
import base64
import time
import uuid

from cryptography.hazmat.primitives.serialization import load_pem_private_key

priv_b64 = sys.argv[1]
priv_raw = base64.b64decode(priv_b64)
# Ed25519 raw seed (32 bytes) -> PEM
import tempfile, subprocess
with tempfile.NamedTemporaryFile(delete=False) as f:
    der_blob = b'\x30\x2e\x02\x01\x00\x30\x05\x06\x03\x2b\x65\x70\x04\x22\x04\x20' + priv_raw
    f.write(der_blob)
    key_file = f.name

with open(key_file, 'rb') as f:
    priv_pem = load_pem_private_key(f.read(), password=None)
pub_pem = priv_pem.public_key()

header = {'alg': 'EdDSA', 'typ': 'JWT'}
payload = {
    'device_id': str(uuid.uuid4()),
    'iat': int(time.time()),
    'exp': int(time.time()) + 3600,  # 1h for testing
    'jti': str(int(time.time() * 1000)),
}

def b64u(d):
    return base64.urlsafe_b64encode(d).rstrip(b'=').decode()

header_b64 = b64u(json.dumps(header).encode())
payload_b64 = b64u(json.dumps(payload).encode())
signing_input = f"{header_b64}.{payload_b64}".encode()

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey
sig = priv_pem.sign(signing_input)
token = f"{header_b64}.{payload_b64}.{b64u(sig)}"
print(token)
PYEOF

# Gera o token (substitua <BASE64> pelo base64 que apareceu no Passo 4)
python3 /tmp/gen_test_token.py <BASE64>
# Saída: eyJhbG... (o token completo)
```

**Com o token gerado, teste:**
```bash
TOKEN=*** curl -I -H "Authorization: Bearer *** https://media.oliveira.braga.nom.br/tvshows/S04E08.mp4
# Esperado: HTTP/1.1 200 OK (se arquivo existe) ou 404 (se não existe, mas auth passou)
```

### Teste 6: Range request com token (deve dar 206)

```bash
TOKEN=*** curl -I -H "Authorization: Bearer *** -H "Range: bytes=0-1023" \
  https://media.oliveira.braga.nom.br/tvshows/S04E08.mp4
# Esperado: HTTP/1.1 206 Partial Content
```

### Teste 7: Token expirado (deve dar 401)

Não tem como testar diretamente sem manipular tempo, mas o código está em `/opt/jwt-validator/validate.py` e cobre esse caso.

### Teste 8: Rate limit (deve dar 429)

```bash
# Sem token, mandar 30 reqs em 1 segundo
for i in {1..30}; do
  curl -s -o /dev/null -w "%{http_code} " https://media.oliveira.braga.nom.br/tvshows/test.mp4
done
echo ""
# Esperado: primeiros ~10 são 401, depois começam a dar 429 (rate limit)
```

---

## Passo 10 — Colar a chave privada no app

Agora que tudo funciona na VPS, você precisa **colar o base64** que apareceu no Passo 4 no arquivo do app:

1. Abra `lib/data/services/auth/jwt_token_manager.dart` no seu PC de dev
2. Encontre a linha `static const String _kPrivateKeyB64 = 'REPLACE_WITH_OUTPUT_OF_generate_jwt_keypair.sh_BASE64';`
3. Substitua pelo base64 do Passo 4
4. Salve

**Verificação de que a chave foi colada certa:**
```bash
# No seu PC de dev, com a chave colada:
flutter test test/data/services/auth/jwt_token_manager_test.dart
# Esperado: All tests passed!
```

---

## Próximos passos (Fase 2)

Quando você confirmar que **todos os testes do Passo 9 passaram**, me avisa e eu começo a Fase 2:

1. Atualizar `api_constants.dart` para apontar pro novo domínio
2. Inicializar `JwtTokenManager` no `app.dart` startup
3. Injetar `AuthenticatedHttpClient` no `PauloFlixService` e `PauloFlixMoviesService`
4. Build + install em device de teste
5. Smoke test: sync de PauloFlix + reprodução de 1 episódio

---

## Troubleshooting

### Erro "Permission denied" ao ler `pauloflix_public.pem`

```bash
ls -la /etc/nginx/auth/
# Esperado: pauloflix_public.pem com chmod 644
chmod 644 /etc/nginx/auth/pauloflix_public.pem
systemctl restart jwt-validator
```

### Erro "Cannot connect to 127.0.0.1:8301" no nginx

```bash
systemctl status jwt-validator
journalctl -u jwt-validator -n 30
# Se o serviço caiu, veja o erro e corrija
```

### 403 ao invés de 401

Tem algo no nginx bloqueando antes do auth_request. Verifique:
```bash
tail -f /var/log/nginx/pauloflix_error.log
# Refaça o curl e veja o erro
```

### certbot falhou na validação HTTP-01

```bash
# Verificar se porta 80 está acessível de fora
curl http://media.oliveira.braga.nom.br/
# Se der timeout, pode ser firewall da VPS bloqueando porta 80
# Solução: abrir porta 80 no firewall (ufw allow 80/tcp, ou iptables)
```

### fail2ban bloqueou seu IP durante o teste

```bash
# Da VPS, ver IPs banidos:
fail2ban-client status pauloflix
# Desbanir seu IP:
fail2ban-client set pauloflix unbanip <seu-ip>
```

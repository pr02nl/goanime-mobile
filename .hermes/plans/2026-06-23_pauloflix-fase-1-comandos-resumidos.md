# Fase 1 — Comandos resumidos (do Passo 3 em diante)

> **Contexto:** Você já fez Passos 1 e 2. Certificado TLS já está em
> `/etc/letsencrypt/live/media.oliveira.braga.nom.br/`. Erro do
> "Could not install certificate" é **esperado e inofensivo** — ele
> só não conseguiu achar o server block (porque ainda não criamos).
>
> **Tudo abaixo é para rodar na VPS via SSH, em sequência.**

---

## Passo 3 — Dependências Python

```bash
apt update
apt install -y python3-pip python3-venv

mkdir -p /opt/jwt-validator
cd /opt/jwt-validator
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install fastapi 'uvicorn[standard]' cryptography

# Verificação
/opt/jwt-validator/venv/bin/uvicorn --version
```

**Esperado:** `Running uvicorn 0.x.x`

---

## Passo 4 — Gerar par Ed25519

```bash
mkdir -p /etc/nginx/auth
chmod 700 /etc/nginx/auth
cd /etc/nginx/auth

openssl genpkey -algorithm Ed25519 -out pauloflix_private.pem
chmod 600 pauloflix_private.pem

openssl pkey -in pauloflix_private.pem -pubout -out pauloflix_public.pem
chmod 644 pauloflix_public.pem

openssl pkey -in pauloflix_private.pem -outform DER | tail -c 32 > pauloflix_private.raw
chmod 600 pauloflix_private.raw

echo "=================================================================="
echo "COLE ESTE BASE64 NO APP (_kPrivateKeyB64 do jwt_token_manager.dart):"
echo "=================================================================="
base64 -w 0 pauloflix_private.raw
echo ""
echo "=================================================================="
```

**⚠️ IMPORTANTE:**
- Copie TUDO entre as duas linhas de `===` (sem espaços/quebras)
- Salve em um lugar seguro (password manager, arquivo encrypted)
- Esse é o valor que vai no `_kPrivateKeyB64` do `jwt_token_manager.dart` no seu PC

---

## Passo 5 — Deploy do validador JWT

```bash
cat > /opt/jwt-validator/validate.py << 'PYEOF'
"""JWT Ed25519 validator para PauloFlix.

Roda em loopback (127.0.0.1:8301). Acessado via nginx auth_request.
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
    global _public_key
    _public_key = load_pem_public_key(PUBLIC_KEY_PATH.read_bytes())
    print(f"[jwt-validator] Chave publica carregada de {PUBLIC_KEY_PATH}")


def _b64decode(s: str) -> bytes:
    return base64.urlsafe_b64decode(s + '=' * (-len(s) % 4))


@app.get("/validate")
def validate(authorization: str = Header(None)):
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

    if header.get('alg') != 'EdDSA':
        raise HTTPException(status_code=401, detail=f"Invalid alg: {header.get('alg')}")

    if 'exp' not in payload:
        raise HTTPException(status_code=401, detail="Missing exp claim")
    if payload['exp'] < time.time():
        raise HTTPException(status_code=401, detail="Token expired")

    try:
        signing_input = f"{parts[0]}.{parts[1]}".encode('utf-8')
        _public_key.verify(signature, signing_input)
    except InvalidSignature:
        raise HTTPException(status_code=401, detail="Invalid signature")

    device_id = payload.get('device_id')
    if not device_id:
        raise HTTPException(status_code=401, detail="Missing device_id claim")

    print(f"[jwt-validator] OK device_id={device_id} exp={payload['exp']}")
    return {"device_id": device_id, "exp": payload['exp']}


@app.get("/health")
def health():
    return {"status": "ok"}
PYEOF

# Validação de sintaxe
python3 -c "import ast; ast.parse(open('/opt/jwt-validator/validate.py').read())" && echo "Sintaxe OK"
```

---

## Passo 6 — Systemd unit

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

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/opt/jwt-validator
ProtectHome=true

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable jwt-validator
systemctl start jwt-validator
sleep 2
systemctl status jwt-validator
```

**Esperado:** `active (running)`. Se der erro:
```bash
journalctl -u jwt-validator -n 30 --no-pager
```

**Smoke test do validador:**
```bash
curl http://127.0.0.1:8301/health
# Esperado: {"status":"ok"}

curl -I http://127.0.0.1:8301/validate
# Esperado: HTTP/1.1 401 Unauthorized
```

---

## Passo 7 — Nginx config

```bash
cat > /etc/nginx/sites-available/pauloflix << 'NGINXEOF'
limit_req_zone $binary_remote_addr zone=pauloflix_limit:10m rate=10r/s;

upstream jwt_validator {
    server 127.0.0.1:8301;
    keepalive 16;
}

server {
    listen 80;
    server_name media.oliveira.braga.nom.br;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name media.oliveira.braga.nom.br;

    ssl_certificate /etc/letsencrypt/live/media.oliveira.braga.nom.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/media.oliveira.braga.nom.br/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy no-referrer;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    access_log /var/log/nginx/pauloflix_access.log;
    error_log /var/log/nginx/pauloflix_error.log;

    location = /auth/validate {
        internal;
        proxy_pass http://jwt_validator/validate;
        proxy_pass_request_body off;
        proxy_set_header Content-Length "";
        proxy_set_header Authorization $http_authorization;
    }

    location = /health {
        access_log off;
        return 200 "ok\n";
        add_header Content-Type text/plain;
    }

    location /tvshows/ {
        limit_req zone=pauloflix_limit burst=20 nodelay;
        auth_request /auth/validate;
        auth_request_set $device_id $upstream_http_device_id;

        alias /home/pr02nl/tvshows/;
        add_header Accept-Ranges bytes;
        add_header Cache-Control "public, max-age=3600";
        try_files $uri =404;
    }

    location /movies/ {
        limit_req zone=pauloflix_limit burst=20 nodelay;
        auth_request /auth/validate;

        alias /home/pr02nl/movies/;
        add_header Accept-Ranges bytes;
        add_header Cache-Control "public, max-age=3600";
        try_files $uri =404;
    }

    location / {
        return 404;
    }
}
NGINXEOF

# Desabilita site default (que certbot modificou)
rm -f /etc/nginx/sites-enabled/default

# Ativa o site novo
ln -sf /etc/nginx/sites-available/pauloflix /etc/nginx/sites-enabled/

# Valida config
nginx -t
```

**Esperado:** `syntax is ok` e `test is successful`.

**Recarrega nginx:**
```bash
systemctl reload nginx
```

---

## Passo 8 — fail2ban

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

## Passo 9 — Smoke tests

```bash
# Teste 1: DNS
dig +short media.oliveira.braga.nom.br

# Teste 2: TLS
openssl s_client -connect media.oliveira.braga.nom.br:443 -servername media.oliveira.braga.nom.br < /dev/null 2>&1 | grep "Verify return code"

# Teste 3: HTTP → HTTPS redirect
curl -I http://media.oliveira.braga.nom.br/health

# Teste 4: Health check (HTTPS)
curl https://media.oliveira.braga.nom.br/health

# Teste 5: Sem token = 401
curl -I https://media.oliveira.braga.nom.br/tvshows/

# Teste 6: Range request sem token = 401
curl -I -H "Range: bytes=0-1023" https://media.oliveira.braga.nom.br/tvshows/S04E08.mp4
```

**Agora vem a parte crítica: gerar um token de teste.**

**Do seu PC de dev (NÃO da VPS)**, primeiro instale a lib Python:

```bash
# No PC de dev
pip install cryptography
```

Depois crie o script:
```bash
cat > /tmp/gen_test_token.py << 'PYEOF'
"""Gera token JWT Ed25519 de teste.

Uso: python3 gen_test_token.py <base64-da-chave-privada>
"""
import sys
import json
import base64
import time
import uuid
import tempfile

from cryptography.hazmat.primitives.serialization import load_pem_private_key

priv_b64 = sys.argv[1]
priv_raw = base64.b64decode(priv_b64)

# Ed25519 raw seed (32 bytes) -> DER (46 bytes) -> key object
der_blob = b'\x30\x2e\x02\x01\x00\x30\x05\x06\x03\x2b\x65\x70\x04\x22\x04\x20' + priv_raw
with tempfile.NamedTemporaryFile(delete=False) as f:
    f.write(der_blob)
    key_file = f.name

with open(key_file, 'rb') as f:
    priv_pem = load_pem_private_key(f.read(), password=None)

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
sig = priv_pem.sign(signing_input)
token = f"{header_b64}.{payload_b64}.{b64u(sig)}"
print(token)
PYEOF

# Gera o token
python3 /tmp/gen_test_token.py "COLE_O_BASE64_AQUI"
# Output: eyJhbG... (o token)
```

**Com o token gerado, na VPS:**
```bash
TOKEN=*** # Cole aqui o token gerado

# Teste 7: Com token + range request = 206
curl -I -H "Authorization: Bearer *** -H "Range: bytes=0-1023" \
  https://media.oliveira.braga.nom.br/tvshows/S04E08.mp4

# Teste 8: Sem range, só pra ver status
curl -I -H "Authorization: Bearer *** \
  https://media.oliveira.braga.nom.br/tvshows/S04E08.mp4
```

**Teste 9: Rate limit (deve dar 429 após ~20 reqs)**
```bash
for i in {1..30}; do
  curl -s -o /dev/null -w "%{http_code} " https://media.oliveira.braga.nom.br/tvshows/test.mp4
done
echo ""
```

---

## Quando terminar

Me avise:
1. **"X/8 smoke tests passaram"** (ou qual falhou + output)
2. **O base64 da chave privada** (pra eu atualizar `_kPrivateKeyB64` no app)

Aí começo a Fase 2 (integração no app).

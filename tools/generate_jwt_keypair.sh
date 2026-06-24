#!/usr/bin/env bash
#
# tools/generate_jwt_keypair.sh
#
# Gera o par de chaves Ed25519 usado para assinar/verificar os tokens
# JWT do PauloFlix (migração Tailscale → HTTPS+token).
#
# ## O que esse script faz
#
# 1. Gera uma chave privada Ed25519 (32 bytes) em formato PEM
# 2. Extrai a chave pública (32 bytes) em formato PEM
# 3. Converte a chave privada para formato raw (32 bytes) e depois
#    para base64 — esse é o valor que você cola em
#    `_kPrivateKeyB64` no arquivo `lib/data/services/auth/jwt_token_manager.dart`
# 4. Salva a chave pública em `/etc/nginx/auth/pauloflix_public.pem`
#    (caminho do nginx config que vou passar na Fase 1)
#
# ## Segurança
#
# - Chave privada NUNCA deve sair da VPS. O base64 impresso no stdout
#   é o ÚNICO momento que o dev precisa vê-la (pra colar no app).
# - Em produção, considere gerar a chave em um air-gapped machine
#   e copiar manualmente para a VPS + repositório do app.
# - Após colar no app e rebuildar, **delete** o arquivo .raw e
#   o base64 do seu clipboard/histórico.
#
# ## Uso
#
#   $ ssh root@vps
#   $ bash generate_jwt_keypair.sh
#
# Copie o output BASE64 (entre os marcadores) para o app.

set -euo pipefail

# Diretório de saída (criado se não existir)
OUT_DIR="${OUT_DIR:-/etc/nginx/auth}"
mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"

echo "=== Gerando par de chaves Ed25519 em $OUT_DIR ==="

# 1. Chave privada PEM
openssl genpkey -algorithm Ed25519 -out "$OUT_DIR/pauloflix_private.pem"
chmod 600 "$OUT_DIR/pauloflix_private.pem"

# 2. Chave pública PEM
openssl pkey -in "$OUT_DIR/pauloflix_private.pem" -pubout -out "$OUT_DIR/pauloflix_public.pem"
chmod 644 "$OUT_DIR/pauloflix_public.pem"

# 3. Converte privada para raw 32 bytes
openssl pkey -in "$OUT_DIR/pauloflix_private.pem" -outform DER | tail -c 32 > "$OUT_DIR/pauloflix_private.raw"
chmod 600 "$OUT_DIR/pauloflix_private.raw"

# 4. Imprime base64 da chave privada raw (única coisa que vai pro app)
PRIV_B64=$(base64 -w 0 "$OUT_DIR/pauloflix_private.raw")

echo ""
echo "=== SUCESSO ==="
echo ""
echo "Chave pública salva em: $OUT_DIR/pauloflix_public.pem"
echo "Chave privada (raw 32 bytes) salva em: $OUT_DIR/pauloflix_private.raw (delete após colar no app)"
echo "Chave privada (PEM) salva em: $OUT_DIR/pauloflix_private.pem (NÃO compartilhar)"
echo ""
echo "=================================================================="
echo "COLE O BASE64 ABAIXO EM _kPrivateKeyB64 no jwt_token_manager.dart"
echo "=================================================================="
echo "$PRIV_B64"
echo "=================================================================="
echo ""
echo "Próximos passos:"
echo "  1. ssh user@dev-pc"
echo "  2. Edite lib/data/services/auth/jwt_token_manager.dart"
echo "  3. Substitua o valor de _kPrivateKeyB64 pelo base64 acima"
echo "  4. Rode: rm $OUT_DIR/pauloflix_private.raw"
echo "  5. Faça build do APK e instale"

#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$(mktemp -d)"; trap 'rm -rf "$LOG_DIR"' EXIT
source "$ROOT_DIR/modules/diagnostics_core.sh"
entrada=$(cat <<'TESTDATA'
url: https://usuario:senha@servidor.example/caminho
outro: https://alguem@exemplo.org/repositorio
banco: mongodb://login:senhaa@host:27017/db
consulta: https://example.org/api?access_token=valor-token&api_key=segredo-query
normal: https://example.org/publico
Authorization: Bearer abc.DEF.xyz
API_KEY="muito confidencial"
TESTDATA
)
resultado="$(printf '%s\n' "$entrada" | redigir_segredos)"
for segredo in 'usuario:senha@' 'alguem@' 'login:senhaa@' 'valor-token' 'segredo-query' 'abc.DEF.xyz' 'muito confidencial'; do
    if printf '%s\n' "$resultado" | grep -Fq "$segredo"; then echo "Segredo exposto: $segredo"; exit 1; fi
done
printf '%s\n' "$resultado" | grep -Fq 'https://example.org/publico'
printf '%s\n' "$resultado" | grep -Fq 'CREDENCIAIS_REMOVIDAS'
echo 'OK: URL autenticada, token de query e headers sanitizados.'

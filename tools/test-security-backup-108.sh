#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export LOG_FILE="$TMP/log" TMP_ROOT="$TMP/private" SESSION_TMP_DIR="$TMP/private/session" DOWNLOADS_DIR="$TMP/download"
mkdir -p "$SESSION_TMP_DIR" "$DOWNLOADS_DIR"
resolver_downloads_dir() { return 0; }
info() { :; }; warn() { :; }; error() { :; }; ok() { :; }; log() { :; }
source "$ROOT_DIR/modules/projects_storage.sh"
PROJ="$TMP/origem/demo"; mkdir -p "$PROJ/src" "$PROJ/keys" "$PROJ/node_modules"
printf 'codigo seguro\n' > "$PROJ/src/app.js"
printf 'SENHA=um-segredo\n' > "$PROJ/.env"
printf 'token-antigo\n' > "$PROJ/.env.production"
printf 'chave-pem-falsa\n' > "$PROJ/keys/key.pem"
printf 'chave-de-assinatura\n' > "$PROJ/keys/release.p12"
printf 'ignore\n' > "$PROJ/node_modules/dep.js"
projeto_contem_arquivos_sensiveis "$PROJ" || { echo 'Não detectou credenciais'; exit 1; }
if backup_pre_exclusao_permitido "$PROJ"; then echo 'Permitiu backup incompleto antes de excluir'; exit 1; fi
gerar_backup_publico_projeto "$PROJ" demo
[ "$BACKUP_PROJETO_COMPLETO" = false ]
LISTA="$TMP/list"; tar -tzf "$BACKUP_PROJETO_RESULTADO" > "$LISTA"
grep -Fq 'demo/src/app.js' "$LISTA"
for segredo in '.env' 'key.pem' 'release.p12' 'node_modules'; do
    if grep -Fq "$segredo" "$LISTA"; then echo "Conteúdo sensível vazou: $segredo"; exit 1; fi
done
if tar -xOzf "$BACKUP_PROJETO_RESULTADO" 2>/dev/null | grep -q 'um-segredo'; then echo 'Credencial encontrada'; exit 1; fi
rm "$PROJ/.env" "$PROJ/.env.production" "$PROJ/keys/key.pem" "$PROJ/keys/release.p12"
backup_pre_exclusao_permitido "$PROJ"
echo 'OK: backup público seguro e exclusão protegida.'

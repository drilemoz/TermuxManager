#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP"
mkdir -p "$HOME/.ssh" "$HOME/.config/termux-manager"
source "$ROOT/modules/projects_aws.sh"
info(){ :; }
printf 'host=18.217.192.20\nssh_key=%s/.ssh/iguatamaonline.pem\n' "$HOME" > "$AWS_CONFIG_FILE"
printf '%s\n' '-----BEGIN OPENSSH PRIVATE KEY-----' > "$HOME/.ssh/iguatamaonline"
chmod 600 "$HOME/.ssh/iguatamaonline"
aws_carregar_config
[[ "$AWS_KEY" == "$HOME/.ssh/iguatamaonline" ]]
aws_validar_config
cp "$AWS_KEY" "$HOME/.ssh/iguatamaonline.pem"
aws_carregar_config
[[ "$AWS_KEY" == "$HOME/.ssh/iguatamaonline.pem" ]]
aws_escolher_chave <<< 1
[[ "$AWS_KEY" == "$HOME/.ssh/iguatamaonline" ]]
aws_salvar_config
aws_carregar_config
[[ "$AWS_KEY" == "$HOME/.ssh/iguatamaonline" ]]
echo 'OK: fallback, preservação de chave existente, seleção e persistência.'

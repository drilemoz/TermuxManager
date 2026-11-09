#!/usr/bin/env bash
# Teste de regressão offline; não usa AWS, SSH real, sudo ou Internet.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
mkdir -p "$HOME/.ssh" "$HOME/storage/downloads"
chmod 700 "$HOME/.ssh"
printf 'chave fictícia; nunca usar para autenticar\n' > "$HOME/.ssh/iguatamaonline.pem"
chmod 600 "$HOME/.ssh/iguatamaonline.pem"
BASE_DIR="$ROOT"
PAINEL_DIR="$HOME/Painel"
error(){ printf 'ERRO: %s\n' "$*" >&2; }
warn(){ :; }
info(){ :; }
ok(){ :; }
pause(){ :; }
cabecalho_tela(){ :; }
caixa_simples(){ :; }
confirmar_acao(){ return 0; }
scp(){ :; }  # Simula o cliente SCP ausente no ambiente de teste.
caminho_home_relativo(){ printf '%s\n' "$1"; }
# Stub do navegador de seleção: o teste faz a escolha explicitamente.
source "$ROOT/modules/projects_aws.sh"

fail(){ echo "FALHOU: $*" >&2; exit 1; }
assert_fail(){ if "$@" >/dev/null 2>&1; then fail "deveria falhar: $*"; fi; }

aws_carregar_config
aws_validar_config || fail 'configuração padrão válida'
AWS_HOST='hostname;rm -rf /'
assert_fail aws_validar_config
AWS_HOST='18.217.192.20'
AWS_PORT=0
assert_fail aws_validar_config
AWS_PORT=22
chmod 644 "$AWS_KEY"
assert_fail aws_validar_config
chmod 600 "$AWS_KEY"
aws_salvar_config || fail 'salvar config válida'
[ "$(stat -c %a "$AWS_CONFIG_FILE")" = 600 ] || fail 'arquivo config não privado'
[ "$(stat -c %a "$(dirname "$AWS_CONFIG_FILE")")" = 700 ] || fail 'pasta config não privada'
aws_carregar_config
[ "$AWS_HOST" = '18.217.192.20' ] || fail 'carregamento da configuração'

python3 - "$HOME/storage/downloads" <<'PY'
import pathlib, sys, zipfile
root = pathlib.Path(sys.argv[1]); out = root / 'AL-Sistemas-v2.0.17-VPS.zip'
files = {'VERSION':'2.0.17\n', 'instalar.sh':'#!/bin/bash\n',
         'SHA256SUMS.txt':'test\n','vps/src/server.js':'test\n',
         'vps/admin/updater.py':'test\n'}
with zipfile.ZipFile(out,'w') as z:
    for k,v in files.items(): z.writestr(k,v)
with zipfile.ZipFile(root/'FALSO.zip','w') as z: z.writestr('outro.txt','test')
PY
GOOD="$HOME/storage/downloads/AL-Sistemas-v2.0.17-VPS.zip"
BAD="$HOME/storage/downloads/FALSO.zip"
aws_validar_pacote "$GOOD" || fail 'ZIP bom rejeitado'
[ "$AWS_PACKAGE_VERSION" = 2.0.17 ] || fail 'versão errada'
assert_fail aws_validar_pacote "$BAD"

LOG="$TMP/events"
: > "$LOG"
aws_escolher_zip(){ AWS_ZIP="$GOOD"; return 0; }
aws_ssh_etapa(){ printf 'SSH %s\n' "$1" >> "$LOG"; return 0; }
scp(){ printf 'SCP\n' >> "$LOG"; return 0; }
# Digitação diferente de INSTALAR não pode acionar nenhuma conexão nem envio.
printf 'NAO\n' | aws_atualizar_alsistemas >/dev/null || fail 'cancelamento retornou erro'
[ ! -s "$LOG" ] || fail 'cancelamento fez operação de rede'
printf 'INSTALAR\n' | aws_atualizar_alsistemas >/dev/null || fail 'execução simulada falhou'
[ "$(cat "$LOG")" = "$(printf 'SSH prepare\nSCP\nSSH install\nSSH cleanup')" ] || fail 'ordem de preparação, envio, instalação e limpeza'
: > "$LOG"
aws_ssh_etapa(){ printf 'SSH %s\n' "$1" >> "$LOG"; if [ "$1" = install ]; then return 1; fi; }
if printf 'INSTALAR\n' | aws_atualizar_alsistemas >/dev/null 2>&1; then fail 'falha de instalação marcada como sucesso'; fi
[ "$(tail -n 1 "$LOG")" = 'SSH cleanup' ] || fail 'sem limpeza após falha'

echo 'OK: configuração privada, validações, consentimento, SCP, fluxo e falhas simuladas.'

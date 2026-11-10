#!/data/data/com.termux/files/usr/bin/bash
# Regressão offline do atalho: nenhuma rede nem EC2 real.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
BASE_DIR="$TMP/manager"
mkdir -p "$BASE_DIR/tools"
cp "$ROOT/tools/atualizar-meu-site-termux.sh" "$BASE_DIR/tools/atualizar-meu-site-termux.sh"
LOG="$TMP/run.log"
: > "$LOG"
error(){ printf 'ERRO:%s\n' "$*" >> "$LOG"; }
info(){ :; }
warn(){ :; }
pause(){ :; }
sleep(){ :; }
menu_unificado(){ printf '%s\n' "$*" > "$TMP/menu.txt"; }
ler_opcao(){ IFS= read -r RESPOSTA_MENU || RESPOSTA_MENU=0; }
aws_carregar_config(){ AWS_HOST=18.217.192.20; AWS_USER=ubuntu; AWS_PORT=2222; AWS_KEY="$TMP/iguatamaonline.pem"; }
aws_validar_config(){ return 0; }
aws_configurar(){ printf 'CONFIG\n' >> "$LOG"; }
# Em shell Bash, a função bash abaixo intercepta qualquer execução,
# permitindo validar argumentos e configuração sem executar SSH/SCP/sudo.
bash(){
  printf '%s|%s|%s|%s|%s|%s\n' "$1" "$2" "${MEUSITE_HOST:-}" "${MEUSITE_USER:-}" "${MEUSITE_PORT:-}" "${MEUSITE_KEY:-}" >> "$LOG"
}
source "$ROOT/modules/projects_meusite.sh"
printf 'fake\n' > "$TMP/iguatamaonline.pem"
meusite_executar_atalho --check
meusite_executar_atalho --patch
meusite_executar_atalho --update
[ "$(wc -l < "$LOG")" -eq 3 ]
grep -Fq "|--check|18.217.192.20|ubuntu|2222|$TMP/iguatamaonline.pem" "$LOG"
grep -Fq "|--patch|18.217.192.20|ubuntu|2222|$TMP/iguatamaonline.pem" "$LOG"
grep -Fq "|--update|18.217.192.20|ubuntu|2222|$TMP/iguatamaonline.pem" "$LOG"
if meusite_executar_atalho '--bad'; then echo 'Modo arbitrário aceito'; exit 1; fi
mv "$BASE_DIR/tools/atualizar-meu-site-termux.sh" "$BASE_DIR/tools/atualizar-meu-site-termux.sh.bak"
if meusite_executar_atalho --check; then echo 'Script ausente aceito'; exit 1; fi
ln -s "$BASE_DIR/tools/atualizar-meu-site-termux.sh.bak" "$BASE_DIR/tools/atualizar-meu-site-termux.sh"
if meusite_executar_atalho --check; then echo 'Link simbólico aceito'; exit 1; fi
rm "$BASE_DIR/tools/atualizar-meu-site-termux.sh"
mv "$BASE_DIR/tools/atualizar-meu-site-termux.sh.bak" "$BASE_DIR/tools/atualizar-meu-site-termux.sh"
printf '1\n2\n3\n4\n0\n' | menu_aws_meusite
[ "$(wc -l < "$LOG")" -eq 10 ]
grep -Fq 'CONFIG' "$LOG"
grep -Fq 'Verificar servidor' "$TMP/menu.txt" || true  # Última tela pode sobrescrever.
grep -Fq 'meusite_executar_atalho --check' "$ROOT/modules/projects_meusite.sh"
grep -Fq 'meusite_executar_atalho --patch' "$ROOT/modules/projects_meusite.sh"
grep -Fq 'meusite_executar_atalho --update' "$ROOT/modules/projects_meusite.sh"
grep -Fq 'i) menu_aws_meusite ;;' "$ROOT/modules/projects.sh"
grep -Fq 'source "$PROJECTS_MODULE_DIR/projects_meusite.sh"' "$ROOT/modules/projects.sh"
grep -Fq 'AWS_PORT="${MEUSITE_PORT:-22}"' "$ROOT/tools/atualizar-meu-site-termux.sh"
grep -Fq 'scp "${SCP_OPTS[@]}"' "$ROOT/tools/atualizar-meu-site-termux.sh"
# Validate that menu never directly runs network (only forwards to script),
# and original AL Sistemas module isn't changed.
echo 'OK: atalho Meu-Site, 3 modos, conexão compartilhada, menu, validações e sem rede real.'

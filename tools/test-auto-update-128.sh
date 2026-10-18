#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
mkdir -p "$HOME" "$TMP/install/.updates" "$TMP/fake"
BASE_DIR="$TMP/install"
FIRST_RUN_FILE="$HOME/.manager_ready"
MANAGER_VERSION=1.0.128
AUTO_UPDATE_ENABLED=true
MANAGER_GITHUB_BRANCH=main
source "$ROOT/modules/updater_auto.sh"
source "$ROOT/modules/updater_core.sh"
source "$ROOT/modules/updater_github.sh"
# Checagem inicial fica desligada sem terminal e, primordialmente, sem wizard.
if auto_update_deve_verificar; then echo 'FAIL: checou sem wizard/TTY'; exit 1; fi
# Estado, intervalo, atomização do registro.
auto_update_marcar_consulta ok
[[ "$(cat "$(auto_update_estado_arquivo)")" =~ ^[0-9]+\|ok$ ]]
[ "$(cat "$(auto_update_estado_arquivo)")" != "" ]
AUTO_UPDATE_ENABLED=false
if auto_update_deve_verificar; then echo 'FAIL: configuracao desligada'; exit 1; fi
AUTO_UPDATE_ENABLED=true
# Substituir somente o gate de TTY para testar conduta offline/conectada.
auto_update_deve_verificar() { return 0; }
consultas=0
avisos=0
consultar_atualizacao_github() { consultas=$((consultas+1)); GITHUB_UPDATE_STATE=same; return 0; }
processar_atualizacao_github_consultada() { avisos=$((avisos+1)); }
verificar_atualizacoes_ao_iniciar >"$TMP/out"
[ "$consultas" -eq 1 ] && [ "$avisos" -eq 0 ]
grep -q '|ok' "$(auto_update_estado_arquivo)"
# Alterações e consentimento usam o handler já consultado, nunca reconsultar.
consultar_atualizacao_github() { consultas=$((consultas+1)); GITHUB_UPDATE_STATE=new; return 0; }
verificar_atualizacoes_ao_iniciar >"$TMP/out"
[ "$consultas" -eq 2 ] && [ "$avisos" -eq 1 ]
# Falhas de consulta não impedem entrada no menu e aplicam recheck mais curto.
consultar_atualizacao_github() { return 28; }
verificar_atualizacoes_ao_iniciar >"$TMP/out"
grep -q '|erro' "$(auto_update_estado_arquivo)"
grep -q 'rede indisponível' "$TMP/out"
# Não deixar a flag da consulta rápida ativa em retorno/erro.
[ "$GITHUB_UPDATE_AUTO_FAST" = false ]
# O estado atual do wizard é verificado na entrada do main antes de chamar a consulta.
python - "$ROOT/modules/app.sh" <<'PY'
import sys
s=open(sys.argv[1]).read()
start=s.index('main() {')
s=s[start:]
assert s.index('pronto_ao_iniciar=false') < s.index('assistente_primeira_execucao')
assert s.index('assistente_primeira_execucao') < s.index('verificar_atualizacoes_ao_iniciar')
assert 'if [ "$pronto_ao_iniciar" = true ]; then' in s
PY
# Persistência, validade da opção e separação de pacotes APT.
grep -q '^AUTO_UPDATE_ENABLED=' "$ROOT/modules/config.sh"
grep -q 'AUTO_UPDATE_ENABLED)' "$ROOT/modules/config.sh"
grep -q 'alternar_config_bool AUTO_UPDATE_ENABLED' "$ROOT/modules/settings.sh"
! grep -Eq 'pkg (upgrade|install)' "$ROOT/modules/updater_auto.sh"
# Intervalo de TTY pela implementação real, sem depender da rede.
cat > "$TMP/tty-check.sh" <<'SH_EOF_128'
#!/usr/bin/env bash
set -eu
BASE_DIR="$1"; FIRST_RUN_FILE="$2"; AUTO_UPDATE_ENABLED=true
source "$3"
touch "$FIRST_RUN_FILE"
# Registro fresco desabilita a nova consulta durante as próximas 24h.
if auto_update_deve_verificar; then exit 10; fi
# Registro antigo deve aceitar novo check.
printf '%s|ok\n' "$(( $(date +%s)-90000 ))" > "$(auto_update_estado_arquivo)"
auto_update_deve_verificar || exit 11
printf '%s|erro\n' "$(( $(date +%s)-60 ))" > "$(auto_update_estado_arquivo)"
if auto_update_deve_verificar; then exit 12; fi
printf '%s|erro\n' "$(( $(date +%s)-22000 ))" > "$(auto_update_estado_arquivo)"
auto_update_deve_verificar || exit 13
# Estado corrompido deve permitir recuperar check.
printf 'invalido' > "$(auto_update_estado_arquivo)"
auto_update_deve_verificar || exit 14
SH_EOF_128
chmod +x "$TMP/tty-check.sh"
if command -v script >/dev/null 2>&1; then
    script -q -e -c "bash '$TMP/tty-check.sh' '$BASE_DIR' '$FIRST_RUN_FILE' '$ROOT/modules/updater_auto.sh'" /dev/null >/dev/null
fi
# Consulta original aceita mock de manifest e changelog via file:// e não baixa changelog sem update.
mkdir -p "$TMP/remote"
printf '{\n  "version": "1.0.129"\n}\n' > "$TMP/remote/MANIFEST.json"
cat > "$TMP/remote/CHANGELOG.md" <<'NOTES_128'
## [1.0.129] - 2026-10-18
- aviso de teste
## [1.0.128] - 2026-10-18
NOTES_128
MANAGER_GITHUB_MANIFEST_URL="file://$TMP/remote/MANIFEST.json"
MANAGER_GITHUB_CHANGELOG_URL="file://$TMP/remote/CHANGELOG.md"
source "$ROOT/modules/updater_github.sh"
GITHUB_UPDATE_INTERACTIVE=false
consultar_atualizacao_github
[ "$GITHUB_UPDATE_STATE" = new ]
printf '%s\n' "$GITHUB_REMOTE_CHANGELOG" | grep -q 'aviso de teste'
printf '{\n  "version": "1.0.128"\n}\n' > "$TMP/remote/MANIFEST.json"
rm "$TMP/remote/CHANGELOG.md"
consultar_atualizacao_github
[ "$GITHUB_UPDATE_STATE" = same ]
[ -z "$GITHUB_REMOTE_CHANGELOG" ]
echo 'OK: startup automático, primeiro assistente, intervalos, offline, opção, consulta real e notas.'

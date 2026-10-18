#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
cleanup() { if [ -n "${LAST_TEST_PID:-}" ]; then kill "$LAST_TEST_PID" 2>/dev/null || true; fi; rm -rf "$TMP"; }
trap cleanup EXIT
export HOME="$TMP/home" PREFIX="$TMP/prefix"
mkdir -p "$HOME" "$PREFIX/var/run" "$TMP/fakebin" "$TMP/source/phpMyAdmin-5.2.3-all-languages/vendor"
printf '%s\n' '<?php echo "phpMyAdmin fixture OK";' > "$TMP/source/phpMyAdmin-5.2.3-all-languages/index.php"
printf '%s\n' '<?php' > "$TMP/source/phpMyAdmin-5.2.3-all-languages/vendor/autoload.php"
( cd "$TMP/source" && zip -qr "$TMP/release.zip" . )
sha256sum "$TMP/release.zip" > "$TMP/release.sha256"
cat > "$TMP/fakebin/curl" <<'CURL'
#!/usr/bin/env bash
# Simula somente downloads oficiais; deixa consultas HTTP ao curl real.
if [[ " $* " == *' --output '* && " $* " == *'files.phpmyadmin.net'* ]]; then
    dest=""
    while (($#)); do
      if [ "$1" = --output ]; then shift; dest="$1"; fi
      shift || true
    done
    if [[ "$dest" == *.sha256 ]]; then cp "$PMA_FAKE_SHA" "$dest"; else cp "$PMA_FAKE_ZIP" "$dest"; fi
    exit 0
fi
exec /usr/local/bin/curl "$@"
CURL
chmod +x "$TMP/fakebin/curl"
export PMA_FAKE_SHA="$TMP/release.sha256" PMA_FAKE_ZIP="$TMP/release.zip"
export PATH="$TMP/fakebin:$PATH"
source "$ROOT/modules/termux_phpmyadmin.sh"
PMA_PORT=18881
cabecalho_tela() { :; }
caixa_simples() { :; }
confirmar_acao() { return 0; }
pause() { :; }
ok() { :; }
error() { printf 'ERROR: %s\n' "$*" >&2; }
caminho_curto() { printf '%s' "$1"; }
# As dependências do PHP para a UI são validadas no celular. O teste local
# substitui apenas esse detector (PHP do runner não possui mysqli e mbstring).
pma_dependencias_php() { return 0; }
# Testa download com SHA inválido: instalação precisa falhar e manter diretório.
printf '%064d\n' 0 > "$TMP/invalid.sha256"
PMA_FAKE_SHA="$TMP/invalid.sha256"
export PMA_FAKE_SHA
if pma_instalar >/dev/null 2>&1; then echo 'FAIL: SHA inválido foi aceito' >&2; exit 1; fi
[ ! -e "$PMA_SITE/index.php" ]
# Instalação válida com preservação de config e SHA.
export PMA_FAKE_SHA="$TMP/release.sha256"
pma_instalar >/dev/null
pma_instalado
[ "$(stat -c '%a' "$PMA_SITE/config.inc.php")" = 600 ]
[ "$(stat -c '%a' "$PMA_ROOT")" = 700 ]
grep -Fq "'auth_type'] = 'cookie'" "$PMA_SITE/config.inc.php"
grep -Fq "'AllowNoPassword'] = false" "$PMA_SITE/config.inc.php"
grep -Fq "$PREFIX/var/run/mysqld.sock" "$PMA_SITE/config.inc.php"
php -l "$PMA_SITE/config.inc.php" >/dev/null
old_hash="$(sha256sum "$PMA_SITE/config.inc.php")"
pma_instalar >/dev/null
[ "$(sha256sum "$PMA_SITE/config.inc.php")" = "$old_hash" ]
# Inicia servidor real, só em loopback e com a pasta dedicada como docroot.
pma_db_ativo() { return 0; }
pma_iniciar_web >/dev/null
pma_web_ativo
LAST_TEST_PID="$(pma_pid_web)"
body="$(/usr/local/bin/curl -fsS --max-time 3 "$(pma_url_local)")"
[ "$body" = "phpMyAdmin fixture OK" ]
! /usr/local/bin/curl -fsS --max-time 1 "http://127.0.0.1:18882/" >/dev/null 2>&1
pma_parar_web >/dev/null || true
sleep 0.3
! pma_web_ativo
# PID não correspondente: nunca matar um processo estranho.
sleep 15 & stranger=$!
printf '%s\n' "$stranger" > "$PMA_ROOT/web.pid"
if pma_pid_web >/dev/null 2>&1; then echo 'FAIL: PID estranho aceito' >&2; exit 1; fi
kill -0 "$stranger" 2>/dev/null
kill "$stranger" 2>/dev/null || true
# Criação de conta é opcional, exige confirmação e não reutiliza senha fixa.
cat > "$TMP/fakebin/mariadb" <<'MDB'
#!/usr/bin/env bash
for x in "$@"; do
    if [ "$x" = '-e' ]; then printf '%s\n' "${MDB_EXISTING:-0}"; exit 0; fi
done
cat > "$MDB_SQL"
MDB
chmod +x "$TMP/fakebin/mariadb"
export MDB_SQL="$TMP/sql.txt" MDB_EXISTING=0
pma_criar_conta > "$TMP/account-result.txt"
grep -Fq "CREATE USER 'termux_pma'@'localhost' IDENTIFIED BY '" "$MDB_SQL"
grep -Eq "IDENTIFIED BY '[a-f0-9]{40}';" "$MDB_SQL"
grep -Fq "GRANT ALL PRIVILEGES ON *.*" "$MDB_SQL"
! grep -Fq 'Senha: ' "$PMA_SITE/config.inc.php"
export MDB_EXISTING=1
rm "$MDB_SQL"
pma_criar_conta > /dev/null
[ ! -e "$MDB_SQL" ]
printf 'PASS: instalação, SHA, config, atualização, HTTP localhost, parada, PID protegido, conta segura\n' 

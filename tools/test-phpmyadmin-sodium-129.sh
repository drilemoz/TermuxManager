#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
cat > "$TMP/bin/php" <<'FAKEPHP'
#!/usr/bin/env bash
if [ "${1:-}" = '-r' ]; then
    case "$2" in
        *'foreach ('*)
            [[ "$2" == *'"mysqli"'* && "$2" == *'"mbstring"'* ]] || exit 1
            [[ "$2" != *'"sodium"'* ]] || { echo 'sodium deveria ser opcional' >&2; exit 1; }
            exit 0;;
        *'extension_loaded("sodium")'*) exit 1;;
        *"extension_loaded('mysqli')"*) exit 0;;
        *"extension_loaded('mbstring')"*) exit 0;;
        *"extension_loaded("*) exit 0;;
        *'PHP_VERSION'*) echo '8.3-test'; exit 0;;
    esac
fi
exit 0
FAKEPHP
cat > "$TMP/bin/mariadb-admin" <<'FAKEDB'
#!/usr/bin/env bash
case " $* " in
    *'--protocol=socket'*) exit 0;;
    *'--protocol=tcp'*) exit 1;;
esac
exit 1
FAKEDB
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/bin/mariadbd"
chmod +x "$TMP/bin/php" "$TMP/bin/mariadb-admin" "$TMP/bin/mariadbd"
export PATH="$TMP/bin:$PATH" PREFIX="$TMP/prefix" HOME="$TMP/home"
source "$ROOT/modules/termux_phpmyadmin.sh"
cabecalho_tela() { :; }
caixa_simples() { printf '%s\n' "$*" >> "$TMP/output"; }
pause() { :; }
caminho_curto() { printf '%s' "$1"; }
pma_instalado() { return 1; }
pma_web_ativo() { return 1; }
pma_dependencias_php  # Sodium ausente não pode bloquear a instalação.
pma_db_ativo
if pma_db_tcp_ativo; then echo 'FAIL: falso TCP ativo' >&2; exit 1; fi
pma_diagnostico
rg -q 'Sodium: ausente \(opcional no phpMyAdmin 5\.2\.3\)' "$TMP/output" || grep -Fq 'Sodium: ausente (opcional no phpMyAdmin 5.2.3)' "$TMP/output"
grep -Fq 'MariaDB (TCP 127.0.0.1:3306): não responde' "$TMP/output"
# Simula MariaDB que responde via socket mas não pelo TCP.
pma_iniciar_db
if ! grep -Fq 'MariaDB ativo apenas por socket' "$TMP/output"; then
  echo 'FAIL: aviso TCP ausente' >&2; exit 1
fi
printf 'PASS: sodium opcional no phpMyAdmin 5.2.3, TCP diferenciado do socket\n'

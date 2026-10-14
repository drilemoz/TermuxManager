#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf -- "$TMP"' EXIT
mkdir -p "$TMP/install/.updates" "$TMP/backup/modules" "$TMP/install/modules"
cp "$ROOT/manager.sh" "$TMP/install/manager.sh"
printf '#!/usr/bin/env bash\necho RESTORED\n' > "$TMP/backup/manager.sh"
printf '# stub original\n' > "$TMP/backup/modules/core.sh"
printf '# código incompleto\n' > "$TMP/install/modules/core.sh"
BK=manager_backup_20261014_100000.tar.gz
(cd "$TMP/backup" && tar -czf "$TMP/install/.updates/$BK" manager.sh modules)
printf '%s\n' "$BK" > "$TMP/install/.updates/.pending-update"
OUTPUT="$(bash "$TMP/install/manager.sh" 2>&1)"
grep -Fq RESTORED <<< "$OUTPUT"
[ ! -e "$TMP/install/.updates/.pending-update" ]
cmp -s "$TMP/backup/modules/core.sh" "$TMP/install/modules/core.sh"
# Um marcador inválido ou backup corrompido NÃO pode executar módulos incompletos.
cp "$ROOT/manager.sh" "$TMP/install/manager.sh"
printf '%s\n' '../../passwd' > "$TMP/install/.updates/.pending-update"
if bash "$TMP/install/manager.sh" > "$TMP/output" 2>&1; then
    echo 'Aceitou marcador malicioso';exit 1
fi
grep -Fq 'marcador de atualização inválido' "$TMP/output"
[ -f "$TMP/install/.updates/.pending-update" ]
# Teste estrutural do journal: escrito antes da substituição e retirado após commit.
python3 - "$ROOT/modules/updater_install.sh" <<'PY'
import sys
s=open(sys.argv[1]).read()
a=s.index('printf \'%s\\n\' "$(basename "$backup")"')
b=s.index('mv "$MODULES_DIR" "$antigos_modulos"',a)
c=s.index('updater_sincronizar_auxiliares "$pacote"',b)
d=s.index('rm -f -- "$journal"',c)
assert a < b < c < d
PY
echo 'OK: reinício recupera atualização incompleta; marcador inválido bloqueado.'

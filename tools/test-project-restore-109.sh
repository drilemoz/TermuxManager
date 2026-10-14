#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/tools/restore_project_backup.py"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
mkdir -p "$TMP/source/demo/src" "$TMP/dest" "$TMP/outside"
printf 'const a = 1;\n' > "$TMP/source/demo/src/app.js"
printf '{"name":"demo"}\n' > "$TMP/source/demo/package.json"
printf '#!/bin/sh\nprintf ok\n' > "$TMP/source/demo/run.sh"
chmod 755 "$TMP/source/demo/run.sh"
(cd "$TMP/source" && tar -czf "$TMP/normal.tar.gz" demo)
INSPECT="$(python3 "$HELPER" inspect "$TMP/normal.tar.gz")"
[[ "$INSPECT" == $'demo\t3\t'* ]] || { echo "Inspeção errada: $INSPECT"; exit 1; }
DEST="$(python3 "$HELPER" restore "$TMP/normal.tar.gz" "$TMP/dest")"
[ "$DEST" = "$TMP/dest/demo" ]
cmp -s "$TMP/source/demo/src/app.js" "$DEST/src/app.js"
[ -x "$DEST/run.sh" ] || { echo "Permissão de execução não foi preservada"; exit 1; }
if python3 "$HELPER" restore "$TMP/normal.tar.gz" "$TMP/dest" >/dev/null 2>&1; then
    echo 'Restaurou por cima de projeto existente'; exit 1
fi
python3 "$HELPER" restore "$TMP/normal.tar.gz" "$TMP/dest" demo2 >/dev/null
[ -f "$TMP/dest/demo2/package.json" ]
# Backups maliciosos: travessia, links, segundo root, entradas duplicadas,
# dispositivo e filename com quebra de linha.
python3 - "$TMP" <<'PY'
import os, pathlib, tarfile, io, sys
p = pathlib.Path(sys.argv[1]); blob=b'conteudo'; modes=['traversal','absolute','symlink','hardlink','otherroot','duplicate','newline','device']
for mode in modes:
    path=p/(mode+'.tar.gz')
    with tarfile.open(path,'w:gz') as t:
        r=tarfile.TarInfo('demo/');r.type=tarfile.DIRTYPE;t.addfile(r)
        first=tarfile.TarInfo('demo/file.txt');first.size=len(blob);t.addfile(first,io.BytesIO(blob))
        f=tarfile.TarInfo('demo/other')
        if mode=='traversal':f.name='demo/../../outside'
        elif mode=='absolute':f.name='/tmp/outside'
        elif mode=='symlink':f.type=tarfile.SYMTYPE;f.linkname='../../outside'
        elif mode=='hardlink':f.type=tarfile.LNKTYPE;f.linkname='demo/file.txt'
        elif mode=='otherroot':f.name='other/file'
        elif mode=='duplicate':f.name='demo/file.txt'
        elif mode=='newline':f.name='demo/a\nxx'
        elif mode=='device':f.type=tarfile.CHRTYPE
        if f.type==tarfile.REGTYPE:f.size=len(blob);t.addfile(f,io.BytesIO(blob))
        else:t.addfile(f)
PY
for mode in traversal absolute symlink hardlink otherroot duplicate newline device; do
    if python3 "$HELPER" inspect "$TMP/$mode.tar.gz" >/dev/null 2>&1; then
        echo "Aceitou backup perigoso: $mode"; exit 1
    fi
    if python3 "$HELPER" restore "$TMP/$mode.tar.gz" "$TMP/dest" attack-$mode >/dev/null 2>&1; then
        echo "Restaurou backup perigoso: $mode"; exit 1
    fi
done
[ ! -f "$TMP/outside" ]
if find "$TMP/dest" -mindepth 1 -maxdepth 1 -name '.manager-restore-*' | grep -q .; then
    echo 'Restou pasta temporária'; exit 1
fi
ln -s "$TMP/dest" "$TMP/linked"
if python3 "$HELPER" restore "$TMP/normal.tar.gz" "$TMP/linked" blocked >/dev/null 2>&1; then
    echo 'Aceitou destino com symlink'; exit 1
fi
# Integração com o menu do projeto.
grep -Fq 'menu_restaurar_backup_projeto' "$ROOT/modules/app.sh"
grep -Fq 'source "$PROJECTS_MODULE_DIR/projects_restore.sh"' "$ROOT/modules/projects.sh"
echo 'OK: restauração segura, conflitos e ataques TAR.GZ bloqueados.'

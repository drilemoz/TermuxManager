#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
import tempfile
s=Path('tools/atualizar-meu-site-termux.sh').read_text().split("<<'PY_REMOTO'\n",1)[1].split('\nPY_REMOTO',1)[0]
ns={'__name__':'test'};exec(compile(s,'remote','exec'),ns)
check=ns['check_schema']; incoming=ns['check_incoming_schema']
def rejects(fn,*args):
 try: fn(*args)
 except RuntimeError: pass
 else: raise AssertionError(args)
with tempfile.TemporaryDirectory() as d:
 p=Path(d);(p/'app').mkdir(); schema=p/'app/schema_migrations.php'
 for current, target in [(37,38),(37,39),(38,39),(39,39),(39,40),(40,41),(39,100),(100,101),(101,10000)]:
  schema.write_text(f'const IGUA_SCHEMA_REVISION = {current};')
  assert check(p,{'schema_revision':target})==(current,target)
  incoming([('app/schema_migrations.php',f'const IGUA_SCHEMA_REVISION = {target}; function igua_migrate_schema($db) {{}}'.encode())],(current,target))
 schema.write_text('const IGUA_SCHEMA_REVISION = 39;')
 for v in (0,-1,38,True,'40',40.5): rejects(check,p,{'schema_revision':v})
 rejects(incoming,[],(39,40))
 rejects(incoming,[('app/schema_migrations.php',b'const IGUA_SCHEMA_REVISION = 39; function igua_migrate_schema($db) {}')],(39,40))
 rejects(incoming,[('app/schema_migrations.php',b'const IGUA_SCHEMA_REVISION = 40;')],(39,40))
print('Schema tests OK: future revisions, downgrade, invalid revisions and missing migrations')
PY

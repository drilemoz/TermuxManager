#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
import tempfile
s=Path('tools/atualizar-meu-site-termux.sh').read_text().split("<<'PY_REMOTO'\n",1)[1].split('\nPY_REMOTO',1)[0]
ns={'__name__':'test'};exec(compile(s,'remote','exec'),ns)
with tempfile.TemporaryDirectory() as d:
 p=Path(d);(p/'app').mkdir();(p/'app/schema_migrations.php').write_text('const IGUA_SCHEMA_REVISION = 37;')
 assert ns['check_schema'](p,{'schema_revision':38})==(37,38)
 assert ns['check_schema'](p,{'schema_revision':37})==(37,37)
 for v in (36,39):
  try: ns['check_schema'](p,{'schema_revision':v})
  except RuntimeError: pass
  else: raise AssertionError(v)
print('Schema tests OK')
PY

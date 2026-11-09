#!/usr/bin/env python3
"""Reproduz validadores Python do script da EC2 sem conectar à AWS."""
import hashlib
import pathlib
import re
import stat
import subprocess
import sys
import tempfile
import zipfile

root = pathlib.Path(__file__).resolve().parents[1]
script = (root / 'tools' / 'alsistemas-aws-remote.sh').read_text()
sections = re.findall(r"python3 - [^\n]+ <<'PY'\n(.*?)\nPY", script, re.DOTALL)
assert len(sections) == 3, f'blocos Python remotos: {len(sections)}'

with tempfile.TemporaryDirectory() as td:
    p = pathlib.Path(td)
    zip_path = p / 'good.zip'
    files = {'VERSION': b'2.0.17\n', 'instalar.sh':b'#!/bin/sh\n',
             'vps/src/server.js': b"const VERSION = '2.0.17'\n",
             'vps/admin/updater.py':b'print("ok")\n'}
    manifest = '\n'.join(hashlib.sha256(data).hexdigest()+'  '+name for name,data in files.items())+'\n'
    files['SHA256SUMS.txt'] = manifest.encode()
    def make_zip(path, contents):
        with zipfile.ZipFile(path, 'w') as z:
            for name,content in contents.items(): z.writestr(name,content)
    make_zip(zip_path,files)
    dest = p / 'good'
    dest.mkdir()
    sub = subprocess.run([sys.executable,'-c',sections[0],str(zip_path),str(dest)],capture_output=True,text=True)
    assert sub.returncode == 0, sub.stderr
    sub = subprocess.run([sys.executable,'-c',sections[1],str(dest)],capture_output=True,text=True)
    assert sub.returncode == 0, sub.stderr
    bad = dict(files)
    bad['vps/src/server.js'] = b'CORRUPT\n'
    tampered = p / 'tampered.zip'; make_zip(tampered,bad)
    out = p/'tampered';out.mkdir()
    sub = subprocess.run([sys.executable,'-c',sections[0],str(tampered),str(out)],capture_output=True,text=True)
    assert sub.returncode == 0
    sub = subprocess.run([sys.executable,'-c',sections[1],str(out)],capture_output=True,text=True)
    assert sub.returncode != 0, 'manifesto alterado aceito'
    traversal = p / 'traversal.zip'
    bad = dict(files);bad['../fora.txt'] = b'x'
    make_zip(traversal,bad)
    sub = subprocess.run([sys.executable,'-c',sections[0],str(traversal),str(p/'outside')],capture_output=True,text=True)
    assert sub.returncode != 0, 'Zip Slip aceito'
    assert not (p / 'fora.txt').exists()
    dangerous = p/'danger.zip'
    bad = dict(files); bad['SHA256SUMS.txt'] = (manifest + hashlib.sha256(b'x').hexdigest()+'  ../../secret\n').encode()
    make_zip(dangerous,bad)
    out = p/'danger';out.mkdir()
    sub = subprocess.run([sys.executable,'-c',sections[0],str(dangerous),str(out)],capture_output=True,text=True)
    assert sub.returncode == 0
    sub = subprocess.run([sys.executable,'-c',sections[1],str(out)],capture_output=True,text=True)
    assert sub.returncode != 0, 'manifesto com traversal aceito'
    # O pacote AL Sistemas v2.0.17 real também precisa passar na inspeção.
    actual=pathlib.Path('/mnt/data/AL-Sistemas-v2.0.17-VPS.zip')
    if actual.exists():
        out=p/'actual';out.mkdir()
        sub=subprocess.run([sys.executable,'-c',sections[0],str(actual),str(out)],capture_output=True,text=True)
        assert sub.returncode == 0, sub.stderr
        sub=subprocess.run([sys.executable,'-c',sections[1],str(out)],capture_output=True,text=True)
        assert sub.returncode == 0, sub.stderr
print('OK: extração segura, manifesto completo, recusa ZIP travessia e hash corrompido.')

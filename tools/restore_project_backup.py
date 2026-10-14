#!/usr/bin/env python3
"""Restore local Manager project backups without trusting TAR entry paths.

Python 3 is needed only for this optional recovery action. Never extract links,
absolute/traversal paths, special files, or entries with ambiguous names.
"""

import os
import re
import shutil
import sys
import tarfile
import tempfile
from pathlib import Path

MAX_FILES = 100_000
MAX_TOTAL_BYTES = 10 * 1024**3
MAX_SINGLE_BYTES = 4 * 1024**3
SAFE_ROOT = re.compile(r"^[^\x00-\x1f\x7f/\\]+$")


class UnsafeBackup(Exception):
    pass


def valid_component(value):
    return bool(value and value not in (".", "..") and SAFE_ROOT.fullmatch(value))


def scan(archive):
    seen = set()
    root = None
    count = 0
    size = 0
    with tarfile.open(archive, mode="r:gz") as tf:
        for item in tf:
            raw = item.name
            parts = raw.rstrip("/").split("/")
            if (not raw or raw.startswith("/") or "\\" in raw or
                    any(not valid_component(part) for part in parts)):
                raise UnsafeBackup("Caminho inseguro no TAR.GZ")
            if not (item.isfile() or item.isdir()):
                raise UnsafeBackup("Links, dispositivos e tipos especiais não são aceitos")
            norm = "/".join(parts)
            if norm in seen:
                raise UnsafeBackup("Entradas duplicadas no backup")
            seen.add(norm)
            if root is None:
                root = parts[0]
            if parts[0] != root:
                raise UnsafeBackup("O backup contém mais de uma pasta raiz")
            if len(parts) == 1 and not item.isdir():
                raise UnsafeBackup("O backup deve conter uma pasta raiz")
            if item.isfile():
                count += 1
                if item.size < 0 or item.size > MAX_SINGLE_BYTES:
                    raise UnsafeBackup("Arquivo excede o limite seguro")
                size += item.size
            if len(seen) > MAX_FILES or size > MAX_TOTAL_BYTES:
                raise UnsafeBackup("Backup excede os limites seguros de restauração")
        if not root or count < 1:
            raise UnsafeBackup("Backup vazio ou sem arquivos regulares")
    return root, count, size


def restore(archive, destination, name=None):
    root, files, size = scan(archive)
    base = Path(destination)
    if not base.is_dir() or base.is_symlink():
        raise UnsafeBackup("Pasta de destino ausente ou contém link simbólico")
    name = name or root
    if not valid_component(name):
        raise UnsafeBackup("Nome inválido para a pasta restaurada")
    # Avoid modifying any existing project, including dangling symlinks.
    target = base / name
    if os.path.lexists(target):
        raise UnsafeBackup("Já existe um projeto com esse nome. Escolha outro nome.")
    free = shutil.disk_usage(base).free
    needed = size + max(16 * 1024**2, size // 5)
    if free < needed:
        raise UnsafeBackup(f"Espaço insuficiente: {needed} bytes necessários; {free} disponíveis")

    # Stage on the same filesystem, then rename atomically to final destination.
    staging = Path(tempfile.mkdtemp(prefix=".manager-restore-", dir=base))
    try:
        extracted = staging / root
        with tarfile.open(archive, mode="r:gz") as tf:
            for member in tf:
                pieces = member.name.rstrip("/").split("/")
                # scan() validated every entry. Recheck types to fail closed.
                if not (member.isdir() or member.isfile()):
                    raise UnsafeBackup("Tipo inseguro detectado durante a extração")
                out = staging.joinpath(*pieces)
                if member.isdir():
                    out.mkdir(parents=True, exist_ok=True)
                else:
                    out.parent.mkdir(parents=True, exist_ok=True)
                    source = tf.extractfile(member)
                    if source is None:
                        raise UnsafeBackup("Não foi possível ler um arquivo do backup")
                    with source, open(out, "xb") as output:
                        remaining = member.size
                        while remaining:
                            chunk = source.read(min(1024 * 1024, remaining))
                            if not chunk:
                                raise UnsafeBackup("Backup truncado durante a extração")
                            output.write(chunk)
                            remaining -= len(chunk)
                    # Preserve the ability to run scripts, but never restore
                    # owner/group access or privileged setuid/setgid bits.
                    out.chmod(0o600 | (member.mode & 0o111))
        if not extracted.is_dir():
            raise UnsafeBackup("Pasta raiz não encontrada após extração")
        if os.path.lexists(target):
            raise UnsafeBackup("Projeto foi criado por outro processo; restauração cancelada")
        # Protect against a concurrent creator replacing the target by using
        # a hard-link-free rename and refusing an already occupied target.
        os.rename(extracted, target)
        return str(target)
    finally:
        shutil.rmtree(staging, ignore_errors=True)


def main(args):
    if len(args) not in (2, 3, 4) or args[0] not in ("inspect", "restore"):
        raise UnsafeBackup("Uso: restore_project_backup.py inspect ARQUIVO | restore ARQUIVO DESTINO [NOME]")
    action, archive = args[:2]
    if not Path(archive).is_file():
        raise UnsafeBackup("Arquivo de backup não encontrado")
    if action == "inspect":
        if len(args) != 2:
            raise UnsafeBackup("Parâmetros inválidos")
        name, count, size = scan(archive)
        print(f"{name}\t{count}\t{size}")
    else:
        if len(args) not in (3, 4):
            raise UnsafeBackup("Informe a pasta de destino")
        print(restore(archive, args[2], args[3] if len(args) == 4 else None))


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (UnsafeBackup, OSError, tarfile.TarError, EOFError, ValueError) as exc:
        print(f"Restauração recusada: {exc}", file=sys.stderr)
        sys.exit(1)

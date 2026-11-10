#!/data/data/com.termux/files/usr/bin/bash
# IguatamaOnline / Meu-Site: implantação manual segura via SSH na AWS EC2.
# Adaptado do fluxo do AL Sistemas, mas SEM alterar o AL Sistemas.
# Modos: --check (padrão), --patch (corrige app/updater.php), --update (release completa).
# Repositório de origem fixo: drilemoz/Meu-Site; destino padrão: /var/www/projetos/iguatamaonline.
set -Eeuo pipefail
umask 077

REPO='drilemoz/Meu-Site'
AWS_HOST="${MEUSITE_HOST:-18.217.192.20}"
AWS_USER="${MEUSITE_USER:-ubuntu}"
AWS_PORT="${MEUSITE_PORT:-22}"
SSH_KEY="${MEUSITE_KEY:-$HOME/.ssh/iguatamaonline.pem}"
SITE="${MEUSITE_SITE:-/var/www/projetos/iguatamaonline}"
DOWNLOADS="${MEUSITE_DOWNLOADS:-$HOME/storage/downloads}"
WORK="$HOME/.cache/meu-site-termux"
MODE='check'
PATCH_NAME='Patch-Inicial-Atualizador-v1.0.144-FTP-ou-SSH.zip'

usage() {
  cat <<'HELP'
Atualizador Meu-Site / IguatamaOnline para Termux + AWS EC2
  bash atualizar-meu-site-termux.sh --check   Inspeciona produção sem alterá-la (padrão)
  bash atualizar-meu-site-termux.sh --patch   Substitui somente app/updater.php com backup
  bash atualizar-meu-site-termux.sh --update  Instala a release mais recente (Downloads ou GitHub)

Arquivos aceitos em Downloads:
  Patch-Inicial-Atualizador-v1.0.144-FTP-ou-SSH.zip
  Atualizacao-Meu-Site-vX.Y.Z.zip (gerado localmente)
  Atualizacao-vX.Y.Z.zip (asset oficial das Releases)

Variáveis opcionais: MEUSITE_HOST, MEUSITE_USER, MEUSITE_KEY, MEUSITE_SITE,
MEUSITE_DOWNLOADS, MEUSITE_PORT. Exige sudo -n na EC2. Não altera serviços AL Sistemas.
Nunca rode --update sem backup externo prévio de MariaDB, storage e uploads.
HELP
}
if (( $# > 1 )); then usage; exit 2; fi
case "${1:---check}" in
  --check) MODE=check ;;
  --patch) MODE=patch ;;
  --update) MODE=update ;;
  --help|-h) usage; exit 0 ;;
  *) usage; exit 2 ;;
esac

mkdir -p "$WORK"
LOG="$WORK/execucao-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1
msg() { printf '\n[Meu-Site Termux] %s\n' "$*"; }
fail() { msg "ERRO: $*"; msg "Log: $LOG"; exit 1; }
trap 'rc=$?; if ((rc != 0)); then printf "\n[Meu-Site Termux] Falha (%d). Log: %s\n" "$rc" "$LOG"; fi' EXIT

[[ "$AWS_HOST" =~ ^[a-zA-Z0-9.-]+$ ]] || fail 'Host SSH inválido.'
[[ "$AWS_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] || fail 'Usuário SSH inválido.'
[[ "$AWS_PORT" =~ ^[0-9]{1,5}$ ]] && (( 10#$AWS_PORT >= 1 && 10#$AWS_PORT <= 65535 )) || fail 'Porta SSH inválida.'
[[ "$SITE" =~ ^/var/www/[a-zA-Z0-9/_-]+$ ]] || fail 'Caminho do site fora de /var/www.'
[[ "$SITE" != *'/iguatama-teste'* && "$SITE" != *'/../'* ]] || fail 'Pasta de testes ou traversal não permitidos.'
[[ "$SITE" == '/var/www/projetos/iguatamaonline' ]] || {
  msg "ATENÇÃO: destino personalizado: $SITE"
  msg 'Confira --check antes de executar um modo de escrita.'
}
[[ -f "$SSH_KEY" ]] || fail "Chave SSH não encontrada: $SSH_KEY"
chmod 600 "$SSH_KEY" || fail 'Falha ao proteger chave SSH.'
if [[ ! -d "$DOWNLOADS" && -d /sdcard/Download ]]; then DOWNLOADS=/sdcard/Download; fi
if [[ "$MODE" != check ]]; then
  [[ -d "$DOWNLOADS" ]] || fail 'Downloads indisponível. Execute termux-setup-storage.'
fi
missing=()
for cmd in ssh scp curl jq sha256sum sort tee; do
  command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done
if ((${#missing[@]})); then
  command -v pkg >/dev/null 2>&1 || fail "Comandos não encontrados: ${missing[*]}"
  pkg install -y openssh curl jq coreutils || fail 'Falha ao preparar Termux.'
fi

version_valid() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; }
version_greater() {
  [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)" == "$1" ]]
}
REMOTE="$AWS_USER@$AWS_HOST"
SSH_OPTS=(-i "$SSH_KEY" -p "$AWS_PORT" -o BatchMode=yes -o ConnectTimeout=15 \
  -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=yes)
SCP_OPTS=(-i "$SSH_KEY" -P "$AWS_PORT" -o BatchMode=yes -o ConnectTimeout=15 \
  -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=yes)
REMOTE_DIR="/home/$AWS_USER/.cache/meu-site-termux"
REMOTE_SCRIPT="$REMOTE_DIR/deploy-iguatama.py"
SELECTED_ZIP=''
SELECTED_VERSION=''

if [[ "$MODE" == patch ]]; then
  SELECTED_ZIP="$DOWNLOADS/$PATCH_NAME"
  [[ -f "$SELECTED_ZIP" ]] || fail "Baixe $PATCH_NAME para Downloads."
  SELECTED_VERSION='1.0.144'
elif [[ "$MODE" == update ]]; then
  LOCAL_VERSION=''
  LOCAL_ZIP=''
  for candidate in "$DOWNLOADS"/Atualizacao-v*.zip "$DOWNLOADS"/Atualizacao-Meu-Site-v*.zip; do
    [[ -f "$candidate" ]] || continue
    name="${candidate##*/}"
    if [[ "$name" =~ ^Atualizacao(-Meu-Site)?-v([0-9]+\.[0-9]+\.[0-9]+)\.zip$ ]]; then
      v="${BASH_REMATCH[2]}"
      if [[ -z "$LOCAL_VERSION" ]] || version_greater "$v" "$LOCAL_VERSION"; then
        LOCAL_VERSION="$v"; LOCAL_ZIP="$candidate"
      fi
    fi
  done
  [[ -z "$LOCAL_VERSION" ]] || msg "Pacote local encontrado: $LOCAL_VERSION"
  GITHUB_VERSION=''
  GITHUB_ZIP=''
  msg 'Consultando a última Release oficial de drilemoz/Meu-Site...'
  RELEASE_JSON="$WORK/release.json"
  if curl -fLsS --max-time 25 -H 'Accept: application/vnd.github+json' \
    -H 'User-Agent: Meu-Site-Termux-SSH/1.0' \
    "https://api.github.com/repos/$REPO/releases/latest" -o "$RELEASE_JSON"; then
    tag="$(jq -r '.tag_name // empty' "$RELEASE_JSON" 2>/dev/null || true)"
    tag="${tag#v}"
    if version_valid "$tag"; then
      asset="Atualizacao-v${tag}.zip"
      # Dados da Release são usados apenas para localizar um asset do repositório fixo.
      asset_url="$(jq -r --arg n "$asset" '.assets[]? | select(.name==$n) | .browser_download_url // empty' "$RELEASE_JSON" | head -n 1)"
      asset_digest="$(jq -r --arg n "$asset" '.assets[]? | select(.name==$n) | .digest // empty' "$RELEASE_JSON" | head -n 1)"
      expected_url="https://github.com/$REPO/releases/download/v${tag}/${asset}"
      if [[ "$asset_url" == "$expected_url" && "$asset_digest" =~ ^sha256:([a-f0-9]{64})$ ]]; then
        if [[ -z "$LOCAL_VERSION" ]] || version_greater "$tag" "$LOCAL_VERSION"; then
          GITHUB_ZIP="$WORK/$asset"
          msg "Baixando release v$tag..."
          if curl -fL --proto '=https' --tlsv1.2 -sS --max-time 180 \
            "$asset_url" -o "$GITHUB_ZIP"; then
            actual="$(sha256sum "$GITHUB_ZIP" | cut -d' ' -f1)"
            if [[ "sha256:$actual" == "$asset_digest" ]]; then
              GITHUB_VERSION="$tag"
              msg "SHA-256 oficial da Release v$tag confirmado."
            else
              msg 'SHA-256 da release inválido. Download ignorado.'
              GITHUB_ZIP=''
            fi
          else
            msg 'Não foi possível baixar a release. Tentando pacote local.'
            GITHUB_ZIP=''
          fi
        fi
      else
        msg 'Asset ZIP ou SHA-256 oficial ausente/inválido. Não aceitar download sem digest.'
      fi
    else
      msg 'Tag de release ausente ou inválida.'
    fi
  else
    msg 'Consulta GitHub falhou. Tentando pacote local.'
  fi
  SELECTED_ZIP="$LOCAL_ZIP"; SELECTED_VERSION="$LOCAL_VERSION"
  if [[ -n "$GITHUB_VERSION" ]]; then
    SELECTED_ZIP="$GITHUB_ZIP"; SELECTED_VERSION="$GITHUB_VERSION"
  fi
  [[ -n "$SELECTED_ZIP" && -f "$SELECTED_ZIP" ]] || fail \
    'Nenhum ZIP de atualização válido em Downloads ou Release oficial.'
fi

SHA=''
REMOTE_ZIP=''
if [[ "$MODE" != check ]]; then
  bytes="$(wc -c < "$SELECTED_ZIP")"
  (( bytes >= 512 && bytes <= 33554432 )) || fail 'ZIP fora do intervalo de 512 bytes a 32 MiB.'
  SHA="$(sha256sum "$SELECTED_ZIP" | cut -d' ' -f1)"
  if [[ "$MODE" == patch ]]; then
    REMOTE_ZIP="$REMOTE_DIR/$PATCH_NAME"
  else
    REMOTE_ZIP="$REMOTE_DIR/Atualizacao-v${SELECTED_VERSION}.zip"
  fi
  msg "Selecionado: ${SELECTED_ZIP##*/} | SHA-256: $SHA"
fi

# Script Python remoto embarcado: permite usar somente um arquivo .sh no Termux.
cat > "$WORK/deploy-iguatama.py" <<'PY_REMOTO'
#!/usr/bin/env python3
"""Implantação manual e auditável do IguatamaOnline, sem alterar AL Sistemas."""
import fcntl
from contextlib import ExitStack
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import zipfile
from datetime import datetime, timezone

RE_VERSION = re.compile(r'^\d+\.\d+\.\d+$')
MAX_ZIP = 32 * 1024 * 1024
MAX_COUNT = 1200
MAX_UNCOMPRESSED = 120 * 1024 * 1024
SAFE_PREFIXES = ('app/', 'public/')
# Arquivos personalizados por hospedagem não devem ser alterados pelo shell.
PRESERVE = {'public/robots.txt', 'public/ads.txt'}
STATE_FILES = (
    'storage/.update-maintenance',
    'storage/updater/vps/private/maintenance',
    'storage/updater/vps/request.json',
    'storage/updater/vps/running.json',
)


def say(msg):
    print('[Meu-Site EC2] ' + str(msg), flush=True)


def die(msg):
    raise RuntimeError(str(msg))


def file_sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def version_tuple(v):
    if not isinstance(v, str) or not RE_VERSION.fullmatch(v):
        die('Versão inválida: ' + repr(v))
    return tuple(map(int, v.split('.')))


def under_tree_without_links(root, rel):
    base = root.resolve(strict=True)
    target = root
    for part in PurePosixPath(rel).parts:
        if part in ('', '.', '..'):
            die('Parte de caminho inválida: ' + rel)
        target = target / part
        if target.is_symlink():
            die('Link simbólico no caminho: ' + str(target))
    if not target.resolve(strict=False).is_relative_to(base):
        die('Arquivo escapou do projeto: ' + rel)
    return target


def site_preflight(site, mode):
    if not site.is_absolute() or '..' in site.parts or site.is_symlink():
        die('Caminho do site inválido/link simbólico')
    if not str(site).startswith('/var/www/') or str(site).startswith('/var/www/iguatama-teste'):
        die('Recusado: pasta fora de /var/www ou instalação de testes')
    if '/iguatama-teste/' in str(site):
        die('A instalação de testes é protegida')
    if site.resolve(strict=False) != site:
        die('Projeto usa symlink ou caminho não canônico')
    for rel in ('VERSION', 'app', 'public', 'storage', 'storage/config.php', 'public/admin.php', 'app/updater.php'):
        p = under_tree_without_links(site, rel)
        if not p.exists():
            die('Instalação de produção incompleta: ' + str(p))
    if not (site / 'VERSION').is_file():
        die('VERSION não é arquivo regular')
    version = (site / 'VERSION').read_text(encoding='utf-8').strip()
    version_tuple(version)
    say('Produção: {} | versão instalada: {}'.format(site, version))
    if mode != 'check':
        if os.geteuid() != 0:
            die('Aplicação do patch/release exige sudo na EC2')
        for rel in STATE_FILES:
            p = under_tree_without_links(site, rel)
            if p.exists() or p.is_symlink():
                die('Atualização ativa ou interrompida: {}. Investigue antes de repetir.'.format(p))
        proc = subprocess.run(['systemctl', 'is-active', '--quiet', 'iguatama-deploy.service'], check=False)
        if proc.returncode == 0:
            die('Serviço iguatama-deploy.service está ativo; operação simultânea bloqueada')
        if (site / 'storage/updater/vps/private/.code.lock').is_symlink():
            die('Lock de atualização inseguro')
    return version


def inspect_zip(path, sha_expected, mode, expected_version):
    if path.is_symlink() or not path.is_file():
        die('Pacote ZIP ausente ou inseguro')
    if not (512 <= path.stat().st_size <= MAX_ZIP):
        die('ZIP excedeu limite de 32 MiB')
    if not re.fullmatch('[a-f0-9]{64}', sha_expected) or file_sha(path) != sha_expected:
        die('SHA-256 após SCP divergente')
    if not zipfile.is_zipfile(path):
        die('Pacote não é um ZIP válido')
    with zipfile.ZipFile(path) as z:
        infos = z.infolist()
        if len(infos) > MAX_COUNT:
            die('ZIP contém entradas demais')
        seen, total = set(), 0
        for info in infos:
            n = info.filename
            if not n or n.startswith('/') or '\\' in n or '\x00' in n or ':' in n:
                die('Entrada de ZIP insegura')
            parts = n.rstrip('/').split('/')
            if any(part in ('', '.', '..') for part in parts):
                die('Traversal/caminho inválido no ZIP: ' + n)
            if n in seen:
                die('Arquivo duplicado no ZIP: ' + n)
            seen.add(n)
            kind = (info.external_attr >> 16) & 0o170000
            if kind not in (0, stat.S_IFREG, stat.S_IFDIR):
                die('Link ou arquivo especial no ZIP')
            if info.file_size < 0:
                die('Tamanho negativo em entrada')
            total += info.file_size
            if total > MAX_UNCOMPRESSED:
                die('ZIP descompactado excede 120 MiB')
        failed = z.testzip()
        if failed:
            die('CRC inválido: ' + failed)
        if mode == 'patch':
            if set(x for x in seen if not x.endswith('/')) != {'app/updater.php', 'LEIA-ME.txt'}:
                die('Patch não possui a estrutura esperada')
            if z.getinfo('app/updater.php').file_size < 2000:
                die('app/updater.php inesperadamente pequeno')
            return [('app/updater.php', z.read('app/updater.php'))], None
        if 'release.json' not in seen or 'VERSION' not in seen:
            die('ZIP sem manifesto release.json ou VERSION')
        meta = json.loads(z.read('release.json'))
        if not isinstance(meta, dict) or meta.get('format') != 'meu-site-update-v2':
            die('Formato de release incompatível')
        if meta.get('version') != expected_version or z.read('VERSION').decode('utf-8').strip() != expected_version:
            die('Versão do ZIP/manifesto diverge do nome')
        if not isinstance(meta.get('schema_revision'), int) or isinstance(meta['schema_revision'], bool):
            die('schema_revision inválido')
        if not isinstance(meta.get('files'), list) or not meta['files']:
            die('Manifesto sem lista de arquivos')
        declared, files = set(), []
        for f in meta['files']:
            if not isinstance(f, dict):
                die('Entrada de manifesto inválida')
            rel, digest, size = f.get('path'), f.get('sha256'), f.get('size')
            if not isinstance(rel, str) or (not rel.startswith(SAFE_PREFIXES) and rel != 'VERSION'):
                die('Caminho não permitido no manifesto: ' + repr(rel))
            if rel in declared or rel not in seen:
                die('Duplicado/ausente no ZIP: ' + rel)
            if not isinstance(size, int) or isinstance(size, bool) or size < 0:
                die('Tamanho inválido no manifesto: ' + rel)
            if not isinstance(digest, str) or not re.fullmatch(r'[a-f0-9]{64}', digest):
                die('Hash inválido no manifesto: ' + rel)
            data = z.read(rel)
            if len(data) != size or hashlib.sha256(data).hexdigest() != digest:
                die('Hash/tamanho divergente no manifesto: ' + rel)
            declared.add(rel)
            if rel not in PRESERVE and rel != 'VERSION':
                files.append((rel, data))
        actual = {n for n in seen if not n.endswith('/') and n != 'release.json'}
        if declared != actual:
            die('Arquivos do ZIP não conferem com o manifesto')
        files.append(('VERSION', z.read('VERSION')))
        return files, meta


def check_schema(site, meta):
    migrations = site / 'app/schema_migrations.php'
    if migrations.is_symlink() or not migrations.is_file():
        die('schema_migrations.php ausente/inseguro')
    m = re.search(r'const\s+IGUA_SCHEMA_REVISION\s*=\s*(\d+)\s*;', migrations.read_text('utf-8'))
    if not m:
        die('Não foi possível identificar revisão de schema instalada')
    current = int(m.group(1))
    if meta['schema_revision'] != current:
        die('Schema {} -> {}: atualização manual recusada; use processo oficial com migrações/backup.'.format(current, meta['schema_revision']))
    say('Revisão de schema preservada: {}'.format(current))


def php_lint(files):
    php = shutil.which('php8.3') or shutil.which('php')
    if not php:
        die('PHP CLI não encontrado na EC2')
    total = 0
    with tempfile.TemporaryDirectory(prefix='igua-lint-') as d:
        for name, data in files:
            if not name.endswith('.php'):
                continue
            temp = Path(d) / ('t-%04d.php' % total)
            temp.write_bytes(data)
            p = subprocess.run([php, '-l', str(temp)], capture_output=True, text=True, timeout=20)
            if p.returncode:
                die('PHP inválido em {}: {}'.format(name, (p.stdout + p.stderr).strip()[:700]))
            total += 1
    say('{} arquivos PHP passaram no teste de sintaxe.'.format(total))


def atomic_write(target, data, previous_stat=None):
    # O arquivo temporário fica no mesmo diretório para rename atômico.
    fd, temp = tempfile.mkstemp(prefix='.igua-manual-', dir=str(target.parent))
    try:
        with os.fdopen(fd, 'wb') as out:
            out.write(data)
            out.flush()
            os.fsync(out.fileno())
            if previous_stat is not None:
                os.fchown(out.fileno(), previous_stat.st_uid, previous_stat.st_gid)
                os.fchmod(out.fileno(), stat.S_IMODE(previous_stat.st_mode))
            else:
                parent = target.parent.stat()
                os.fchown(out.fileno(), parent.st_uid, parent.st_gid)
                os.fchmod(out.fileno(), 0o644)
        os.replace(temp, target)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def update_files(site, files, installed, incoming, mode):
    root_backup = Path('/var/backups/iguatamaonline-manual')
    if root_backup.is_symlink():
        die('Diretório de backups é link simbólico')
    root_backup.mkdir(mode=0o700, parents=True, exist_ok=True)
    root_backup.chmod(0o700)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    backup = root_backup / ('{}-{}-para-{}-{}'.format(mode, installed, incoming, stamp))
    backup.mkdir(mode=0o700)
    backup_files = backup / 'original'
    backup_files.mkdir(mode=0o700)
    existed, original_stats, replaced = {}, {}, []
    say('Criando backup ANTES de modificar o código: ' + str(backup))
    for rel, data in files:
        target = under_tree_without_links(site, rel)
        if not target.parent.is_dir():
            die('Diretório destino ausente: ' + str(target.parent))
        if target.exists() and not target.is_file():
            die('Destino não é arquivo regular: ' + str(target))
        if not target.exists():
            existed[rel] = False
        else:
            existed[rel] = True
            original_stats[rel] = target.stat()
            old = backup_files / rel
            old.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            shutil.copy2(target, old)
    backup_meta = {k: ({'existed': existed[k], 'uid': original_stats[k].st_uid,
                 'gid': original_stats[k].st_gid, 'mode': stat.S_IMODE(original_stats[k].st_mode)}
                 if existed[k] else {'existed': False}) for k in existed}
    (backup / 'metadata.json').write_text(json.dumps({'mode': mode, 'old_version': installed,
        'new_version': incoming, 'files': backup_meta}, indent=2), encoding='utf-8')
    try:
        for rel, data in files:
            target = under_tree_without_links(site, rel)
            old_stat = target.stat() if existed[rel] else None
            atomic_write(target, data, old_stat)
            replaced.append(rel)
        say('SUCESSO: {} arquivos substituídos. Backup: {}'.format(len(replaced), backup))
    except Exception:
        say('Erro após {} substituições. Tentando rollback do código...'.format(len(replaced)))
        for rel in reversed(replaced):
            try:
                target = under_tree_without_links(site, rel)
                if existed[rel]:
                    old = backup_files / rel
                    atomic_write(target, old.read_bytes(), original_stats[rel])
                else:
                    target.unlink(missing_ok=True)
            except Exception as exc:
                say('ATENÇÃO: rollback falhou para {}: {}'.format(rel, exc))
        say('Se necessário, restaure manualmente pelo backup: ' + str(backup))
        raise


def deploy_with_lock(site, files, installed, incoming, mode):
    # Respeitar também o flock usado pelo atualizador PHP nativo, se existir.
    with ExitStack() as stack:
        for rel in ('storage/updater/vps/private/.code.lock', 'storage/updater/.lock'):
            lockfile = under_tree_without_links(site, rel)
            if not lockfile.exists():
                continue
            if not lockfile.is_file() or lockfile.is_symlink():
                die('Lock inválido: ' + str(lockfile))
            fd = stack.enter_context(open(lockfile, 'r+b'))
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                die('Lock de atualização em uso: ' + str(lockfile))
        # Conferir os marcadores novamente sob lock contra corrida com worker.
        for rel in STATE_FILES:
            p = under_tree_without_links(site, rel)
            if p.exists() or p.is_symlink():
                die('Atualização concorrente/interrompida: ' + str(p))
        if subprocess.run(['systemctl', 'is-active', '--quiet', 'iguatama-deploy.service'],
                          check=False).returncode == 0:
            die('Worker ativo durante a obtenção do lock')
        update_files(site, files, installed, incoming, mode)


def main():
    if len(sys.argv) != 6:
        die('Uso: remoto.py check|patch|update SITE ZIP SHA256 VERSAO')
    mode, site_arg, zip_arg, sha, incoming = sys.argv[1:]
    if mode not in ('check', 'patch', 'update'):
        die('Modo inválido')
    site = Path(site_arg)
    installed = site_preflight(site, mode)
    if mode == 'check':
        print('[Meu-Site EC2] Conta do projeto:', site.stat().st_uid, 'grupo:', site.stat().st_gid)
        for rel in ('VERSION', 'app', 'app/updater.php', 'public', 'public/admin.php', 'storage'):
            p = site / rel
            s = p.stat()
            print('[Meu-Site EC2] {} {:o} UID={} GID={}'.format(rel, stat.S_IMODE(s.st_mode), s.st_uid, s.st_gid))
        for rel in STATE_FILES:
            p = site / rel
            if p.exists() or p.is_symlink():
                say('ALERTA: estado de atualização presente: ' + str(p))
        say('Modo consulta: nenhum arquivo da produção foi alterado.')
        return
    if not incoming or not RE_VERSION.fullmatch(incoming):
        die('Versão do pacote inválida')
    if mode == 'patch' and (version_tuple(installed) < (1, 0, 143) or version_tuple(installed) > (1, 0, 144)):
        die('Patch v1.0.144 foi preparado apenas para instalação 1.0.143/1.0.144; instalada: ' + installed)
    if mode == 'update' and version_tuple(incoming) <= version_tuple(installed):
        say('Nenhuma alteração: instalada {} >= pacote {}.'.format(installed, incoming))
        return
    files, meta = inspect_zip(Path(zip_arg), sha, mode, incoming)
    if mode == 'update':
        check_schema(site, meta)
    php_lint(files)
    deploy_with_lock(site, files, installed, incoming, mode)
    if mode == 'patch':
        say('Patch instalado. Abra Atualizações > Vistoria do servidor no painel.')
    else:
        say('Código publicado. Confirme o painel e a versão. Banco, storage e uploads não foram modificados.')


if __name__ == '__main__':
    try:
        if len(sys.argv) < 2:
            die('Modo obrigatório')
        if sys.argv[1] == 'check':
            main()
        else:
            lock_path = Path('/var/lock/iguatama-manual-deploy.lock')
            with open(lock_path, 'a+b') as stream:
                fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
                main()
    except Exception as exc:
        say('{}: {}'.format(type(exc).__name__, exc))
        sys.exit(1)
PY_REMOTO

msg 'Conectando por SSH (host conhecido obrigatório)...'
ssh "${SSH_OPTS[@]}" "$REMOTE" "umask 077; mkdir -p '$REMOTE_DIR' && chmod 700 '$REMOTE_DIR'" || \
  fail 'SSH falhou. Verifique chave, host e known_hosts.'
scp "${SCP_OPTS[@]}" "$WORK/deploy-iguatama.py" "$REMOTE:$REMOTE_SCRIPT" || \
  fail 'Não foi possível enviar o auxiliar de implantação.'
if [[ "$MODE" != check ]]; then
  scp "${SCP_OPTS[@]}" "$SELECTED_ZIP" "$REMOTE:$REMOTE_ZIP" || \
    fail 'Não foi possível enviar ZIP por SCP.'
  if [[ "$MODE" == update ]]; then
    msg 'IMPORTANTE: este shell cria backup do CÓDIGO, mas NÃO salva MariaDB, storage nem uploads.'
    msg 'Antes de prosseguir, tenha cópia externa comprovada desses dados e/ou snapshot EBS.'
    printf 'Confirma que esses backups já foram verificados? Digite BACKUP-CONFIRMADO: '
    read -r ack
    [[ "$ack" == BACKUP-CONFIRMADO ]] || fail 'Sem confirmação de backup externo; cancelado.'
  else
    msg 'Patch de um arquivo com cópia automática do updater.php anterior.'
    printf 'Digite APLICAR para continuar: '
    read -r ack
    [[ "$ack" == APLICAR ]] || fail 'Cancelado pelo usuário.'
  fi
fi
msg "Inspecionando $SITE..."
status=0
ssh "${SSH_OPTS[@]}" "$REMOTE" \
  "sudo -n /usr/bin/python3 '$REMOTE_SCRIPT' '$MODE' '$SITE' '$REMOTE_ZIP' '$SHA' '$SELECTED_VERSION'" || status=$?
msg "Log Termux: $LOG"
if (( status != 0 )); then
  fail 'Operação remota falhou. Não repita antes de conferir o erro.'
fi
msg "Concluído ($MODE). O AL Sistemas e o site de testes não foram alvo desta operação."

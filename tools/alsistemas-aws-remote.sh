#!/usr/bin/env bash
# Executado NA EC2 pelo Termux Manager. Nunca recebe senhas ou chaves privadas.
set -Eeuo pipefail
umask 077

mode="${1:-}" run_id="${2:-}" expected_sha="${3:-}" requested_version="${4:-}"
[[ "$run_id" =~ ^tmals-[0-9]{8}T[0-9]{6}-[0-9]+$ ]] || { echo 'Identificador de operação inválido.' >&2; exit 2; }
[[ "$expected_sha" =~ ^[a-f0-9]{64}$ ]] || { echo 'SHA-256 inválido.' >&2; exit 2; }
[[ "$requested_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Versão inválida.' >&2; exit 2; }
base="$HOME/.cache/termux-manager-aws"
work="$base/$run_id"
zip="$work/package.zip"
extracted="$work/extracted"

require_host() {
  [[ -r /etc/os-release ]] || { echo 'SO não identificado.' >&2; exit 1; }
  # shellcheck source=/dev/null
  . /etc/os-release
  [[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 24.04 ]] || { echo 'Exige Ubuntu 24.04.' >&2; exit 1; }
  command -v python3 >/dev/null && command -v systemctl >/dev/null || { echo 'Dependências ausentes.' >&2; exit 1; }
  sudo -n true || { echo 'sudo sem senha indisponível para o usuário SSH.' >&2; exit 1; }
  [[ ! -L /opt/alsistemas-vps/current && -f /opt/alsistemas-vps/current/src/server.js ]] || {
    echo 'AL Sistemas não encontrado em /opt/alsistemas-vps/current. Esta rotina atualiza instalações existentes.' >&2; exit 1;
  }
  sudo -n systemctl cat alsistemas-vps.service >/dev/null || { echo 'Serviço alsistemas-vps não encontrado.' >&2; exit 1; }
  sudo -n systemctl cat alsistemas-vps.service | grep -Fq 'Description=AL Sistemas VPS (painel local)' || {
    echo 'O serviço existente não tem a identificação esperada. Nada será alterado.' >&2; exit 1;
  }
  local free_kb
  free_kb="$(df -Pk "$HOME" | awk 'NR==2 {print $4}')"
  [[ "$free_kb" =~ ^[0-9]+$ ]] && (( free_kb >= 1048576 )) || {
    echo 'Espaço livre inferior a 1 GiB. Atualização recusada.' >&2; exit 1;
  }
}

current_version() {
  sed -nE "s/^const VERSION = '([0-9]+\.[0-9]+\.[0-9]+)'.*/\1/p" \
    /opt/alsistemas-vps/current/src/server.js | head -n 1
}

prepare() {
  require_host
  [[ ! -L "$base" && ! -L "$work" ]] || { echo 'Diretório de preparação é link simbólico.' >&2; exit 1; }
  mkdir -p -- "$base" || exit 1
  chmod 700 -- "$base"
  [[ ! -e "$work" ]] || { echo 'Operação já existe; recusei sobrescrever.' >&2; exit 1; }
  mkdir -m 700 -- "$work"
  printf '[1/6] Servidor confirmado (Ubuntu 24.04); pasta temporária preparada.\n'
  printf 'Versão instalada: %s\n' "$(current_version)"
}

verify_and_extract() {
  [[ -f "$zip" && ! -L "$zip" ]] || { echo 'ZIP enviado não encontrado.' >&2; exit 1; }
  printf '%s  %s\n' "$expected_sha" "$zip" | sha256sum -c --status || {
    echo 'Hash SHA-256 diferente do arquivo local. Instalação bloqueada.' >&2; exit 1;
  }
  [[ ! -e "$extracted" ]] || { echo 'Extração já existente. Operação recusada.' >&2; exit 1; }
  mkdir -m 700 "$extracted"
  python3 - "$zip" "$extracted" <<'PY'
import pathlib, stat, sys, zipfile
source, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
with zipfile.ZipFile(source) as archive:
    members = archive.infolist()
    if not members or len(members) > 2500:
        sys.exit('ZIP vazio ou com arquivos demais.')
    size = sum(m.file_size for m in members)
    if size > 512 * 1024 * 1024:
        sys.exit('ZIP excede 512 MiB descompactados.')
    names = set()
    for member in members:
        name = member.filename
        posix = pathlib.PurePosixPath(name)
        mode = (member.external_attr >> 16) & 0xFFFF
        kind = stat.S_IFMT(mode)
        if (not name or '\\' in name or '\x00' in name or name.startswith('/')
                or '..' in posix.parts or '.' in posix.parts or ':' in posix.parts[0]
                or kind not in (0, stat.S_IFREG, stat.S_IFDIR)):
            sys.exit('ZIP contém caminho ou tipo de arquivo inseguro.')
        if name.rstrip('/') in names:
            sys.exit('ZIP contém nomes duplicados.')
        names.add(name.rstrip('/'))
    if not {'VERSION','instalar.sh','SHA256SUMS.txt','vps/src/server.js','vps/admin/updater.py'} <= names:
        sys.exit('ZIP não possui a estrutura esperada de AL Sistemas VPS.')
    archive.extractall(out)
PY
  [[ ! -L "$extracted/instalar.sh" ]] || { echo 'Instalador é link simbólico.' >&2; exit 1; }
  # Exige que SHA256SUMS.txt cubra exatamente os arquivos extraídos.
  python3 - "$extracted" <<'PY'
import hashlib, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
lines = (root / 'SHA256SUMS.txt').read_text(encoding='utf-8').splitlines()
seen = set()
for line in lines:
    match = re.fullmatch(r'([a-f0-9]{64})  (.+)', line)
    if not match:
        sys.exit('Manifesto SHA256SUMS.txt malformado.')
    expected, name = match.groups()
    part = pathlib.PurePosixPath(name)
    if (name.startswith('/') or chr(92) in name or '..' in part.parts
            or '.' in part.parts or name == 'SHA256SUMS.txt' or name in seen):
        sys.exit('Manifesto contém caminho inseguro ou duplicado.')
    seen.add(name)
    item = root.joinpath(*part.parts)
    if not item.is_file() or item.is_symlink():
        sys.exit('Manifesto aponta para arquivo ausente ou inválido.')
    actual = hashlib.sha256(item.read_bytes()).hexdigest()
    if actual != expected:
        sys.exit(f'Falha de integridade no arquivo: {name}')
files = {str(p.relative_to(root)) for p in root.rglob('*') if p.is_file()}
files.discard('SHA256SUMS.txt')
if seen != files:
    sys.exit('Manifesto não cobre exatamente os arquivos do pacote.')
PY
  local found_version
  found_version="$(tr -d '\r\n' < "$extracted/VERSION")"
  [[ "$found_version" == "$requested_version" ]] || {
    echo "Versão do pacote ($found_version) difere da selecionada ($requested_version)." >&2; exit 1;
  }
  printf '[3/6] ZIP e manifesto íntegros; versão %s validada.\n' "$found_version"
}

run_update() {
  require_host
  printf '[2/6] Verificando arquivo transferido...\n'
  verify_and_extract
  local old
  old="$(current_version)"
  [[ "$old" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Versão instalada não identificada.' >&2; exit 1; }
  if [[ "$(printf '%s\n%s\n' "$old" "$requested_version" | sort -V | tail -n 1)" == "$old" ]]; then
    echo "Versão instalada ($old) é igual ou superior à solicitada ($requested_version)." >&2
    exit 1
  fi
  printf '[4/6] Plano de instalação, sem alterações:\n'
  sudo -n bash "$extracted/instalar.sh" --plan --core-upgrade --allow-existing-host
  printf '[5/6] Criando backup privado dos dados e configurações do painel...\n'
  backup_root='/var/backups/alsistemas/manual'
  sudo -n install -d -o root -g root -m 0700 "$backup_root"
  backup="$backup_root/pre-${requested_version}-${run_id}.tar.gz"
  sudo -n tar -C / -czf "$backup" \
    opt/alsistemas-vps/current \
    var/lib/alsistemas \
    etc/systemd/system/alsistemas-vps.service
  sudo -n chmod 0600 "$backup"
  sudo -n tar -tzf "$backup" >/dev/null || { echo "Backup falhou na verificação." >&2; exit 1; }
  sudo -n test -s "$backup" || { echo 'Backup vazio; instalação cancelada.' >&2; exit 1; }
  printf 'Backup privado: %s\n' "$backup"
  printf '[5/6] Instalando somente o núcleo do AL Sistemas...\n'
  sudo -n bash "$extracted/instalar.sh" --core-upgrade --allow-existing-host
  printf '[6/6] Validando serviços e versão HTTP...\n'
  sudo -n systemctl is-active --quiet alsistemas-vps.service || {
    echo "Painel não está ativo. Backup: $backup" >&2; exit 1;
  }
  sudo -n nginx -t || { echo "Nginx inválido. Backup: $backup" >&2; exit 1; }
  python3 - "$requested_version" <<'PY'
import json, sys, time, urllib.request
expected = sys.argv[1]
for attempt in range(12):
    try:
        with urllib.request.urlopen('http://127.0.0.1:8181/api/health', timeout=3) as response:
            data = json.load(response)
        if data.get('ok') is True and data.get('version') == expected:
            print(f'Painel confirmado: versão {expected} ativa.')
            sys.exit(0)
    except Exception:
        pass
    time.sleep(2)
sys.exit('O serviço não confirmou a nova versão via /api/health; confira o journalctl e o backup.')
PY
  echo 'ATUALIZAÇÃO CONCLUÍDA. O IguatamaOnline e a instalação de testes não foram selecionados para alteração.'
}

case "$mode" in
  prepare) prepare ;;
  install) run_update ;;
  cleanup)
    # Só remove a pasta desta operação (não toca em backups, dados ou projetos).
    [[ "$work" == "$base"/tmals-* ]] || exit 2
    if [[ -d "$work" && ! -L "$work" ]]; then rm -rf -- "$work"; fi
    echo 'Arquivos temporários desta operação removidos.'
    ;;
  *) echo 'Modo não reconhecido.' >&2; exit 2 ;;
esac

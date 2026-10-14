#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf -- "$T"' EXIT
LINUX_STATE_DIR="$T/private"
LINUX_LOG="$T/linux.log"
mkdir -p "$LINUX_STATE_DIR"
: > "$LINUX_LOG"
source "$ROOT_DIR/modules/linux_x11.sh"
linux_log() { printf '%s\n' "$*" >> "$LINUX_LOG"; }

# O stream real do APT deve ser mantido sem fabricar percentual ou ETA.
proot-distro() {
    printf '[Manager][ETAPA] Atualizando listas de pacotes\n'
    printf 'Get:1 http://mirror/ubuntu archive 123 B\n'
    printf '[Manager][ETAPA] Instalando pacotes do desktop lxde\n'
    printf 'Unpacking lxde-common ...\n'
    printf 'Setting up lxde-common ...\n'
    sleep 2
    return "${MOCK_EXIT:-0}"
}
export LINUX_DESKTOP_HEARTBEAT_SECONDS=1
linux_executar_desktop_com_progresso ubuntu 'echo desktop' > "$T/output"
grep -Fq '[Manager][ETAPA] Atualizando listas de pacotes' "$T/output"
grep -Fq '[Manager][ETAPA] Instalando pacotes do desktop lxde' "$T/output"
grep -Fq 'Setting up lxde-common' "$T/output"
grep -Fq '[Manager][STATUS] Tempo ' "$T/output"
grep -Fq 'Etapa: Configurando pacotes | Downloads observados: 1 | Pacotes configurados: 1' "$T/output"
grep -Fq 'Execução finalizada em ' "$T/output"
grep -Fq 'Setting up lxde-common' "$LINUX_LOG"
if find "$LINUX_STATE_DIR" -name 'desktop-status.*' | grep -q .; then
    echo 'Estado temporário do progresso não foi removido' >&2; exit 1
fi
# Simula PRoot falhando e exige preservação exata do código.
MOCK_EXIT=39
if linux_executar_desktop_com_progresso ubuntu 'echo desktop' > "$T/error-output"; then
    echo 'Falha PRoot mascarada' >&2; exit 1
else
    [ "$?" -eq 39 ]
fi
# Confirma que o painel não fica preso em buffer até o fim da instalação.
python - "$ROOT_DIR/modules/linux_x11.sh" <<'PY'
import pathlib,sys
s=pathlib.Path(sys.argv[1]).read_text()
start=s.index('linux_instalar_desktop_na_distro()')
end=s.index('linux_instalar_xfce_na_distro()', start)
part=s[start:end]
assert part.index('ui_buffer_flush 2>/dev/null || true') < part.index('linux_executar_desktop_com_progresso "$alias" "$guest_script"')
PY
# As mensagens [ETAPA] devem estar presentes em todos os gerenciadores.
for stage in 'Atualizando listas de pacotes' 'Atualizando repositórios (pacman)' 'Atualizando repositórios (apk)' 'Instalando pacotes (dnf)' 'Atualizando repositórios (zypper)' 'Verificando inicializador do desktop'; do
    grep -Fq "$stage" "$ROOT_DIR/modules/linux_x11.sh"
done
printf 'OK: tempo, etapa, downloads observados, pacotes configurados, flush e exit code.\n'

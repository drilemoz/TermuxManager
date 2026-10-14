#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf -- "$T"' EXIT
export HOME="$T/home"
mkdir -p "$HOME"
LINUX_LOG="$T/linux.log"; : > "$LINUX_LOG"
source "$ROOT_DIR/modules/linux_permissions.sh"
source "$ROOT_DIR/modules/linux_x11.sh"
linux_log() { printf '%s\n' "$*" >> "$LINUX_LOG"; }

props="$HOME/.termux/termux.properties"
[ ! -e "$props" ]
if linux_apk_external_apps_ativo; then exit 1; fi
termux-reload-settings() { printf 'reload\n' >> "$T/reloads"; }
linux_apk_configurar_integracao
linux_apk_external_apps_ativo
[ "$(stat -c '%a' "$props")" = 600 ]
[ "$(stat -c '%a' "${props%/*}")" = 700 ]
linux_apk_restaurar_integracao
[ ! -e "$props" ]

printf '# Manter\ninterface=dark\nallow-external-apps=false\nallow-external-apps = true\nallow-external-apps=false\n' > "$props"
[ ! "$(linux_apk_external_apps_ativo && echo ativo || echo desativado)" = ativo ]
linux_apk_configurar_integracao
[ "$(grep -c '^allow-external-apps=true$' "$props")" -eq 1 ]
[ "$(grep -Ec '^[[:space:]]*allow-external-apps[[:space:]]*=' "$props")" -eq 1 ]
grep -q '^interface=dark' "$props"
echo 'mudança posterior' >> "$props"
linux_apk_restaurar_integracao
[ "$(cat "$props")" = "$(printf '# Manter\ninterface=dark\nallow-external-apps=false\nallow-external-apps = true\nallow-external-apps=false')" ]
if linux_apk_external_apps_ativo; then exit 1; fi

ln -s "$T/evil" "$HOME/.termux/termux.properties.manager-backup"
if linux_apk_configurar_integracao; then echo 'Symlink backup permitido' >&2; exit 1; fi
rm "$HOME/.termux/termux.properties.manager-backup"

am() {
    printf '%s\n' "$*" > "$T/am-args"
    if [ "${FAKE_AM_FAIL:-0}" = 1 ]; then echo 'Permission Denial' >&2; return 4; fi
    echo 'Starting: Intent'
}
linux_apk_abrir_config_android
[ "$(cat "$T/am-args")" = 'start --user 0 -a android.settings.MANAGE_UNKNOWN_APP_SOURCES -d package:com.termux' ]
FAKE_AM_FAIL=1
if linux_apk_abrir_config_android; then echo 'Permissão negada mascarada' >&2; exit 1; fi
unset FAKE_AM_FAIL

# A função não deve travar a UI em silêncio e deve preservar o exit code.
proot-distro() {
    printf 'proot invocado: %s\n' "$1"
    if [ "${FAKE_PROOT_SLOW:-0}" = 1 ]; then sleep 2; fi
    return "${FAKE_PROOT_EXIT:-0}"
}
export LINUX_DESKTOP_HEARTBEAT_SECONDS=1
FAKE_PROOT_SLOW=1
linux_executar_desktop_com_progresso ubuntu 'echo ok' > "$T/progress.log"
grep -q 'Iniciando PRoot (ubuntu)' "$T/progress.log"
grep -q 'Aguardando Linux/APT há 1s' "$T/progress.log"
FAKE_PROOT_EXIT=37
if linux_executar_desktop_com_progresso ubuntu 'echo ok' > "$T/failed.log"; then
  echo 'PRoot falhou mas retorna sucesso' >&2; exit 1
else
  [ "$?" -eq 37 ]
fi
# O watchdog precisa parar e liberar os processos mesmo após falha.
! pgrep -f 'sleep termux-manager-115' >/dev/null 2>&1 || true
grep -q 'Permissões para instalar APKs' "$ROOT_DIR/modules/linux_x11.sh"
grep -q 'Permissões de APK' "$ROOT_DIR/modules/linux_ui.sh"
printf 'OK: integração opcional, restore, symlink, Android settings, progresso sem silêncio e exit code.\n'

#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf -- "$T"' EXIT
export HOME="$T/home" DOWNLOADS_DIR="$T/Downloads"
mkdir -p "$HOME/.termux" "$DOWNLOADS_DIR"
LINUX_LOG="$T/linux.log"
: > "$LINUX_LOG"
source "$ROOT_DIR/modules/linux_x11.sh"
EVENTS="$T/events"; : > "$EVENTS"
logev() { echo "$*" >> "$EVENTS"; }
warn() { logev "warn:$*"; }
ok() { logev "ok:$*"; }
error() { logev "error:$*"; }
linux_log() { logev "log:$*"; }
caixa_simples() { logev "box:$*"; }
cabecalho_tela() { :; }
pause() { :; }
caminho_curto() { printf '%s' "$1"; }
resolver_downloads_dir() { :; }
confirmar_acao() { logev "ask:$1"; return 0; }
termux-open() { logev "termux-open:$*"; return "${MOCK_OPEN_RC:-0}"; }
pm() { if [ "${MOCK_PM_RC:-1}" = 0 ]; then echo 'package:/data/app/com.termux.x11/base.apk'; else return 1; fi; }

# When Termux blocks ContentProvider, don't call termux-open and guide manual APK install.
dest="$DOWNLOADS_DIR/termux-x11-universal-debug.apk"
printf 'APK dummy\n' > "$dest"
if linux_x11_abrir_instalador "$dest"; then echo 'should be blocked'; exit 1; fi
! grep -q '^termux-open:' "$EVENTS"
grep -q 'allow-external-apps=true' "$EVENTS"
grep -q 'gerenciador de arquivos' "$EVENTS"
# No automatic modification of the security-sensitive setting.
[ ! -e "$HOME/.termux/termux.properties" ]

# Existing APK must be reused without a download or curl.
: > "$EVENTS"
linux_baixar_x11_apk
! grep -q 'Baixar o APK oficial agora?' "$EVENTS"
grep -q 'Usar o APK existente' "$EVENTS"

# Respect opt-in, propagate opening failure to log; keep APK intact.
printf 'allow-external-apps=true\n' > "$HOME/.termux/termux.properties"
: > "$EVENTS"
export MOCK_OPEN_RC=17
if linux_x11_abrir_instalador "$dest"; then echo 'failed open silently accepted'; exit 1; fi
grep -q 'código 17' "$EVENTS"
grep -q '^termux-open:' "$EVENTS"
: > "$EVENTS"
export MOCK_OPEN_RC=0
linux_x11_abrir_instalador "$dest"
grep -q 'Solicitação enviada' "$EVENTS"

# `pm path` failure is inconclusive, not an assertion APK isn't installed.
export MOCK_PM_RC=1
[ "$(linux_x11_apk_status_texto)" = 'não confirmado (pode estar instalado)' ]
export MOCK_PM_RC=0
[ "$(linux_x11_apk_status_texto)" = 'detectado no Android' ]
# Reinstall is not the default when a recognized app is already present.
: > "$EVENTS"
linux_baixar_x11_apk
grep -q 'já foi detectado' "$EVENTS"

# Starting the desktop should offer continuation with inconclusive pm detection.
export MOCK_PM_RC=1
linux_garantir_proot_distro() { return 0; }
linux_x11_companion_instalado() { return 0; }
linux_selecionar_instalada() { LINUX_DISTRO_ALIAS=ubuntu; }
linux_coletar_info_distro() { LINUX_INFO_HEALTH=bad; LINUX_DIAG_REASON='test'; }
: > "$EVENTS"
linux_iniciar_desktop >/dev/null || true
grep -q 'Tentar iniciar o desktop mesmo assim' "$EVENTS"

printf 'OK: X11 APK existente, permissão externa, abertura, status inconclusivo e continuação segura.\n'

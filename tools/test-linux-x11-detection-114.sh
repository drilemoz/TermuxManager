#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf -- "$T"' EXIT
LINUX_LOG="$T/linux.log"; : > "$LINUX_LOG"
source "$ROOT_DIR/modules/linux_x11.sh"
linux_log() { printf '%s\n' "$*" >> "$LINUX_LOG"; }
warn() { :; }; ok() { :; }; error() { :; }; cabecalho_tela() { :; }; caixa_simples() { :; }; pause() { :; }
confirmar_acao() { return 0; }
# Both pm and cmd are emulated, so the test never inspects host Android state.
pm() {
  case "${1:-}" in
    path) if [ "${FAKE_PM_PATH:-0}" = 1 ]; then printf 'package:/mock/base.apk\n'; else echo 'Error: service inaccessible' >&2; return 13; fi ;;
    list) if [ "${FAKE_PM_LIST:-0}" = 1 ]; then printf 'package:com.termux.x11\n'; else echo 'No results' >&2; return 0; fi ;;
    *) return 1 ;;
  esac
}
cmd() {
  if [ "${FAKE_CMD_PATH:-0}" = 1 ]; then printf 'package:/mock/base.apk\n'; else echo 'package service rejected' >&2; return 17; fi
}
am() {
 case "${FAKE_AM:-success}" in
   success) echo 'Starting: Intent { cmp=com.termux.x11/.MainActivity }' ;;
   already) echo 'Warning: Activity not started, intent delivered to currently running top-most instance.' ;;
   errorzero) echo 'Error type 3'; echo 'Error: Activity class does not exist.' ;;
   denied) echo 'SecurityException: Permission Denial' >&2; return 1 ;;
 esac
}
FAKE_PM_PATH=0 FAKE_PM_LIST=0 FAKE_CMD_PATH=0
[ "$(linux_x11_apk_status_texto)" = 'não confirmado (pode estar instalado)' ]
if linux_x11_apk_instalado; then echo 'consulta falha foi classificada como instalada'; exit 1; fi
FAKE_CMD_PATH=1
linux_x11_consultar_apk_android
[ "$LINUX_X11_DETECCAO_METODO" = 'cmd package path' ]
FAKE_CMD_PATH=0 FAKE_PM_LIST=1
linux_x11_consultar_apk_android
[ "$LINUX_X11_DETECCAO_METODO" = 'pm list packages' ]
FAKE_PM_LIST=0 FAKE_PM_PATH=1
linux_x11_consultar_apk_android
[ "$LINUX_X11_DETECCAO_METODO" = 'pm path' ]
FAKE_PM_PATH=0
# Diagnostic must survive query failures under set -e, capture errors, and not log private paths.
linux_x11_registrar_consultas_android
grep -q 'pm path: sem confirmação (status=13)' "$LINUX_LOG"
grep -q 'cmd package path: sem confirmação (status=17)' "$LINUX_LOG"
FAKE_AM=success
linux_x11_testar_abertura_android
[ "$(linux_x11_apk_status_texto)" = 'abertura confirmada no Android' ]
grep -q 'abertura Android confirmada' "$LINUX_LOG"
FAKE_AM=already
linux_x11_testar_abertura_android
[ "$LINUX_X11_ABERTURA_ESTADO" = confirmada ]
FAKE_AM=errorzero
if linux_x11_testar_abertura_android; then echo 'am com Error type 3 passou incorretamente'; exit 1; fi
[ "$LINUX_X11_ABERTURA_ESTADO" = falhou ]
[ "$(linux_x11_apk_status_texto)" = 'não confirmado; abertura falhou (ver log)' ]
FAKE_AM=denied
if linux_x11_testar_abertura_android; then echo 'am Permission Denial passou incorretamente'; exit 1; fi
grep -q 'Permission Denial' "$LINUX_LOG"
# UI should never duplicate menu index in the option label.
! grep -Fq '1|📦|1. Componentes' "$ROOT_DIR/modules/linux_x11.sh"
! grep -Fq '2|📲|2. Aplicativo' "$ROOT_DIR/modules/linux_x11.sh"
grep -Fq '4|▶️|Testar abertura do app' "$ROOT_DIR/modules/linux_x11.sh"
grep -Fq '6|▶️|Testar abertura do X11' "$ROOT_DIR/modules/linux_x11.sh"
printf 'OK: consultas alternativas X11, Activity am start, falhas com rc=0, log e menu.\n'

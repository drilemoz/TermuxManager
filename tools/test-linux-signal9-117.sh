#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf -- "$T"' EXIT
LINUX_STATE_DIR="$T/private"; LINUX_LOG="$T/linux.log"; mkdir -p "$LINUX_STATE_DIR"; : > "$LINUX_LOG"
source "$ROOT_DIR/modules/linux_x11.sh"
linux_log() { printf '%s\n' "$*" >> "$LINUX_LOG"; }
caixa_simples() { printf '%s\n' "$*" >> "$T/boxes"; }
proot-distro() { printf 'Session is LXDE\n'; return "${FAKE_RC:-0}"; }
# A pending marker must not be confused with proof of Android SIGKILL.
linux_x11_marcar_inicio_sessao ubuntu lxde
[ -f "$LINUX_STATE_DIR/x11-session-pending.state" ]
[ "$(stat -c %a "$LINUX_STATE_DIR/x11-session-pending.state")" = 600 ]
linux_x11_verificar_sessao_anterior
grep -q 'não recebeu o término normal' "$T/boxes"
if [ -L "$LINUX_STATE_DIR/x11-session-pending.state" ]; then exit 1; fi
rm "$LINUX_STATE_DIR/x11-session-pending.state"
ln -s "$T/forbidden" "$LINUX_STATE_DIR/x11-session-pending.state"
if linux_x11_marcar_inicio_sessao ubuntu lxde; then echo 'symlink accepted' >&2; exit 1; fi
[ ! -e "$T/forbidden" ]
rm "$LINUX_STATE_DIR/x11-session-pending.state"
# Propagate exact status and preserve output in Linux exportable log.
FAKE_RC=0
linux_x11_executar_sessao_proot ubuntu 'startlxde' > "$T/ok"
grep -q 'Session is LXDE' "$LINUX_LOG"
FAKE_RC=137
if linux_x11_executar_sessao_proot ubuntu 'startlxde' > "$T/fail"; then exit 1; else [ "$?" -eq 137 ]; fi
grep -q 'status=137' "$LINUX_LOG"
linux_x11_orientar_sigkill
grep -q 'SIGKILL' "$T/boxes"
grep -q 'restrições de processos filhos' "$T/boxes"
# Export includes sanitized X11 companion log and refuses symlink log sources.
source "$ROOT_DIR/modules/linux_diagnostics.sh"
DOWNLOADS_DIR="$T/downloads"; mkdir -p "$DOWNLOADS_DIR"
resolver_downloads_dir() { :; }
caixa_simples_wrap() { :; }
caminho_curto() { printf '%s' "$1"; }
error() { printf 'ERRO %s\n' "$*" >&2; }
linux_limpar_ansi_log() { cat; }
linux_redigir_log_exportado() { sed -e 's/segredo[0-9][0-9]*/[REMOVIDO]/g'; }
printf 'servidor: segredo123\n' > "$LINUX_STATE_DIR/x11-server.log"
linux_exportar_log_downloads
exportado=("$DOWNLOADS_DIR"/termux-manager-linux-*.log)
grep -q 'TERMUX:X11' "${exportado[0]}"
grep -q '\[REMOVIDO\]' "${exportado[0]}"
! grep -q segredo123 "${exportado[0]}"
! grep -q 'settings put global' "$ROOT_DIR/modules/linux_x11.sh"
grep -Fq '8|⚠️|Signal 9 e Android' "$ROOT_DIR/modules/linux_x11.sh"
python - "$ROOT_DIR/modules/linux_x11.sh" <<'PY_CHECK'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(); part=s[s.index('linux_iniciar_desktop()'):s.index('linux_iniciar_xfce()')]
assert part.index('linux_x11_marcar_inicio_sessao') < part.index('termux-x11 :1')
assert part.index('linux_x11_executar_sessao_proot') < part.rindex('rm -f -- "$(linux_x11_marcador_sessao)"')
assert 'linux_x11_verificar_sessao_anterior' in part
assert 'x11-server.log' in part and '2>&1 &' in part
PY_CHECK
printf 'OK: signal 9, aviso de sessão incompleta, logs e código de erro preservado.\n'

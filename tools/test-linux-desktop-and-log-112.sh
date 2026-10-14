#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
mkdir -p "$TMP_ROOT/bin" "$TMP_ROOT/logs" "$TMP_ROOT/downloads"
PAINEL_DIR="$TMP_ROOT/manager"
LOG_DIR="$TMP_ROOT/logs"
LINUX_LOG="$LOG_DIR/linux.log"
source "$ROOT_DIR/modules/linux.sh"
source "$ROOT_DIR/modules/diagnostics_core.sh"

cat > "$TMP_ROOT/bin/apt-get" <<'MOCK'
#!/bin/sh
printf '%s\n' "$*" >> "$MOCK_APT_CALLS"
if [ "$1" = update ] && [ "${MOCK_FAIL_UPDATE:-0}" = 1 ]; then
  echo '[mock] APT update falhou' >&2
  exit 27
fi
if [ "$1" = install ] && [ "${MOCK_FAIL_INSTALL:-0}" = 1 ]; then
  echo '[mock] APT install falhou' >&2
  exit 42
fi
MOCK
chmod +x "$TMP_ROOT/bin/apt-get"
for launcher in xfce4-session startlxqt startlxde mate-session openbox-session i3 startplasma-x11 gnome-session; do
  printf '#!/bin/sh\nexit 0\n' > "$TMP_ROOT/bin/$launcher"
  chmod +x "$TMP_ROOT/bin/$launcher"
done
export MOCK_APT_CALLS="$TMP_ROOT/apt-calls"
export PATH="$TMP_ROOT/bin:$PATH"

# Unquoted 'case \"xfce\"' regression: all desktops must actually run apt-get install.
for desktop in xfce lxqt lxde mate openbox i3 kde gnome; do
  : > "$MOCK_APT_CALLS"
  guest="$(linux_desktop_guest_script "$desktop")"
  /bin/sh -n -c "$guest"
  /bin/sh -c "$guest" > "$TMP_ROOT/guest.log" 2>&1
  grep -q '^update ' "$MOCK_APT_CALLS"
  grep -q '^install -y ' "$MOCK_APT_CALLS"
  grep -q "Instalando pacotes do desktop $desktop" "$TMP_ROOT/guest.log"
done

# Package manager failure must be visible and not converted into success.
export MOCK_FAIL_UPDATE=1
: > "$MOCK_APT_CALLS"
guest="$(linux_desktop_guest_script xfce)"
if /bin/sh -c "$guest" > "$TMP_ROOT/guest.log" 2>&1; then
  echo 'Atualização APT falhou mas script considerou sucesso' >&2; exit 1
else
  [ "$?" -eq 27 ]
fi
! grep -q '^install ' "$MOCK_APT_CALLS"
unset MOCK_FAIL_UPDATE
export MOCK_FAIL_INSTALL=1
if /bin/sh -c "$guest" > "$TMP_ROOT/guest.log" 2>&1; then
  echo 'Falha APT install foi mascarada' >&2; exit 1
else
  [ "$?" -eq 42 ]
fi
unset MOCK_FAIL_INSTALL
rm "$TMP_ROOT/bin/xfce4-session"
if /bin/sh -c "$guest" > "$TMP_ROOT/guest.log" 2>&1; then
  echo 'Launcher ausente foi aceito' >&2; exit 1
else
  [ "$?" -eq 66 ]
fi
grep -q 'Inicializador ausente: xfce4-session' "$TMP_ROOT/guest.log"

# Linux log exportation must sanitize secrets without altering original content.
printf '%s\n' 'PASS=segredo123' 'https://usuario:senha123@example.com/caminho' 'Authorization: Bearer abc123' 'Início de teste' > "$LINUX_LOG"
resolver_downloads_dir() { DOWNLOADS_DIR="$TMP_ROOT/downloads"; }
caixa_simples_wrap() { :; }
caminho_curto() { printf '%s' "$1"; }
error() { echo "ERRO: $*" >&2; }
linux_exportar_log_downloads
lista=("$TMP_ROOT"/downloads/termux-manager-linux-*.log)
[ "${#lista[@]}" -eq 1 ]
[ -f "${lista[0]}" ]
grep -q '\[REMOVIDO\]' "${lista[0]}"
! grep -q -E 'segredo123|senha123|Bearer abc123' "${lista[0]}"
grep -q 'segredo123' "$LINUX_LOG"

# Collision with symbolic links may not replace a link target.
date() { if [ "$1" = '+%Y%m%d-%H%M%S' ]; then printf '20000101-010101'; else command date "$@"; fi; }
evil="$TMP_ROOT/arquivo-fora"
printf 'NÃO ALTERAR\n' > "$evil"
ln -s "$evil" "$TMP_ROOT/downloads/termux-manager-linux-20000101-010101-$$.log"
if linux_exportar_log_downloads >/dev/null 2>&1; then
  echo 'Symlink de destino não foi rejeitado' >&2; exit 1
fi
grep -qx 'NÃO ALTERAR' "$evil"
unset -f date

# When a desktop fails in proot, the error must offer the export path.
linux_detectar_gerenciador_distro() { printf 'apt'; }
linux_desktop_instalado() { return 1; }
linux_avaliar_aparelho() { LINUX_PROFILE='BÁSICO'; LINUX_PROFILE_ICON='x'; }
caixa_simples() { :; }
cabecalho_tela() { :; }
confirmar_acao() { :; }
linux_log() { printf '%s\n' "$*" >> "$LINUX_LOG"; }
linux_exportar_log_downloads() { echo SIM >> "$TMP_ROOT/oferta"; }
proot-distro() { return 42; }
if linux_instalar_desktop_na_distro ubuntu xfce >/dev/null 2>&1; then
    echo 'Erro PRoot mascarado' >&2; exit 1
fi
grep -q 'código=42' "$LINUX_LOG"
grep -qx SIM "$TMP_ROOT/oferta"
echo 'OK: todos os oito desktops instalam, falhas reais são preservadas, exportação segura e opção após erro.'

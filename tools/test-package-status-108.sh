#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
source "$ROOT_DIR/modules/termux_packages_actions.sh"
# Substituir dpkg-query por função evita qualquer dependência do host.
dpkg-query() {
    case "${*: -1}" in
        coreutils) return 1 ;;
        wget) printf '%s\n' 'install ok installed' ;;
        *) return 1 ;;
    esac
}
if pacote_funcional_pos_instalacao coreutils; then
    echo 'Aceitou coreutils ausente porque ls está no PATH'; exit 1
fi
# wget precisa estar instalado e o comando executável disponível.
if command -v wget >/dev/null 2>&1; then
    pacote_funcional_pos_instalacao wget
else
    if pacote_funcional_pos_instalacao wget; then echo 'Aceitou wget ausente'; exit 1; fi
fi
echo 'OK: estado dpkg validado sem falso positivo por comandos compartilhados.'

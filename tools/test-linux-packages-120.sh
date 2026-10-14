#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/modules/linux_packages.sh"
linux_pacote_nome_valido python3
linux_pacote_nome_valido libstdc++
! linux_pacote_nome_valido '-x'
! linux_pacote_nome_valido 'nano;rm -rf /'
! linux_pacote_nome_valido 'curl wget'
! linux_pacote_nome_valido '$(touch /tmp/test-pkg-bad)'
[ "$(linux_pacotes_comando apt instalar nano)" = 'export DEBIAN_FRONTEND=noninteractive; apt-get install -y nano' ]
[ "$(linux_pacotes_comando pacman remover python3)" = 'pacman -R --noconfirm python3' ]
[ "$(linux_pacotes_comando apk instalar curl)" = 'apk add curl' ]
[ "$(linux_pacotes_comando dnf buscar jq)" = 'dnf search jq' ]
[ "$(linux_pacotes_comando zypper detalhes git)" = 'zypper info git' ]
if linux_pacotes_comando apt instalar 'curl;cat /etc/passwd' >/dev/null 2>&1; then exit 1; fi
for c in dev editors rede monitor arquivos sessoes utils web; do
    [ -n "$(linux_pacotes_catalogo_pacotes "$c")" ]
done
printf 'OK: validação de nomes, comandos por distro e catálogo.\n'

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/modules/linux_packages.sh"
[[ $(linux_catalog_categorias | wc -l) -eq 21 ]]
[[ $(for c in $(linux_catalog_categorias | cut -d'|' -f1); do linux_catalog_listar "$c"; done | wc -l) -ge 150 ]]
for item in browsers office pdf audio video graphics ide database games science desktop filegui; do
    [[ -n "$(linux_catalog_listar "$item")" ]]
done
linux_catalog_listar browsers | grep -q '^netsurf-gtk|'
linux_catalog_listar browsers | grep -q '^epiphany-browser|'
linux_catalog_listar textweb | grep -q '^w3m|'
! linux_catalog_listar browsers | grep -Eq '^(firefox|chromium-browser)\|'
# Confirmar nomes seguros, títulos, indicador de recursos e ausência de entradas duplicadas.
all="$(while IFS='|' read -r category icon title about; do linux_catalog_listar "$category"; done < <(linux_catalog_categorias))"
[[ $(printf '%s\n' "$all" | cut -d'|' -f1 | sort -u | wc -l) -gt 90 ]]
while IFS='|' read -r package title mode size note; do
    linux_pacote_nome_valido "$package"
    [[ -n "$title" && -n "$note" ]]
    [[ "$mode" == G || "$mode" == T ]]
    [[ "$size" == L || "$size" == M || "$size" == H ]]
    [[ "$package" != 'chromium-browser' && "$package" != 'firefox' ]]
done <<< "$all"
# Testar a consulta real executando o shell da distro com fakes, sem instalar nada.
T="$(mktemp -d)"; trap 'rm -rf -- "$T"' EXIT
mkdir -p "$T/bin"
cat > "$T/bin/dpkg-query" <<'EOF'
#!/bin/sh
if [ "$3" = pkg-instalado ]; then printf 'install ok installed'; exit 0; fi
exit 1
EOF
cat > "$T/bin/apt-cache" <<'EOF'
#!/bin/sh
[ "$1" = policy ] || exit 2
case "$2" in
pkg-disponivel) printf '  Candidate: 1.0\n';;
pkg-ausente) printf '  Candidate: (none)\n';;
*) exit 3;;
esac
EOF
chmod +x "$T/bin"/*
linux_admin_alias_valido() { [[ "$1" == ubuntu ]]; }
proot-distro() {
    [[ "$1" == login && "$2" == ubuntu && "$3" == -- ]] || return 17
    PATH="$T/bin:$PATH" /bin/sh -c "$6"
}
[[ "$(linux_catalog_status_pacote ubuntu apt pkg-instalado)" == instalado ]]
[[ "$(linux_catalog_status_pacote ubuntu apt pkg-disponivel)" == disponivel ]]
[[ "$(linux_catalog_status_pacote ubuntu apt pkg-ausente)" == ausente ]]
[[ "$(linux_catalog_status_pacote ubuntu apt bogus)" == ausente ]]
if linux_catalog_status_pacote ubuntu apt 'wget;touch /tmp/never' > /dev/null 2>&1; then exit 1; fi
proot-distro() { return 64; }
[[ "$(linux_catalog_status_pacote ubuntu apt pkg-disponivel)" == desconhecido ]]
# Paginação: a página 2 deve incluir categorias reais, sem rolar 21 itens.
menu_unificado() { printf 'MENU:%s\n' "$2" >> "$T/menu"; }
ler_opcao() { RESPOSTA_MENU="${ANSWERS[$INDEX]}"; INDEX=$((INDEX+1)); }
linux_admin_gerenciador() { printf apt; }
linux_catalog_pagina_pacotes() { printf '%s\n' "$2" >> "$T/categories"; }
feedback_curto() { :; }
INDEX=0; ANSWERS=(8 1 0)
linux_pacotes_catalogo ubuntu
[[ -s "$T/categories" ]]
grep -q 'categorias 2/3' "$T/menu"
[[ $(wc -l < "$T/categories") -eq 1 ]]
echo 'OK: catálogo Linux de 21 categorias, 160 entradas e verificação segura no repositório.'

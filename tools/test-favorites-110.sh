#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PAINEL_DIR="$TMP/painel"
HOME="$TMP/home"; export HOME
mkdir -p "$HOME" "$PAINEL_DIR"
warn(){ :; }; error(){ :; }
source "$ROOT/modules/commands_favorites.sh"

favoritos_adicionar 'Listar arquivos' 'printf "%s" "$HOME"'
favoritos_adicionar 'Nome estranho | teste' 'printf "a|b; c $(date +%Y)"'
[ "$(favoritos_listar | wc -l)" -eq 2 ]
[ "$(stat -c %a "$(favoritos_arquivo)")" = 600 ]
# Nenhum comando é executado ao criar ou listar os favoritos.
favoritos_adicionar 'não execute' "touch '$TMP/marcador'"
[ ! -e "$TMP/marcador" ]
! favoritos_adicionar 'não execute' 'echo duplicado'
! favoritos_adicionar 'inválido' $'printf x\nrm -rf /'
! favoritos_adicionar $'mal\nnome' 'echo x'
[ "$(favoritos_listar | wc -l)" -eq 3 ]
favoritos_excluir_indice 2
[ "$(favoritos_listar | wc -l)" -eq 2 ]
! favoritos_excluir_indice 20
# Salvar em alvo symlink é proibido.
mv "$(favoritos_arquivo)" "$TMP/seguro"
ln -s "$TMP/seguro" "$(favoritos_arquivo)"
! favoritos_adicionar 'sem gravar' 'echo 123'
[ "$(wc -l < "$TMP/seguro")" -eq 2 ]
rm "$(favoritos_arquivo)"
mv "$TMP/seguro" "$(favoritos_arquivo)"
# 12 entradas no máximo.
for n in {4..13}; do favoritos_adicionar "comando$n" "echo $n"; done
[ "$(favoritos_listar | wc -l)" -eq 12 ]
! favoritos_adicionar '13' 'echo 13'
# Reinício: lê as linhas persistidas do arquivo sem executá-las.
[ "$(favoritos_listar | wc -l)" -eq 12 ]
echo 'OK: favoritos privados, atômicos, limitados e sem execução automática.'

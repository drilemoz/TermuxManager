#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
export HOME="$TMP/home"
DOWNLOADS_DIR="$HOME/storage/downloads"
PAINEL_DIR="$HOME/Painel"
mkdir -p "$DOWNLOADS_DIR/Arquivos 2026/IguaNews/versões" "$PAINEL_DIR" "$HOME/storage/shared/Documentos"
touch "$DOWNLOADS_DIR/Arquivos 2026/IguaNews/versões/IguaNews-v1.0.0.zip"
touch "$HOME/storage/shared/Documentos/projeto android.zip"
for i in $(seq -w 1 15); do touch "$DOWNLOADS_DIR/Arquivos 2026/IguaNews/versões/zz-$i.zip"; done
source "$ROOT/modules/import.sh"
check_storage_access() { return 0; }
wizard_cabecalho() { :; }
caixa_simples() { :; }
caixa_linha_topo() { :; }
caixa_linha_baixo() { :; }
caixa_linha_texto() { :; }
menu_opcao() { :; }
rodape_atalhos() { :; }
caminho_curto() { printf '%s' "$1"; }
icone_tipo_item() { if [ -d "$1" ]; then ICON_ITEM=📁; TIPO_ITEM=Pasta; else ICON_ITEM=📦; TIPO_ITEM=ZIP; fi; }
warn() { :; }
pause() { :; }
ler_opcao() { RESPOSTA_MENU="${SEQUENCIA[$POS]}"; POS=$((POS+1)); [ "$POS" -le "${#SEQUENCIA[@]}" ] || { echo "Sequência esgotada" >&2; exit 9; }; }

# Entrar em 3 subpastas, voltar uma e selecionar o ZIP em diretório aninhado.
wizard_resetar_importacao; wizard_localizar_origem
POS=0; SEQUENCIA=(1 1 1 0 1 1)
wizard_etapa_item
[ "$WIZ_ORIGEM" = "$DOWNLOADS_DIR/Arquivos 2026/IguaNews/versões/IguaNews-v1.0.0.zip" ] || { echo "ZIP incorreto: $WIZ_ORIGEM" >&2; exit 1; }
[ "$WIZ_ORIGEM_ORIGINAL" = "$WIZ_ORIGEM" ]
[ "$WIZ_TIPO" = ZIP ]

# Selecionar pastas NÃO pode iniciar importação: é preciso usar [I] explicitamente.
wizard_resetar_importacao; wizard_localizar_origem
POS=0; SEQUENCIA=(1 1 I)
wizard_etapa_item
[ "$WIZ_ORIGEM" = "$DOWNLOADS_DIR/Arquivos 2026/IguaNews" ] || exit 1
[ -d "$WIZ_ORIGEM" ]

# Não importar toda a Downloads inadvertidamente.
if wizard_pasta_importavel "$DOWNLOADS_DIR"; then echo 'Downloads importável sem navegar' >&2; exit 1; fi

# Atalho Android + diretório com espaços, sem mover arquivo.
wizard_resetar_importacao; wizard_localizar_origem
POS=0; SEQUENCIA=(A 1 1)
wizard_etapa_item
[ "$WIZ_ORIGEM" = "$HOME/storage/shared/Documentos/projeto android.zip" ] || exit 1
[ -f "$WIZ_ORIGEM" ]

# Teste de paginação, seleção da segunda página, cancelamento e pastas vazias.
wizard_resetar_importacao; wizard_localizar_origem
POS=0; SEQUENCIA=(1 1 1 + 2)
wizard_etapa_item
[ "$WIZ_ORIGEM" = "$DOWNLOADS_DIR/Arquivos 2026/IguaNews/versões/zz-11.zip" ] || { echo "Paginação falhou: $WIZ_ORIGEM" >&2; exit 1; }

wizard_resetar_importacao; wizard_localizar_origem
POS=0; SEQUENCIA=(X)
if wizard_etapa_item; then echo 'Cancelamento ignorado' >&2; exit 1; fi

printf 'OK: navegar, subir, importar pasta explicitamente, atalhos, paginação e cancelar.\n'

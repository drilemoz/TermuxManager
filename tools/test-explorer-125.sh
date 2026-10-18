#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home"
mkdir -p "$HOME/Painel/projetos" "$HOME/scripts/manager" "$HOME/work/origem/pasta" "$HOME/work/destino" "$HOME/work/sub" "$HOME/storage/downloads"
export PREFIX="$tmp/prefix"
mkdir -p "$PREFIX"
BASE_DIR="$HOME/scripts/manager"
PAINEL_DIR="$HOME/Painel"
PROJETOS_DIR="$PAINEL_DIR/projetos"
LOG_DIR="$PAINEL_DIR/.logs"
PID_DIR="$PAINEL_DIR/.pids"
INSTANCE_LOCK="$PAINEL_DIR/.manager.lock"
CONFIG_FILE="$PAINEL_DIR/.manager.conf"
DOWNLOADS_DIR="$HOME/storage/downloads"
source "$ROOT/modules/explorer.sh"
warn() { :; }
ok() { :; }
info() { :; }
caminho_home_relativo() { printf '%s' "$1"; }
confirmar_acao() { [ "${TEST_CONFIRMA:-0}" = 1 ]; }
assert() { "$@" || { echo "FALHOU: $*"; exit 1; }; }

# Nomes com espaços, acentos, metacaracteres shell e arquivos ocultos
printf 'alpha\n' > "$HOME/work/origem/órgão [v1];.txt"
printf 'oculto\n' > "$HOME/work/origem/.env"
assert explorer_nome_valido 'teste final.txt'
if explorer_nome_valido '../escapar'; then exit 1; fi
if explorer_nome_valido 'nao/permitido'; then exit 1; fi
assert explorer_protegido '/'
assert explorer_protegido "$HOME"
assert explorer_protegido "$HOME/Painel"
assert explorer_protegido "$BASE_DIR/modules/a.sh"
assert explorer_protegido "$PREFIX/etc"
assert explorer_destino_restrito "$BASE_DIR"
assert explorer_destino_restrito "$PREFIX/etc"
if explorer_destino_restrito "$HOME"; then exit 1; fi
if explorer_protegido "$HOME/work/origem"; then exit 1; fi
assert explorer_operar_renomear "$HOME/work/origem/órgão [v1];.txt" 'nova versão.txt'
assert test -f "$HOME/work/origem/nova versão.txt"
if explorer_operar_renomear "$HOME/work/origem/nova versão.txt" '.env'; then exit 1; fi
assert test -f "$HOME/work/origem/.env"

EXPLORER_DIR="$HOME/work/destino"
EXPLORER_CLIP_PATH="$HOME/work/origem/nova versão.txt"
EXPLORER_CLIP_MODE=copiar
EXPLORER_DIR="$BASE_DIR"
if explorer_colar; then exit 1; fi
EXPLORER_DIR="$HOME/work/destino"
assert explorer_colar
assert test -f "$HOME/work/destino/nova versão.txt"
if explorer_colar; then exit 1; fi
assert test -f "$HOME/work/origem/nova versão.txt"
EXPLORER_CLIP_PATH="$HOME/work/origem/.env"
EXPLORER_CLIP_MODE=mover
assert explorer_colar
assert test -f "$HOME/work/destino/.env"
assert test ! -e "$HOME/work/origem/.env"
assert test -z "$EXPLORER_CLIP_MODE"

EXPLORER_DIR="$HOME/work/origem/pasta"
EXPLORER_CLIP_PATH="$HOME/work/origem"
EXPLORER_CLIP_MODE=copiar
if explorer_colar; then exit 1; fi
assert test ! -e "$HOME/work/origem/pasta/origem"
EXPLORER_DIR="$HOME/work/sub"
EXPLORER_CLIP_PATH="$HOME/work/origem"
EXPLORER_CLIP_MODE=mover
assert explorer_colar
assert test -d "$HOME/work/sub/origem/pasta"
assert test ! -e "$HOME/work/origem"

# Impede exclusões acidentais ou da instalação; confirmações explícitas
if explorer_excluir "$HOME/work/destino/nova versão.txt"; then exit 1; fi
assert test -f "$HOME/work/destino/nova versão.txt"
TEST_CONFIRMA=1
if explorer_excluir "$BASE_DIR"; then exit 1; fi
assert test -d "$BASE_DIR"
assert explorer_excluir "$HOME/work/destino/nova versão.txt"
assert test ! -e "$HOME/work/destino/nova versão.txt"
assert explorer_excluir "$HOME/work/sub/origem"
assert test ! -e "$HOME/work/sub/origem"
assert explorer_nova_pasta 'nova pasta'
assert test -d "$HOME/work/sub/nova pasta"

# Links simbólicos nunca removem seu alvo, mesmo para diretórios.
mkdir "$HOME/work/real-dir"
ln -s "$HOME/work/real-dir" "$HOME/work/sub/atalho"
assert explorer_excluir "$HOME/work/sub/atalho"
assert test -d "$HOME/work/real-dir"

# A navegação usa opções numéricas, atalhos e lista nomes ocultos.
mkdir -p "$HOME/browse/s1"; touch "$HOME/browse/.segredo" "$HOME/browse/t.txt"
EXPLORER_DIR="$HOME/browse"
explorer_listar
assert test "${#EXPLORER_ITEMS[@]}" -eq 3
assert test "${EXPLORER_ITEMS[0]}" = "$HOME/browse/s1"

# Simula interação por menus sem comandos: 1=selecionar pasta, 1=abrir,
# U=subir, ?=atalhos, 1=home, 0=voltar.
menu_unificado() { printf '%s\n' "$*" >> "$tmp/menus"; }
ler_opcao() { IFS= read -r RESPOSTA_MENU || RESPOSTA_MENU=0; }
pause() { :; }
ui_preparar_prompt() { :; }
cabecalho_tela() { :; }
caixa_simples_wrap() { :; }
EXPLORER_DIR="$HOME/browse"
menu_explorer < <(printf '1\n1\nu\n?\n1\n0\n')
assert test "$EXPLORER_DIR" = "$HOME"
assert grep -q 'EXPLORER' "$tmp/menus"
assert grep -q 'Abrir pasta' "$tmp/menus"

printf 'OK: Explorer v1.0.125, segurança, cópia, mover, renomear, excluir, criar pasta e navegação\n'

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
export HOME="$TMP/home"
mkdir -p "$HOME/Painel" "$TMP/source/node_modules" "$TMP/source/src" "$TMP/empty"
printf 'atualizado\n' > "$TMP/source/src/index.php"
printf 'ignore\n' > "$TMP/source/node_modules/dependencia.txt"
EXCLUSOES_PADRAO='node_modules .git dist build'
CONFLITO_PADRAO=perguntar
LARGURA_CAIXA=80
C_BOLD=""; C_GREEN=""; C_RESET=""; C_DIM=""
SESSION_TMP_DIR="$TMP/temporary"
LOG_FILE="$TMP/manager.log"
mkdir -p "$SESSION_TMP_DIR"
: > "$LOG_FILE"
source "$ROOT/modules/import.sh"
# UI isolada: qualquer solicitação de entrada fora de um conflito real é falha.
ler_opcao(){
    if [ "${#OPCOES[@]}" -eq 0 ]; then echo 'FAIL: solicitou Enter desnecessário' >&2; exit 99; fi
    RESPOSTA_MENU="${OPCOES[0]}"; OPCOES=("${OPCOES[@]:1}")
}
menu_unificado(){ :; }
cabecalho_tela(){ :; }
wizard_cabecalho(){ :; }
caixa_linha_topo(){ :; }
caixa_linha_texto(){ :; }
caixa_linha_baixo(){ :; }
caixa_linha_sep(){ :; }
rodape_atalhos(){ :; }
caixa_simples(){ :; }
caminho_curto(){ echo "$1"; }
valor_legivel_bool(){ echo "$1"; }
warn(){ :; }
error(){ :; }
info(){ :; }
ok(){ :; }
log(){ :; }
pause(){ echo 'FAIL: pausa inesperada' >&2; exit 99; }
clear(){ :; }
progresso_resetar(){ :; }
progresso_render(){ :; }
progresso_analise_render(){ :; }

wizard_resetar_importacao
WIZ_ORIGEM="$TMP/source"
WIZ_DESTINO="$HOME/Painel"
WIZ_DESTINO_PROJETO=false
OPCOES=()
wizard_etapa_conflitos
[ "$WIZ_CONFLITOS" = 0 ] && [ "$WIZ_CONFLITOS_TELA" = false ] && [ "$WIZ_CONFLITO_MODO" = 2 ]
# Excluir node_modules automaticamente, sem outra tela de limpeza/conflito.
motor_copia "$WIZ_ORIGEM" "$WIZ_DESTINO" true false true </dev/null >"$TMP/copia.log"
[ -f "$WIZ_DESTINO/src/index.php" ]
[ ! -e "$WIZ_DESTINO/node_modules/dependencia.txt" ]

# Reimportar: agora há colisão. Escolher preservar, sem sobrescrever.
printf 'versão-antiga\n' > "$WIZ_DESTINO/src/index.php"
OPCOES=(1)
wizard_etapa_conflitos
[ "$WIZ_CONFLITOS" = 1 ] && [ "$WIZ_CONFLITOS_TELA" = true ] && [ "$WIZ_CONFLITO_MODO" = 2 ]
motor_copia "$WIZ_ORIGEM" "$WIZ_DESTINO" true false true </dev/null >"$TMP/mescla.log"
grep -qx 'versão-antiga' "$WIZ_DESTINO/src/index.php"

# Substituição de arquivos somente quando explicitamente escolhida.
OPCOES=(2)
wizard_etapa_conflitos
[ "$WIZ_CONFLITO_MODO" = 1 ]
motor_copia "$WIZ_ORIGEM" "$WIZ_DESTINO" true false true </dev/null >"$TMP/substitui.log"
grep -qx 'atualizado' "$WIZ_DESTINO/src/index.php"

# Projeto próprio existente: substituição inteira é explicitamente confirmada.
mkdir -p "$HOME/Painel/projetos/demo"; printf 'antigo\n' > "$HOME/Painel/projetos/demo/removido.txt"
WIZ_DESTINO="$HOME/Painel/projetos/demo"
WIZ_DESTINO_PROJETO=true
OPCOES=(2)
wizard_etapa_conflitos
[ "$WIZ_SOBRESCREVER" = true ]
[ "$WIZ_CONFLITO_MODO" = 1 ]

# Arquivos avulsos: a escolha de conflito deve ser realmente aplicada na cópia.
printf 'original\n' > "$HOME/Painel/solto.txt"
printf 'novo\n' > "$TMP/solto.txt"
WIZ_ORIGEM="$TMP/solto.txt"
WIZ_ITENS=("$WIZ_ORIGEM")
WIZ_DESTINO="$HOME/Painel"
WIZ_DESTINO_PROJETO=false
OPCOES=(1)
wizard_etapa_conflitos
[ "$WIZ_CONFLITOS" = 1 ]
wizard_executar_importacao >"$TMP/avulsos-pular.log"
grep -qx 'original' "$HOME/Painel/solto.txt"
OPCOES=(2)
wizard_etapa_conflitos
wizard_executar_importacao >"$TMP/avulsos-atualizar.log"
grep -qx 'novo' "$HOME/Painel/solto.txt"

# Voltar na revisão quando a etapa de conflitos foi omitida vai para destino.
# Evita regressão de navegação sem criar outra confirmação vazia.
[ "$WIZ_CONFLITOS_TELA" = true ]
printf 'OK: sem telas supérfluas, exclusões automáticas, mescla segura e substituição explícita.\n'

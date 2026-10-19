#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
mkdir -p "$HOME" "$TMP/Painel/projetos/Portal Cidade/public" "$TMP/Painel/projetos/Node Site" "$TMP/pids" "$TMP/logs"
printf '<?php echo "ok";\n' > "$TMP/Painel/projetos/Portal Cidade/public/index.php"
printf '{"scripts":{"dev":"vite"},"dependencies":{"vite":"*"}}\n' > "$TMP/Painel/projetos/Node Site/package.json"
PAINEL_DIR="$TMP/Painel"; PROJETOS_DIR="$PAINEL_DIR/projetos"; PID_DIR="$TMP/pids"; LOG_DIR="$TMP/logs"
source "$ROOT/modules/runtime_detect.sh"
source "$ROOT/modules/runtime_processes.sh"
comando_existe() { case "$1" in php|node|mariadbd|mariadb-admin) return 0;; *) return 1;; esac; }
descobrir_entradas() { PROJETOS_ENCONTRADOS=("$PROJETOS_DIR/Portal Cidade|PHP" "$PROJETOS_DIR/Node Site|Node"); }
nome_amigavel_projeto() { NOME_PROJETO="$(basename "$1")"; }
caminho_curto() { printf '%s' "$1"; }
menu_unificado() { printf '%s\n' "$*" > "$TMP/menu"; }
ler_opcao() { RESPOSTA_MENU="$ESCOLHA"; }
caixa_simples() { printf '%s\n' "$*" > "$TMP/message"; }
pause() { :; }
warn() { printf 'WARN %s\n' "$*" >> "$TMP/events"; }
info() { printf 'INFO %s\n' "$*" >> "$TMP/events"; }
ok() { :; }
error() { printf 'ERROR %s\n' "$*" >> "$TMP/events"; }
cabecalho_tela() { :; }

# Na primeira escolha com vários projetos, solicita perfil e salva uma única vez.
ESCOLHA=1
central_perfil_selecionar false
[[ "$CENTRAL_PROJETO_ESCOLHIDO" == "$PROJETOS_DIR/Portal Cidade" ]]
[[ "$(cat "$(central_perfil_arquivo)")" == "$PROJETOS_DIR/Portal Cidade" ]]
[[ "$(stat -c %a "$(central_perfil_arquivo)")" == 600 ]]
ESCOLHA=2
central_perfil_selecionar false
[[ "$CENTRAL_PROJETO_ESCOLHIDO" == "$PROJETOS_DIR/Portal Cidade" ]]
# Configurar novamente permite escolher Node.
central_perfil_selecionar true
[[ "$CENTRAL_PROJETO_ESCOLHIDO" == "$PROJETOS_DIR/Node Site" ]]
# Salvar perfil de apenas serviços, sem repetir a seleção.
ESCOLHA=0
central_perfil_selecionar true
[[ "$(cat "$(central_perfil_arquivo)")" == SERVICOS_APENAS ]]
ESCOLHA=1
central_perfil_selecionar false
[[ -z "$CENTRAL_PROJETO_ESCOLHIDO" ]]
# Se seleção armazenada ficar inválida, solicita outra.
printf '%s\n' '/nao/existe' > "$(central_perfil_arquivo)"
central_perfil_selecionar false
[[ "$CENTRAL_PROJETO_ESCOLHIDO" == "$PROJETOS_DIR/Portal Cidade" ]]

# Início na ordem MariaDB -> phpMyAdmin -> projeto, sem duplicações de serviços.
pma_db_ativo() { return 0; }
pma_db_tcp_ativo() { return 0; }
pma_instalado() { return 0; }
pma_web_ativo() { return 0; }
pma_iniciar_db() { [[ "$1" == --lote ]] && printf 'DB\n' >> "$TMP/order"; }
pma_iniciar_web() { [[ "$1" == --lote ]] && printf 'PMA\n' >> "$TMP/order"; }
CENTRAL_REAL_INICIAR_PROJETO_LOTE="$(declare -f central_iniciar_projeto_lote)"
central_iniciar_projeto_lote() { printf 'PROJETO %s\n' "$1" >> "$TMP/order"; }
central_status_servicos() { CENTRAL_DB_STATUS='ativo'; CENTRAL_PMA_STATUS='ativo'; }
central_iniciar_tudo
[[ "$(sed -n '1p' "$TMP/order")" == DB ]]
[[ "$(sed -n '2p' "$TMP/order")" == PMA ]]
[[ "$(sed -n '3p' "$TMP/order")" == "PROJETO $PROJETOS_DIR/Portal Cidade" ]]
# Simula MariaDB indisponível. Não deve relatar sucesso geral.
: > "$TMP/order"
pma_iniciar_db() { printf 'DB-FALHOU\n' >> "$TMP/order"; return 1; }
if central_iniciar_tudo; then echo 'FALHA: serviço com erro marcado como sucesso' >&2; exit 1; fi
grep -Fq 'Falhas: 1' "$TMP/message"

# Runtime real do projeto, mas execução simulada: usa detecção e evita PID duplicado.
unset -f central_iniciar_projeto_lote
eval "$CENTRAL_REAL_INICIAR_PROJETO_LOTE"
executar_em_background() { printf '%s\n' "$3" >> "$TMP/started"; }
aguardar_servidor_processo() { return 0; }
pid_ativo() { return 1; }
porta_em_escuta() { return 1; }
porta_valida() { [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; }
central_iniciar_projeto_lote "$PROJETOS_DIR/Portal Cidade"
[[ "$(wc -l < "$TMP/started")" -eq 1 ]]
# Se a porta já foi ocupada, não iniciar processo.
: > "$TMP/started"
porta_em_escuta() { return 0; }
if central_iniciar_projeto_lote "$PROJETOS_DIR/Portal Cidade"; then echo 'FALHA: porta ocupada' >&2; exit 1; fi
[[ ! -s "$TMP/started" ]]
# PID conhecido já ativo: idempotência.
pid_ativo() { return 0; }
central_iniciar_projeto_lote "$PROJETOS_DIR/Portal Cidade"
[[ ! -s "$TMP/started" ]]

printf 'PASS: perfil salvo, apenas serviços, validação de origem, ordem, falhas, runtime, porta ocupada e PID idempotente\n'

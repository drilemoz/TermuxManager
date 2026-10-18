#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/Painel" "$TMP/pids"
PID_DIR="$TMP/pids"
PAINEL_DIR="$TMP/Painel"
PROJETOS_DIR="$PAINEL_DIR/projetos"
LOG_DIR="$TMP/logs"
source "$ROOT/modules/runtime_processes.sh"

comando_existe() { case "$1" in php|node|mariadbd|mariadb-admin) return 0 ;; *) return 1 ;; esac; }
pma_db_ativo() { return 0; }
pma_db_tcp_ativo() { return 1; }
pma_instalado() { return 0; }
pma_web_ativo() { return 0; }
central_status_servicos
[[ "$CENTRAL_PHP_STATUS" == instalado && "$CENTRAL_NODE_STATUS" == instalado ]]
[[ "$CENTRAL_DB_STATUS" == *"TCP 3306 indisponível"* ]]
[[ "$CENTRAL_PMA_STATUS" == "servidor ativo"* ]]

# PHP simples, Node frontend e aplicação desconhecida.
mkdir -p "$PAINEL_DIR/Portal Cidade/public" "$PAINEL_DIR/WebApp" "$PAINEL_DIR/Outro"
printf '<?php echo 1;\n' > "$PAINEL_DIR/Portal Cidade/public/index.php"
printf '{"scripts":{"dev":"vite"},"dependencies":{"vite":"1"}}' > "$PAINEL_DIR/WebApp/package.json"
printf '# nenhum executável\n' > "$PAINEL_DIR/Outro/README.md"
# O detetor precisa ser carregado para testar estruturas reais.
source "$ROOT/modules/runtime_detect.sh"
central_projeto_compativel "$PAINEL_DIR/Portal Cidade" php
if central_projeto_compativel "$PAINEL_DIR/Portal Cidade" node; then exit 1; fi
central_projeto_compativel "$PAINEL_DIR/WebApp" node
if central_projeto_compativel "$PAINEL_DIR/WebApp" php; then exit 1; fi
if central_projeto_compativel "$PAINEL_DIR/Outro" php; then exit 1; fi
if central_projeto_compativel "$PAINEL_DIR/Outro" node; then exit 1; fi

# Testar a escolha sem instalar pacotes, iniciar processos ou acessar rede.
descobrir_entradas() {
  PROJETOS_ENCONTRADOS=("$PAINEL_DIR/Portal Cidade|test" "$PAINEL_DIR/WebApp|test" "$PAINEL_DIR/Outro|test")
}
nome_amigavel_projeto() { NOME_PROJETO="$(basename "$1")"; }
caminho_curto() { printf '%s' "$1"; }
menu_unificado() { printf '%s\n' "$*" > "$TMP/menu"; }
ler_opcao() { RESPOSTA_MENU="$TEST_ESCOLHA"; }
testar_projeto() { printf '%s\n' "$1" > "$TMP/selected"; }
caixa_simples() { printf '%s\n' "$*" > "$TMP/box"; }
pause() { :; }
warn() { :; }
TEST_ESCOLHA=1
central_iniciar_projeto php
[[ "$(cat "$TMP/selected")" == "$PAINEL_DIR/Portal Cidade" ]]
[[ "$(cat "$TMP/menu")" == *"Portal Cidade"* ]]
[[ "$(cat "$TMP/menu")" != *"WebApp"* ]]
rm -f "$TMP/selected"
central_iniciar_projeto node
[[ "$(cat "$TMP/selected")" == "$PAINEL_DIR/WebApp" ]]
[[ "$(cat "$TMP/menu")" != *"Portal Cidade"* ]]
TEST_ESCOLHA=0
rm -f "$TMP/selected"
central_iniciar_projeto php
[[ ! -f "$TMP/selected" ]]
TEST_ESCOLHA=4
central_iniciar_projeto php
[[ ! -f "$TMP/selected" ]]

# Menu deve manter atalhos sem processos monitorados; 'A' não pode parar MariaDB.
limpar_pidfiles_inativos() { :; }
cabecalho_tela() { printf 'header %s\n' "$*" >> "$TMP/screens"; }
caixa_linha_topo() { :; }
caixa_linha_baixo() { :; }
menu_opcao() { printf 'opt %s %s\n' "$1" "$3" >> "$TMP/screens"; }
rodape_atalhos() { :; }
confirmar_acao() { echo 'should not stop MariaDB' > "$TMP/wrong"; return 1; }
pma_iniciar_db() { printf 'db-start\n' >> "$TMP/actions"; }
pma_parar_web() { printf 'web-stop\n' >> "$TMP/actions"; }
pma_abrir_web() { printf 'open-web\n' >> "$TMP/actions"; }
central_iniciar_projeto() { printf 'start-%s\n' "$1" >> "$TMP/actions"; }
# No menu, não deixar digitar a próxima opção no fluxo das ações.
SEQ=(p n d m w r a 0)
CURRENT=0
ler_opcao() { RESPOSTA_MENU="${SEQ[$CURRENT]}"; CURRENT=$((CURRENT+1)); }
menu_processos_ativos
[[ "$CURRENT" == 8 ]]
[[ ! -e "$TMP/wrong" ]]
for expected in start-php start-node db-start web-stop open-web; do
  grep -Fxq "$expected" "$TMP/actions" || { echo "faltou $expected" >&2; exit 1; }
done
for opt in P N D M W R; do
  grep -Fq "opt $opt " "$TMP/screens" || { echo "faltou atalho $opt" >&2; exit 1; }
done
grep -q 'Nenhum processo de projeto' "$TMP/box"

# Projeto em execução deve continuar aparecendo por número, permitindo gerenciar.
printf '12345\n' > "$PID_DIR/painel_backend.pid"
pid_ativo() { return 0; }
estado_servidor_processo() { PORTA_PROCESSO=8000; ESTADO_PROCESSO="servidor disponível"; ICONE_PROCESSO="🟢"; }
tela_execucao() { printf '%s\n' "$1" > "$TMP/selected_process"; }
SEQ=(1 0); CURRENT=0
menu_processos_ativos
[[ "$(cat "$TMP/selected_process")" == painel_backend ]]
grep -q 'opt 1 ' "$TMP/screens"
printf 'PASS: central de execução, status separado, projetos filtrados, confirmações e atalhos\n'

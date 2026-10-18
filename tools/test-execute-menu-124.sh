#!/usr/bin/env bash
# Regressão do menu Executar: opções não existentes não podem ser selecionadas.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
source "$ROOT/modules/runtime_processes.sh"
TEST_MENU="$TMP/menu.txt"
TEST_ACT="$TMP/acao.txt"
menu_unificado() { printf '%s\n' "$@" > "$TEST_MENU"; }
ler_opcao() { RESPOSTA_MENU="$TEST_CHOICE"; }
nome_processo_projeto() { NOME_PROCESSO="teste_$2"; }
executar_em_background() { printf 'EXEC:%s:%s:%s\n' "$1" "$2" "$5" >> "$TEST_ACT"; }
aguardar_backend_local() { printf 'HEALTH:%s\n' "$2" >> "$TEST_ACT"; return 0; }
esperar_porta_e_abrir() { printf 'FRONT:%s\n' "$1" >> "$TEST_ACT"; }
porta_processo() { printf '8000'; }
porta_valida() { [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; }
abrir_navegador() { printf 'URL:%s\n' "$1" >> "$TEST_ACT"; }
confirmar_inicio() { return 0; }
pause() { :; }
error() { printf 'ERROR:%s\n' "$*" >> "$TEST_ACT"; }
warn() { printf 'WARN:%s\n' "$*" >> "$TEST_ACT"; }
info() { :; }
setup_case() { : > "$TEST_ACT"; : > "$TEST_MENU"; }
assert_menu_contains() { grep -Fq -- "$1" "$TEST_MENU" || { echo "Menu não contém: $1" >&2; cat "$TEST_MENU" >&2; exit 1; }; }
assert_menu_lacks() { ! grep -Fq -- "$1" "$TEST_MENU" || { echo "Menu contém indevidamente: $1" >&2; cat "$TEST_MENU" >&2; exit 1; }; }
assert_act_contains() { grep -Fq -- "$1" "$TEST_ACT" || { echo "Ação não executada: $1" >&2; cat "$TEST_ACT" >&2; exit 1; }; }
assert_act_empty() { [[ ! -s "$TEST_ACT" ]] || { echo 'Executou algo inesperado:' >&2; cat "$TEST_ACT" >&2; exit 1; }; }

FRONT_DIR=''; FRONT_FRAMEWORK=''; FRONT_RUN_CMD=''
BACK_DIR="$TMP/IguaNews"; BACK_FRAMEWORK='PHP'; BACK_RUN_CMD='php -S 127.0.0.1:8000 -t public'
TEST_CHOICE=1; setup_case; menu_executar_projeto "$BACK_DIR"
assert_menu_contains '1|🧰|Iniciar site PHP|Iniciar PHP'
assert_menu_contains '[1] Executar'
assert_menu_lacks 'Executar frontend'
assert_menu_lacks '2|'
assert_menu_lacks '[1–3]'
assert_act_contains "EXEC:$BACK_DIR:php -S 127.0.0.1:8000 -t public:backend"
assert_act_contains 'URL:http://127.0.0.1:8000'
echo 'OK: PHP puro opção 1 inicia servidor e abre navegador'

TEST_CHOICE=2; setup_case; menu_executar_projeto "$BACK_DIR"
assert_act_contains 'WARN:Opção inválida.'
if grep -q '^EXEC:' "$TEST_ACT"; then echo 'ERRO: opção oculta 2 iniciou backend' >&2; exit 1; fi
echo 'OK: opção oculta é inválida'

TEST_CHOICE=0; setup_case; menu_executar_projeto "$BACK_DIR"
if grep -q '^EXEC:' "$TEST_ACT"; then echo 'ERRO: cancelamento iniciou backend' >&2; exit 1; fi
echo 'OK: cancelamento respeitado'

BACK_FRAMEWORK='Laravel'; BACK_RUN_CMD='php artisan serve --host=127.0.0.1 --port=8000'
TEST_CHOICE=1; setup_case; menu_executar_projeto "$BACK_DIR"
assert_menu_contains '1|🧰|Iniciar site PHP|Iniciar Laravel'
assert_act_contains 'EXEC:'
echo 'OK: Laravel backend único'

BACK_FRAMEWORK='Python'; BACK_RUN_CMD='python -m http.server 8000'
TEST_CHOICE=1; setup_case; menu_executar_projeto "$BACK_DIR"
assert_menu_contains '1|🧰|Executar backend|Iniciar Python'
assert_act_contains 'EXEC:'
echo 'OK: backend Python único'

BACK_DIR=''; BACK_FRAMEWORK=''; BACK_RUN_CMD=''
FRONT_DIR="$TMP/frontend"; FRONT_FRAMEWORK='Vite'; FRONT_RUN_CMD='npm run dev'
TEST_CHOICE=1; setup_case; menu_executar_projeto "$FRONT_DIR"
assert_menu_contains '1|🌐|Executar frontend|Iniciar Vite'
assert_menu_lacks 'Executar backend'
assert_menu_lacks '2|'
assert_act_contains "EXEC:$FRONT_DIR:npm run dev:frontend"
assert_act_contains 'FRONT:teste_frontend'
echo 'OK: frontend único'

BACK_DIR="$TMP/backend"; BACK_FRAMEWORK='Express'; BACK_RUN_CMD='npm run start'
TEST_CHOICE=2; setup_case; menu_executar_projeto "$FRONT_DIR"
assert_menu_contains '1|🌐|Executar frontend'
assert_menu_contains '2|🧰|Executar backend|Iniciar Express'
assert_menu_contains '3|🧩|Executar sistema'
assert_act_contains "EXEC:$BACK_DIR:npm run start:backend"
if grep -q 'FRONT:' "$TEST_ACT"; then echo 'ERRO: backend abriu frontend' >&2; exit 1; fi
echo 'OK: fullstack opção 2 inicia apenas backend'

TEST_CHOICE=3; setup_case; menu_executar_projeto "$FRONT_DIR"
assert_act_contains "EXEC:$BACK_DIR:npm run start:backend"
assert_act_contains "EXEC:$FRONT_DIR:npm run dev:frontend"
assert_act_contains 'FRONT:teste_frontend'
echo 'OK: fullstack opção 3 inicia os dois'

echo 'OK: regressões menu executar 1.0.124 aprovadas.'

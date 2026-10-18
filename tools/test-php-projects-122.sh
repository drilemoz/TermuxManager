#!/usr/bin/env bash
# Regressão PHP puro, Composer, public/index.php e integração HTTP local.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap '[[ -n "${PHP_SERVER_PID:-}" ]] && kill "$PHP_SERVER_PID" 2>/dev/null || true; rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
mkdir -p "$HOME/Painel/projetos" "$TMP/empty"
source "$ROOT_DIR/modules/core.sh"
source "$ROOT_DIR/modules/runtime.sh"
source "$ROOT_DIR/modules/projects.sh"
info(){ :; }; warn(){ :; }; error(){ :; }; ok(){ :; }; log(){ :; }

pure="$HOME/Painel/projetos/portal-simples"
mkdir -p "$pure"
printf '<?php echo "PORTAL_TESTE_OK";\n' > "$pure/index.php"
printf 'PORTAL_SECRET=nao-publicar\n' > "$pure/.env"
eh_projeto_valido "$pure"
detectar_estrutura_projeto "$pure"
[[ "$PROJ_MODO" == 'simples_backend' && "$BACK_FRAMEWORK" == 'PHP' ]] 
[[ "$BACK_GERENCIADOR" == 'php' && "$BACK_RUN_CMD" == 'php -S 127.0.0.1:8000' ]]
php -v >/dev/null 2>&1 || { echo 'PHP não disponível para teste'; exit 1; }
instalar_dependencias "$pure" php >/dev/null
verificar_instalacao "$pure" php >/dev/null
[[ ! -d "$pure/vendor" ]]

public="$HOME/Painel/projetos/portal-publico"
mkdir -p "$public/public" "$public/config"
printf '<?php echo "PUBLIC_OK";\n' > "$public/public/index.php"
printf 'DB_PASSWORD=SEGREDO\n' > "$public/.env"
eh_projeto_valido "$public"
detectar_estrutura_projeto "$public"
[[ "$BACK_RUN_CMD" == 'php -S 127.0.0.1:8000 -t public' ]]
port="$(porta_esperada_execucao "$public" "$BACK_RUN_CMD" backend)"
[[ "$port" == '8000' ]]
PHP_TEST_PORT=$((20000 + RANDOM % 20000))
( cd "$public" && php -S "127.0.0.1:$PHP_TEST_PORT" -t public >"$TMP/php.log" 2>&1 ) & PHP_SERVER_PID=$!
for i in {1..25}; do
    if curl --noproxy "*" -fsS "http://127.0.0.1:$PHP_TEST_PORT/" >"$TMP/output" 2>/dev/null; then break; fi
    sleep 0.1
done
grep -qx 'PUBLIC_OK' "$TMP/output" || { cat "$TMP/php.log"; exit 1; }
http_status="$(curl -s -o "$TMP/env-out" -w '%{http_code}' "http://127.0.0.1:$PHP_TEST_PORT/.env")"
# O servidor embutido pode encaminhar URLs inexistentes ao index.php.
# O importante é que o arquivo fora de public/ não seja disponibilizado.
[[ "$http_status" == '200' || "$http_status" == '404' ]]
! grep -q 'SEGREDO' "$TMP/env-out"
kill "$PHP_SERVER_PID" 2>/dev/null || true; wait "$PHP_SERVER_PID" 2>/dev/null || true; PHP_SERVER_PID=''

legacy="$HOME/Painel/projetos/legacy"
mkdir -p "$legacy"
printf '<?php echo 1;\n' > "$legacy/admin.php"
eh_projeto_valido "$legacy"
detectar_stack "$legacy"
[[ "$DETECT_FRAMEWORK" == PHP && "$DETECT_GERENCIADOR" == php ]]

composer="$HOME/Painel/projetos/composer"
mkdir -p "$composer"
printf '{"require":{"monolog/monolog":"^3.0"}}\n' > "$composer/composer.json"
detectar_stack "$composer"
[[ "$DETECT_GERENCIADOR" == composer && "$DETECT_FRAMEWORK" == PHP ]]

laravel="$HOME/Painel/projetos/laravel"
mkdir -p "$laravel"; touch "$laravel/artisan"
printf '{"require":{"laravel/framework":"^12.0"}}\n' > "$laravel/composer.json"
detectar_stack "$laravel"
[[ "$DETECT_GERENCIADOR" == composer && "$DETECT_FRAMEWORK" == Laravel ]]
[[ "$DETECT_RUN_CMD" == *'--host=127.0.0.1'* ]]

mono="$HOME/Painel/projetos/mono"
mkdir -p "$mono/backend" "$mono/frontend"
printf '<?php echo 1;\n' > "$mono/backend/index.php"
printf '{"scripts":{"dev":"vite"},"dependencies":{"vite":"^6.0.0"}}' > "$mono/frontend/package.json"
eh_projeto_valido "$mono"
detectar_estrutura_projeto "$mono"
[[ "$PROJ_MODO" == fullstack && "$BACK_FRAMEWORK" == PHP ]]

! eh_projeto_valido "$TMP/empty"
descobrir_entradas
[[ ${#PROJETOS_ENCONTRADOS[@]} -ge 5 ]]

# PORT do .env não substitui a porta explícita do servidor PHP.
printf 'PORT=9999\n' >> "$public/.env"
[[ "$(porta_esperada_execucao "$public" 'php -S 127.0.0.1:8000 -t public' backend)" == 8000 ]]
echo 'OK: PHP puro, composer, Laravel, public/, monorepo, dependências, descoberta e HTTP local.'

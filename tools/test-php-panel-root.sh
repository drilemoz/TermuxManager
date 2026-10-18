#!/usr/bin/env bash
# Regressão: um portal PHP importado diretamente no Painel não vira 4 projetos.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'cd /; rm -rf -- "$TMP"' EXIT
export HOME="$TMP/home"
PAINEL_DIR="$HOME/Painel"
PROJETOS_DIR="$PAINEL_DIR/projetos"
BACKUPS_DIR="$PAINEL_DIR/backups"
mkdir -p "$PROJETOS_DIR" "$BACKUPS_DIR"
# shellcheck disable=SC1090
source "$ROOT/modules/runtime_detect.sh"
# shellcheck disable=SC1090
source "$ROOT/modules/projects.sh"

reset_painel() {
    find "$PAINEL_DIR" -mindepth 1 -maxdepth 1 ! -name projetos ! -name backups -exec rm -rf -- {} +
    find "$PROJETOS_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
}
check() {
    local esperado="$1" caso="$2"
    descobrir_entradas
    [[ ${#PROJETOS_ENCONTRADOS[@]} == "$esperado" ]] || {
        printf 'FALHA [%s]: esperado %s projetos, retornou %s: %s\n' "$caso" "$esperado" "${#PROJETOS_ENCONTRADOS[@]}" "${PROJETOS_ENCONTRADOS[*]}" >&2
        exit 1
    }
    echo "OK: $caso"
}

# IguaNews: portal PHP sem Composer, achatado durante a importação.
mkdir -p "$PAINEL_DIR"/{app,bin,public,tests}
printf '<?php\n' > "$PAINEL_DIR/app/bootstrap.php"
printf '<?php\n' > "$PAINEL_DIR/bin/backup.php"
printf '<?php echo "ok";\n' > "$PAINEL_DIR/public/index.php"
printf '<?php\n' > "$PAINEL_DIR/tests/smoke.php"
check 1 'portal PHP achatado'
[[ ${PROJETOS_ENCONTRADOS[0]%%|*} == "$PAINEL_DIR" ]]
detectar_estrutura_projeto "$PAINEL_DIR"
[[ "$PROJ_MODO" == simples_backend && "$BACK_DIR" == "$PAINEL_DIR" && "$BACK_FRAMEWORK" == PHP ]] || {
    echo 'FALHA: portal foi detectado como frontend/fullstack incorretamente' >&2
    exit 1
}
[[ "$(php_document_root "$PAINEL_DIR")" == public ]]
echo 'OK: modo PHP backend e docroot public'

# Diretório de outro projeto também deve aparecer, sem perder a raiz.
mkdir -p "$PAINEL_DIR/loja"
printf '<?php\n' > "$PAINEL_DIR/loja/index.php"
check 2 'projeto independente preservado'
[[ ${PROJETOS_ENCONTRADOS[1]%%|*} == "$PAINEL_DIR/loja" ]]

# Um app/ isolado não pode virar "Projeto do Painel".
reset_painel
mkdir -p "$PAINEL_DIR/app"
printf '<?php\n' > "$PAINEL_DIR/app/index.php"
check 1 'app isolado'
[[ ${PROJETOS_ENCONTRADOS[0]%%|*} == "$PAINEL_DIR/app" ]]

# Mesmo projeto na pasta própria, fluxo recomendado.
reset_painel
mkdir -p "$PROJETOS_DIR/IguaNews"/{app,bin,public,tests}
printf '<?php\n' > "$PROJETOS_DIR/IguaNews/public/index.php"
printf '<?php\n' > "$PROJETOS_DIR/IguaNews/app/bootstrap.php"
check 1 'projeto em Painel/projetos/IguaNews'
[[ ${PROJETOS_ENCONTRADOS[0]%%|*} == "$PROJETOS_DIR/IguaNews" ]]

# Projetos Node independentes no mesmo Painel não devem virar um projeto PHP.
reset_painel
mkdir -p "$PAINEL_DIR/siteA" "$PAINEL_DIR/siteB"
printf '{}\n' > "$PAINEL_DIR/siteA/package.json"
printf '{}\n' > "$PAINEL_DIR/siteB/package.json"
check 2 'projetos Node sem PHP isolados'

# Um site com entrada na própria raiz do Painel também é um projeto.
reset_painel
printf '<?php\n' > "$PAINEL_DIR/index.php"
check 1 'PHP diretamente na raiz do Painel'
[[ ${PROJETOS_ENCONTRADOS[0]%%|*} == "$PAINEL_DIR" ]]

# O código de segurança deve bloquear exclusão da pasta inteira.
# `projeto_caminho_exclusao_seguro` vem de projects_storage.sh.
if projeto_caminho_exclusao_seguro "$PAINEL_DIR"; then
    echo 'FALHA: exclusão do Painel não bloqueada' >&2; exit 1
else
    [[ $? == 2 ]] || { echo 'FALHA: código de erro da exclusão da raiz' >&2; exit 1; }
fi
echo 'OK: proteção contra exclusão da raiz'
# Copiar a raiz para sua subpasta projetos/ geraria cópia recursiva.
warn() { :; }; info() { :; }; pause() { :; }
if copiar_projeto_existente "$PAINEL_DIR"; then
    echo 'FALHA: cópia da raiz do Painel deveria ser bloqueada' >&2; exit 1
fi
echo 'OK: proteção contra cópia recursiva da raiz'
echo 'Concluído: testes de regressão PHP/Painel aprovados.'

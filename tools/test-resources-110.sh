#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
mkdir -p "$HOME"
source "$ROOT/modules/resources_monitor.sh"
for fn in recursos_memoria_livre_mib recursos_carga_cpu recursos_armazenamento_livre; do
    resultado="$($fn)"
    [ -n "$resultado" ]
    [[ "$resultado" != *$'\n'* ]]
done
# O modo econômico deixa claro que os valores são sob demanda e não percorre
# projetos nem processos no menu inicial.
grep -Fq 'if [ "${MODO_ECONOMICO:-false}" = true ]; then' "$ROOT/modules/app.sh"
grep -Fq 'Projetos e processos sob demanda' "$ROOT/modules/app.sh"
grep -Fq 'Ativos: $ativos' "$ROOT/modules/app.sh"
grep -Fq 'MODO_ECONOMICO=$MODO_ECONOMICO' "$ROOT/modules/config.sh"
grep -Fq '5) alternar_config_bool MODO_ECONOMICO' "$ROOT/modules/settings.sh"
grep -Fq 'source "$APP_MODULE_DIR/commands_favorites.sh"' "$ROOT/modules/app.sh"
grep -Fq 'source "$APP_MODULE_DIR/resources_monitor.sh"' "$ROOT/modules/app.sh"
grep -Fq 'https://github.com/termux/termux-x11' "$ROOT/modules/linux_x11.sh"
# A sintaxe não pode conter erros e o novo módulo é independente de Termux.
for f in "$ROOT"/modules/*.sh; do bash -n "$f"; done
echo 'OK: métricas sob demanda, configuração persistente e módulos carregados.'

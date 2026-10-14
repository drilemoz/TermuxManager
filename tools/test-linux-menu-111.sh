#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/modules/linux_ui.sh"
source "$ROOT_DIR/modules/linux_x11.sh"
linux_menu_configuracoes_distro() { registrar "config:$1"; }
linux_menu_pacotes_distro() { registrar "pacotes:$1"; }

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
EVENTS="$TMP_ROOT/events"
MENU_TEXT="$TMP_ROOT/menus"
: > "$EVENTS"; : > "$MENU_TEXT"
menu_unificado() {
    printf '%s\n' "$1" "$2" "$@" >> "$MENU_TEXT"
}
RESPOSTA_MENU=""
MENU_INDEX=0
MENU_INPUT=()
ler_opcao() {
    if [ "$MENU_INDEX" -ge "${#MENU_INPUT[@]}" ]; then
        echo 'menu solicitou opção inesperada' >&2
        return 1
    fi
    RESPOSTA_MENU="${MENU_INPUT[$MENU_INDEX]}"
    MENU_INDEX=$((MENU_INDEX + 1))
}
cenario() { MENU_INPUT=("$@"); MENU_INDEX=0; : > "$EVENTS"; : > "$MENU_TEXT"; }
registrar() { printf '%s\n' "$1" >> "$EVENTS"; }
feedback_curto() { registrar "aviso:$1"; }
warn() { registrar "aviso:$1"; }
pause() { :; }
cabecalho_tela() { :; }
caixa_simples() { :; }
caixa_simples_wrap() { :; }
caminho_curto() { printf '%s' "$1"; }
linux_avaliar_aparelho() { LINUX_PROFILE="BÁSICO"; }
linux_mostrar_perfil() { registrar compatibilidade; }
linux_instalar_distro() { registrar instalar_distro; }
linux_meus_linux() { registrar meus_linux; }
linux_restaurar_backup() { registrar restaurar_backup; }
linux_garantir_proot_distro() { return 0; }
linux_selecionar_instalada() { LINUX_DISTRO_ALIAS="debian"; return 0; }
linux_backup_distro() { registrar "backup:$1"; }
linux_iniciar_desktop() { registrar "desktop:${1:-selecao}"; }
linux_instalar_ambiente_grafico() { registrar desktop_instalar; }
linux_instalar_x11_companion() { registrar companion_instalar; }
linux_baixar_x11_apk() { registrar apk_baixar; }
linux_status_x11() { registrar x11_status; }
linux_parar_x11() { registrar x11_parar; }
linux_diagnostico_x11() { registrar x11_diagnostico; }
linux_exportar_log_downloads() { registrar log_para_downloads; }
linux_x11_apk_instalado() { return 1; }
linux_x11_companion_instalado() { return 1; }
linux_coletar_info_distro() {
    LINUX_INFO_NAME="Debian"; LINUX_INFO_STATE_ICON="⚪"; LINUX_INFO_STATE_LABEL="Parado"
    LINUX_INFO_HEALTH_ICON="✅"; LINUX_INFO_HEALTH_LABEL="OK"
    LINUX_INFO_SIZE="2 GB"; LINUX_INFO_ARCH="arm64"; LINUX_INFO_DESKTOPS="nenhum"
}
linux_abrir_terminal_distro() { registrar "terminal:$1"; }
linux_atualizar_distro() { registrar "atualizar:$1"; }
linux_exibir_diagnostico_distro() { registrar "diagnostico:$1"; }
linux_exibir_info_distro() { registrar "info:$1"; }
linux_encerrar_sessoes_distro() { registrar "parar:$1"; }
linux_resetar_distro() { registrar "reparar:$1"; }
linux_remover_distro() { registrar "remover:$1"; }
linux_coletar_instaladas() { LINUX_INSTALLED_DISTROS=(debian); }
menu_ambiente_proot() { registrar proot_diag; }
LINUX_LOG="/tmp/linux.log"

# A operação de restaurar só aparece após entrar em Backups.
cenario 4 2 0 0
menu_linux_celular
[ "$(cat "$EVENTS")" = 'restaurar_backup' ]
grep -q 'Backup e restauração' "$MENU_TEXT"
grep -q '💾 BACKUP DO LINUX' "$MENU_TEXT"
[ "$MENU_INDEX" -eq 4 ]

# Criar backup seleciona explicitamente a distribuição.
cenario 1 0 0
linux_menu_backups
[ "$(cat "$EVENTS")" = 'backup:debian' ]

# Status detalhado é consultado só quando solicitado, não na tela principal.
cenario 5 3 0 0
menu_linux_celular
[ ! -s "$EVENTS" ]
grep -q 'AJUDA DO LINUX' "$MENU_TEXT"
grep -q 'Status dos componentes' "$MENU_TEXT"

# A distro exibe quatro ações; opções de risco exigem entrar na manutenção.
cenario 6 1 0 0
menu_linux_distro debian
[ "$(cat "$EVENTS")" = 'backup:debian' ]
grep -q 'Manutenção e detalhes' "$MENU_TEXT"
grep -q 'Criar backup' "$MENU_TEXT"
[ "$MENU_INDEX" -eq 4 ]

cenario 4 0
menu_linux_distro debian
[ "$(cat "$EVENTS")" = 'desktop:debian' ]
cenario 2 0
menu_linux_distro debian
[ "$(cat "$EVENTS")" = 'pacotes:debian' ]
cenario 3 0
menu_linux_distro debian
[ "$(cat "$EVENTS")" = 'config:debian' ]

# X11: fluxo separado, sem confundir instalar companion com baixar APK.
cenario 1 1 2 0 0
menu_termux_x11
[ "$(cat "$EVENTS")" = $'companion_instalar\napk_baixar' ]
grep -q 'PREPARAR TERMUX:X11' "$MENU_TEXT"
grep -q 'Aplicativo Android (APK)' "$MENU_TEXT"

# Tela de suporte permite diagnóstico sem instalar nada.
cenario 4 3 0 0
menu_termux_x11
[ "$(cat "$EVENTS")" = 'x11_diagnostico' ]

# O log completo pode ser copiado tanto em Ajuda quanto em Suporte X11.
cenario 5 5 0 0
menu_linux_celular
[ "$(cat "$EVENTS")" = 'log_para_downloads' ]
grep -q 'Copiar log para Downloads' "$MENU_TEXT"

cenario 4 5 0 0
menu_termux_x11
[ "$(cat "$EVENTS")" = 'log_para_downloads' ]

# Invalid input must not dispatch other commands.
cenario 99 0
menu_linux_celular
[ "$(cat "$EVENTS")" = 'aviso:Opção inválida.' ]

echo 'OK: navegação Linux por tarefas, backup, manutenção, X11 e opções inválidas.'

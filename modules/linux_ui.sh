# Módulo: linux_ui.sh
# Menus e navegação do subsistema Linux no celular.

# As tarefas diárias ficam separadas das ações de manutenção, reduzindo o
# risco de escolher uma ação destrutiva por engano em telas pequenas.
linux_menu_manutencao_distro() {
    local alias="${1:-}" escolha
    [ -n "$alias" ] || return 1
    while true; do
        menu_unificado "🔧 Manutenção: $alias" "Backup, diagnóstico e ações avançadas" \
            "[0] Voltar  •  [1–6] Selecionar" \
            "1|💾|Criar backup|Salvar uma cópia em Downloads" \
            "2|🔎|Diagnóstico|Verificar problemas desta distro" \
            "3|ℹ️|Informações|Arquitetura, versão e espaço" \
            "4|⏹️|Encerrar sessões|Fechar processos desta distro" \
            "5|🩺|Reparar / reinstalar|Pode recriar a instalação" \
            "6|🗑️|Remover distribuição|Exclusão permanente, exige confirmação"
        ler_opcao
        escolha="$RESPOSTA_MENU"
        case "$escolha" in
            1) linux_backup_distro "$alias" ;;
            2) linux_exibir_diagnostico_distro "$alias" true ;;
            3) linux_exibir_info_distro "$alias" ;;
            4) linux_encerrar_sessoes_distro "$alias" ;;
            5) linux_resetar_distro "$alias" ;;
            6)
                linux_remover_distro "$alias"
                linux_coletar_instaladas || true
                if ! printf '%s\n' "${LINUX_INSTALLED_DISTROS[@]}" | grep -Fxq "$alias"; then
                    return 10 # Não existe mais: voltar à lista, não ao menu antigo.
                fi
                ;;
            0) return 0 ;;
            *) feedback_curto "Opção inválida." ;;
        esac
    done
}

menu_linux_distro() {
    local alias="${1:-}" escolha resultado
    [ -n "$alias" ] || return 1
    while true; do
        linux_coletar_info_distro "$alias" false
        menu_unificado "🐧 $LINUX_INFO_NAME" \
            "${LINUX_INFO_STATE_ICON} ${LINUX_INFO_STATE_LABEL} • ${LINUX_INFO_HEALTH_ICON} ${LINUX_INFO_HEALTH_LABEL}" \
            "[0] Minhas distribuições  •  [1–4] Selecionar" \
            "1|⌨️|Abrir terminal|Usar comandos dentro deste Linux" \
            "2|🖥️|Abrir área de trabalho|Interface gráfica via Termux:X11" \
            "3|🔄|Atualizar sistema|Atualizar pacotes desta distribuição" \
            "4|🔧|Manutenção e detalhes|Backup, diagnóstico, sessões e remoção"
        ler_opcao
        escolha="$RESPOSTA_MENU"
        case "$escolha" in
            1) linux_abrir_terminal_distro "$alias" ;;
            2) linux_iniciar_desktop "$alias" ;;
            3) linux_atualizar_distro "$alias" ;;
            4)
                resultado=0
                linux_menu_manutencao_distro "$alias" || resultado=$?
                [ "$resultado" -eq 10 ] && return 0
                ;;
            0) return 0 ;;
            *) feedback_curto "Opção inválida." ;;
        esac
    done
}

linux_meus_linux() {
    local i escolha alias resumo estado saude tamanho arch desktops
    linux_garantir_proot_distro || { pause; return 1; }
    while true; do
        linux_coletar_instaladas || true
        if [ ${#LINUX_INSTALLED_DISTROS[@]} -eq 0 ]; then
            cabecalho_tela "🐧 Meus Linux" "Distribuições instaladas"
            caixa_simples "📭 Nenhuma distribuição instalada" \
                "Ainda não existe um Linux instalado neste aparelho." \
                "O Manager pode abrir a instalação agora."
            if confirmar_acao "Instalar uma distribuição agora?" "s"; then linux_instalar_distro; fi
            return 0
        fi

        local -a opcoes=()
        cabecalho_tela "🔎 Analisando distribuições" "Coletando tamanho, arquitetura e estado"
        printf '⏳ Verificando %d instalação(ões)...\n' "${#LINUX_INSTALLED_DISTROS[@]}"
        ui_buffer_flush 2>/dev/null || true
        for ((i=0; i<${#LINUX_INSTALLED_DISTROS[@]}; i++)); do
            alias="${LINUX_INSTALLED_DISTROS[$i]}"
            linux_coletar_info_distro "$alias" false
            resumo="${LINUX_INFO_STATE_ICON} ${LINUX_INFO_STATE_LABEL} • ${LINUX_INFO_HEALTH_ICON} ${LINUX_INFO_HEALTH_LABEL} • ${LINUX_INFO_SIZE} • ${LINUX_INFO_ARCH}"
            [ "$LINUX_INFO_DESKTOPS" != "nenhum" ] && resumo+=" • Desktop: $LINUX_INFO_DESKTOPS"
            opcoes+=("$((i+1))|🐧|$LINUX_INFO_NAME|$resumo")
        done
        menu_unificado "🐧 MEUS LINUX" "Escolha uma distribuição para administrar" \
            "[0] Voltar  •  [1–${#LINUX_INSTALLED_DISTROS[@]}] Abrir" "${opcoes[@]}"
        ler_opcao
        escolha="$RESPOSTA_MENU"
        [ "$escolha" = "0" ] && return 0
        if [[ "$escolha" =~ ^[0-9]+$ ]] && [ "$escolha" -ge 1 ] && [ "$escolha" -le ${#LINUX_INSTALLED_DISTROS[@]} ]; then
            menu_linux_distro "${LINUX_INSTALLED_DISTROS[$((escolha-1))]}"
        else
            feedback_curto "Opção inválida."
        fi
    done
}

# Backups do Linux via PRoot não são os mesmos backups de projetos do Manager.
linux_menu_backups() {
    local escolha
    while true; do
        menu_unificado "💾 BACKUP DO LINUX" "Cópia de uma distribuição PRoot inteira" \
            "[0] Voltar  •  [1–3] Selecionar" \
            "1|💾|Criar backup|Escolher um Linux instalado" \
            "2|♻️|Restaurar backup|Buscar em Downloads" \
            "3|ℹ️|Como funciona?|Formato, espaço e arquivos salvos"
        ler_opcao
        escolha="$RESPOSTA_MENU"
        case "$escolha" in
            1)
                linux_garantir_proot_distro || { pause; continue; }
                if linux_selecionar_instalada "💾 Criar backup" "Escolha qual Linux salvar"; then
                    linux_backup_distro "$LINUX_DISTRO_ALIAS"
                fi
                ;;
            2) linux_restaurar_backup ;;
            3)
                cabecalho_tela "💾 Backups Linux" "Distribuições PRoot"
                caixa_simples_wrap "O que será salvo" \
                    "A cópia contém os dados da distribuição Linux escolhida." \
                    "Use o menu Projetos para backups dos seus projetos do Manager." \
                    "O arquivo pode ser grande. Confirme o espaço antes de prosseguir." \
                    "Ao restaurar, confira também espaço disponível e nome da distribuição."
                pause
                ;;
            0) return 0 ;;
            *) feedback_curto "Opção inválida." ;;
        esac
    done
}

linux_menu_ajuda_diagnostico() {
    local escolha perfil status_proot status_x11 instaladas
    while true; do
        menu_unificado "🩺 AJUDA DO LINUX" "Requisitos, estado e problemas comuns" \
            "[0] Voltar  •  [1–4] Selecionar" \
            "1|📱|Compatibilidade|Memória, CPU e espaço no aparelho" \
            "2|🩺|Ambiente PRoot|Diagnosticar e reparar" \
            "3|ℹ️|Status dos componentes|PRoot, X11 e distribuições" \
            "4|❓|Entenda Linux e X11|Diferença entre terminal e desktop"
        ler_opcao
        escolha="$RESPOSTA_MENU"
        case "$escolha" in
            1) linux_avaliar_aparelho; linux_mostrar_perfil ;;
            2) menu_ambiente_proot ;;
            3)
                linux_avaliar_aparelho
                perfil="${LINUX_PROFILE:-indisponível}"
                status_proot="ausente"; status_x11="ausente"; instaladas=0
                command -v proot-distro >/dev/null 2>&1 && status_proot="disponível"
                linux_x11_companion_instalado && status_x11="disponível"
                if command -v proot-distro >/dev/null 2>&1; then
                    linux_coletar_instaladas || true
                    instaladas=${#LINUX_INSTALLED_DISTROS[@]}
                fi
                cabecalho_tela "ℹ️ Linux no celular" "Estado dos componentes"
                caixa_simples "Status" \
                    "Perfil: $perfil" \
                    "Distribuições instaladas: $instaladas" \
                    "proot-distro: $status_proot" \
                    "Termux:X11 companion: $status_x11" \
                    "Termux:X11 Android: $(linux_x11_apk_instalado && echo instalado || echo não detectado)" \
                    "Log: $(caminho_curto "$LINUX_LOG")"
                pause
                ;;
            4)
                cabecalho_tela "❓ Linux no celular" "Como as peças se encaixam"
                caixa_simples_wrap "1. Distribuição Linux" \
                    "Ubuntu, Debian etc. rodam no Termux via PRoot, sem root." \
                    "O terminal funciona sem interface gráfica."
                caixa_simples_wrap "2. Termux:X11" \
                    "É a janela gráfica do Android, não uma distribuição Linux." \
                    "Para ter desktop é preciso o APK, o companion e um desktop instalado na distro." \
                    "Comece por Meus Linux para entrar no terminal."
                pause
                ;;
            0) return 0 ;;
            *) feedback_curto "Opção inválida." ;;
        esac
    done
}

menu_linux_celular() {
    local escolha instaladas
    while true; do
        instaladas=0
        if command -v proot-distro >/dev/null 2>&1; then
            linux_coletar_instaladas || true
            instaladas=${#LINUX_INSTALLED_DISTROS[@]}
        fi
        menu_unificado "🐧 LINUX NO CELULAR" "Escolha o que deseja fazer" \
            "[0] Voltar  •  [1–5] Selecionar" \
            "1|🐧|Meus Linux|Abrir e administrar • $instaladas instalado(s)" \
            "2|⬇️|Instalar Linux|Ubuntu, Debian e outras distribuições" \
            "3|🖥️|Interface gráfica (X11)|Preparar e abrir desktop no Android" \
            "4|💾|Backup e restauração|Salvar ou recuperar distribuições" \
            "5|🩺|Ajuda e diagnóstico|Status, compatibilidade e reparos"
        ler_opcao
        escolha="$RESPOSTA_MENU"
        case "$escolha" in
            1) linux_meus_linux ;;
            2) linux_instalar_distro ;;
            3) menu_termux_x11 ;;
            4) linux_menu_backups ;;
            5) linux_menu_ajuda_diagnostico ;;
            0) return 0 ;;
            *) feedback_curto "Opção inválida." ;;
        esac
    done
}

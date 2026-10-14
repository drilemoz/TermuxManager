# Permissões de instalação APK. Sempre exige confirmação do usuário.
# Esta configuração permite maior integração de aplicativos externos com Termux.

linux_apk_properties() {
    printf '%s/.termux/termux.properties\n' "$HOME"
}

linux_apk_external_apps_ativo() {
    local props
    props="$(linux_apk_properties)"
    [ -f "$props" ] && [ ! -L "$props" ] || return 1
    awk '
      /^[[:space:]]*allow-external-apps[[:space:]]*=/ {
        sub(/^[^=]*=[[:space:]]*/, "", $0)
        sub(/[[:space:]]*$/, "", $0)
        ativo=($0 == "true")
      }
      END { exit(ativo ? 0 : 1) }
    ' "$props"
}

linux_apk_configurar_integracao() {
    local dir props backup estado tmp
    props="$(linux_apk_properties)"; dir="${props%/*}"
    backup="$dir/termux.properties.manager-backup"
    estado="$dir/termux.properties.manager-backup-state"
    if [ -L "$dir" ] || [ -L "$props" ] || [ -L "$backup" ] || [ -L "$estado" ]; then
        linux_log 'Permissões APK: caminho simbólico bloqueado'
        return 1
    fi
    ( umask 077; mkdir -p -- "$dir" ) || return 1
    chmod 700 "$dir" 2>/dev/null || true
    # A primeira alteração salva uma cópia imutável para reversão posterior.
    if [ ! -e "$estado" ]; then
        if [ -e "$props" ]; then
            [ -f "$props" ] || return 1
            ( umask 077; cp -- "$props" "$backup" ) || return 1
            chmod 600 "$backup" || return 1
            ( umask 077; printf 'presente\n' > "$estado" ) || return 1
        else
            ( umask 077; printf 'ausente\n' > "$estado" ) || return 1
        fi
    fi
    tmp="$(mktemp "$dir/.termux-properties-manager.XXXXXXXX")" || return 1
    if [ -f "$props" ]; then
        if ! awk '!/^[[:space:]]*allow-external-apps[[:space:]]*=/' "$props" > "$tmp"; then
            rm -f -- "$tmp"; return 1
        fi
    fi
    if ! printf '\nallow-external-apps=true\n' >> "$tmp"; then
        rm -f -- "$tmp"; return 1
    fi
    chmod 600 "$tmp" || { rm -f -- "$tmp"; return 1; }
    mv -f -- "$tmp" "$props" || { rm -f -- "$tmp"; return 1; }
    if command -v termux-reload-settings >/dev/null 2>&1; then
        termux-reload-settings || linux_log 'Permissões APK: configuração gravada, mas recarga não confirmada'
    fi
    linux_log 'Permissões APK: allow-external-apps habilitado mediante confirmação local'
    return 0
}

linux_apk_restaurar_integracao() {
    local dir props backup estado estado_salvo tmp
    props="$(linux_apk_properties)"; dir="${props%/*}"
    backup="$dir/termux.properties.manager-backup"
    estado="$dir/termux.properties.manager-backup-state"
    [ ! -L "$dir" ] && [ ! -L "$props" ] && [ ! -L "$backup" ] && [ ! -L "$estado" ] || return 1
    [ -f "$estado" ] || return 1
    estado_salvo="$(cat "$estado")" || return 1
    case "$estado_salvo" in
        presente)
            [ -f "$backup" ] || return 1
            tmp="$(mktemp "$dir/.termux-properties-manager.XXXXXXXX")" || return 1
            cp -- "$backup" "$tmp" || { rm -f -- "$tmp"; return 1; }
            chmod 600 "$tmp" || { rm -f -- "$tmp"; return 1; }
            mv -f -- "$tmp" "$props" || { rm -f -- "$tmp"; return 1; }
            ;;
        ausente) rm -f -- "$props" || return 1 ;;
        *) return 1 ;;
    esac
    rm -f -- "$backup" "$estado"
    if command -v termux-reload-settings >/dev/null 2>&1; then
        termux-reload-settings || linux_log 'Permissões APK: restauração concluída, recarga pendente'
    fi
    linux_log 'Permissões APK: configuração anterior restaurada'
}

linux_apk_abrir_config_android() {
    local saida rc=0
    if ! command -v am >/dev/null 2>&1; then return 1; fi
    if saida="$(am start --user 0 -a android.settings.MANAGE_UNKNOWN_APP_SOURCES -d package:com.termux 2>&1)"; then
        rc=0
    else
        rc=$?
    fi
    if [ "$rc" -ne 0 ] || grep -Eiq 'Error:|Exception|Permission Denial|unable to resolve|does not exist' <<< "$saida"; then
        linux_log "Permissões APK: Android não abriu ajustes (código=$rc): $(linux_x11_resumir_retorno_android "$saida")"
        return 1
    fi
    linux_log 'Permissões APK: Android recebeu solicitação de abrir tela de fontes desconhecidas'
}

linux_menu_permissoes_apk() {
    local escolha status arquivo
    arquivo="$(linux_apk_properties)"
    while true; do
        status='desativada ou não configurada'
        linux_apk_external_apps_ativo && status='ativada'
        menu_unificado '🔐 PERMISSÕES PARA APK' "Integração Termux: $status" \
            '[0] Voltar  •  [1–5] Selecionar' \
            '1|🔎|Verificar configuração|Conferir Termux e Android' \
            '2|🔓|Autorizar integração do Termux|Opcional, após confirmação' \
            '3|📱|Abrir permissão do Android|Permitir instalar APKs desta fonte' \
            '4|♻️|Restaurar configuração anterior|Recuperar backup do termux.properties' \
            '5|ℹ️|Como instalar APKs?|Ajuda e riscos da permissão'
        ler_opcao
        escolha="$RESPOSTA_MENU"
        case "$escolha" in
            1)
                cabecalho_tela '🔎 Permissões de APK' 'Situação atual'
                caixa_simples 'Termux' \
                    "allow-external-apps: $status" \
                    "Arquivo: $(caminho_curto "$arquivo")" \
                    'Esta opção NÃO equivale à permissão do Android.' \
                    'Não é possível confirmar a autorização do instalador por Bash sem ação do usuário.'
                pause ;;
            2)
                cabecalho_tela '⚠️ Integração externa' 'Permissão opcional e sensível'
                caixa_simples_wrap 'Antes de ativar' \
                    'Permite que aplicativos externos autorizados executem comandos no Termux via intents e acessem integrações como termux-open.' \
                    'Não conceda RUN_COMMAND a aplicativos não confiáveis.' \
                    'Será criado um backup privado das configurações atuais.' \
                    'A autorização do Android para instalar APKs continua sendo manual.'
                if confirmar_acao 'Ativar allow-external-apps no Termux?' 'n'; then
                    if linux_apk_configurar_integracao; then
                        ok 'Configuração ativada e salva. Confira a autorização no Android.'
                    else
                        error 'Não foi possível gravar a configuração com segurança.'
                    fi
                fi
                pause ;;
            3)
                cabecalho_tela '📱 Instalação de APKs' 'Autorização no Android'
                caixa_simples_wrap 'Ação obrigatória' \
                    'O Android exige uma autorização manual por fonte.' \
                    'Na tela que abrir, habilite Permitir desta fonte somente se confiar nos APKs.'
                if confirmar_acao 'Abrir a tela do Android agora?' 's'; then
                    if linux_apk_abrir_config_android; then
                        ok 'Android recebeu a solicitação. Confirme na tela do sistema.'
                    else
                        warn 'Não foi possível abrir diretamente as configurações.'
                        caixa_simples_wrap 'Alternativa' \
                            'Android > Configurações > Apps > Acesso especial > Instalar apps desconhecidos > Termux.'
                    fi
                fi
                pause ;;
            4)
                cabecalho_tela '♻️ Restaurar integração' 'Retorno ao estado anterior'
                caixa_simples_wrap 'Atenção' \
                    'Restaura o termux.properties salvo antes da primeira alteração.' \
                    'Alterações manuais posteriores nesse arquivo poderão ser perdidas.'
                if confirmar_acao 'Restaurar backup das configurações do Termux?' 'n'; then
                    if linux_apk_restaurar_integracao; then ok 'Configuração restaurada.'
                    else warn 'Nenhum backup válido encontrado ou restauração bloqueada.'; fi
                fi
                pause ;;
            5)
                cabecalho_tela 'ℹ️ Instalar APKs' 'Como as permissões funcionam'
                caixa_simples_wrap 'Permissões diferentes' \
                    '1. allow-external-apps permite integrações externas do Termux, como termux-open.' \
                    '2. Permitir desta fonte é controlada exclusivamente pelo Android.' \
                    'O Manager não consegue instalar APK silenciosamente nem conceder permissões do Android.'
                pause ;;
            0) return 0 ;;
            *) feedback_curto 'Opção inválida.' ;;
        esac
    done
}

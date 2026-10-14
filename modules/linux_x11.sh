# Módulo: linux_x11.sh
# Termux:X11 e ambientes gráficos das distribuições Linux.
# Extraído de linux.sh para reduzir acoplamento e facilitar manutenção.

TERMUX_X11_APK_URL="https://github.com/termux/termux-x11/releases/download/nightly/termux-x11-universal-debug.apk"
TERMUX_X11_APK_NAME="termux-x11-universal-debug.apk"

linux_x11_android_compativel() {
    local versao major
    versao="$(linux_android_versao)"
    major="${versao%%.*}"
    [[ "$major" =~ ^[0-9]+$ ]] || return 0
    [ "$major" -ge 8 ]
}

# Resultado de um teste de abertura bem-sucedido vale nesta execução do Manager.
# Não é gravado em arquivo: estado do Android pode mudar entre sessões.
LINUX_X11_ABERTURA_ESTADO=""
LINUX_X11_ABERTURA_ERRO=""
LINUX_X11_DETECCAO_METODO=""

linux_x11_resumir_retorno_android() {
    # Restringe a quantidade de texto do Android salva no log local.
    printf '%s' "$1" | tr '\r\n' '  ' | cut -c1-300
}

# Não confundir consulta indisponível com aplicativo desinstalado.
# As três consultas podem ser bloqueadas por políticas do Android; nenhuma
# exige root ou a permissão allow-external-apps.
linux_x11_consultar_apk_android() {
    local saida rc
    LINUX_X11_DETECCAO_METODO=""
    if command -v pm >/dev/null 2>&1; then
        if saida="$(pm path com.termux.x11 2>&1)"; then rc=0; else rc=$?; fi
        if [ "$rc" -eq 0 ] && grep -q '^package:' <<< "$saida"; then
            LINUX_X11_DETECCAO_METODO="pm path"
            return 0
        fi
    fi
    if command -v cmd >/dev/null 2>&1; then
        if saida="$(cmd package path com.termux.x11 2>&1)"; then rc=0; else rc=$?; fi
        if [ "$rc" -eq 0 ] && grep -q '^package:' <<< "$saida"; then
            LINUX_X11_DETECCAO_METODO="cmd package path"
            return 0
        fi
    fi
    if command -v pm >/dev/null 2>&1; then
        if saida="$(pm list packages --user 0 com.termux.x11 2>&1)"; then rc=0; else rc=$?; fi
        if [ "$rc" -eq 0 ] && grep -qx 'package:com.termux.x11' <<< "$saida"; then
            LINUX_X11_DETECCAO_METODO="pm list packages"
            return 0
        fi
    fi
    return 1
}

linux_x11_apk_instalado() {
    [ "${LINUX_X11_ABERTURA_ESTADO:-}" = "confirmada" ] && return 0
    linux_x11_consultar_apk_android
}

linux_x11_companion_instalado() {
    command -v termux-x11 >/dev/null 2>&1
}

linux_x11_apk_status_texto() {
    if [ "${LINUX_X11_ABERTURA_ESTADO:-}" = "confirmada" ]; then
        printf 'abertura confirmada no Android'
    elif linux_x11_consultar_apk_android; then
        printf 'detectado no Android'
    elif [ "${LINUX_X11_ABERTURA_ESTADO:-}" = "falhou" ]; then
        printf 'não confirmado; abertura falhou (ver log)'
    else
        printf 'não confirmado (pode estar instalado)'
    fi
}

# Apenas uma ação iniciada pelo usuário executa este teste real.
# am start é documentado pelo projeto Termux:X11. Aceitar somente retorno
# zero SEM mensagens explícitas de falha (alguns Androids retornam status 0
# apesar de exibirem "Error type 3" ou "Permission Denial").
linux_x11_testar_abertura_android() {
    local saida rc resumo
    if ! command -v am >/dev/null 2>&1; then
        LINUX_X11_ABERTURA_ESTADO="falhou"
        LINUX_X11_ABERTURA_ERRO="comando Android am não encontrado"
        linux_log "X11: não foi possível testar abertura: comando am ausente"
        return 1
    fi
    if saida="$(am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity 2>&1)"; then rc=0; else rc=$?; fi
    resumo="$(linux_x11_resumir_retorno_android "$saida")"
    if [ "$rc" -ne 0 ] || grep -Eiq '(Error:|Error type|Exception|Permission Denial|SecurityException|does not exist|not found|unable to resolve|unable to start)' <<< "$saida"; then
        LINUX_X11_ABERTURA_ESTADO="falhou"
        LINUX_X11_ABERTURA_ERRO="${resumo:-falha sem detalhes}"
        linux_log "X11: abertura Android FALHOU (status=$rc): $LINUX_X11_ABERTURA_ERRO"
        return 1
    fi
    LINUX_X11_ABERTURA_ESTADO="confirmada"
    LINUX_X11_ABERTURA_ERRO=""
    linux_log "X11: abertura Android confirmada por am start (status=$rc): $resumo"
    return 0
}

linux_x11_testar_abertura_menu() {
    cabecalho_tela "📲 Testar Termux:X11" "Abertura do aplicativo Android"
    caixa_simples "Teste prático" \
        "O Android tentará abrir o aplicativo Termux:X11." \
        "Este teste não reinstala o APK nem altera permissões." \
        "A abertura do aplicativo não garante que o desktop Linux esteja pronto."
    confirmar_acao "Abrir agora o aplicativo Termux:X11?" "s" || return 0
    if linux_x11_testar_abertura_android; then
        ok "Android aceitou o comando de abertura do Termux:X11."
        caixa_simples "Abertura solicitada" \
            "Se o aplicativo apareceu, o APK está instalado." \
            "Para mostrar o XFCE, abra Linux > Interface gráfica > Abrir desktop."
    else
        warn "O Android não conseguiu abrir o X11 automaticamente."
        caixa_simples "Falha no teste" \
            "Mensagem: ${LINUX_X11_ABERTURA_ERRO:-indisponível}" \
            "Isso não comprova que o APK esteja desinstalado." \
            "Confira o aplicativo na lista do Android e exporte o log em Suporte."
    fi
    pause
}

# Diagnóstico sob demanda, sem escrever logs a cada redesenho do menu.
linux_x11_registrar_consultas_android() {
    local saida rc metodo
    for metodo in 'pm path' 'cmd package path' 'pm list packages'; do
        case "$metodo" in
            'pm path')
                if ! command -v pm >/dev/null 2>&1; then
                    linux_log 'X11: pm path: comando indisponível'; continue
                fi
                if saida="$(pm path com.termux.x11 2>&1)"; then rc=0; else rc=$?; fi ;;
            'cmd package path')
                if ! command -v cmd >/dev/null 2>&1; then
                    linux_log 'X11: cmd package path: comando indisponível'; continue
                fi
                if saida="$(cmd package path com.termux.x11 2>&1)"; then rc=0; else rc=$?; fi ;;
            'pm list packages')
                if ! command -v pm >/dev/null 2>&1; then
                    linux_log 'X11: pm list packages: comando indisponível'; continue
                fi
                if saida="$(pm list packages --user 0 com.termux.x11 2>&1)"; then rc=0; else rc=$?; fi ;;
        esac
        # Não registrar caminhos privados /data/app; basta informar sucesso.
        if [ "$rc" -eq 0 ] && { grep -q '^package:' <<< "$saida"; }; then
            linux_log "X11: $metodo: pacote encontrado (status=0)"
        else
            linux_log "X11: $metodo: sem confirmação (status=$rc); $(linux_x11_resumir_retorno_android "$saida")"
        fi
    done
}

# Termux v0.118+ exige consentimento explícito para compartilhar arquivos
# usando termux-open/ContentProvider. Não modificar esta opção sem o usuário.
linux_x11_compartilhamento_permitido() {
    local arquivo="${HOME:-}/.termux/termux.properties"
    [ -f "$arquivo" ] && grep -Eq '^[[:space:]]*allow-external-apps[[:space:]]*=[[:space:]]*true[[:space:]]*(#.*)?$' "$arquivo"
}

linux_x11_instalacao_manual() {
    local destino="$1"
    caixa_simples "Instalar pelo Android" \
        "O APK já está salvo em Downloads." \
        "Abra o gerenciador de arquivos do Android > Downloads." \
        "Toque em $(basename -- "$destino") e escolha Instalar ou Atualizar." \
        "Se X11 já estiver instalado, não precisa baixar de novo."
}

linux_x11_abrir_instalador() {
    local destino="$1" retorno
    [ -s "$destino" ] || { error "APK ausente ou vazio: $destino"; return 1; }
    if ! command -v termux-open >/dev/null 2>&1; then
        linux_x11_instalacao_manual "$destino"
        return 1
    fi
    if ! linux_x11_compartilhamento_permitido; then
        warn "O Termux bloqueou a abertura automática do APK por segurança."
        caixa_simples "Permissão opcional do Termux" \
            "Para usar termux-open, edite ~/.termux/termux.properties:" \
            "allow-external-apps=true" \
            "Depois execute: termux-reload-settings" \
            "ATENÇÃO: esta opção amplia a integração de outros apps com o Termux." \
            "O Manager não habilitará essa permissão automaticamente."
        linux_x11_instalacao_manual "$destino"
        linux_log "X11: termux-open não executado sem consentimento allow-external-apps"
        return 1
    fi
    if termux-open --view --content-type application/vnd.android.package-archive "$destino"; then
        ok "Solicitação enviada ao Android. Confirme Instalar ou Atualizar na tela."
        return 0
    else
        retorno=$?
        linux_log "X11: abertura do instalador falhou (código $retorno)"
        warn "Não foi possível abrir o instalador automaticamente."
        linux_x11_instalacao_manual "$destino"
        return 1
    fi
}

linux_instalar_x11_companion() {
    cabecalho_tela "🖥️ Termux:X11" "Instalar componentes no Termux"
    if ! linux_x11_android_compativel; then
        caixa_simples "⚠ Android incompatível" \
            "O Termux:X11 requer Android 8 ou superior." \
            "Android detectado: $(linux_android_versao)"
        pause
        return 1
    fi
    if declare -F pacote_disponivel_termux >/dev/null 2>&1 && ! pacote_disponivel_termux x11-repo; then
        caixa_simples "⚠ x11-repo indisponível" \
            "O repositório gráfico não está disponível nos repositórios atuais do Termux." \
            "O Manager não tentará forçar uma instalação incompatível."
        pause
        return 1
    fi
    caixa_simples "Componentes" \
        "1. Repositório gráfico: x11-repo" \
        "2. Pacote companion: termux-x11-nightly" \
        "O aplicativo Android é instalado em uma etapa separada."
    confirmar_acao "Instalar componentes do Termux:X11?" "s" || return 0

    executar_pkg_monitorado "Preparando Termux:X11" 10 45 \
        "Habilitando repositório gráfico..." "Instalando x11-repo." -- install -y x11-repo || {
            mostrar_erro_pkg "Não foi possível instalar x11-repo."
            pause
            return 1
        }
    executar_pkg_monitorado "Preparando Termux:X11" 50 95 \
        "Instalando o companion do X11..." "Pacote termux-x11-nightly." -- install -y termux-x11-nightly || {
            mostrar_erro_pkg "Não foi possível instalar termux-x11-nightly."
            pause
            return 1
        }
    linux_log "Termux:X11 companion instalado"
    ok "Componentes do Termux:X11 instalados."
    pause
}

linux_baixar_x11_apk() {
    resolver_downloads_dir >/dev/null 2>&1 || true
    cabecalho_tela "📲 Aplicativo Termux:X11" "Baixar ou instalar APK oficial"
    local destino="$DOWNLOADS_DIR/$TERMUX_X11_APK_NAME" tmp="${DOWNLOADS_DIR}/.${TERMUX_X11_APK_NAME}.part"
    caixa_simples "Origem" \
        "Projeto oficial: termux/termux-x11" \
        "Arquivo: $TERMUX_X11_APK_NAME" \
        "Destino: $(caminho_curto "$destino")" \
        "O APK e o companion do Termux são instalações diferentes."
    if linux_x11_apk_instalado; then
        ok "O aplicativo Android Termux:X11 já foi detectado."
        confirmar_acao "Baixar ou reinstalar o APK mesmo assim?" "n" || { pause; return 0; }
    fi
    if [ -s "$destino" ]; then
        ok "Já existe um APK baixado em Downloads."
        if confirmar_acao "Usar o APK existente sem baixar novamente?" "s"; then
            linux_x11_abrir_instalador "$destino" || true
            pause
            return 0
        fi
    fi
    confirmar_acao "Baixar o APK oficial agora?" "s" || return 0
    if ! command -v curl >/dev/null 2>&1; then
        warn "curl não está instalado."
        confirmar_acao "Instalar curl agora?" "s" || return 1
        executar_pkg_monitorado "Instalando curl" 20 95 "Preparando download..." "Dependência necessária." -- install -y curl || return 1
    fi
    mkdir -p "$DOWNLOADS_DIR"
    rm -f "$tmp"
    # Preserve o status do curl mesmo em ambientes sem `pipefail`.
    if curl -fL --retry 3 --connect-timeout 20 --max-time 600 \
        -o "$tmp" "$TERMUX_X11_APK_URL" 2>&1 | tee -a "$LINUX_LOG"; then
        if [ ! -s "$tmp" ] || ! mv -f "$tmp" "$destino"; then
            rm -f "$tmp"
            error "APK baixado está vazio ou não pôde ser salvo."
            pause
            return 1
        fi
        linux_log "APK Termux:X11 baixado: $destino"
        ok "APK salvo em $(caminho_curto "$destino")."
        confirmar_acao "Abrir o instalador do Android agora?" "s" && linux_x11_abrir_instalador "$destino" || true
    else
        rm -f "$tmp"
        error "Falha ao baixar o APK do Termux:X11."
        printf 'Endereço usado: %s\n' "$TERMUX_X11_APK_URL"
    fi
    pause
}

linux_status_x11() {
    detectar_variante_termux 2>/dev/null || true
    linux_x11_registrar_consultas_android
    cabecalho_tela "🖥️ Status Termux:X11" "Componentes necessários"
    caixa_simples "Termux:X11" \
        "Companion no Termux: $(linux_x11_companion_instalado && echo instalado || echo ausente)" \
        "Aplicativo Android: $(linux_x11_apk_status_texto)" \
        "Consulta bloqueada NÃO significa APK ausente." \
        "Use Preparar X11 > Testar abertura do app." \
        "Origem do Termux: $(termux_origem_resumida)" \
        "Android: $(linux_android_versao)"
    caixa_simples "Observação" \
        "O APK padrão funciona independentemente de sharedUid." \
        "O modo sharedUid só deve ser usado com builds compatíveis e assinaturas correspondentes." \
        "O Manager usa o APK padrão por segurança e compatibilidade."
    pause
}

linux_detectar_gerenciador_distro() {
    local alias="${1:-}"
    [ -n "$alias" ] || return 1
    mkdir -p "$(dirname "$LINUX_LOG")" 2>/dev/null || true
    proot-distro login "$alias" -- /bin/sh -lc '
if command -v apt-get >/dev/null 2>&1; then
  printf "apt\n"
elif command -v pacman >/dev/null 2>&1; then
  printf "pacman\n"
elif command -v apk >/dev/null 2>&1; then
  printf "apk\n"
elif command -v dnf >/dev/null 2>&1; then
  printf "dnf\n"
elif command -v zypper >/dev/null 2>&1; then
  printf "zypper\n"
else
  printf "desconhecido\n"
fi' 2>>"$LINUX_LOG" | tail -n 1
}

linux_descrever_gerenciador_distro() {
    case "${1:-desconhecido}" in
        apt) printf 'APT (Debian/Ubuntu)' ;;
        pacman) printf 'Pacman (Arch)' ;;
        apk) printf 'APK (Alpine)' ;;
        dnf) printf 'DNF (Fedora/Rocky)' ;;
        zypper) printf 'Zypper (openSUSE)' ;;
        *) printf 'Não reconhecido' ;;
    esac
}

linux_desktop_nome() {
    case "${1:-}" in
        xfce) printf 'XFCE' ;;
        lxqt) printf 'LXQt' ;;
        lxde) printf 'LXDE' ;;
        mate) printf 'MATE' ;;
        openbox) printf 'Openbox' ;;
        i3) printf 'i3' ;;
        kde) printf 'KDE Plasma' ;;
        gnome) printf 'GNOME' ;;
        *) printf '%s' "${1:-desconhecido}" ;;
    esac
}

linux_desktop_launcher() {
    case "${1:-}" in
        xfce) printf 'xfce4-session' ;;
        lxqt) printf 'startlxqt' ;;
        lxde) printf 'startlxde' ;;
        mate) printf 'mate-session' ;;
        openbox) printf 'openbox-session' ;;
        i3) printf 'i3' ;;
        kde) printf 'startplasma-x11' ;;
        gnome) printf 'gnome-session' ;;
        *) return 1 ;;
    esac
}

linux_desktop_peso() {
    case "${1:-}" in
        openbox|i3) printf 'muito leve' ;;
        lxde) printf 'muito leve' ;;
        xfce|lxqt) printf 'leve' ;;
        mate) printf 'médio' ;;
        kde) printf 'pesado' ;;
        gnome) printf 'muito pesado' ;;
        *) printf 'desconhecido' ;;
    esac
}

linux_desktop_descricao() {
    case "${1:-}" in
        xfce) printf 'Leve, completo e com ótima compatibilidade' ;;
        lxqt) printf 'Leve e com visual moderno' ;;
        lxde) printf 'Muito leve para aparelhos modestos' ;;
        mate) printf 'Desktop tradicional com consumo médio' ;;
        openbox) printf 'Janela mínima e extremamente leve' ;;
        i3) printf 'Tiling muito leve, focado em teclado' ;;
        kde) printf 'Visual avançado, exige mais RAM e CPU' ;;
        gnome) printf 'Completo, pesado e mais limitado em PRoot' ;;
        *) printf 'Ambiente gráfico' ;;
    esac
}

linux_desktop_recomendado_perfil() {
    local desktop="${1:-}" perfil="${2:-$LINUX_PROFILE}"
    case "$perfil:$desktop" in
        BÁSICO:lxde|BÁSICO:openbox|BÁSICO:i3) return 0 ;;
        INTERMEDIÁRIO:xfce|INTERMEDIÁRIO:lxqt) return 0 ;;
        DESKTOP:xfce|DESKTOP:lxqt|DESKTOP:mate) return 0 ;;
        *) return 1 ;;
    esac
}

linux_desktop_aviso_perfil() {
    local desktop="${1:-}" peso
    peso="$(linux_desktop_peso "$desktop")"
    if [ "$LINUX_PROFILE" = "BÁSICO" ] && [[ "$desktop" =~ ^(mate|kde|gnome)$ ]]; then
        printf '⚠ Muito pesado para o perfil BÁSICO; travamentos e encerramentos são prováveis.'
    elif [ "$LINUX_PROFILE" = "INTERMEDIÁRIO" ] && [[ "$desktop" =~ ^(kde|gnome)$ ]]; then
        printf '⚠ Pode consumir muita RAM/CPU neste aparelho; use apenas para testar.'
    elif [ "$desktop" = "gnome" ]; then
        printf '⚠ GNOME pode ter limitações extras em PRoot por depender de serviços do sistema.'
    elif [ "$desktop" = "kde" ]; then
        printf 'ℹ KDE Plasma é mais pesado que XFCE/LXQt e pode demorar mais para iniciar.'
    else
        printf 'Consumo estimado: %s.' "$peso"
    fi
}

linux_escolher_desktop() {
    local titulo="${1:-🖥️ Escolher ambiente gráfico}" subtitulo="${2:-Selecione o desktop}" rec=""
    linux_avaliar_aparelho
    local -a itens=()
    local id nome desc peso marcador
    for id in xfce lxqt lxde mate openbox i3 kde gnome; do
        nome="$(linux_desktop_nome "$id")"
        desc="$(linux_desktop_descricao "$id")"
        peso="$(linux_desktop_peso "$id")"
        marcador=""
        linux_desktop_recomendado_perfil "$id" && marcador=" • recomendado"
        itens+=("$(( ${#itens[@]} + 1 ))|🖥️|$nome|$desc • $peso$marcador")
    done
    menu_unificado "$titulo" "$subtitulo • perfil ${LINUX_PROFILE}" \
        "[0] Voltar  •  [1–8] Selecionar" "${itens[@]}"
    ler_opcao
    case "$RESPOSTA_MENU" in
        1) LINUX_DESKTOP_ID="xfce" ;;
        2) LINUX_DESKTOP_ID="lxqt" ;;
        3) LINUX_DESKTOP_ID="lxde" ;;
        4) LINUX_DESKTOP_ID="mate" ;;
        5) LINUX_DESKTOP_ID="openbox" ;;
        6) LINUX_DESKTOP_ID="i3" ;;
        7) LINUX_DESKTOP_ID="kde" ;;
        8) LINUX_DESKTOP_ID="gnome" ;;
        0) return 1 ;;
        *) warn "Opção inválida."; sleep 1; return 2 ;;
    esac
    LINUX_DESKTOP_NOME="$(linux_desktop_nome "$LINUX_DESKTOP_ID")"
    LINUX_DESKTOP_LAUNCHER="$(linux_desktop_launcher "$LINUX_DESKTOP_ID")"
    return 0
}

linux_desktop_instalado() {
    local alias="${1:-}" desktop="${2:-}" launcher
    [ -n "$alias" ] && [ -n "$desktop" ] || return 1
    launcher="$(linux_desktop_launcher "$desktop" 2>/dev/null)" || return 1
    mkdir -p "$(dirname "$LINUX_LOG")" 2>/dev/null || true
    proot-distro login "$alias" -- /bin/sh -lc "command -v '$launcher' >/dev/null 2>&1" \
        >>"$LINUX_LOG" 2>&1
}

linux_xfce_instalado() {
    linux_desktop_instalado "${1:-}" xfce
}

linux_desktops_instalados() {
    local alias="${1:-}" id
    [ -n "$alias" ] || return 1
    for id in xfce lxqt lxde mate openbox i3 kde gnome; do
        linux_desktop_instalado "$alias" "$id" && printf '%s\n' "$id"
    done
}

linux_desktops_instalados_resumo() {
    local alias="${1:-}" id nomes=""
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        nomes+="${nomes:+, }$(linux_desktop_nome "$id")"
    done < <(linux_desktops_instalados "$alias" 2>/dev/null || true)
    [ -n "$nomes" ] && printf '%s' "$nomes" || printf 'nenhum'
}

linux_desktop_guest_script() {
    local desktop="${1:-}" launcher
    launcher="$(linux_desktop_launcher "$desktop" 2>/dev/null)" || return 1
    cat <<EOF
set -e
DESKTOP_ID='$desktop'
LAUNCHER='$launcher'
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  export DEBCONF_NONINTERACTIVE_SEEN=true
  printf "[Manager][ETAPA] Ubuntu iniciado; preparando APT\n"
  printf "[Manager][ETAPA] Atualizando listas de pacotes\n"
  apt-get update -o Acquire::Retries=2 -o Acquire::http::Timeout=45 -o Acquire::https::Timeout=45
  printf "[Manager][ETAPA] Instalando pacotes do desktop %s\n" "\$DESKTOP_ID"
  case "\$DESKTOP_ID" in
    xfce) apt-get install -y xfce4 xfce4-terminal dbus-x11 ;;
    lxqt) apt-get install -y lxqt qterminal dbus-x11 || apt-get install -y lxqt-core qterminal dbus-x11 ;;
    lxde) apt-get install -y lxde-core lxterminal dbus-x11 || apt-get install -y lxde lxterminal dbus-x11 ;;
    mate) apt-get install -y mate-desktop-environment-core mate-terminal dbus-x11 || apt-get install -y mate-desktop-environment mate-terminal dbus-x11 ;;
    openbox) apt-get install -y openbox tint2 lxterminal dbus-x11 ;;
    i3) apt-get install -y i3-wm i3status dmenu xterm dbus-x11 || apt-get install -y i3 xterm dbus-x11 ;;
    kde) apt-get install -y plasma-desktop konsole dbus-x11 || apt-get install -y kde-plasma-desktop konsole dbus-x11 ;;
    gnome) apt-get install -y gnome-session gnome-shell gnome-terminal dbus-x11 ;;
  esac
elif command -v pacman >/dev/null 2>&1; then
  printf "[Manager][ETAPA] Atualizando repositórios (pacman)\n"
  pacman -Sy --noconfirm
  case "\$DESKTOP_ID" in
    xfce) pacman -S --needed --noconfirm xfce4 xfce4-goodies dbus ;;
    lxqt) pacman -S --needed --noconfirm lxqt qterminal dbus ;;
    lxde) pacman -S --needed --noconfirm lxde lxterminal dbus ;;
    mate) pacman -S --needed --noconfirm mate mate-extra dbus ;;
    openbox) pacman -S --needed --noconfirm openbox tint2 xterm dbus ;;
    i3) pacman -S --needed --noconfirm i3-wm i3status dmenu xterm dbus ;;
    kde) pacman -S --needed --noconfirm plasma-desktop konsole dbus ;;
    gnome) pacman -S --needed --noconfirm gnome gnome-terminal dbus ;;
  esac
elif command -v apk >/dev/null 2>&1; then
  printf "[Manager][ETAPA] Atualizando repositórios (apk)\n"
  apk update
  case "\$DESKTOP_ID" in
    xfce) apk add xfce4 xfce4-terminal dbus ;;
    lxqt) apk add lxqt-desktop qterminal dbus || apk add lxqt qterminal dbus ;;
    lxde) apk add lxde lxterminal dbus ;;
    mate) apk add mate-desktop-environment mate-terminal dbus || apk add mate-desktop mate-session-manager mate-panel mate-terminal dbus ;;
    openbox) apk add openbox tint2 xterm dbus ;;
    i3) apk add i3wm i3status dmenu xterm dbus ;;
    kde) apk add plasma-desktop konsole dbus ;;
    gnome) apk add gnome-shell gnome-session gnome-terminal dbus ;;
  esac
elif command -v dnf >/dev/null 2>&1; then
  printf "[Manager][ETAPA] Instalando pacotes (dnf)\n"
  case "\$DESKTOP_ID" in
    xfce) dnf -y install @xfce-desktop-environment dbus-x11 || dnf -y group install "Xfce Desktop" || dnf -y install xfce4-session xfce4-panel xfce4-settings xfce4-terminal dbus-x11 ;;
    lxqt) dnf -y group install "LXQt Desktop" || dnf -y install lxqt-session lxqt-panel pcmanfm-qt qterminal dbus-x11 ;;
    lxde) dnf -y group install "LXDE Desktop" || dnf -y install lxde-common lxsession openbox lxterminal dbus-x11 ;;
    mate) dnf -y group install "MATE Desktop" || dnf -y install mate-session-manager mate-panel mate-terminal dbus-x11 ;;
    openbox) dnf -y install openbox tint2 xterm dbus-x11 ;;
    i3) dnf -y install i3 i3status dmenu xterm dbus-x11 ;;
    kde) dnf -y group install "KDE Plasma Workspaces" || dnf -y install plasma-workspace plasma-desktop konsole dbus-x11 ;;
    gnome) dnf -y group install "GNOME Desktop Environment" || dnf -y install gnome-session gnome-shell gnome-terminal dbus-x11 ;;
  esac
elif command -v zypper >/dev/null 2>&1; then
  printf "[Manager][ETAPA] Atualizando repositórios (zypper)\n"
  zypper --non-interactive refresh
  case "\$DESKTOP_ID" in
    xfce) zypper --non-interactive install -t pattern xfce || zypper --non-interactive install xfce4-session xfce4-panel xfce4-settings xfce4-terminal dbus-1-x11 ;;
    lxqt) zypper --non-interactive install -t pattern lxqt || zypper --non-interactive install lxqt-session lxqt-panel pcmanfm-qt qterminal dbus-1-x11 ;;
    lxde) zypper --non-interactive install -t pattern lxde || zypper --non-interactive install lxsession openbox lxterminal dbus-1-x11 ;;
    mate) zypper --non-interactive install -t pattern mate || zypper --non-interactive install mate-session-manager mate-panel mate-terminal dbus-1-x11 ;;
    openbox) zypper --non-interactive install openbox tint2 xterm dbus-1-x11 ;;
    i3) zypper --non-interactive install i3 i3status dmenu xterm dbus-1-x11 ;;
    kde) zypper --non-interactive install -t pattern kde_plasma || zypper --non-interactive install plasma5-session plasma5-workspace konsole dbus-1-x11 ;;
    gnome) zypper --non-interactive install -t pattern gnome || zypper --non-interactive install gnome-session gnome-shell gnome-terminal dbus-1-x11 ;;
  esac
else
  echo "Gerenciador de pacotes não reconhecido para instalação automática." >&2
  exit 65
fi
printf "[Manager][ETAPA] Verificando inicializador do desktop\n"
if ! command -v "\$LAUNCHER" >/dev/null 2>&1; then
  printf "[Manager][ERRO] Inicializador ausente: %s\n" "\$LAUNCHER" >&2
  exit 66
fi
EOF
}

# A saída é encaminhada imediatamente ao terminal e ao log; não armazenar
# o progresso em um buffer de UI. Os contadores refletem somente eventos
# observados no APT (nunca porcentagem ou previsão inventada).
linux_desktop_registrar_fluxo() {
    local status_file="${1:-}" linha etapa="Entrando na distribuição" downloads=0 configurados=0 agora atualizou
    while IFS= read -r linha || [ -n "$linha" ]; do
        printf '%s\n' "$linha"
        printf '%s\n' "$linha" >> "$LINUX_LOG"
        atualizou=false
        case "$linha" in
            '[Manager][ETAPA] '*)
                etapa="${linha#'[Manager][ETAPA] '}"
                atualizou=true ;;
            Get:[0-9]*|Downloading\ *|Baixando\ *)
                downloads=$((downloads + 1))
                etapa="Recebendo arquivos dos repositórios"
                atualizou=true ;;
            Unpacking\ *|Descompactando\ *|Preparing\ to\ unpack\ *)
                etapa="Descompactando pacotes"
                atualizou=true ;;
            'Setting up '*|'Configurando '*)
                configurados=$((configurados + 1))
                etapa="Configurando pacotes"
                atualizou=true ;;
            'Reading package lists'*|'Lendo listas de pacotes'*)
                etapa="Lendo listas de pacotes"
                atualizou=true ;;
            'Building dependency tree'*|'Construindo árvore de dependências'*)
                etapa="Resolvendo dependências"
                atualizou=true ;;
        esac
        if [ "$atualizou" = true ] && [ -n "$status_file" ]; then
            agora="$(date +%s 2>/dev/null || printf 0)"
            printf '%s|%s|%s|%s\n' "$etapa" "$downloads" "$configurados" "$agora" > "$status_file" 2>/dev/null || true
        fi
    done
}

linux_desktop_tempo_legivel() {
    local segundos="${1:-0}"
    [[ "$segundos" =~ ^[0-9]+$ ]] || segundos=0
    printf '%dm%02ds' "$((segundos / 60))" "$((segundos % 60))"
}

# Aviso periódico é um status de tempo/etapa; não prova progresso real.
# Não há timeout global: downloads e dpkg podem precisar de vários minutos.
linux_executar_desktop_com_progresso() {
    local alias="${1:-}" guest_script="${2:-}" rc=0 heartbeat_pid intervalo shell_pid
    local trap_int trap_term status_file status_dir inicio agora total etapa downloads configurados ultima intervalo_atividade
    [ -n "$alias" ] && [ -n "$guest_script" ] || return 2
    intervalo="${LINUX_DESKTOP_HEARTBEAT_SECONDS:-10}"
    [[ "$intervalo" =~ ^[0-9]+$ ]] && [ "$intervalo" -ge 1 ] || intervalo=10
    status_dir="${LINUX_STATE_DIR:-$(dirname "$LINUX_LOG")}"
    mkdir -p "$status_dir" 2>/dev/null || true
    status_file="$(mktemp "$status_dir/desktop-status.XXXXXX" 2>/dev/null)" || status_file=""
    if [ -n "$status_file" ]; then chmod 600 "$status_file" 2>/dev/null || true; fi
    inicio="$(date +%s 2>/dev/null || printf 0)"
    if [ -n "$status_file" ]; then
        printf 'Entrando na distribuição|0|0|%s\n' "$inicio" > "$status_file"
    fi
    printf '[Manager] Abrindo Linux (%s). Tempo: 0m00s.\n' "$alias"
    printf '[Manager] Etapas e saída do instalador aparecem abaixo; sem porcentagem fictícia.\n'
    printf '[Manager] Atualização de status a cada %ss. Ctrl+C interrompe.\n' "$intervalo"
    shell_pid="$BASHPID"
    (
        while sleep "$intervalo"; do
            kill -0 "$shell_pid" 2>/dev/null || exit 0
            agora="$(date +%s 2>/dev/null || printf 0)"
            total=$((agora - inicio))
            [ "$total" -ge 0 ] || total=0
            etapa="Entrando na distribuição"; downloads=0; configurados=0; ultima="$inicio"
            if [ -n "$status_file" ] && [ -r "$status_file" ]; then
                IFS='|' read -r etapa downloads configurados ultima < "$status_file" || true
            fi
            [[ "$ultima" =~ ^[0-9]+$ ]] || ultima="$inicio"
            intervalo_atividade=$((agora - ultima)); [ "$intervalo_atividade" -ge 0 ] || intervalo_atividade=0
            printf '[Manager][STATUS] Tempo %s | Etapa: %s | Downloads observados: %s | Pacotes configurados: %s | Última atividade: %ss\n' \
                "$(linux_desktop_tempo_legivel "$total")" "${etapa:-Aguardando saída}" "${downloads:-0}" "${configurados:-0}" "$intervalo_atividade"
        done
    ) &
    heartbeat_pid=$!
    trap_int="$(trap -p INT)"; trap_term="$(trap -p TERM)"
    trap 'kill "$heartbeat_pid" 2>/dev/null || true' INT TERM
    if proot-distro login "$alias" -- /bin/sh -lc "$guest_script" 2>&1 | linux_desktop_registrar_fluxo "$status_file"; then
        rc=0
    else
        # Preserve o status do PRoot, não o do leitor de saída.
        rc=${PIPESTATUS[0]}
    fi
    kill "$heartbeat_pid" 2>/dev/null || true
    wait "$heartbeat_pid" 2>/dev/null || true
    if [ -n "$status_file" ]; then rm -f -- "$status_file"; fi
    if [ -n "$trap_int" ]; then eval "$trap_int"; else trap - INT; fi
    if [ -n "$trap_term" ]; then eval "$trap_term"; else trap - TERM; fi
    agora="$(date +%s 2>/dev/null || printf 0)"
    total=$((agora - inicio)); [ "$total" -ge 0 ] || total=0
    printf '[Manager] Execução finalizada em %s (código %s).\n' "$(linux_desktop_tempo_legivel "$total")" "$rc"
    linux_log "desktop proot encerrado: alias=$alias código=$rc tempo=${total}s"
    return "$rc"
}

linux_instalar_desktop_na_distro() {
    local alias="${1:-}" desktop="${2:-}" gerenciador guest_script nome launcher aviso
    [ -n "$alias" ] && [ -n "$desktop" ] || return 1
    nome="$(linux_desktop_nome "$desktop")"
    launcher="$(linux_desktop_launcher "$desktop")"
    gerenciador="$(linux_detectar_gerenciador_distro "$alias" 2>/dev/null || printf 'desconhecido')"
    [ -n "$gerenciador" ] || gerenciador="desconhecido"

    if linux_desktop_instalado "$alias" "$desktop"; then
        cabecalho_tela "✅ $nome já instalado" "$alias"
        caixa_simples "Desktop encontrado" \
            "Distribuição: $alias" \
            "Gerenciador: $(linux_descrever_gerenciador_distro "$gerenciador")" \
            "Inicializador: $launcher" \
            "Nenhuma reinstalação é necessária."
        linux_log "$nome já presente em $alias; reinstalação evitada"
        return 0
    fi

    if [ "$gerenciador" = "desconhecido" ]; then
        cabecalho_tela "⚠ Desktop não automatizado" "$alias"
        caixa_simples "Gerenciador não reconhecido" \
            "O Manager não encontrou apt, pacman, apk, dnf ou zypper nesta distribuição." \
            "A instalação automática foi interrompida para evitar comandos incompatíveis."
        linux_log "gerenciador de pacotes desconhecido em $alias"
        return 65
    fi

    linux_avaliar_aparelho
    aviso="$(linux_desktop_aviso_perfil "$desktop")"
    cabecalho_tela "🪟 Preparando $nome" "$alias"
    caixa_simples "Ambiente gráfico" \
        "Distribuição: $alias" \
        "Desktop: $nome" \
        "Gerenciador: $(linux_descrever_gerenciador_distro "$gerenciador")" \
        "Perfil do aparelho: ${LINUX_PROFILE_ICON} ${LINUX_PROFILE}" \
        "$aviso"
    if [ "$desktop" = "gnome" ]; then
        caixa_simples "⚠ Compatibilidade GNOME" \
            "GNOME foi mantido como opção avançada." \
            "Algumas funções dependem de serviços do sistema que não existem em PRoot." \
            "Se houver problemas, prefira XFCE, LXQt ou MATE."
    fi
    confirmar_acao "Instalar $nome dentro de '$alias'?" || return 2

    guest_script="$(linux_desktop_guest_script "$desktop")" || return 1
    cabecalho_tela "🪟 Instalando $nome" "A instalação dentro do Linux pode ser demorada"
    caixa_simples "Instalação inteligente" \
        "Distribuição: $alias" \
        "Desktop: $nome" \
        "Gerenciador: $(linux_descrever_gerenciador_distro "$gerenciador")" \
        "O Manager validará '$launcher' ao terminar." \
        "Não feche o Termux durante esta etapa."
    # Essencial: o cabeçalho e a caixa ficam em buffer até a próxima leitura.
    # Instalações longas precisam renderizar o quadro ANTES de iniciar o PRoot.
    ui_buffer_flush 2>/dev/null || true
    # A linha de comando dentro da distribuição produz um status real; tee nunca
    # deve esconder o erro do gerenciador de pacotes ou do proot-distro.
    local rc=0
    linux_log "iniciando instalação desktop=$desktop alias=$alias gerenciador=$gerenciador"
    printf '[Manager] Preparando execução do desktop %s em %s...\n' "$nome" "$alias"
    linux_executar_desktop_com_progresso "$alias" "$guest_script" || rc=$?
    if [ "$rc" -eq 0 ]; then
        if linux_desktop_instalado "$alias" "$desktop"; then
            linux_log "$nome instalado e validado em $alias via $gerenciador"
            ok "$nome instalado e validado em '$alias'."
            return 0
        fi
        rc=66
        error "A instalação terminou, mas '$launcher' não foi encontrado."
    fi

    linux_log "falha desktop=$desktop alias=$alias gerenciador=$gerenciador código=$rc"
    error "Falha ao instalar $nome (código $rc)."
    caixa_simples_wrap "Instalação não concluída" \
        "Distribuição: $alias • Desktop: $nome" \
        "Código de saída: $rc" \
        "Confira a mensagem APT/DNF/etc. no log, antes de tentar reparar pacotes." \
        "Log interno: $(caminho_curto "$LINUX_LOG")"
    if confirmar_acao "Copiar log do Linux para Downloads agora?" "s"; then
        linux_exportar_log_downloads || true
    fi
    return 1
}

linux_instalar_xfce_na_distro() {
    linux_instalar_desktop_na_distro "${1:-}" xfce
}

linux_instalar_ambiente_grafico() {
    linux_garantir_proot_distro || { pause; return 1; }
    linux_avaliar_aparelho
    cabecalho_tela "🪟 Instalar ambiente gráfico" "Escolha o desktop para a distribuição"
    caixa_simples "Perfil do aparelho" \
        "${LINUX_PROFILE_ICON} ${LINUX_PROFILE}" \
        "$LINUX_PROFILE_RECOMMEND" \
        "Você pode instalar mais de um ambiente na mesma distribuição."
    linux_selecionar_instalada "🪟 Instalar ambiente gráfico" "Escolha a distribuição" || return 0
    linux_escolher_desktop "🖥️ Escolher ambiente gráfico" "$LINUX_DISTRO_ALIAS" || return 0
    linux_instalar_desktop_na_distro "$LINUX_DISTRO_ALIAS" "$LINUX_DESKTOP_ID"
    local rc=$?
    [ "$rc" -eq 2 ] || pause
    return 0
}

linux_instalar_desktop_xfce() {
    linux_instalar_ambiente_grafico
}

linux_selecionar_desktop_instalado() {
    local alias="${1:-}" titulo="${2:-🖥️ Ambiente instalado}" id nome indice=0
    local -a ids=() itens=()
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        ids+=("$id")
        indice=$((indice + 1))
        nome="$(linux_desktop_nome "$id")"
        itens+=("$indice|🖥️|$nome|$(linux_desktop_descricao "$id")")
    done < <(linux_desktops_instalados "$alias" 2>/dev/null || true)
    [ ${#ids[@]} -gt 0 ] || return 1
    if [ ${#ids[@]} -eq 1 ]; then
        LINUX_DESKTOP_ID="${ids[0]}"
        LINUX_DESKTOP_NOME="$(linux_desktop_nome "$LINUX_DESKTOP_ID")"
        LINUX_DESKTOP_LAUNCHER="$(linux_desktop_launcher "$LINUX_DESKTOP_ID")"
        return 0
    fi
    menu_unificado "$titulo" "$alias • escolha qual iniciar" \
        "[0] Voltar  •  [1–${#ids[@]}] Selecionar" "${itens[@]}"
    ler_opcao
    [[ "$RESPOSTA_MENU" =~ ^[0-9]+$ ]] || return 2
    [ "$RESPOSTA_MENU" -eq 0 ] && return 2
    [ "$RESPOSTA_MENU" -ge 1 ] && [ "$RESPOSTA_MENU" -le ${#ids[@]} ] || return 2
    LINUX_DESKTOP_ID="${ids[$((RESPOSTA_MENU - 1))]}"
    LINUX_DESKTOP_NOME="$(linux_desktop_nome "$LINUX_DESKTOP_ID")"
    LINUX_DESKTOP_LAUNCHER="$(linux_desktop_launcher "$LINUX_DESKTOP_ID")"
    return 0
}

# Um SIGKILL do Android pode matar o próprio Termux antes de qualquer trap.
# Marcador privado: um reinício posterior pode avisar que a sessão anterior
# não retornou ao Manager. Isso NÃO identifica a causa nem comprova SIGKILL.
linux_x11_marcador_sessao() {
    printf '%s/x11-session-pending.state\n' "$LINUX_STATE_DIR"
}

linux_x11_marcar_inicio_sessao() {
    local arquivo
    arquivo="$(linux_x11_marcador_sessao)"
    mkdir -p -- "$LINUX_STATE_DIR" || return 1
    if [ -L "$arquivo" ]; then
        linux_log 'X11: marcador simbólico recusado; não será sobrescrito'
        return 1
    fi
    (umask 077; printf 'iniciada_em=%s\ndistribuicao=%s\ndesktop=%s\n' \
        "$(date '+%Y-%m-%dT%H:%M:%S')" "$1" "$2" > "$arquivo")
}

linux_x11_verificar_sessao_anterior() {
    local arquivo
    arquivo="$(linux_x11_marcador_sessao)"
    [ -f "$arquivo" ] && [ ! -L "$arquivo" ] || return 1
    linux_log 'X11: sessão anterior não retornou ao Manager; possível interrupção externa'
    caixa_simples 'Sessão anterior interrompida' \
        'O Manager não recebeu o término normal da sessão gráfica.' \
        'Possíveis causas: Termux encerrado, falha do Android, falta de memória ou SIGKILL.' \
        'A mensagem signal 9 sugere encerramento forçado, sem identificar o responsável.' \
        'Consulte Suporte X11 > Signal 9 e restrições do Android.'
    return 0
}

linux_x11_orientar_sigkill() {
    caixa_simples 'Processo encerrado (signal 9)' \
        'SIGKILL é um encerramento forçado; não é falha comprovada de instalação do desktop.' \
        'Android 12+: o controle de processos filhos é uma causa conhecida, mas não a única.' \
        'Confira Termux > Bateria > Sem restrições, caso esteja disponível.' \
        'Nas Opções do desenvolvedor, procure Desativar restrições de processos filhos.' \
        'Essa alteração é manual e pode aumentar o uso de bateria e recursos.' \
        'O Manager não altera configurações globais, root ou ADB automaticamente.'
}

# Esta função retorna o status original do PRoot, inclusive 137 quando
# um subprocesso foi encerrado por SIGKILL. A própria shell pode ser morta
# sem conseguir executar esta função até o fim.
linux_x11_executar_sessao_proot() {
    local alias="$1" comando="$2" rc=0
    if proot-distro login "$alias" --shared-tmp -- /bin/sh -lc "$comando" 2>&1 | tee -a "$LINUX_LOG" ${LINUX_LOGS_SESSAO_ATUAL:+"$LINUX_LOGS_SESSAO_ATUAL"}; then
        rc=0
    else
        rc=${PIPESTATUS[0]}
    fi
    linux_log "X11: processo do desktop retornou status=$rc"
    return "$rc"
}

linux_iniciar_desktop() {
    local alias_preselecionado="${1:-}"
    linux_x11_verificar_sessao_anterior || true
    linux_garantir_proot_distro || { pause; return 1; }
    cabecalho_tela "🖥️ Iniciar desktop Linux" "Termux:X11 + ambiente gráfico"
    if ! linux_x11_companion_instalado; then
        warn "O companion termux-x11 não está instalado."
        caixa_simples "Como corrigir" "Abra Interface gráfica (X11) > Preparar Termux:X11 > Componentes do Termux."
        pause
        return 1
    fi
    if ! linux_x11_apk_instalado; then
        warn "As consultas do Android não confirmaram o aplicativo X11."
        caixa_simples "Detecção limitada" \
            "As consultas pm/cmd podem falhar com o X11 instalado." \
            "Confira Termux:X11 em Configurações > Aplicativos." \
            "Se estiver instalado, você pode tentar abrir o desktop normalmente."
        confirmar_acao "Tentar iniciar o desktop mesmo assim?" "s" || { pause; return 0; }
    fi

    if [ -n "$alias_preselecionado" ]; then
        LINUX_DISTRO_ALIAS="$alias_preselecionado"
    else
        linux_selecionar_instalada "🖥️ Iniciar desktop Linux" "Escolha a distribuição para o desktop" || return 0
    fi
    linux_coletar_info_distro "$LINUX_DISTRO_ALIAS" false
    if [ "$LINUX_INFO_HEALTH" != "ok" ]; then
        cabecalho_tela "⚠ Desktop indisponível" "$LINUX_DISTRO_ALIAS"
        caixa_simples "Distribuição com problema"             "Motivo: ${LINUX_DIAG_REASON:-falha ao iniciar}"             "Use Diagnóstico ou Reparar antes do desktop."
        pause
        return 1
    fi
    local instalados
    instalados="$(linux_desktops_instalados_resumo "$LINUX_DISTRO_ALIAS")"
    if [ "$instalados" = "nenhum" ]; then
        local gerenciador
        gerenciador="$(linux_detectar_gerenciador_distro "$LINUX_DISTRO_ALIAS" 2>/dev/null || printf 'desconhecido')"
        cabecalho_tela "⚠ Nenhum desktop instalado" "$LINUX_DISTRO_ALIAS"
        caixa_simples "Ambiente gráfico ausente" \
            "Distribuição: $LINUX_DISTRO_ALIAS" \
            "Gerenciador: $(linux_descrever_gerenciador_distro "$gerenciador")" \
            "Você pode escolher XFCE, LXQt, LXDE, MATE, Openbox, i3, KDE ou GNOME."
        if confirmar_acao "Escolher e instalar um ambiente agora?" "s"; then
            linux_escolher_desktop "🖥️ Escolher ambiente gráfico" "$LINUX_DISTRO_ALIAS" || return 0
            linux_instalar_desktop_na_distro "$LINUX_DISTRO_ALIAS" "$LINUX_DESKTOP_ID"
            local rc=$?
            if [ "$rc" -ne 0 ]; then
                [ "$rc" -eq 2 ] || pause
                return 0
            fi
        else
            return 0
        fi
    else
        linux_selecionar_desktop_instalado "$LINUX_DISTRO_ALIAS" "🖥️ Ambientes instalados" || return 0
    fi

    local desktop="$LINUX_DESKTOP_ID" nome="$LINUX_DESKTOP_NOME" launcher="$LINUX_DESKTOP_LAUNCHER"
    cabecalho_tela "🖥️ Iniciar desktop Linux" "Termux:X11 + $nome"
    caixa_simples "Sessão gráfica" \
        "Distribuição: $LINUX_DISTRO_ALIAS" \
        "Desktop: $nome" \
        "Inicializador: $launcher" \
        "Display: :1" \
        "O Manager compartilhará /tmp com a distribuição para o X11." \
        "Feche a sessão gráfica para retornar ao Manager."
    confirmar_acao "Iniciar $nome agora?" "s" || return 0

    # Gravar antes de entrar no PRoot permite diagnosticar encerramentos do
    # próprio terminal em que a limpeza Bash já não pode ser executada.
    linux_x11_marcar_inicio_sessao "$LINUX_DISTRO_ALIAS" "$desktop" || {
        warn 'Não foi possível salvar o estado da sessão X11.'
        return 1
    }
    linux_logs_nova_sessao "$LINUX_DISTRO_ALIAS" "$desktop" || linux_log "X11: não foi possível iniciar histórico privado de sessão"
    local x11_server_log="$LINUX_STATE_DIR/x11-server.log"
    if [ -L "$x11_server_log" ]; then
        warn 'O caminho de log do X11 é um link simbólico, operação recusada.'
        rm -f -- "$(linux_x11_marcador_sessao)"
        return 1
    fi
    (umask 077; : >> "$x11_server_log") || return 1
    pkill -f 'termux-x11 :1' 2>/dev/null || true
    XDG_RUNTIME_DIR="${TMPDIR:-$PREFIX/tmp}" termux-x11 :1 >> "$x11_server_log" 2>&1 &
    linux_log 'X11: companion iniciado; saída disponível no log privado x11-server.log'
    sleep 1
    if ! linux_x11_testar_abertura_android; then
        warn "Não foi possível abrir o aplicativo X11 pelo Termux."
        caixa_simples "Abertura do Android" \
            "Erro: ${LINUX_X11_ABERTURA_ERRO:-indisponível}" \
            "O companion continuará tentando iniciar o desktop." \
            "Se o APK já está instalado, abra-o pelo ícone do Android." \
            "O erro completo está no log Linux."
    fi
    linux_log "sessão X11 solicitada para $LINUX_DISTRO_ALIAS desktop=$desktop"

    local session_cmd
    session_cmd="export DISPLAY=:1; export XDG_RUNTIME_DIR=/tmp; if command -v dbus-launch >/dev/null 2>&1; then exec dbus-launch --exit-with-session '$launcher'; else exec '$launcher'; fi"
    local rc=0
    linux_log "X11: iniciando sessão guest distro=$LINUX_DISTRO_ALIAS desktop=$desktop"
    linux_x11_executar_sessao_proot "$LINUX_DISTRO_ALIAS" "$session_cmd" || rc=$?
    rm -f -- "$(linux_x11_marcador_sessao)"
    linux_logs_encerrar_sessao "$rc"
    if [ "$rc" -ne 0 ]; then
        error "A sessão gráfica terminou com erro (status=$rc)."
        if [ "$rc" -eq 137 ]; then
            linux_log 'X11: status 137; possível SIGKILL do processo guest (causa não confirmada)'
            linux_x11_orientar_sigkill
        else
            caixa_simples "Dicas" \
                "$nome foi verificado antes da abertura da sessão." \
                "Se aparecer tela preta, consulte Diagnóstico X11." \
                "Ambientes pesados como KDE/GNOME podem exigir mais memória."
        fi
        pause
    fi
}

linux_iniciar_xfce() {
    linux_iniciar_desktop
}

linux_parar_x11() {
    cabecalho_tela "⏹️ Parar sessão gráfica" "Encerrar servidor Termux:X11"
    pkill -f 'com.termux.x11' 2>/dev/null || true
    pkill -f 'termux-x11' 2>/dev/null || true
    command -v am >/dev/null 2>&1 && am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 >/dev/null 2>&1 || true
    linux_log "sessão X11 encerrada"
    ok "Solicitação de encerramento enviada ao Termux:X11."
    pause
}

linux_diagnostico_x11() {
    cabecalho_tela "🩺 Diagnóstico X11" "Orientações para problemas comuns"
    caixa_simples "Tela preta ou cursor apenas" \
        "Teste iniciar o servidor com: termux-x11 :1 -legacy-drawing" \
        "Alguns aparelhos precisam desse modo de desenho."
    caixa_simples "Cores trocadas" \
        "Teste: termux-x11 :1 -force-bgra"
    caixa_simples "Desktop lento" \
        "O Android pode limitar CPU quando o Termux fica em segundo plano." \
        "Mantenha o Termux ativo quando possível e use um desktop leve." \
        "O APK sharedUid pode reduzir esse problema, mas só é compatível com builds específicas do Termux."
    caixa_simples "APK não abre pelo Termux" \
        "Instale pelo gerenciador de arquivos em Downloads." \
        "O termux-open pode exigir allow-external-apps=true, opção de segurança." \
        "O Manager não ativa esta permissão sozinho."
    caixa_simples "Aplicativo instalado mas não detectado" \
        "As consultas pm/cmd podem falhar em algumas versões do Android." \
        "Teste a abertura pelo menu Preparar X11 > Testar app." \
        "O diagnóstico registra o motivo no log Linux." \
        "Confira X11 em Configurações > Aplicativos e tente iniciar." \
        "O Manager não deve bloquear a inicialização por essa consulta."
    linux_x11_orientar_sigkill
    caixa_simples "PRoot + X11" \
        "O Manager inicia a distribuição com --shared-tmp." \
        "DISPLAY usado: :1"
    pause
}

# Preparação inicial: o APK e o companion são componentes distintos.
linux_menu_preparar_x11() {
    local companion app escolha
    while true; do
        companion="pendente"; app="pendente"
        linux_x11_companion_instalado && companion="pronto"
        app="$(linux_x11_apk_status_texto)"
        menu_unificado "⚙️ PREPARAR TERMUX:X11" "Duas instalações necessárias (uma única vez)" \
            "[0] Voltar  •  [1–4] Selecionar" \
            "1|📦|Componentes do Termux|Companion: $companion" \
            "2|📲|Aplicativo Android (APK)|Aplicativo: $app" \
            "3|📋|Verificar instalação|Conferir os dois componentes" \
            "4|▶️|Testar abertura do app|Abrir o X11 sem instalar novamente"
        ler_opcao
        escolha="$RESPOSTA_MENU"
        case "$escolha" in
            1) linux_instalar_x11_companion ;;
            2) linux_baixar_x11_apk ;;
            3) linux_status_x11 ;;
            4) linux_x11_testar_abertura_menu ;;
            0) return 0 ;;
            *) feedback_curto "Opção inválida." ;;
        esac
    done
}

linux_menu_suporte_x11() {
    local escolha
    while true; do
        menu_unificado "🩺 SUPORTE TERMUX:X11" "Solução de problemas e documentação" \
            "[0] Voltar  •  [1–8] Selecionar" \
            "1|📋|Status do X11|Aplicativo e companion" \
            "2|⏹️|Parar sessão gráfica|Encerrar o servidor X11" \
            "3|🩺|Diagnóstico X11|Tela preta, cores e lentidão" \
            "4|🌐|Repositório oficial|GitHub termux/termux-x11" \
            "5|📥|Copiar log para Downloads|Salvar o log Linux em .log" \
            "6|▶️|Testar abertura do X11|Verificar atividade do aplicativo Android" \
            "7|🔐|Permissões para instalar APKs|Integração Termux e ajustes do Android" \
            "8|⚠️|Signal 9 e Android|Processos encerrados pelo sistema"
        ler_opcao
        escolha="$RESPOSTA_MENU"
        case "$escolha" in
            1) linux_status_x11 ;;
            2) linux_parar_x11 ;;
            3) linux_diagnostico_x11 ;;
            4)
                if command -v termux-open-url >/dev/null 2>&1; then
                    termux-open-url "https://github.com/termux/termux-x11" || true
                else
                    caixa_simples "Repositório oficial" "https://github.com/termux/termux-x11"
                    pause
                fi
                ;;
            5) linux_exportar_log_downloads || true; pause ;;
            6) linux_x11_testar_abertura_menu ;;
            7) linux_menu_permissoes_apk ;;
            8) linux_x11_orientar_sigkill; pause ;;
            0) return 0 ;;
            *) feedback_curto "Opção inválida." ;;
        esac
    done
}

menu_termux_x11() {
    local escolha
    while true; do
        menu_unificado "🖥️ DESKTOP LINUX (X11)" "Interface gráfica no Android, sem root" \
            "[0] Voltar  •  [1–4] Selecionar" \
            "1|⚙️|Preparar Termux:X11|Primeiro uso: companion e APK Android" \
            "2|🪟|Instalar desktop|Depois: escolher XFCE, LXQt e outros" \
            "3|▶️|Abrir desktop|Iniciar um ambiente já instalado" \
            "4|🩺|Status e problemas|Diagnóstico, encerrar e ajuda"
        ler_opcao
        escolha="$RESPOSTA_MENU"
        case "$escolha" in
            1) linux_menu_preparar_x11 ;;
            2) linux_instalar_ambiente_grafico ;;
            3) linux_iniciar_desktop ;;
            4) linux_menu_suporte_x11 ;;
            0) return 0 ;;
            *) feedback_curto "Opção inválida." ;;
        esac
    done
}

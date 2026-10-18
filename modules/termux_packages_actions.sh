# Módulo: termux_packages_actions.sh
# Ações públicas de atualização, ambiente e instalação de pacotes.

atualizar_pacotes_termux() {
    local inicio fim
    inicio=$(date +%s)
    mkdir -p "$(dirname "$TERMUX_SETUP_LOG")"
    : >> "$TERMUX_SETUP_LOG"

    if [ "${WIZARD_MODE:-false}" != true ]; then
        aviso_repositorios_termux || return 1
    fi

    # Corrige um dpkg interrompido antes de consultar ou atualizar pacotes.
    if [ -n "$(dpkg --audit 2>/dev/null)" ]; then
        if ! reparar_dpkg_automaticamente "Reparando instalação anterior interrompida"; then
            LAST_PKG_COMMAND="dpkg --configure -a; apt-get -f install"
            LAST_PKG_EXIT_CODE="1"
            mostrar_erro_pkg "Não foi possível reparar o sistema de pacotes antes da atualização."
            return 1
        fi
    fi

    if ! executar_pkg_monitorado "Preparando Ambiente Termux" 10 44         "Sincronizando repositórios..." "Usando mirrors oficiais do Termux." -- update -y; then
        if [ "${WIZARD_MODE:-false}" = true ] && [ "${LAST_PKG_EXIT_CODE:-}" = 130 ]; then
            log "INFO" "Atualização do wizard pausada pelo usuário durante apt-get update."
            return 130
        fi
        mostrar_erro_pkg "Falha ao consultar os repositórios do Termux."
        [ "${WIZARD_MODE:-false}" = true ] || pause
        return 1
    fi

    if ! executar_pkg_monitorado "Preparando Ambiente Termux" 45 89 \
        "Atualizando o sistema do Termux..." "Verificando pacotes instalados." -- upgrade -y; then
        if [ "${WIZARD_MODE:-false}" = true ] && [ "${LAST_PKG_EXIT_CODE:-}" = 130 ]; then
            log "INFO" "Atualização do wizard pausada pelo usuário durante apt-get upgrade."
            return 130
        fi
        # Se o dpkg ficou interrompido, tenta reparar e repete o upgrade uma
        # única vez. Isso cobre interrupções reais sem criar loop infinito.
        if log_pkg_tem_dpkg_interrompido "$TERMUX_SETUP_LOG" "${LAST_PKG_LOG_START_OFFSET:-0}"; then
            if reparar_dpkg_automaticamente "Reparando atualização interrompida"; then
                if ! executar_pkg_monitorado "Preparando Ambiente Termux" 55 89 \
                    "Retomando a atualização do Termux..." "Pacotes pendentes foram reparados." -- upgrade -y; then
                    mostrar_erro_pkg "A atualização falhou novamente após o reparo automático."
                    [ "${WIZARD_MODE:-false}" = true ] || pause
                    return 1
                fi
            else
                mostrar_erro_pkg "O dpkg foi interrompido e o reparo automático não conseguiu concluir."
                [ "${WIZARD_MODE:-false}" = true ] || pause
                return 1
            fi
        else
            mostrar_erro_pkg "Falha ao atualizar os pacotes do Termux."
            [ "${WIZARD_MODE:-false}" = true ] || pause
            return 1
        fi
    fi

    # Confirma a consistência depois do upgrade e tenta reparar antes de falhar.
    if [ -n "$(dpkg --audit 2>/dev/null)" ]; then
        if ! reparar_dpkg_automaticamente "Finalizando pacotes pendentes após a atualização"; then
            LAST_PKG_COMMAND="dpkg --audit"
            LAST_PKG_EXIT_CODE="1"
            mostrar_erro_pkg "Ainda existem pacotes pendentes após o reparo automático."
            return 1
        fi
    fi

    tela_operacao_termux "Preparando Ambiente Termux" 90 "Finalizando manutenção..." "Limpando arquivos temporários." "✔ Repositórios sincronizados" "✔ Pacotes atualizados" "⏳ Limpando cache" "Quase concluído."
    pkg clean >>"$TERMUX_SETUP_LOG" 2>&1 || true
    fim=$(date +%s)

    local resumo_linhas mirror atualizaveis
    resumo_linhas="$(ultimas_linhas_pkg "$TERMUX_SETUP_LOG" 5)"
    mirror="$(grep -Eo 'https?://[^ ]+' "$TERMUX_SETUP_LOG" 2>/dev/null | tail -n 1 | sed 's/[),]$//' || true)"
    [ -n "$mirror" ] || mirror="repositório configurado"
    atualizaveis="$(apt list --upgradable 2>/dev/null | awk 'NR>1 && NF{n++} END{print n+0}')"

    tela_operacao_termux "Ambiente Termux preparado" 100 "Atualização concluída." "Tempo: $(formatar_tempo $((fim-inicio)))" "✔ Repositórios sincronizados" "✔ Pacotes atualizados" "✔ Cache limpo" "O ambiente está pronto." "$resumo_linhas"
    encerrar_ui_termux
    cabecalho_tela "✅ Ambiente Termux preparado" "Atualização concluída em $(formatar_tempo $((fim-inicio)))"
    caixa_simples "Resumo" \
        "Mirror/repositório: $(printf '%s' "$mirror" | cut -c1-60)" \
        "Pacotes ainda atualizáveis: $atualizaveis" \
        "Configurações existentes: preservadas" \
        "Cache: limpo"
    local -a mensagens_resumo=()
    while IFS= read -r linha; do
        [ -n "$linha" ] && mensagens_resumo+=("$linha")
    done < <(printf '%s\n' "$resumo_linhas" | head -n 4)
    [ ${#mensagens_resumo[@]} -gt 0 ] || mensagens_resumo=("Nenhuma mensagem pendente.")
    caixa_simples "Últimas mensagens"         "${mensagens_resumo[@]}"         "Log completo: $(caminho_curto "$TERMUX_SETUP_LOG")"
    if [ "${WIZARD_MODE:-false}" = true ]; then
        echo
        caixa_simples_wrap "➡ Próxima etapa"             "A atualização do Termux já terminou."             "O assistente vai continuar automaticamente para instalar as ferramentas recomendadas."             "Se esta tela continuar visível por alguns segundos, isso não é travamento."             "Não use Ctrl+C aqui, a menos que realmente queira interromper a configuração."             "Prosseguindo automaticamente em 3 segundos..."
        sleep 3
    else
        printf '\nPressione ENTER para continuar...'
        read -r _
    fi
    return 0
}

configurar_armazenamento() {
    resolver_downloads_dir >/dev/null 2>&1 || true
    cabecalho_tela "🔐 Armazenamento" "Permissões do Android"
    if [ -d "$HOME/storage" ]; then
        caixa_simples "✅ Acesso encontrado" "~/storage está disponível" "Downloads: $(caminho_curto "$DOWNLOADS_DIR")"
        confirmar_acao "Executar termux-setup-storage novamente?" || return
    else
        caixa_simples "⚠ Acesso ausente" "O Android ainda não liberou os arquivos." "Aceite a permissão na próxima tela."
    fi
    if command -v termux-setup-storage >/dev/null 2>&1; then
        termux-setup-storage
        sleep 2
        resolver_downloads_dir || true
        [ -d "$HOME/storage" ] && ok "Armazenamento configurado." || warn "A permissão ainda não foi detectada."
    else
        error "termux-setup-storage não foi encontrado."
    fi
    [ "${WIZARD_MODE:-false}" = true ] || pause
}

verificar_ambiente_termux() {
    resolver_downloads_dir >/dev/null 2>&1 || true
    detectar_variante_termux
    cabecalho_tela "🔎 Diagnóstico do ambiente" "Ferramentas detectadas no aparelho"

    versao_cmd() {
        local cmd="$1"; shift
        if command -v "$cmd" >/dev/null 2>&1; then
            "$@" 2>&1 | head -1 | sed 's/^[[:space:]]*//'
        else
            printf 'não instalado'
        fi
    }

    caixa_simples "📱 Termux"         "Origem: $(termux_origem_resumida)"         "Versão: ${TERMUX_VERSION:-indisponível}"         "Repositório: $(termux_repositorio_resumido)"         "PREFIX: $(caminho_curto "${PREFIX:-indisponível}")"

    caixa_simples "📂 Acesso"         "Armazenamento: $([ -d "$HOME/storage" ] && echo OK || echo ausente)"         "Downloads: $([ -d "$DOWNLOADS_DIR" ] && echo acessível || echo indisponível)"         "Espaço livre: $(df -h "$HOME" 2>/dev/null | awk 'NR==2{print $4}')"

    caixa_simples "🌐 Web"         "Git: $(versao_cmd git git --version)"         "Node: $(versao_cmd node node --version)"         "npm: $(versao_cmd npm npm --version)"         "pnpm: $(versao_cmd pnpm pnpm --version)"         "Yarn: $(versao_cmd yarn yarn --version)"         "PHP: $(versao_cmd php php --version)"         "Composer: $(versao_cmd composer composer --version)"

    caixa_simples "📝 Terminal e editores"         "Nano: $(versao_cmd nano nano --version)"         "Micro: $(versao_cmd micro micro --version)"         "Fish: $(versao_cmd fish fish --version)"         "Bash: $(versao_cmd bash bash --version)"

    caixa_simples "🐍 Python e Java"         "Python: $(versao_cmd python python --version)"         "pip: $(versao_cmd pip pip --version)"         "Java: $(versao_cmd java java -version)"         "Gradle: $(versao_cmd gradle gradle --version)"         "Maven: $(versao_cmd mvn mvn -version)"

    caixa_simples "🔧 Compilação e dados"         "Clang: $(versao_cmd clang clang --version)"         "Make: $(versao_cmd make make --version)"         "CMake: $(versao_cmd cmake cmake --version)"         "SQLite: $(versao_cmd sqlite3 sqlite3 --version)"         "PostgreSQL: $(versao_cmd psql psql --version)"         "MariaDB: $(versao_cmd mariadb mariadb --version)"
    pause
}
pacote_ja_funcional() {
    local pacote="${1:-}"
    case "$pacote" in
        nodejs) command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 ;;
        python) command -v python >/dev/null 2>&1 ;;
        php) command -v php >/dev/null 2>&1 ;;
        composer) command -v composer >/dev/null 2>&1 ;;
        golang) command -v go >/dev/null 2>&1 ;;
        rust) command -v cargo >/dev/null 2>&1 && command -v rustc >/dev/null 2>&1 ;;
        ruby) command -v ruby >/dev/null 2>&1 ;;
        openjdk-*) command -v java >/dev/null 2>&1 && command -v javac >/dev/null 2>&1 ;;
        maven) command -v mvn >/dev/null 2>&1 ;;
        postgresql) command -v psql >/dev/null 2>&1 ;;
        sqlite) command -v sqlite3 >/dev/null 2>&1 ;;
        redis) command -v redis-server >/dev/null 2>&1 ;;
        openssh) command -v ssh >/dev/null 2>&1 ;;
        *) command -v "$pacote" >/dev/null 2>&1 ;;
    esac
}

# Aceita somente nomes de pacotes Termux/Debian, nunca opções do apt ou URLs.
# A seleção manual não pode transformar um nome em argumento do gerenciador.
pacote_nome_valido() {
    [[ "${1:-}" =~ ^[a-z0-9][a-z0-9+.-]{0,99}$ ]]
}

pacote_registrado_instalado() {
    local pacote="${1:-}"
    pacote_nome_valido "$pacote" || return 1
    if command -v dpkg-query >/dev/null 2>&1; then
        [ "$(dpkg-query -W -f='${Status}' "$pacote" 2>/dev/null)" = 'install ok installed' ]
    else
        dpkg -s "$pacote" 2>/dev/null | grep -Fxq 'Status: install ok installed'
    fi
}

pacote_instalado_ou_funcional() {
    local pacote="${1:-}"
    pacote_nome_valido "$pacote" || return 1
    pacote_ja_funcional "$pacote" || pacote_registrado_instalado "$pacote"
}

comando_referencia_pacote() {
    # O nome do pacote nem sempre é o nome de um executável. Na verificação
    # pós-instalação do wizard, usar `command -v coreutils/findutils` gerava
    # falsos negativos mesmo com o pacote instalado e funcional. Retorna um
    # comando representativo que comprova a funcionalidade entregue.
    case "${1:-}" in
        coreutils) printf '%s' ls ;;
        grep) printf '%s' grep ;;
        sed) printf '%s' sed ;;
        gawk) printf '%s' awk ;;
        findutils) printf '%s' find ;;
        nano) printf '%s' nano ;;
        micro) printf '%s' micro ;;
        fish) printf '%s' fish ;;
        git) printf '%s' git ;;
        curl) printf '%s' curl ;;
        wget) printf '%s' wget ;;
        zip) printf '%s' zip ;;
        unzip) printf '%s' unzip ;;
        jq) printf '%s' jq ;;
        *) printf '%s' "${1:-}" ;;
    esac
}

pacote_funcional_pos_instalacao() {
    local pacote="${1:-}" comando
    [ -n "$pacote" ] || return 1
    # Se o dpkg estiver presente, ele é a fonte de verdade sobre o pacote.
    # Um ls/awk/find no PATH pode ser fornecido por outro pacote, ou pelo host.
    if command -v dpkg-query >/dev/null 2>&1; then
        dpkg-query -W -f='${Status}' "$pacote" 2>/dev/null | grep -Fqx 'install ok installed' || return 1
        case "$pacote" in
            coreutils|grep|sed|gawk|findutils|nano|micro|fish|git|curl|wget|zip|unzip|jq)
                comando="$(comando_referencia_pacote "$pacote")"
                command -v "$comando" >/dev/null 2>&1 || return 1
                return 0 ;;
            *) return 0 ;; # Pacote instalado sem executável único de referência.
        esac
    fi
    # Sem dpkg-query, a existência de comandos não comprova instalação.
    return 1
}

instalar_lista_pacotes() {
    local titulo="$1"; shift
    local -a pacotes=("$@") faltando=() indisponiveis=() falhados=() confirmados=() pulados=()
    local auto="${TERMUX_INSTALL_NONINTERACTIVE:-false}" p rc p_rc escolha
    local instalados=0 falhas=0

    # Pacotes são argumentos diretos do apt: rejeitar opções e nomes malformados.
    for p in "${pacotes[@]}"; do
        if ! pacote_nome_valido "$p"; then
            error "Nome de pacote inválido: $p"
            log "ERROR" "Instalação recusada: nome de pacote inválido: $p"
            [ "$auto" = true ] || [ "${WIZARD_MODE:-false}" = true ] || pause
            return 2
        fi
    done
    if [ "${#pacotes[@]}" -eq 0 ]; then
        warn "Nenhum pacote selecionado."
        return 1
    fi

    detectar_variante_termux
    for p in "${pacotes[@]}"; do
        if pacote_instalado_ou_funcional "$p"; then
            continue
        elif pacote_disponivel_termux "$p"; then
            faltando+=("$p")
        else
            indisponiveis+=("$p")
            log "WARN" "Pacote não disponível nesta variante do Termux: $p (${TERMUX_VARIANT_LABEL:-desconhecida})"
        fi
    done

    if [ ${#faltando[@]} -eq 0 ]; then
        cabecalho_tela "🧰 Instalar ferramentas" "$titulo"
        if [ ${#indisponiveis[@]} -gt 0 ]; then
            caixa_simples "⚠ Ambiente incompleto" \
                "Origem: $(termux_origem_resumida)" \
                "Não disponíveis: ${indisponiveis[*]}" \
                "Revise o mirror e execute pkg update."
        else
            caixa_simples "✅ Nada a instalar" "Todos os componentes já estão disponíveis."
        fi
        if [ "$auto" != true ] && [ "${WIZARD_MODE:-false}" != true ]; then pause; fi
        [ "${#indisponiveis[@]}" -eq 0 ]
        return $?
    fi

    cabecalho_tela "🧰 Instalar ferramentas" "$titulo"
    caixa_simples "Sistema do Termux" \
        "Origem: $(termux_origem_resumida)" \
        "Repositório: $(termux_repositorio_resumido)" \
        "Pacotes ausentes: ${#faltando[@]}"
    caixa_simples "Instalação em lote" "${faltando[*]}"
    if [ ${#indisponiveis[@]} -gt 0 ]; then
        caixa_simples "⚠ Compatibilidade" \
            "Não disponíveis (ambiente ficará incompleto):" \
            "${indisponiveis[*]}"
    fi
    if [ "$auto" != true ] && [ "${WIZARD_MODE:-false}" != true ]; then
        confirmar_acao "Continuar com a instalação?" || return 1
    fi

    mkdir -p "$(dirname "$TERMUX_SETUP_LOG")"
    if executar_pkg_monitorado "Instalando Ferramentas" 10 90 \
        "Pacotes: ${#faltando[@]}" "Instalação em lote pelo pkg." -- install -y "${faltando[@]}"; then
        rc=0
    else
        rc=$?
    fi
    if [ "$rc" -eq 130 ]; then
        # Nunca reiniciar automaticamente uma transação do dpkg interrompida.
        log "WARN" "Instalação interrompida: $titulo"
        return 130
    fi

    # Mesmo com apt exit 0, não marcar pacote como instalado sem dpkg válido.
    # Um lote malsucedido pode ter instalado parcialmente vários pacotes.
    local -a pendentes=()
    for p in "${faltando[@]}"; do
        if pacote_instalado_ou_funcional "$p"; then
            confirmados+=("$p")
        else
            pendentes+=("$p")
        fi
    done
    if [ "${#pendentes[@]}" -gt 0 ]; then
        [ -n "$(dpkg --audit 2>/dev/null)" ] && reparar_dpkg_automaticamente "Reparando antes do fallback" || true
        log "WARN" "Pacotes pendentes para '$titulo'; iniciando fallback individual."
        for p in "${pendentes[@]}"; do
            if executar_pkg_monitorado "Instalando Ferramentas" 10 95 \
                "Fallback: $p" "Tentativa individual." -- install -y "$p"; then
                p_rc=0
            else
                p_rc=$?
            fi
            if [ "$p_rc" -eq 130 ]; then
                log "WARN" "Instalação interrompida durante o pacote $p"
                return 130
            fi
            if pacote_instalado_ou_funcional "$p"; then
                confirmados+=("$p")
            else
                falhados+=("$p")
                log "ERROR" "Falha ao instalar/verificar pacote: $p (exit=$p_rc)"
            fi
        done
    fi
    instalados=${#confirmados[@]}
    falhas=${#falhados[@]}
    tela_operacao_termux "Instalando Ferramentas" 100 \
        "Processamento finalizado." \
        "$instalados confirmado(s) • $falhas falha(s)" \
        "✔ Pacotes verificados no Termux" \
        "$([ "$falhas" -gt 0 ] || [ "${#indisponiveis[@]}" -gt 0 ] && echo '⚠ Ambiente incompleto' || echo '✔ Nenhuma pendência')" \
        "Log: $(caminho_curto "$TERMUX_SETUP_LOG")"
    if [ "$falhas" -eq 0 ] && [ "${#indisponiveis[@]}" -eq 0 ]; then
        caixa_simples "✅ $titulo" \
            "Confirmados: $instalados" \
            "Pacotes restantes: nenhum" \
            "Gerenciador: pkg do Termux"
    else
        caixa_simples "⚠ $titulo • instalação incompleta" \
            "Confirmados: $instalados" \
            "Falhas: ${falhados[*]:-nenhuma}" \
            "Indisponíveis: ${indisponiveis[*]:-nenhum}" \
            "Log: $(caminho_curto "$TERMUX_SETUP_LOG")"
    fi
    if [ "$auto" != true ] && [ "${WIZARD_MODE:-false}" != true ]; then pause; fi
    [ "$falhas" -eq 0 ] && [ "${#indisponiveis[@]}" -eq 0 ]
}

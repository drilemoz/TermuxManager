# Módulo: runtime_processes.sh
# Processos, portas, execução e saúde de servidores.

# Valor de starttime em /proc/<pid>/stat (campo 22). Junto ao PID,
# distingue processos diferentes após reutilização do número pelo Android.
pid_inicio_ticks() {
    local pid="$1" linha resto ticks
    [[ "$pid" =~ ^[0-9]+$ ]] && [ -r "/proc/$pid/stat" ] || return 1
    IFS= read -r linha < "/proc/$pid/stat" || return 1
    # O campo comm pode conter espaços e parênteses: remova até o último ") ".
    resto="${linha##*) }"
    ticks="$(printf '%s\n' "$resto" | awk '{print $20}')"
    [[ "$ticks" =~ ^[0-9]+$ ]] || return 1
    printf '%s' "$ticks"
}

pid_identidade_confirmada() {
    local arquivo_pid="$1" pid meta esperado atual
    [ -r "$arquivo_pid" ] || return 1
    pid="$(cat "$arquivo_pid" 2>/dev/null || true)"
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    meta="${arquivo_pid%.pid}.meta"
    esperado="$(meta_valor "$meta" PID_START_TICKS 2>/dev/null || true)"
    [[ "$esperado" =~ ^[0-9]+$ ]] || return 1
    atual="$(pid_inicio_ticks "$pid" 2>/dev/null || true)"
    [ -n "$atual" ] && [ "$atual" = "$esperado" ] && kill -0 "$pid" 2>/dev/null
}

pid_ativo() {
    local arquivo_pid="$1" pid meta esperado
    [ -f "$arquivo_pid" ] || return 1
    pid="$(cat "$arquivo_pid" 2>/dev/null || true)"
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    meta="${arquivo_pid%.pid}.meta"
    esperado="$(meta_valor "$meta" PID_START_TICKS 2>/dev/null || true)"
    if [ -n "$esperado" ]; then
        # Fail closed: se a identidade não pode ser confirmada, não aceitar PID.
        pid_identidade_confirmada "$arquivo_pid"
    else
        # Arquivo legado: apenas para exibição. Nunca encerrar sem identidade.
        return 0
    fi
}

limpar_pidfiles_inativos() {
    local arquivo_pid nome
    mkdir -p "$PID_DIR"
    for arquivo_pid in "$PID_DIR"/*.pid; do
        [ -e "$arquivo_pid" ] || continue
        if ! pid_ativo "$arquivo_pid"; then
            nome="$(basename "$arquivo_pid" .pid)"
            rm -f "$arquivo_pid" "$PID_DIR/${nome}.meta"
        fi
    done
}

# ============================================================================
# IDENTIDADE E METADADOS DE PROCESSOS
# ============================================================================

id_projeto() {
    # Identidade interna baseada no caminho absoluto/canônico do projeto.
    # Isso impede colisões entre ~/Painel e ~/Painel/projetos/<nome>, mesmo
    # quando ambos possuem backend/, frontend/ ou o mesmo nome de package.
    local projeto="$1" base caminho soma
    base="$(printf '%s' "$(basename "$projeto")" | tr -cs '[:alnum:]_-' '_')"
    caminho="$(cd "$projeto" 2>/dev/null && pwd -P || readlink -f "$projeto" 2>/dev/null || printf '%s' "$projeto")"
    if comando_existe sha256sum; then
        soma="$(printf '%s' "$caminho" | sha256sum | cut -c1-12)"
    elif comando_existe shasum; then
        soma="$(printf '%s' "$caminho" | shasum -a 256 | cut -c1-12)"
    else
        soma="$(printf '%s' "$caminho" | cksum | awk '{print $1}')"
    fi
    ID_PROJETO="${base}_${soma}"
    CAMINHO_PROJETO_CANONICO="$caminho"
}

nome_processo_projeto() {
    local projeto="$1" componente="$2"
    id_projeto "$projeto"
    NOME_PROCESSO="${ID_PROJETO}_${componente}"
}

meta_valor() {
    local arquivo="$1" chave="$2"
    [ -f "$arquivo" ] || return 1
    sed -n "s/^${chave}=//p" "$arquivo" | head -n 1
}

meta_definir() {
    local arquivo="$1" chave="$2" valor="$3" tmp
    mkdir -p "$(dirname "$arquivo")"
    tmp="${arquivo}.tmp.$$"
    if [ -f "$arquivo" ]; then
        grep -v "^${chave}=" "$arquivo" > "$tmp" 2>/dev/null || true
    else
        : > "$tmp"
    fi
    printf '%s=%s\n' "$chave" "$valor" >> "$tmp"
    mv "$tmp" "$arquivo"
}


rotulo_processo() {
    local nome="$1" valor
    local meta="$PID_DIR/${nome}.meta"
    valor="$(meta_valor "$meta" LABEL 2>/dev/null || true)"
    if [ -z "$valor" ]; then
        valor="${nome%_frontend}"
        valor="${valor%_backend}"
    fi
    printf '%s' "$valor"
}

componente_processo() {
    local nome="$1" valor
    local meta="$PID_DIR/${nome}.meta"
    valor="$(meta_valor "$meta" COMPONENT 2>/dev/null || true)"
    if [ -z "$valor" ]; then
        [[ "$nome" == *_frontend ]] && valor="frontend"
        [[ "$nome" == *_backend ]] && valor="backend"
    fi
    printf '%s' "${valor:-processo}"
}

# ============================================================================
# EXECUÇÃO E SAÚDE DOS SERVIDORES
# ============================================================================

detectar_porta_frontend() {
    case "$DETECT_FRAMEWORK" in
        Vite|React|Svelte) printf '5173' ;;
        Next.js|Nuxt) printf '3000' ;;
        Vue) printf '8080' ;;
        Angular) printf '4200' ;;
        *) printf '3000' ;;
    esac
}

abrir_navegador() {
    local url="$1"
    if [ "${ABRIR_NAVEGADOR_AUTO:-true}" != true ]; then
        info "Servidor disponível em: $url"
        return 0
    fi
    info "Abrindo navegador em: $url"
    if comando_existe termux-open-url; then
        termux-open-url "$url" >>"$LOG_FILE" 2>&1 || true
    elif comando_existe termux-open; then
        termux-open "$url" >>"$LOG_FILE" 2>&1 || true
    else
        warn "termux-open não está disponível. URL: $url"
    fi
}

porta_esperada_execucao() {
    local dir="$1" cmd="$2" componente="$3" porta=""
    # Para PHP a porta do comando `php -S` prevalece sobre PORT no .env,
    # que pode pertencer à aplicação e não ao servidor de desenvolvimento.
    if [[ "$cmd" =~ php[[:space:]]+-S[[:space:]]+[^[:space:]]*:([0-9]{2,5}) ]]; then
        porta="${BASH_REMATCH[1]}"
    fi
    if ! porta_valida "$porta" && [ -f "$dir/.env" ]; then
        porta="$(grep -E '^[[:space:]]*PORT[[:space:]]*=' "$dir/.env" 2>/dev/null | tail -n 1 | cut -d= -f2- | tr -cd '0-9')"
    fi
    if ! porta_valida "$porta"; then
        porta="$(printf '%s' "$cmd" | sed -nE 's/.*--port[=[:space:]]+([0-9]{2,5}).*/\\1/p' | tail -n 1)"
    fi
    if ! porta_valida "$porta" && [[ "$cmd" =~ http\.server[[:space:]]+([0-9]{2,5}) ]]; then
        porta="${BASH_REMATCH[1]}"
    fi
    if ! porta_valida "$porta" && [ "$componente" = frontend ]; then
        porta="$(detectar_porta_frontend)"
    fi
    porta_valida "$porta" && printf '%s' "$porta"
}

executar_em_background() {
    # executar_em_background <diretorio> <comando> <nome> [projeto] [componente]
    local dir="$1" cmd="$2" nome="$3" projeto="${4:-$1}" componente="${5:-processo}"
    local logfile="$LOG_DIR/${nome}.log" pidfile="$PID_DIR/${nome}.pid" metafile="$PID_DIR/${nome}.meta"
    local pid porta_esperada=""

    porta_esperada="$(porta_esperada_execucao "$dir" "$cmd" "$componente" 2>/dev/null || true)"
    mkdir -p "$LOG_DIR" "$PID_DIR"
    if pid_ativo "$pidfile"; then
        warn "'$nome' já está ativo (PID $(cat "$pidfile"))."
        return 0
    fi

    rotacionar_log "$logfile"
    : > "$logfile"
    (
        cd "$dir" || exit 1
        nohup bash -lc "exec $cmd" >>"$logfile" 2>&1 </dev/null &
        printf '%s\n' "$!" > "$pidfile"
    ) || {
        error "Não foi possível iniciar '$nome'."
        return 1
    }

    pid="$(cat "$pidfile" 2>/dev/null || true)"
    local ticks
    ticks="$(pid_inicio_ticks "$pid" 2>/dev/null || true)"
    {
        [ -n "$ticks" ] && printf 'PID_START_TICKS=%s\n' "$ticks"
        printf 'DIR=%s\n' "$dir"
        printf 'PROJECT=%s\n' "$projeto"
        printf 'LABEL=%s\n' "$(basename "$projeto")"
        printf 'COMPONENT=%s\n' "$componente"
        printf 'CMD=%s\n' "$cmd"
        printf 'START=%s\n' "$(date +%s)"
        printf 'STATE=starting\n'
        [ -n "$porta_esperada" ] && printf 'EXPECTED_PORT=%s\n' "$porta_esperada"
    } > "$metafile"

    # Evita esperar 1 segundo fixo. Em aparelhos lentos ainda damos uma curta
    # janela para detectar encerramento imediato, mas seguimos em ~200 ms.
    sleep 0.2
    if ! pid_ativo "$pidfile"; then
        error "'$nome' encerrou logo após iniciar."
        [ "${MOSTRAR_LOG_FALHA:-true}" = true ] && [ -f "$logfile" ] && { echo; tail -n 16 "$logfile"; echo; }
        rm -f "$pidfile" "$metafile"
        return 1
    fi

    ok "'$nome' iniciado (PID $pid)."
    info "Log: $(caminho_home_relativo "$logfile")"
    log "INFO" "Processo iniciado: $nome PID=$pid componente=$componente"
    return 0
}

log_indica_falha_servidor() {
    local logf="$1"
    [ -s "$logf" ] || return 1
    tail -n 80 "$logf" 2>/dev/null | grep -qiE \
        '(Failed running|Unhandled .error.|EADDRINUSE|Cannot find module|MODULE_NOT_FOUND|SyntaxError:|ReferenceError:|TypeError:|node:events:.*|throw er;|Traceback \(most recent call last\)|address already in use|segmentation fault|panic:)'
}

porta_em_escuta() {
    local porta="$1"
    porta_valida "$porta" || return 1
    if comando_existe ss; then
        ss -ltnH 2>/dev/null | awk -v p=":$porta" '$4 ~ p"$" {achou=1; exit} END{exit !achou}' && return 0
    fi
    if comando_existe curl; then
        curl -sS --connect-timeout 1 --max-time 2 -o /dev/null "http://127.0.0.1:$porta/" >/dev/null 2>&1 && return 0
    fi
    if comando_existe nc; then
        nc -z 127.0.0.1 "$porta" >/dev/null 2>&1 && return 0
    fi
    return 1
}

estado_servidor_processo() {
    # Define ESTADO_PROCESSO, ICONE_PROCESSO e PORTA_PROCESSO.
    local nome="$1" porta
    local pf="$PID_DIR/${nome}.pid" logf="$LOG_DIR/${nome}.log"
    ESTADO_PROCESSO="encerrado"; ICONE_PROCESSO="🔴"; PORTA_PROCESSO="?"
    pid_ativo "$pf" || return 1
    porta="$(porta_processo "$nome")"
    PORTA_PROCESSO="$porta"
    if porta_valida "$porta" && porta_em_escuta "$porta"; then
        ESTADO_PROCESSO="servidor disponível"; ICONE_PROCESSO="🟢"
        return 0
    fi
    local suspeita
    suspeita="$(meta_valor "$PID_DIR/${nome}.meta" UNVERIFIED_PORT 2>/dev/null || true)"
    if log_indica_falha_servidor "$logf"; then
        ESTADO_PROCESSO="processo ativo • servidor falhou"; ICONE_PROCESSO="🟡"
    elif porta_valida "$suspeita"; then
        ESTADO_PROCESSO="porta $suspeita aberta • proprietário não confirmado"; ICONE_PROCESSO="🟡"
    else
        ESTADO_PROCESSO="processo ativo • servidor não confirmado"; ICONE_PROCESSO="🟡"
    fi
    return 2
}

aguardar_servidor_processo() {
    local nome="$1" tentativas="${2:-20}" porta
    local logf="$LOG_DIR/${nome}.log" meta="$PID_DIR/${nome}.meta"
    while [ "$tentativas" -gt 0 ]; do
        if ! pid_ativo "$PID_DIR/${nome}.pid"; then
            error "O processo '$nome' encerrou antes de disponibilizar o servidor."
            meta_definir "$meta" STATE "stopped" || true
            return 1
        fi
        porta="$(porta_processo "$nome")"
        if porta_valida "$porta" && porta_em_escuta "$porta"; then
            meta_definir "$meta" PORT "$porta" || true
            meta_definir "$meta" STATE "healthy" || true
            ok "Servidor disponível na porta $porta."
            return 0
        fi
        if log_indica_falha_servidor "$logf"; then
            if log_indica_dependencia_corrompida "$logf"; then
                meta_definir "$meta" STATE "dependency_error" || true
                error "O processo continua ativo, mas há falha de dependência na inicialização."
            else
                meta_definir "$meta" STATE "degraded" || true
                error "O processo continua ativo, mas o servidor falhou ao iniciar."
            fi
            info "Consulte o log: $(caminho_home_relativo "$logf")"
            if [ "${MOSTRAR_LOG_FALHA:-true}" = true ]; then
                if [ "$UI_LIVE_BOX_ACTIVE" = true ]; then
                    info "Detalhes completos disponíveis na Central de Diagnóstico."
                else
                    echo; tail -n 18 "$logf"; echo
                fi
            fi
            return 1
        fi
        sleep 0.35
        tentativas=$((tentativas-1))
    done
    meta_definir "$meta" STATE "degraded" || true
    warn "O processo está ativo, mas nenhuma porta de servidor foi confirmada."
    info "Ele aparecerá em 'Em execução' com estado amarelo."
    return 1
}

aguardar_backend_local() {
    local _dir="$1" nome="$2" tentativas="${3:-25}"
    info "Aguardando backend disponibilizar o servidor..."
    aguardar_servidor_processo "$nome" "$tentativas"
}

esperar_porta_e_abrir() {
    local nome="$1" porta
    info "Aguardando servidor frontend iniciar..."
    if ! aguardar_servidor_processo "$nome" "${TEMPO_DETECTAR_PORTA:-30}"; then
        return 1
    fi
    porta="$(porta_processo "$nome")"
    porta_valida "$porta" || {
        warn "Servidor ativo, mas a porta não pôde ser identificada."
        return 1
    }
    abrir_navegador "http://127.0.0.1:$porta"
}

confirmar_inicio() {
    local projeto="$1" acao="$2"
    [ "${CONFIRMAR_EXECUCAO:-true}" = true ] || return 0
    cabecalho_tela "🚀 Confirmar execução" "$(basename "$projeto")"
    caixa_linha_topo
    caixa_linha_texto "Ação: $acao"
    [ -n "$FRONT_DIR" ] && caixa_linha_texto "Frontend: $FRONT_FRAMEWORK"
    [ -n "$BACK_DIR" ] && caixa_linha_texto "Backend: $BACK_FRAMEWORK"
    caixa_linha_baixo
    rodape_atalhos "[0] Voltar  •  [Enter] Iniciar"
    ui_buffer_flush
    read -r RESPOSTA_MENU
    [ -z "$RESPOSTA_MENU" ]
}

menu_executar_projeto() {
    local projeto="$1" nome_front="" nome_back="" op rodape descricao_back rotulo_back
    local itens=()
    if [ -z "$FRONT_DIR" ] && [ -z "$BACK_DIR" ]; then
        error "Nenhum componente executável foi detectado."
        pause
        return 1
    fi
    if [ -n "$FRONT_DIR" ]; then
        nome_processo_projeto "$projeto" frontend; nome_front="$NOME_PROCESSO"
        itens+=("1|🌐|Executar frontend|Iniciar $FRONT_FRAMEWORK")
    fi
    if [ -n "$BACK_DIR" ]; then
        nome_processo_projeto "$projeto" backend; nome_back="$NOME_PROCESSO"
        descricao_back="Executar backend"
        rotulo_back="Iniciar backend"
        case "$BACK_FRAMEWORK" in
            PHP|Laravel)
                descricao_back="Iniciar site PHP"
                rotulo_back="Iniciar site PHP"
                ;;
        esac
        if [ -n "$FRONT_DIR" ]; then
            itens+=("2|🧰|$descricao_back|Iniciar $BACK_FRAMEWORK")
        else
            # Projeto com componente único: sempre opção 1, independentemente
            # de ser backend (PHP/Python/API) ou frontend (Vite/React).
            itens+=("1|🧰|$descricao_back|Iniciar $BACK_FRAMEWORK")
        fi
    fi
    if [ -n "$FRONT_DIR" ] && [ -n "$BACK_DIR" ]; then
        itens+=("3|🧩|Executar sistema|Iniciar os dois componentes")
        rodape="[0] Cancelar  •  [1–3] Executar"
    else
        rodape="[0] Cancelar  •  [1] Executar"
    fi
    itens+=("0|🔙|Cancelar|Voltar sem iniciar")
    menu_unificado "🚀 Executar projeto" "$(basename "$projeto")" "$rodape" "${itens[@]}"
    ler_opcao; op="$RESPOSTA_MENU"
    # No projeto com backend único, a opção 1 deve iniciar esse backend.
    # Não aceitar 2 invisível, nem encaminhar 1 para frontend inexistente.
    if [ -z "$FRONT_DIR" ] && [ -n "$BACK_DIR" ]; then
        if [ "$op" = "1" ]; then
            op="2"
        elif [ "$op" = "2" ]; then
            op="invalida"
        fi
    fi
    case "$op" in
        1)
            [ -n "$FRONT_DIR" ] || { error "Frontend não detectado."; pause; return; }
            confirmar_inicio "$projeto" "Iniciar frontend" || return
            DETECT_FRAMEWORK="$FRONT_FRAMEWORK"
            executar_em_background "$FRONT_DIR" "$FRONT_RUN_CMD" "$nome_front" "$projeto" frontend || { pause; return; }
            esperar_porta_e_abrir "$nome_front"
            ;;
        2)
            [ -n "$BACK_DIR" ] || { error "Backend não detectado."; pause; return; }
            confirmar_inicio "$projeto" "$rotulo_back" || return
            executar_em_background "$BACK_DIR" "$BACK_RUN_CMD" "$nome_back" "$projeto" backend || { pause; return; }
            if aguardar_backend_local "$BACK_DIR" "$nome_back" 20; then
                # PHP puro/Laravel disponibiliza páginas, não somente uma API.
                # Para o portal local, abrir o navegador como fazemos com Vite.
                if [ -z "$FRONT_DIR" ]; then
                    case "$BACK_FRAMEWORK" in
                        PHP|Laravel)
                            local porta_php
                            porta_php="$(porta_processo "$nome_back")"
                            porta_valida "$porta_php" && abrir_navegador "http://127.0.0.1:$porta_php"
                            ;;
                    esac
                fi
            fi
            ;;
        3)
            [ -n "$FRONT_DIR" ] && [ -n "$BACK_DIR" ] || { error "Sistema completo não detectado."; pause; return; }
            confirmar_inicio "$projeto" "Iniciar sistema completo" || return
            executar_em_background "$BACK_DIR" "$BACK_RUN_CMD" "$nome_back" "$projeto" backend || { pause; return; }
            DETECT_FRAMEWORK="$FRONT_FRAMEWORK"
            executar_em_background "$FRONT_DIR" "$FRONT_RUN_CMD" "$nome_front" "$projeto" frontend || { parar_processo "$nome_back" >/dev/null 2>&1 || true; pause; return; }
            if ! aguardar_backend_local "$BACK_DIR" "$nome_back" 25; then
                warn "Backend indisponível; encerrando o frontend iniciado em paralelo."
                parar_processo "$nome_front" >/dev/null 2>&1 || true
                pause; return
            fi
            esperar_porta_e_abrir "$nome_front"
            ;;
        0) info "Execução cancelada." ;;
        *) warn "Opção inválida." ;;
    esac
    pause
}

porta_valida() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

porta_pid_direto() {
    local pid="$1" porta=""
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1

    if comando_existe ss; then
        porta=$(ss -ltnpH 2>/dev/null | awk -v pid="$pid" '
            index($0, "pid=" pid ",") {
                addr=$4
                sub(/^.*:/, "", addr)
                if (addr ~ /^[0-9]+$/) { print addr; exit }
            }')
    fi

    if [ -z "$porta" ] && comando_existe lsof; then
        porta=$(lsof -Pan -p "$pid" -iTCP -sTCP:LISTEN 2>/dev/null             | awk 'NR>1 {addr=$9; sub(/^.*:/, "", addr); if (addr ~ /^[0-9]+$/) {print addr; exit}}')
    fi

    porta_valida "$porta" && printf '%s' "$porta"
}

porta_arvore_pid() {
    local pid="$1" porta filho
    porta="$(porta_pid_direto "$pid" 2>/dev/null || true)"
    if porta_valida "$porta"; then
        printf '%s' "$porta"
        return 0
    fi
    while IFS= read -r filho; do
        [ -n "$filho" ] || continue
        porta="$(porta_arvore_pid "$filho" 2>/dev/null || true)"
        if porta_valida "$porta"; then
            printf '%s' "$porta"
            return 0
        fi
    done < <(pgrep -P "$pid" 2>/dev/null || true)
    return 1
}

porta_log_estrita() {
    local logf="$1" porta=""
    [ -f "$logf" ] || return 1

    # URLs explícitas: exige dois-pontos e uma porta; nunca extrai o último octeto do IP.
    porta=$(grep -oE '(https?://)?(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\]):[0-9]{2,5}' "$logf" 2>/dev/null         | grep -oE '[0-9]{2,5}$' | tail -n 1)

    # Frases comuns de servidores. Evita o padrão amplo "port + qualquer número".
    if [ -z "$porta" ]; then
        porta=$(grep -oiE '(listening|running|started|server|local)[^[:cntrl:]]{0,32}(port|porta|:)[[:space:]]*[0-9]{2,5}' "$logf" 2>/dev/null             | grep -oE '[0-9]{2,5}$' | tail -n 1)
    fi

    porta_valida "$porta" && printf '%s' "$porta"
}

# Confirma que um socket LISTEN está no processo ou na sua árvore.
# A porta simplesmente responder não é evidência de que pertence ao projeto.
porta_pertence_pid() {
    local pid="$1" porta="$2" hex inode alvo fd
    [[ "$pid" =~ ^[0-9]+$ ]] && porta_valida "$porta" || return 1
    if comando_existe ss; then
        if ss -ltnpH 2>/dev/null | awk -v p=":$porta" -v pid="pid=$pid," '
            $4 ~ p"$" && index($0,pid) {ok=1; exit} END {exit !ok}'; then
            return 0
        fi
    fi
    # Fallback para instalações onde ss não mostra o proprietário.
    # /proc/net/tcp* lista o inode e /proc/PID/fd identifica o socket.
    hex="$(printf '%04X' "$porta")"
    local inodes=""
    inodes="$(awk -v port=":$hex" '$2 ~ port"$" && $4 == "0A" { print $10 }' \
        /proc/net/tcp /proc/net/tcp6 2>/dev/null || true)"
    [ -n "$inodes" ] || return 1
    for fd in "/proc/$pid/fd/"*; do
        [ -L "$fd" ] || continue
        alvo="$(readlink "$fd" 2>/dev/null || true)"
        case "$alvo" in
            'socket:['*']')
                inode="${alvo#socket:[}"; inode="${inode%]}"
                if printf '%s\n' "$inodes" | grep -Fqx "$inode"; then
                    return 0
                fi
                ;;
        esac
    done
    return 1
}

porta_pertence_arvore() {
    local pid="$1" porta="$2" filho
    porta_pertence_pid "$pid" "$porta" && return 0
    while IFS= read -r filho; do
        [ -n "$filho" ] || continue
        if porta_pertence_arvore "$filho" "$porta"; then
            return 0
        fi
    done < <(pgrep -P "$pid" 2>/dev/null || true)
    return 1
}

porta_processo() {
    local nome="$1" logf="$LOG_DIR/${nome}.log" meta="$PID_DIR/${nome}.meta"
    local pid porta candidato="" alternativa=""
    pid="$(cat "$PID_DIR/${nome}.pid" 2>/dev/null || true)"
    [[ "$pid" =~ ^[0-9]+$ ]] || { printf '?\n'; return 0; }
    local chave
    for chave in PORT EXPECTED_PORT; do
        porta="$(meta_valor "$meta" "$chave" 2>/dev/null || true)"
        if porta_valida "$porta" && porta_em_escuta "$porta"; then
            if porta_pertence_arvore "$pid" "$porta"; then
                meta_definir "$meta" PORT "$porta" || true
                meta_definir "$meta" UNVERIFIED_PORT "" || true
                printf '%s\n' "$porta"
                return 0
            fi
            candidato="$porta"
        fi
    done
    # Detecta uma porta dinâmica alternativa, que pode ser diferente da .env.
    for chave in arvore log; do
        if [ "$chave" = arvore ]; then
            porta="$(porta_arvore_pid "$pid" 2>/dev/null || true)"
        else
            porta="$(porta_log_estrita "$logf" 2>/dev/null || true)"
        fi
        if porta_valida "$porta" && porta_em_escuta "$porta"; then
            if porta_pertence_arvore "$pid" "$porta"; then
                meta_definir "$meta" PORT "$porta" || true
                meta_definir "$meta" UNVERIFIED_PORT "" || true
                printf '%s\n' "$porta"
                return 0
            fi
            candidato="$porta"
        fi
    done
    # Diferenciar "porta não detectada" de "porta aberta sem dono comprovado".
    meta_definir "$meta" PORT "" || true
    meta_definir "$meta" UNVERIFIED_PORT "$candidato" || true
    printf '?\n'
}

encerrar_arvore_processo() {
    local pid="$1" sinal="${2:-TERM}" filho
    while IFS= read -r filho; do
        [ -n "$filho" ] && encerrar_arvore_processo "$filho" "$sinal"
    done < <(pgrep -P "$pid" 2>/dev/null || true)
    kill -"$sinal" "$pid" 2>/dev/null || true
}

parar_processo() {
    local nome="$1" pid
    local pf="$PID_DIR/${nome}.pid"
    if ! pid_ativo "$pf"; then
        rm -f "$pf"
        warn "O processo '$nome' já não está ativo."
        return 1
    fi
    if ! pid_identidade_confirmada "$pf"; then
        warn "Processo com identidade não verificada; encerramento bloqueado."
        info "Reinicie o Manager ou encerre manualmente após conferir o PID."
        return 1
    fi
    pid=$(cat "$pf")
    encerrar_arvore_processo "$pid" TERM
    sleep 1
    if pid_identidade_confirmada "$pf"; then
        encerrar_arvore_processo "$pid" KILL
    fi
    rm -f "$pf" "$PID_DIR/${nome}.meta"
    ok "Processo '$nome' encerrado."
    log "INFO" "Processo encerrado: $nome PID=$pid"
}

mostrar_log_processo() {
    local nome="$1"
    local logf="$LOG_DIR/${nome}.log"
    cabecalho_tela "📋 Log da execução" "$nome"
    if [ -f "$logf" ]; then
        tail -n 40 "$logf"
    else
        warn "Log não encontrado: $logf"
    fi
    pause
}

abrir_frontend_ativo() {
    local nome="$1" porta
    porta=$(porta_processo "$nome")
    if [ "$porta" = "?" ]; then
        warn "A porta ainda não foi identificada. Consulte o log."
        pause
        return
    fi
    abrir_navegador "http://127.0.0.1:$porta"
}

tela_execucao() {
    local nome="$1" componente projeto_base porta op outro
    componente="$(componente_processo "$nome")"
    [ "$componente" = frontend ] && componente="Frontend"
    [ "$componente" = backend ] && componente="Backend"
    projeto_base="$(rotulo_processo "$nome")"
    local grupo="${nome%_frontend}"; grupo="${grupo%_backend}"

    while pid_ativo "$PID_DIR/${nome}.pid"; do
        estado_servidor_processo "$nome" >/dev/null 2>&1 || true
        porta="$PORTA_PROCESSO"
        local estado_atual="$ESTADO_PROCESSO" icone_atual="$ICONE_PROCESSO"
        if [ "$componente" = "Frontend" ]; then
            outro="${grupo}_backend"
            local itens=()
            if porta_valida "$porta" && porta_em_escuta "$porta"; then
                itens+=("1|🌐|Abrir no navegador|http://127.0.0.1:$porta")
            else
                itens+=("1|⚠️|Servidor indisponível|A porta do frontend não está respondendo")
            fi
            itens+=("2|📋|Ver log|Mostrar as últimas 40 linhas" "3|🛑|Parar frontend|Encerrar somente este componente")
            pid_ativo "$PID_DIR/${outro}.pid" && itens+=("4|🛑|Parar sistema completo|Encerrar frontend e backend deste projeto")
            menu_unificado "$icone_atual $projeto_base — $componente" "PID $(cat "$PID_DIR/${nome}.pid") • Porta $porta • $estado_atual" "[0] Voltar" "${itens[@]}"
            ler_opcao; op="$RESPOSTA_MENU"
            case "$op" in
                1) if porta_valida "$porta" && porta_em_escuta "$porta"; then abrir_frontend_ativo "$nome"; else warn "Servidor indisponível. Consulte o log."; pause; fi ;;
                2) mostrar_log_processo "$nome" ;;
                3) parar_processo "$nome"; pause; return ;;
                4)
                    pid_ativo "$PID_DIR/${outro}.pid" || { error "O backend não está ativo."; pause; continue; }
                    confirmar_acao "Encerrar frontend e backend de '$projeto_base'?" || continue
                    parar_processo "$nome"; parar_processo "$outro"; pause; return
                    ;;
                0) return ;;
                *) warn "Opção inválida."; pause ;;
            esac
        else
            outro="${grupo}_frontend"
            local itens=(
                "1|📋|Ver log|Mostrar as últimas 40 linhas"
                "2|🛑|Parar backend|Encerrar somente este componente"
            )
            pid_ativo "$PID_DIR/${outro}.pid" && itens+=("3|🛑|Parar sistema completo|Encerrar backend e frontend deste projeto")
            menu_unificado "$icone_atual $projeto_base — $componente" "PID $(cat "$PID_DIR/${nome}.pid") • Porta $porta • $estado_atual" "[0] Voltar" "${itens[@]}"
            ler_opcao; op="$RESPOSTA_MENU"
            case "$op" in
                1) mostrar_log_processo "$nome" ;;
                2) parar_processo "$nome"; pause; return ;;
                3)
                    pid_ativo "$PID_DIR/${outro}.pid" || { error "O frontend não está ativo."; pause; continue; }
                    confirmar_acao "Encerrar backend e frontend de '$projeto_base'?" || continue
                    parar_processo "$nome"; parar_processo "$outro"; pause; return
                    ;;
                0) return ;;
                *) warn "Opção inválida."; pause ;;
            esac
        fi
    done
}

# ==========================================================================
# CENTRAL DE EXECUÇÃO — serviços locais e projetos (v1.0.130)
# ==========================================================================

# PHP e Node são ambientes instalados, NÃO daemons. O indicador de execução
# pertence aos projetos/PIDs monitorados. MariaDB e phpMyAdmin têm verificações
# próprias, pois não usam os PID files dos projetos.
central_status_servicos() {
    CENTRAL_PHP_STATUS="não instalado"
    CENTRAL_NODE_STATUS="não instalado"
    CENTRAL_DB_STATUS="não instalado"
    CENTRAL_PMA_STATUS="não instalado"
    comando_existe php && CENTRAL_PHP_STATUS="instalado" || true
    comando_existe node && CENTRAL_NODE_STATUS="instalado" || true

    if comando_existe mariadbd && comando_existe mariadb-admin; then
        CENTRAL_DB_STATUS="parado"
        if pma_db_ativo; then
            if pma_db_tcp_ativo; then
                CENTRAL_DB_STATUS="ativo • TCP 3306 OK"
            else
                CENTRAL_DB_STATUS="ativo • TCP 3306 indisponível"
            fi
        elif pma_db_tcp_ativo; then
            CENTRAL_DB_STATUS="TCP 3306 responde • socket não confirmado"
        fi
    fi

    if pma_instalado; then
        CENTRAL_PMA_STATUS="instalado • parado"
        pma_web_ativo && CENTRAL_PMA_STATUS="servidor ativo • 127.0.0.1:8081" || true
    fi
}

# Seleciona apenas projetos cuja stack detectada realmente usa o ambiente.
# Um interpretador PHP ou Node instalado, sozinho, não constitui projeto web.
central_projeto_compativel() {
    local dir="$1" ambiente="$2"
    detectar_estrutura_projeto "$dir"
    case "$ambiente" in
        php)
            case "${FRONT_FRAMEWORK:-}:${BACK_FRAMEWORK:-}" in
                PHP:*|Laravel:*|*:PHP|*:Laravel) return 0 ;;
            esac
            ;;
        node)
            case "${FRONT_GERENCIADOR:-}:${BACK_GERENCIADOR:-}" in
                npm:*|pnpm:*|yarn:*|*:npm|*:pnpm|*:yarn) return 0 ;;
            esac
            ;;
    esac
    return 1
}

central_iniciar_projeto() {
    local ambiente="$1" entrada dir escolha i=1 label
    local -a candidatos=() itens=()
    if [ "$ambiente" = php ]; then
        if ! comando_existe php; then
            caixa_simples "PHP não instalado" "Instale PHP pelo menu Ambiente e ferramentas."
            pause; return 0
        fi
        label="PHP"
    elif [ "$ambiente" = node ]; then
        if ! comando_existe node; then
            caixa_simples "Node.js não instalado" "Instale Node.js pelo menu Ambiente e ferramentas."
            pause; return 0
        fi
        label="Node.js"
    else
        return 1
    fi

    descobrir_entradas
    for entrada in "${PROJETOS_ENCONTRADOS[@]}"; do
        dir="${entrada%%|*}"
        if central_projeto_compativel "$dir" "$ambiente"; then
            candidatos+=("$dir")
            nome_amigavel_projeto "$dir"
            itens+=("$i|📦|$NOME_PROJETO|$(caminho_curto "$dir")")
            i=$((i+1))
        fi
    done
    if [ "${#candidatos[@]}" -eq 0 ]; then
        caixa_simples "Nenhum projeto $label encontrado" \
            "Importe um projeto ou verifique a estrutura no menu Meus projetos." \
            "Não foi iniciado nenhum processo."
        pause; return 0
    fi
    menu_unificado "🚀 Iniciar projeto $label" "Selecione o projeto pelo número" \
        "[0] Cancelar  •  [número] Selecionar" "${itens[@]}"
    ler_opcao; escolha="$RESPOSTA_MENU"
    [ "$escolha" = 0 ] && return 0
    if [[ "$escolha" =~ ^[0-9]+$ ]] && [ "$escolha" -ge 1 ] && [ "$escolha" -le ${#candidatos[@]} ]; then
        # Reutiliza toda a validação de dependências, permissões, confirmação,
        # PID e health checks da execução normal do projeto.
        testar_projeto "${candidatos[$((escolha-1))]}"
    else
        warn "Opção inválida."; pause
    fi
}

central_atalho_phpmyadmin() {
    if pma_web_ativo; then
        pma_parar_web
    elif ! pma_instalado; then
        caixa_simples "phpMyAdmin não instalado" \
            "O instalador seguro está disponível em Ambiente e ferramentas > PHP > phpMyAdmin."
        pause
    else
        pma_iniciar_web
    fi
}

central_abrir_phpmyadmin() {
    if pma_web_ativo; then
        pma_abrir_web
    else
        caixa_simples "phpMyAdmin parado" "Inicie o phpMyAdmin pelo atalho [M] antes de abrir."
        pause
    fi
}

# Início conjunto fica limitado a um projeto explicitamente selecionado
# (ou ao único projeto detectado). Não inicia todos os repositórios às cegas.
central_perfil_arquivo() { printf '%s/.termux-manager/central-iniciar-tudo-projeto' "$HOME"; }

central_projetos_candidatos() {
    local entrada dir
    CENTRAL_CANDIDATOS=()
    descobrir_entradas
    for entrada in "${PROJETOS_ENCONTRADOS[@]}"; do
        dir="${entrada%%|*}"
        [ -d "$dir" ] || continue
        if central_projeto_compativel "$dir" php || central_projeto_compativel "$dir" node; then
            CENTRAL_CANDIDATOS+=("$dir")
        fi
    done
}

central_perfil_selecionar() {
    # central_perfil_selecionar [configurar]: false retorna o projeto salvo
    # ou o único encontrado sem mostrar seleção; true permite trocar o perfil.
    local configurar="${1:-false}" salvo="" escolha i dir arq
    local -a itens=()
    central_projetos_candidatos
    CENTRAL_PROJETO_ESCOLHIDO=""
    arq="$(central_perfil_arquivo)"
    [ -f "$arq" ] && IFS= read -r salvo < "$arq" || true
    if [ "$configurar" != true ] && [ "$salvo" = SERVICOS_APENAS ]; then
        return 0
    fi
    if [ "$configurar" != true ] && [ -n "$salvo" ]; then
        for dir in "${CENTRAL_CANDIDATOS[@]}"; do
            if [ "$dir" = "$salvo" ]; then
                CENTRAL_PROJETO_ESCOLHIDO="$dir"; return 0
            fi
        done
    fi
    if [ "$configurar" != true ] && [ "${#CENTRAL_CANDIDATOS[@]}" -eq 1 ]; then
        CENTRAL_PROJETO_ESCOLHIDO="${CENTRAL_CANDIDATOS[0]}"
        return 0
    fi
    if [ "${#CENTRAL_CANDIDATOS[@]}" -eq 0 ]; then
        [ "$configurar" = true ] && caixa_simples "Sem projetos" "Importe um projeto PHP ou Node antes de configurar o início conjunto."
        return 0
    fi
    for ((i=0;i<${#CENTRAL_CANDIDATOS[@]};i++)); do
        dir="${CENTRAL_CANDIDATOS[i]}"
        nome_amigavel_projeto "$dir"
        itens+=("$((i+1))|📦|$NOME_PROJETO|$(caminho_curto "$dir")")
    done
    menu_unificado "🚀 Projeto de início conjunto" \
        "Selecione uma vez. A escolha ficará salva e poderá ser trocada em [C]." \
        "[0] Apenas serviços • [número] Selecionar projeto" "${itens[@]}"
    ler_opcao; escolha="$RESPOSTA_MENU"
    if [ "$escolha" = 0 ]; then
        # Escolha explícita: persistir perfil sem projeto para não repetir a pergunta.
        (umask 077; mkdir -p "$(dirname "$arq")" && printf 'SERVICOS_APENAS\n' > "$arq.tmp.$$" && mv -f -- "$arq.tmp.$$" "$arq") || return 1
        [ "$configurar" = true ] && caixa_simples "Perfil atualizado" "Somente serviços serão iniciados."
        return 0
    fi
    if ! [[ "$escolha" =~ ^[0-9]+$ ]] || [ "$escolha" -lt 1 ] || [ "$escolha" -gt "${#CENTRAL_CANDIDATOS[@]}" ]; then
        warn "Seleção inválida; nenhum perfil alterado."
        return 1
    fi
    dir="${CENTRAL_CANDIDATOS[$((escolha-1))]}"
    # Salvar de forma atômica, com permissões restritas. Nunca executar o conteúdo como shell.
    (umask 077; mkdir -p "$(dirname "$arq")" && printf '%s\n' "$dir" > "$arq.tmp.$$" && mv -f -- "$arq.tmp.$$" "$arq") || return 1
    CENTRAL_PROJETO_ESCOLHIDO="$dir"
    return 0
}

central_iniciar_componente_lote() {
    local projeto="$1" tipo="$2" dir="$3" cmd="$4" framework="$5"
    local nome porta previa
    [ -n "$dir" ] && [ -n "$cmd" ] || return 1
    nome_processo_projeto "$projeto" "$tipo"; nome="$NOME_PROCESSO"
    if pid_ativo "$PID_DIR/${nome}.pid"; then
        info "$tipo já está ativo e será preservado."
        return 0
    fi
    previa="$DETECT_FRAMEWORK"
    DETECT_FRAMEWORK="$framework"
    porta="$(porta_esperada_execucao "$dir" "$cmd" "$tipo" 2>/dev/null || true)"
    DETECT_FRAMEWORK="$previa"
    if porta_valida "$porta" && porta_em_escuta "$porta"; then
        warn "Porta $porta já ocupada por outro processo; $tipo não iniciado."
        return 1
    fi
    executar_em_background "$dir" "$cmd" "$nome" "$projeto" "$tipo" || return 1
    if ! aguardar_servidor_processo "$nome" 15; then
        warn "Verifique o log de $tipo na Central de Execução."
        return 1
    fi
    return 0
}

central_iniciar_projeto_lote() {
    local projeto="$1" front_dir front_cmd front_fw back_dir back_cmd back_fw
    [ -d "$projeto" ] || { warn "Projeto não existe mais."; return 1; }
    detectar_estrutura_projeto "$projeto"
    front_dir="$FRONT_DIR"; front_cmd="$FRONT_RUN_CMD"; front_fw="$FRONT_FRAMEWORK"
    back_dir="$BACK_DIR"; back_cmd="$BACK_RUN_CMD"; back_fw="$BACK_FRAMEWORK"
    [ -n "$front_dir" ] || [ -n "$back_dir" ] || { warn "Projeto sem componentes executáveis."; return 1; }
    local falha=0
    # Não instala pacotes ou dependências em segundo plano; usa o ambiente já pronto.
    if [ -n "$back_dir" ]; then
        case "$back_fw" in
            PHP|Laravel) comando_existe php || { warn "PHP não instalado."; falha=1; } ;;
            Node.js|Express|NestJS|Fastify|Koa) comando_existe node || { warn "Node.js não instalado."; falha=1; } ;;
        esac
        if [ "$falha" -eq 0 ]; then
            central_iniciar_componente_lote "$projeto" backend "$back_dir" "$back_cmd" "$back_fw" || falha=1
        fi
    fi
    if [ -n "$front_dir" ]; then
        if ! comando_existe node; then
            warn "Node.js não instalado; frontend não iniciado."
            falha=1
        elif [ "$falha" -eq 0 ]; then
            central_iniciar_componente_lote "$projeto" frontend "$front_dir" "$front_cmd" "$front_fw" || falha=1
        else
            warn "Frontend não iniciado porque o backend não ficou disponível."
        fi
    fi
    [ "$falha" -eq 0 ]
}

central_iniciar_tudo() {
    local projeto="" falhas=0 servicos=0 resumo=""
    # A única escolha necessária é feita no primeiro uso com vários projetos.
    central_perfil_selecionar false || { pause; return 1; }
    projeto="$CENTRAL_PROJETO_ESCOLHIDO"
    cabecalho_tela "🚀 Iniciar tudo" "Serviços e projeto selecionado"
    [ -n "$projeto" ] && info "Projeto: $(caminho_curto "$projeto")" || info "Nenhum projeto selecionado: somente serviços."
    # MariaDB primeiro: site PHP pode depender de TCP 3306.
    if comando_existe mariadbd && comando_existe mariadb-admin; then
        if pma_iniciar_db --lote; then
            servicos=$((servicos+1))
            pma_db_tcp_ativo || warn "MariaDB por socket OK, mas TCP 3306 não confirmado. IguaNews pode falhar."
        else
            falhas=$((falhas+1))
        fi
    else
        info "MariaDB não instalado; ignorado."
    fi
    if pma_instalado; then
        if pma_iniciar_web --lote; then servicos=$((servicos+1)); else falhas=$((falhas+1)); fi
    else
        info "phpMyAdmin não instalado; ignorado."
    fi
    if [ -n "$projeto" ]; then
        if central_iniciar_projeto_lote "$projeto"; then servicos=$((servicos+1)); else falhas=$((falhas+1)); fi
    fi
    printf '\n'
    central_status_servicos
    caixa_simples "Resultado do início conjunto" \
        "MariaDB: $CENTRAL_DB_STATUS" \
        "phpMyAdmin: $CENTRAL_PMA_STATUS" \
        "Projeto: ${projeto:-nenhum selecionado}" \
        "Etapas sem erro: $servicos • Falhas: $falhas" \
        "Abra [R] para atualizar ou escolha um processo para ver o log."
    pause
    [ "$falhas" -eq 0 ]
}

menu_processos_ativos() {
    while true; do
        limpar_pidfiles_inativos
        local nomes=() pf nome i=1 comp porta rotulo estado icone detalhe
        for pf in "$PID_DIR"/*.pid; do
            [ -e "$pf" ] || continue
            pid_ativo "$pf" || continue
            nomes+=("$(basename "$pf" .pid)")
        done
        central_status_servicos
        cabecalho_tela "🚦 Central de execução" \
            "${#nomes[@]} componente(s) de projetos gerenciados"
        if [ ${#nomes[@]} -eq 0 ]; then
            caixa_simples "📭 Projetos" "Nenhum processo de projeto gerenciado está ativo."
        else
            caixa_linha_topo
            for nome in "${nomes[@]}"; do
                comp="$(componente_processo "$nome")"
                [ "$comp" = frontend ] && comp="Frontend"
                [ "$comp" = backend ] && comp="Backend"
                rotulo="$(rotulo_processo "$nome")"
                estado_servidor_processo "$nome" >/dev/null 2>&1 || true
                porta="$PORTA_PROCESSO"; estado="$ESTADO_PROCESSO"; icone="$ICONE_PROCESSO"
                if porta_valida "$porta"; then
                    detalhe="$comp • PID $(cat "$PID_DIR/${nome}.pid") • Porta $porta • $estado"
                else
                    detalhe="$comp • PID $(cat "$PID_DIR/${nome}.pid") • $estado"
                fi
                menu_opcao "$i" "$icone" "$rotulo" "$detalhe"
                i=$((i+1))
            done
            caixa_linha_baixo
        fi

        caixa_linha_topo
        menu_opcao "T" "🚀" "Iniciar tudo" "MariaDB, phpMyAdmin e projeto escolhido"
        menu_opcao "C" "⚙️" "Configurar início conjunto" "Escolher projeto padrão"
        menu_opcao "P" "🐘" "Projetos PHP" "PHP: $CENTRAL_PHP_STATUS • iniciar projeto"
        menu_opcao "N" "🟢" "Projetos Node.js" "Node: $CENTRAL_NODE_STATUS • iniciar projeto"
        menu_opcao "D" "🗄️" "Iniciar / verificar MariaDB" "$CENTRAL_DB_STATUS"
        menu_opcao "M" "🌐" "Iniciar / parar phpMyAdmin" "$CENTRAL_PMA_STATUS"
        menu_opcao "W" "📱" "Abrir phpMyAdmin" "http://127.0.0.1:8081 (somente local)"
        menu_opcao "R" "🔄" "Atualizar estados" "Consultar projetos e serviços novamente"
        caixa_linha_baixo
        rodape_atalhos "[0] Voltar • [T] Iniciar tudo • [C] Configurar • [P/N/D/M/W/R] Serviços • [A] Parar projetos • [número] Gerenciar"
        ler_opcao
        case "${RESPOSTA_MENU,,}" in
            0) return ;;
            t) central_iniciar_tudo || true ;;
            c) central_perfil_selecionar true || true ;;
            p) central_iniciar_projeto php ;;
            n) central_iniciar_projeto node ;;
            d) pma_iniciar_db || true ;;
            m) central_atalho_phpmyadmin ;;
            w) central_abrir_phpmyadmin ;;
            r) continue ;;
            a)
                if [ "${#nomes[@]}" -eq 0 ]; then
                    caixa_simples "Sem projetos ativos" "Nenhum processo gerenciado será encerrado." \
                        "O MariaDB e o phpMyAdmin não são afetados por esta opção."
                    pause
                elif confirmar_acao "Encerrar apenas os processos de projetos gerenciados?"; then
                    for nome in "${nomes[@]}"; do parar_processo "$nome" || true; done
                    pause
                fi
                ;;
            *)
                if [[ "$RESPOSTA_MENU" =~ ^[0-9]+$ ]] && [ "$RESPOSTA_MENU" -ge 1 ] && [ "$RESPOSTA_MENU" -le ${#nomes[@]} ]; then
                    tela_execucao "${nomes[$((RESPOSTA_MENU-1))]}"
                else
                    warn "Opção inválida."; pause
                fi
                ;;
        esac
    done
}

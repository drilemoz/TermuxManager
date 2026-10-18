# Submódulo: updater_auto.sh
# Verificação opcional na abertura, sem bloquear o primeiro assistente e sem
# iniciar downloads, upgrades do Termux ou instalações sem confirmação.

AUTO_UPDATE_INTERVALO_OK=86400     # 24 horas
AUTO_UPDATE_INTERVALO_ERRO=21600   # 6 horas se a rede falhar

auto_update_estado_arquivo() {
    printf '%s' "$BASE_DIR/.updates/auto-check.state"
}

auto_update_deve_verificar() {
    [ "${AUTO_UPDATE_ENABLED:-true}" = true ] || return 1
    [ -f "$FIRST_RUN_FILE" ] || return 1
    # Nunca consumir entrada de scripts, pipes, tarefas agendadas ou testes.
    [ -t 0 ] && [ -t 1 ] || return 1
    command -v curl >/dev/null 2>&1 || return 1
    local arquivo agora anterior estado espera idade
    arquivo="$(auto_update_estado_arquivo)"
    [ -f "$arquivo" ] || return 0
    IFS='|' read -r anterior estado < "$arquivo" || true
    [[ "$anterior" =~ ^[0-9]{1,12}$ ]] || return 0
    [[ "$estado" = ok || "$estado" = erro ]] || return 0
    agora="$(date +%s)"
    [[ "$agora" =~ ^[0-9]+$ ]] || return 0
    idade=$((agora - anterior))
    [ "$idade" -ge 0 ] || return 0
    if [ "$estado" = ok ]; then espera=$AUTO_UPDATE_INTERVALO_OK; else espera=$AUTO_UPDATE_INTERVALO_ERRO; fi
    [ "$idade" -ge "$espera" ]
}

auto_update_marcar_consulta() {
    local status="$1" diretorio arquivo tmp atual
    [[ "$status" = ok || "$status" = erro ]] || return 0
    arquivo="$(auto_update_estado_arquivo)"
    diretorio="$(dirname "$arquivo")"
    mkdir -p "$diretorio" 2>/dev/null || return 0
    atual="$(date +%s)"
    [[ "$atual" =~ ^[0-9]+$ ]] || return 0
    tmp="${arquivo}.$$"
    if printf '%s|%s\n' "$atual" "$status" > "$tmp" 2>/dev/null; then
        mv -f -- "$tmp" "$arquivo" 2>/dev/null || rm -f -- "$tmp"
    fi
    return 0
}

verificar_atualizacoes_ao_iniciar() {
    auto_update_deve_verificar || return 0
    printf '\n🔎 Verificando atualizações do Manager no GitHub...\n'
    local consulta_rc=0
    GITHUB_UPDATE_INTERACTIVE=false
    GITHUB_UPDATE_AUTO_FAST=true
    GITHUB_CURL_ERROR=""
    consultar_atualizacao_github || consulta_rc=$?
    GITHUB_UPDATE_AUTO_FAST=false
    if [ "$consulta_rc" -ne 0 ]; then
        auto_update_marcar_consulta erro
        printf 'ℹ Sem atualização automática no momento (rede indisponível ou consulta falhou).\n'
        return 0
    fi
    # Registrar antes da pergunta e eventual exec após instalar. Na abertura
    # seguinte, não incomoda o usuário novamente nem interrompe o pós-update.
    auto_update_marcar_consulta ok
    case "$GITHUB_UPDATE_STATE" in
        new)
            # A apresentação do changelog e a instalação continuam sujeitas
            # às confirmações existentes no instalador transacional.
            processar_atualizacao_github_consultada || true
            ;;
        same|older)
            printf '✔ Manager %s: nenhuma versão mais nova disponível.\n' "$MANAGER_VERSION"
            ;;
    esac
    return 0
}

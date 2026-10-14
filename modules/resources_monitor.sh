# Módulo: resources_monitor.sh
# Consulta pontual de informações locais. Sem daemon, sem sondagem contínua.

recursos_memoria_livre_mib() {
    local kb
    [ -r /proc/meminfo ] || { printf 'indisponível'; return; }
    kb="$(awk '$1 == "MemAvailable:" {print $2; exit}' /proc/meminfo 2>/dev/null)"
    [[ "$kb" =~ ^[0-9]+$ ]] && printf '%s MiB' "$((kb / 1024))" || printf 'indisponível'
}

recursos_carga_cpu() {
    local carga nucleos
    [ -r /proc/loadavg ] || { printf 'indisponível'; return; }
    read -r carga _ < /proc/loadavg || true
    [[ "$carga" =~ ^[0-9]+(\.[0-9]+)?$ ]] || { printf 'indisponível'; return; }
    nucleos="$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
    if [[ "$nucleos" =~ ^[0-9]+$ ]] && [ "$nucleos" -gt 0 ]; then
        printf '%s (1 min) / %s CPUs' "$carga" "$nucleos"
    else
        printf '%s (1 min)' "$carga"
    fi
}

recursos_armazenamento_livre() {
    local kb
    kb="$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2 {print $4; exit}')"
    [[ "$kb" =~ ^[0-9]+$ ]] && printf '%s MiB' "$((kb / 1024))" || printf 'indisponível'
}

menu_painel_recursos() {
    while true; do
        cabecalho_tela "📊 Recursos do aparelho" "Leitura pontual, sem serviço residente"
        caixa_simples "Indicadores" \
            "RAM disponível: $(recursos_memoria_livre_mib)" \
            "Carga média da CPU: $(recursos_carga_cpu)" \
            "Armazenamento livre (Termux): $(recursos_armazenamento_livre)" \
            "Modo econômico: $([ "${MODO_ECONOMICO:-false}" = true ] && echo ativado || echo desativado)"
        caixa_simples "Interpretação" \
            "Carga da CPU não representa uso em porcentagem." \
            "Android pode restringir /proc e df." \
            "Nenhum monitor fica em execução após sair."
        rodape_atalhos "[Enter] Atualizar agora • [0] Voltar"
        ui_buffer_flush
        local opcao
        read -r -p '> ' opcao || return 0
        [ "$opcao" = 0 ] && return 0
    done
}

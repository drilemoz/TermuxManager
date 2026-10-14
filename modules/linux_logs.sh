# Logs privados de sessões Linux e exportação opcional para Downloads.
# Nenhum processo residente é necessário. SIGKILL não pode executar traps.
linux_logs_pasta() { printf '%s/sessoes\n' "$LINUX_STATE_DIR"; }
linux_logs_config() { printf '%s/logs.conf\n' "$LINUX_STATE_DIR"; }
linux_logs_inicializar() {
    [ ! -L "$LINUX_STATE_DIR" ] || return 1
    (umask 077; mkdir -p -- "$LINUX_STATE_DIR" "$(linux_logs_pasta)") || return 1
    [ ! -L "$(linux_logs_pasta)" ] || return 1
    chmod 700 "$LINUX_STATE_DIR" "$(linux_logs_pasta)" 2>/dev/null || true
}
linux_logs_preferencia() {
    local campo="$1" padrao="$2" c linha
    c="$(linux_logs_config)"
    [ -f "$c" ] && [ ! -L "$c" ] || { printf '%s\n' "$padrao"; return; }
    linha="$(grep -E "^${campo}=(manual|falha|todas|[0-9]+)$" "$c" 2>/dev/null | tail -n 1 || true)"
    [ -n "$linha" ] && printf '%s\n' "${linha#*=}" || printf '%s\n' "$padrao"
}
linux_logs_salvar_preferencias() {
    local modo="$1" limite="$2" arq tmp
    case "$modo" in manual|falha|todas) ;; *) return 2 ;; esac
    [[ "$limite" =~ ^[0-9]+$ ]] && [ "$limite" -ge 2 ] && [ "$limite" -le 30 ] || return 2
    linux_logs_inicializar || return 1
    arq="$(linux_logs_config)"; [ ! -L "$arq" ] || return 1
    tmp="$arq.$$"; [ ! -e "$tmp" ] && [ ! -L "$tmp" ] || return 1
    (umask 077; printf 'modo=%s\nlimite=%s\n' "$modo" "$limite" > "$tmp") || return 1
    mv -f -- "$tmp" "$arq"
}
linux_logs_rotacionar() {
    local limite excess n=0 f
    linux_logs_inicializar || return 1
    limite="$(linux_logs_preferencia limite 10)"
    [[ "$limite" =~ ^[0-9]+$ ]] && [ "$limite" -ge 2 ] && [ "$limite" -le 30 ] || limite=10
    local -a logs=()
    mapfile -t logs < <(find "$(linux_logs_pasta)" -maxdepth 1 -type f -name 'sessao-*.log' -printf '%f\n' 2>/dev/null | LC_ALL=C sort -r)
    for f in "${logs[@]}"; do
        n=$((n + 1))
        [ "$n" -le "$limite" ] && continue
        rm -f -- "$(linux_logs_pasta)/$f"
    done
    # Nunca apagar relatórios já exportados sem ação explícita do usuário.
}
linux_logs_nova_sessao() {
    local alias="$1" tipo="$2" arquivo seq=0
    [[ "$alias" =~ ^[a-zA-Z0-9_.-]{1,64}$ ]] || return 1
    [[ "$tipo" =~ ^[a-zA-Z0-9_.-]{1,32}$ ]] || return 1
    linux_logs_inicializar || return 1
    # Rotaciona o log geral ao iniciar uma sessão (sem modificar Downloads).
    if [ -f "$LINUX_LOG" ] && [ ! -L "$LINUX_LOG" ] && [ "$(wc -c < "$LINUX_LOG")" -gt 2097152 ]; then
        [ ! -L "${LINUX_LOG}.anterior" ] && mv -f -- "$LINUX_LOG" "${LINUX_LOG}.anterior" && (umask 077; : > "$LINUX_LOG") || true
    fi
    arquivo="$(linux_logs_pasta)/sessao-$(date '+%Y%m%d-%H%M%S')-$$-$alias-$tipo.log"
    while [ -e "$arquivo" ] || [ -L "$arquivo" ]; do
        seq=$((seq + 1)); [ "$seq" -le 99 ] || return 1
        arquivo="$(linux_logs_pasta)/sessao-$(date '+%Y%m%d-%H%M%S')-$$-$alias-$tipo-$seq.log"
    done
    (umask 077; printf 'Início: %s\nDistribuição: %s\nTipo: %s\n' "$(date -Is)" "$alias" "$tipo" > "$arquivo") || return 1
    LINUX_LOGS_SESSAO_ATUAL="$arquivo"
    linux_logs_rotacionar
}
linux_logs_encerrar_sessao() {
    local rc="$1" arq="${LINUX_LOGS_SESSAO_ATUAL:-}"
    if [ -f "$arq" ] && [ ! -L "$arq" ]; then
        printf 'Término: %s\nStatus de saída: %s\n' "$(date -Is)" "$rc" >> "$arq"
    fi
    LINUX_LOGS_SESSAO_ATUAL=""
    linux_logs_auto_exportar "$rc"
}
linux_logs_auto_exportar() {
    local rc="$1" modo
    modo="$(linux_logs_preferencia modo manual)"
    if [ "$modo" = todas ] || { [ "$modo" = falha ] && [ "$rc" -ne 0 ]; }; then
        linux_exportar_log_downloads >/dev/null 2>&1 && linux_log 'Logs: exportação automática para Downloads concluída' || linux_log 'Logs: exportação automática falhou (permissão ou espaço)'
    fi
}
linux_logs_capturar_desktop_guest() {
    # Consulta SOB DEMANDA; não inicia processos em background nem lê credenciais.
    # Os caminhos são fixos e internos à distribuição, nunca vindos do usuário.
    local alias="$1" desktop="$2" origem='' destino rc=0
    [[ "$alias" =~ ^[a-zA-Z0-9_.-]{1,64}$ ]] || return 1
    case "$desktop" in
      lxde) origem='/root/.cache/lxsession/LXDE/run.log' ;;
      xfce) origem='/root/.cache/sessions' ;;
      lxqt) origem='/root/.cache/lxqt' ;;
      mate) origem='/root/.cache/mate-session' ;;
      *) return 2 ;;
    esac
    linux_logs_inicializar || return 1
    destino="$LINUX_STATE_DIR/guest-desktop.log"
    [ ! -L "$destino" ] || return 1
    local cmd
    # Apenas caminhos fixos; não interpretar dados não confiáveis como shell.
    cmd="if [ -f '$origem' ]; then tail -c 65536 '$origem'; elif [ -d '$origem' ]; then find '$origem' -maxdepth 1 -type f -name '*.log' -exec tail -c 8192 {} \\;; else echo 'Log específico do desktop indisponível'; fi"
    if command -v timeout >/dev/null 2>&1; then
        timeout 15s proot-distro login "$alias" -- /bin/sh -lc "$cmd" > "$destino" 2>&1 || rc=$?
    else
        proot-distro login "$alias" -- /bin/sh -lc "$cmd" > "$destino" 2>&1 || rc=$?
    fi
    chmod 600 "$destino" 2>/dev/null || true
    return "$rc"
}
linux_logs_verificar_interrupcao() {
    local pendente assinatura processado modo
    pendente="$(linux_x11_marcador_sessao)"
    [ -f "$pendente" ] && [ ! -L "$pendente" ] || return 0
    assinatura="$(cksum < "$pendente" 2>/dev/null || true)"
    processado="$LINUX_STATE_DIR/last-interruption.reported"
    [ ! -L "$processado" ] || return 1
    if [ -f "$processado" ] && [ "$(cat "$processado")" = "$assinatura" ]; then return 0; fi
    linux_log 'X11: sessão não finalizada detectada ao abrir o menu Linux'
    modo="$(linux_logs_preferencia modo manual)"
    if [ "$modo" = falha ] || [ "$modo" = todas ]; then
        linux_exportar_log_downloads >/dev/null 2>&1 || true
    else
        caixa_simples 'Sessão gráfica interrompida' \
            'A execução anterior não retornou ao Manager. Isso não comprova SIGKILL.' \
            'O log privado foi preservado. Use Ajuda > Logs > Copiar para Downloads.'
    fi
    (umask 077; printf '%s\n' "$assinatura" > "$processado")
}
linux_logs_historico() {
    local -a logs=(); local f
    linux_logs_inicializar || return 1
    mapfile -t logs < <(find "$(linux_logs_pasta)" -maxdepth 1 -type f -name 'sessao-*.log' -printf '%f\n' | LC_ALL=C sort -r | head -n 15)
    cabecalho_tela '📚 Sessões Linux' 'Arquivos privados disponíveis'
    if [ ${#logs[@]} -eq 0 ]; then printf 'Nenhuma sessão registrada.\n'; else
        for f in "${logs[@]}"; do printf '%s\n' "$f"; done
    fi
    pause
}
linux_logs_menu() {
    local escolha modo limite
    while true; do
        modo="$(linux_logs_preferencia modo manual)"; limite="$(linux_logs_preferencia limite 10)"
        menu_unificado '📋 Logs do Linux' "Exportação: $modo • Histórico: $limite sessões" \
            '[0] Voltar  •  [1–8] Selecionar' \
            '1|📥|Copiar diagnóstico|Salvar em Downloads com sanitização' \
            '2|🛑|Exportar só após falha|Também na próxima abertura após interrupção' \
            '3|✅|Exportar ao terminar|Copia após sucesso ou erro' \
            '4|🔒|Somente manual|Não copiar automaticamente para Downloads' \
            '5|📚|Histórico de sessões|Exibir os últimos registros privados' \
            '6|🧹|Limpar logs de sessões|Mantém log central e backups' \
            '7|🔢|Limite de histórico|Escolher 5, 10 ou 20 sessões' \
            '8|🖥️|Capturar log do desktop|LXDE, XFCE, LXQt ou MATE (sob demanda)'
        ler_opcao; escolha="$RESPOSTA_MENU"
        case "$escolha" in
            1) linux_exportar_log_downloads || true; pause ;;
            2) confirmar_acao 'Exportar automaticamente após erros para Downloads?' 'n' && linux_logs_salvar_preferencias falha "$limite" ;;
            3) confirmar_acao 'Exportar após TODAS as sessões para Downloads?' 'n' && linux_logs_salvar_preferencias todas "$limite" ;;
            4) linux_logs_salvar_preferencias manual "$limite" ;;
            5) linux_logs_historico ;;
            6) if confirmar_acao 'Apagar registros privados de sessões antigas?' 'n'; then
                   linux_logs_inicializar && find "$(linux_logs_pasta)" -maxdepth 1 -type f -name 'sessao-*.log' -delete
               fi ;;
            7) menu_unificado 'Histórico de logs' 'Quantidade de sessões privadas' '[0] Voltar' '1|🔢|5 sessões|Menos espaço' '2|🔢|10 sessões|Padrão' '3|🔢|20 sessões|Histórico maior'; ler_opcao
               case "$RESPOSTA_MENU" in 1) linux_logs_salvar_preferencias "$modo" 5;; 2) linux_logs_salvar_preferencias "$modo" 10;; 3) linux_logs_salvar_preferencias "$modo" 20;; esac ;;
            8) if linux_selecionar_instalada 'Log do desktop' 'Distribuição de origem'; then
                   local alias="$LINUX_DISTRO_ALIAS" escolha_desktop='' rc=0
                   menu_unificado 'Log do desktop' 'Localizar o log do ambiente gráfico' '[0] Voltar' \
                       '1|🖥️|LXDE|lxsession' '2|🖥️|XFCE|xfce4-session' '3|🖥️|LXQt|lxqt-session' '4|🖥️|MATE|mate-session'
                   ler_opcao
                   case "$RESPOSTA_MENU" in 1) escolha_desktop=lxde;;2) escolha_desktop=xfce;;3) escolha_desktop=lxqt;;4) escolha_desktop=mate;;esac
                   if [ -n "$escolha_desktop" ]; then
                       linux_logs_capturar_desktop_guest "$alias" "$escolha_desktop" || rc=$?
                       if [ "$rc" -eq 0 ]; then ok 'Log privado obtido. Use Copiar diagnóstico para exportar.'; else warn 'Não foi possível obter o log do desktop; consulte o relatório central.'; fi
                       pause
                   fi
               fi ;;
            0) return 0 ;;
            *) feedback_curto 'Opção inválida.' ;;
        esac
    done
}

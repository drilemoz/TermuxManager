# Módulo: commands_favorites.sh
# Comandos locais favoritos: nunca executados automaticamente.
# Arquivo privado, com campos em base64 para preservar espaços e caracteres especiais.

favoritos_arquivo() {
    printf '%s/.manager-favoritos' "$PAINEL_DIR"
}

favoritos_listar() {
    local arquivo linha nome_b64 cmd_b64 nome cmd qtd=0
    arquivo="$(favoritos_arquivo)"
    [ -f "$arquivo" ] || return 0
    [ ! -L "$arquivo" ] || { warn "Arquivo de favoritos não pode ser um link."; return 1; }
    [ "$(wc -c < "$arquivo")" -le 65536 ] || { warn "Arquivo de favoritos excede o limite."; return 1; }
    while IFS=$'\t' read -r nome_b64 cmd_b64 linha || [ -n "$nome_b64" ]; do
        [ -n "$nome_b64" ] && [ -n "$cmd_b64" ] || continue
        [ "${#nome_b64}" -le 128 ] && [ "${#cmd_b64}" -le 2048 ] || continue
        nome="$(printf '%s' "$nome_b64" | base64 -d 2>/dev/null)" || continue
        cmd="$(printf '%s' "$cmd_b64" | base64 -d 2>/dev/null)" || continue
        [[ "$nome" != *$'\n'* && "$cmd" != *$'\n'* ]] || continue
        [ -n "$nome" ] && [ -n "$cmd" ] || continue
        qtd=$((qtd + 1))
        [ "$qtd" -le 12 ] || break
        printf '%s\t%s\n' "$nome_b64" "$cmd_b64"
    done < "$arquivo"
}

favoritos_salvar_linhas() {
    local arquivo tmp linha
    arquivo="$(favoritos_arquivo)"
    mkdir -p "$PAINEL_DIR" || return 1
    [ ! -L "$arquivo" ] || { error "Destino de favoritos é um link simbólico."; return 1; }
    # mktemp no mesmo diretório permite publicação atômica com mv.
    tmp="$(umask 077; mktemp "$PAINEL_DIR/.manager-favoritos.XXXXXX")" || return 1
    for linha in "$@"; do printf '%s\n' "$linha" >> "$tmp" || { rm -f "$tmp"; return 1; }; done
    chmod 600 "$tmp" || { rm -f "$tmp"; return 1; }
    mv -f -- "$tmp" "$arquivo" || { rm -f "$tmp"; return 1; }
}

favoritos_adicionar() {
    local nome="${1:-}" cmd="${2:-}" linha
    [[ "$nome" =~ ^[^[:cntrl:]]{1,32}$ ]] || { warn "Nome inválido (1–32 caracteres)."; return 1; }
    [ -n "$cmd" ] && [ "${#cmd}" -le 500 ] && [[ "$cmd" != *$'\n'* && "$cmd" != *$'\r'* ]] || {
        warn "Comando inválido (uma linha, até 500 caracteres)."; return 1;
    }
    local -a dados=()
    mapfile -t dados < <(favoritos_listar) || return 1
    [ "${#dados[@]}" -lt 12 ] || { warn "Limite de 12 favoritos atingido."; return 1; }
    local n_b64 c_b64 n_dec
    for linha in "${dados[@]}"; do
        n_b64="${linha%%$'\t'*}"
        n_dec="$(printf '%s' "$n_b64" | base64 -d)" || return 1
        [ "$n_dec" != "$nome" ] || { warn "Esse nome já existe."; return 1; }
    done
    n_b64="$(printf '%s' "$nome" | base64 | tr -d '\n')"
    c_b64="$(printf '%s' "$cmd" | base64 | tr -d '\n')"
    dados+=("${n_b64}"$'\t'"${c_b64}")
    favoritos_salvar_linhas "${dados[@]}"
}

favoritos_excluir_indice() {
    local indice="${1:-}" i
    [[ "$indice" =~ ^[0-9]+$ ]] && [ "$indice" -ge 1 ] || return 1
    local -a dados=() mantidos=()
    mapfile -t dados < <(favoritos_listar) || return 1
    [ "$indice" -le "${#dados[@]}" ] || return 1
    for ((i=0; i<${#dados[@]}; i++)); do
        [ "$i" -eq "$((indice-1))" ] || mantidos+=("${dados[i]}")
    done
    favoritos_salvar_linhas "${mantidos[@]}"
}

menu_comandos_favoritos() {
    local -a linhas=() itens=()
    local i linha n_b64 c_b64 nome comando
    while true; do
        linhas=(); itens=()
        mapfile -t linhas < <(favoritos_listar)
        for ((i=0; i<${#linhas[@]}; i++)); do
            linha="${linhas[i]}"
            n_b64="${linha%%$'\t'*}"
            nome="$(printf '%s' "$n_b64" | base64 -d)"
            itens+=("$((i+1))|⌨️|$nome|Executar somente após confirmação")
        done
        menu_unificado "⌨️ Comandos favoritos" "${#linhas[@]} de 12 comandos locais" \
            "[0] Voltar • [A] Adicionar • [R] Remover" "${itens[@]}"
        ler_opcao
        case "${RESPOSTA_MENU,,}" in
            0) return ;;
            a)
                cabecalho_tela "Adicionar favorito" "Não salve tokens ou senhas aqui"
                local novo_nome novo_cmd
                read -r -p "Nome: " novo_nome || continue
                read -r -p "Comando Bash (uma linha): " novo_cmd || continue
                if favoritos_adicionar "$novo_nome" "$novo_cmd"; then ok "Favorito salvo."; fi
                pause ;;
            r)
                [ "${#linhas[@]}" -gt 0 ] || { warn "Não há favoritos."; pause; continue; }
                read -r -p "Número para remover: " i || continue
                if [[ "$i" =~ ^[0-9]+$ ]] && [ "$i" -ge 1 ] && [ "$i" -le "${#linhas[@]}" ]; then
                    nome="$(printf '%s' "${linhas[$((i-1))]%%$'\t'*}" | base64 -d)"
                    if confirmar_acao "Remover '$nome'?" "n"; then favoritos_excluir_indice "$i"; fi
                fi ;;
            *)
                i="$RESPOSTA_MENU"
                if [[ "$i" =~ ^[0-9]+$ ]] && [ "$i" -ge 1 ] && [ "$i" -le "${#linhas[@]}" ]; then
                    linha="${linhas[$((i-1))]}"
                    n_b64="${linha%%$'\t'*}"; c_b64="${linha#*$'\t'}"
                    nome="$(printf '%s' "$n_b64" | base64 -d)"
                    comando="$(printf '%s' "$c_b64" | base64 -d)"
                    cabecalho_tela "Executar favorito" "$nome"
                    printf 'Comando: %s\n\n' "$comando"
                    if confirmar_acao "Executar este comando no seu Termux?" "n"; then
                        ( cd "$HOME" && bash -c "$comando" ) || warn "Comando terminou com erro."
                        pause
                    fi
                else
                    feedback_curto "Opção inválida."
                fi ;;
        esac
    done
}

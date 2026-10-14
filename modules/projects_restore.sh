# Submódulo: projects_restore.sh
# Restauração assistida de backups TAR.GZ, sem substituir projetos existentes.

projeto_python_restauracao() {
    local candidato
    for candidato in python3 python; do
        if command -v "$candidato" >/dev/null 2>&1 && \
            "$candidato" -c 'import sys; sys.exit(sys.version_info < (3, 8))' >/dev/null 2>&1; then
            printf '%s' "$candidato"
            return 0
        fi
    done
    return 1
}

listar_backups_restauraveis() {
    BACKUPS_RESTAURAVEIS=()
    local arquivo diretorio
    local -A adicionados=()
    # Inclui backups novos em Downloads e antigos armazenados dentro do Painel.
    for diretorio in "${DOWNLOADS_DIR:-$HOME/storage/downloads}/projetos/backups" "${BACKUPS_DIR:-$HOME/Painel/backups}"; do
        [ -d "$diretorio" ] || continue
        while IFS= read -r -d '' arquivo; do
            [ -n "${adicionados[$arquivo]:-}" ] && continue
            BACKUPS_RESTAURAVEIS+=("$arquivo")
            adicionados["$arquivo"]=1
        done < <(find "$diretorio" -mindepth 1 -maxdepth 1 -type f -name '*.tar.gz' -print0 2>/dev/null | sort -z)
    done
}

restaurar_backup_projeto() {
    local arquivo="$1" interpretador ferramenta saida nome qtd bytes destino escolha novo_nome caminho
    ferramenta="${BASE_DIR}/tools/restore_project_backup.py"
    if ! interpretador="$(projeto_python_restauracao)"; then
        error "A restauração precisa de Python 3.8 ou superior. No Termux: pkg install python"
        pause
        return 1
    fi
    if [ ! -r "$ferramenta" ]; then
        error "Ferramenta de restauração não encontrada na instalação."
        pause
        return 1
    fi
    if ! saida="$("$interpretador" "$ferramenta" inspect "$arquivo" 2>&1)"; then
        error "Backup inválido ou inseguro: $saida"
        pause
        return 1
    fi
    IFS=$'\t' read -r nome qtd bytes <<< "$saida"
    cabecalho_tela "♻️ Restaurar projeto" "Inspeção concluída, sem modificar arquivos"
    caixa_simples "Prévia do backup" \
        "Arquivo: $(basename "$arquivo")" \
        "Pasta: $nome" \
        "Arquivos: $qtd" \
        "Conteúdo: $(formatar_tamanho "$bytes")" \
        "Credenciais removidas no backup público não serão recuperadas."
    rodape_atalhos "[1] Restaurar em projetos  •  [2] Raiz do Painel  •  [0] Cancelar"
    ler_opcao
    case "$RESPOSTA_MENU" in
        1) destino="$PROJETOS_DIR" ;;
        2) destino="$PAINEL_DIR" ;;
        *) return 0 ;;
    esac
    mkdir -p -- "$destino" || { error "Não foi possível criar a pasta de destino."; pause; return 1; }
    novo_nome="$nome"
    if [ -e "$destino/$novo_nome" ] || [ -L "$destino/$novo_nome" ]; then
        warn "A pasta '$novo_nome' já existe. Ela não será substituída."
        read -r -p "Nome diferente para o projeto (ENTER cancela): " novo_nome
        [ -n "$novo_nome" ] || { info "Cancelado, projeto original preservado."; return 0; }
    fi
    caminho="$destino/$novo_nome"
    caixa_simples "Confirmar restauração" "Origem: $(basename "$arquivo")" \
        "Destino: $(caminho_curto "$caminho")" \
        "Não sobrescreve pastas existentes." \
        "Espaço livre será verificado antes da extração."
    confirmar_acao "Restaurar o projeto neste destino?" "n" || return 0
    if ! saida="$("$interpretador" "$ferramenta" restore "$arquivo" "$destino" "$novo_nome" 2>&1)"; then
        error "$saida"
        pause
        return 1
    fi
    ok "Restauração concluída: $(caminho_curto "$saida")"
    info "Dependências e credenciais excluídas do backup devem ser recuperadas separadamente."
    log "INFO" "Projeto restaurado de $(basename "$arquivo") para $saida"
    pause
}

menu_restaurar_backup_projeto() {
    local i arquivo
    local -a opcoes=()
    while true; do
        listar_backups_restauraveis
        if [ "${#BACKUPS_RESTAURAVEIS[@]}" -eq 0 ]; then
            cabecalho_tela "♻️ Restaurar projeto" "Nenhum TAR.GZ encontrado"
            caixa_simples "Onde procurar" "Downloads/projetos/backups" "~/Painel/backups (legado)"
            pause
            return 0
        fi
        opcoes=()
        i=1
        for arquivo in "${BACKUPS_RESTAURAVEIS[@]}"; do
            opcoes+=("$i|💾|$(basename "$arquivo")|$(formatar_tamanho "$(stat -c%s "$arquivo" 2>/dev/null || echo 0)")")
            i=$((i+1))
        done
        menu_unificado "♻️ RESTAURAR BACKUP" "Arquivos TAR.GZ disponíveis" \
            "[0] Voltar  •  [número] Visualizar" "${opcoes[@]}"
        ler_opcao
        [ "$RESPOSTA_MENU" = 0 ] && return 0
        if [[ "$RESPOSTA_MENU" =~ ^[0-9]+$ ]] && [ "$RESPOSTA_MENU" -ge 1 ] && [ "$RESPOSTA_MENU" -le "${#BACKUPS_RESTAURAVEIS[@]}" ]; then
            restaurar_backup_projeto "${BACKUPS_RESTAURAVEIS[$((RESPOSTA_MENU-1))]}"
        else
            feedback_curto "Opção inválida."
        fi
    done
}

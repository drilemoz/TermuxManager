# Módulo: explorer.sh — Explorer de arquivos (Termux Manager v1.0.125)
# Navegação e operações por menus, sem interpretar entradas como comandos shell.
# Cada ação ocorre sob as permissões normais do Termux, sem root.

EXPLORER_CLIP_PATH=""
EXPLORER_CLIP_MODE=""  # copiar | mover
EXPLORER_DIR=""
EXPLORER_PAGE=0
EXPLORER_PAGE_SIZE=10

explorer_canonico() {
    # Canonicaliza caminhos existentes com -P; mantém o caminho sob controle.
    (cd -P -- "$1" 2>/dev/null && pwd -P)
}

explorer_nome_exibicao() {
    local nome="${1##*/}"
    nome="${nome//$'\n'/ }"
    nome="${nome//$'\r'/ }"
    nome="${nome//$'\t'/ }"
    nome="${nome//|/¦}"
    printf '%s' "$nome"
}

explorer_protegido() {
    # Bloqueia exclusão, renomeação e movimentação da própria instalação,
    # raízes do Android/Termux e metadados ativos do Manager.
    local caminho="$1" abs base protegido item
    abs="$(realpath -m -- "$caminho" 2>/dev/null)" || return 0
    [ -n "$abs" ] || return 0
    case "$abs" in
        /|/data|/data/data|/storage|/storage/emulated|/storage/emulated/0|/storage/self|/storage/self/primary|/sdcard|/mnt|/proc|/proc/*|/sys|/sys/*|/dev|/dev/*|/system|/system/*|/vendor|/vendor/*|/apex|/apex/*|/product|/product/*)
            return 0 ;;
    esac
    for protegido in "${HOME:-/}" "${PREFIX:-/nonexistent-prefix}" "${BASE_DIR:-/nonexistent-manager}" \
        "${PAINEL_DIR:-/nonexistent-painel}" "${PROJETOS_DIR:-/nonexistent-projetos}" \
        "${HOME:-/}/storage" "${HOME:-/}/.termux" \
        "${LOG_DIR:-/nonexistent-logs}" "${PID_DIR:-/nonexistent-pids}" \
        "${INSTANCE_LOCK:-/nonexistent-lock}" "${CONFIG_FILE:-/nonexistent-config}"; do
        base="$(realpath -m -- "$protegido" 2>/dev/null)" || continue
        [ -n "$base" ] || continue
        # Protege o item, seus descendentes se técnicos e seus ancestrais.
        if [ "$abs" = "$base" ]; then return 0; fi
        case "$base/" in "$abs/"*) return 0 ;; esac
        case "$abs/" in "$base/"*)
            # Apenas a instalação, arquivos internos de controle e seus subitens.
            case "$protegido" in
                "${BASE_DIR:-/nonexistent-manager}"|"${PREFIX:-/nonexistent-prefix}"|"${LOG_DIR:-/nonexistent-logs}"|"${PID_DIR:-/nonexistent-pids}"|"${INSTANCE_LOCK:-/nonexistent-lock}"|"${HOME:-/}/.termux") return 0 ;;
            esac
            ;;
        esac
    done
    return 1
}

explorer_destino_restrito() {
    # Itens do Manager e do próprio runtime do Termux são navegáveis,
    # mas não recebem novos arquivos/pastas pelo Explorer.
    local dir="${1:-}" abs raiz base
    abs="$(realpath -m -- "$dir" 2>/dev/null)" || return 0
    for raiz in "${PREFIX:-/nonexistent-prefix}" "${BASE_DIR:-/nonexistent-manager}" \
        "${LOG_DIR:-/nonexistent-logs}" "${PID_DIR:-/nonexistent-pids}" \
        "${INSTANCE_LOCK:-/nonexistent-lock}" "${HOME:-/}/.termux"; do
        base="$(realpath -m -- "$raiz" 2>/dev/null)" || continue
        case "$abs/" in "$base/"*) return 0 ;; esac
    done
    return 1
}

explorer_nome_valido() {
    local nome="$1"
    [[ -n "$nome" && "$nome" != . && "$nome" != .. && "$nome" != */* && "$nome" != *$'\n'* && "$nome" != *$'\r'* && "$nome" != *$'\t'* && "$nome" != *'|'* ]]
}

explorer_existe() { [ -e "$1" ] || [ -L "$1" ]; }

explorer_operar_renomear() {
    local src="$1" nome="$2" dst
    explorer_existe "$src" || { warn "Item não existe mais."; return 1; }
    explorer_protegido "$src" && { warn "Pasta ou arquivo protegido. Operação bloqueada."; return 1; }
    explorer_nome_valido "$nome" || { warn "Nome inválido: use apenas o nome, sem barras."; return 1; }
    dst="$(dirname -- "$src")/$nome"
    [ "$src" = "$dst" ] && { warn "O nome não foi alterado."; return 1; }
    explorer_existe "$dst" && { warn "Já existe outro item com esse nome."; return 1; }
    mv -- "$src" "$dst" || { warn "Falha ao renomear. Verifique as permissões."; return 1; }
    ok "Renomeado para: $nome"
}

explorer_colar() {
    local src="$EXPLORER_CLIP_PATH" modo="$EXPLORER_CLIP_MODE" dir="$EXPLORER_DIR" dst nome resolved_src resolved_dest
    if [ -z "$src" ] || [ -z "$modo" ]; then warn "Nenhum item para colar."; return 1; fi
    explorer_existe "$src" || { warn "Origem não existe mais; seleção cancelada."; EXPLORER_CLIP_PATH=""; EXPLORER_CLIP_MODE=""; return 1; }
    [ -d "$dir" ] && [ -w "$dir" ] || { warn "Destino não está disponível para escrita."; return 1; }
    explorer_destino_restrito "$dir" && { warn "Destino protegido: não é permitido alterar a instalação."; return 1; }
    if explorer_protegido "$src"; then
        # A cópia da instalação é permitida, mas não o deslocamento.
        if [ "$modo" = mover ]; then warn "Origem protegida, não é possível mover."; return 1; fi
    fi
    nome="${src##*/}"
    dst="$dir/$nome"
    if explorer_existe "$dst"; then warn "Já existe '$nome' no destino. Nada foi substituído."; return 1; fi
    resolved_src="$(realpath -m -- "$src" 2>/dev/null)" || return 1
    resolved_dest="$(realpath -m -- "$dst" 2>/dev/null)" || return 1
    # Impede diretório ser copiado para si mesmo (inclusive via symlinks).
    if [ -d "$src" ]; then
        case "$resolved_dest/" in "$resolved_src/"*) warn "Não é possível colar uma pasta dentro dela mesma."; return 1 ;; esac
    fi
    if [ "$modo" = mover ]; then
        if explorer_protegido "$src"; then warn "Origem protegida."; return 1; fi
        if ! mv -- "$src" "$dst"; then warn "Falha ao mover. Confira espaço e permissões."; return 1; fi
        EXPLORER_CLIP_PATH=""
        EXPLORER_CLIP_MODE=""
        ok "Movido para $(caminho_home_relativo "$dir")"
    elif [ "$modo" = copiar ]; then
        # cp -R é compatível com armazenamento compartilhado Android (que não
        # implementa chmod/chown usados por cp -a). Symlinks são preservados.
        if ! cp -R -- "$src" "$dst"; then
            warn "Cópia incompleta ou falhou; verifique o destino antes de tentar novamente."
            return 1
        fi
        ok "Copiado para $(caminho_home_relativo "$dir")"
    else
        warn "Operação desconhecida."; return 1
    fi
}

explorer_excluir() {
    local src="$1" texto nome
    explorer_existe "$src" || { warn "Item não existe mais."; return 1; }
    explorer_protegido "$src" && { warn "Item protegido: exclusão bloqueada."; return 1; }
    nome="$(explorer_nome_exibicao "$src")"
    if [ -d "$src" ] && [ ! -L "$src" ]; then
        texto="Excluir a pasta '$nome' e TODO seu conteúdo?"
    else
        texto="Excluir permanentemente '$nome'?"
    fi
    echo
    warn "Exclusão definitiva, sem lixeira: $(caminho_home_relativo "$src")"
    confirmar_acao "$texto" || { info "Exclusão cancelada."; return 1; }
    # -- e o caminho original previnem interpretação de nomes como opções.
    if [ -d "$src" ] && [ ! -L "$src" ]; then
        rm -r -- "$src" || { warn "Não foi possível excluir tudo. Confira permissões."; return 1; }
    else
        rm -- "$src" || { warn "Não foi possível excluir."; return 1; }
    fi
    [ "$EXPLORER_CLIP_PATH" = "$src" ] && { EXPLORER_CLIP_PATH=""; EXPLORER_CLIP_MODE=""; }
    ok "Excluído: $nome"
}

explorer_nova_pasta() {
    local nome="$1" destino="$EXPLORER_DIR/$1"
    explorer_nome_valido "$nome" || { warn "Nome de pasta inválido."; return 1; }
    explorer_existe "$destino" && { warn "Já existe uma pasta ou arquivo com esse nome."; return 1; }
    [ -w "$EXPLORER_DIR" ] || { warn "Sem permissão de escrita."; return 1; }
    explorer_destino_restrito "$EXPLORER_DIR" && { warn "Não é permitido criar pastas nesse diretório protegido."; return 1; }
    mkdir -- "$destino" || { warn "Falha ao criar pasta."; return 1; }
    ok "Pasta criada: $nome"
}

explorer_detalhes() {
    local src="$1" tamanho modificacao tipo permissao
    if [ -L "$src" ]; then tipo="Link simbólico"
    elif [ -d "$src" ]; then tipo="Pasta"
    elif [ -f "$src" ]; then tipo="Arquivo"
    else tipo="Outro tipo de item"; fi
    tamanho="$(du -sh -- "$src" 2>/dev/null | cut -f1 || true)"
    modificacao="$(date -r "$src" '+%d/%m/%Y %H:%M' 2>/dev/null || printf 'indisponível')"
    permissao="$(stat -c '%A' -- "$src" 2>/dev/null || printf 'indisponível')"
    cabecalho_tela "ℹ️ Detalhes" "$(explorer_nome_exibicao "$src")"
    caixa_simples_wrap "Informações" "Caminho: $(caminho_home_relativo "$src")" \
        "Tipo: $tipo" "Tamanho aproximado: ${tamanho:-indisponível}" \
        "Modificado: $modificacao" "Permissões: $permissao"
    pause
}

explorer_visualizar() {
    local src="$1" linha=0 conteudo="" l
    [ -f "$src" ] && [ -r "$src" ] || { warn "Arquivo não pode ser lido."; pause; return 1; }
    # Nunca exibe conteúdo de binários nem executa o arquivo.
    if ! LC_ALL=C grep -Iq . -- "$src" 2>/dev/null; then
        warn "Prévia indisponível para arquivo vazio ou binário."
        pause; return 1
    fi
    cabecalho_tela "📄 Visualizar arquivo" "$(explorer_nome_exibicao "$src")"
    echo "Primeiras 25 linhas (somente leitura):"
    while IFS= read -r l && [ "$linha" -lt 25 ]; do
        printf '%s\n' "${l:0:180}"
        linha=$((linha + 1))
    done < "$src"
    ui_buffer_flush
    pause
}

explorer_menu_item() {
    local src="$1" tipo="Arquivo" opcao novo
    explorer_existe "$src" || { warn "O item não existe mais."; pause; return 1; }
    if [ -d "$src" ]; then tipo="Pasta"; fi
    while explorer_existe "$src"; do
        if [ -d "$src" ]; then
            menu_unificado "📂 $tipo" "$(explorer_nome_exibicao "$src")" \
                "[0] Voltar  •  [1–6] Ação" \
                "1|📂|Abrir pasta|Navegar pelos arquivos" \
                "2|ℹ|Detalhes|Caminho, tamanho e data" \
                "3|📋|Copiar|Selecionar para colar em outra pasta" \
                "4|📦|Mover|Selecionar para mover a outra pasta" \
                "5|📝|Renomear|Alterar o nome desta pasta" \
                "6|🗑|Excluir|Remover a pasta e seu conteúdo"
        else
            menu_unificado "📄 $tipo" "$(explorer_nome_exibicao "$src")" \
                "[0] Voltar  •  [1–6] Ação" \
                "1|📖|Visualizar|Primeiras linhas, somente texto" \
                "2|ℹ|Detalhes|Caminho, tamanho e data" \
                "3|📋|Copiar|Selecionar para colar em outra pasta" \
                "4|📦|Mover|Selecionar para mover a outra pasta" \
                "5|📝|Renomear|Alterar o nome deste arquivo" \
                "6|🗑|Excluir|Remoção definitiva com confirmação"
        fi
        ler_opcao
        opcao="$RESPOSTA_MENU"
        case "$opcao" in
            1)
                if [ -d "$src" ]; then
                    novo="$(explorer_canonico "$src" 2>/dev/null)" || novo=""
                    if [ -n "$novo" ]; then EXPLORER_DIR="$novo"; EXPLORER_PAGE=0; return 0; fi
                    warn "Pasta inacessível."; pause
                else explorer_visualizar "$src"; fi ;;
            2) explorer_detalhes "$src" ;;
            3|4)
                if [ "$opcao" = 3 ]; then EXPLORER_CLIP_MODE="copiar"; else
                    if explorer_protegido "$src"; then warn "Item protegido: não é possível mover."; pause; continue; fi
                    EXPLORER_CLIP_MODE="mover"
                fi
                EXPLORER_CLIP_PATH="$src"
                ok "Selecionado para $EXPLORER_CLIP_MODE. Navegue até o destino e use [C] Colar."
                pause; return 0 ;;
            5)
                ui_preparar_prompt
                printf 'Novo nome (deixe vazio para cancelar): '
                IFS= read -r novo
                if [ -n "$novo" ]; then
                    if explorer_operar_renomear "$src" "$novo"; then pause; return 0; fi
                    pause
                fi ;;
            6)
                if explorer_excluir "$src"; then pause; return 0; fi
                pause ;;
            0) return 0 ;;
            *) warn "Opção inválida."; pause ;;
        esac
    done
}

explorer_listar() {
    local item
    EXPLORER_ITEMS=()
    local -a pastas=() arquivos=()
    while IFS= read -r -d '' item; do
        if [ -d "$item" ]; then pastas+=("$item"); else arquivos+=("$item"); fi
    done < <(find "$EXPLORER_DIR" -mindepth 1 -maxdepth 1 -print0 2>/dev/null | sort -z)
    EXPLORER_ITEMS=("${pastas[@]}" "${arquivos[@]}")
}

menu_explorer() {
    EXPLORER_DIR="$(explorer_canonico "${EXPLORER_DIR:-$HOME}" 2>/dev/null)" || EXPLORER_DIR="$HOME"
    EXPLORER_PAGE=0
    local total inicio fim i pagina_max n item descricao icone resposta destino titulo rodape clip
    local -a menu_itens=()
    while true; do
        if [ ! -d "$EXPLORER_DIR" ] || [ ! -r "$EXPLORER_DIR" ]; then
            EXPLORER_DIR="$(explorer_canonico "$HOME")" || return 1
            EXPLORER_PAGE=0
        fi
        explorer_listar
        total=${#EXPLORER_ITEMS[@]}
        pagina_max=$(((total + EXPLORER_PAGE_SIZE - 1) / EXPLORER_PAGE_SIZE))
        [ "$pagina_max" -lt 1 ] && pagina_max=1
        [ "$EXPLORER_PAGE" -ge "$pagina_max" ] && EXPLORER_PAGE=$((pagina_max - 1))
        inicio=$((EXPLORER_PAGE * EXPLORER_PAGE_SIZE))
        fim=$((inicio + EXPLORER_PAGE_SIZE))
        [ "$fim" -gt "$total" ] && fim=$total
        menu_itens=()
        for ((i=inicio; i<fim; i++)); do
            item="${EXPLORER_ITEMS[$i]}"; n=$((i - inicio + 1))
            if [ -L "$item" ]; then icone="🔗"; descricao="Link simbólico"
            elif [ -d "$item" ]; then icone="📁"; descricao="Pasta"
            else icone="📄"; descricao="Arquivo"; fi
            menu_itens+=("$n|$icone|$(explorer_nome_exibicao "$item")|$descricao")
        done
        [ "$total" -eq 0 ] && menu_itens+=("—|📭|Pasta vazia|Use [M] para criar uma pasta")
        clip="Sem item selecionado"
        if [ -n "$EXPLORER_CLIP_PATH" ]; then clip="${EXPLORER_CLIP_MODE}: $(explorer_nome_exibicao "$EXPLORER_CLIP_PATH")"; fi
        titulo="$(caminho_home_relativo "$EXPLORER_DIR")"
        rodape="[0] Voltar • [U] Subir • [N/A] Pág. • [?] Atalhos"
        menu_unificado "📂 EXPLORER • $((EXPLORER_PAGE + 1))/$pagina_max" "$titulo" "$rodape" "${menu_itens[@]}"
        echo "Arquivos: $total • $clip"
        echo "[C] Colar   [M] Nova pasta   [X] Limpar seleção"
        ler_opcao
        resposta="${RESPOSTA_MENU,,}"
        case "$resposta" in
            0) return 0 ;;
            u)
                destino="$(dirname -- "$EXPLORER_DIR")"
                EXPLORER_DIR="$(explorer_canonico "$destino" 2>/dev/null || printf '%s' "$EXPLORER_DIR")"
                EXPLORER_PAGE=0 ;;
            n) if [ "$EXPLORER_PAGE" -lt $((pagina_max - 1)) ]; then EXPLORER_PAGE=$((EXPLORER_PAGE + 1)); fi ;;
            a) if [ "$EXPLORER_PAGE" -gt 0 ]; then EXPLORER_PAGE=$((EXPLORER_PAGE - 1)); fi ;;
            '?'|h|d|p|r|s)
                if [ "$resposta" = '?' ]; then
                    menu_unificado "🧭 Ir para" "Atalhos do Explorer" "[0] Cancelar" \
                        "1|🏠|Home|Pasta pessoal do Termux" \
                        "2|📁|Painel|Projetos do Manager" \
                        "3|📥|Downloads|Arquivos recebidos no Android" \
                        "4|📱|Armazenamento|Memória compartilhada /sdcard" \
                        "5|🗂|Raiz do sistema|Diretórios acessíveis a você"
                    ler_opcao
                    case "$RESPOSTA_MENU" in
                        1) resposta=h ;; 2) resposta=p ;; 3) resposta=d ;; 4) resposta=s ;; 5) resposta=r ;; *) continue ;; esac
                fi
                case "$resposta" in
                    h) destino="$HOME" ;; p) destino="${PAINEL_DIR:-$HOME/Painel}" ;;
                    d) destino="${DOWNLOADS_DIR:-$HOME/storage/downloads}" ;;
                    r) destino="/" ;; s) destino="/sdcard" ;;
                esac
                if [ -d "$destino" ] && [ -r "$destino" ]; then
                    EXPLORER_DIR="$(explorer_canonico "$destino")"; EXPLORER_PAGE=0
                else warn "Diretório inacessível. Configure a permissão de armazenamento do Android."; pause; fi ;;
            c)
                explorer_colar || true
                pause ;;
            x) EXPLORER_CLIP_PATH=""; EXPLORER_CLIP_MODE="" ;;
            m)
                ui_preparar_prompt
                printf 'Nome da nova pasta (vazio cancela): '
                IFS= read -r destino
                if [ -n "$destino" ]; then explorer_nova_pasta "$destino" || true; pause; fi ;;
            *)
                if [[ "$resposta" =~ ^[0-9]+$ ]] && [ "$resposta" -ge 1 ] && [ "$resposta" -le $((fim - inicio)) ]; then
                    explorer_menu_item "${EXPLORER_ITEMS[$((inicio + resposta - 1))]}" || true
                else warn "Opção inválida."; pause; fi ;;
        esac
    done
}

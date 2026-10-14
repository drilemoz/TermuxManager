# Catálogo, busca e manutenção de pacotes de distribuições Linux via PRoot.
# Entradas de pacotes nunca são avaliadas como shell: aceitar identificadores estritos.
linux_pacote_nome_valido() {
    [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$ ]]
}
linux_pacotes_ler_nome() {
    local entrada
    printf 'Nome do pacote (sem espaços): '
    read -r entrada || return 1
    linux_pacote_nome_valido "$entrada" || { warn 'Nome de pacote inválido. Use apenas letras, números, + . _ e -'; pause; return 2; }
    LINUX_PACOTE_NOME="$entrada"
}
linux_pacotes_comando() {
    local pm="$1" acao="$2" pacote="$3"
    linux_pacote_nome_valido "$pacote" || return 2
    case "$pm:$acao" in
        apt:buscar) printf 'apt-cache search -- %s\n' "$pacote" ;;
        apt:detalhes) printf 'apt-cache show %s\n' "$pacote" ;;
        apt:simular) printf 'apt-get -s install %s\n' "$pacote" ;;
        apt:instalar) printf 'export DEBIAN_FRONTEND=noninteractive; apt-get install -y %s\n' "$pacote" ;;
        apt:remover) printf 'export DEBIAN_FRONTEND=noninteractive; apt-get remove -y %s\n' "$pacote" ;;
        pacman:buscar) printf 'pacman -Ss %s\n' "$pacote" ;;
        pacman:detalhes) printf 'pacman -Si %s\n' "$pacote" ;;
        pacman:simular) printf 'pacman -Si %s\n' "$pacote" ;;
        pacman:instalar) printf 'pacman -S --needed --noconfirm %s\n' "$pacote" ;;
        pacman:remover) printf 'pacman -R --noconfirm %s\n' "$pacote" ;;
        apk:buscar) printf 'apk search %s\n' "$pacote" ;;
        apk:detalhes) printf 'apk info -a %s\n' "$pacote" ;;
        apk:simular) printf 'apk info -a %s\n' "$pacote" ;;
        apk:instalar) printf 'apk add %s\n' "$pacote" ;;
        apk:remover) printf 'apk del %s\n' "$pacote" ;;
        dnf:buscar) printf 'dnf search %s\n' "$pacote" ;;
        dnf:detalhes) printf 'dnf info %s\n' "$pacote" ;;
        dnf:simular) printf 'dnf info %s\n' "$pacote" ;;
        dnf:instalar) printf 'dnf install -y %s\n' "$pacote" ;;
        dnf:remover) printf 'dnf remove -y %s\n' "$pacote" ;;
        zypper:buscar) printf 'zypper search %s\n' "$pacote" ;;
        zypper:detalhes) printf 'zypper info %s\n' "$pacote" ;;
        zypper:simular) printf 'zypper info %s\n' "$pacote" ;;
        zypper:instalar) printf 'zypper --non-interactive install %s\n' "$pacote" ;;
        zypper:remover) printf 'zypper --non-interactive remove %s\n' "$pacote" ;;
        *) return 3 ;;
    esac
}
linux_pacotes_previa() {
    local alias="$1" pm="$2" pacote="$3" comando rc=0
    comando="$(linux_pacotes_comando "$pm" simular "$pacote")" || return 1
    cabecalho_tela '📦 Prévia de instalação' "$alias • $pacote"
    caixa_simples_wrap 'Antes da instalação' \
        'O APT calcula as dependências; outros gerenciadores mostram dados do pacote, não uma simulação completa.' \
        'Verifique espaço livre e custos de download quando informados.'
    ui_buffer_flush 2>/dev/null || true
    proot-distro login "$alias" -- /bin/sh -lc "$comando" 2>&1 | head -n 70 || rc=${PIPESTATUS[0]}
    [ "$rc" -eq 0 ] || warn 'Não foi possível consultar os detalhes desse pacote.'
    return 0
}
linux_pacotes_operacao() {
    local alias="$1" acao="$2" pacote="$3" pm cmd
    linux_pacote_nome_valido "$pacote" || { error 'Pacote rejeitado por validação.'; return 2; }
    pm="$(linux_admin_gerenciador "$alias")"
    case "$acao" in
       buscar|detalhes|simular|instalar|remover) ;;
       *) return 2;;
    esac
    cmd="$(linux_pacotes_comando "$pm" "$acao" "$pacote")" || { warn 'Gerenciador não suportado.'; pause; return 3; }
    if [ "$acao" = instalar ]; then
        linux_pacotes_previa "$alias" "$pm" "$pacote" || true
        printf '\n'
    fi
    linux_admin_exec "$alias" "$acao pacote $pacote" "$cmd"
}
# Catálogo de distribuições: não usar o catálogo nativo do Termux.
# Carregado também quando este módulo é testado isoladamente.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/linux_catalog_data.sh"

linux_pacotes_catalogo_pacotes() {
    # Compatibilidade com verificações legadas (v1.0.120).
    linux_catalog_listar "$1" | cut -d'|' -f1 | paste -sd' ' -
}

linux_catalog_modo_texto() {
    case "$1" in G) printf 'Requer desktop/X11';; T) printf 'Terminal (sem X11)';; esac
}
linux_catalog_consumo_texto() {
    case "$1" in L) printf 'leve';; M) printf 'médio';; H) printf 'pesado';; esac
}

# O status é consultado no repositório da distro, não em uma lista presumida.
# stdout: instalado|disponivel|ausente|desconhecido. Consulta sob demanda:
# cada pacote verificado requer iniciar uma sessão PRoot, não executar em lote
# os 160 candidatos toda vez que o usuário abre o catálogo.
linux_catalog_status_pacote() {
    local distro="$1" pm="$2" pacote="$3" cmd saida rc=0
    linux_pacote_nome_valido "$pacote" || return 2
    linux_admin_alias_valido "$distro" || return 2
    case "$pm" in
        apt)
            cmd="if dpkg-query -W -f='\${Status}' '$pacote' 2>/dev/null | grep -qx 'install ok installed'; then echo instalado; elif apt-cache policy '$pacote' 2>/dev/null | awk '/^[[:space:]]*Candidate:/ { if (\$2 != \"(none)\") found=1 } END { exit !found }'; then echo disponivel; else echo ausente; fi"
            ;;
        pacman)
            cmd="if pacman -Q '$pacote' >/dev/null 2>&1; then echo instalado; elif pacman -Si '$pacote' >/dev/null 2>&1; then echo disponivel; else echo ausente; fi" ;;
        apk)
            cmd="if apk info -e '$pacote' 2>/dev/null | grep -qx '$pacote'; then echo instalado; elif apk search -x '$pacote' 2>/dev/null | grep -q .; then echo disponivel; else echo ausente; fi" ;;
        dnf)
            cmd="if rpm -q '$pacote' >/dev/null 2>&1; then echo instalado; elif dnf -q info '$pacote' >/dev/null 2>&1; then echo disponivel; else echo ausente; fi" ;;
        zypper)
            cmd="if rpm -q '$pacote' >/dev/null 2>&1; then echo instalado; elif zypper --non-interactive info '$pacote' 2>/dev/null | grep -qi 'Information for package'; then echo disponivel; else echo ausente; fi" ;;
        *) printf 'desconhecido\n'; return 0 ;;
    esac
    saida="$(proot-distro login "$distro" -- /bin/sh -lc "$cmd" 2>/dev/null)" || rc=$?
    if [ "$rc" -ne 0 ]; then printf 'desconhecido\n'; return 0; fi
    saida="${saida##*$'\n'}"
    case "$saida" in instalado|disponivel|ausente) printf '%s\n' "$saida" ;; *) printf 'desconhecido\n' ;; esac
}

linux_catalog_detalhes() {
    local distro="$1" pacote="$2" nome="$3" modo="$4" custo="$5" nota="$6"
    local pm status escolha mode_text cost_text
    pm="$(linux_admin_gerenciador "$distro")"
    cabecalho_tela '🔎 Consultando repositório' "$distro • $pacote"
    ui_buffer_flush 2>/dev/null || true
    status="$(linux_catalog_status_pacote "$distro" "$pm" "$pacote")"
    mode_text="$(linux_catalog_modo_texto "$modo")"
    cost_text="$(linux_catalog_consumo_texto "$custo")"
    while true; do
        menu_unificado "📦 $nome" "$distro • pacote: $pacote" '[0] Voltar • [1–2] Selecionar' \
            "1|⬇️|Instalar|Estado no repositório: $status" \
            "2|ℹ️|Ver informações|Versão, descrição e dependências"
        caixa_simples_wrap 'Compatibilidade e recursos' \
            "Modo: $mode_text • Custo relativo: $cost_text" \
            "$nota" \
            "Situação: $status (consulta feita nesta distribuição)" \
            'O consumo depende das dependências, aparelho e sistema gráfico.'
        ler_opcao; escolha="$RESPOSTA_MENU"
        case "$escolha" in
            1)
                if [ "$status" = instalado ]; then
                    warn 'O pacote já consta como instalado.'; pause; return 0
                elif [ "$status" = ausente ]; then
                    warn 'Este nome não tem candidato disponível no repositório atual.'
                    warn 'Tente atualizar a lista de pacotes ou pesquisar um equivalente.'
                    pause; return 0
                elif [ "$status" = desconhecido ]; then
                    warn 'Não foi possível confirmar disponibilidade. A instalação pelo catálogo foi bloqueada.'
                    warn 'Consulte as configurações de rede e repositórios Linux.'
                    pause; return 1
                fi
                if [ "$modo" = G ]; then
                    caixa_simples_wrap 'Precisa de X11' \
                        'Instalar o pacote não inicia o aplicativo Android Termux:X11.' \
                        'O desktop deve funcionar antes de abrir este programa gráfico.'
                fi
                [ "$custo" = H ] && warn 'Aplicativo potencialmente pesado: confira espaço e memória na prévia.'
                linux_pacotes_operacao "$distro" instalar "$pacote"
                return $?
                ;;
            2) linux_pacotes_operacao "$distro" detalhes "$pacote" || true ;;
            0) return 0 ;;
            *) feedback_curto 'Opção inválida.' ;;
        esac
    done
}

# Uma página curta por vez: o teclado ocupa boa parte do display Android.
linux_pacotes_catalogo() {
    local distro="$1" pm page=0 escolha atual categoria etiqueta icon desc ctotal
    local -a linhas=() opcoes=() campos=()
    local pagina=0 indice inicio fim total modo custo pacote nome nota
    pm="$(linux_admin_gerenciador "$distro")"
    while true; do
        mapfile -t linhas < <(linux_catalog_categorias)
        total=${#linhas[@]}; inicio=$((page * 7)); fim=$((inicio + 7))
        [ "$fim" -gt "$total" ] && fim=$total
        opcoes=()
        for ((indice=inicio;indice<fim;indice++)); do
            IFS='|' read -r categoria icon etiqueta desc <<< "${linhas[indice]}"
            opcoes+=("$((indice-inicio+1))|$icon|$etiqueta|$desc")
        done
        [ "$fim" -lt "$total" ] && opcoes+=('8|➡️|Próxima página|Mais categorias')
        [ "$page" -gt 0 ] && opcoes+=('9|⬅️|Página anterior|Voltar às categorias anteriores')
        menu_unificado '📚 Programas Linux' "$distro • $pm • categorias $((page+1))/$(((total+6)/7))" \
            '[0] Voltar • [1–7] Abrir • [8/9] Páginas' "${opcoes[@]}"
        ler_opcao; escolha="$RESPOSTA_MENU"
        case "$escolha" in
            0) return 0 ;;
            8) if [ "$fim" -lt "$total" ]; then page=$((page+1)); fi; continue ;;
            9) if [ "$page" -gt 0 ]; then page=$((page-1)); fi; continue ;;
        esac
        if [[ "$escolha" =~ ^[1-7]$ ]] && [ "$((inicio+escolha-1))" -lt "$fim" ]; then
            IFS='|' read -r categoria icon etiqueta desc <<< "${linhas[$((inicio+escolha-1))]}"
            linux_catalog_pagina_pacotes "$distro" "$categoria" "$etiqueta" || true
        else feedback_curto 'Opção inválida.'; fi
    done
}

linux_catalog_pagina_pacotes() {
    local distro="$1" categoria="$2" titulo="$3" page=0 escolha total inicio fim indice pacote nome modo custo nota
    local -a linhas=() opcoes=()
    mapfile -t linhas < <(linux_catalog_listar "$categoria") || return 1
    total=${#linhas[@]}
    while true; do
        inicio=$((page*7)); fim=$((inicio+7))
        [ "$fim" -gt "$total" ] && fim=$total
        opcoes=()
        for ((indice=inicio;indice<fim;indice++)); do
            IFS='|' read -r pacote nome modo custo nota <<< "${linhas[indice]}"
            if [ "$modo" = G ]; then
                opcoes+=("$((indice-inicio+1))|🖥️|$nome|$pacote • X11 • $(linux_catalog_consumo_texto "$custo")")
            else
                opcoes+=("$((indice-inicio+1))|⌨️|$nome|$pacote • terminal • $(linux_catalog_consumo_texto "$custo")")
            fi
        done
        [ "$fim" -lt "$total" ] && opcoes+=('8|➡️|Próxima página|Mais programas')
        [ "$page" -gt 0 ] && opcoes+=('9|⬅️|Página anterior|Ver programas anteriores')
        menu_unificado "📦 $titulo" "$distro • $total opções • página $((page+1))/$(((total+6)/7))" \
            '[0] Categorias • [1–7] Detalhar • [8/9] Páginas' "${opcoes[@]}"
        ler_opcao; escolha="$RESPOSTA_MENU"
        case "$escolha" in
            0) return 0 ;;
            8) if [ "$fim" -lt "$total" ]; then page=$((page+1)); fi; continue ;;
            9) if [ "$page" -gt 0 ]; then page=$((page-1)); fi; continue ;;
        esac
        if [[ "$escolha" =~ ^[1-7]$ ]] && [ "$((inicio+escolha-1))" -lt "$fim" ]; then
            IFS='|' read -r pacote nome modo custo nota <<< "${linhas[$((inicio+escolha-1))]}"
            linux_catalog_detalhes "$distro" "$pacote" "$nome" "$modo" "$custo" "$nota" || true
        else feedback_curto 'Opção inválida.'; fi
    done
}

linux_pacotes_listar_instalados() {
    local alias="$1" pm cmd
    pm="$(linux_admin_gerenciador "$alias")"
    case "$pm" in
       apt) cmd="dpkg-query -W -f='\${Package} \${Version}\\n' | head -n 100";;
       pacman) cmd='pacman -Q | head -n 100';;
       apk) cmd='apk info -v | head -n 100';;
       dnf) cmd='dnf list installed | head -n 100';;
       zypper) cmd='zypper search -i | head -n 100';;
       *) warn 'Gerenciador não reconhecido.'; pause; return 1;;
    esac
    linux_admin_exec "$alias" 'Listar instalados (100 primeiros)' "$cmd"
}
linux_menu_pacotes_distro() {
    local alias="$1" escolha pacote
    while true; do
        menu_unificado '📦 Programas e pacotes' "$alias • comandos executados pelo PRoot" '[0] Voltar • [1–7] Selecionar' \
            '1|📚|Catálogo Linux ampliado|Gráficos X11 e terminal; verificar repositório' \
            '2|🔎|Pesquisar pacote|Consultar repositório da distribuição' \
            '3|ℹ️|Informações de pacote|Versão e dependências, quando disponíveis' \
            '4|⬇️|Instalar pacote por nome|Simulação no APT e confirmação' \
            '5|🗑️|Remover pacote|Confirmação antes da operação' \
            '6|📋|Listar instalados|Até 100 pacotes' \
            '7|🔄|Atualizar sistema|Repositórios e pacotes'
        ler_opcao; escolha="$RESPOSTA_MENU"
        case "$escolha" in
           1) linux_pacotes_catalogo "$alias" || true ;;
           2|3|4|5)
              linux_pacotes_ler_nome || continue
              pacote="$LINUX_PACOTE_NOME"
              case "$escolha" in
                 2) linux_pacotes_operacao "$alias" buscar "$pacote" || true ;;
                 3) linux_pacotes_operacao "$alias" detalhes "$pacote" || true ;;
                 4) linux_pacotes_operacao "$alias" instalar "$pacote" || true ;;
                 5) linux_pacotes_operacao "$alias" remover "$pacote" || true ;;
              esac ;;
           6) linux_pacotes_listar_instalados "$alias" || true ;;
           7) linux_atualizar_distro "$alias" || true ;;
           0) return 0;; *) feedback_curto 'Opção inválida.';;
        esac
    done
}

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
linux_pacotes_catalogo_pacotes() {
    # Identificadores do catálogo são candidatos; a disponibilidade real é consultada na distro.
    case "$1" in
      dev) printf '%s\n' 'git python3 nodejs gcc make' ;;
      editors) printf '%s\n' 'nano vim micro' ;;
      rede) printf '%s\n' 'curl wget openssh' ;;
      monitor) printf '%s\n' 'htop btop procps' ;;
      arquivos) printf '%s\n' 'zip unzip tar rsync' ;;
      sessoes) printf '%s\n' 'tmux screen' ;;
      utils) printf '%s\n' 'jq tree less' ;;
      web) printf '%s\n' 'python3 nginx' ;;
      *) return 1 ;;
    esac
}
linux_pacotes_catalogo() {
    local alias="$1" escolha categoria nomes i pacote
    local -a itens=() pacotes=()
    menu_unificado '📚 Catálogo Linux' 'Escolha uma categoria' '[0] Voltar' \
        '1|👨‍💻|Desenvolvimento|Git, Python, Node.js, compiladores' \
        '2|✍️|Editores|Nano, Vim, Micro' \
        '3|🌐|Rede|Curl, Wget, OpenSSH' \
        '4|📊|Monitoramento|Htop, Btop, Procps' \
        '5|📁|Arquivos|Zip, Unzip, Tar, Rsync' \
        '6|⌨️|Sessões|Tmux, Screen' \
        '7|🧰|Utilitários|JQ, Tree, Less' \
        '8|🌍|Web|Python, Nginx'
    ler_opcao; escolha="$RESPOSTA_MENU"
    case "$escolha" in
        1) categoria=dev;;2) categoria=editors;;3) categoria=rede;;4) categoria=monitor;;
        5) categoria=arquivos;;6) categoria=sessoes;;7) categoria=utils;;8) categoria=web;;
        0) return 0;;*) return 1;;
    esac
    nomes="$(linux_pacotes_catalogo_pacotes "$categoria")" || return 1
    read -r -a pacotes <<< "$nomes"
    for ((i=0;i<${#pacotes[@]};i++)); do
        itens+=("$((i+1))|📦|${pacotes[$i]}|Ver disponibilidade e instalar")
    done
    menu_unificado '📦 Pacotes Linux' "$alias • nomes podem variar por distribuição" "[0] Voltar • [1–${#itens[@]}] Pacote" "${itens[@]}"
    ler_opcao; escolha="$RESPOSTA_MENU"
    if [[ "$escolha" =~ ^[0-9]+$ ]] && [ "$escolha" -ge 1 ] && [ "$escolha" -le "${#pacotes[@]}" ]; then
        pacote="${pacotes[$((escolha - 1))]}"
        linux_pacotes_operacao "$alias" instalar "$pacote" || true
    fi
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
            '1|📚|Catálogo por categoria|Instalar aplicativos de terminal' \
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

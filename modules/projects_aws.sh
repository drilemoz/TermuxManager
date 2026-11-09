# Módulo: projects_aws.sh — atualização do AL Sistemas na AWS EC2 por SSH.
# Não instala no Termux: envia o ZIP escolhido ao servidor configurado,
# valida, cria backup privado e usa o instalador de atualização do AL Sistemas.

AWS_CONFIG_FILE="$HOME/.config/termux-manager/alsistemas-aws.conf"
AWS_HOST="" AWS_USER="ubuntu" AWS_PORT="22" AWS_KEY="$HOME/.ssh/iguatamaonline.pem"
AWS_ZIP="" AWS_PACKAGE_VERSION="" AWS_PACKAGE_SHA=""

aws_carregar_config() {
    AWS_HOST="18.217.192.20"  # Último IP conhecido; o usuário deve conferir no console EC2.
    AWS_USER="ubuntu"
    AWS_PORT="22"
    AWS_KEY="$HOME/.ssh/iguatamaonline.pem"
    [ -f "$AWS_CONFIG_FILE" ] && [ ! -L "$AWS_CONFIG_FILE" ] || return 0
    local key value
    while IFS='=' read -r key value || [ -n "${key:-}" ]; do
        case "$key" in
            host) AWS_HOST="$value" ;;
            user) AWS_USER="$value" ;;
            port) AWS_PORT="$value" ;;
            ssh_key) AWS_KEY="$value" ;;
        esac
    done < "$AWS_CONFIG_FILE"
}

aws_validar_config() {
    [[ "$AWS_HOST" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]{0,252}$ ]] || { error "Endereço AWS inválido."; return 1; }
    [[ "$AWS_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] || { error "Usuário SSH inválido."; return 1; }
    [[ "$AWS_PORT" =~ ^[0-9]{1,5}$ ]] && (( 10#$AWS_PORT >= 1 && 10#$AWS_PORT <= 65535 )) || {
        error "Porta SSH inválida."; return 1;
    }
    # Impede usar chaves no armazenamento compartilhado do Android/Downloads.
    [[ "$AWS_KEY" == "$HOME/.ssh/"* && "$AWS_KEY" != *$'\n'* ]] || {
        error "A chave deve estar na pasta privada ~/.ssh/ do Termux."; return 1;
    }
    [ -f "$AWS_KEY" ] && [ ! -L "$AWS_KEY" ] || {
        error "Chave SSH não encontrada: $(caminho_home_relativo "$AWS_KEY")"; return 1;
    }
    local perms
    perms="$(stat -c %a "$AWS_KEY" 2>/dev/null)"
    [[ "$perms" =~ ^[0-7]{3,4}$ ]] && (( (8#$perms & 077) == 0 )) || {
        error "Permissões inseguras da chave SSH. Execute: chmod 600 ~/.ssh/$(basename "$AWS_KEY")"; return 1;
    }
    return 0
}

aws_salvar_config() {
    aws_validar_config || return 1
    local dir tmp
    dir="$(dirname "$AWS_CONFIG_FILE")"
    [ ! -L "$dir" ] || { error "Diretório de configuração é link simbólico."; return 1; }
    (umask 077; mkdir -p "$dir" && chmod 700 "$dir") || return 1
    [ ! -L "$AWS_CONFIG_FILE" ] || { error "Configuração é link simbólico; operação recusada."; return 1; }
    tmp="$(mktemp "$dir/.aws-conf-XXXXXX")" || return 1
    if ! printf 'host=%s\nuser=%s\nport=%s\nssh_key=%s\n' \
        "$AWS_HOST" "$AWS_USER" "$AWS_PORT" "$AWS_KEY" > "$tmp"; then
        rm -f "$tmp"; return 1
    fi
    chmod 600 "$tmp"
    mv -f -- "$tmp" "$AWS_CONFIG_FILE"
}

aws_configurar() {
    aws_carregar_config
    cabecalho_tela "☁️ Configurar AWS EC2" "Dados ficam privados no Termux; nenhuma senha é armazenada"
    info "IP registrado anteriormente: 18.217.192.20. Confirme o IP atual no console EC2."
    info "A chave privada precisa estar em ~/.ssh/ com permissão 600."
    local resposta
    printf 'Servidor/IP [%s]: ' "$AWS_HOST"
    IFS= read -r resposta || return 1
    [ -z "$resposta" ] || AWS_HOST="$resposta"
    printf 'Usuário SSH [%s]: ' "$AWS_USER"
    IFS= read -r resposta || return 1
    [ -z "$resposta" ] || AWS_USER="$resposta"
    printf 'Porta SSH [%s]: ' "$AWS_PORT"
    IFS= read -r resposta || return 1
    [ -z "$resposta" ] || AWS_PORT="$resposta"
    printf 'Chave SSH [%s]: ' "$(caminho_home_relativo "$AWS_KEY")"
    IFS= read -r resposta || return 1
    if [ -n "$resposta" ]; then
        case "$resposta" in
            '~/'*) AWS_KEY="$HOME/${resposta#\~/}" ;;
            /*) AWS_KEY="$resposta" ;;
            *) error "Informe o caminho absoluto ou ~/.ssh/nome.pem"; pause; return 1 ;;
        esac
    fi
    if aws_salvar_config; then
        ok "Conexão salva. Verifique o acesso SSH antes de atualizar."
        info "A identidade do servidor precisa estar registrada em ~/.ssh/known_hosts."
    else
        error "Configuração não salva. Nenhuma conexão foi iniciada."
    fi
    pause
}

aws_ssh() {
    local command_str="$1"
    ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=12 \
        -o ServerAliveInterval=10 -o ServerAliveCountMax=3 \
        -p "$AWS_PORT" -i "$AWS_KEY" \
        "$AWS_USER@$AWS_HOST" "$command_str"
}

aws_ssh_etapa() {
    local action="$1" operation="$2" digest="$3" version="$4"
    local remote_script="$BASE_DIR/tools/alsistemas-aws-remote.sh"
    [ -r "$remote_script" ] || { error "Script remoto do Manager ausente."; return 1; }
    aws_ssh "bash -s -- $action $operation $digest $version" < "$remote_script"
}

aws_testar_conexao() {
    aws_carregar_config
    cabecalho_tela "☁️ Testar conexão SSH" "Somente consulta; não altera arquivos da EC2"
    if ! aws_validar_config; then pause; return 1; fi
    info "Conectando a $AWS_USER@$AWS_HOST:$AWS_PORT (identidade do host obrigatória)..."
    if aws_ssh 'printf "SSH autenticado em: "; hostname; . /etc/os-release; printf "Sistema: %s %s\n" "$ID" "$VERSION_ID"; printf "Versão AL Sistemas: "; sed -nE "s/^const VERSION = '\''([0-9]+\.[0-9]+\.[0-9]+)'\''.*/\1/p" /opt/alsistemas-vps/current/src/server.js'; then
        ok "SSH autenticado."
    else
        error "Falha de SSH. Confira IP, porta, chave, Security Group e known_hosts."
        info "Na primeira conexão, use SSH manualmente para conferir a chave do host."
    fi
    pause
}

aws_escolher_zip() {
    local pasta="$HOME/storage/downloads" resposta f ultima inicio fim i indice total page=0
    local -a pastas=() arquivos=() itens=()
    [ -d "$pasta" ] || pasta="$HOME"
    while true; do
        pastas=(); arquivos=(); itens=()
        while IFS= read -r -d '' f; do
            if [ -d "$f" ] && [ ! -L "$f" ]; then pastas+=("$f")
            elif [ -f "$f" ] && [ ! -L "$f" ] && [[ "${f,,}" == *.zip ]]; then arquivos+=("$f")
            fi
        # No Termux, ~/storage/downloads e um link simbolico para Download do Android.
        # -H segue apenas a pasta inicial informada ao find; nao percorre links
        # simbolicos encontrados dentro dela (arquivos ZIP/link seguem bloqueados).
        done < <(find -H "$pasta" -mindepth 1 -maxdepth 1 -print0 2>/dev/null | sort -z)
        itens=("${pastas[@]}" "${arquivos[@]}")
        total=${#itens[@]}
        ultima=$((total > 0 ? (total - 1) / 10 : 0))
        ((page <= ultima)) || page=$ultima
        inicio=$((page * 10)); fim=$((inicio+10)); ((fim <= total)) || fim=$total
        cabecalho_tela "📦 ZIP do AL Sistemas" "Escolha o arquivo que será enviado para a EC2"
        caixa_simples "📂 Pasta atual" "$(caminho_curto "$pasta")"
        echo
        caixa_linha_topo
        for ((i=inicio; i<fim; i++)); do
            f="${itens[$i]}"
            if [ -d "$f" ]; then
                menu_opcao "$((i-inicio+1))" "📁" "$(wizard_nome_arquivo_visivel "$f")" "Abrir subpasta"
            else
                menu_opcao "$((i-inicio+1))" "📦" "$(wizard_nome_arquivo_visivel "$f")" "Arquivo ZIP"
            fi
        done
        ((total > 0)) || caixa_linha_texto "Nenhum ZIP aqui. Entre em outra pasta."
        caixa_linha_baixo
        rodape_atalhos "Página $((page+1))/$((ultima+1)) • [1-10] Selecionar • [+/-] Página"
        rodape_atalhos "[0] Subir • [D] Downloads • [H] Home • [X] Cancelar"
        ler_opcao
        resposta="${RESPOSTA_MENU^^}"
        case "$resposta" in
            X|Q) return 1 ;;
            0) [ "$pasta" = / ] && return 1; pasta="$(dirname -- "$pasta")"; page=0 ;;
            D) pasta="$HOME/storage/downloads"; [ -d "$pasta" ] || pasta="$HOME"; page=0 ;;
            H) pasta="$HOME"; page=0 ;;
            +) ((page < ultima)) && page=$((page+1)) || true ;;
            -) ((page > 0)) && page=$((page-1)) || true ;;
            *)
                if [[ "$resposta" =~ ^[0-9]+$ ]] && (( 10#$resposta >= 1 && 10#$resposta <= fim-inicio )); then
                    indice=$((inicio + 10#$resposta - 1))
                    f="${itens[$indice]}"
                    if [ -d "$f" ]; then pasta="$f"; page=0
                    else AWS_ZIP="$f"; return 0
                    fi
                else
                    warn "Escolha inválida."; pause
                fi
                ;;
        esac
    done
}

aws_validar_pacote() {
    local zip="$1" n tamanho ver nomes
    [ -f "$zip" ] && [ ! -L "$zip" ] && [[ "${zip,,}" == *.zip ]] || {
        error "Selecione um arquivo ZIP regular."; return 1;
    }
    command -v unzip >/dev/null && command -v sha256sum >/dev/null && command -v scp >/dev/null || {
        error "Instale openssh e unzip no Termux: pkg install openssh unzip"; return 1;
    }
    tamanho="$(stat -c %s "$zip" 2>/dev/null)"
    [[ "$tamanho" =~ ^[0-9]+$ ]] && (( tamanho >= 512 && tamanho <= 134217728 )) || {
        error "ZIP fora do limite seguro de 512 B a 128 MiB."; return 1;
    }
    unzip -tq "$zip" >/dev/null 2>&1 || { error "ZIP corrompido."; return 1; }
    nomes="$(unzip -Z1 "$zip" 2>/dev/null)" || return 1
    for n in VERSION instalar.sh SHA256SUMS.txt vps/src/server.js vps/admin/updater.py; do
        grep -Fxq "$n" <<< "$nomes" || { error "Pacote não é AL Sistemas VPS: falta $n"; return 1; }
    done
    ver="$(unzip -p "$zip" VERSION 2>/dev/null | tr -d '\r\n')"
    [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { error "VERSION inválida no ZIP."; return 1; }
    AWS_PACKAGE_VERSION="$ver"
    AWS_PACKAGE_SHA="$(sha256sum "$zip" | awk '{print $1}')"
    [[ "$AWS_PACKAGE_SHA" =~ ^[a-f0-9]{64}$ ]]
}

aws_atualizar_alsistemas() {
    aws_carregar_config
    if ! aws_validar_config; then
        info "Configure a conexão AWS antes de atualizar."
        pause
        return 1
    fi
    AWS_ZIP=""
    aws_escolher_zip || return 0
    cabecalho_tela "☁️ Preparar atualização" "Analisando o pacote local"
    if ! aws_validar_pacote "$AWS_ZIP"; then pause; return 1; fi
    caixa_simples "Revisão antes de instalar" \
        "Servidor: $AWS_USER@$AWS_HOST:$AWS_PORT" \
        "Arquivo: $(basename "$AWS_ZIP")" \
        "Versão pretendida: $AWS_PACKAGE_VERSION" \
        "SHA-256: $AWS_PACKAGE_SHA" \
        "Método: SSH/SCP + backup + core-upgrade" \
        "Projetos web e bancos: não selecionados para alteração"
    warn "SHA-256 detecta alteração, mas NÃO prova quem criou o ZIP. Use pacote confiável."
    warn "Recomendado: snapshot do volume EBS no console AWS antes de atualizar."
    if ! confirmar_acao "Conferiu o IP, o ZIP e o backup/snapshot? Continuar"; then return 0; fi
    local frase
    printf 'Para autorizar alterações na EC2, digite INSTALAR: '
    IFS= read -r frase || return 1
    [ "$frase" = INSTALAR ] || { info "Cancelado; servidor não alterado."; pause; return 0; }
    local runid upload_ok=false install_ok=false
    runid="tmals-$(date -u +%Y%m%dT%H%M%S)-$$"
    cabecalho_tela "☁️ Enviando e atualizando" "Conexão segura; não feche o Termux até terminar"
    info "[1/6] Preparando servidor remoto..."
    if ! aws_ssh_etapa prepare "$runid" "$AWS_PACKAGE_SHA" "$AWS_PACKAGE_VERSION"; then
        error "A preparação da EC2 falhou. Nenhuma atualização foi iniciada."
        info "Se o SSH é novo, confirme a identidade do host na primeira conexão manual."
        pause
        return 1
    fi
    info "[2/6] Enviando ZIP por SCP..."
    if scp -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=12 \
        -P "$AWS_PORT" -i "$AWS_KEY" -- "$AWS_ZIP" \
        "$AWS_USER@$AWS_HOST:.cache/termux-manager-aws/$runid/package.zip"; then
        upload_ok=true
    else
        error "Falha no envio do ZIP. A instalação não foi iniciada."
    fi
    if [ "$upload_ok" = true ]; then
        info "[3–6/6] Verificando integridade, plano, backup, instalação e saúde..."
        if aws_ssh_etapa install "$runid" "$AWS_PACKAGE_SHA" "$AWS_PACKAGE_VERSION"; then
            install_ok=true
        else
            error "A atualização não foi confirmada. Consulte o journalctl no servidor antes de tentar novamente."
            warn "Se o instalador chegou a executar, o backup foi salvo em /var/backups/alsistemas/manual/."
        fi
    fi
    # A limpeza não altera dados nem backups. Falha de SSH pode deixar temporários
    # no HOME do usuário remoto; não mascaramos o resultado da instalação.
    if ! aws_ssh_etapa cleanup "$runid" "$AWS_PACKAGE_SHA" "$AWS_PACKAGE_VERSION"; then
        warn "Não foi possível apagar os temporários da operação no servidor."
    fi
    if [ "$install_ok" = true ]; then
        ok "AL Sistemas v$AWS_PACKAGE_VERSION instalado e verificado via HTTP local da VPS."
        info "Abra https://painel.iguatama.online e atualize a página."
    else
        error "Instalação incompleta ou não confirmada; veja os logs da EC2."
    fi
    pause
    [ "$install_ok" = true ]
}

aws_diagnosticar() {
    aws_carregar_config
    cabecalho_tela "🔎 Diagnóstico AL Sistemas" "Somente leitura do status da EC2"
    if ! aws_validar_config; then pause; return 1; fi
    if ! aws_ssh 'sudo -n systemctl --no-pager status alsistemas-vps.service | head -n 24; printf "\n--- Últimos logs do painel ---\n"; sudo -n journalctl -u alsistemas-vps.service -n 25 --no-pager; printf "\n--- Versão local ---\n"; python3 -c '\''import urllib.request; print(urllib.request.urlopen("http://127.0.0.1:8181/api/health", timeout=5).read().decode())'\'''; then
        warn "Diagnóstico incompleto: confira a conexão ou os serviços."
    fi
    pause
}

menu_aws_alsistemas() {
    local alvo
    while true; do
        aws_carregar_config
        alvo="$AWS_USER@$AWS_HOST:$AWS_PORT"
        menu_unificado "☁️ AL SISTEMAS NA AWS" "Servidor configurado: $alvo" \
            "[0] Voltar  •  [1–4] Selecionar" \
            "1|🔐|Configurar acesso SSH|IP, porta, usuário e caminho da chave" \
            "2|🔎|Testar conexão|Consulta a EC2, sem alterar arquivos" \
            "3|📦|Atualizar por ZIP|Selecionar pacote, enviar, backup e instalar" \
            "4|🩺|Diagnóstico remoto|Serviço, versão HTTP e últimos logs"
        ler_opcao
        case "$RESPOSTA_MENU" in
            1) aws_configurar ;;
            2) aws_testar_conexao ;;
            3) aws_atualizar_alsistemas || true ;;
            4) aws_diagnosticar ;;
            0) return ;;
            *) warn "Opção inválida."; pause ;;
        esac
    done
}

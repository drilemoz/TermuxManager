# Administração de distribuições PRoot exclusivamente via terminal.
# Toda entrada interpolada em comandos guest deve ser validada ou vir de menus fixos.
linux_admin_alias_valido() { [[ "$1" =~ ^[A-Za-z0-9_.-]{1,64}$ ]]; }
linux_admin_usuario_valido() { [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,30}$ ]]; }
linux_admin_exec() {
    local distro="$1" titulo="$2" comando="$3" rc=0
    linux_admin_alias_valido "$distro" || { error 'Nome de distribuição inválido.'; return 2; }
    linux_garantir_proot_distro || return 1
    cabecalho_tela "🐧 $titulo" "$distro"
    caixa_simples 'Operação na distribuição' 'O comando será executado dentro do Linux, via PRoot.' 'Nenhuma configuração global do Android será modificada.'
    confirmar_acao "Executar $titulo em '$distro'?" 'n' || return 0
    ui_buffer_flush 2>/dev/null || true
    linux_logs_nova_sessao "$distro" administracao || true
    linux_log "Linux: operação administrativa $titulo na distro $distro"
    proot-distro login "$distro" -- /bin/sh -lc "$comando" 2>&1 | tee -a "$LINUX_LOG" ${LINUX_LOGS_SESSAO_ATUAL:+"$LINUX_LOGS_SESSAO_ATUAL"} || rc=${PIPESTATUS[0]}
    linux_logs_encerrar_sessao "$rc"
    linux_invalidar_cache_distro "$distro" || true
    if [ "$rc" -eq 0 ]; then ok 'Comando concluído.'; else error "Operação falhou (código $rc). Consulte Logs."; fi
    pause
    return "$rc"
}
linux_admin_gerenciador() {
    local alias="$1"
    linux_detectar_gerenciador_distro "$alias" 2>/dev/null || printf 'desconhecido'
}
linux_admin_idioma() {
    local alias="$1" opcao lang base pkgs gerenciador cmd
    gerenciador="$(linux_admin_gerenciador "$alias")"
    menu_unificado '🌎 Idioma do Linux' "$alias • gerenciamento $gerenciador" '[0] Voltar' \
        '1|🇧🇷|Português (Brasil)|pt_BR.UTF-8' \
        '2|🇺🇸|Inglês (Estados Unidos)|en_US.UTF-8' \
        '3|🇪🇸|Espanhol (Espanha)|es_ES.UTF-8'
    ler_opcao; opcao="$RESPOSTA_MENU"
    case "$opcao" in 1) lang=pt_BR.UTF-8; base=pt_BR;; 2) lang=en_US.UTF-8; base=en_US;; 3) lang=es_ES.UTF-8; base=es_ES;; 0) return 0;; *) return 1;; esac
    case "$gerenciador" in
       apt)
          pkgs='locales'
          # language-pack-* é específico do Ubuntu; no Debian basta locales.
          if [ "$lang" = 'pt_BR.UTF-8' ]; then pkgs='locales'; fi
          cmd="export DEBIAN_FRONTEND=noninteractive; apt-get update && apt-get install -y $pkgs && { grep -q '^$lang UTF-8' /etc/locale.gen 2>/dev/null || printf '%s UTF-8\\n' '$lang' >> /etc/locale.gen; } && locale-gen '$lang' && update-locale LANG='$lang' && echo 'Reabra o terminal para aplicar a configuração.'"
          ;;
       *)
          cabecalho_tela '🌎 Idioma do Linux' "$alias"
          caixa_simples 'Configuração não automatizada' 'Este assistente configura locales automaticamente apenas em Debian/Ubuntu (APT).' 'A biblioteca C e os nomes de pacotes diferem entre distribuições.'
          pause; return 2 ;;
    esac
    linux_admin_exec "$alias" 'Alterar idioma' "$cmd"
}
linux_admin_fuso() {
    local alias="$1" escolha zona
    menu_unificado '🕓 Fuso horário' "$alias" '[0] Voltar' \
        '1|🕓|Brasília|America/Sao_Paulo' \
        '2|🕓|UTC|Etapa neutra internacional' \
        '3|🕓|Lisboa|Europe/Lisbon' \
        '4|🕓|Buenos Aires|America/Argentina/Buenos_Aires'
    ler_opcao; escolha="$RESPOSTA_MENU"
    case "$escolha" in 1) zona=America/Sao_Paulo;;2) zona=Etc/UTC;;3) zona=Europe/Lisbon;;4) zona=America/Argentina/Buenos_Aires;;0) return 0;;*) return 1;;esac
    linux_admin_exec "$alias" 'Configurar fuso horário' "[ -e '/usr/share/zoneinfo/$zona' ] || { echo 'Pacote tzdata ausente'; exit 1; }; ln -snf '/usr/share/zoneinfo/$zona' /etc/localtime && printf '%s\\n' '$zona' > /etc/timezone && date"
}
linux_admin_criar_usuario() {
    local alias="$1" usuario gerenciador cmd
    cabecalho_tela '👤 Criar usuário comum' "$alias"
    printf 'Usuário (letras minúsculas, números e _-): '; read -r usuario || return 1
    linux_admin_usuario_valido "$usuario" || { warn 'Nome inválido ou muito longo.'; pause; return 2; }
    [ "$usuario" != root ] || { warn 'Não é permitido recriar root.'; pause; return 2; }
    cmd="if id '$usuario' >/dev/null 2>&1; then echo 'Usuário já existe'; exit 2; fi; if command -v useradd >/dev/null 2>&1; then useradd -m -s /bin/sh '$usuario'; elif command -v adduser >/dev/null 2>&1; then adduser -D '$usuario'; else echo 'useradd/adduser não disponível'; exit 3; fi; id '$usuario'"
    linux_admin_exec "$alias" 'Criar usuário $usuario' "$cmd"
}
linux_admin_shell() {
    local alias="$1" escolha shell usuario
    menu_unificado '⌨️ Shell do usuário' "$alias • o shell escolhido já deve estar instalado" '[0] Voltar' \
        '1|⌨️|Bash|bash' '2|⌨️|Zsh|zsh' '3|⌨️|Fish|fish' '4|⌨️|POSIX sh|sh'
    ler_opcao; escolha="$RESPOSTA_MENU"
    case "$escolha" in 1) shell=bash;;2) shell=zsh;;3) shell=fish;;4) shell=sh;;0) return 0;;*) return 1;;esac
    printf 'Usuário da distro (ex.: root): '; read -r usuario || return 1
    linux_admin_usuario_valido "$usuario" || { warn 'Nome inválido.'; pause; return 2; }
    linux_admin_exec "$alias" 'Alterar shell' "id '$usuario' >/dev/null 2>&1 && command -v '$shell' >/dev/null 2>&1 && command -v usermod >/dev/null 2>&1 && usermod -s \"\$(command -v '$shell')\" '$usuario' && getent passwd '$usuario'"
}
linux_admin_rede() {
    local alias="$1"
    # Consulta DNS local; a rede pode estar offline e DNS depende do Android.
    linux_admin_exec "$alias" 'Diagnosticar rede' "printf 'DNS configurado:\\n'; cat /etc/resolv.conf 2>/dev/null || true; printf '\\nResolução DNS (example.com):\\n'; if command -v getent >/dev/null 2>&1; then getent hosts example.com || true; else echo 'getent indisponível'; fi; printf '\\nPortas locais (quando suportado):\\n'; if command -v ss >/dev/null 2>&1; then ss -ltn 2>&1 || true; else echo 'ss não instalado'; fi"
}
linux_admin_armazenamento() {
    local alias="$1" escolha pm cmd
    pm="$(linux_admin_gerenciador "$alias")"
    menu_unificado '💽 Armazenamento Linux' "$alias" '[0] Voltar' \
        '1|📊|Verificar espaço|Disco e cache de pacotes' \
        '2|🧹|Limpar cache de pacotes|Não remove arquivos pessoais'
    ler_opcao; escolha="$RESPOSTA_MENU"
    case "$escolha" in
      1) linux_admin_exec "$alias" 'Consultar armazenamento' "df -h /; printf '\\nCaches comuns:\\n'; du -sh /var/cache/apt /var/cache/pacman/pkg /var/cache/apk /var/cache/dnf 2>/dev/null || true" ;;
      2)
        case "$pm" in
          apt) cmd='apt-get clean';;pacman) cmd='pacman -Sc --noconfirm';;apk) cmd='rm -f /var/cache/apk/*.apk';;dnf) cmd='dnf clean all';;zypper) cmd='zypper clean -a';;
          *) warn 'Gerenciador de pacotes não suportado.'; pause; return 1;;
        esac
        linux_admin_exec "$alias" 'Limpar cache de pacotes' "$cmd" ;;
      0) return 0;; *) return 1;;
    esac
}
linux_admin_ssh() {
    local alias="$1" escolha pm cmd
    pm="$(linux_admin_gerenciador "$alias")"
    menu_unificado '🔐 SSH no Linux' 'Somente localhost:8022 • chaves SSH • sem expor rede' '[0] Voltar' \
        '1|⬇️|Instalar servidor SSH|Requer repositório da distro' \
        '2|🩺|Diagnóstico SSH|Binário, chaves e configuração' \
        '3|▶️|Executar servidor local|Foreground, sair com Ctrl+C'
    ler_opcao; escolha="$RESPOSTA_MENU"
    case "$escolha" in
      1) case "$pm" in apt) cmd='apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server';;apk) cmd='apk add openssh';;pacman) cmd='pacman -Sy --noconfirm openssh';;dnf) cmd='dnf install -y openssh-server';;zypper) cmd='zypper --non-interactive install openssh';;*) warn 'Distro não suportada.'; pause; return 2;; esac
         linux_admin_exec "$alias" 'Instalar SSH' "$cmd" ;;
      2) linux_admin_exec "$alias" 'Diagnosticar SSH' "command -v sshd || exit 1; sshd -t; printf 'Login por chave requer authorized_keys do usuário.'" ;;
      3) linux_admin_exec "$alias" 'Servidor SSH local' "[ -x /usr/sbin/sshd ] || { echo 'Instale o servidor SSH'; exit 1; }; mkdir -p /run/sshd; /usr/sbin/sshd -D -e -p 8022 -o ListenAddress=127.0.0.1 -o PasswordAuthentication=no -o PermitRootLogin=no -o PubkeyAuthentication=yes" ;;
      0) return 0;; *) return 1;;
    esac
}
linux_admin_servicos() {
    local alias="$1" escolha
    menu_unificado '🧰 Serviços sem systemd' "$alias • executados somente sob demanda" '[0] Voltar' \
        '1|🌐|Servidor HTTP local|Python, porta 8000, Ctrl+C para parar' \
        '2|🩺|Ver processos|ps sem alterar serviços'
    ler_opcao; escolha="$RESPOSTA_MENU"
    case "$escolha" in
       1) linux_admin_exec "$alias" 'Servidor HTTP local' "command -v python3 >/dev/null 2>&1 || { echo 'Instale python3'; exit 2; }; cd /tmp && python3 -m http.server 8000 --bind 127.0.0.1" ;;
       2) linux_admin_exec "$alias" 'Ver processos' 'ps -ef 2>&1 | head -n 50' ;;
       0) return 0;; *) return 1;;
    esac
}
linux_menu_configuracoes_distro() {
    local alias="$1" escolha
    while true; do
        menu_unificado '⚙️ Configurar Linux' "$alias • via terminal, sem interface gráfica" '[0] Voltar • [1–8] Selecionar' \
            '1|🌎|Idioma e região|Locale UTF-8 para Debian/Ubuntu' \
            '2|🕓|Fuso horário|tzdata da distribuição' \
            '3|👤|Criar usuário|Usuário comum na distribuição' \
            '4|⌨️|Shell padrão|Bash, Zsh, Fish ou sh' \
            '5|🌐|Rede e DNS|Diagnóstico read-only' \
            '6|💽|Armazenamento|Espaço e limpeza de cache' \
            '7|🔐|SSH|Instalar e iniciar somente localhost' \
            '8|🧰|Serviços simples|Servidor HTTP e processos'
        ler_opcao; escolha="$RESPOSTA_MENU"
        case "$escolha" in
            1) linux_admin_idioma "$alias" || true;; 2) linux_admin_fuso "$alias" || true;;
            3) linux_admin_criar_usuario "$alias" || true;; 4) linux_admin_shell "$alias" || true;;
            5) linux_admin_rede "$alias" || true;; 6) linux_admin_armazenamento "$alias" || true;;
            7) linux_admin_ssh "$alias" || true;; 8) linux_admin_servicos "$alias" || true;;
            0) return 0;; *) feedback_curto 'Opção inválida.';;
        esac
    done
}

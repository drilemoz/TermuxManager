# Módulo: termux_phpmyadmin.sh
# Administração LOCAL do MariaDB com phpMyAdmin oficial (sem exposição na LAN).
# Os arquivos PHP do projeto nunca são publicados pela porta administrativa.

PMA_VERSION="5.2.3"
PMA_URL="https://files.phpmyadmin.net/phpMyAdmin/${PMA_VERSION}/phpMyAdmin-${PMA_VERSION}-all-languages.zip"
PMA_SHA_URL="${PMA_URL}.sha256"
PMA_ROOT="${HOME}/.termux-manager/phpmyadmin"
PMA_SITE="${PMA_ROOT}/site"
PMA_PORT=8081
PMA_ADDRESS="127.0.0.1"

pma_url_local() { printf 'http://%s:%s/' "$PMA_ADDRESS" "$PMA_PORT"; }
pma_socket() { printf '%s/var/run/mysqld.sock' "${PREFIX:-/data/data/com.termux/files/usr}"; }
pma_db_data() { printf '%s/var/lib/mysql' "${PREFIX:-/data/data/com.termux/files/usr}"; }

pma_instalado() {
    [ -f "$PMA_SITE/index.php" ] && [ -f "$PMA_SITE/vendor/autoload.php" ] && [ -f "$PMA_SITE/config.inc.php" ]
}

pma_dependencias_php() {
    command -v php >/dev/null 2>&1 || return 1
    # phpMyAdmin 5.2.3 utiliza paragonie/sodium_compat quando a extensão
    # sodium nativa não está carregada. Não bloquear a instalação por isso.
    php -r 'foreach (["mysqli", "mbstring", "session", "json", "ctype", "filter", "iconv"] as $e) { if (!extension_loaded($e)) { fwrite(STDERR, "Extensão PHP ausente: $e\n"); exit(1); } }' 2>&1
}

pma_db_ativo() {
    command -v mariadb-admin >/dev/null 2>&1 || return 1
    mariadb-admin --protocol=socket --socket="$(pma_socket)" ping >/dev/null 2>&1
}

# IguaNews conecta a 127.0.0.1:3306 (TCP), enquanto phpMyAdmin usa o
# socket. Uma conexão pelo socket NÃO garante que o servidor aceite TCP.
pma_db_tcp_ativo() {
    command -v mariadb-admin >/dev/null 2>&1 || return 1
    mariadb-admin --protocol=tcp -h 127.0.0.1 -P 3306 --connect-timeout=3 ping >/dev/null 2>&1
}

pma_pid_web() {
    local pid cmd
    [ -f "$PMA_ROOT/web.pid" ] || return 1
    IFS= read -r pid < "$PMA_ROOT/web.pid" || return 1
    [[ "$pid" =~ ^[1-9][0-9]*$ ]] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    # Confere o comando do processo antes de permitir interrompê-lo.
    cmd="$(tr '\000' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"
    [[ "$cmd" == *"php -S ${PMA_ADDRESS}:${PMA_PORT}"* && "$cmd" == *"$PMA_SITE"* ]] || return 1
    printf '%s\n' "$pid"
}

pma_web_ativo() { pma_pid_web >/dev/null 2>&1; }

pma_gerar_configuracao() {
    local dir="$1" secret socket
    secret="$(openssl rand -base64 24 2>/dev/null | tr -d '\r\n')" || return 1
    [ "${#secret}" -eq 32 ] || return 1
    socket="$(pma_socket)"
    # Os caminhos do PREFIX Termux são internos e controlados pelo aplicativo.
    [[ "$socket" != *"'"* && "$socket" != *'\\'* ]] || return 1
    cat > "$dir/config.inc.php" <<EOF_PMA
<?php
// Configuração do Termux Manager. Acesso apenas por 127.0.0.1.
\$cfg['blowfish_secret'] = '${secret}';
\$i = 0;
\$i++;
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['host'] = 'localhost';
\$cfg['Servers'][\$i]['connect_type'] = 'socket';
\$cfg['Servers'][\$i]['socket'] = '${socket}';
\$cfg['Servers'][\$i]['AllowNoPassword'] = false;
\$cfg['TempDir'] = '${PMA_ROOT}/tmp';
\$cfg['LoginCookieValidity'] = 1800;
EOF_PMA
    chmod 600 "$dir/config.inc.php"
    php -l "$dir/config.inc.php" >/dev/null 2>&1
}

# Instalador isolado em subshell: umask e diretórios temporários não alteram
# o ambiente do gerenciador. O serviço existente nunca é sobrescrito.
pma_instalar() (
    umask 077
    local tmp archive hash expected_root entry old="" atual=""
    cabecalho_tela "🗄️ phpMyAdmin" "Instalação oficial v${PMA_VERSION}"
    caixa_simples "Download seguro" \
        "Origem: files.phpmyadmin.net" \
        "Versão fixa e verificação SHA-256." \
        "PHP e MariaDB devem estar instalados no Termux." \
        "A instalação não modifica bancos existentes."
    if pma_instalado; then
        caixa_simples "Já instalado" "Há uma instalação funcional em $(caminho_curto "$PMA_SITE")."
        confirmar_acao "Reinstalar preservando a configuração?" "n" || return 0
        if pma_web_ativo; then
            error "Encerre o phpMyAdmin antes de reinstalar."
            pause; return 1
        fi
    else
        confirmar_acao "Baixar e instalar phpMyAdmin?" "s" || return 0
    fi
    if ! command -v php >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1 || ! command -v openssl >/dev/null 2>&1; then
        instalar_lista_pacotes "Dependências phpMyAdmin" php curl unzip openssl || return 1
    fi
    if ! pma_dependencias_php; then
        error "PHP sem extensões obrigatórias para phpMyAdmin. Verifique o pacote PHP."
        pause; return 1
    fi
    mkdir -p "$PMA_ROOT" "$PMA_ROOT/tmp" || return 1
    chmod 700 "$PMA_ROOT" "$PMA_ROOT/tmp"
    tmp="$(mktemp -d "$PMA_ROOT/.instalacao.XXXXXXXX")" || return 1
    archive="$tmp/pma.zip"
    printf '\nBaixando o pacote oficial (aprox. 16 MB)...\n'
    if ! curl --fail --location --retry 2 --connect-timeout 15 --max-time 480 --progress-bar --output "$archive" "$PMA_URL" || \
       ! curl --fail --location --retry 2 --connect-timeout 15 --max-time 60 --silent --show-error --output "$tmp/pma.sha256" "$PMA_SHA_URL"; then
        rm -rf -- "$tmp"; error "Falha no download HTTPS. Tente novamente com internet."; pause; return 1
    fi
    hash="$(head -n 1 "$tmp/pma.sha256" | awk '{print $1}')"
    if ! [[ "$hash" =~ ^[[:xdigit:]]{64}$ ]]; then
        rm -rf -- "$tmp"; error "SHA-256 oficial inválido: instalação cancelada."; pause; return 1
    fi
    atual="$(sha256sum "$archive" | awk '{print $1}')"
    if [ "${hash,,}" != "${atual,,}" ]; then
        rm -rf -- "$tmp"; error "SHA-256 divergente: arquivo rejeitado."; pause; return 1
    fi
    if ! unzip -tq "$archive" >/dev/null 2>&1; then
        rm -rf -- "$tmp"; error "Arquivo ZIP corrompido."; pause; return 1
    fi
    # A origem é oficial e o SHA-256 está verificado. Ainda bloqueia caminhos
    # fora da pasta esperada, evitando extração fora do estágio.
    expected_root="phpMyAdmin-${PMA_VERSION}-all-languages"
    while IFS= read -r entry; do
        case "$entry" in
            "$expected_root"/*) ;;
            *) rm -rf -- "$tmp"; error "Arquivo inesperado no pacote."; pause; return 1 ;;
        esac
        if [[ "$entry" == *'/../'* || "$entry" == *'/./'* || "$entry" == */.. || "$entry" == /* || "$entry" == *'\\'* ]]; then
            rm -rf -- "$tmp"; error "Caminho inseguro no ZIP."; pause; return 1
        fi
    done < <(unzip -Z -1 "$archive")
    mkdir -p "$tmp/unpack" || { rm -rf -- "$tmp"; return 1; }
    if ! unzip -q "$archive" -d "$tmp/unpack"; then
        rm -rf -- "$tmp"; error "Falha ao extrair phpMyAdmin."; pause; return 1
    fi
    local novo="$tmp/unpack/$expected_root"
    if [ ! -f "$novo/index.php" ] || [ ! -f "$novo/vendor/autoload.php" ]; then
        rm -rf -- "$tmp"; error "Distribuição incompleta; pacote rejeitado."; pause; return 1
    fi
    if [ -f "$PMA_SITE/config.inc.php" ]; then
        cp -p "$PMA_SITE/config.inc.php" "$novo/config.inc.php" || { rm -rf -- "$tmp"; return 1; }
    elif ! pma_gerar_configuracao "$novo"; then
        rm -rf -- "$tmp"; error "Não foi possível preparar config.inc.php."; pause; return 1
    fi
    if [ -d "$PMA_SITE" ]; then
        old="$PMA_ROOT/.anterior.$$"
        if ! mv -- "$PMA_SITE" "$old"; then
            rm -rf -- "$tmp"; error "Não foi possível preservar instalação anterior."; pause; return 1
        fi
    fi
    if ! mv -- "$novo" "$PMA_SITE"; then
        [ -n "$old" ] && mv -- "$old" "$PMA_SITE" || true
        rm -rf -- "$tmp"; error "Não foi possível concluir instalação."; pause; return 1
    fi
    rm -rf -- "$tmp"
    [ -z "$old" ] || rm -rf -- "$old"
    ok "phpMyAdmin ${PMA_VERSION} instalado. SHA-256 conferido."
    caixa_simples "Próximo passo" "Inicie MariaDB pelo menu e depois inicie phpMyAdmin." "Login por usuário e senha MariaDB; senha vazia bloqueada."
    pause
)

pma_iniciar_db() {
    local dbdir socket pid i
    cabecalho_tela "🗄️ MariaDB" "Servidor local"
    if ! command -v mariadbd >/dev/null 2>&1 || ! command -v mariadb-admin >/dev/null 2>&1; then
        caixa_simples "Não instalado" "Instale PHP + MariaDB no menu PHP."
        pause; return 1
    fi
    if pma_db_ativo; then
        if pma_db_tcp_ativo; then
            caixa_simples "✅ MariaDB ativo" "Socket e TCP 127.0.0.1:3306 respondendo." "Nenhum banco foi alterado."
        else
            caixa_simples "⚠ MariaDB ativo apenas por socket" \
                "O phpMyAdmin pode funcionar, mas o IguaNews precisa de TCP 127.0.0.1:3306." \
                "Verifique skip-networking/bind-address na configuração MariaDB." \
                "Não reiniciamos nem alteramos bancos automaticamente."
        fi
        pause; return 0
    fi
    dbdir="$(pma_db_data)"; socket="$(pma_socket)"
    if [ ! -d "$dbdir/mysql" ]; then
        error "Banco ainda não inicializado. A instalação normal do pacote MariaDB cria as tabelas de sistema."
        caixa_simples "Diagnóstico" "Não recriamos automaticamente o diretório de dados para evitar perda de dados." "Verifique a instalação e o log do MariaDB."
        pause; return 1
    fi
    mkdir -p "$PMA_ROOT" "$(dirname "$socket")" || return 1
    chmod 700 "$PMA_ROOT"
    printf '\nIniciando MariaDB somente na interface local...\n'
    nohup mariadbd --datadir="$dbdir" --socket="$socket" --bind-address=127.0.0.1 \
        --port=3306 --pid-file="$PMA_ROOT/mariadb.pid" >"$PMA_ROOT/mariadb.log" 2>&1 </dev/null &
    pid=$!
    for ((i=0;i<10;i++)); do
        if pma_db_ativo; then
            if pma_db_tcp_ativo; then
                ok "MariaDB ativo: socket e TCP 127.0.0.1:3306."
            else
                caixa_simples "⚠ MariaDB iniciou" \
                    "Socket responde, mas TCP 127.0.0.1:3306 não foi confirmado." \
                    "O IguaNews poderá continuar sem conexão. Veja o diagnóstico."
            fi
            pause; return 0
        fi
        kill -0 "$pid" 2>/dev/null || break
        sleep 1
    done
    error "MariaDB não iniciou. Verifique o log $(caminho_curto "$PMA_ROOT/mariadb.log")."
    pause; return 1
}

pma_iniciar_web() {
    local pid i codigo
    cabecalho_tela "🌐 phpMyAdmin" "Servidor web local"
    if ! pma_instalado; then
        caixa_simples "Não instalado" "Selecione Instalar phpMyAdmin antes de iniciar."
        pause; return 1
    fi
    if ! pma_dependencias_php; then
        error "Extensões PHP incompletas."; pause; return 1
    fi
    if ! pma_db_ativo; then
        caixa_simples "MariaDB parado" "Inicie o MariaDB no menu antes do phpMyAdmin."
        pause; return 1
    fi
    if pma_web_ativo; then
        caixa_simples "✅ Já ativo" "Endereço: $(pma_url_local)"
        pause; return 0
    fi
    # Se a porta já estiver ocupada, jamais abrir um servidor desconhecido.
    if command -v curl >/dev/null 2>&1 && curl --silent --max-time 2 --output /dev/null "$(pma_url_local)"; then
        error "Porta 8081 ocupada por outro servidor. Início cancelado."; pause; return 1
    fi
    mkdir -p "$PMA_ROOT" || return 1
    chmod 700 "$PMA_ROOT"
    printf '\nIniciando servidor PHP em 127.0.0.1:%s...\n' "$PMA_PORT"
    nohup php -S "${PMA_ADDRESS}:${PMA_PORT}" -t "$PMA_SITE" >"$PMA_ROOT/web.log" 2>&1 </dev/null &
    pid=$!
    printf '%s\n' "$pid" > "$PMA_ROOT/web.pid"
    chmod 600 "$PMA_ROOT/web.pid"
    for ((i=0;i<6;i++)); do
        if ! kill -0 "$pid" 2>/dev/null; then break; fi
        codigo="$(curl --silent --max-time 2 --output /dev/null --write-out '%{http_code}' "$(pma_url_local)" || true)"
        if [[ "$codigo" =~ ^[234][0-9][0-9]$ ]] && pma_web_ativo; then
            ok "phpMyAdmin disponível em $(pma_url_local)"
            caixa_simples "Acesso protegido" "Servidor HTTP restrito a 127.0.0.1." "Login por usuário e senha MariaDB." "O MariaDB permanece ativo ao fechar phpMyAdmin."
            pause; return 0
        fi
        sleep 1
    done
    if pma_pid_web >/dev/null 2>&1; then kill "$pid" 2>/dev/null || true; fi
    rm -f -- "$PMA_ROOT/web.pid"
    error "Servidor não iniciou corretamente. Log: $(caminho_curto "$PMA_ROOT/web.log")"
    pause; return 1
}

pma_abrir_web() {
    cabecalho_tela "🌐 phpMyAdmin" "Navegador do Android"
    if ! pma_web_ativo; then
        caixa_simples "Servidor não iniciado" "Selecione Iniciar phpMyAdmin antes de abrir."
        pause; return 1
    fi
    local url
    url="$(pma_url_local)"
    if command -v termux-open-url >/dev/null 2>&1; then
        termux-open-url "$url" || true
    elif command -v am >/dev/null 2>&1; then
        am start -a android.intent.action.VIEW -d "$url" >/dev/null 2>&1 || true
    fi
    caixa_simples "Endereço local" "$url" "Use seu usuário e senha MariaDB." "Funciona sem internet após instalação."
    pause
}

pma_parar_web() {
    local pid
    cabecalho_tela "🌐 phpMyAdmin" "Encerrar servidor web"
    if ! pid="$(pma_pid_web)"; then
        caixa_simples "Sem servidor gerenciado" "Nenhum processo confirmado; não enviaremos sinal a outros processos."
        pause; return 0
    fi
    confirmar_acao "Encerrar apenas o phpMyAdmin?" "s" || return 0
    kill "$pid" 2>/dev/null || { error "Não foi possível encerrar servidor."; pause; return 1; }
    rm -f -- "$PMA_ROOT/web.pid"
    ok "Servidor phpMyAdmin encerrado. MariaDB preservado."
    pause
}

pma_criar_conta() (
    umask 077
    local senha count socket
    cabecalho_tela "🔐 Conta MariaDB" "Administração no phpMyAdmin"
    caixa_simples "Permissões" "Cria 'termux_pma'@'localhost' com privilégios administrativos completos." \
        "A senha aleatória será exibida uma vez; anote com cuidado." \
        "Não altera contas existentes nem apaga bancos." \
        "Use apenas em um aparelho pessoal e protegido."
    if ! pma_db_ativo; then error "Inicie MariaDB primeiro."; pause; return 1; fi
    if ! command -v openssl >/dev/null 2>&1; then error "OpenSSL ausente."; pause; return 1; fi
    socket="$(pma_socket)"
    if ! count="$(mariadb --protocol=socket --socket="$socket" -u root -N -B -e "SELECT COUNT(*) FROM mysql.user WHERE User='termux_pma' AND Host='localhost';" 2>/dev/null)"; then
        caixa_simples "Acesso root necessário" "Não foi possível conectar ao root sem senha." \
            "Use uma conta MariaDB já configurada no phpMyAdmin." \
            "Nenhuma credencial foi alterada."
        pause; return 1
    fi
    if [ "$count" != 0 ]; then
        caixa_simples "Conta já existe" "'termux_pma'@'localhost' não será modificada." "Entre com a senha já cadastrada."
        pause; return 0
    fi
    confirmar_acao "Criar conta administrativa local agora?" "n" || return 0
    senha="$(openssl rand -hex 20 2>/dev/null)" || return 1
    [[ "$senha" =~ ^[a-f0-9]{40}$ ]] || return 1
    if ! mariadb --protocol=socket --socket="$socket" -u root >/dev/null 2>&1 <<EOF_SQL
CREATE USER 'termux_pma'@'localhost' IDENTIFIED BY '$senha';
GRANT ALL PRIVILEGES ON *.* TO 'termux_pma'@'localhost' WITH GRANT OPTION;
EOF_SQL
    then
        error "Não foi possível criar a conta. Nenhuma senha foi gravada pelo Manager."
        pause; return 1
    fi
    caixa_simples "✅ Conta criada" "Usuário: termux_pma" "Senha: $senha" \
        "Guarde a senha agora; ela não será mostrada novamente." \
        "A conta possui permissões administrativas no MariaDB."
    pause
)

pma_diagnostico() {
    local ext pendentes="" socket sodium_status="indisponível" tcp_status="não responde"
    socket="$(pma_socket)"
    if command -v php >/dev/null 2>&1; then
        for ext in mysqli mbstring session json ctype filter iconv; do
            if ! php -r "exit(extension_loaded('$ext') ? 0 : 1);" 2>/dev/null; then
                pendentes+="${ext} "
            fi
        done
        if php -r 'exit(extension_loaded("sodium") ? 0 : 1);' 2>/dev/null; then
            sodium_status="ativa"
        else
            sodium_status="ausente (opcional no phpMyAdmin 5.2.3)"
        fi
    else
        pendentes="php (interpretador)"
    fi
    pma_db_tcp_ativo && tcp_status="respondendo" || true
    cabecalho_tela "🔎 phpMyAdmin" "Diagnóstico local"
    caixa_simples "Ambiente" \
        "PHP: $(command -v php >/dev/null 2>&1 && php -r 'echo PHP_VERSION;' || printf ausente)" \
        "Extensões obrigatórias ausentes: ${pendentes:-nenhuma}" \
        "Sodium: $sodium_status" \
        "MariaDB (socket): $(pma_db_ativo && printf ativo || printf parado)" \
        "MariaDB (TCP 127.0.0.1:3306): $tcp_status" \
        "Socket: $(caminho_curto "$socket")" \
        "phpMyAdmin: $(pma_instalado && printf instalado || printf ausente)" \
        "Servidor web: $(pma_web_ativo && printf ativo || printf parado)"
    caixa_simples "Acesso" "URL: $(pma_url_local)" "Somente loopback (127.0.0.1)." \
        "IguaNews exige conexão TCP ao MariaDB na porta 3306." \
        "Log web: $(caminho_curto "$PMA_ROOT/web.log")" "Log banco: $(caminho_curto "$PMA_ROOT/mariadb.log")"
    pause
}

menu_phpmyadmin() {
    while true; do
        menu_unificado "🗄️ phpMyAdmin" "MariaDB no navegador, acesso apenas local" "[0] Voltar" \
            "1|📥|Instalar phpMyAdmin|$(pma_instalado && printf 'Instalado' || printf 'Necessário download')" \
            "2|🗄️|Iniciar MariaDB|$(pma_db_ativo && printf 'Ativo' || printf 'Parado')" \
            "3|🌐|Iniciar phpMyAdmin|$(pma_web_ativo && printf 'Ativo' || printf 'Parado')" \
            "4|📱|Abrir no navegador|$(pma_url_local)" \
            "5|🔒|Criar conta local|Login com senha aleatória" \
            "6|⏹️|Parar phpMyAdmin|Não encerra MariaDB" \
            "7|🔎|Diagnóstico|PHP, banco, portas e extensões"
        ler_opcao
        case "$RESPOSTA_MENU" in
            1) pma_instalar || true ;;
            2) pma_iniciar_db || true ;;
            3) pma_iniciar_web || true ;;
            4) pma_abrir_web || true ;;
            5) pma_criar_conta || true ;;
            6) pma_parar_web || true ;;
            7) pma_diagnostico || true ;;
            0) return ;;
            *) feedback_curto "Opção inválida." ;;
        esac
    done
}

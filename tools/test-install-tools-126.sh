#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/modules/termux_packages_actions.sh"
source "$ROOT/modules/termux_tools.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export TERMUX_INSTALL_NONINTERACTIVE=true
TERMUX_SETUP_LOG="$TMP/pkg.log"
WIZARD_MODE=false
UI_CALLS=0
INSTALL_CALLS=0
INSTALL_TARGETS=()
declare -A EXIST=()
log(){ :; }
error(){ :; }
warn(){ :; }
pause(){ :; }
cabecalho_tela(){ :; }
caixa_simples(){ :; }
mostrar_erro_pkg(){ :; }
tela_operacao_termux(){ :; }
caminho_curto(){ printf '%s' "$1"; }
detectar_variante_termux(){ :; }
termux_origem_resumida(){ echo Teste; }
termux_repositorio_resumido(){ echo Teste; }
pacote_instalado_ou_funcional(){ [[ "${EXIST[$1]:-}" = yes ]]; }
pacote_disponivel_termux(){ [ "$1" != missing ]; }
executar_pkg_monitorado() {
    INSTALL_CALLS=$((INSTALL_CALLS + 1))
    INSTALL_TARGETS+=("$*")
    # Testa lote com exit 0 mas pacote não instalado. Tentativa individual deve
    # recuperar ou registrar falha; não presumir sucesso.
    if [[ "$*" == *"-- install -y php composer"* ]]; then
        EXIST[php]=yes
        return 0
    elif [[ "$*" == *"-- install -y composer"* ]]; then
        return 7
    else
        EXIST[php]=yes
        return 0
    fi
}
if instalar_lista_pacotes "Injeção" '--assume-yes'; then
    echo 'Aceitou opção perigosa como nome de pacote' >&2; exit 1
fi
[ "$INSTALL_CALLS" -eq 0 ]
if instalar_lista_pacotes "Indisponível" missing; then
    echo 'Retornou sucesso com pacote indisponível' >&2; exit 1
fi
[ "$INSTALL_CALLS" -eq 0 ]
if instalar_lista_pacotes "Pacotes" php composer; then
    echo 'Aceitou lote parcial sem o composer' >&2; exit 1
fi
[ "$INSTALL_CALLS" -eq 2 ]
[[ "${INSTALL_TARGETS[1]}" == *"-- install -y composer"* ]]
EXIST[composer]=yes
instalar_lista_pacotes "Pacotes" php composer
[ "$INSTALL_CALLS" -eq 2 ]

# A checagem com dpkg-query deve distinguir removido de instalado.
unset -f pacote_instalado_ou_funcional
function dpkg-query() {
    if [ "${*: -1}" = php ]; then printf 'install ok installed'; else printf 'deinstall ok config-files'; fi
}
pacote_registrado_instalado php
! pacote_registrado_instalado ruby

# Composer não é dependência obrigatória de PHP puro.
ambiente_dev_configurar php
[ "${AMB_DEV_COMANDOS[*]}" = php ]
[ "${AMB_DEV_PACOTES[*]}" = php ]

# O diagnóstico não cria banco nem executa comandos de inicialização.
function php() {
    if [ "$1" = -m ]; then printf 'PDO\npdo_mysql\nfileinfo\nmysqli\nzlib\n';
    elif [ "$1" = -r ]; then printf '8.4.0'; fi
}
function mariadb(){ :; }
function mariadbd(){ :; }
function status_comando_curto(){ printf 'Instalado'; }
function cabecalho_tela(){ :; }
DIAG_CONTENT="$TMP/diag"
function caixa_simples(){ printf '%s\n' "$@" >> "$DIAG_CONTENT"; }
diagnostico_php_local
! grep -q 'pdo_mysql: ausente' "$DIAG_CONTENT"
grep -q 'pdo_mysql: OK' "$DIAG_CONTENT"
grep -q 'fileinfo: OK' "$DIAG_CONTENT"
echo 'OK: nomes seguros, pacotes indisponíveis, lote parcial, Composer opcional, diagnóstico PHP.'

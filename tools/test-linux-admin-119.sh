#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/modules/linux_admin.sh"
linux_admin_usuario_valido ana_23
! linux_admin_usuario_valido 'a;rm -rf /'
! linux_admin_usuario_valido '-flag'
! linux_admin_alias_valido 'debian;touch /tmp/no'
linux_admin_alias_valido ubuntu
# Sensitive settings must be validated, not hardcoded to change Android globals.
! grep -Fq 'settings put global' "$ROOT/modules/linux_admin.sh"
grep -q 'pt_BR.UTF-8' "$ROOT/modules/linux_admin.sh"
grep -q 'America/Sao_Paulo' "$ROOT/modules/linux_admin.sh"
grep -q 'PermitRootLogin=no' "$ROOT/modules/linux_admin.sh"
grep -q '127.0.0.1' "$ROOT/modules/linux_admin.sh"
# Ensure admin guest call preserves PRoot status and does not mask failures.
T="$(mktemp -d)"; trap 'rm -rf -- "$T"' EXIT
LINUX_STATE_DIR="$T/state"; LINUX_LOG="$T/linux.log"
linux_garantir_proot_distro() { :; }; cabecalho_tela() { :; }; caixa_simples() { :; }; confirmar_acao() { :; }
ui_buffer_flush() { :; }; linux_logs_nova_sessao() { :; }; linux_logs_encerrar_sessao() { :; }
linux_log() { :; }; linux_invalidar_cache_distro() { :; }; ok() { :; }; error() { :; }; pause() { :; }
proot-distro() { printf 'falha\n'; return 47; }
mkdir -p "$T"
if linux_admin_exec ubuntu Teste 'echo hello' > "$T/out" 2>&1; then exit 1; else [ "$?" -eq 47 ]; fi
printf 'OK: entradas, isolamento, SSH local e status do PRoot.\n'

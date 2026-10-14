#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf -- "$T"' EXIT
LINUX_STATE_DIR="$T/state"; LINUX_LOG="$T/linux.log"; : > "$LINUX_LOG"
source "$ROOT/modules/linux_logs.sh"
source "$ROOT/modules/linux_diagnostics.sh"
source "$ROOT/modules/linux_x11.sh"
linux_log() { printf '%s\n' "$*" >> "$LINUX_LOG"; }
error() { :; }; warn() { :; }; pause() { :; }; ok() { :; }
linux_logs_inicializar
[ "$(stat -c %a "$LINUX_STATE_DIR/sessoes")" = 700 ]
[ "$(linux_logs_preferencia modo manual)" = manual ]
! linux_logs_salvar_preferencias 'invalido' 10
! linux_logs_salvar_preferencias falha 100
linux_logs_salvar_preferencias falha 5
[ "$(stat -c %a "$LINUX_STATE_DIR/logs.conf")" = 600 ]
linux_logs_nova_sessao ubuntu lxde
f="$LINUX_LOGS_SESSAO_ATUAL"
[ -f "$f" ]
[ "$(stat -c %a "$f")" = 600 ]
linux_logs_encerrar_sessao 137
[ -z "$LINUX_LOGS_SESSAO_ATUAL" ]
grep -q 'Status de saída: 137' "$f"
# Mocks: no need for Android. Failure mode triggers one export.
linux_exportar_log_downloads() { printf 'exportado\n' >> "$T/exports"; }
linux_logs_auto_exportar 0
[ ! -f "$T/exports" ]
linux_logs_auto_exportar 2
[ "$(wc -l < "$T/exports")" -eq 1 ]
linux_logs_salvar_preferencias todas 5
linux_logs_auto_exportar 0
[ "$(wc -l < "$T/exports")" -eq 2 ]
linux_logs_salvar_preferencias manual 5
linux_logs_nova_sessao ubuntu lxde
linux_logs_encerrar_sessao 0
linux_x11_marcar_inicio_sessao ubuntu lxde
caixa_simples() { :; }
linux_logs_verificar_interrupcao
linux_logs_verificar_interrupcao
[ -f "$LINUX_STATE_DIR/last-interruption.reported" ]
# Symlink attacks on preferences and guest logs are refused.
rm "$LINUX_STATE_DIR/logs.conf"; printf 'imutavel\n' > "$T/victim"
ln -s "$T/victim" "$LINUX_STATE_DIR/logs.conf"
! linux_logs_salvar_preferencias falha 5
[ "$(cat "$T/victim")" = imutavel ]
# New session history limited to selected retention.
rm "$LINUX_STATE_DIR/logs.conf"
linux_logs_salvar_preferencias manual 5
for n in 1 2 3 4 5 6 7; do LINUX_LOGS_SESSAO_ATUAL=""; linux_logs_nova_sessao "ubuntu$n" teste; done
[ "$(find "$LINUX_STATE_DIR/sessoes" -type f -name 'sessao-*.log' | wc -l)" -le 5 ]
printf 'OK: histórico privado, rotação, preferências, SIGKILL e segurança de links.\n'

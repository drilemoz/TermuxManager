#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
PIDS=()
cleanup() { for pid in "${PIDS[@]}"; do kill "$pid" 2>/dev/null || true; done; rm -rf "$TMP"; }
trap cleanup EXIT
export HOME="$TMP/home"; mkdir -p "$HOME"
source "$ROOT_DIR/modules/core.sh"
comando_existe() { command -v "$1" >/dev/null 2>&1; }
info() { :; }; warn() { :; }; error() { :; }; ok() { :; }; log() { :; }
MOSTRAR_LOG_FALHA=false; ABRIR_NAVEGADOR_AUTO=false
source "$ROOT_DIR/modules/runtime.sh"
mkdir -p "$LOG_DIR" "$PID_DIR" "$SESSION_TMP_DIR"
# PID e tick válidos: não inferir saúde somente pela porta de outro processo.
porta=$((39000 + RANDOM % 12000))
python3 -m http.server "$porta" --bind 127.0.0.1 >"$TMP/http.log" 2>&1 & servidor=$!; PIDS+=("$servidor")
for _ in {1..30}; do if porta_em_escuta "$porta"; then break; fi; sleep 0.1; done
porta_em_escuta "$porta" || { echo 'Servidor auxiliar indisponível'; exit 1; }
sleep 40 & inocente=$!; PIDS+=("$inocente")
printf '%s\n' "$inocente" > "$PID_DIR/falso.pid"
printf 'EXPECTED_PORT=%s\nPID_START_TICKS=%s\n' "$porta" "$(pid_inicio_ticks "$inocente")" > "$PID_DIR/falso.meta"
estado_servidor_processo falso >/dev/null 2>&1 || true
[ "$ESTADO_PROCESSO" != 'servidor disponível' ] || { echo 'Porta de terceiro foi atribuída ao processo'; exit 1; }
[ "$PORTA_PROCESSO" = '?' ] || { echo 'Identificou porta incorreta'; exit 1; }
# Simula PID reutilizado: o número existe, mas o instante é outro.
printf 'EXPECTED_PORT=%s\nPID_START_TICKS=1\n' "$porta" > "$PID_DIR/falso.meta"
if pid_ativo "$PID_DIR/falso.pid"; then echo 'Aceitou PID reutilizado'; exit 1; fi
if parar_processo falso >/dev/null 2>&1; then echo 'Permitiu encerrar PID não validado'; exit 1; fi
kill -0 "$inocente" 2>/dev/null || { echo 'Processo inocente encerrado'; exit 1; }
# Legado sem identidade também não deve ser encerrado automaticamente.
printf 'EXPECTED_PORT=%s\n' "$porta" > "$PID_DIR/falso.meta"
if parar_processo falso >/dev/null 2>&1; then echo 'Permitiu encerrar processo legado'; exit 1; fi
kill -0 "$inocente" 2>/dev/null || { echo 'Processo legado encerrado'; exit 1; }
echo 'OK: porta não atribuída incorretamente e PID reutilizado protegido.'

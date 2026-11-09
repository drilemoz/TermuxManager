#!/usr/bin/env bash
# Regressão offline: Downloads do Termux é um link simbólico no Android.
# Não usa conexão SSH, sudo, Internet ou arquivos do usuário.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
export HOME="$TMP/home"
SHARED="$TMP/Armazenamento Android/Download"
mkdir -p "$HOME/storage" "$SHARED"
ln -s "$SHARED" "$HOME/storage/downloads"
printf 'zip teste\n' > "$SHARED/AL-Sistemas-v2.0.18-VPS.zip"
ln -s "$SHARED/AL-Sistemas-v2.0.18-VPS.zip" "$SHARED/arquivo-link.zip"
printf 'não zip\n' > "$SHARED/arquivo.txt"
LOG="$TMP/menu.log"
: > "$LOG"
# Stubs da interface para rodar apenas o navegador de arquivos.
cabecalho_tela(){ :; }
caixa_simples(){ :; }
caixa_linha_topo(){ :; }
caixa_linha_baixo(){ :; }
caixa_linha_texto(){ :; }
rodape_atalhos(){ :; }
menu_opcao(){ printf '%s\n' "$3" >> "$LOG"; }
ler_opcao(){ IFS= read -r RESPOSTA_MENU || RESPOSTA_MENU=X; }
warn(){ :; }
pause(){ :; }
caminho_curto(){ printf '%s' "$1"; }
wizard_nome_arquivo_visivel(){ basename -- "$1"; }
source "$ROOT/modules/projects_aws.sh"

# 1) ZIP normal deve aparecer na pasta Downloads apontada por link.
AWS_ZIP=''
aws_escolher_zip <<< '1' || { echo 'FALHOU: Downloads simbólico não foi percorrido.' >&2; exit 1; }
[ "$AWS_ZIP" = "$HOME/storage/downloads/AL-Sistemas-v2.0.18-VPS.zip" ] || {
    echo "FALHOU: ZIP selecionado incorreto: $AWS_ZIP" >&2; exit 1;
}
! grep -Fq 'arquivo-link.zip' "$LOG" || { echo 'FALHOU: seguiu link de ZIP.' >&2; exit 1; }
! grep -Fq 'arquivo.txt' "$LOG" || { echo 'FALHOU: exibiu arquivo sem extensão ZIP.' >&2; exit 1; }

# 2) Entrar em uma subpasta com espaço, mantendo o caminho de Downloads.
mkdir "$SHARED/subpasta com espaço"
mv "$SHARED/AL-Sistemas-v2.0.18-VPS.zip" "$SHARED/subpasta com espaço/"
AWS_ZIP=''
aws_escolher_zip <<< $'1\n1' || { echo 'FALHOU: navegação até subpasta de Downloads.' >&2; exit 1; }
[ "$AWS_ZIP" = "$HOME/storage/downloads/subpasta com espaço/AL-Sistemas-v2.0.18-VPS.zip" ] || {
    echo 'FALHOU: ZIP aninhado selecionado incorretamente.' >&2; exit 1;
}

# 3) A opção Downloads continua funcionando após alternar para Home.
AWS_ZIP=''
aws_escolher_zip <<< $'H\nD\n1\n1' || { echo 'FALHOU: atalho D/Home.' >&2; exit 1; }
[ "$AWS_ZIP" = "$HOME/storage/downloads/subpasta com espaço/AL-Sistemas-v2.0.18-VPS.zip" ] || {
    echo 'FALHOU: atalho Downloads selecionou destino errado.' >&2; exit 1;
}

# 4) Atualizador local de ZIPs e módulos usa o mesmo caminho simbólico.
source "$ROOT/modules/updater_local.sh"
DOWNLOADS_DIR="$HOME/storage/downloads"
printf 'manager teste\n' > "$SHARED/TermuxManager-v1.0.135.zip"
printf '#!/bin/bash\n' > "$SHARED/manager.sh"
ln -s "$SHARED/TermuxManager-v1.0.135.zip" "$SHARED/manager-link.zip"
listar_pacotes_completos
[ "${#ATUALIZACOES_ENCONTRADAS[@]}" -eq 1 ] || {
    echo 'FALHOU: atualizador não achou ZIP real ou listou link simbólico.' >&2; exit 1;
}
[ "${ATUALIZACOES_ENCONTRADAS[0]}" = "$SHARED/TermuxManager-v1.0.135.zip" ] || {
    # A função deve manter o caminho de Downloads configurado, não reescrever para alvo real.
    [ "${ATUALIZACOES_ENCONTRADAS[0]}" = "$DOWNLOADS_DIR/TermuxManager-v1.0.135.zip" ] || exit 1;
}
MODULES_DIR="$ROOT/modules"
listar_modulos_atualizacao
[ "${#ATUALIZACOES_ENCONTRADAS[@]}" -eq 1 ] && [ "${ATUALIZACOES_ENCONTRADAS[0]}" = "$DOWNLOADS_DIR/manager.sh" ] || {
    echo 'FALHOU: atualização local não localizou manager.sh em Downloads.' >&2; exit 1;
}

# 5) O detector de armazenamento não considera Downloads vazio por ser link.
source "$ROOT/modules/core.sh"
resolver_downloads_dir || { echo 'FALHOU: não resolveu Downloads.' >&2; exit 1; }
[ "$DOWNLOADS_DIR" = "$HOME/storage/downloads" ] || {
    echo 'FALHOU: não escolheu Downloads principal com conteúdo.' >&2; exit 1;
}

echo 'OK: AWS ZIP, atualização local ZIP/módulos, detecção de Downloads simbólico, filtros, bloqueio de links e subpastas.'


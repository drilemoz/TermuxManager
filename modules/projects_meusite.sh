#!/data/data/com.termux/files/usr/bin/bash
# Integração de menu: atalho para o atualizador independente do IguatamaOnline.
# Não implementa implantação dentro do Manager; preserva as confirmações do shell.

meusite_executar_atalho() {
    local modo="$1" script="$BASE_DIR/tools/atualizar-meu-site-termux.sh"
    case "$modo" in
        --check|--patch|--update) ;;
        *) error "Modo inválido."; return 2 ;;
    esac
    if [ ! -f "$script" ] || [ -L "$script" ] || [ ! -r "$script" ]; then
        error "Atualizador do IguatamaOnline ausente/inseguro na instalação do Manager."
        return 1
    fi
    # Compartilha a configuração SSH já existente do Manager para a mesma EC2,
    # sem compartilhar chaves ou armazená-las no pacote.
    aws_carregar_config
    aws_validar_config || return 1
    info "Executando IguatamaOnline $modo em $AWS_USER@$AWS_HOST:$AWS_PORT"
    info "Destino de referência: ${MEUSITE_SITE:-/var/www/projetos/iguatamaonline}"
    # O script confirma ações de escrita e interrompe operações inseguras.
    MEUSITE_HOST="$AWS_HOST" MEUSITE_USER="$AWS_USER" MEUSITE_PORT="$AWS_PORT" \
      MEUSITE_KEY="$AWS_KEY" bash "$script" "$modo"
}

menu_aws_meusite() {
    local resultado
    while true; do
        menu_unificado "📰 IGUATAMAONLINE NA AWS" "Atalho do atualizador Meu-Site (SSH)" \
            "[0] Voltar  •  [1–4] Selecionar" \
            "1|🔎|Verificar servidor|Somente diagnóstico; não modifica o site" \
            "2|🩹|Aplicar patch do atualizador|Substitui app/updater.php após confirmar" \
            "3|🔄|Atualizar IguatamaOnline|ZIP local ou Release GitHub; exige backup" \
            "4|🔑|Configurar conexão SSH|Compartilhada com AL Sistemas na AWS"
        ler_opcao
        case "$RESPOSTA_MENU" in
            1) meusite_executar_atalho --check; resultado=$?; [ "$resultado" -eq 0 ] || warn "Verificação falhou (código $resultado)."; pause ;;
            2) meusite_executar_atalho --patch; resultado=$?; [ "$resultado" -eq 0 ] || warn "Patch não aplicado (código $resultado)."; pause ;;
            3) meusite_executar_atalho --update; resultado=$?; [ "$resultado" -eq 0 ] || warn "Atualização não concluída (código $resultado)."; pause ;;
            4) aws_configurar ;;
            0) return 0 ;;
            *) warn "Opção inválida."; sleep 1 ;;
        esac
    done
}

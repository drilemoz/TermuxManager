# Termux Manager

Gerenciador modular de projetos para **Termux no Android**, desenvolvido por **Adriedson Aparecido Lemos**.

O Termux Manager organiza, importa, prepara, executa e mantém projetos locais por meio de uma interface de terminal com menus estáveis, progresso em tempo real, logs, backups, atalhos globais e controle de processos.

**Versão atual:** 1.0.130  

### Verificação automática opcional na abertura (1.0.129)

- Ao executar `mm` ou `manager`, consulta a versão no GitHub se o assistente inicial **já estava concluído** e a última consulta bem-sucedida ocorreu há 24 horas ou mais. Não consulta durante o primeiro assistente, nem ao executar em pipes/sem terminal interativo.
- Se houver versão superior na `main`, mostra as notas, pede confirmação para baixar e instalar e reutiliza o instalador transacional com backup e recuperação.
- Se não houver internet ou o GitHub falhar, abre o menu normalmente. Limite para nova tentativa após erro: 6 horas. O check de abertura tem timeout curto, sem consultas a cada menu.
- Para desligar: **Configurações → Comportamento → Buscar atualizações ao abrir**. Para verificar imediatamente: **Atualizar Manager → Verificar no GitHub**. O ajuste é persistido no Painel.
- A atualização automática depende da publicação de um `MANIFEST.json` compatível na branch `main` do repositório configurado; não consulta arquivos salvos só no Drive. Não atualiza pacotes APT nem serviços do usuário.

### phpMyAdmin integrado ao MariaDB (1.0.127)

- **Instalar ferramentas → PHP → phpMyAdmin** ou **Instalar ferramentas → Bancos → phpMyAdmin**: instalar a distribuição oficial **phpMyAdmin 5.2.3**, iniciar o MariaDB local, iniciar/abrir/parar o servidor web local, criar opcionalmente uma conta administrativa local e visualizar diagnóstico.
- O phpMyAdmin **não está embutido** no ZIP do Termux Manager: sua instalação baixa o arquivo oficial completo por HTTPS, verifica o **SHA-256** publicado pelo mesmo provedor e extrai para `~/.termux-manager/phpmyadmin/site`. Necessita internet para a primeira instalação; depois o uso local dispensa internet.
- A página de administração usa **somente `127.0.0.1:8081`**, separado da porta do IguaNews (`127.0.0.1:8000`). Usa o socket `$PREFIX/var/run/mysqld.sock`, autenticação `cookie`, segredo aleatório privado e proíbe senhas em branco. O phpMyAdmin não fornece banco próprio: conecta-se ao MariaDB.
- Uma ação opcional cria **`termux_pma`@`localhost`** com senha aleatória de 40 caracteres hexadecimais e privilégios administrativos completos, SOMENTE após confirmação e quando o cliente root local consegue entrar sem senha. A senha é exibida uma vez, **não fica em arquivos do Manager**. Não modifica uma conta `termux_pma` existente. Caso root exija senha, use uma conta já configurada ou administre-a separadamente.
- O MariaDB existente é preservado: se estiver inicializado, pode ser iniciado na interface local; se faltar a tabela de sistema, o Manager não recria o banco automaticamente. Parar o servidor web **não encerra o MariaDB**.
- Servidor PHP de desenvolvimento, para uso privado no próprio Android. **Nunca exponha phpMyAdmin à rede pública, encaminhamento de portas, túnel ou internet sem medidas adicionais**. Antes de restaurar bancos do IguaNews, faça backup. O uso com MariaDB real e navegadores Android ainda exige teste no celular.

### Auditoria da instalação de ferramentas (1.0.126)

- Menu **Instalar ferramentas → PHP** agora separa **PHP básico** (sem Composer), **PHP + Composer**, **PHP + MariaDB** e **Diagnóstico PHP**. Composer é opcional para projetos PHP simples e o painel de ambientes não o marca como requisito obrigatório.
- Diagnóstico mostra a versão do PHP, extensões `PDO`, `pdo_mysql`, `mysqli`, `fileinfo`, `zlib` e presença do cliente/servidor MariaDB. A instalação do pacote **não inicia nem inicializa o banco**, preservando dados existentes. Para IguaNews, é necessário configurar um banco e usuário próprios separadamente.
- O instalador recusa nomes de pacote malformados (inclusive argumentos começando com `-`), confere o estado de cada pacote após o apt, tenta fallback individual somente quando restarem pendências e não informa sucesso se houver pacote falho ou indisponível.
- Corrigida a propagação de falhas ao instalar gerenciadores JavaScript por `pkg` ou `npm`. Atualização da documentação sem alteração dos projetos do usuário.

### Explorer de arquivos (1.0.125)

- Acesse **Menu principal → 9. Explorer de arquivos** para navegar por arquivos e diretórios acessíveis ao Termux, sem digitar comandos shell. As opções exibidas dependem das permissões do Android e do Termux; não concede acesso root.
- Selecione um item pelo número. Em pastas: abrir, detalhes, copiar, mover, renomear ou excluir. Em arquivos: visualizar texto (somente leitura), detalhes, copiar, mover, renomear ou excluir.
- Navegação paginada de 10 itens por tela, pastas antes de arquivos, incluindo arquivos ocultos. **U** sobe um nível, **N/A** troca a página, **?** abre atalhos para Home, Painel, Downloads, armazenamento e raiz do sistema. Os atalhos **H/P/D/S/R** também podem ser usados diretamente.
- Ao escolher **Copiar** ou **Mover**, navegue até a pasta de destino e use **C (Colar)**. **X** limpa a seleção. **M** cria uma nova pasta; para renomear ou criar, digita-se apenas o novo nome, sem comandos.
- **Segurança:** operações de exclusão exigem confirmação e não passam pela lixeira; substituições de nomes existentes são recusadas; cópia recursiva de pasta dentro dela mesma é bloqueada; raízes críticas e a instalação do Manager não podem ser removidas/movidas/renomeadas.
- A visualização de arquivos de texto nunca executa scripts; o recurso não funciona como editor e não contorna as restrições de armazenamento do Android. Faça backup antes de mover ou excluir arquivos importantes.

### Menu de execução ajustado (1.0.124)

- Para projetos PHP/Laravel sem frontend separado, **Executar projeto** oferece `1) Iniciar site PHP`, e não um frontend inexistente; o navegador abre no endereço local após o servidor responder.
- Projetos backend-only (por exemplo, Python/API) também usam a opção 1; frontend-only permanece opção 1. Projetos fullstack mantêm 1 frontend, 2 backend e 3 ambos.
- Essa atualização altera o **Termux Manager**, não o código do IguaNews. O MariaDB continua sendo instalado e inicializado separadamente.

### Importação de portais PHP como um único projeto (1.0.123)

- Corrige a descoberta quando um ZIP com portal PHP (ex.: IguaNews, composto de `app/`, `bin/`, `public/` e `tests/`) é importado diretamente para `~/Painel`. O Manager passa a exibir a **raiz do Painel como um projeto**, sem duplicar as subpastas internas na lista.
- A detecção precisa de um marcador real na raiz, como `composer.json`, `index.php` ou `public/index.php`. Não agrupa pastas avulsas só por conterem scripts PHP.
- Outros projetos independentes continuam listados, desde que não usem um nome reservado para pastas internas PHP. Importar cada projeto como `~/Painel/projetos/Nome/` é recomendado para isolamento e para evitar ambiguidades.
- Com `public/index.php`, executar o projeto na raiz mantém `public/` como docroot HTTP. A atualização **não move nem exclui arquivos**, não altera o portal nem instala/configura o MariaDB.
- As opções **Excluir projeto** e **Copiar projeto** bloqueiam operações sobre a raiz inteira do Painel, evitando apagar tudo ou criar uma cópia recursiva. Para cópia independente, importe o ZIP numa pasta própria. Pode-se personalizar o nome de exibição como `IguaNews` no menu do projeto.

### Projetos PHP e portais locais (1.0.122)

- Reconhece `index.php`, arquivos `*.php` na raiz, `public/index.php`, `web/index.php`, `www/index.php`, `htdocs/index.php` e `public_html/index.php` sem exigir Composer.
- Em **Projetos**, o PHP é exibido como backend e pode ser preparado e executado. Para PHP sem Composer, apenas o pacote `php` é necessário; projetos com `composer.json` mantêm a instalação pelo Composer.
- Inicia um servidor de **desenvolvimento** em `127.0.0.1:8000`, usando a pasta pública com `-t public` quando encontrada, e abre `http://127.0.0.1:8000` no navegador após confirmar a inicialização.
- Para Laravel, mantém `artisan serve` mas escuta somente em `127.0.0.1`.
- Projetos com `.env` ou credenciais na pasta publicada devem proteger esses arquivos. Prefira uma pasta `public/` separada; o servidor PHP embutido **não é adequado para produção** nem para acesso público na internet.
- Para portais PHP + MySQL/MariaDB no Termux, instale **PHP** em Ferramentas de desenvolvimento e **MariaDB** em Bancos de dados. Configure e inicie o MariaDB separadamente; a nova detecção não cria banco, usuário, schema, migração ou backups do portal. Confira as extensões com `php -m | grep -Ei 'pdo_mysql|mysqli'`.

### Pós-importação direto ao projeto (1.0.64)

Depois de uma importação bem-sucedida, o Manager não obriga mais o retorno ao menu principal. É possível **testar o projeto recém-importado**, **abrir seu menu de gerenciamento**, **importar outro projeto** ou voltar ao início. O caminho usado é exatamente o destino da cópia.

A análise de arquivos também foi dividida em duas fases. Enquanto o total ainda é desconhecido, a tela mostra quantos arquivos foram encontrados sem inventar uma porcentagem. Depois, com o total conhecido, exibe o percentual real de cálculo de tamanho antes de iniciar a cópia.


### Isolamento por caminho do projeto (1.0.63)

O runtime, processos e caches distinguem cada projeto pelo caminho canônico. Assim `~/Painel` e `~/Painel/projetos/<nome>` permanecem isolados mesmo quando possuem pastas `backend`/`frontend` semelhantes. O teste integrado também rotaciona logs no início e o relatório de erro informa os diretórios efetivamente resolvidos. A validação npm considera dependências de topo e registra o pacote/etapa responsável quando houver inconsistência.

**Canal:** Estável  
**Repositório:** https://github.com/adriedsonlemoz/TermuxManager

### Identificação de projetos

O Manager usa o **nome da pasta** como identidade padrão do projeto. O campo `name` do `package.json` é mantido como informação técnica e para apoio à detecção da stack. Em **Gerenciar projetos → Nome de exibição**, é possível definir um apelido sem modificar o projeto; ele é salvo em `~/.termux-manager/projects/`.

## Painel de teste integrado
Ao executar frontend + backend juntos, o Manager usa um painel único com quatro etapas (Backend, Frontend, Inicialização e Disponibilidade). Status, avisos, PID, logs e detecção de servidor permanecem dentro da moldura visual durante a execução. Quando uma etapa falha, o painel é encerrado corretamente e o Manager oferece **Coletar logs do teste**, gerando em Downloads um único TXT sanitizado com logs de backend, frontend, Manager e metadados de processo.



### Catálogo Linux ampliado e navegadores (1.0.122)

- **21 categorias, 160 sugestões de pacotes** exclusivas do catálogo das distribuições Linux PRoot, sem copiar o catálogo de dependências do Termux.
- Navegadores GUI (NetSurf, GNOME Web, Falkon, Qutebrowser) e de terminal (W3M, Lynx, Links, ELinks); gerenciadores de arquivos, escritório, PDF, multimídia, edição de imagens, IDEs, linguagens, terminal, rede, servidores, bancos de dados, jogos, ciência, temas e fontes.
- Menu paginado em **7 itens por tela** (8 = próxima; 9 = anterior), adequado à tela com teclado do Android. Antes de instalar, apresenta descrição, necessidade de X11, indicação **relativa** de consumo e **verifica sob demanda** no repositório da distro se o pacote está instalado, disponível ou ausente.
- No APT, consulta `dpkg-query` e `apt-cache policy` dentro do Ubuntu/Debian; os demais gerenciadores usam suas próprias consultas. Se consulta falhar ou pacote estiver ausente, **não instala automaticamente pelo catálogo**. É possível pesquisar/instalar outro nome pela central, com confirmação.
- A prévia do APT com `apt-get -s` continua disponível e informa dependências; **estimativas de consumo não substituem tamanho efetivo de download**. A presença do pacote no repositório não garante que sua GUI funcione no Android/PRoot.
- Evita sugerir `chromium-browser` e `firefox` no Ubuntu como instalação direta: os pacotes distribuídos via Snap não são adequados ao PRoot sem systemd. Não instala nem baixa nada quando se abre o catálogo. Pacotes diferentes/ausentes em Alpine, Arch ou Fedora são identificados na consulta.

### Central de programas e gerenciamento de pacotes (1.0.120)

- Menu Programas e pacotes em cada distro, sem necessidade do X11.
- Catálogo por oito categorias: desenvolvimento, editores, rede, monitoramento, arquivos, sessões, utilitários e web.
- Busca, informações, prévia e instalação, remoção, listagem de pacotes e atualização do sistema.
- Gerenciadores suportados: APT, Pacman, APK/Alpine, DNF e Zypper, com verificação do nome antes de interpolar qualquer pacote.
- APT executa simulação antes da confirmação; outros gerenciadores oferecem dados do pacote, não uma simulação de dependências.
- Resultado do comando e falhas do PRoot são exibidos e registrados; nomes do catálogo dependem da distribuição.

### Configuração do Linux pelo terminal (1.0.119)

- Configuração do idioma UTF-8 no Debian/Ubuntu: pt_BR, en_US e es_ES; outras distribuições recebem aviso de compatibilidade.
- Fuso horário (Brasília, UTC, Lisboa ou Buenos Aires), criação de usuário não-root e escolha do shell instalado.
- Diagnóstico DNS/rede, espaço, limpeza de cache por gerenciador de pacotes e painel de processos.
- Assistente SSH opcional: instalação, diagnóstico e execução em 127.0.0.1:8022, com login por chave e senhas/root desabilitados.
- Servidor HTTP local de teste em 127.0.0.1:8000, sem criar serviço residente nem exigir systemd.
- Comandos interpolam apenas opções predefinidas ou identificadores validados; operações são confirmadas antes de executar.

### Logs inteligentes e diagnóstico de sessões (1.0.118)

- Histórico privado por sessão Linux (inclui terminal e desktop), com limite configurável e limpeza explícita.
- Exportação opcional para Downloads: somente manual, após falha ou ao encerrar qualquer sessão.
- Detecção de sessão X11 interrompida na próxima abertura do menu e preservação do log para análise.
- Captura opcional do arquivo de log do desktop dentro do Ubuntu (LXDE, XFCE, LXQt e MATE), sem processo residente.
- Sanitização existente preservada; exportação inclui o log capturado do desktop. Logs centrais grandes são rotacionados ao começar uma nova sessão.
- Não promete exportação no instante de SIGKILL: nesse caso, tenta ao reabrir o menu, se a preferência permitir.

### Diagnóstico de signal 9 no Termux:X11 (1.0.117)

Uma sessão gráfica pode mostrar `[Process completed (signal 9)]` quando o Android encerra à força o processo do Termux. Android 12+ possui restrições conhecidas sobre processos filhos (Phantom Process Killer), mas SIGKILL também pode ocorrer por outros motivos, incluindo pressão de memória. O Manager não tem como impedir o Android de encerrar seu próprio processo.

O menu **Linux > Interface gráfica (X11) > Suporte > Signal 9 e Android** orienta a verificar bateria e opções de desenvolvedor manualmente. O Manager salva um marcador privado de sessão ativa; se o próprio terminal for encerrado, a próxima abertura do desktop avisa sobre a interrupção anterior sem afirmar sua causa. A saída do servidor vai para `linux/x11-server.log` no armazenamento privado do Manager, e a sessão PRoot é registrada em `linux.log`, exportável com sanitização para Downloads. A exportação acrescenta até 64 KiB recentes do servidor X11, também sanitizados. A captura de logs para quando o Android mata o processo e, portanto, pode ser incompleta.

### Instalação de desktop com status visível (1.0.116)

- **Linux > Interface gráfica (X11) > Instalar desktop:** depois de confirmar, a tela e os avisos saem imediatamente do buffer visual; não fica vazia até o término do processo.
- A instalação mostra **etapa atual**, **tempo decorrido** e, conforme o APT emitir eventos, contagem de **downloads observados** e **pacotes configurados**. A saída original do gerenciador de pacotes permanece visível e é salva em `linux.log`.
- O status aparece a cada 10 segundos (configurável via `LINUX_DESKTOP_HEARTBEAT_SECONDS`). Os contadores se baseiam em linhas reais; não existe percentual global, total de arquivos ou ETA confiável para a instalação inteira.
- A mensagem de espera **não comprova que o download está avançando**. Se parar por tempo excessivo, exporte o log no menu de diagnóstico. O Manager não impõe timeout global e preserva o código de erro do PRoot/APT.

### Instalação de desktop com progresso e permissões de APK (1.0.115)

- **Linux > Interface gráfica (X11) > Instalar desktop:** antes de entrar no Ubuntu/PRoot, a tela mostra o comando em andamento e exibe um aviso a cada 20 segundos durante a espera. Isso **não garante que a instalação esteja progredindo** nem identifica automaticamente a causa de um bloqueio; fornece visibilidade e mantém a opção de Ctrl+C. O código de retorno do PRoot/APT continua no log Linux.
- **Linux > Interface gráfica (X11) > Status e problemas > Permissões para instalar APKs** (também em **Linux > Ajuda e diagnóstico**): checar `allow-external-apps`, ativar com confirmação e backup protegido, abrir a tela Android de fontes desconhecidas e restaurar o `termux.properties` anterior. A autorização do Android continua manual. **Não é necessária para simplesmente usar um X11 já instalado.**
- `allow-external-apps=true` amplia a superfície de integração externa do Termux (inclusive `RUN_COMMAND` em aplicativos que receberem permissão). Só ative se desejar essa integração e confiar nos aplicativos aos quais concedeu acesso.

### Verificação do Termux:X11 e teste de abertura no Android (1.0.114)

Em **Linux no celular > Interface gráfica (X11) > Preparar Termux:X11**, o Manager usa consultas alternativas do Android (`pm path`, `cmd package path` e `pm list packages`). Se o Android restringir as consultas, o estado continua **não confirmado**, sem supor que o APK esteja desinstalado. A opção **Testar abertura do app** usa a Activity oficial do Termux:X11 com `am start`, sem reinstalar APK, pedir root ou habilitar `allow-external-apps`. Também está disponível em **Status e problemas > Testar abertura do X11**. A confirmação permanece somente durante a sessão atual do Manager.

Em **Verificar instalação**, os resultados das consultas são registrados no log Linux; falhas de abertura incluem o código de retorno e mensagem útil. Exporte por **Status e problemas > Copiar log para Downloads** se precisar compartilhar um diagnóstico. O sucesso do teste confirma que o Android aceitou a solicitação de abertura do aplicativo, não que XFCE/Ubuntu estejam funcionando; isso deve ser testado separadamente em **Abrir desktop**.

### Corrigida a instalação e detecção do APK Termux:X11 (1.0.113)

O APK Android pode estar instalado mesmo se `pm path com.termux.x11` não conseguir consultá-lo. A detecção agora é não conclusiva e não impede tentar abrir o desktop. O gerenciador reutiliza APK existente em Downloads, separa a instalação Android da do companion e explica quando `termux-open` foi bloqueado pelo `TermuxContentProvider`.

Instale o APK pelo aplicativo Arquivos do Android em Downloads para evitar alterar a configuração de segurança do Termux. A opção `allow-external-apps=true` em `~/.termux/termux.properties` permite `termux-open`, mas também amplia as capacidades de integração com aplicativos externos; o Manager não a habilita automaticamente. Após uma alteração manual, execute `termux-reload-settings`.

### Correção da instalação de desktops e exportação de logs (1.0.112)

Corrigida a geração das instruções de instalação de todos os desktops Linux suportados (XFCE, LXQt, LXDE, MATE, Openbox, i3, KDE e GNOME): aspas indevidamente escapadas faziam o gerenciador atualizar os repositórios sem executar a instalação do ambiente escolhido. O Manager preserva o código de falha do instalador e oferece **copiar o log para Downloads** em caso de erro.

O recurso também está em **Linux no celular > Ajuda e diagnóstico > Copiar log para Downloads** e **Interface gráfica (X11) > Suporte > Copiar log para Downloads**. Gera `termux-manager-linux-AAAAmmdd-HHMMSS-PID.log`, contendo o log Linux completo com códigos ANSI removidos e segredos comuns ocultados, sem alterar o log interno. O arquivo fica em armazenamento compartilhado: confira seu conteúdo antes de enviar.

### Linux com navegação por tarefas (1.0.111)

Em **Linux no celular**, agora são cinco opções: **Meus Linux** (abrir terminal, desktop ou atualizar sistema), **Instalar Linux**, **Interface gráfica (X11)**, **Backup e restauração** e **Ajuda e diagnóstico**. Os recursos de manutenção de uma distro (backup, informações, diagnósticos, sessões, reparação e remoção) ficam em **Meus Linux > [distribuição] > Manutenção e detalhes**.

O menu X11 orienta a preparação em duas etapas independentes: **componentes no Termux** (`x11-repo` e `termux-x11-nightly`) e **APK Android**, necessários para o desktop gráfico; depois é possível instalar o desktop na distribuição e abri-lo. O APK não é instalado silenciosamente. Há submenus para suporte, status e encerramento. O terminal da distro funciona sem X11. As verificações detalhadas de hardware e estado continuam sob demanda em Ajuda e diagnóstico.

### Comandos favoritos, recursos e modo econômico (1.0.110)

Em **Ambiente e ferramentas > Comandos favoritos** (ou **Configurações > Comandos favoritos**) é possível armazenar até 12 comandos Bash para uso pessoal. O Manager mostra o comando e exige confirmação antes de executá-lo; nunca executa favoritos sozinho. Os dados ficam em `~/Painel/.manager-favoritos`, com permissões privadas (`600`), sem incluir tokens ou senhas nos comandos.

Em **Ambiente e ferramentas > Recursos do aparelho**, o Manager mostra RAM disponível, carga média do sistema e espaço livre mediante consulta pontual; não inicia monitor residente. Em **Configurações > Comportamento**, o **modo econômico** reduz verificações automáticas de projetos e PIDs no menu principal. Isso preserva a consulta no menu de processos e não equivale a promessa de economia mensurável da bateria. A seção Termux:X11 oferece link direto para seu repositório oficial.

### Recuperação inteligente (1.0.109)

Em **Projetos > Restaurar backup**, o Manager lista arquivos `.tar.gz` em `Download/projetos/backups` e na pasta legada de backups, mostra o nome e o tamanho do conteúdo, e oferece restauração em `~/Painel/projetos` ou na raiz do Painel. A restauração usa **Python 3.8+** (no Termux: `pkg install python`), verifica entradas do TAR.GZ e espaço disponível, rejeita caminhos inseguros, links e dispositivos, extrai numa pasta temporária privada e só depois publica o projeto restaurado. Pastas existentes não são substituídas; pode-se escolher outro nome. O backup público não contém credenciais excluídas na geração: `.env`, chaves e dependências devem ser recuperadas ou reinstaladas separadamente.

Atualizações completas iniciadas pelo menu agora registram um marcador antes de substituir `modules/manager.sh`. Na inicialização seguinte, se o Android encerrou o processo durante a transação, o Manager tenta restaurar o backup anterior e reiniciar. Se o marcador ou backup estiver inválido, interrompe e informa o erro em vez de carregar módulos incompletos. A proteção exige que `manager.sh` e `.updates` permaneçam acessíveis. Este mecanismo não cobre atualizações manuais ou falhas físicas no armazenamento.

### Proteções de backups e processos (1.0.108)

**Backups de projetos:** o TAR.GZ colocado em Downloads omite arquivos de credenciais reconhecíveis, como `.env*`, PEM, P12, chaves de assinatura e `credentials.json`. O Manager informa quando a cópia é parcial. Se uma exclusão tiver solicitado backup, mas houver arquivos sensíveis que ficariam fora dele, a exclusão será **bloqueada** para evitar perda silenciosa. Faça uma cópia privada segura dos arquivos antes de removê-los. O filtro não detecta todos os possíveis segredos embutidos no código.

**Servidores:** uma porta responde como saudável somente quando for possível verificar que pertence ao PID do Manager ou a um processo filho. Quando o Android restringe acesso a `ss -p` e `/proc`, o vínculo pode não ser confirmado: o sistema mostra aviso, sem atribuir incorretamente portas de outros aplicativos. Um processo iniciado em versão anterior sem identidade verificável não é encerrado automaticamente, para evitar atingir um PID reutilizado.

**Diagnósticos:** URLs com credenciais embutidas e parâmetros comuns de token são sanitizados. **Revise o arquivo exportado antes de compartilhar**, pois nenhum filtro cobre todos os formatos possíveis de segredo.

### Primeira instalação: correção de `wget` e pacotes ignorados (1.0.107)

A consulta de pacotes por `apt-cache show` não gera mais falso negativo devido ao uso de `grep -q` com `pipefail`. Ao terminar a instalação inicial, se alguma ferramenta obrigatória continuar ausente (como `wget`), o assistente tenta instalar apenas essa ferramenta e verifica novamente seu executável. Se não conseguir, mantém a configuração pendente e informa o erro no log, sem registrar sucesso incorretamente.

### Primeira instalação: pós-checagem e exportação de log (1.0.106)

A verificação final das ferramentas agora comprova os comandos que realmente precisam funcionar no Termux, evitando falso aviso de configuração incompleta após uma instalação APT concluída com sucesso. Se ainda houver uma pendência real, o assistente mostra quais pacotes continuam ausentes. A tela de erro e o menu final da configuração também oferecem **Copiar log para Downloads**, criando `termux-setup.log` sanitizado para facilitar o envio do diagnóstico.

### Correção visual das caixas do terminal (1.0.105)

A interface passa a manter textos e bordas dentro das molduras mesmo quando há emojis de largura dupla ou quando a largura do terminal muda entre telas. A tabela de largura visual foi ampliada para todos os ícones usados pelo Manager, o menu recalcula o viewport antes de montar seu buffer e mensagens de status da atualização — como caminho do log e contagem para a próxima etapa — deixaram de aparecer soltas fora dos retângulos.

### Primeira instalação e pacotes iniciais corrigidos (1.0.104)

A primeira configuração agora trata corretamente um Termux ainda sem índices APT. O instalador sincroniza os repositórios antes de instalar ferramentas de bootstrap, isola a entrada do `pkg` quando executado por `curl ... | bash` e pode abrir o seletor oficial de repositórios quando necessário. No assistente, um cache vazio não faz mais pacotes serem classificados como inexistentes, e a etapa de ferramentas só é concluída depois que os pacotes iniciais são realmente verificados.

### Refatoração estrutural concluída do Linux (1.0.103)

A rodada principal de refatoração foi concluída. O antigo `linux.sh`, que ainda concentrava 1.320 linhas após a primeira etapa, agora atua apenas como carregador e distribui núcleo/arquitetura, distribuições, backup/restauração, diagnóstico, X11 e interface em módulos coesos. O cache de compatibilidade OCI passou a usar um identificador derivado da referência completa para evitar colisões entre imagens diferentes, e backups vazios/corrompidos com nome semelhante ao padrão do Manager deixaram de aparecer como restauráveis.

### Atualizador modular e validação reforçada (1.0.102)

O subsistema de atualização foi separado em módulos para rede/GitHub, integridade, instalação completa, atualização local e interface. Pacotes completos agora rejeitam manifestos parciais, divergência de versão, caminhos inseguros, ZIPs com travessia de diretório e links simbólicos. A estimativa de espaço considera o backup completo e diretórios auxiliares presentes no pacote são sincronizados sem deixar arquivos obsoletos.

### Central de Diagnóstico modular (1.0.101)

A Central de Diagnóstico foi dividida em módulos menores para captura de falhas, relatórios de projetos, exportação de suporte, diagnóstico Android e menus. A API pública continua sendo carregada por `diagnostics.sh`. A sanitização também cobre segredos entre aspas e blocos de chave privada, e os relatórios de teste de projeto voltaram a gerar corretamente as seções de resolução e estado dos processos.

## Recursos principais

- importação de pastas, arquivos e ZIPs;
- progresso de análise e cópia com contador de arquivos, velocidade e tempo;
- descoberta de projetos em `~/Painel` e `~/Painel/projetos`;
- detecção de frontend, backend, fullstack e monorepos;
- instalação de dependências com feedback visual e cache por assinatura;
- execução conjunta ou separada de componentes;
- detecção de portas pelo PID e processos filhos;
- registro de PIDs, portas e logs;
- Central de Diagnóstico com erros numerados do Manager, projetos e Termux;
- exportação sanitizada de um erro, log completo ou pacote de suporte;
- abertura automática do navegador;
- instalação e inventário de ferramentas do Termux;
- instalação e gerenciamento de distribuições Linux sem root com `proot-distro`;
- configuração assistida do Termux:X11 com múltiplos ambientes gráficos;
- diagnóstico de RAM, CPU e espaço com orientação de desempenho antes de usar Linux gráfico;
- configuração completa e limpeza segura do Fish Shell;
- atalhos globais `manager` e `mm`;
- atualização completa ou de módulo com backup e validação;
- manutenção, restauração e desinstalação segura;
- Centro de exclusão do Painel com vários níveis de remoção;
- renderização atômica dos menus, sem linhas “caindo” ou prompts sobrepostos.

## Primeira instalação

A instalação principal usa **um único comando**, depois de liberar o armazenamento do Android. Você não precisa baixar o ZIP manualmente, procurar o arquivo em Downloads nem executar comandos de extração.

### 1. Instale o Termux

Escolha **uma** das opções abaixo. Evite misturar o aplicativo principal e complementos do Termux vindos de fontes diferentes.

#### Opção A — Termux pelo GitHub

Página oficial:

**https://github.com/termux/termux-app/releases**

1. Abra a release estável mais recente.
2. Em **Assets**, baixe o APK compatível com seu Android/aparelho.
3. Instale o APK e abra o Termux.
4. Aguarde a preparação inicial terminar.

> Se usar Termux:API, Termux:Widget, Termux:Boot ou outros complementos, mantenha-os em uma origem compatível com a instalação principal.

#### Opção B — Termux pelo Google Play

Página oficial:

**https://play.google.com/store/apps/details?id=com.termux**

1. Instale o Termux pelo Google Play.
2. Abra o aplicativo e aguarde a preparação inicial terminar.
3. Depois execute o comando de instalação do Manager mostrado abaixo.

A edição do Google Play é mantida separadamente da edição GitHub/F-Droid e atualmente exige **Android 11 ou superior**. Alguns recursos e complementos podem ter diferenças. Informações dessa edição:

O instalador e a configuração inicial do Manager agora **detectam automaticamente** se o Termux em uso é da **Google Play** ou da linha **GitHub/F-Droid**, registram essa origem nos diagnósticos e adaptam a instalação das ferramentas recomendadas quando um pacote não existir naquela variante.

**https://github.com/termux-play-store**

### 2. Libere o acesso ao armazenamento

Antes de instalar o Manager pela primeira vez, abra o Termux e execute:

```bash
termux-setup-storage
```

Quando o Android solicitar, **autorize o acesso aos arquivos**. Esse passo cria os atalhos de armazenamento usados pelo Manager para Downloads, backups, diagnósticos e importação de projetos.

> O instalador também tenta executar `termux-setup-storage` automaticamente quando o acesso ainda não estiver disponível, mas a confirmação da permissão continua dependendo do usuário no Android.

### 3. Instale o Termux Manager com um comando

Se `curl` ainda não existir no seu Termux, execute uma vez:

```bash
pkg install -y curl
```

Depois copie e execute **esta linha inteira**:

```bash
curl -fsSL https://raw.githubusercontent.com/adriedsonlemoz/TermuxManager/main/install.sh | bash
```

Pronto. O instalador oficial faz automaticamente o restante:

1. verifica se o acesso ao armazenamento Android já foi liberado e chama `termux-setup-storage` quando necessário;
2. baixa a versão estável diretamente da branch `main` do repositório;
3. verifica se `curl`, `unzip` e as ferramentas básicas já existem e, se os índices APT ainda estiverem vazios, sincroniza primeiro os repositórios do Termux;
4. se a sincronização inicial precisar de outro mirror, pode abrir o seletor oficial `termux-change-repo` no terminal e tentar novamente;
5. se outro `apt`/`dpkg` estiver trabalhando, aguarda a liberação e mostra apenas um status controlado, sem repetir dezenas de linhas de `Waiting for cache lock`;
6. extrai o projeto e confere a versão declarada;
7. valida os hashes de todos os arquivos listados em `MANIFEST.json`;
8. valida `manager.sh` e os módulos com `bash -n`;
9. instala em `~/scripts/manager`, preservando backup da instalação anterior;
10. abre o Termux Manager.

Esse fluxo **não depende de uma GitHub Release publicada**. Enquanto `main` for o canal estável do projeto, o comando acima continua funcionando mesmo que a página de Releases esteja vazia.

> O comando recomendado não executa mais `pkg install curl` toda vez. Se o seu Termux realmente não tiver `curl`, instale-o uma única vez com `pkg install curl` e repita o comando.

Na primeira abertura, o Manager confirma o acesso ao armazenamento, atualiza o ambiente, instala as ferramentas recomendadas e configura o comando global `manager`.

A primeira configuração é retomável: cada etapa concluída é salva. Se uma instalação de pacote ficar sem novas mensagens, o Manager continua mostrando **tempo decorrido** e **tempo desde a última atividade** em vez de parecer congelado. `Ctrl+C` durante uma instalação monitorada não fecha mais o Manager; abre opções para **tentar novamente**, **pular o pacote** ou **retomar depois**. Ao abrir novamente, etapas já concluídas e pacotes já instalados não são repetidos.

Durante a instalação de ferramentas, o Manager também distingue pacotes **já instalados**, **ausentes** e **indisponíveis na variante atual do Termux**. Em uma instalação nova, porém, um cache APT ainda vazio é tratado como estado **não verificado**, e não como pacote inexistente. Depois da sincronização dos repositórios, a etapa só é salva como concluída quando as ferramentas correspondentes estiverem realmente funcionais no sistema. Se algo continuar ausente, o Manager mostra a lista exata e permite **Copiar log para Downloads** diretamente da tela de configuração incompleta. A mesma ação também fica disponível no menu final da configuração inicial.

Após a atualização inicial do Termux, o assistente agora mostra uma mensagem explícita informando que a etapa terminou e que a próxima fase continuará automaticamente. Isso evita a sensação de travamento naquela tela de resumo/log.

Depois da configuração inicial, basta abrir com:

```bash
manager
```

### Instalação manual (alternativa)

Use esta opção apenas se não quiser executar o instalador automático.

Abra o repositório:

**https://github.com/adriedsonlemoz/TermuxManager**

Use **Code → Download ZIP** para baixar a cópia atual da branch `main`. Depois extraia o conteúdo e execute `manager.sh`. Esse método é destinado a instalação manual; o comando automático acima continua sendo o método recomendado porque também valida o `MANIFEST.json` e cria backup de uma instalação anterior.

## Menu principal

O menu principal usa um modelo híbrido: as funções mais usadas ficam visíveis diretamente e apenas as opções realmente secundárias permanecem agrupadas. Isso evita a sensação de ficar procurando funções em vários submenus.

As opções principais são:

- **Gerenciar projetos:** abrir, testar e organizar os projetos detectados.
- **Em execução:** visualizar processos, serviços e portas ativos.
- **Importar projeto:** importar pasta, arquivo ou ZIP.
- **Linux no celular:** acesso direto a distribuições, PRoot e Termux:X11.
- **Ambiente e ferramentas:** instalação de ferramentas, manutenção do Termux e diagnóstico rápido.
- **Atualizar Manager:** atualização pela branch `main`, ZIP local ou módulo individual.
- **Configurações:** preferências e manutenção.
- **Ajuda e Sobre:** manual, versão e informações do desenvolvedor.

O cabeçalho também mostra um resumo curto da origem do Termux, quantidade de projetos e componentes ativos.

### Atualização direta pela branch `main`

Em **Manager → Atualizar Manager → Verificar no GitHub**, o Manager consulta diretamente a branch `main` do repositório oficial. Não é necessário criar Releases ou tags manualmente para esse fluxo.

Quando existe uma versão mais nova, o Manager:

1. compara a versão instalada com `MANIFEST.json` da `main`;
2. mostra a nova versão e o trecho correspondente do `CHANGELOG.md`;
3. pede confirmação antes de modificar qualquer arquivo;
4. baixa o ZIP da branch `main`;
5. valida todos os hashes declarados em `MANIFEST.json` e a sintaxe dos scripts;
6. cria backup da instalação atual;
7. sincroniza código, documentação, instalador e ferramentas auxiliares;
8. reinicia automaticamente na nova versão.

Se a consulta falhar ou a integridade do pacote não conferir, a instalação atual permanece intacta. A atualização por ZIP em Downloads continua disponível como alternativa.

Durante a consulta ao GitHub, o Manager agora mantém uma tela de atividade visível com estados como **Conectando ao GitHub**, **Carregando informações**, **Baixando atualização** e **Validando pacote**. Em conexões lentas, o tempo de espera continua sendo atualizado e o download mostra quantidade baixada e velocidade média aproximada, reduzindo a impressão de travamento.

Nenhuma função foi removida; apenas as funções relacionadas passaram a ficar agrupadas em submenus.

As descrições exibidas abaixo das opções de menu são resumidas automaticamente para telas móveis. Quando precisam ser reduzidas, o corte procura terminar em uma palavra completa para evitar textos quebrados no meio.

## Linux no celular

A interface de Linux prioriza uso leigo: distribuições instaladas são detectadas automaticamente e todas as ações principais usam **seleção numerada**, sem exigir que o usuário memorize aliases. A instalação oferece Ubuntu 24.04, Debian 12, Alpine, Fedora, openSUSE e Rocky Linux como atalhos, além de pesquisa opcional no Docker Hub. Referências OCI com versão, como `ubuntu:24.04`, são aceitas corretamente.

A área **Meus Linux** centraliza as distribuições já instaladas. A lista mostra nome do sistema, estado da sessão, saúde, arquitetura, tamanho atual e desktops detectados. Ao selecionar uma distro, o Manager abre um painel próprio com **Iniciar terminal**, **Desktop/X11**, **Atualizar sistema**, **Criar backup**, **Informações completas**, **Encerrar sessões**, **Reparar/reinstalar** e **Remover**.

O tamanho do rootfs é medido localmente e fica em cache curto para evitar percorrer milhares de arquivos a cada abertura do menu. A saúde também é testada com `/bin/sh`. Quando o teste falha, o Manager mostra uma causa curta na lista — por exemplo **Arquitetura**, **QEMU**, **Loader ausente**, **Ambiente PRoot** ou **Timeout** — e oferece um diagnóstico completo.

O diagnóstico diferencia **geração da CPU** (por exemplo ARMv8), **ABI do Android** (`armeabi-v7a`/`arm64-v8a`), **arquitetura usada pelo Termux** (`arm`/`aarch64`) e **32/64 bits do processo**. Assim, um aparelho pode possuir CPU ARMv8 e ainda executar um Termux 32-bit; nesse caso as distros nativas continuam seguindo a arquitetura real do Termux.

Mensagens conhecidas do PRoot são interpretadas em português na tela, com uma orientação curta do que verificar. Na exportação para Downloads, o relatório mantém primeiro a interpretação em português e preserva o erro técnico original em uma seção separada, para facilitar suporte e pesquisa.

A opção **Ambiente PRoot** diagnostica separadamente o motor usado pelas distros: verifica os comandos `proot`/`proot-distro`, versões instaladas, a pasta temporária interna do Termux e executa um teste com o shell nativo do próprio Termux. O reparo reinstala apenas esses componentes, invalida diagnósticos antigos e **não apaga as distribuições instaladas**.

A opção **Restaurar backup** procura arquivos compatíveis na pasta Downloads, mostra distro, tamanho e data antes da restauração e usa o `proot-distro restore`. Se a distro do backup já existir, o Manager oferece criar primeiro um novo backup de segurança da instalação atual. O arquivo original em Downloads é preservado.

O cache de saúde guarda também o motivo da falha. Caches antigos que só sabiam “Problema” são reavaliados automaticamente para produzir um diagnóstico explicativo. Na tentativa de iniciar uma distro com falha, o usuário pode **Ver diagnóstico**, **Testar novamente** ou **Reparar/reinstalar**.

Quando nenhuma distribuição estiver instalada, **Meus Linux** oferece abrir a instalação imediatamente, em vez de pedir um alias inexistente.

Em **Linux no celular**, acessível diretamente pelo menu principal, o Manager pode preparar uma distribuição Linux sem exigir root. O fluxo usa o `proot-distro` instalado pelo próprio Termux e consulta dinamicamente a lista de distribuições disponíveis, em vez de manter uma lista fixa no código.

O submenu permite:

- analisar RAM, CPU, arquitetura, Android e espaço livre antes da instalação;
- verificar **antes do download** se a imagem selecionada publica uma variante OCI compatível com a arquitetura do aparelho;
- forçar explicitamente a arquitetura escolhida no `proot-distro install` e executar um teste pós-instalação para evitar containers com `Exec format error`;
- classificar o aparelho em perfil **Básico**, **Intermediário** ou **Desktop**, sempre como estimativa orientativa;
- instalar `proot-distro` quando necessário;
- listar e instalar distribuições disponíveis;
- administrar cada distro por um painel próprio com tamanho, arquitetura, imagem de origem, estado, saúde, gerenciador de pacotes e desktops instalados;
- iniciar uma distribuição em modo terminal ou desktop;
- atualizar os pacotes do sistema usando APT, Pacman, APK, DNF ou Zypper;
- criar backup completo em Downloads pelo `proot-distro backup`;
- restaurar backups encontrados em Downloads pelo `proot-distro restore`, com confirmação antes de substituir uma distro existente;
- encerrar sessões ativas pelo `proot-distro kill`;
- diagnosticar e reparar o ambiente PRoot sem remover as distros instaladas;
- resetar/reinstalar ou remover uma distribuição com confirmações reforçadas;
- instalar `x11-repo` e `termux-x11-nightly`;
- baixar o APK oficial nightly do Termux:X11 para Downloads e abrir o instalador do Android;
- escolher entre **XFCE, LXQt, LXDE, MATE, Openbox, i3, KDE Plasma e GNOME**;
- classificar cada ambiente como muito leve, leve, médio, pesado ou muito pesado e destacar os mais indicados para o perfil do aparelho;
- instalar ambientes gráficos automaticamente em distribuições com `apt`, `pacman`, `apk`, `dnf` ou `zypper`, usando alternativas de pacote/grupo quando necessário;
- detectar os ambientes já instalados e evitar reinstalações desnecessárias;
- permitir **mais de um desktop na mesma distribuição** e escolher qual iniciar;
- iniciar o desktop selecionado usando Termux:X11 e `--shared-tmp`;
- tratar KDE Plasma e GNOME como opções avançadas, mostrando avisos de consumo e limitações do PRoot antes da instalação;
- encerrar a sessão X11 e consultar orientações para tela preta, cores trocadas ou lentidão.

O perfil de desempenho é conservador. Em aparelhos com pouca RAM ou pouco armazenamento, o Manager avisa que uma interface gráfica pode apresentar lentidão, encerramentos ou travamentos e recomenda priorizar o modo terminal. O usuário ainda pode continuar se quiser testar.

Antes de baixar uma distribuição do Docker Hub, o Manager também traduz a arquitetura do Termux para a arquitetura OCI correspondente (`aarch64 → arm64`, `arm → arm`, `x86_64 → amd64`, `i686 → 386` e `riscv64 → riscv64`) e consulta as arquiteturas publicadas para a tag escolhida. O resultado aparece como **Compatível**, **Não confirmado** ou **Incompatível nativamente**. Quando a imagem é confirmada como incompatível, o download é bloqueado para evitar desperdício de dados e armazenamento. Se a consulta não puder ser confirmada, o usuário ainda pode prosseguir e o `proot-distro` fará a validação durante a instalação. As consultas bem-sucedidas ficam em cache local por algumas horas para evitar chamadas repetidas.

O Termux:X11 possui duas partes: o pacote companion dentro do Termux e o aplicativo Android. O Manager instala automaticamente a parte do Termux e pode baixar o APK oficial, mas a confirmação final de instalação continua sendo feita pelo Android.

A recomendação do desktop acompanha o perfil calculado pelo Manager: aparelhos básicos priorizam LXDE/Openbox/i3; intermediários destacam XFCE/LXQt; aparelhos com mais margem recebem XFCE/LXQt/MATE como opções recomendadas e podem testar KDE Plasma. GNOME continua disponível como opção avançada, pois costuma depender mais de serviços de sistema que não existem normalmente em PRoot.

## Importação de projetos

A origem padrão da importação é sempre a própria pasta **Downloads**. O Manager não entra automaticamente em `Downloads/projetos`, então um ZIP recém-baixado aparece imediatamente na lista sem precisar ser movido antes.

O assistente permite:

- importar uma pasta inteira;
- selecionar arquivos soltos;
- extrair um ZIP;
- copiar o conteúdo sem manter a pasta externa;
- escolher `~/Painel` ou `~/Painel/projetos` como destino;
- substituir, ignorar, renomear ou confirmar conflitos individualmente.

Durante análise e cópia, o painel avança em tempo real:

```text
10/254 arquivos
20/254 arquivos
30/254 arquivos
...
254/254 arquivos
```

Ao terminar, mostra velocidade média, tempo total, arquivos copiados e pastas criadas. Depois de `ENTER`, retorna ao menu de importação sem encerrar o Manager.

Caminhos exibidos pela interface são abreviados a partir de `$HOME`: por exemplo, `/data/data/com.termux/files/home/Painel/.logs/app.log` aparece como `~/Painel/.logs/app.log`. Caminhos absolutos continuam sendo usados internamente pelos comandos.

## Execução, dependências e portas

O Manager detecta comandos de execução e gerenciadores de dependências. Em projetos fullstack, frontend e backend são tratados separadamente. O painel vivo de teste mantém largura fixa durante toda a execução; mensagens menores apenas recebem espaço interno e não deslocam a borda da caixa.

Antes de instalar dependências, o Manager verifica se elas já estão presentes. A assinatura dos manifests/lockfiles fica fora do projeto, em `~/.termux-manager/dependencies/`, para sobreviver a atualizações que substituam arquivos do projeto. Se ainda não houver assinatura, `node_modules`/`vendor` existentes são verificados antes de qualquer reinstalação.

A detecção de porta:

1. procura sockets associados ao PID e aos processos filhos;
2. valida a porta encontrada;
3. usa o log apenas como fallback estrito com `:porta` explícita;
4. grava a porta validada nos metadados do processo;
5. reutiliza o mesmo valor na página **Em execução**.

Isso evita interpretar números de IP, versões ou mensagens do log como portas.

## Ferramentas e ambientes de desenvolvimento

O menu **Instalar ferramentas** foi organizado por ambientes: **Web, Python, Java, Go, Rust, Ruby, PHP, Compilação, Bancos de dados, Arquivos e Terminal**. A tela principal mostra se cada ambiente está completo, incompleto ou ausente.

A opção **Recomendado** analisa os projetos existentes em `~/Painel` procurando `package.json`, `requirements.txt`, `pyproject.toml`, `composer.json`, `go.mod`, `Cargo.toml`, `pom.xml` e arquivos Gradle. Depois oferece instalar **somente as ferramentas que realmente estão faltando**.

Instalações com vários pacotes são tentadas primeiro **em lote**, reduzindo chamadas repetidas ao `apt/pkg`; se o lote falhar, o Manager faz fallback individual para identificar o pacote problemático. Instalações automáticas solicitadas pelos módulos de projeto/GitHub também usam o mesmo instalador robusto.

Em **Instalar ferramentas → Ferramentas instaladas**, o Manager abre um painel dos principais ambientes de desenvolvimento. Cada ambiente mostra se está **completo, incompleto ou ausente**, quais comandos faltam e as versões reais dos componentes detectados. É possível entrar no ambiente e instalar somente o que estiver faltando. A lista completa de ferramentas continua disponível em uma opção separada.

A detecção prioriza o **comando realmente funcional** antes de considerar um pacote ausente. Isso evita pedir novamente `nodejs`, Java, Rust ou outras ferramentas quando uma versão equivalente já fornece os comandos necessários.

Categorias:

- linguagens: Python, PHP, Ruby, Go, Rust e outras;
- web: Node.js, npm, pnpm, Yarn, Composer e Git;
- Java: Java, Javac, Gradle e Maven;
- shells e editores: Fish, Bash, Zsh, Nano, Micro, Vim e Neovim;
- compilação: Clang, GCC, Make, CMake e pkg-config;
- bancos: SQLite, PostgreSQL, MariaDB, Redis e Mongo Shell;
- utilitários: curl, wget, rsync, ZIP, jq, OpenSSL, SSH e tmux.

Ferramentas ausentes ficam ocultas.

## Fish Shell

Em **Configurações → Fish Shell**, é possível:

- instalar o Fish;
- defini-lo como shell padrão;
- ativar autosugestões e completações;
- configurar prompt, Git, histórico e atalhos;
- ocultar os banners do Termux e do Fish;
- mostrar mensagem de boas-vindas personalizada;
- mostrar o tempo total da sessão ao sair;
- restaurar o Bash;
- limpar somente as configurações do shell.

A limpeza do Fish não remove Python, Node.js, PHP, Git, projetos ou outros pacotes.

A instalação do Fish usa o mesmo instalador monitorado dos demais ambientes de desenvolvimento, com espera de locks do `apt`/`dpkg`, recuperação e diagnóstico de falhas.


## Interface responsiva

A interface usa a largura real disponível no terminal. As caixas deixam apenas uma pequena margem lateral de segurança e se adaptam a celulares, rotação de tela, tablets e terminais maiores. Painéis de operações longas congelam a largura durante a execução para impedir que a borda direita varie conforme o tamanho das mensagens.

## Atalhos globais

O comando principal é instalado em:

```text
$PREFIX/bin/manager
```

Ele funciona em Bash e Fish. O submenu **Atalhos do Manager** permite instalar, reparar, verificar e remover `manager` e `mm`.

## Centro de exclusão do Painel

Disponível em:

```text
Gerenciar projetos → Limpeza do Painel
Configurações → Limpeza do Painel
```

Permite:

1. excluir um projeto individual;
2. limpar o conteúdo de `~/Painel/projetos`, preservando a pasta;
3. excluir e recriar `~/Painel/projetos` vazia;
4. excluir todo o `~/Painel`.

Antes de ações coletivas, o Manager mostra quantidade, tamanho e conteúdo afetado, oferece backup opcional e exige confirmação proporcional ao risco.

Backups de projetos são exportados para `Download/projetos/backups`. O Manager ignora dependências e artefatos regeneráveis como `node_modules`, `.git`, caches, `dist`, `build`, ambientes virtuais e diretórios equivalentes. A cópia temporária é removida do Termux somente depois que o arquivo em Downloads é validado por SHA-256. Arquivos de credenciais conhecidos são ignorados em backups públicos; esse backup não substitui uma cópia privada de suas chaves.

## Atualizações

O padrão oficial é:

```text
Versão: 1.0.129
Tag: v1.0.129
Release: Manager 1.0.129
Pacote único: TermuxManager-v1.0.130.zip
Integridade: MANIFEST.json dentro do próprio pacote
```

### Transição da versão 1.0.44

A versão 1.0.44 possui uma falha no próprio processo de atualização: ao chegar em **Etapa 5 de 5**, a saída pode ficar presa no buffer da interface. O pacote é aplicado, mas o Manager reiniciado fica invisível no terminal.

Para instalar a 1.0.45 uma única vez, feche a execução presa com `Ctrl+C` e atualize diretamente da pasta Downloads:

```bash
unzip -o ~/storage/downloads/manager-v1.0.45.zip -d ~/scripts/manager
manager
```

A partir da 1.0.45, as próximas atualizações podem voltar a ser feitas normalmente pelo menu interno.

Na atualização completa, o Manager:

1. identifica e valida o ZIP;
2. mostra versão atual e nova;
3. informa tamanho compactado, tamanho extraído e quantidade de arquivos;
4. verifica espaço livre e estimativa do backup;
5. cria backup da instalação;
6. aplica a atualização em uma tela fixa;
7. registra a atualização sem recriar atalhos desnecessariamente;
8. restaura a saída, o cursor e o estado do terminal;
9. libera o bloqueio da instância antes do reinício;
10. reinicia a nova versão com a saída visível no terminal;
11. exibe uma confirmação pós-atualização, uma única vez, provando que a nova versão está ativa.

## Manutenção do Manager

Em **Configurações → Manutenção do Manager**:

- **Restaurar instalação:** limpa preferências, cache, logs e estado interno, preservando projetos e backups.
- **Desinstalar Manager:** remove o aplicativo e seus atalhos com confirmação reforçada, preservando os projetos do Painel.

## Estrutura principal

```text
~/scripts/manager/
├── manager.sh
├── modules/
│   ├── app.sh
│   ├── config.sh
│   ├── core.sh
│   ├── diagnostics.sh
│   ├── help.sh
│   ├── import.sh
│   ├── import_copy.sh
│   ├── import_wizard.sh
│   ├── linux.sh
│   ├── linux_core.sh
│   ├── linux_distros.sh
│   ├── linux_backup.sh
│   ├── linux_diagnostics.sh
│   ├── linux_x11.sh
│   ├── linux_ui.sh
│   ├── projects.sh
│   ├── projects_github.sh
│   ├── projects_github_core.sh
│   ├── projects_github_project.sh
│   ├── projects_git.sh
│   ├── projects_storage.sh
│   ├── runtime.sh
│   ├── runtime_detect.sh
│   ├── runtime_dependencies.sh
│   ├── runtime_processes.sh
│   ├── settings.sh
│   ├── settings_fish.sh
│   ├── settings_shortcuts.sh
│   ├── settings_maintenance.sh
│   ├── termux.sh
│   ├── termux_packages.sh
│   ├── termux_packages_core.sh
│   ├── termux_packages_ui.sh
│   ├── termux_packages_monitor.sh
│   ├── termux_packages_actions.sh
│   ├── termux_setup.sh
│   ├── termux_tools.sh
│   ├── ui.sh
│   └── updater.sh
├── tools/build-release.sh
├── README.md
├── CHANGELOG.md
├── RELEASE_STANDARD.md
└── MANIFEST.json
```

## Teste rápido e reimportação

Para ciclos frequentes de copiar um pacote completo e testar novamente, o Manager otimiza o caminho crítico:

- ao **substituir** um projeto, `node_modules` é preservado quando `package.json`/lockfiles continuam iguais;
- dependências já validadas usam cache de integridade leve antes de executar verificações profundas;
- instalações novas priorizam o cache local do npm e desativam audit/fund/progresso durante a preparação;
- no teste do **sistema completo**, backend e frontend sobem em paralelo depois da preparação das dependências;
- a disponibilidade é detectada em intervalos curtos, sem a antiga espera fixa de 1 segundo por processo.

Se os manifestos de dependência mudarem, o Manager não reutiliza `node_modules` antigo e volta automaticamente ao fluxo seguro de instalação/reparo.

## Central de Diagnóstico

Abra **Configurações → Central de Diagnóstico**. A área separa os registros em:

A central também possui **Exportar todos os relatórios**, que cria em Downloads uma pasta datada com `manager/`, `projetos/` e `termux/`, além do **Pacote completo de suporte**, que compacta as mesmas categorias.

- **Manager:** falhas internas capturadas, comandos, arquivo, linha e código de saída;
- **Projetos:** logs de frontend, backend e outros processos iniciados pelo Manager;
- **Termux:** operações do `pkg`/`dpkg`, ambiente, armazenamento e diagnóstico atual.

Dentro de cada arquivo, os padrões de erro aparecem numerados. É possível selecionar um número e copiar somente aquele erro com linhas de contexto para Downloads, ou exportar o log completo.

A opção **Pacote completo de suporte** cria um arquivo com pastas separadas:

```text
manager/
projetos/
termux/
```

Antes de exportar, o Manager remove valores comuns de senhas, tokens, chaves, URLs de banco com credenciais e cabeçalhos de autorização. O arquivo original não é alterado. Ainda assim, revise o relatório antes de compartilhar.

A central cobre os registros do ambiente Termux. Logs internos do Android, como `logcat`, dependem de permissões externas e não são coletados.

Locais principais:

```text
~/Painel/.logs
~/Painel/.logs/diagnostics
~/scripts/manager/logs
~/Painel/projetos
Download/projetos/backups
```

## Solução rápida de problemas

### `manager: command not found`

Abra **Configurações → Atalhos do Manager → Instalar ou reparar atalho**.

### Projeto não inicia

Confira:

- `backend/.env` e `frontend/.env`;
- dependências;
- logs em `~/Painel/.logs`;
- portas exibidas em **Em execução**.

### Downloads não aparece

```bash
termux-setup-storage
```

Depois use **Ambiente Termux → Armazenamento**.

### Atualização não aplicada

Abra **Atualizar Manager → Última atualização** e confira versão, pacote, hash, backup e status.

## Build de release

```bash
cd ~/scripts/manager
bash tools/build-release.sh
```

Os arquivos são gerados em `dist/`.

## Licença

Projeto de uso pessoal e educacional. Defina uma licença explícita no repositório antes de aceitar contribuições externas.


## Saúde de processos — 1.0.48

A existência do PID, sozinha, não significa mais que o servidor está saudável. O Manager revalida a porta antes de exibir o estado verde. Processos como `node --watch` que permanecem vivos após o servidor interno falhar aparecem em amarelo, e o fluxo de sistema completo não inicia o frontend enquanto o backend estiver indisponível.

## Painel de projetos

Em **Gerenciar projetos**, cada projeto mostra um resumo rápido da stack, estado do Git e componentes ativos. Ao abrir um projeto, o Manager exibe também tamanho e pasta antes das ações.

A área **Git / GitHub** centraliza o status do repositório, envio de alterações, branches e a opção **Atualizar do remoto**. A atualização usa somente avanço rápido (`fast-forward`): se houver arquivos locais alterados ou histórico divergente, o Manager não sobrescreve nem cria merge automaticamente.

## Central GitHub

Em **Configurações → GitHub**, a conta é configurada uma única vez para todos os projetos. A Central GitHub permite conectar/desconectar a conta pelo `gh`, revisar o usuário atual, definir nome e e-mail globais do Git, escolher a branch padrão, testar a conexão e abrir **Meus repositórios**.

A conta é global, mas o vínculo do repositório é **individual por projeto**. Cada projeto registra seu próprio `remote`, repositório e branch padrão. Antes de atualizar ou enviar, o Manager compara o vínculo salvo com o remote Git atual; se apontarem para repositórios diferentes, a operação é bloqueada para evitar publicar um projeto no repositório de outro. Quando um projeto possui vários remotes, o vínculo GitHub salvo pelo Manager tem prioridade sobre `origin`, permitindo manter `origin` em outro provedor sem atualizar, enviar ou remover o remoto errado.

Dentro de **Gerenciar projetos → projeto → Git / GitHub**, estão disponíveis **Status do Git**, **Atualizar do remoto**, **Enviar para GitHub**, **Branches**, **Repositório vinculado**, **Histórico de commits** e **Configurar projeto**. O submenu de branches permite listar branches locais/remotas, criar, trocar, atualizar e publicar a branch atual.

## Envio simplificado para GitHub

Ao escolher **Enviar para GitHub**, o Manager mostra antes do commit o projeto selecionado, repositório de destino, branch, total de arquivos novos/modificados/removidos e uma prévia das alterações. O envio ocorre somente após confirmação e somente para o repositório vinculado àquele projeto.

Na primeira publicação, o Manager pode instalar `git`/`gh`, conduzir o login oficial, criar um `.gitignore` de proteção, inicializar o Git e criar ou vincular um repositório existente. A autenticação é reutilizada pelos demais projetos, mas cada um mantém seu destino separado.

O Manager **não usa `push --force` automaticamente**. Se o remoto tiver histórico diferente, o envio é interrompido e o usuário recebe orientação para sincronizar primeiro. Arquivos sensíveis comuns (`.env`, `.npmrc`, chaves privadas, credenciais) são ignorados por padrão; se algum deles já estiver rastreado pelo Git, o envio é bloqueado até ser removido do índice. Quando o projeto é a raiz `~/Painel`, estados internos do Manager e `~/Painel/projetos` também ficam fora da publicação.


### Reparo automático de dependências

No teste de projetos Node, o Manager valida `node_modules` antes de reutilizar o cache. Se detectar uma instalação inconsistente ou se o servidor falhar com `MODULE_NOT_FOUND`, a assinatura é invalidada e o Manager tenta um reparo limpo uma única vez. Projetos com lockfile usam `npm ci`; sem lockfile, `node_modules` é recriado com `npm install`.

### Central de execução (v1.0.130)

No menu principal, escolha **2. Central de execução** para ver projetos monitorados e o estado independente das ferramentas locais. Atalhos: `P` seleciona projetos PHP; `N` seleciona projetos Node; `D` verifica/inicia MariaDB; `M` inicia ou encerra o webserver phpMyAdmin; `W` abre o phpMyAdmin local; `R` atualiza a tela. Se houver processos gerenciados, escolha seu número para ver logs e parar individualmente. `A` encerra somente os processos gerenciados de projetos, após confirmação, não os bancos. PHP e Node são executáveis, não servidores sempre ativos.

# Catálogo separado das dependências do Termux.
# Sugestões: a disponibilidade deve ser confirmada NA distribuição via repositório.
# G=GUI/X11, T=terminal; L=leve, M=médio, H=pesado.
linux_catalog_categorias() {
    cat <<'CAT_EOF'
browsers|🌐|Navegadores gráficos|NetSurf, Falkon, GNOME Web
textweb|⌨️|Navegadores no terminal|W3M, Lynx, Links, ELinks
filegui|📁|Arquivos e pastas|PCManFM, Thunar, Caja, Ranger
office|📝|Escritório|LibreOffice, AbiWord, Gnumeric
pdf|📄|PDF e documentos|Evince, MuPDF, Zathura, Okular
audio|🎵|Música e áudio|Audacious, CMUS, SoX
video|🎬|Vídeo e conversão|MPV, VLC, FFmpeg
graphics|🎨|Imagens e desenho|GIMP, Inkscape, Krita, Feh
ide|💻|Editores gráficos e IDEs|Geany, Mousepad, Kate, Meld
dev|🧑‍💻|Desenvolvimento|Python, Node.js, GCC, Rust, Go
editors|✍️|Editores de terminal|Vim, Nano, Neovim, Micro
rede|📡|Rede e acesso remoto|SSH, Nmap, DNS, Remmina
monitor|📊|Monitoramento|Htop, Btop, Ncdu, Procps
arquivos|🗜️|Compactação e backup|7-Zip, Rsync, Tar, Zstd
sessoes|🖥️|Sessões e produtividade|Tmux, Screen, Fzf, Ripgrep
web|🌍|Servidores web|Nginx, Apache, PHP, Lighttpd
database|🗄️|Bancos de dados|SQLite, clientes SQL, Redis
games|🎮|Jogos e passatempos|XBoard, GNOME Mines, LTris
science|🔭|Ciência e matemática|Gnuplot, Octave, Qalculate
desktop|🎛️|Aparência e acessórios|LXAppearance, fontes, temas
utils|🧰|Utilitários de terminal|JQ, Tree, Less, File
CAT_EOF
}
linux_catalog_listar() {
    case "$1" in
      browsers) cat <<'CAT_EOF'
netsurf-gtk|NetSurf|G|L|Leve; JavaScript moderno limitado
epiphany-browser|GNOME Web|G|H|WebKitGTK; exige mais RAM
falkon|Falkon|G|H|Qt WebEngine; consumo elevado
qutebrowser|Qutebrowser|G|H|Navegação por teclado; Qt WebEngine
CAT_EOF
         ;;
      textweb) cat <<'CAT_EOF'
w3m|W3M|T|L|Navegação diretamente no terminal
lynx|Lynx|T|L|Navegador textual
links|Links|T|L|Navegador textual
elinks|ELinks|T|L|Navegador textual com menus
CAT_EOF
         ;;
      filegui) cat <<'CAT_EOF'
pcmanfm|PCManFM|G|L|Gerenciador de arquivos do LXDE
thunar|Thunar|G|L|Gerenciador de arquivos do XFCE
caja|Caja|G|M|Gerenciador do MATE
nemo|Nemo|G|M|Gerenciador de arquivos Cinnamon
doublecmd-gtk|Double Commander GTK|G|M|Dois painéis; confirme repositório
ranger|Ranger|T|L|Arquivos no terminal
mc|Midnight Commander|T|L|Gerenciador em dois painéis
nnn|nnn|T|L|Gerenciador de arquivos compacto
CAT_EOF
         ;;
      office) cat <<'CAT_EOF'
abiword|AbiWord|G|L|Editor de textos leve
gnumeric|Gnumeric|G|L|Planilhas leves
libreoffice-writer|LibreOffice Writer|G|H|Editor de documentos
libreoffice-calc|LibreOffice Calc|G|H|Planilhas avançadas
libreoffice-impress|LibreOffice Impress|G|H|Apresentações
leafpad|Leafpad|G|L|Editor de texto simples
CAT_EOF
         ;;
      pdf) cat <<'CAT_EOF'
evince|Evince|G|M|Visualizador de documentos
atril|Atril|G|M|Visualizador PDF do MATE
mupdf|MuPDF|G|L|Visualizador PDF compacto
zathura|Zathura|G|L|Visualizador controlado por teclado
xpdf|Xpdf|G|L|Visualizador PDF tradicional
okular|Okular|G|H|Visualizador de documentos KDE
poppler-utils|Poppler Utils|T|L|PDF para texto e ferramentas CLI
CAT_EOF
         ;;
      audio) cat <<'CAT_EOF'
audacious|Audacious|G|L|Player de áudio relativamente leve
cmus|CMUS|T|L|Player musical de terminal
moc|Music On Console|T|L|Player musical de terminal
sox|SoX|T|L|Processamento de áudio
flac|FLAC|T|L|Codec e utilitários FLAC
lame|LAME|T|L|Codificador MP3
rhythmbox|Rhythmbox|G|H|Biblioteca musical GNOME
CAT_EOF
         ;;
      video) cat <<'CAT_EOF'
mpv|MPV|G|M|Player de vídeo; X11 para janela
vlc|VLC|G|H|Player multimídia completo
parole|Parole|G|L|Player de vídeo do XFCE
ffmpeg|FFmpeg|T|M|Converter e processar áudio/vídeo
mediainfo|MediaInfo|T|L|Detalhes técnicos de mídia
yt-dlp|yt-dlp|T|L|Baixar mídia onde permitido
CAT_EOF
         ;;
      graphics) cat <<'CAT_EOF'
gimp|GIMP|G|H|Editor de imagens
inkscape|Inkscape|G|H|Desenho vetorial
pinta|Pinta|G|M|Editor simples de imagens
krita|Krita|G|H|Pintura digital; exige RAM
imagemagick|ImageMagick|T|M|Conversão e manipulação de imagens
feh|Feh|G|L|Visualizador leve de imagens
ristretto|Ristretto|G|L|Visualizador de imagens do XFCE
sxiv|sxiv|G|L|Visualizador minimalista
CAT_EOF
         ;;
      ide) cat <<'CAT_EOF'
geany|Geany|G|L|Editor e IDE leve
mousepad|Mousepad|G|L|Editor gráfico do XFCE
kate|Kate|G|H|Editor de código KDE
meld|Meld|G|M|Comparação visual de arquivos
gitg|Gitg|G|M|Interface Git gráfica
sqlitebrowser|DB Browser for SQLite|G|M|Editor gráfico SQLite
emacs-gtk|Emacs GTK|G|H|Editor extensível com GUI
CAT_EOF
         ;;
      dev) cat <<'CAT_EOF'
git|Git|T|L|Controle de versões
python3|Python 3|T|L|Linguagem Python
python3-pip|Pip|T|L|Gerenciador de pacotes Python
nodejs|Node.js|T|M|JavaScript fora do navegador
npm|NPM|T|M|Pacotes Node.js
build-essential|Build Essential|T|H|Compiladores e ferramentas no Debian
gcc|GCC|T|M|Compilador C
clang|Clang|T|M|Compilador C/C++
cmake|CMake|T|M|Gerador de builds
golang-go|Go|T|H|Compilador Go; nome pode variar
rustc|Rust|T|H|Compilador Rust
cargo|Cargo|T|H|Gerenciador Rust
gdb|GDB|T|M|Depurador; PRoot pode limitar ptrace
openjdk-17-jdk|Java JDK 17|T|H|Java para desenvolvimento
make|Make|T|L|Automação de builds
CAT_EOF
         ;;
      editors) cat <<'CAT_EOF'
nano|Nano|T|L|Editor simples
vim|Vim|T|L|Editor clássico
neovim|Neovim|T|M|Editor moderno
micro|Micro|T|L|Editor de terminal
emacs-nox|Emacs no terminal|T|M|Emacs sem interface X11
CAT_EOF
         ;;
      rede) cat <<'CAT_EOF'
curl|Curl|T|L|Cliente HTTP e ferramentas de rede
wget|Wget|T|L|Downloader por terminal
openssh-client|OpenSSH Client|T|L|Cliente SSH
openssh-server|OpenSSH Server|T|M|Servidor: configurar localhost com cuidado
nmap|Nmap|T|M|Diagnóstico de rede; recursos limitados em PRoot
dnsutils|DNS Utils|T|L|Dig e nslookup
iproute2|iproute2|T|L|Inspeção de rede limitada por Android
net-tools|Net-tools|T|L|ifconfig e netstat
traceroute|Traceroute|T|L|Rotas; recursos do Android podem restringir
socat|Socat|T|L|Encaminhamento de conexões
remmina|Remmina|G|H|Cliente gráfico RDP/VNC/SSH
tigervnc-viewer|TigerVNC Viewer|G|M|Visualizador VNC
x11vnc|x11vnc|T|M|Compartilhar display X11; proteger acesso
CAT_EOF
         ;;
      monitor) cat <<'CAT_EOF'
htop|Htop|T|L|Monitor de processos
btop|Btop|T|M|Monitor de recursos
ncdu|Ncdu|T|L|Análise de espaço
procps|Procps|T|L|ps, top e outros utilitários
lsof|Lsof|T|L|Arquivos abertos; PRoot pode restringir
sysstat|Sysstat|T|L|Ferramentas de desempenho
inxi|Inxi|T|L|Informações do sistema
CAT_EOF
         ;;
      arquivos) cat <<'CAT_EOF'
zip|Zip|T|L|Compactar ZIP
unzip|Unzip|T|L|Extrair ZIP
p7zip-full|7-Zip CLI|T|L|Pacote pode variar conforme distro
tar|Tar|T|L|Arquivamento
rsync|Rsync|T|L|Sincronização de arquivos
zstd|Zstandard|T|L|Compressão rápida
xz-utils|XZ Utils|T|L|Compressão XZ
unrar-free|Unrar-free|T|L|Extrair RAR compatível
CAT_EOF
         ;;
      sessoes) cat <<'CAT_EOF'
tmux|Tmux|T|L|Sessões em terminal
screen|GNU Screen|T|L|Sessões persistentes
fzf|Fzf|T|L|Busca interativa
ripgrep|Ripgrep|T|L|Pesquisar texto rapidamente
fd-find|fd-find|T|L|Buscar arquivos
bat|Bat|T|L|Visualizar arquivos com cores
parallel|GNU Parallel|T|L|Execução de tarefas
entr|entr|T|L|Executar comandos após mudanças
CAT_EOF
         ;;
      web) cat <<'CAT_EOF'
nginx|Nginx|T|M|Servidor web; iniciar manualmente
apache2|Apache|T|H|Servidor web; sem systemd
lighttpd|Lighttpd|T|L|Servidor HTTP leve
php-cli|PHP CLI|T|M|PHP no terminal
php-fpm|PHP-FPM|T|M|Processador PHP; processo separado
python3|Python HTTP|T|L|Servidor simples via Python
certbot|Certbot|T|M|TLS; acesso a portas pode limitar
CAT_EOF
         ;;
      database) cat <<'CAT_EOF'
sqlite3|SQLite CLI|T|L|Banco SQL local
sqlitebrowser|DB Browser SQLite|G|M|Gerenciador gráfico SQLite
postgresql-client|PostgreSQL Client|T|M|Cliente PostgreSQL
mariadb-client|MariaDB Client|T|M|Cliente MySQL/MariaDB
redis-tools|Redis CLI|T|L|Cliente Redis
postgresql|PostgreSQL Server|T|H|Servidor exige inicialização manual
redis-server|Redis Server|T|M|Servidor manual; não usar init
CAT_EOF
         ;;
      games) cat <<'CAT_EOF'
gnuchess|GNU Chess|T|L|Xadrez pelo terminal
xboard|XBoard|G|L|Xadrez com interface
aisleriot|AisleRiot|G|M|Jogos de cartas
gnome-mines|GNOME Mines|G|M|Campo minado
gnome-sudoku|GNOME Sudoku|G|M|Sudoku
ltris|LTris|G|L|Jogo de blocos
wesnoth|Wesnoth|G|H|Estratégia por turnos; grande
CAT_EOF
         ;;
      science) cat <<'CAT_EOF'
gnuplot|Gnuplot|T|M|Gráficos científicos
octave|GNU Octave|T|H|Computação numérica; pesado
maxima|Maxima|T|M|Álgebra simbólica
qalculate-gtk|Qalculate GTK|G|M|Calculadora científica
units|GNU Units|T|L|Conversão de unidades
bc|bc|T|L|Calculadora CLI
stellarium|Stellarium|G|H|Astronomia; OpenGL pode falhar no PRoot
CAT_EOF
         ;;
      desktop) cat <<'CAT_EOF'
lxappearance|LXAppearance|G|L|Aparência do LXDE
qt5ct|Qt5ct|G|L|Aparência de aplicativos Qt5
arc-theme|Arc Theme|G|L|Tema GTK
papirus-icon-theme|Papirus Icons|G|M|Tema de ícones
fonts-noto|Noto Fonts|T|M|Fontes Unicode
fonts-noto-color-emoji|Noto Emoji|T|M|Emoji colorido
fonts-dejavu|DejaVu Fonts|T|L|Fontes de uso geral
xterm|XTerm|G|L|Terminal X11
lxterminal|LXTerminal|G|L|Terminal gráfico LXDE
xfce4-terminal|XFCE Terminal|G|L|Terminal gráfico XFCE
xarchiver|Xarchiver|G|L|Compactador gráfico
onboard|Onboard|G|M|Teclado virtual para X11
CAT_EOF
         ;;
      utils) cat <<'CAT_EOF'
jq|JQ|T|L|Processar JSON
tree|Tree|T|L|Exibir árvores de diretórios
less|Less|T|L|Paginação de textos
file|File|T|L|Identificar arquivos
dos2unix|Dos2unix|T|L|Converter fim de linha
htop|Htop|T|L|Ver processos
ncdu|Ncdu|T|L|Ver espaço por pasta
CAT_EOF
         ;;
      *) return 1 ;;
    esac
}

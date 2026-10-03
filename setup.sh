#!/bin/bash
# GNOME Setup - Backup y restauración de configuración
# Compatible con Arch (y derivados como CachyOS) y Fedora
set -e

BACKUP_DIR="$HOME/.gnome-setup-backup"

# Detectar distro
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID ${ID_LIKE}" in
            *arch*|*cachyos*|*manjaro*|*endeavouros*) echo "arch" ;;
            *fedora*|*rhel*|*nobara*) echo "fedora" ;;
            *) echo "unknown" ;;
        esac
    fi
}

DISTRO=$(detect_distro)
echo "Distro detectada: $DISTRO"

install_packages() {
    case "$DISTRO" in
        arch)
            sudo pacman -S --needed gnome-shell gnome-control-center dconf
            ;;
        fedora)
            sudo dnf install -y gnome-shell gnome-control-center dconf
            ;;
        *)
            echo "Distro no soportada aún"
            ;;
    esac
}

backup() {
    mkdir -p "$BACKUP_DIR"
    dconf dump / > "$BACKUP_DIR/dconf-settings.ini"
    echo "Backup guardado en $BACKUP_DIR"
}

restore() {
    if [ ! -f "$BACKUP_DIR/dconf-settings.ini" ]; then
        echo "No hay backup en $BACKUP_DIR"
        exit 1
    fi
    dconf load / < "$BACKUP_DIR/dconf-settings.ini"
    echo "Configuración restaurada. Reinicia sesión."
}

log() { echo -e "\n▶ $*"; }

clear_schema() {
    gsettings list-recursively "$1" 2>/dev/null | awk '{print $2}' | while read -r key; do
        [ -n "$key" ] && gsettings reset "$1" "$key" 2>/dev/null
    done
}

# -----------------------------------------------------------------------------
# Atajos (limpieza + propios)
# -----------------------------------------------------------------------------
step_reset_shortcuts() {
  log "3 · Limpieza base de atajos"
  gsettings reset-recursively org.gnome.settings-daemon.plugins.media-keys
  dconf reset -f /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/
  dconf reset -f /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/
  clear_schema org.gnome.desktop.wm.keybindings
  clear_schema org.gnome.shell.keybindings
  clear_schema org.gnome.mutter.keybindings
  clear_schema org.gnome.mutter.wayland.keybindings
}

mk_custom() { # n nombre comando tecla
  local base="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"
  local path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom$1/"
  gsettings set "$base:$path" name "$2"
  gsettings set "$base:$path" command "$3"
  gsettings set "$base:$path" binding "$4"
}

# Resolver app predeterminada del sistema a comando ejecutable
default_browser() {
    local desktop
    desktop=$(xdg-settings get default-web-browser 2>/dev/null)
    case "$desktop" in
        *firefox*) echo "firefox --new-window" ;;
        *chromium*|*chrome*) echo "chromium --new-window || google-chrome-stable --new-window" ;;
        *brave*) echo "brave-browser --new-window" ;;
        *edge*) echo "microsoft-edge --new-window" ;;
        *) [ -n "$desktop" ] && echo "${desktop%.desktop}" || echo "firefox" ;;
    esac
}

default_filemanager() {
    local desktop
    desktop=$(xdg-mime query default inode/directory 2>/dev/null)
    case "$desktop" in
        *nautilus*|*org.gnome.Nautilus*) echo "nautilus --new-window" ;;
        *dolphin*) echo "dolphin" ;;
        *thunar*) echo "thunar" ;;
        *nemo*) echo "nemo" ;;
        *pcmanfm*) echo "pcmanfm" ;;
        *) [ -n "$desktop" ] && echo "${desktop%.desktop}" || echo "nautilus" ;;
    esac
}

default_terminal() {
    local t
    t=$(gsettings get org.gnome.desktop.default-applications.terminal exec 2>/dev/null | tr -d "'")
    if [ -n "$t" ] && [ "$t" != "null" ]; then
        echo "$t"
        return
    fi
    for t in xdg-terminal-exec ghostty ptyxis kgx gnome-terminal kitty alacritty foot konsole xfce4-terminal; do
        if command -v "$t" &>/dev/null; then
            echo "$t"
            return
        fi
    done
    echo "gnome-terminal"
}

step_shortcuts() {
  log "4 · Atajos propios"
  local WM="org.gnome.desktop.wm.keybindings" i d D
  local TERM_CMD BROWSER_CMD FILES_CMD
  TERM_CMD=$(default_terminal)
  BROWSER_CMD=$(default_browser)
  FILES_CMD=$(default_filemanager)
  echo "Terminal:  $TERM_CMD"
  echo "Navegador: $BROWSER_CMD"
  echo "Archivos:  $FILES_CMD"

  gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
    "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/']"
  mk_custom 0 'Terminal'  "$TERM_CMD"    '<Super>Return'
  mk_custom 1 'Navegador' "$BROWSER_CMD" '<Super>w'
  mk_custom 2 'Archivos'  "$FILES_CMD"   '<Super>e'

  gsettings set "$WM" close "['<Super>q', '<Alt>F4']"
  gsettings set "$WM" toggle-fullscreen "['<Super>f']"
  gsettings set "$WM" panel-run-dialog "['<Alt>F2']"
  for i in 1 2 3 4 5; do
    gsettings set "$WM" switch-to-workspace-$i "['<Super>$i']"
    gsettings set "$WM" move-to-workspace-$i "['<Super><Ctrl>$i']"
  done
  for d in left right up down; do
    D="$(tr '[:lower:]' '[:upper:]' <<< "${d:0:1}")${d:1}"
    gsettings set "$WM" switch-to-workspace-$d "['<Super>$D']"
    gsettings set "$WM" move-to-workspace-$d "['<Super><Ctrl>$D']"
  done
  gsettings set org.gnome.mutter overlay-key 'Super_L'
  gsettings set org.gnome.shell.keybindings toggle-application-view "['<Super>a']"
  gsettings reset org.gnome.shell.keybindings show-screenshot-ui
  gsettings reset org.gnome.shell.keybindings screenshot
  gsettings reset org.gnome.shell.keybindings screenshot-window
}

shortcuts() {
    step_reset_shortcuts
    step_shortcuts
}

# Lista de Flatpaks a instalar (edita aquí)
FLATPAKS=(
    # "com.discordapp.Discord"
    # "com.spotify.Client"
    # "com.valvesoftware.Steam"
    # "org.telegram.desktop"
)

install_flatpaks() {
    log "Flatpaks"
    # Asegurar Flathub
    if ! flatpak remotes | grep -q flathub; then
        echo "Agregando remote Flathub..."
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
    if [ ${#FLATPAKS[@]} -eq 0 ]; then
        echo "(aviso) Lista de Flatpaks vacía, edita FLATPAKS en el script"
        return
    fi
    for app in "${FLATPAKS[@]}"; do
        echo "Instalando $app..."
        flatpak install -y flathub "$app"
    done
}

PACKAGES_ARCH=(
    gnome-tweaks
    dconf-editor
    ghostty
)

PACKAGES_FEDORA=(
    gnome-tweaks
    dconf-editor
    # ghostty: sudo dnf copr enable scottames/ghostty && sudo dnf install ghostty
)

gaming_optimize() {
    log "Gaming (GameMode + MangoHud)"
    case "$DISTRO" in
        arch)   sudo pacman -S --needed gamemode lib32-gamemode mangohud ;;
        fedora) sudo dnf install -y gamemode mangohud ;;
    esac
    echo "✅ Listo. En Steam ve a: clic derecho en el juego → Propiedades → Opciones de lanzamiento →"
    echo '   gamemoderun %command%'
    echo "   (MangoHud se activa con: mangohud %command%)"
}

install_apps() {
    log "Aplicaciones y tweaks"
    case "$DISTRO" in
        arch)   sudo pacman -S --needed "${PACKAGES_ARCH[@]}" ;;
        fedora) sudo dnf install -y "${PACKAGES_FEDORA[@]}" ;;
        *) echo "Distro no soportada" ;;
    esac
}

# Paquetes de AUR (solo Arch)
AUR_PACKAGES=(
    # "yay-bin"
    # "zen-browser-bin"
)

install_aur() {
    if [ "$DISTRO" != "arch" ]; then
        echo "AUR solo aplica en Arch (detectado: $DISTRO). Omitido."
        return
    fi
    log "AUR"
    # Instalar helper si no hay
    if ! command -v paru &>/dev/null && ! command -v yay &>/dev/null; then
        echo "Instalando paru..."
        sudo pacman -S --needed --noconfirm base-devel git
        tmp=$(mktemp -d)
        git clone https://aur.archlinux.org/paru.git "$tmp/paru"
        (cd "$tmp/paru" && makepkg -si --noconfirm)
        rm -rf "$tmp"
    fi
    local helper
    helper=$(command -v paru || command -v yay)
    if [ ${#AUR_PACKAGES[@]} -eq 0 ]; then
        echo "(aviso) Lista AUR_PACKAGES vacía"
        return
    fi
    for pkg in "${AUR_PACKAGES[@]}"; do
        "$helper" -S --needed --noconfirm "$pkg"
    done
}

detect_gpu() {
    local gpu
    gpu=$(lspci -nn | grep -Ei 'vga compatible|3d controller|display controller')
    echo "$gpu"
}

system_optimize() {
    log "Optimizaciones Linux (ZRAM, TRIM, journald, BBR, etc.)"

    echo "→ ZRAM (swap comprimida)"
    case "$DISTRO" in
        arch)   sudo pacman -S --needed systemd-zram-generator || true ;;
        fedora) sudo dnf install -y systemd-zram-generator || true ;;
    esac
    echo "[zram0]
zram-size = ram / 2
compression-algorithm = lz4
swap-priority = 100" | sudo tee /etc/systemd/zram-generator.conf >/dev/null || true

    echo "→ swappiness y page-cluster (óptimo con ZRAM)"
    printf "vm.swappiness=100\nvm.page-cluster=0\n" | sudo tee /etc/sysctl.d/99-zram.conf >/dev/null || true
    sudo sysctl -p /etc/sysctl.d/99-zram.conf >/dev/null 2>&1 || true

    echo "→ fstrim.timer (semanal en SSD)"
    sudo systemctl enable --now fstrim.timer || true

    echo "→ Power profile performance"
    powerprofilesctl set performance 2>/dev/null || echo "   (power-profiles-daemon no disponible)"

    echo "→ Animaciones OFF en GNOME"
    gsettings set org.gnome.desktop.interface enable-animations false || true

    echo "→ Deshabilitar indexador Tracker"
    for s in tracker-miner-fs-3 tracker-extract-3 tracker-miner-rss-3; do
        systemctl --user mask "$s.service" 2>/dev/null || true
    done

    echo "→ BBR congestion control"
    printf "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\n" | sudo tee /etc/sysctl.d/99-bbr.conf >/dev/null || true
    sudo sysctl -p /etc/sysctl.d/99-bbr.conf >/dev/null 2>&1 || true

    echo "→ Limitar journal a 200M"
    sudo sed -i 's/^#\?SystemMaxUse=.*/SystemMaxUse=200M/' /etc/systemd/journald.conf || true
    sudo systemctl restart systemd-journald || true

    echo "→ noatime en la partición raíz (backup en /etc/fstab.bak)"
    if grep -q ' / ' /etc/fstab && ! grep -q 'noatime' /etc/fstab; then
        sudo cp /etc/fstab /etc/fstab.bak
        sudo sed -i '/ \/ / s/defaults/defaults,noatime/' /etc/fstab || true
        echo "   aplicado, se verá tras re-montar o reiniciar"
    else
        echo "   ya estaba o no se encontró la raíz, omitido"
    fi

    echo "→ preload"
    case "$DISTRO" in
        arch)   sudo pacman -S --needed preload || true ;;
        fedora) sudo dnf install -y preload || true ;;
    esac
    sudo systemctl enable --now preload 2>/dev/null || true

    echo "Listo. Reinicia para aplicar todo (noatime, ZRAM, BBR)."
}

optimize_gnome() {
    log "Optimizaciones GNOME"
    local gpu
    gpu=$(detect_gpu)
    echo "GPU detectada:"
    echo "$gpu"

    # VRR (tasa de refresco variable)
    if echo "$gpu" | grep -qi nvidia; then
        echo "→ NVIDIA: se recomienda usar el modo Wayland con el driver 555+"
    elif echo "$gpu" | grep -qi amd; then
        echo "→ AMD: instalando/verificando drivers Vulkan Radeon"
        [ "$DISTRO" = "arch" ] && sudo pacman -S --needed vulkan-radeon lib32-vulkan-radeon
        [ "$DISTRO" = "fedora" ] && sudo dnf install -y mesa-vulkan-drivers
    elif echo "$gpu" | grep -qi intel; then
        echo "→ Intel: instalando/verificando drivers Vulkan Intel"
        [ "$DISTRO" = "arch" ] && sudo pacman -S --needed vulkan-intel lib32-vulkan-intel
        [ "$DISTRO" = "fedora" ] && sudo dnf install -y mesa-vulkan-drivers
    fi

    # Tweaks seguros
    echo "→ Habilitando variable refresh rate (VRR) en Mutter si está soportado"
    gsettings set org.gnome.mutter experimental-features "['variable-refresh-rate']" 2>/dev/null || \
        echo "   (no soportado en esta versión, omitido)"
    echo "→ Forzando hardware cursors desactivados solo si es X11"
    if [ "$XDG_SESSION_TYPE" = "x11" ]; then
        gsettings set org.gnome.desktop.interface gtk-enable-animations true
    fi
    echo "Listo. Algunas opciones se aplican tras reiniciar sesión."
    system_optimize
}

EXTENSIONS=(
    "dash-to-dock@micxgx.gmail.com"
    "just-perfection-desktop@just-perfection"
    "caffeine@patapon.info"
)

install_extensions() {
    log "Extensiones GNOME (gext)"
    if ! command -v gext &>/dev/null; then
        echo "Instalando gext..."
        case "$DISTRO" in
            arch) sudo pacman -S --needed python-pipx && pipx ensurepath ;;
            fedora) sudo dnf install -y pipx ;;
        esac
        pipx install gnome-extensions-cli
    fi
    for ext in "${EXTENSIONS[@]}"; do
        echo "Instalando $ext..."
        gext install "$ext" || echo "(aviso) falló $ext, quizá no es compatible con GNOME $(gnome-shell --version)"
        gext enable "$ext" 2>/dev/null || true
    done
}

step_firefox() {
  log "Extra · Firefox/Zen (Betterfox + DoH Mullvad)"
  local prof n=0
  for prof in ~/.config/mozilla/firefox/*.default-release ~/.mozilla/firefox/*.default-release ~/.zen/*.default; do
    [[ -d "$prof" ]] || continue
    cp "$prof/prefs.js" "$prof/prefs.js.bak" 2>/dev/null || true
    curl -sL -o "$prof/user.js" "https://raw.githubusercontent.com/yokoffing/Betterfox/main/user.js" || continue
    cat >> "$prof/user.js" <<'USERJS_EOF'

// Rice overrides: videollamadas + contraseñas intactas, DoH Mullvad
user_pref("media.peerconnection.enabled", true);
user_pref("signon.rememberSignons", true);
user_pref("network.trr.custom_uri", "https://doh.mullvad.net/dns-query");
user_pref("network.trr.uri", "https://doh.mullvad.net/dns-query");
user_pref("network.trr.mode", 3);
user_pref("network.proxy.socks_remote_dns", true);
USERJS_EOF
    n=$((n + 1))
    echo "  -> $prof"
  done
  [[ "$n" -gt 0 ]] && echo "user.js instalado en $n perfil(es)" || echo "(aviso) sin perfiles Firefox/Zen, omitido"
}

# Solo actualiza los atajos personalizados 0-2 según las apps por defecto (sin resetear todo)
apply_shortcuts() {
  local TERM_CMD BROWSER_CMD FILES_CMD
  TERM_CMD=$(default_terminal)
  BROWSER_CMD=$(default_browser)
  FILES_CMD=$(default_filemanager)
  gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
    "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/']"
  mk_custom 0 'Terminal'  "$TERM_CMD"    '<Super>Return'
  mk_custom 1 'Navegador' "$BROWSER_CMD" '<Super>w'
  mk_custom 2 'Archivos'  "$FILES_CMD"   '<Super>e'
  echo "Atajos actualizados → Terminal: $TERM_CMD | Navegador: $BROWSER_CMD | Archivos: $FILES_CMD"
}

# Vigila cambios en las apps por defecto y re-aplica los atajos
watch_defaults() {
  local last="" cur
  echo "Vigilando cambios de apps predeterminadas..."
  while true; do
    cur="$(default_terminal)|$(default_browser)|$(default_filemanager)"
    if [ "$cur" != "$last" ]; then
        [ -n "$last" ] && apply_shortcuts
        last="$cur"
    fi
    sleep 5
  done
}

case "${1:-}" in
    backup) backup ;;
    restore) restore ;;
    install) install_packages ;;
    shortcuts) shortcuts ;;
    apply-shortcuts) apply_shortcuts ;;
    watch) watch_defaults ;;
    firefox) step_firefox ;;
    flatpaks) install_flatpaks ;;
    extensions) install_extensions ;;
    aur) install_aur ;;
    optimize) optimize_gnome ;;
    apps) install_apps ;;
    gaming) gaming_optimize ;;
    *)
        echo "Uso: $0 [backup|restore|install|shortcuts|apply-shortcuts|watch|firefox|flatpaks|extensions|aur|optimize|apps|gaming]"
        ;;
esac

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
            sudo pacman -S --needed --noconfirm gnome-shell gnome-control-center dconf
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

# Vacía TODAS las teclas de un schema (para que GNOME no imponga sus propios atajos)
clear_schema() {
    gsettings list-recursively "$1" 2>/dev/null | awk '{print $2}' | while read -r key; do
        [ -n "$key" ] || continue
        # Si es un array de strings, lo vacía; si no, vuelve al default
        gsettings set "$1" "$key" "@as []" 2>/dev/null || gsettings reset "$1" "$key" 2>/dev/null || true
    done || true
    return 0
}

# -----------------------------------------------------------------------------
# Atajos (limpieza + propios)
# -----------------------------------------------------------------------------
step_reset_shortcuts() {
  log "3 · Limpieza base de atajos"
  gsettings reset-recursively org.gnome.settings-daemon.plugins.media-keys 2>/dev/null || true
  dconf reset -f /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/ 2>/dev/null || true
  dconf reset -f /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/ 2>/dev/null || true
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
    local desktop alt
    desktop=$(xdg-settings get default-web-browser 2>/dev/null) || desktop=""
    case "$desktop" in
        *firefox*) echo "firefox --new-window" ;;
        *chromium*) echo "chromium --new-window" ;;
        *chrome*) echo "google-chrome-stable --new-window" ;;
        *brave*)
            # Binarios posibles: brave (AUR), brave-origin (Origin), brave-browser (repo)
            for alt in brave-origin brave brave-browser; do
                command -v "$alt" &>/dev/null && { echo "$alt --new-window"; return; }
            done
            echo "brave --new-window"
            ;;
        *edge*) echo "microsoft-edge --new-window" ;;
        *opera*) echo "opera --new-window" ;;
        *)
            # Fallback: primer navegador realmente instalado
            for alt in firefox firefox-developer-edition chromium google-chrome-stable brave-browser microsoft-edge opera; do
                command -v "$alt" &>/dev/null && { echo "$alt"; return; }
            done
            echo "firefox"
            ;;
    esac
}

default_filemanager() {
    local desktop alt
    desktop=$(xdg-mime query default inode/directory 2>/dev/null) || desktop=""
    case "$desktop" in
        *nautilus*|*org.gnome.Nautilus*) echo "nautilus --new-window" ;;
        *dolphin*) echo "dolphin" ;;
        *thunar*) echo "thunar" ;;
        *nemo*) echo "nemo" ;;
        *pcmanfm*) echo "pcmanfm" ;;
        *)
            for alt in nautilus dolphin thunar nemo pcmanfm; do
                command -v "$alt" &>/dev/null && { echo "$alt"; return; }
            done
            echo "nautilus"
            ;;
    esac
}

default_terminal() {
    local t
    t=$(gsettings get org.gnome.desktop.default-applications.terminal exec 2>/dev/null | tr -d "'")
    if [ -n "$t" ] && [ "$t" != "null" ] && command -v "$t" &>/dev/null; then
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

  # Desactivar atajos de Dash to Dock que chocan con los nuestros
  dconf write /org/gnome/shell/extensions/dash-to-dock/shortcut "@as []"
  for i in 1 2 3 4 5 6 7 8 9 10; do
    dconf write /org/gnome/shell/extensions/dash-to-dock/app-hotkey-$i "@as []"
  done

  # Dock transparente
  dconf write /org/gnome/shell/extensions/dash-to-dock/transparency-mode "'FIXED'"
  # Dock: ocultar Trash y Discos, mostrar solo Show Apps
  dconf write /org/gnome/shell/extensions/dash-to-dock/show-trash false
  dconf write /org/gnome/shell/extensions/dash-to-dock/show-mounts false
  dconf write /org/gnome/shell/extensions/dash-to-dock/show-mounts-network false
  dconf write /org/gnome/shell/extensions/dash-to-dock/show-show-apps-button true

  # Asegurar workspaces fijos para que Super+1..5 siempre funcionen
  gsettings set org.gnome.mutter dynamic-workspaces false
  gsettings set org.gnome.desktop.wm.preferences num-workspaces 5

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
  # Vaciar switch-to-application-N (chocan con Super+1..5 de workspaces)
  for i in 1 2 3 4 5 6 7 8 9; do
    gsettings set org.gnome.shell.keybindings switch-to-application-$i "[]"
  done
  gsettings reset org.gnome.shell.keybindings show-screenshot-ui 2>/dev/null || true
  gsettings reset org.gnome.shell.keybindings screenshot 2>/dev/null || true
  gsettings reset org.gnome.shell.keybindings screenshot-window 2>/dev/null || true
}

shortcuts() {
    step_reset_shortcuts
    step_shortcuts
}

# Lista de Flatpaks a instalar (edita aquí)
FLATPAKS=(
    "me.proton.Pass"
)

install_flatpaks() {
    log "Flatpaks"
    if ! command -v flatpak &>/dev/null; then
        echo "(aviso) flatpak no está instalado, omitido"
        return 0
    fi
    # Asegurar Flathub
    if ! flatpak remotes 2>/dev/null | grep -q flathub; then
        echo "Agregando remote Flathub..."
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
    fi
    if [ ${#FLATPAKS[@]} -eq 0 ]; then
        echo "(aviso) Lista de Flatpaks vacía, edita FLATPAKS en el script"
        return 0
    fi
    for app in "${FLATPAKS[@]}"; do
        echo "Instalando $app..."
        flatpak install -y flathub "$app" || echo "(aviso) falló $app"
    done
}

PACKAGES_ARCH=(
    gnome-tweaks
    dconf-editor
    ghostty
    power-profiles-daemon
    gedit
    thunderbird
    brave-origin-bin
    qemu-desktop
    libvirt
    virt-manager
    dnsmasq
    iptables-nft
)

PACKAGES_FEDORA=(
    gnome-tweaks
    dconf-editor
    power-profiles-daemon
    gedit
    thunderbird
    qemu-kvm
    libvirt
    virt-manager
    dnsmasq
    # ghostty: sudo dnf copr enable scottames/ghostty && sudo dnf install ghostty
    # brave:   sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo && sudo dnf install brave-browser
)

gaming_optimize() {
    log "Gaming (GameMode + MangoHud)"
    case "$DISTRO" in
        arch)   sudo pacman -S --needed --noconfirm gamemode lib32-gamemode mangohud ;;
        fedora) sudo dnf install -y gamemode mangohud ;;
    esac
    echo "✅ Listo. En Steam ve a: clic derecho en el juego → Propiedades → Opciones de lanzamiento →"
    echo '   gamemoderun %command%'
    echo "   (MangoHud se activa con: mangohud %command%)"
}

uninstall_all() {
    local FULL=false
    [ "${2:-}" = "--full" ] && FULL=true
    log "Desinstalar/revertir lo aplicado por el script"
    if $FULL; then
        echo "MODO COMPLETO: además de la configuración, se desinstalarán paquetes, apps, Flatpaks y AUR."
    else
        echo "Modo suave: se revierte solo configuración (atajos, extensiones, tweaks, watcher)."
        echo "Usa 'uninstall --full' para quitar también paquetes y apps instaladas."
    fi
    read -p "¿Continuar? [y/N] " -n 1 -r || REPLY=""
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || { echo "Cancelado"; exit 0; }

    echo "→ Deteniendo servicio watcher"
    systemctl --user disable --now gnome-watch-defaults.service 2>/dev/null || true
    rm -f ~/.config/systemd/user/gnome-watch-defaults.service
    systemctl --user daemon-reload

    echo "→ Restaurando atajos por defecto"
    gsettings reset-recursively org.gnome.settings-daemon.plugins.media-keys
    clear_schema org.gnome.desktop.wm.keybindings
    clear_schema org.gnome.shell.keybindings
    clear_schema org.gnome.mutter.keybindings
    clear_schema org.gnome.mutter.wayland.keybindings
    gsettings set org.gnome.mutter dynamic-workspaces true
    gsettings reset org.gnome.desktop.wm.preferences num-workspaces

    echo "→ Desinstalando Flatpaks de la lista"
    for app in "${FLATPAKS[@]}"; do
        flatpak uninstall -y "$app" 2>/dev/null || true
    done

    echo "→ Desinstalando extensiones"
    for ext in "${EXTENSIONS[@]}"; do
        gext uninstall "$ext" 2>/dev/null || true
    done

    echo "→ Desinstalando paquetes AUR de la lista"
    if command -v paru &>/dev/null || command -v yay &>/dev/null; then
        helper=$(command -v paru || command -v yay)
        for pkg in "${AUR_PACKAGES[@]}"; do
            "$helper" -Rns --noconfirm "$pkg" 2>/dev/null || true
        done
    fi

    echo "→ Revirtiendo tweaks de sistema"
    sudo rm -f /etc/systemd/zram-generator.conf
    sudo rm -f /etc/sysctl.d/99-zram.conf /etc/sysctl.d/99-bbr.conf
    [ -f /etc/fstab.bak ] && sudo cp /etc/fstab.bak /etc/fstab && echo "   /etc/fstab restaurado"
    sudo systemctl disable --now preload 2>/dev/null || true
    powerprofilesctl set balanced 2>/dev/null || true
    gsettings set org.gnome.desktop.interface enable-animations true
    for s in tracker-miner-fs-3 tracker-extract-3 tracker-miner-rss-3; do
        systemctl --user unmask "$s.service" 2>/dev/null || true
    done
    sudo sed -i 's/^SystemMaxUse=200M/#SystemMaxUse=/' /etc/systemd/journald.conf
    sudo systemctl restart systemd-journald || true
    sudo systemctl disable fstrim.timer 2>/dev/null || true
    sudo systemctl disable --now cpufreq-performance.service 2>/dev/null || true
    sudo rm -f /etc/systemd/system/cpufreq-performance.service
    sudo cpupower frequency-set -g schedutil 2>/dev/null || true

    echo "✅ Todo revertido. Reinicia para aplicar todos los cambios."
    if $FULL; then
        echo ""
        echo "→ Desinstalando paquetes de apps ($DISTRO)"
        case "$DISTRO" in
            arch)   sudo pacman -Rns --noconfirm "${PACKAGES_ARCH[@]}" preload gamemode lib32-gamemode mangohud 2>/dev/null || true ;;
            fedora) sudo dnf remove -y "${PACKAGES_FEDORA[@]}" preload gamemode mangohud 2>/dev/null || true ;;
        esac
        echo "→ Desinstalando apps extra (Brave, Proton Pass, gedit, thunderbird...)"
        case "$DISTRO" in
            arch)   sudo pacman -Rns --noconfirm brave-origin-bin gedit thunderbird 2>/dev/null || true ;;
            fedora) sudo dnf remove -y brave-browser proton-pass gedit thunderbird 2>/dev/null || true ;;
        esac
        echo "→ Desinstalando Flatpaks de la lista"
        for app in "${FLATPAKS[@]}"; do
            flatpak uninstall -y "$app" 2>/dev/null || true
        done
        echo "→ Desinstalando gext (CLI de extensiones)"
        pipx uninstall gnome-extensions-cli 2>/dev/null || true
        echo "✅ Desinstalación completa."
    fi
}

install_apps() {
    log "Aplicaciones y tweaks (incluye QEMU/libvirt/virt-manager)"
    case "$DISTRO" in
        arch)   sudo pacman -S --needed --noconfirm "${PACKAGES_ARCH[@]}" ;;
        fedora) sudo dnf install -y "${PACKAGES_FEDORA[@]}" ;;
        *) echo "Distro no soportada" ;;
    esac
    echo "→ Habilitando libvirt (para usar KVM/virt-manager)"
    sudo systemctl enable --now libvirtd 2>/dev/null || sudo systemctl enable --now virtqemud 2>/dev/null || true
    echo "→ Añadiendo usuario al grupo libvirt"
    sudo usermod -aG libvirt "$USER" 2>/dev/null || true
    echo "(aplica el grupo tras cerrar sesión y volver a entrar)"
}

# Paquetes de AUR (solo Arch) - vacío: todo se instala desde repos oficiales
AUR_PACKAGES=()

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
    gpu=$(lspci -nn 2>/dev/null | grep -Ei 'vga compatible|3d controller|display controller' || true)
    echo "${gpu:-GPU no detectada}"
}

system_optimize() {
    log "Optimizaciones Linux (ZRAM, TRIM, journald, BBR, etc.)"

    echo "→ ZRAM (swap comprimida)"
    case "$DISTRO" in
        arch)   sudo pacman -S --needed --noconfirm zram-generator || true ;;
        fedora) sudo dnf install -y systemd-zram-generator || sudo dnf install -y zram-generator || true ;;
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
    powerprofilesctl set performance 2>/dev/null || echo "   (power-profiles-daemon no compatible, usamos cpupower)"
    echo "→ CPU governor performance (persiste tras reiniciar)"
    sudo cpupower frequency-set -g performance 2>/dev/null || echo "   (cpupower no disponible)"
    printf '[Unit]\nDescription=CPU governor performance\nAfter=multi-user.target\n\n[Service]\nType=oneshot\nExecStart=/usr/bin/cpupower frequency-set -g performance\n\n[Install]\nWantedBy=multi-user.target\n' | sudo tee /etc/systemd/system/cpufreq-performance.service >/dev/null
    sudo systemctl enable cpufreq-performance.service 2>/dev/null || true

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
        if [ "$DISTRO" = "arch" ]; then sudo pacman -S --needed --noconfirm vulkan-radeon lib32-vulkan-radeon || true; fi
        if [ "$DISTRO" = "fedora" ]; then sudo dnf install -y mesa-vulkan-drivers || true; fi
    elif echo "$gpu" | grep -qi intel; then
        echo "→ Intel: instalando/verificando drivers Vulkan Intel"
        if [ "$DISTRO" = "arch" ]; then sudo pacman -S --needed --noconfirm vulkan-intel lib32-vulkan-intel || true; fi
        if [ "$DISTRO" = "fedora" ]; then sudo dnf install -y mesa-vulkan-drivers || true; fi
    fi

    # Tweaks seguros
    echo "→ Habilitando variable refresh rate (VRR) en Mutter si está soportado"
    gsettings set org.gnome.mutter experimental-features "['variable-refresh-rate']" 2>/dev/null || \
        echo "   (no soportado en esta versión, omitido)"
    if [ "$XDG_SESSION_TYPE" = "x11" ]; then
        gsettings set org.gnome.desktop.interface gtk-enable-animations true || true
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
            arch) sudo pacman -S --needed --noconfirm python-pipx && pipx ensurepath ;;
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
        apply_shortcuts
        last="$cur"
    fi
    sleep 30
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
    uninstall) uninstall_all "$@" ;;
    *)
        echo "Uso: $0 [backup|restore|install|shortcuts|apply-shortcuts|watch|firefox|flatpaks|extensions|aur|optimize|apps|gaming|uninstall [--full]]"
        ;;
esac

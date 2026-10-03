# GNOME Setup

Script para configurar GNOME rápidamente tras una reinstalación. Soporta **Arch** (CachyOS, Manjaro, EndeavourOS) y **Fedora**.

## Uso

```bash
git clone https://github.com/AZIT0/Gnome-Basic.git
cd Gnome-Basic
chmod +x setup.sh
./setup.sh <comando>
```

## Comandos

| Comando | Qué hace |
|---|---|
| `backup` | Guarda la configuración de dconf en `~/.Gnome-Basic-backup` |
| `restore` | Restaura la configuración guardada |
| `install` | Instala paquetes base de GNOME según la distro |
| `shortcuts` | Limpia atajos de GNOME y aplica los propios |
| `apply-shortcuts` | Actualiza atajos 0-2 según apps predeterminadas |
| `watch` | Vigila cambios de apps predeterminadas y actualiza atajos |
| `firefox` | Instala Betterfox + DoH Mullvad en Firefox/Zen |
| `flatpaks` | Agrega Flathub e instala Flatpaks de la lista |
| `extensions` | Instala extensiones con gext |
| `aur` | Instala paquetes de AUR con paru/yay |
| `optimize` | Optimizaciones GNOME + Linux (ZRAM, TRIM, BBR, etc.) |
| `apps` | Instala gnome-tweaks, dconf-editor, ghostty |
| `gaming` | Instala GameMode + MangoHud |

## Servicio de vigilancia de apps predeterminadas

Para que los atajos `<Super>Return`/`<Super>w`/`<Super>e` se actualicen solos cuando cambias el navegador/terminal/gestor de archivos por defecto:

```bash
mkdir -p ~/.config/systemd/user
cp gnome-watch-defaults.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now gnome-watch-defaults.service
```

## Nota

Edita las listas `EXTENSIONS`, `FLATPAKS`, `AUR_PACKAGES`, `PACKAGES_ARCH` y `PACKAGES_FEDORA` dentro de `setup.sh` para personalizar tu instalación.

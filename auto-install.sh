#!/bin/bash
# Auto-install: descarga Gzito-B y ejecuta install o uninstall
# Uso: curl ... | bash              (instala)
#      curl ... | bash -s uninstall (desinstala/revierte)
set -e
ACTION="${1:-install}"
REPO_DIR="$HOME/Gzito-B"
URL="https://github.com/AZIT0/Gzito-B/archive/refs/heads/main.tar.gz"

# Descargar/actualizar el repo a una ubicación fija (para que el servicio watcher persista)
if [ -d "$REPO_DIR/.git" ]; then
    # Ya existe una copia con git: solo actualizar
    git -C "$REPO_DIR" pull --ff-only || true
else
    TMP=$(mktemp -d)
    curl -fsSL "$URL" -o "$TMP/gzitob.tar.gz"
    tar xzf "$TMP/gzitob.tar.gz" -C "$TMP"
    rm -rf "$REPO_DIR"
    mv "$TMP/Gzito-B-main" "$REPO_DIR"
    rm -rf "$TMP"
fi
cd "$REPO_DIR"
chmod +x setup.sh install

if [ "$ACTION" = "uninstall" ]; then
    ./setup.sh uninstall < /dev/tty
else
    ./install < /dev/tty
fi

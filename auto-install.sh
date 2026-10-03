#!/bin/bash
# Auto-install: descarga Gzito-B y ejecuta install o uninstall
# Uso: curl ... | bash              (instala)
#      curl ... | bash -s uninstall (desinstala/revierte)
set -e
ACTION="${1:-install}"
URL="https://github.com/AZIT0/Gzito-B/archive/refs/heads/main.tar.gz"
TMP=$(mktemp -d)
curl -fsSL "$URL" -o "$TMP/gzitob.tar.gz"
tar xzf "$TMP/gzitob.tar.gz" -C "$TMP"
cd "$TMP/Gzito-B-main"
if [ "$ACTION" = "uninstall" ]; then
    ./setup.sh uninstall
else
    ./install
fi

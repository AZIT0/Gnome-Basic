#!/bin/bash
# Bootstrap: descarga Gnome-Basic y ejecuta ./install
set -e
URL="https://github.com/AZIT0/Gnome-Basic/archive/refs/heads/main.tar.gz"
TMP=$(mktemp -d)
curl -fsSL "$URL" -o "$TMP/gnome-basic.tar.gz"
tar xzf "$TMP/gnome-basic.tar.gz" -C "$TMP"
cd "$TMP/Gnome-Basic-main"
./install

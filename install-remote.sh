#!/bin/bash
# Bootstrap: descarga Gzito-B y ejecuta ./install
set -e
URL="https://github.com/AZIT0/Gzito-B/archive/refs/heads/main.tar.gz"
TMP=$(mktemp -d)
curl -fsSL "$URL" -o "$TMP/gnome-basic.tar.gz"
tar xzf "$TMP/gnome-basic.tar.gz" -C "$TMP"
cd "$TMP/Gzito-B-main"
./install

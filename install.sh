#!/usr/bin/env bash
# Instala o gamma-switch: link em ~/.local/bin e atalhos globais do KDE.
# Uso: bash install.sh            (instala / reinstala)
#      bash install.sh --uninstall
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
ACTIONS=(toggle up down reset)

shortcut_of() { sed -n 's/^X-KDE-Shortcuts=//p' "$ROOT/shortcuts/gamma-$1.desktop"; }

if [[ ${1:-} == --uninstall ]]; then
  rm -f "$BIN_DIR/gamma"
  for a in "${ACTIONS[@]}"; do
    rm -f "$APPS_DIR/gamma-$a.desktop"
    kwriteconfig6 --file kglobalshortcutsrc --group services --group "gamma-$a.desktop" --key _launch --delete
  done
  kbuildsycoca6 >/dev/null 2>&1 || true
  echo "gamma-switch removido. Saia e entre na sessão para liberar os atalhos."
  exit 0
fi

mkdir -p "$BIN_DIR" "$APPS_DIR"
ln -sf "$ROOT/bin/gamma" "$BIN_DIR/gamma"
for a in "${ACTIONS[@]}"; do
  sed "s|@BIN@|$BIN_DIR/gamma|" "$ROOT/shortcuts/gamma-$a.desktop" > "$APPS_DIR/gamma-$a.desktop"
  kwriteconfig6 --file kglobalshortcutsrc --group services --group "gamma-$a.desktop" --key _launch "$(shortcut_of "$a")"
done
kbuildsycoca6 >/dev/null 2>&1 || true
echo "gamma-switch instalado:"
for a in "${ACTIONS[@]}"; do printf '  %-8s %s\n' "$a" "$(shortcut_of "$a")"; done

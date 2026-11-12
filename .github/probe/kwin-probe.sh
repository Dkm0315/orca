#!/usr/bin/env bash
# Throwaway probe: real KWin Wayland + xdg-desktop-portal-kde session for Orca's Linux computer-use runtime.
set -u
export PROBE_OUT="$PWD/probe-out"
mkdir -p "$PROBE_OUT" "$HOME/Pictures"
export XDG_RUNTIME_DIR="$(mktemp -d)"
chmod 700 "$XDG_RUNTIME_DIR"
export XDG_CURRENT_DESKTOP=KDE XDG_SESSION_TYPE=wayland KDE_FULL_SESSION=true
export QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 QT_ACCESSIBILITY=1
exec dbus-run-session -- bash "$(dirname "$0")/kwin-probe-inner.sh"

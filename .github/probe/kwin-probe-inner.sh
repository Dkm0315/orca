#!/usr/bin/env bash
set -u
OUT="$PROBE_OUT"
DIR="$(cd "$(dirname "$0")" && pwd)"
RT="$PWD/native/computer-use-linux/runtime.py"
log() { echo; echo "=== $*"; }
alive() { if kill -0 "$KWIN_PID" 2>/dev/null; then echo "kwin alive"; else echo "KWIN DEAD"; tail -60 "$OUT/kwin.log"; exit 1; fi; }
export WAYLAND_DISPLAY=orca-wl QT_QPA_PLATFORM=wayland GDK_BACKEND=wayland
gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
  --method org.freedesktop.DBus.UpdateActivationEnvironment \
  "{'WAYLAND_DISPLAY': '$WAYLAND_DISPLAY', 'QT_QPA_PLATFORM': 'wayland', 'XDG_CURRENT_DESKTOP': 'KDE', 'XDG_SESSION_TYPE': 'wayland', 'QT_LINUX_ACCESSIBILITY_ALWAYS_ON': '1', 'XDG_RUNTIME_DIR': '$XDG_RUNTIME_DIR', 'KDE_FULL_SESSION': 'true'}"
KWIN_BIN="$(command -v kwin_wayland)"
cp "$KWIN_BIN" "$XDG_RUNTIME_DIR/kwin_wayland" && KWIN_BIN="$XDG_RUNTIME_DIR/kwin_wayland"
if command -v gdb >/dev/null; then
  gdb -q -batch -ex run -ex "thread apply all bt 25" --args "$KWIN_BIN" --virtual --width 1280 --height 800 --socket orca-wl > "$OUT/kwin.log" 2>&1 &
else
  "$KWIN_BIN" --virtual --width 1280 --height 800 --socket orca-wl > "$OUT/kwin.log" 2>&1 &
fi
KWIN_PID=$!
for i in $(seq 150); do [ -S "$XDG_RUNTIME_DIR/orca-wl" ] && break; sleep 0.2; done
for b in /usr/libexec/at-spi-bus-launcher /usr/lib/at-spi2-core/at-spi-bus-launcher; do
  if [ -x "$b" ]; then "$b" --launch-immediately & break; fi
done
sleep 2
export AT_SPI_BUS_ADDRESS="$(gdbus call --session --dest org.a11y.Bus --object-path /org/a11y/bus --method org.a11y.Bus.GetAddress | sed "s/^('//; s/',)$//")"
gdbus call --session --dest org.a11y.Bus --object-path /org/a11y/bus --method org.freedesktop.DBus.Properties.Set org.a11y.Status IsEnabled "<true>"
bash -c "$TARGET_CMD" > "$OUT/target.log" 2>&1 &
TARGET=$!
sleep 6
alive
op() { echo "$1" > "$XDG_RUNTIME_DIR/op.json"; timeout 60 python3 "$RT" "$XDG_RUNTIME_DIR/op.json"; }
state() { date +%T; op "{\"tool\":\"get_app_state\",\"app\":\"$TARGET_APP\"}" > "$OUT/$1.json"; python3 "$DIR/summarize.py" "$OUT/$1.json" "$OUT/$1"; }
store() { gdbus call --session --dest org.freedesktop.impl.portal.PermissionStore --object-path /org/freedesktop/impl/portal/PermissionStore --method "org.freedesktop.impl.portal.PermissionStore.$@"; }
kwinjs() { local f="$XDG_RUNTIME_DIR/t$RANDOM.js"; echo "$1" > "$f"; local id; id=$(gdbus call --session --dest org.kde.KWin --object-path /Scripting --method org.kde.kwin.Scripting.loadScript "$f" "probe$RANDOM" | tr -dc '0-9'); gdbus call --session --dest org.kde.KWin --object-path "/Scripting/Script$id" --method org.kde.kwin.Script.run 2>/dev/null || gdbus call --session --dest org.kde.KWin --object-path "/$id" --method org.kde.kwin.Script.run; }
EACH="var l = workspace.windowList ? workspace.windowList() : workspace.clientList(); for (var i = 0; i < l.length; i++) { var w = l[i];"

log handshake; op '{"tool":"handshake"}' | grep -o '"observation":{[^}]*}'
log windows; op "{\"tool\":\"list_windows\",\"app\":\"$TARGET_APP\"}"
log "trivial kwin script"; kwinjs "print('probe hello');"; sleep 1; alive
log "direct layout"; python3 "$DIR/direct.py" "$RT" layout; alive
store SetPermission screenshot true screenshot '' "['yes']"
log "direct portal"; python3 "$DIR/direct.py" "$RT" portal; alive
ls -la "$HOME/Pictures"

log "multi-desktop"
kwinjs "if (workspace.createDesktop) workspace.createDesktop(1, 'two'); else workspace.desktops = 2;"
sleep 1
kwinjs "var ds = workspace.desktops; print('desktops', ds, ds && ds.length, workspace.currentVirtualDesktop, workspace.currentDesktop); $EACH if (w.pid == $TARGET) { print('target desktops', w.desktops, w.desktops && w.desktops.length, w.desktop); } }"
python3 "$DIR/direct.py" "$RT" layout
log "01 granted, alone"; state 01-granted; alive
ls -la "$HOME/Pictures"
log "02 covered"
bash -c "$COVER_CMD" > "$OUT/cover.log" 2>&1 &
COVER=$!
sleep 6
kwinjs "var t, c; $EACH if (w.pid == $TARGET) t = w; if (w.pid == $COVER) c = w; } c.frameGeometry = {x: t.frameGeometry.x + 20, y: t.frameGeometry.y + 20, width: 300, height: 200};"
sleep 2
state 02-covered
log "03 uncovered, target at 10,10"
kwinjs "$EACH if (w.pid == $COVER) w.frameGeometry = {x: 900, y: 450, width: 300, height: 300}; if (w.pid == $TARGET) w.frameGeometry = {x: 10, y: 10, width: w.frameGeometry.width, height: w.frameGeometry.height}; }"
sleep 2
state 03-uncovered
log "04 partly off screen"
kwinjs "$EACH if (w.pid == $TARGET) w.frameGeometry = {x: -60, y: 300, width: w.frameGeometry.width, height: w.frameGeometry.height}; }"
sleep 2
state 04-offscreen
log "04b show desktop"
kwinjs "$EACH if (w.pid == $TARGET) w.frameGeometry = {x: 10, y: 10, width: w.frameGeometry.width, height: w.frameGeometry.height}; }"
gdbus call --session --dest org.kde.KWin --object-path /KWin --method org.kde.KWin.showDesktop true
sleep 1
gdbus call --session --dest org.kde.KWin --object-path /KWin --method org.freedesktop.DBus.Properties.Get org.kde.KWin showingDesktop
python3 "$DIR/direct.py" "$RT" layout
state 04b-show-desktop
gdbus call --session --dest org.kde.KWin --object-path /KWin --method org.kde.KWin.showDesktop false
sleep 1
log "05 minimized"
kwinjs "$EACH if (w.pid == $TARGET) { w.frameGeometry = {x: 10, y: 10, width: w.frameGeometry.width, height: w.frameGeometry.height}; w.minimized = true; } }"
sleep 1
state 05-minimized
kwinjs "$EACH if (w.pid == $TARGET) w.minimized = false; }"
sleep 1

kwinjs "$EACH if (w.pid == $COVER) w.minimized = true; }"
sleep 1
log "06 prompt: allow"
store DeletePermission screenshot screenshot ''
python3 "$DIR/answer_prompt.py" Allow > "$OUT/answer-allow.log" 2>&1 &
state 06-prompt-allowed
cat "$OUT/answer-allow.log"
store Lookup screenshot screenshot || true
state 07-after-allow
log "08 prompt: deny"
store DeletePermission screenshot screenshot ''
python3 "$DIR/answer_prompt.py" Deny > "$OUT/answer-deny.log" 2>&1 &
state 08-prompt-denied
cat "$OUT/answer-deny.log"
store Lookup screenshot screenshot || true
state 09-after-deny
log "10 prompt: unanswered"
store DeletePermission screenshot screenshot ''
state 10-prompt-unanswered
ls -la "$HOME/Pictures"
alive

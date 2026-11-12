import sys, time
import gi
gi.require_version("Atspi", "2.0")
from gi.repository import Atspi

label = sys.argv[1]
deadline = time.time() + 12

def find(node, depth=0):
    if node is None or depth > 40:
        return None
    try:
        if node.get_name() == label and "button" in node.get_role_name():
            return node
        for index in range(node.get_child_count()):
            found = find(node.get_child_at_index(index), depth + 1)
            if found is not None:
                return found
    except Exception:
        return None
    return None

while time.time() < deadline:
    desktop = Atspi.get_desktop(0)
    names = []
    for index in range(desktop.get_child_count()):
        app = desktop.get_child_at_index(index)
        name = app.get_name() if app else ""
        names.append(name)
        if name in ("kcalc", "gedit", "org.gnome.gedit"):
            continue
        button = find(app)
        if button is not None:
            print(time.strftime("%T"), "pressing", label, "in", name, flush=True)
            time.sleep(1)
            button.get_action_iface().do_action(0)
            sys.exit(0)
    time.sleep(0.5)
print("no", label, "button; apps:", names)
sys.exit(1)

import gi
gi.require_version("Atspi", "2.0")
from gi.repository import Atspi
desktop = Atspi.get_desktop(0)
for index in range(desktop.get_child_count()):
    app = desktop.get_child_at_index(index)
    try:
        print("app", repr(app.get_name()), app.get_process_id(), "children", app.get_child_count(),
              [(child.get_role_name(), child.get_name()) for child in (app.get_child_at_index(i) for i in range(min(app.get_child_count(), 5)))])
    except Exception as error:
        print("app error", error)

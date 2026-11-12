import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("rt", sys.argv[1])
rt = importlib.util.module_from_spec(spec); spec.loader.exec_module(rt)
bus = rt.session_bus()
if sys.argv[2] == "layout":
    report = rt.kwin_layout(bus)
    print(json.dumps(report)[:3000], report.get("showingDesktop"))
else:
    data = rt.portal_screenshot_png(bus)
    print("portal bytes", len(data))

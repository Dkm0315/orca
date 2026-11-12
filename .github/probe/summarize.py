import base64, json, sys
import gi
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf, GLib

raw = open(sys.argv[1]).read()
try:
    data = json.loads(raw)
except Exception:
    print("unparsable:", raw[:500]); sys.exit(0)
snap = data.get("snapshot") or {}
print("ok:", data.get("ok"), "error:", data.get("error"))
print("windowBounds:", snap.get("windowBounds"))
print("screenshotError:", snap.get("screenshotError"))
print("screenshot:", snap.get("screenshotWidth"), snap.get("screenshotHeight"), snap.get("screenshotScale"))
elements = [e for e in snap.get("elements", []) if e.get("frame")]
for element in elements[:12]:
    print("  ", element.get("controlType"), repr(element.get("name")), element.get("frame"))
if snap.get("screenshotPngBase64"):
    png = base64.b64decode(snap["screenshotPngBase64"])
    open(sys.argv[2] + ".png", "wb").write(png)
    loader = GdkPixbuf.PixbufLoader.new_with_type("png"); loader.write(png); loader.close()
    pix = loader.get_pixbuf().add_alpha(False, 0, 0, 0)
    w, h, stride, n = pix.get_width(), pix.get_height(), pix.get_rowstride(), pix.get_n_channels()
    buf = bytearray(pix.get_pixels())
    scale = snap.get("screenshotScale") or 1
    def put(x, y):
        if 0 <= x < w and 0 <= y < h:
            o = y * stride + x * n; buf[o:o + 4] = b"\xff\x00\x00\xff"
    for element in elements:
        f = element["frame"]
        if f["width"] >= w * 0.95 / scale:
            continue
        x0, y0 = int(f["x"] * scale), int(f["y"] * scale)
        x1, y1 = int((f["x"] + f["width"]) * scale) - 1, int((f["y"] + f["height"]) * scale) - 1
        for x in range(x0, x1 + 1): put(x, y0); put(x, y1)
        for y in range(y0, y1 + 1): put(x0, y); put(x1, y)
    out = GdkPixbuf.Pixbuf.new_from_bytes(GLib.Bytes.new(bytes(buf)), GdkPixbuf.Colorspace.RGB, True, 8, w, h, stride)
    out.savev(sys.argv[2] + "-frames.png", "png", [], [])
    print("saved", sys.argv[2] + ".png")

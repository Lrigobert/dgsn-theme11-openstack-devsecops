#!/usr/bin/env python3
"""Rend les blocs ```mermaid d'un fichier Markdown en PNG (Edge headless + mermaid.js), recadrés.
Usage : render-mermaid.py <fichier.md> <dossier_sortie>   -> fig-1.png, fig-2.png, ...
"""
import html
import os
import re
import subprocess
import sys
import tempfile

from PIL import Image, ImageChops

md, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
blocks = re.findall(r"```mermaid\n(.*?)```", open(md, encoding="utf-8").read(), re.S)
edge = next(p for p in (r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
                        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe") if os.path.exists(p))
tmp = tempfile.mkdtemp(prefix="mmd-")
for i, code in enumerate(blocks, 1):
    page = os.path.join(tmp, f"fig-{i}.html")
    with open(page, "w", encoding="utf-8") as f:
        f.write(f"""<!doctype html><html><head><meta charset="utf-8">
<style>body{{margin:0;padding:24px;background:#fff;font-family:Segoe UI,Arial}}</style>
<script src="https://cdn.jsdelivr.net/npm/mermaid@10.9.1/dist/mermaid.min.js"></script></head>
<body><pre class="mermaid">{html.escape(code)}</pre>
<script>mermaid.initialize({{startOnLoad:true,theme:"default",flowchart:{{htmlLabels:true}}}});</script>
</body></html>""")
    png = os.path.join(out, f"fig-{i}.png")
    subprocess.run([edge, "--headless=new", "--disable-gpu", "--no-first-run", "--hide-scrollbars",
                    f"--user-data-dir={os.path.join(tmp, 'profil')}", "--force-device-scale-factor=2",
                    "--window-size=1500,1100", "--virtual-time-budget=15000", f"--screenshot={png}",
                    "file:///" + page.replace("\\", "/")], check=True, capture_output=True)
    im = Image.open(png).convert("RGB")
    bbox = ImageChops.difference(im, Image.new("RGB", im.size, (255, 255, 255))).getbbox()
    if bbox:
        m = 20
        im = im.crop((max(bbox[0] - m, 0), max(bbox[1] - m, 0), min(bbox[2] + m, im.width), min(bbox[3] + m, im.height)))
    im.save(png)
    print(f"fig-{i}.png {im.width}x{im.height}")

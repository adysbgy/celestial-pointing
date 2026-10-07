"""Susun semua kasus visual jadi satu lembar agar bisa dinilai dengan mata.

Alat ini **bukan gerbang**: ia tidak menuntut apa pun dan tidak pernah gagal.
Tujuannya satu — membuat keadaan visual yang sebenarnya bisa dilihat, karena
tidak ada pemeriksaan otomatis di repo ini yang mengukur "bagus".

Dipakai saat menilai hasil kerja lapisan gambar:

    python3 Tools/montage.py out/visuals/sheet.png [ukuran_px]

Ukuran bawaan 200 px: cukup besar untuk menilai bentuk (pita, sabit, cincin),
masih terbaca sebagai satu lembar.
"""

import importlib.util
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_check():
    """Modul `check-visuals.py` — sumber kasus dan jalur render."""
    spec = importlib.util.spec_from_file_location(
        "check_visuals", os.path.join(ROOT, "Tools", "check-visuals.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        ROOT, "out", "visuals", "sheet.png")
    size = int(sys.argv[2]) if len(sys.argv) > 2 else 200

    C = load_check()
    R = C.R
    cases = R.build_cases()

    cell = size + 26           # ruang untuk label di bawah gambar
    columns = 7
    rows = (len(cases) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * cell, rows * cell), (18, 18, 22))
    draw = ImageDraw.Draw(sheet)

    for index, case in enumerate(cases):
        canvas = R.render(case, size=size, night_mode=False, show_frame=False, ss=2)
        path = os.path.join(R.OUT_DIR, f"{case.name}.png")
        os.makedirs(R.OUT_DIR, exist_ok=True)
        with open(path, "wb") as handle:
            handle.write(canvas.to_png())
        tile = Image.open(path).convert("RGB")
        x = (index % columns) * cell
        y = (index // columns) * cell
        sheet.paste(tile, (x + 13, y + 4))
        draw.text((x + 6, y + size + 8), case.name, fill=(150, 150, 160))

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    sheet.save(out_path)
    print(f"{len(cases)} kasus -> {out_path} ({sheet.width}x{sheet.height})")


if __name__ == "__main__":
    main()

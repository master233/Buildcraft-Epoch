"""
Crop transparent/near-transparent padding from building sprite sheets.
Uses alpha threshold > 30 to find real content bounds.
"""
from PIL import Image
import numpy as np
import os

building_dir = r"D:\Buildcraft-Epoch\asserts\image\building"

sheets = [
    "home_anim_sheet.png",
    "tower_anim_sheet.png",
    "lumberyard_anim_sheet.png",
    "mine_anim_sheet.png",
    "tavern_anim_sheet.png",
    "research_anim_sheet.png",
]

for name in sheets:
    path = os.path.join(building_dir, name)
    img = Image.open(path).convert("RGBA")
    arr = np.array(img)
    alpha = arr[:, :, 3]

    # Find rows/cols with any pixel alpha > 30
    rows = np.any(alpha > 30, axis=1)
    cols = np.any(alpha > 30, axis=0)
    if not rows.any():
        print(f"{name}: no content found, skipping")
        continue

    top    = int(np.argmax(rows))
    bottom = int(len(rows) - np.argmax(rows[::-1]))
    left   = int(np.argmax(cols))
    right  = int(len(cols) - np.argmax(cols[::-1]))

    # Add padding
    w, h = img.size
    pad = 12
    top    = max(0, top - pad)
    bottom = min(h, bottom + pad)
    # Keep left/right as full width (preserve exact 4-frame divisions)

    cropped = img.crop((0, top, w, bottom))
    cropped.save(path)
    fw = w // 4
    new_h = bottom - top
    print(f"{name}: {w}x{h} -> {w}x{new_h}  (frame {fw}x{new_h})")

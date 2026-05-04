"""Remove background from building sprite sheets using rembg (U2Net)."""
from rembg import remove
from PIL import Image
import os

building_dir = r"D:\Buildcraft-Epoch\asserts\image\building"

sheets = [
    "tower_anim_sheet.png",
    "lumberyard_anim_sheet.png",
    "mine_anim_sheet.png",
    "tavern_anim_sheet.png",
    "research_anim_sheet.png",
]

for name in sheets:
    path = os.path.join(building_dir, name)
    img = Image.open(path)
    print(f"Processing {name} ({img.size})...")
    result = remove(img)
    result.save(path)
    print(f"  -> saved with transparent background")

print("Done.")

from PIL import Image
import os

preview_dir = r"D:\Buildcraft-Epoch\asserts\image\building\gen_preview"
out_dir = r"D:\Buildcraft-Epoch\asserts\image\building\gen_preview\sheets"
os.makedirs(out_dir, exist_ok=True)

def make_sheet(frames, name):
    max_h = max(f.height for f in frames)
    total_w = sum(f.width for f in frames)
    sheet = Image.new("RGBA", (total_w, max_h), (0, 0, 0, 0))
    x = 0
    for f in frames:
        sheet.paste(f, (x, 0))
        x += f.width
    path = os.path.join(out_dir, f"{name}_sheet.png")
    sheet.save(path)
    print(f"{name}: {total_w}x{max_h} -> saved")

# home: 2x2 grid -> 4 frames horizontal
home = Image.open(os.path.join(preview_dir, "home_gen.jpg")).convert("RGBA")
w, h = home.size
hw, hh = w // 2, h // 2
make_sheet([
    home.crop((0, 0, hw, hh)),
    home.crop((hw, 0, w, hh)),
    home.crop((0, hh, hw, h)),
    home.crop((hw, hh, w, h)),
], "home")

# tower: horizontal strip 4 frames
tower = Image.open(os.path.join(preview_dir, "tower_gen.jpg")).convert("RGBA")
w, h = tower.size
fw = w // 4
make_sheet([tower.crop((i * fw, 0, (i + 1) * fw, h)) for i in range(4)], "tower")

# lumberyard: horizontal strip 4 frames
lumber = Image.open(os.path.join(preview_dir, "lumberyard_gen.jpg")).convert("RGBA")
w, h = lumber.size
fw = w // 4
make_sheet([lumber.crop((i * fw, 0, (i + 1) * fw, h)) for i in range(4)], "lumberyard")

# mine: horizontal strip 4 frames (3168x1344)
mine = Image.open(os.path.join(preview_dir, "mine_gen2.jpg")).convert("RGBA")
w, h = mine.size
fw = w // 4
make_sheet([mine.crop((i * fw, 0, (i + 1) * fw, h)) for i in range(4)], "mine")

# tavern: horizontal strip 4 frames
tavern = Image.open(os.path.join(preview_dir, "tavern_gen.jpg")).convert("RGBA")
w, h = tavern.size
fw = w // 4
make_sheet([tavern.crop((i * fw, 0, (i + 1) * fw, h)) for i in range(4)], "tavern")

# research: horizontal strip 4 frames
research = Image.open(os.path.join(preview_dir, "research_gen.jpg")).convert("RGBA")
w, h = research.size
fw = w // 4
make_sheet([research.crop((i * fw, 0, (i + 1) * fw, h)) for i in range(4)], "research")

print("Done.")

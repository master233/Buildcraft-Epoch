"""
角色 idle 序列图生成：从已提取的 12 帧 raw_*.png 去白背景并横向拼接。
依赖：tools 目录下的 raw 帧位于 asserts/image/role/role_video/tmp/
输出：asserts/image/role/role1_idle_sheet.png
"""
from pathlib import Path
from PIL import Image
import numpy as np

TMP_DIR = Path(r"D:\Buildcraft-Epoch\asserts\image\role\role_video\tmp")
SHEET_OUT = Path(r"D:\Buildcraft-Epoch\asserts\image\role\role1_idle_sheet.png")
FRAMES = 12
FRAME_SIZE = 1024  # 缩放到此尺寸，避免单纹理超过 Godot 16384 上限

BG_THRESHOLD = 240
EDGE_RANGE   = 20


def remove_white_bg(img_path: Path) -> Image.Image:
    img = Image.open(img_path).convert("RGBA")
    arr = np.array(img, dtype=np.float32)
    min_ch = np.minimum(np.minimum(arr[:, :, 0], arr[:, :, 1]), arr[:, :, 2])
    alpha = np.clip((BG_THRESHOLD - min_ch) / EDGE_RANGE * 255, 0, 255).astype(np.uint8)
    result = arr.astype(np.uint8)
    result[:, :, 3] = alpha
    return Image.fromarray(result, "RGBA")


raw_frames = sorted(TMP_DIR.glob("raw_*.png"))
assert len(raw_frames) == FRAMES, f"expected {FRAMES} frames, got {len(raw_frames)}"

print(">>> 去白底 + 缩放 + 拼接 ...")
clean = []
for i, fp in enumerate(raw_frames):
    out = TMP_DIR / f"clean_{i + 1:02d}.png"
    img = remove_white_bg(fp)
    if img.size != (FRAME_SIZE, FRAME_SIZE):
        img = img.resize((FRAME_SIZE, FRAME_SIZE), Image.LANCZOS)
    img.save(out)
    clean.append(img)
    print(f"    [{i + 1}/{FRAMES}] {out.name}")

W, H = clean[0].size
sheet = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
for i, img in enumerate(clean):
    sheet.paste(img, (i * W, 0))

SHEET_OUT.parent.mkdir(parents=True, exist_ok=True)
sheet.save(SHEET_OUT)
print(f">>> 完成：{SHEET_OUT}")
print(f"    尺寸：{sheet.width} × {sheet.height}，单帧：{W} × {H}")

"""
从特效视频提取序列帧，用亮度作为 Alpha（黑背景 → 透明），合成横向序列图。
适用于加法混合（Add blend）特效。

输入：asserts/fx/fx_video/build_lv_up.mp4
输出：asserts/fx/building_anim_sheet/build_lv_up_anim_sheet.png
"""
import subprocess, sys
from pathlib import Path
from PIL import Image
import numpy as np

ROOT      = Path(r"D:\Buildcraft-Epoch")
VIDEO     = ROOT / "asserts/fx/fx_video/build_lv_up.mp4"
TMP_DIR   = ROOT / "asserts/fx/tmp"
SHEET_DIR = ROOT / "asserts/fx/building_anim_sheet"
SHEET_OUT = SHEET_DIR / "build_lv_up_anim_sheet.png"

FRAMES   = 12      # 提取帧数
START    = 0.0     # 起始秒
DURATION = 3.0     # 截取时长（取前 3s 主体特效）

TMP_DIR.mkdir(exist_ok=True)
SHEET_DIR.mkdir(exist_ok=True)

BG_THRESHOLD = 65   # 背景 max_ch ≈ 57，阈值取 65 留余量
EDGE_RANGE   = 35   # 阈值到全不透明的过渡宽度

def dark_bg_to_alpha(img_path: Path) -> Image.Image:
    """阈值截断 + 亮度渐变 Alpha，背景 max_ch < BG_THRESHOLD → 完全透明。"""
    img = Image.open(img_path).convert("RGBA")
    arr = np.array(img, dtype=np.float32)
    max_ch = np.maximum(np.maximum(arr[:, :, 0], arr[:, :, 1]), arr[:, :, 2])
    alpha = np.clip((max_ch - BG_THRESHOLD) / EDGE_RANGE * 255, 0, 255).astype(np.uint8)
    result = arr.astype(np.uint8)
    result[:, :, 3] = alpha
    # 全透明像素清零 RGB，避免颜色溢出
    result[alpha == 0] = 0
    return Image.fromarray(result, "RGBA")

# 1. 用 ffmpeg 提取帧
fps_expr = f"{FRAMES}/{DURATION}"
frame_pattern = str(TMP_DIR / "fx_frame_%03d_raw.png")
cmd = [
    "ffmpeg", "-y",
    "-ss", str(START),
    "-i", str(VIDEO),
    "-t", str(DURATION),
    "-vf", f"fps={fps_expr}",
    frame_pattern
]
print(">>> 提取帧中...")
result = subprocess.run(cmd, capture_output=True, text=True)
if result.returncode != 0:
    print(result.stderr)
    sys.exit(1)

raw_frames = sorted(TMP_DIR.glob("fx_frame_*_raw.png"))
print(f"    提取到 {len(raw_frames)} 帧")

# 2. 亮度 → Alpha 去黑背景
print(">>> 黑背景转透明中...")
clean_frames = []
for i, fp in enumerate(raw_frames):
    out_path = TMP_DIR / f"fx_frame_{i+1:03d}.png"
    img = dark_bg_to_alpha(fp)
    img.save(out_path)
    print(f"    [{i+1}/{len(raw_frames)}] {out_path.name}")
    clean_frames.append(out_path)

# 3. 拼 2 行 6 列序列图（宽 6×W < 16384 GL 上限）
print(">>> 拼接序列图（2行6列）...")
imgs = [Image.open(p).convert("RGBA") for p in clean_frames]
W, H = imgs[0].size
cols = 6
rows = (len(imgs) + cols - 1) // cols
sheet = Image.new("RGBA", (W * cols, H * rows), (0, 0, 0, 0))
for i, img in enumerate(imgs):
    sheet.paste(img, ((i % cols) * W, (i // cols) * H))
sheet.save(SHEET_OUT)
print(f">>> 完成！{SHEET_OUT}")
print(f"    序列图尺寸：{sheet.width} × {sheet.height}，单帧：{W} × {H}，{cols}列×{rows}行")

"""
从建筑视频前N秒提取8帧，去除纯白背景，合成序列图。
视频放在：asserts/image/building/building_video/
临时帧放在：asserts/image/building/building_video/tmp/
序列图输出：asserts/image/building/building_anim_sheet/
"""
import subprocess, sys, io
from pathlib import Path
from PIL import Image
import numpy as np

BUILDING_VIDEO_DIR = Path(r"D:\Buildcraft-Epoch\asserts\image\building\building_video")
SHEET_DIR = Path(r"D:\Buildcraft-Epoch\asserts\image\building\building_anim_sheet")

VIDEO    = BUILDING_VIDEO_DIR / "lumberyard3_video.mp4"
OUT_DIR  = BUILDING_VIDEO_DIR / "tmp"
SHEET_OUT = SHEET_DIR / "lumberyard3_anim_sheet.png"
FRAMES   = 8
START    = 1  # seconds
DURATION = 2  # seconds

# 白背景去除参数：min(R,G,B) > THRESHOLD 视为背景
# EDGE_RANGE 控制边缘抗锯齿过渡宽度（像素灰度范围）
BG_THRESHOLD = 240
EDGE_RANGE   = 20

OUT_DIR.mkdir(exist_ok=True)

def remove_white_bg(img_path: Path) -> Image.Image:
    img = Image.open(img_path).convert("RGBA")
    arr = np.array(img, dtype=np.float32)
    # 取 RGB 三通道最小值作为"距白色的远近"指标
    min_ch = np.minimum(np.minimum(arr[:,:,0], arr[:,:,1]), arr[:,:,2])
    # 线性映射：min_ch >= THRESHOLD → alpha=0，<= THRESHOLD-EDGE_RANGE → alpha=255
    alpha = np.clip((BG_THRESHOLD - min_ch) / EDGE_RANGE * 255, 0, 255).astype(np.uint8)
    result = arr.astype(np.uint8)
    result[:,:,3] = alpha
    return Image.fromarray(result, "RGBA")

# 1. 用 ffmpeg 提取帧
fps_expr = f"{FRAMES}/{DURATION}"
frame_pattern = str(OUT_DIR / "frame_%03d_raw.png")
cmd = ["ffmpeg", "-y", "-ss", str(START), "-i", str(VIDEO), "-t", str(DURATION),
       "-vf", f"fps={fps_expr}", frame_pattern]
print(">>> 提取帧中...")
result = subprocess.run(cmd, capture_output=True, text=True)
if result.returncode != 0:
    print(result.stderr)
    sys.exit(1)

raw_frames = sorted(OUT_DIR.glob("frame_*_raw.png"))
print(f"    提取到 {len(raw_frames)} 帧")

# 2. 去除白背景
print(">>> 去除白背景中...")
clean_frames = []
for i, fp in enumerate(raw_frames):
    out_path = OUT_DIR / f"frame_{i+1:03d}.png"
    img = remove_white_bg(fp)
    img.save(out_path)
    print(f"    [{i+1}/{len(raw_frames)}] {out_path.name}")
    clean_frames.append(out_path)

# 3. 拼接横向序列图
print(">>> 拼接序列图...")
imgs = [Image.open(p).convert("RGBA") for p in clean_frames]
W, H = imgs[0].size
sheet = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
for i, img in enumerate(imgs):
    sheet.paste(img, (i * W, 0))
sheet.save(SHEET_OUT)
print(f">>> 完成！序列图已保存：{SHEET_OUT}")
print(f"    尺寸：{sheet.width} × {sheet.height}，帧尺寸：{W} × {H}")

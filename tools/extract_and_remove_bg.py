"""
从建筑视频前3秒提取8帧，去除背景，合成序列图。
视频放在：asserts/image/building/building_video/
临时帧放在：asserts/image/building/building_video/tmp/
序列图输出：asserts/image/building/building_anim_sheet/
"""
import subprocess, sys
from pathlib import Path
from PIL import Image
from rembg import remove, new_session

BUILDING_VIDEO_DIR = Path(r"D:\Buildcraft-Epoch\asserts\image\building\building_video")
SHEET_DIR = Path(r"D:\Buildcraft-Epoch\asserts\image\building\building_anim_sheet")

VIDEO = BUILDING_VIDEO_DIR / "home1_video.mp4"
OUT_DIR = BUILDING_VIDEO_DIR / "tmp"
SHEET_OUT = SHEET_DIR / "home1_anim_sheet.png"
FRAMES = 8
DURATION = 3  # seconds

OUT_DIR.mkdir(exist_ok=True)

# 1. 用 ffmpeg 提取 8 帧（均匀分布在前3秒）
fps_expr = f"{FRAMES}/{DURATION}"  # = 8/3 fps → 3秒恰好8帧
frame_pattern = str(OUT_DIR / "frame_%03d_raw.png")

cmd = [
    "ffmpeg", "-y",
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

raw_frames = sorted(OUT_DIR.glob("frame_*_raw.png"))
print(f"    提取到 {len(raw_frames)} 帧")

# 2. 用 rembg 去除背景
print(">>> 去除背景中（isnet-general-use 模型）...")
session = new_session("isnet-general-use")

clean_frames = []
for i, fp in enumerate(raw_frames):
    out_path = OUT_DIR / f"frame_{i+1:03d}.png"
    with open(fp, "rb") as f:
        raw_data = f.read()
    result_data = remove(raw_data, session=session)
    with open(out_path, "wb") as f:
        f.write(result_data)
    print(f"    [{i+1}/{len(raw_frames)}] {out_path.name}")
    clean_frames.append(out_path)

# 3. 拼接横向序列图（1行 × 8列）
print(">>> 拼接序列图...")
imgs = [Image.open(p).convert("RGBA") for p in clean_frames]
W, H = imgs[0].size
sheet = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
for i, img in enumerate(imgs):
    sheet.paste(img, (i * W, 0))
sheet.save(SHEET_OUT)
print(f">>> 完成！序列图已保存：{SHEET_OUT}")
print(f"    尺寸：{sheet.width} × {sheet.height}，帧尺寸：{W} × {H}")

"""
将序列图中每帧内容水平居中，消除帧间位移。
用法：直接运行，处理 building_anim_sheet 目录下所有 *_anim_sheet.png
"""
from pathlib import Path
from PIL import Image
import numpy as np

SHEET_DIR = Path(r"D:\Buildcraft-Epoch\asserts\image\building\building_anim_sheet")

def recenter_sheet(path: Path) -> None:
    img = Image.open(path).convert("RGBA")
    arr = np.array(img)
    total_w, h = img.width, img.height
    n_frames = 8
    fw = total_w // n_frames

    recentered = []
    for i in range(n_frames):
        frame = arr[:, i * fw:(i + 1) * fw, :].copy()
        alpha = frame[:, :, 3]
        cols = np.where(alpha > 30)
        if len(cols[1]) == 0:
            recentered.append(frame)
            continue
        x_min, x_max = int(cols[1].min()), int(cols[1].max())
        content_cx = (x_min + x_max) // 2
        frame_cx = fw // 2
        shift = frame_cx - content_cx
        if shift != 0:
            shifted = np.zeros_like(frame)
            if shift > 0:
                shifted[:, shift:, :] = frame[:, :fw - shift, :]
            else:
                shifted[:, :fw + shift, :] = frame[:, -shift:, :]
            recentered.append(shifted)
        else:
            recentered.append(frame)

    out = np.concatenate(recentered, axis=1)
    result = Image.fromarray(out, "RGBA")
    result.save(path)
    print(f"  已居中：{path.name}  (帧宽={fw})")

sheets = sorted(SHEET_DIR.glob("*_anim_sheet.png"))
print(f"找到 {len(sheets)} 张序列图")
for s in sheets:
    recenter_sheet(s)
print("完成！")

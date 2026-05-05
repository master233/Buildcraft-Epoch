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

    # 先用高阈值 alpha(>128) 计算每帧底部重心，再取中位数作为统一偏移
    # 避免半透明边缘像素导致的帧间偏差
    bottom_start = int(h * 0.75)
    frame_cx = fw // 2
    cxs = []
    for i in range(n_frames):
        frame = arr[:, i * fw:(i + 1) * fw, :]
        alpha_solid = (frame[:, :, 3] > 128).astype(np.float64)
        bottom = alpha_solid[bottom_start:, :]
        col_w = bottom.sum(axis=0)
        if col_w.sum() < 1.0:
            col_w = alpha_solid.sum(axis=0)
        if col_w.sum() < 1.0:
            cxs.append(frame_cx)
            continue
        cxs.append((col_w * np.arange(fw)).sum() / col_w.sum())
    # 所有帧用同一个 shift（中位数），消除半透明噪声引起的帧间差异
    median_cx = int(round(float(np.median(cxs))))
    shift = frame_cx - median_cx

    recentered = []
    for i in range(n_frames):
        frame = arr[:, i * fw:(i + 1) * fw, :].copy()
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

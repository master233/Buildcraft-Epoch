"""
对单张序列图做 per-frame 水平重对齐：
  把每帧底部 25% 的水平重心都对齐到所有帧的中位数位置，消除帧间抖动。
与 recenter_sheets.py 的差别：那个脚本对所有帧应用同一个 shift（只能整体居中），
本脚本独立平移每一帧。仅用于"动画过程中建筑底座本应静止但抖动"的场景。
用法：python recenter_per_frame.py <sheet_path> [n_frames]
"""
import sys
from pathlib import Path
from PIL import Image
import numpy as np
from scipy.ndimage import shift as nd_shift


def recenter(path: Path, n_frames: int = 8) -> None:
    img = Image.open(path).convert("RGBA")
    arr = np.array(img)
    H, W, _ = arr.shape
    fw = W // n_frames
    bot_start = int(H * 0.75)
    cols = np.arange(fw)

    cxs = []
    for i in range(n_frames):
        f = arr[:, i * fw:(i + 1) * fw, :]
        a = (f[:, :, 3] > 128).astype(np.float64)
        bot = a[bot_start:, :]
        if bot.sum() >= 1:
            cxs.append((bot.sum(axis=0) * cols).sum() / bot.sum())
        elif a.sum() >= 1:
            cxs.append((a.sum(axis=0) * cols).sum() / a.sum())
        else:
            cxs.append(fw / 2.0)

    target = float(np.median(cxs))
    frames = []
    for i in range(n_frames):
        f = arr[:, i * fw:(i + 1) * fw, :].astype(np.float32)
        sh = target - cxs[i]
        shifted = nd_shift(f, shift=(0, sh, 0), order=1, mode="constant", cval=0.0)
        shifted = np.clip(shifted, 0, 255).astype(np.uint8)
        frames.append(shifted)
        print(f"  frame {i}: cx={cxs[i]:.2f} shift={sh:+.3f}")

    result = np.concatenate(frames, axis=1)
    Image.fromarray(result, "RGBA").save(path)
    print(f"saved: {path.name} (target_cx={target:.2f})")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: python recenter_per_frame.py <sheet_path> [n_frames]")
        sys.exit(1)
    sheet = Path(sys.argv[1])
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 8
    recenter(sheet, n)

"""
为带"近纯色"背景的 PNG（如 AIART 输出的 UI 资源）添加 alpha 通道。
背景色取自四角像素的平均；颜色距离 ≤ hard 的像素全透明，≥ soft 的全不透明，中间线性渐变。

用法：python remove_solid_bg.py <png> [<png> ...] [--hard 10] [--soft 28]
"""
import sys
from pathlib import Path
from PIL import Image
import numpy as np


def remove_solid_bg(path: Path, hard: float = 10.0, soft: float = 28.0) -> None:
    im = Image.open(path).convert("RGB")
    arr = np.array(im, dtype=np.float32)
    H, W, _ = arr.shape
    corners = np.concatenate([
        arr[:8, :8].reshape(-1, 3),
        arr[:8, -8:].reshape(-1, 3),
        arr[-8:, :8].reshape(-1, 3),
        arr[-8:, -8:].reshape(-1, 3),
    ])
    bg = corners.mean(axis=0)

    diff = arr - bg
    dist = np.sqrt((diff ** 2).sum(axis=-1))
    alpha = np.clip((dist - hard) / max(soft - hard, 1e-6), 0.0, 1.0) * 255.0

    out = np.dstack([arr, alpha]).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(path)
    opaque_pct = (alpha > 200).mean() * 100
    print(f"saved: {path.name}  bg=({int(bg[0])},{int(bg[1])},{int(bg[2])})  opaque%={opaque_pct:.1f}")


if __name__ == "__main__":
    args = sys.argv[1:]
    hard = 10.0
    soft = 28.0
    paths = []
    i = 0
    while i < len(args):
        if args[i] == "--hard":
            hard = float(args[i + 1]); i += 2
        elif args[i] == "--soft":
            soft = float(args[i + 1]); i += 2
        else:
            paths.append(Path(args[i])); i += 1
    if not paths:
        print("usage: python remove_solid_bg.py <png> [...] [--hard N] [--soft N]")
        sys.exit(1)
    for p in paths:
        remove_solid_bg(p, hard, soft)

"""
给序列图前景外缘添加白色描边，外缘 alpha 渐淡，模拟手绘卡通描边。
原图叠在描边之上，建筑本体不受影响。

用法：python add_outline.py <sheet_path> [thickness=4] [n_frames=8]
"""
import sys
from pathlib import Path
from PIL import Image
import numpy as np
from scipy.ndimage import distance_transform_edt


def add_outline(path: Path, thickness: int = 4, n_frames: int = 8,
                color: tuple = (255, 255, 255)) -> None:
    img = Image.open(path).convert("RGBA")
    arr = np.array(img).astype(np.float32)
    H, W, _ = arr.shape
    fw = W // n_frames
    out_full = np.zeros_like(arr, dtype=np.float32)

    for i in range(n_frames):
        f = arr[:, i * fw:(i + 1) * fw, :].copy()
        alpha = f[:, :, 3]
        mask = alpha > 32
        if not mask.any():
            out_full[:, i * fw:(i + 1) * fw, :] = f
            continue

        # 描边层：外侧 [1, thickness] 像素环
        dist = distance_transform_edt(~mask)
        outline_mask = (dist > 0) & (dist <= thickness)
        # 外缘 alpha 由内向外渐淡：dist=1 -> 1.0，dist=thickness -> ~0.4
        fade = np.clip(1.0 - (dist - 1.0) / (thickness + 0.5), 0.0, 1.0)

        layer = np.zeros_like(f)
        layer[..., 0] = color[0]
        layer[..., 1] = color[1]
        layer[..., 2] = color[2]
        layer[..., 3] = fade * 255.0
        layer[~outline_mask] = 0.0

        # 标准 alpha-over：原图(src) 叠在描边(dst) 之上
        sa = f[..., 3:4] / 255.0
        da = layer[..., 3:4] / 255.0
        out_a = sa + da * (1.0 - sa)
        out_rgb = (f[..., :3] * sa + layer[..., :3] * da * (1.0 - sa))
        # 防 0 除
        safe_a = np.where(out_a > 1e-6, out_a, 1.0)
        out_rgb = out_rgb / safe_a
        merged = np.concatenate([out_rgb, out_a * 255.0], axis=-1)
        out_full[:, i * fw:(i + 1) * fw, :] = merged

    out_full = np.clip(out_full, 0, 255).astype(np.uint8)
    Image.fromarray(out_full, "RGBA").save(path)
    print(f"saved: {path.name} (thickness={thickness}, frames={n_frames})")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: python add_outline.py <sheet_path> [thickness=4] [n_frames=8]")
        sys.exit(1)
    p = Path(sys.argv[1])
    th = int(sys.argv[2]) if len(sys.argv) > 2 else 4
    nf = int(sys.argv[3]) if len(sys.argv) > 3 else 8
    add_outline(p, th, nf)

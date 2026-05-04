"""
Fix two animation problems:
1. Frame jitter: normalize building position across frames (align bounding-box centers)
2. Too few frames: interpolate alpha-blend between adjacent frames to double 4->8 frames
"""
from PIL import Image
import numpy as np
import os

building_dir = r"D:\Buildcraft-Epoch\asserts\image\building"
sheets = [
    "home_anim_sheet.png",
    "tower_anim_sheet.png",
    "lumberyard_anim_sheet.png",
    "mine_anim_sheet.png",
    "tavern_anim_sheet.png",
    "research_anim_sheet.png",
]

def split_frames(img, n=4):
    w, h = img.size
    fw = w // n
    return [img.crop((i * fw, 0, (i + 1) * fw, h)) for i in range(n)]

def content_bbox(frame, threshold=30):
    arr = np.array(frame.convert("RGBA"))
    alpha = arr[:, :, 3]
    rows = np.any(alpha > threshold, axis=1)
    cols = np.any(alpha > threshold, axis=0)
    if not rows.any():
        return None
    top    = int(np.argmax(rows))
    bottom = int(len(rows) - np.argmax(rows[::-1]))
    left   = int(np.argmax(cols))
    right  = int(len(cols) - np.argmax(cols[::-1]))
    return (left, top, right, bottom)

def normalize_positions(frames):
    """Shift each frame so its content center aligns to the median center."""
    bboxes = [content_bbox(f) for f in frames]
    valid = [b for b in bboxes if b is not None]
    if not valid:
        return frames

    cx_list = [(b[0] + b[2]) / 2 for b in valid]
    cy_list = [(b[1] + b[3]) / 2 for b in valid]
    target_cx = float(np.median(cx_list))
    target_cy = float(np.median(cy_list))

    fw, fh = frames[0].size
    result = []
    for frame, bbox in zip(frames, bboxes):
        if bbox is None:
            result.append(frame)
            continue
        cx = (bbox[0] + bbox[2]) / 2
        cy = (bbox[1] + bbox[3]) / 2
        dx = int(round(target_cx - cx))
        dy = int(round(target_cy - cy))
        if dx == 0 and dy == 0:
            result.append(frame)
            continue
        shifted = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
        shifted.paste(frame, (dx, dy))
        result.append(shifted)
    return result

def blend_frames(f1, f2, alpha=0.5):
    """Alpha-blend two frames to create an in-between frame."""
    a1 = np.array(f1.convert("RGBA"), dtype=float)
    a2 = np.array(f2.convert("RGBA"), dtype=float)
    blended = (a1 * (1 - alpha) + a2 * alpha).astype(np.uint8)
    return Image.fromarray(blended, "RGBA")

def interleave_frames(frames):
    """Insert a blended in-between frame between each pair -> 4 frames become 8."""
    result = []
    for i in range(len(frames)):
        result.append(frames[i])
        next_i = (i + 1) % len(frames)
        result.append(blend_frames(frames[i], frames[next_i], 0.5))
    return result

for name in sheets:
    path = os.path.join(building_dir, name)
    img = Image.open(path).convert("RGBA")
    w, h = img.size

    frames = split_frames(img, 4)

    # Step 1: normalize positions
    frames = normalize_positions(frames)

    # Step 2: interleave to 8 frames
    frames = interleave_frames(frames)

    # Stitch back
    fw = frames[0].width
    fh = frames[0].height
    sheet = Image.new("RGBA", (fw * len(frames), fh), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * fw, 0))
    sheet.save(path)
    print(f"{name}: {w}x{h} -> {sheet.width}x{sheet.height}  ({len(frames)} frames, frame {fw}x{fh})")

print("Done.")

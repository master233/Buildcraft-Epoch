"""
Align building sprite sheet frames by bottom edge + horizontal center.
Input:  asserts/image/building/building_anim_sheet/*_anim_sheet.png  (8 frames, RGBA)
Output: same files overwritten with aligned frames
"""
from PIL import Image
import numpy as np
import os

building_dir = r"D:\Buildcraft-Epoch\asserts\image\building\building_anim_sheet"
THRESHOLD = 30
N_FRAMES = 8

sheets = [
    "home_anim_sheet.png",
    "tower_anim_sheet.png",
    "lumberyard_anim_sheet.png",
    "mine_anim_sheet.png",
    "tavern_anim_sheet.png",
    "research_anim_sheet.png",
]

def content_bbox(alpha_arr, threshold=30):
    rows = np.any(alpha_arr > threshold, axis=1)
    cols = np.any(alpha_arr > threshold, axis=0)
    if not rows.any():
        return None
    top    = int(np.argmax(rows))
    bottom = int(len(rows) - np.argmax(rows[::-1]))
    left   = int(np.argmax(cols))
    right  = int(len(cols) - np.argmax(cols[::-1]))
    return (left, top, right, bottom)

for name in sheets:
    path = os.path.join(building_dir, name)
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    fw = w // N_FRAMES
    arr = np.array(img)

    # extract frames and compute bboxes
    frames = []
    bboxes = []
    for i in range(N_FRAMES):
        f = img.crop((i * fw, 0, (i + 1) * fw, h))
        alpha = arr[:, i * fw:(i + 1) * fw, 3]
        bbox = content_bbox(alpha, THRESHOLD)
        frames.append(f)
        bboxes.append(bbox)

    # target: max bottom (ground plane), median h-center
    valid = [(i, b) for i, b in enumerate(bboxes) if b is not None]
    if not valid:
        print(f"{name}: no content found, skip")
        continue

    target_bottom = max(b[3] for _, b in valid)
    target_cx = int(np.median([((b[0] + b[2]) // 2) for _, b in valid]))

    # compute per-frame shift needed
    shifts = []
    for bbox in bboxes:
        if bbox is None:
            shifts.append((0, 0))
            continue
        frame_bottom = bbox[3]
        frame_cx = (bbox[0] + bbox[2]) // 2
        dy = target_bottom - frame_bottom  # positive = shift down
        dx = target_cx - frame_cx          # positive = shift right
        shifts.append((dx, dy))

    # determine extra canvas padding needed
    max_down  = max(max(dy, 0) for dx, dy in shifts)
    max_up    = max(max(-dy, 0) for dx, dy in shifts)
    max_right = max(max(dx, 0) for dx, dy in shifts)
    max_left  = max(max(-dx, 0) for dx, dy in shifts)

    new_h  = h + max_down + max_up
    new_fw = fw + max_right + max_left
    # anchor: original frame top-left maps to (max_left, max_up) in new canvas
    ox, oy = max_left, max_up

    aligned = []
    for frame, (dx, dy) in zip(frames, shifts):
        canvas = Image.new("RGBA", (new_fw, new_h), (0, 0, 0, 0))
        canvas.paste(frame, (ox + dx, oy + dy))
        aligned.append(canvas)

    # stitch back
    sheet = Image.new("RGBA", (new_fw * N_FRAMES, new_h), (0, 0, 0, 0))
    for i, f in enumerate(aligned):
        sheet.paste(f, (i * new_fw, 0))
    sheet.save(path)
    print(f"{name}: frame {fw}x{h} -> {new_fw}x{new_h}  (pad L{max_left} R{max_right} U{max_up} D{max_down})")

print("Done.")

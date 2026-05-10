"""
清除升级特效精灵表中的低透明度边缘像素
原因：ADD 叠加模式下，alpha 极低但非零的像素会渲染出方形轮廓
做法：alpha < THRESHOLD 的像素强制置为 (0,0,0,0)
"""
from PIL import Image

PATH      = r"E:\Buildcraft-Epoch\asserts\fx\building_anim_sheet\build_lv_up_anim_sheet.png"
THRESHOLD = 20   # 0~255，低于此值的像素视为透明背景

img = Image.open(PATH).convert("RGBA")

try:
    import numpy as np
    arr = np.array(img)
    mask = arr[:, :, 3] < THRESHOLD
    arr[mask] = [0, 0, 0, 0]
    img = Image.fromarray(arr, "RGBA")
except ImportError:
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            if px[x, y][3] < THRESHOLD:
                px[x, y] = (0, 0, 0, 0)

img.save(PATH, "PNG")
print(f"Done — zeroed pixels with alpha < {THRESHOLD}  →  {PATH}")

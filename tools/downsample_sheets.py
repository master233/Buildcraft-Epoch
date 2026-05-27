"""Downsample role/monster sprite sheets to half height (512→256).

Sheets are horizontal frame strips of N frames. We compute target size as
(width/2, height/2) preserving frame count. Uses LANCZOS for quality.
"""
from PIL import Image
import glob
import os
import sys

TARGETS = [
    'asserts/image/role/role*_*_sheet.png',
    'asserts/image/monster/role*_sheet.png',
]

def main():
    files = []
    for pat in TARGETS:
        files.extend(sorted(glob.glob(pat)))
    print(f'Found {len(files)} sheets')
    total_before = 0
    total_after = 0
    for f in files:
        before = os.path.getsize(f)
        total_before += before
        img = Image.open(f)
        if img.mode != 'RGBA':
            img = img.convert('RGBA')
        w, h = img.size
        new_size = (w // 2, h // 2)
        resized = img.resize(new_size, Image.Resampling.LANCZOS)
        resized.save(f, optimize=True)
        after = os.path.getsize(f)
        total_after += after
        print(f'  {os.path.basename(f):40s} {w}x{h} -> {new_size[0]}x{new_size[1]}  {before//1024}KB -> {after//1024}KB')
    print(f'\nTotal: {total_before/1024/1024:.1f} MB -> {total_after/1024/1024:.1f} MB '
          f'(saved {(total_before-total_after)/1024/1024:.1f} MB)')

if __name__ == '__main__':
    main()

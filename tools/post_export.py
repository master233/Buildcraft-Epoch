"""导出 Web 后的后处理：
1. 把 web_head_include.html 注入到 bin/index.html 的 </head> 之前
2. 生成 bin/loader_bg.jpg 和 bin/loader_logo.png（HTML 加载层用）
3. 将 index.pck 拆分为多个 <50MB 的 chunk（适配 GitHub Pages）
"""
from pathlib import Path
from PIL import Image
import json

ROOT = Path(__file__).resolve().parent.parent
BIN = ROOT / "bin"
INDEX = BIN / "index.html"
HEAD_INCLUDE = ROOT / "web_head_include.html"

# ---- 1. 注入 head_include ----
if not INDEX.exists():
    raise SystemExit(f"ERROR: {INDEX} not found, run export first")
if not HEAD_INCLUDE.exists():
    raise SystemExit(f"ERROR: {HEAD_INCLUDE} not found")

html = INDEX.read_text(encoding="utf-8")
inject = HEAD_INCLUDE.read_text(encoding="utf-8")
marker_begin = "<!-- BCE_HEAD_INJECT_BEGIN -->"
marker_end = "<!-- BCE_HEAD_INJECT_END -->"

# 移除旧注入块（如果有）
if marker_begin in html and marker_end in html:
    pre, _, rest = html.partition(marker_begin)
    _, _, post = rest.partition(marker_end)
    html = pre + post

block = f"\n{marker_begin}\n{inject}\n{marker_end}\n"
if "</head>" not in html:
    raise SystemExit("ERROR: </head> not found in index.html")
html = html.replace("</head>", block + "</head>", 1)

# ---- 1b. 在 onProgress 回调中注入 __bce_download_progress 更新 ----
OLD_ON_PROGRESS = "'onProgress': function (current, total) {"
NEW_ON_PROGRESS = "'onProgress': function (current, total) {\n\t\t\t\t\tif (current > 0 && total > 0) { window.__bce_download_progress = current / total; }"
if OLD_ON_PROGRESS in html:
    html = html.replace(OLD_ON_PROGRESS, NEW_ON_PROGRESS, 1)
    print("  patched onProgress to update __bce_download_progress")

INDEX.write_text(html, encoding="utf-8")
print(f"  injected head_include into {INDEX.name}")

# ---- 2. 生成 loader 资源 ----
bg_src = ROOT / "asserts" / "image" / "backgroud" / "bg_test_1.jpg"
logo_src = ROOT / "asserts" / "image" / "ui" / "logo.png"

bg = Image.open(bg_src)
tw, th = 1280, 720
sr = bg.width / bg.height
tr = tw / th
if sr > tr:
    nw, nh = int(th * sr), th
else:
    nw, nh = tw, int(tw / sr)
bg = bg.resize((nw, nh), Image.Resampling.LANCZOS)
left = (nw - tw) // 2
top = (nh - th) // 2
bg = bg.crop((left, top, left + tw, top + th))
bg.save(BIN / "loader_bg.jpg", quality=78, optimize=True)
print(f"  generated bin/loader_bg.jpg ({(BIN / 'loader_bg.jpg').stat().st_size // 1024} KB)")

logo = Image.open(logo_src)  # 1024 原图，避免缩放后浏览器再拉伸导致模糊
logo.save(BIN / "loader_logo.png", optimize=True)
print(f"  generated bin/loader_logo.png ({(BIN / 'loader_logo.png').stat().st_size // 1024} KB)")

btn_src = ROOT / "asserts" / "image" / "ui" / "btn_start.png"
if btn_src.exists():
    btn = Image.open(btn_src)
    btn.save(BIN / "loader_btn.png", optimize=True)
    print(f"  generated bin/loader_btn.png ({(BIN / 'loader_btn.png').stat().st_size // 1024} KB)")

# 复制中文字体（与 LoadingScreen 进度条字体一致）
import shutil
font_src = ROOT / "asserts" / "fonts" / "ZCOOLKuaiLe.ttf"
if font_src.exists():
    shutil.copy(font_src, BIN / "loader_font.ttf")
    print(f"  copied bin/loader_font.ttf ({(BIN / 'loader_font.ttf').stat().st_size // 1024} KB)")

# ---- 3. 拆分 index.pck 为多个 chunk（适配 GitHub 100MB 限制）----
CHUNK_SIZE = 50 * 1024 * 1024  # 50MB per chunk
pck_file = BIN / "index.pck"
if pck_file.exists():
    total_size = pck_file.stat().st_size
    chunks = []
    with open(pck_file, "rb") as f:
        idx = 0
        while True:
            data = f.read(CHUNK_SIZE)
            if not data:
                break
            chunk_name = f"index.pck.{idx:02d}"
            chunk_path = BIN / chunk_name
            chunk_path.write_bytes(data)
            chunks.append(chunk_name)
            idx += 1
    manifest = {"chunks": chunks, "totalSize": total_size}
    (BIN / "index.pck.manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    pck_file.unlink()
    print(f"  split index.pck ({total_size // 1024 // 1024} MB) into {len(chunks)} chunks")
else:
    print("  WARN: index.pck not found, skipping split")

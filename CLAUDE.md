# CLAUDE.md

本文件为 Claude Code（claude.ai/code）提供在此代码仓库中工作的指引。

## 项目概览
BuildcraftEpoch — 2D 模拟经营 + 肉鸽养成
- 引擎：Godot 4.6，目标平台：**HTML5（浏览器直接运行）**
- 渲染：GL Compatibility；物理：Jolt Physics
- 分辨率：1280×720，拉伸模式：`canvas_items`

## 构建与运行

**导出为 HTML5**（需要 Godot 在 PATH 中，或通过 Steam 安装在 C/D/E 盘）：
```
export.bat
```
输出到 `bin/` 目录。脚本会自动从 PATH 检测 Godot，找不到则依次检索 C/D/E 盘的 Steam 路径。

**在本地运行导出的游戏：**
```
bin\start.bat
```
启动 `bin/server.ps1`——一个 PowerShell HTTP 服务器，自动附带 WebAssembly SharedArrayBuffer 所需的 `Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy` 响应头。默认在浏览器打开 `http://127.0.0.1:8089`。

**在编辑器中运行：** 用 Godot 4.6 打开 `project.godot`，按 F5。

## 架构说明

### 场景流程
- **入口**：`scenes/TitleScreen.tscn` + `TitleScreen.gd` — Logo 动画 + 开始按钮，点击后切换到 Main
- **核心玩法**：`scenes/Main.tscn` + `Main.gd` — 全部游戏逻辑集中在这一个场景

两个场景的 UI 均完全在 GDScript 中构建（`_ready` → `call_deferred("_build_ui")`），`.tscn` 文件只有极少节点。

### 建筑系统（`Main.gd`）
六栋建筑全部定义在 `Main.gd` 顶部的 `BUILDINGS` 常量字典中，每个条目包含：
- `paths[3]` — 各等级静态 PNG
- `anim_sheets[3]` — 横向 8 帧精灵表，用于待机动画
- `pos` — 固定的 `Vector2` 屏幕坐标
- `upgrade_cost[2]` — 1→2 级、2→3 级各自消耗的木材和矿石
- `produces` — `"wood"`、`"ore"` 或 `""`（不产出）

运行时状态存储在 `_building_nodes` 字典中，按建筑名索引，包含 `level`、`sprite` 节点、`label` 节点。

**文件命名特例**：`Mine` 和 `Tavern` 的资源文件名首字母大写（`Mine1.png`、`Tavern1.png`），其余建筑全部小写。

### 资源与生产
- 资源变量：`_wood`、`_ore`、`_gold`（均为 int，位于 `Main.gd`）
- 生产每 `PRODUCE_INTERVAL = 5.0` 秒触发一次（在 `_process` 中计时）
- 各等级每次产出量：`PRODUCE_RATES = [3, 6, 12]`（仅伐木场产木材，矿石场产矿石）
- 升级限制：非主基地建筑的等级不能超过主基地等级

### 输入处理
点击检测完全用手动距离/矩形判断——无 Area2D 或物理体：
- 建筑命中半径：`distance_to(建筑坐标) < 80.0`
- 面板矩形（`_panel_rect`、`_upgrade_rect`、`_close_rect`）在每次打开时通过 `_reposition_panel` 重算，确保不超出屏幕边界

### 存档 / 读档
每次生产触发或升级后将 JSON 写入 `user://savegame.json`。数据结构：`{wood, ore, gold, levels: {建筑key: int}}`。点击"重置游戏数据"按钮会删除该文件。

### 精灵表
建筑使用 `AnimatedSprite2D`，`SpriteFrames` 在运行时从横向 8 帧精灵表动态构建。缩放比例以 1 级静态 PNG 为基准，保证各等级视觉大小一致。升级特效使用 6×2 网格精灵表（`build_lv_up_anim_sheet.png`），叠加模式为 Additive。

### 资源目录
资源文件夹拼写为 **`asserts/`**（非 `assets/`）。主要子目录：
- `asserts/image/building/building_template/` — 各等级静态 PNG
- `asserts/image/building/building_anim_sheet/` — 待机动画精灵表
- `asserts/image/ui/` — UI 贴图（面板、按钮、图标）
- `asserts/fonts/` — ZCOOLKuaiLe.ttf（主显示字体）、NotoSansSC.ttf
- `asserts/fx/building_anim_sheet/` — 升级特效精灵表
- `asserts/image/animal/` — 鸟类、松鼠精灵表
- `bin/` — 导出的 Web 构建产物（HTML/WASM/PCK），不要手动修改

### 图像处理工具
`tools/` 目录下是用于美术资源流程的独立 Python（PIL）脚本。脚本内路径**硬编码**为 `D:\Buildcraft-Epoch\...`，如果项目在其他盘需先修改路径。

## 设计文档
- 完整 GDD：`docs/GDD.md`
- 美术风格规范：`docs/art_style_guide.md`
- 建筑 key → 文件名对照：`docs/building_assets.md`

## AIART 使用规范（必须遵守）
- `taskType` 必须是 `multiEdit`，禁止使用 `general` / `chat`
- `positivePrompt` 必须包含以下关键词（每次生成美术资源都必须加，缺一不可）：
  - `transparent background, PNG` — 透明背景
  - `centered character` — 角色/建筑居中，防止帧间位移
  - `same scale` — 每帧比例一致，防止大小变化
  - `fixed camera` — 固定镜头视角
  - `no camera movement, no zoom` — 禁止推拉镜头
  - `consistent framing` — 构图一致
- `negativePrompt` 必须包含 `white background, solid background, background scenery`
- 禁止生成后再调 AIART 的 `removeBackground` 任务，一步到位生成带透明通道的图片
- 收到结果后立即用 PIL 验证 alpha：`Image.open(path).mode == 'RGBA'` 且四角像素 alpha=0；AIART 即使 prompt 写了 transparent 也可能返回 RGB

### 角色序列帧生成规则（白色背景视频）
**重要：用户提供的所有角色视频背景都是纯白色，必须使用以下流程，禁止使用 rembg**

标准流程（12 帧，目标尺寸 512×512）：
1. **询问截取时间段**：必须先询问用户提供视频截取时间段（例如 "2-4 秒"）
2. **提取原始帧**：
   ```bash
   ffmpeg -i "视频路径" -ss 起始秒 -to 结束秒 -vf "fps=12/时长,scale=-1:-1" -vsync 0 "输出路径/frame_%02d.png"
   ```
3. **备份原始帧**：
   ```bash
   mkdir -p 备份目录 && cp 原始帧*.png 备份目录/
   ```
4. **直接去白色背景**（**禁止使用 rembg**，白色背景用颜色距离算法即可）：
   ```bash
   python tools/remove_solid_bg.py 原始帧*.png --hard 30 --soft 55
   ```
5. **合并为精灵表并缩放到 512 高度**：
   ```python
   from PIL import Image
   import glob
   frames = sorted(glob.glob('原始帧*.png'))
   imgs = [Image.open(f) for f in frames]
   w, h = imgs[0].size
   sheet = Image.new('RGBA', (w * len(imgs), h), (0, 0, 0, 0))
   for i, img in enumerate(imgs):
	   sheet.paste(img, (i * w, 0))
   scale = 512 / h
   new_w = int(w * len(imgs) * scale)
   resized = sheet.resize((new_w, 512), Image.Resampling.LANCZOS)
   resized.save('角色_alert_sheet.png')
   ```
6. **更新配置表**：在 `asserts/table/roles.txt` 中添加 `alert_sheet` 路径和参数（12 帧，12 fps）

**为什么不用 rembg**：
- rembg 的 AI 模型会把接近白色的物体（如弓箭、浅色装备）误判为背景去除
- 纯白背景用简单的颜色距离算法（`remove_solid_bg.py`）更可靠、更快

## 透明背景兜底脚本：`tools/remove_solid_bg.py`
当 AIART 输出意外带纯色（近白）背景时，**用本脚本本地补 alpha，不要写一次性 PIL 代码**：

```bash
python tools/remove_solid_bg.py <png_path> [<png_path> ...] [--hard 10] [--soft 28]
```

- 自动取四角像素均值作为 bg 颜色
- `--hard`（默认 10）：颜色距离 ≤ hard 的像素全透明
- `--soft`（默认 28）：颜色距离 ≥ soft 的像素全不透明，中间线性渐变
- **AIART 输出实测默认值偏弱**，会留下 alpha=1-50 的薄雾残留。推荐 `--hard 30 --soft 55`
- 处理后必须执行 `--headless --import` 让 Godot 重新导入 PNG，alpha 才会生效
- 验证：处理后用 PIL 查 alpha 直方图，1-50 区间应该 < 1 万像素，否则继续提高 hard

## rembg 脚本：`tools/remove_bg.py`
用于复杂背景的建筑序列图（U2Net AI 模型，慢但效果好）。UI 小图标用 `remove_solid_bg.py` 即可。

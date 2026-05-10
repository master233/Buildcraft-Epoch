# BuildcraftEpoch - 项目概览

## 游戏定位
2D 模拟经营 + 肉鸽养成

## 技术栈
- Godot 4.6
- 目标平台：**HTML5（浏览器直接运行）**
- 渲染：GL Compatibility（适合 Web）
- 物理：Jolt Physics

## 核心设计文档
- 详细设计见 `docs/GDD.md`

## 建筑系统（速览）
6 栋建筑，每栋 3 个等级，升级消耗木材 + 矿石。
主基地等级限制其他建筑的最高等级。

## 美术风格（必须遵守）
- 等距视角（Isometric 2.5D），45° 斜上方俯视
- 风格化 3D 卡通渲染，参考 Clash of Clans 画风
- 主色：钴蓝、暖棕、原木色；强调色：金黄、冰蓝、紫罗兰
- 光源统一来自左上方
- 建筑底部必须有石砌地基平台，透明背景 PNG
- 详细规范见 `docs/art_style_guide.md`

## 当前阶段
设计阶段，尚未开始编码。

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

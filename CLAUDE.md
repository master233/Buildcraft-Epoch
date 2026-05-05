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
- 禁止生成后再调 `removeBackground`，一步到位生成带透明通道的图片

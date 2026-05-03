# BuildcraftEpoch 美术风格规范

> 所有游戏美术资源必须遵循本规范，以保证视觉风格一致性。
> 参考基准：`asserts/image/building/building_levels.png`

---

## 视角与透视

- **等距视角（Isometric 2.5D）**，摄像机角度约 45°斜上方俯视
- 建筑/物体的正面、侧面、顶面三个面均可见
- 所有资源必须使用相同的等距投影角度，不得混用正交或其他视角

---

## 渲染风格

- **风格化 3D 卡通渲染**，介于 3D 写实与手绘插画之间
- 有明显的体积感和厚度，但不追求照片级写实
- 轮廓清晰，边缘干净，无过度模糊或噪点
- 整体质感接近 Clash of Clans / Hay Day 等移动策略游戏

---

## 色彩规范

### 主色调
| 用途 | 颜色描述 |
|------|----------|
| 建筑主色 | 深蓝（钴蓝/海军蓝）、暖棕、原木色 |
| 屋顶/穹顶 | 钴蓝、石板蓝、金属灰蓝 |
| 石材/地基 | 暖灰、米黄、砂岩色 |
| 木材 | 橙棕、深棕、原木黄 |

### 强调色
| 用途 | 颜色描述 |
|------|----------|
| 魔法/能量 | 亮蓝、冰蓝、蓝白发光 |
| 金属装饰 | 金黄、铜色 |
| 特殊建筑 | 紫罗兰、酒红 |

### 禁止
- 禁止使用大面积高饱和荧光色
- 禁止使用暗沉、脏污的配色
- 整体色调保持明亮、饱和、温暖

---

## 光照规范

- 光源来自**左上方**，统一方向
- 顶面最亮，左侧面次亮，右侧面最暗（受阴影）
- 建筑顶面有柔和高光反射
- 魔法/发光元素允许使用自发光蓝色光晕
- 每个建筑底部有轻微投影（drop shadow），不宜过重

---

## 材质与细节

- 所有材质需有**可辨认的纹理**：石块缝隙、木纹、砖纹、金属铆钉等
- 建筑上需有装饰细节：旗帜、窗户、门、灯笼、招牌、栅栏等
- 建筑底部必须有**石砌/泥土地基平台**，不能直接悬浮在背景上
- 允许添加少量周边装饰：植物、木桶、箱子、花朵等，增加生活感

---

## 建筑等级规范

- 同一建筑的三个等级，外观应有**明显差异**：
  - **1 级**：简陋、材料粗糙、体积较小
  - **2 级**：材料升级、增加结构、加入装饰元素
  - **3 级**：宏伟精致、多层结构、魔法/机械元素、最丰富的细节
- 每一级升级后应比上一级在视觉上有**明显的质感和规模提升**

---

## 尺寸规范

- 建筑图片使用**透明背景 PNG**
- 建筑主体居中，四周留适量透明边距（约 10% 左右）
- 各建筑之间保持相对一致的比例关系，避免大小悬殊

---

## AI 生成规范

### 调用方式
**必须使用 `multiEdit` 模式**，`general` 模式在当前环境无效。

调用示例（通过 mcp__aiart__create_image_task）：
```json
{
  "taskType": "multiEdit",
  "positivePrompt": "...",
  "negativePrompt": "...",
  "referenceImages": [
    { "purpose": "source", "imageId": "<已上传的参考图ID>", "weight": 0.6 }
  ],
  "waitForCompletion": true
}
```

参考图上传使用 `mcp__aiart__upload_file`，`businessType: 8`（reference/style image）。

### 正向提示词模板

生成新资源时，建议在提示词中包含以下关键词：

```
isometric 2.5D, medieval fantasy, stylized 3D cartoon rendering,
warm vibrant colors, cobalt blue roof, wooden brown structure,
soft top-left lighting, detailed textures, stone base platform,
mobile strategy game art style, Clash of Clans style,
transparent background, high quality game asset
```

### 负向提示词模板
```
realistic photo, dark gloomy, blurry, flat 2D, top-down only,
neon colors, oversaturated, sketch, watermark
```

---

## 禁止事项

- 禁止混用其他画风（像素风、写实风、扁平风）
- 禁止使用与等距视角不符的正面/背面视角资源
- 禁止使用与现有建筑比例严重不符的资源
- 禁止使用无地基直接悬浮的建筑素材

# 建筑图片对应关系

| 建筑 key | 显示名 | 图片文件 | 外观描述 |
|---------|-------|---------|---------|
| home | 主基地 | home1/2/3.png | 城堡式主建筑，蓝色屋顶，两侧有树 |
| tower | 远征塔 | tower1/2/3.png | 圆形瞭望塔，顶部飘扬蓝色旗帜 |
| lumberyard | 伐木场 | lumberyard1/2/3.png | 木屋/锯木厂，暖棕色木质结构 |
| mine | 矿石场 | Mine1/2/3.png | 矿洞入口，两侧有蓝色水晶矿石 |
| tavern | 酒馆 | Tavern1/2/3.png | 木质酒馆，门口有遮阳棚和酒桶 |
| research | 研究院 | research1/2/3.png | 圆顶天文台，顶部装有望远镜 |

## 注意

- 文件路径：`res://asserts/image/building/`
- Mine 和 Tavern 文件名首字母大写（`Mine1.png`、`Tavern1.png`），其余全小写
- 每栋建筑有 3 个等级图片，等级升级时在代码里切换 `sprite.texture`

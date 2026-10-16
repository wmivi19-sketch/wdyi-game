# 地名驱动地貌（Godot 4）

运行游戏后按 Y 打开世界地图，点击左上角「地名地貌」。也可以在编辑器打开 `scenes/ui/named_terrain.tscn` 按 F6 独立运行。

选择地名，修改名称或种子，点击「生成地貌 / 更新标签」。左侧显示原世界地图及清理后的名称，右侧 TextureRect 显示选中区域的新地貌。改名和标签更新仅在当前面板会话生效；关闭重开恢复 JSON。本工具不改变现有地图 ID、存档、碰撞、玩家位置或旧底图。

## 配置

`resources/maps/named_regions.json` 手工录入地名及原图 1536×1024 像素坐标。以用户文字中的名称为准；图片字形与文字若有出入，在此修改 `name`。不调用 OCR 或外部图片 API。

- `world_seed`：世界种子；同一名称和种子产生相同地貌。
- `regions[].name`：原名称；仅用 `strip_edges().trim_suffix("大陆")` 删除末尾后缀，「大陆架」等保留。
- `regions[].terrain`：可选规则覆盖，支持 ice / forest / mountain / desert / mystic / marsh / plains。改名时重新匹配语义。
- `regions[].position`：左侧标签的原图坐标。
- `preview_polygon`：默认示例边界，点坐标归一化到 0..1；每个区域可以设置自己的 `polygon` 覆盖。

截图红线未闭合，不能用作精确海岸遮罩。这版提供独立地貌预览，不自动将矩形色块覆盖在原图上。需要精确替换原图局部时，先校准每个区域的闭合多边形及目标 Rect2，再将生成纹理贴到对应位置。区域外的纹理像素透明，地形底色本身不透明。

## 代码接口

```gdscript
const Terrain = preload("res://scripts/NamedTerrain.gd")
var name = Terrain.clean_location_name("索坦瑞大陆")
var image = Terrain.generate(name, 42, 256, normalized_polygon)
$TextureRect.texture = ImageTexture.create_from_image(image)
```

这是显式词义规则与 FastNoiseLite 的基础生成逻辑，不是语言模型推理，也不是对原手绘线稿的智能重绘。北冥/索坦瑞对应冰雪、神赐山脉对应山地，方丈/维洛斯对应秘境；未知名称回退平原。山地使用脊状噪声，其他类型使用对应的分层色带。新增词义规则在 `NamedTerrain.NAME_RULES` 中配置。等高线使用褪色墨褐色以 0.8 系数与底色混合。

验证：`godot --headless --path . --script res://tests/NamedTerrainTest.gd`，覆盖后缀保护、词义规则、生成可复现性、种子差异、透明遮罩及界面标签更新。

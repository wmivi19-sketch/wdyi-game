# 双地图：大陆概览与箱庭区域图

Godot 4.3+。已接入当前地图、真实角色、统一玩家面板和职业系统。

## 运行与操作

打开本目录 project.godot，F5 运行原游戏。

- Y：打开/关闭六大陆世界概览，使用用户上传的1536×1024原图。
- M：打开/关闭当前区域详细地图（默认2048×2048占位背景）。
- 左键拖动 / 单指拖动：平移；鼠标滚轮或放大/缩小按钮缩放。
- 重置：恢复窗口适配比例和地图中心。
- Esc / 关闭按钮：返回游戏。
- Tab/B：从地图切换回统一玩家窗口；Y/M也可以从玩家窗口直接切到地图。

两个地图互斥，缩放与平移分别保存。地图窗口打开时阻止移动及地图/时间热键穿透，游戏模拟本身继续运行。关闭后使用原有WASD移动、1–6切大陆、N键推进时间。

互动演示场景：scenes/test/test_dual_maps.tscn。它使用真正的MapDemo与可移动角色，Y/M打开查看，不另外模拟玩家或背包。

## 地图范围和坐标

沿用现有大陆编号 continent_0 至 continent_5，对应按键1–6。大陆边界和POI由 resources/maps/continents.json 配置，区域由 areas.json 配置。

配置坐标采用 **MapLoader局部像素坐标**：左上角为原点，X向右、Y向下。格子中心 = (格子坐标+0.5)×tile_size。运行时自动换算加载器的全局偏移、缩放和旋转，不要把MapLoader.position再次加进配置。

大陆与区域各自使用自己的bounds。默认每个大陆有完整区域 area_0 至 area_5；余烬大陆的 area_volcano、古木大陆的 area_forest 为200×200子区域示例。角色进入多个重叠区域时，选择面积最小的包含区域；否则使用大陆default_area。

GameState新增 current_continent、current_area、player_world_position、current_map_bounds 与 current_area_bounds。后两者是全局AABB，查看器实际换算使用各图局部边界。**current_area不会覆盖player_location**，因此原合成和交易的祭坛/市场位置条件仍有效。地图成功加载后才更新身份，失败的切图请求不会更换当前图。

## 无美术资源也可运行

地图资源加载顺序：texture_path正式资源 → placeholder_path可选占位文件 → 自动生成纯色ImageTexture。

占位背景上使用现有MapLoader地形数据绘制色块。大陆图粗采样显示概览；区域图逐格显示地形、墙体与网格。标记缺图时生成彩色方块，附文字标签；重叠POI文字自动避让。正式底图成功加载后不再覆盖生成地形。

两种查看器各用独立World2D/SubViewport，UI覆盖层不跟随缩放。地图关闭时关闭视口渲染；纹理仅在打开对应地图时加载；缓存数量在JSON中限制。标记节点按ID复用，玩家点每帧更新，NPC/敌人/宝箱按配置间隔更新。

目前采用整图按需加载，适合当前50×50地图，未实现超大世界分块流式加载。支持不超过4096像素的生成背景；新增大型图时建议先控制纹理缓存和区域划分。

## 美术路径和替换

```text
assets/maps/continents/continent_0.png ... continent_5.png
assets/maps/local/area_0.png ... area_5.png
assets/maps/local/area_volcano.png
assets/maps/local/area_forest.png
assets/maps/placeholders/                  # 可选占位PNG
assets/icons/markers/player_marker.png
assets/icons/markers/npc_marker.png
assets/icons/markers/enemy_marker.png
assets/icons/markers/chest_marker.png
assets/icons/markers/exchange_marker.png
assets/icons/markers/altar_marker.png
assets/icons/markers/portal_marker.png
assets/icons/markers/artifact_marker.png
assets/icons/placeholders/                # 保留给后续图标资源
```

把正式PNG放入上述路径并让Godot导入，或修改JSON中的texture_path；不必改脚本。图标路径由map_settings.json的marker_paths配置。贴图左上角必须对应bounds.begin，右下角对应bounds.end；建议图片宽高比与地图边界一致。缺文件、空路径或非Texture2D资源会回退，占位逻辑不会崩溃。

continents.json、areas.json、map_settings.json支持内容哈希热重载，验证失败时保留上一个有效版本。替换图片但不改JSON时，重新打开工程或调用MapDatabase.reload()清除缓存。

## POI和动态实体

大陆POI合并JSON配置与现有地图的真实特殊地点。区域NPC/敌人/宝箱支持JSON条目；当前敌人、宝箱和规划传送门是**地图标记示例**，不新增战斗、开箱或传送玩法。

动态Node2D分别加入map_npcs、map_enemies或map_chests组；可设置元数据map_marker_id（唯一字符串）、map_marker_name（显示名）、continent_id（所属大陆）。控制器读取真实全局位置，移除或隐藏实体后标记自动消失。持久实体应显式提供continent_id，避免跨大陆显示。

## 文件与测试

- scenes/ui/map_system.tscn：双地图UI、独立视口、标题/图例/信息/罗盘/缩放按钮。
- scripts/ui/map_system.gd：热键、互斥、缩放锚点、拖拽、状态同步。
- scripts/ui/map_canvas.gd、map_terrain.gd：坐标映射、地形和标记。
- scripts/data/map_database.gd：JSON验证、查询、热重载、纹理容错与缓存。
- resources/maps/*.json：六大陆、八区域及显示配置。
- tests/DualMapTest.gd、同名tscn：自动化回归。

```powershell
# 首次导入
godot --headless --path . --editor --import --quit
# 双地图46项测试
godot --headless --path . res://tests/DualMapTest.tscn
# 含可移动角色的交互演示
godot --path . res://scenes/test/test_dual_maps.tscn
# 使用真实渲染器生成三张截图
godot --path . res://tests/DualMapTest.tscn -- --capture-maps
# 原功能回归
godot --headless --path . res://tests/PlayerPanelTest.tscn
godot --headless --path . --script res://tests/ProgressionIntegrationTest.gd
godot --headless --path . res://tests/ItemWorldIntegrationTest.tscn
```

截图生成到 .validation/map-continent.png、map-local.png、map-narrow.png。触摸通过InputEvent模拟验证，尚未在实际触屏设备测试。修改前文件保存在shop-and-object/backups/before-dual-maps中。

## 已接入上传的世界原图

世界图位于 assets/maps/world/world_atlas.png，保持上传原文件字节不变。Y显示整张六大陆世界，M仍是当前区域的精细图，碰撞和行走地形沿用原数据。可直接运行 scenes/test/test_world_atlas.tscn，打开即查看原图，Esc回到游戏。

resources/maps/atlas.json 管理原图参考尺寸、各大陆校准矩形及名称位置。对应关系为：左上余烬大陆、右上霜冠大陆、左中烈日沙洲、右中古木大陆、左下交汇大陆、右下翠绿大陆。所有大陆POI均按所属大陆校准后显示；当前大陆额外标注“当前”，玩家点随真实角色位置变化。

**手绘图与现有方格地形并非逐像素对应。** 当前采用可配置的矩形比例映射，后续可调整各region的rect和label_position进行校准；没有从图片自动生成碰撞或可行走海岸线。更换同内容的高分辨率图片时可保留参考尺寸，绘制层会自动换算到实际纹理像素。若更换图案布局，则需重新校准各大陆矩形。

原图不可用时生成相同比例背景，区域地图仍正常工作。atlas.json也参与配置热重载与整体验证。不存在的大陆、越界校准或负尺寸不会覆盖有效配置。

```powershell
godot --headless --path . res://tests/WorldAtlasTest.tscn
godot --path . res://tests/WorldAtlasTest.tscn -- --capture-atlas
godot --path . res://scenes/test/test_world_atlas.tscn
```

WorldAtlasTest包含43项检查；渲染截图生成到 .validation/world-atlas.png。原图SHA256保存在atlas.json中，测试验证上传文件在运行前后未发生改变。

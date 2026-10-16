全局管理与按键切换接入说明、完整源码索引及编辑器设置见 [INTEGRATION.md](INTEGRATION.md)。当前默认演示使用 continent_0 至 continent_5：1–6 切换，空格推进时间。

# 六大陆数据驱动地图系统

使用 Godot 4.3 或更高版本打开本目录的 `project.godot`，按 F6/F5 运行演示。选择大陆后，用 WASD 或方向键移动白色角色。水域、山脉、熔岩阻挡移动。

## 文件与数据约定

- `data/maps/`：六份独立 JSON；大陆名称暂用翠绿、烈日沙洲、霜冠、古木、余烬、交汇，可按世界观修改。
- `scripts/MapLoader.gd`：校验 JSON 后创建 TileMapLayer、TileSet 碰撞、资源 Area2D、特殊地点 Area2D。加载失败发出 `load_failed`，保留原地图。
- `scripts/MapDemo.gd` / `scenes/MapDemo.tscn`：切换与移动演示。
- `tests/MapLoaderTest.gd`：六图加载、单元格数量、节点类型及地形碰撞检查。

`res://` 指本目录项目根。`terrain_rows` 每字符代表一个格子，行数等于 height，字符数等于 width。坐标 cell 和 spawn 为从零开始的 [列, 行]。tile_size 为像素尺寸。terrain_types 将字符映射到唯一 id、颜色和 solid。整个系统无随机数、噪声或随机地图生成；程序仅将明确配置转换为节点。演示色块图集由配置颜色创建，后续可在 `_build_tileset` 替换为美术图集。

资源配置包含 id、kind（ore/herb/wood）、name、cell、amount。特殊地点包含 id、kind（artifact/altar/market）、name、cell、radius。生成节点的 `map_data` 元数据保留完整配置，同时加入对应类别分组。amount 是数据，采集扣除及神器/交易/仪式业务由游戏系统接入。

碰撞层：1 地形，2 玩家，4 特殊地点，8 资源点。角色的 collision_layer 必须包含 2，collision_mask 包含 1。特殊地点通过 location_entered/location_exited 发出 ID、类别及进入/离开的物体。资源点可连接自身 body_entered 信号。地图更换应在物理回调外进行；在回调中使用 call_deferred。

加载调用示例：

```gdscript
var loader = preload("res://scripts/MapLoader.gd").new()
add_child(loader)
if loader.load_map("emerald"):
    player.position = loader.to_global(loader.spawn_position)
```

命令行验证（将 godot 替换为本机可执行文件路径）：

```text
godot --headless --path . --editor --quit
godot --headless --path . res://tests/MapLoaderTest.tscn
```


## 可移动角色与模块化外观

`scenes/Player.tscn` 可直接实例化。角色使用 16×16 Sprite2D 纯色占位图、12×12 固定碰撞体、WASD/方向键移动与 Camera2D 平滑跟随。换装不会改变碰撞范围或速度。地图演示已使用此场景，大陆切换会重置相机平滑，避免跨大陆缓慢漂移。

三个视觉层 `BaseBody`、`Outfit`、`Accessory` 按顺序叠加。`scripts/AppearanceManager.gd` 读取 `data/skins.json`。示例职业为 default、warrior、mage、ranger；将图片放到相应 `assets/skins/<职业>/` 目录，配置各层的 path、hframes 和 vframes 即可。静态图设置 1×1；动画图默认 4 列×4 行，各行为下、左、右、上，可修改 direction_rows。每一层使用自身帧数，建议同职业各层保持相同帧布局和画布尺寸，透明背景，角色中心对齐。图片尺寸必须能被行列数整除。

缺失身体图片时显示默认方块；缺失衣服或配饰时隐藏该层，保留身体。未知职业回退 default。缺失配置、无效层数据也不会使角色消失。`test_sheet.svg` 是自动测试的图集样本，默认职业不使用它。

`AnimationPlayer` 中由配置创建 walk_down、walk_left、walk_right、walk_up 四段帧动画，移动播放、停止后保留对应方向的第一帧。1×1 占位图同样兼容。物理层沿用地图：角色 layer=2、mask=1。

转职仪式成功后调用：

```gdscript
player.complete_job_ritual("mage")
# 或仅更新外观：
player.update_skin("warrior")
# 也可以直接调用角色下的 AppearanceManager.update_skin(job_name)
```

仪式消耗、任务条件与职业数值由业务系统判定；此处提供完成后的换装入口和 job_changed 信号，不会在进入祭坛时自动转职。

验证命令：

```text
godot --headless --path . --import
godot --headless --path . --script res://tests/PlayerTest.gd
```


## 统一背包与职业面板

Tab / B 打开统一窗口，左右按钮或鼠标/触摸水平滑动切页，Esc 关闭。完整使用、文件结构和测试命令见 [PLAYER_PANEL.md](PLAYER_PANEL.md)。旧职业与成神功能、共享背包和商店均已保留。


## 双地图系统

Y 查看大陆概览，M 查看当前区域细节；支持滚轮缩放、鼠标/单指拖动、实时玩家位置和NPC/敌人/宝箱标记。缺失美术时自动生成色块与文字占位。资源替换、坐标规范与测试说明见 [DUAL_MAPS.md](DUAL_MAPS.md)。


## 上传的六大陆世界原图

Y已改为显示上传的六大陆世界原图，M保留区域细图。直接运行 `scenes/test/test_world_atlas.tscn` 查看，Esc返回原游戏。校准配置见 `resources/maps/atlas.json`；代码检查与本地验证记录见 [ATLAS_VALIDATION.md](ATLAS_VALIDATION.md)。


## 游戏开始界面

项目入口已接入可配置主菜单，包含新游戏、真实存档继续、设置、制作人员与退出。游戏中 F5 保存，F10 保存并返回菜单。封面、Logo、按钮样式和音效通过 JSON 替换，缺资源使用占位或静音。详见 [主菜单与资源替换指南](MAIN_MENU.md)。


## 地图、人物与摄像机比例

统一配置：`resources/config/scale_config.json`。世界位置采用 Godot 像素坐标，32 像素为一个设计单位；人物各层按单帧尺寸缩放到 32×32，碰撞为 32×32，节点原点即人物中心。

大陆／区域图标分别固定为 16×16／24×24 **视口像素**，地图缩放不改变图标显示尺寸。转换公式是 `(世界位置 - 边界起点) / 边界尺寸 × 纹理尺寸`，逆变换使用同一边界。不会假定所有地图的纹理像素与世界坐标 1:1。屏幕转换使用 Camera2D 的画布变换及其逆矩阵；坐标为所属 Viewport 内坐标。

配置中的大陆 10000×10000、纹理 2048×2048，以及区域 2000×2000、纹理 4096×4096 是新地图参考规格。现有六大陆、世界图集和区域继续使用 MapDatabase 的实际边界与原始纹理，避免改变地点位置。大陆适配留白系数 0.9，区域 0.95，窗口变化重新适配。

SmartCamera 用于现有玩家摄像机，游戏模式默认 zoom=1，支持平滑跟随、模式切换和窗口变化；当视口比地图大时居中，避免反向 clamp。既有地图查看器继续使用隔离 SubViewport 的缩放和平移。GameState 只发送位置变化信号，地图按现有频率更新，避免每帧重建标记。

运行 `res://scenes/test/test_scale.tscn` 可用 WASD／方向键移动，切换三种模式，观察 32 像素网格、位置与缩放。可复用标记场景为 `scenes/ui/map_marker.tscn`；MapRenderer 复用现有 MapCanvas 节点布局及数据流程。

美术建议：人物 PNG 透明背景，单帧 32×32，可用四方向各四帧；大陆纹理推荐 2048×2048（每纹理像素约 4.88 世界像素），区域推荐 4096×4096（约 0.49）。人物分层素材需具有相同帧画布与中心；玩家红色、NPC 黄色、交易所蓝色、祭坛紫色、传送门绿色。高分辨率标记按实际纹理尺寸缩到目标显示尺寸，不再重复乘 0.5／0.75。

实际游戏接入：主菜单进入 MapDemo 后创建同一 PlayerController；SmartCamera 跟随真实玩家，地图加载成功时从实际地形尺寸计算全局边界。传送及读档立即更新位置并重置摄像机平滑。双地图场景统一使用 MapRenderer，继续复用既有图集、标记与独立视口。

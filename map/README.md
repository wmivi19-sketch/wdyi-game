全局管理与按键切换接入说明、完整源码索引及编辑器设置见 [INTEGRATION.md](INTEGRATION.md)。当前默认演示使用 continent_0 至 continent_5：1–6 切换，空格推进时间。

职业进阶与成神已接入当前地图主场景。完整操作步骤与接口见 [PROGRESSION.md](PROGRESSION.md)。按 E 采集、领取剧情印记或在祭坛开始仪式；按 Q 释放神力。右侧面板显示职业、半神/神明状态、HP、材料及印记。

人物信息面板默认隐藏，按 Tab 显示/隐藏。控制脚本 `scripts/CharacterInfoUI.gd` 挂载在 `scenes/CharacterInfoUI.tscn` 的 GameUI（CanvasLayer）节点上，通过 `$CharacterInfoPanel` 引用面板；输入使用 `_unhandled_input`，忽略长按重复事件。现有按钮设置为不获取键盘焦点，避免 Tab 被焦点导航消费。

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

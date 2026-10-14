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
godot --headless --path . --script res://tests/MapLoaderTest.gd
```

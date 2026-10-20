# 全局管理与 JSON 地图连接

职业叠加、印记合成、地图祭坛、成神和死亡逻辑现已接入同一主场景，操作步骤见 [PROGRESSION.md](PROGRESSION.md)。

使用 Godot **4.3 或更高的 4.x 版本**打开本目录的 project.godot。本项目使用 TileMapLayer（4.3 引入）；4.0–4.2 无法直接运行此版本。TileMapLayer 是新版单层 TileMap 节点。

## 完整源码
- scripts/GameManager.gd：Autoload，日期从 1 开始，早/中/晚分别为枚举 0/1/2。
- scripts/MapLoader.gd：自动订阅 continent_switched，首次加载当前大陆；load_map_from_json(id) 返回成功与否。
- scripts/MapDemo.gd、scenes/MapDemo.tscn：可运行的按键测试及角色碰撞演示。
- data/maps/continent_0.json 至 continent_5.json：六份完整 50 行、每行 50 个数字的数据。
- tests/ContinentIntegrationTest.gd、同名 tscn：六大陆信号切换、2500 格、资源清理、碰撞多边形和跨天推进验证。
- 原有命名地图和 load_map("emerald") 接口仍可使用。

## Godot 编辑器设置步骤
1. 导入 map/project.godot，确保 res:// 指向 map 目录。
2. 项目 → 项目设置 → 全局/Autoload：路径选择 res://scripts/GameManager.gd，名称 GameManager，启用单例。本项目已经配置，不要重复添加。不要给脚本写 class_name GameManager，以免与单例名称冲突。
3. 打开 scenes/MapDemo.tscn，项目设置 → 应用 → 运行中设置为主场景（本项目已配置），按 F5。
4. 主场景脚本自动创建挂有 MapLoader.gd 的 Node2D 和玩家，无需手动创建 TileSet 或导入图片。
5. 按主键盘 1–6 对应大陆 ID 0–5，按N键推进早→中→晚→次日早；WASD/方向键移动。六张地图底色和障碍位置不同，状态文字显示大陆和日期。
6. 调试 → 可见碰撞形状可以查看墙壁碰撞。玩家 Layer=2、Mask=1；地形 Layer=1、Mask=2。
7. 打开 tests/ContinentIntegrationTest.tscn，按 F6，成功时控制台输出六个 PASS 和时间验证结果并退出。

## JSON 结构

下面是可直接加载的 5×5 小模板；完整 50×50 模板见 continent_0.json，结构相同：

~~~json
{
  "id": "continent_0",
  "name": "翠绿大陆",
  "tile_size": 10,
  "spawn": [1, 1],
  "colors": ["639455", "356b99", "91785c"],
  "terrain": [
    [2, 2, 2, 2, 2],
    [2, 0, 0, 0, 2],
    [2, 0, 1, 0, 2],
    [2, 0, 0, 0, 2],
    [2, 2, 2, 2, 2]
  ],
  "collision_points": [
    [0,0], [1,0], [2,0], [3,0], [4,0],
    [0,1], [4,1], [0,2], [4,2], [0,3], [4,3],
    [0,4], [1,4], [2,4], [3,4], [4,4]
  ],
  "resource_spots": [[3,1], [1,3]]
}
~~~

terrain[y][x] 为地形类型：0 草地、1 水域、2 岩石。颜色可按大陆配置，地形数字本身不决定碰撞；collision_points 是唯一碰撞来源。resource_spots 是资源坐标列表，生成带圆形检测区域的 Area2D，数据保存在 map_data 元数据中。资源与出生点必须处于无碰撞格子。

坐标均为从零开始的 [x,y]，x 向右，y 向下。每格中心像素坐标为 (Vector2(x,y)+Vector2(0.5,0.5))*tile_size。50×50 表示 2500 个格子，tile_size=10 对应 500×500 像素。若想要字面上的 50×50 像素地图，需要 1 像素格子并调整图集边框和角色尺寸，本演示采用常规像素游戏格子尺寸。

加载器先解析并验证整份数据，再清空旧 TileMapLayer，移除旧地图树，创建新地形及资源，避免错误文件导致当前地图消失。碰撞在 TileSet 内生成，不会额外重复创建 StaticBody2D。信号切换使用 deferred 加载，避免物理回调修改碰撞；load_map_from_json 的直接调用应在物理回调外执行。

GameManager 记录请求的大陆 ID。文件加载失败时旧图保留并发出 load_failed，GameManager 的 ID 仍是请求值；正式业务可在失败信号中显示错误或恢复上一个 ID。

## 调用示例
~~~gdscript
GameManager.switch_to_continent(2) # 发信号，加载 continent_2.json
GameManager.next_time_period()
# map_loaded 表示加载完成，再重置玩家：
func on_map_loaded(_map_id: String) -> void:
    player.global_position = loader.to_global(loader.spawn_position)
~~~

## 命令行验证
~~~text
godot --headless --path map --editor --quit
godot --headless --path map res://tests/ContinentIntegrationTest.tscn
godot --headless --path map res://tests/MapLoaderTest.tscn
~~~

从 map 目录运行时将 --path map 改为 --path .。

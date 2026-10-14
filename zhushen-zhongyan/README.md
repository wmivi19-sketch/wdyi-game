# 逐神终焉

独立 Godot 4.x / GDScript 项目。第一阶段实现全局管理系统，主场景为调试面板。
现有目录中的其他 Godot 项目无需修改。

## 运行

用 Godot 4.x 导入本目录的 `project.godot`，按 F6 或 F5 运行。
`GameManager` 已配置为 Autoload，无需手动挂载。
界面可推进时段、重开、修改真人玩家血量、物品与职业。
本阶段不包含 AI 决策、地形地图美术、玩家移动、战斗或存档。

## 规则与默认数据

- 玩家 0 为真人，1–5 为 AI；AI 标记仅表示控制者类型。
- 六块固定大陆：森林、沙漠、雪原、火山、沼泽、山地。名称和出生坐标是可调整的初始设计值。
- 每名玩家初始血量 100、职业未选择、物品栏为空。
- 策略层调用 `advance_period()` 推进时段，无真实时间自动计时。
- 从第 1 天早开始，早 → 中 → 晚，42 次推进后第 14 天晚结束。
- 第 14 天结束进入 ENDGAME；时间保持第 14 天晚，不产生第 15 天。
- 所有存活玩家强制进入终焉大陆，各自有固定、不重叠的落点。
- 死亡玩家不复活、不传送；传送保留职业、血量和物品。
- `spawn_position` / `home_continent_id` 保留原出生数据，当前位置与当前大陆另存。
- 状态查询返回深拷贝；血量、物品和职业应通过管理器接口修改。
- 职业状态可存放技能冷却、职业标记等 bool/int/float/String 数据。
- 物品栏是 `{item_id: 数量}`，本阶段不限制格数，不提供装备与堆叠上限。

## 接口

```gdscript
GameManager.advance_period()
GameManager.get_player(0)
GameManager.get_players()
GameManager.set_profession(0, GameManager.Profession.WARRIOR)
GameManager.set_profession_status(0, "skill_cooldown", 2)
GameManager.damage_player(0, 20)
GameManager.heal_player(0, 10)
GameManager.add_item(0, "wood", 3)
GameManager.remove_item(0, "wood", 1)
```

真实玩家节点进入场景树后注册，使出生、传送、重开同时更新实体：

```gdscript
extends CharacterBody2D
@export var player_id: int = 0

func _ready() -> void:
    GameManager.register_player_body(player_id, self)

func _physics_process(_delta: float) -> void:
    # 移动完成后同步当前位置。
    GameManager.update_player_position(player_id, global_position)

func _exit_tree() -> void:
    GameManager.unregister_player_body(player_id, self)
```

不同大陆地图的加载由后续地图系统监听 `endgame_started` 处理。
管理器先提交全部玩家的目标状态并移动已注册实体，再发送终焉通知。
地图切换后新实体调用注册接口，会使用已记录的终焉落点。
同一同步信号回调内再次推进时间或重开会被拒绝，重开可延迟调用。

血条可监听 `health_changed(player_id, health, maximum)`；库存界面监听
`inventory_changed(player_id, inventory)`；通用 UI 监听 `player_changed`。

## 测试

```powershell
godot --headless --path . --editor --quit
godot --headless --path . res://tests/GameManagerTest.tscn
```

测试覆盖六玩家分配、42 时段边界、死亡处理、血量上限、库存校验、状态快照、
职业状态、实体传送及速度清零、重开恢复和同步重入保护。失败以退出码 1 返回。

已使用官方 Godot 4.4.1 完成导入、自动化测试及主场景无界面启动验证。

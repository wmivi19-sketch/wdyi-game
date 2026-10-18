# 逐神终焉

本目录保留为独立管理器/战斗测试工程。完整游戏（原封面、菜单、地图、背包与战斗）请启动 `../map/project.godot`，说明见 [原地图接入指南](../map/ARPG_INTEGRATION.md)。

独立 Godot 4.x / GDScript 项目。包含全局管理系统和 ARPG 核心战斗系统，主场景为管理面板。
现有目录中的其他 Godot 项目无需修改。

## 运行

用 Godot 4.x 导入本目录的 `project.godot`，按 F6 或 F5 运行。
`GameManager` 已配置为 Autoload，无需手动挂载。
界面可推进时段、重开、修改真人玩家血量、物品与职业。
点击“进入 ARPG 战斗”可打开可移动、可施法的战斗验证场景。
尚不包含 AI 决策、地形地图美术或存档；AI 角色目前是静止测试目标。

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
- 职业状态保留 bool/int/float/String 标记；实际技能冷却由战斗组件管理，勿另存第二份。
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
初始化及时间推进期间，同步信号回调再次推进时间或重开会被拒绝，重开可延迟调用。
`day_finished` 在当天晚结束、切换日期或进入终焉之前同步发送；日结算逻辑应在
该信号的同步回调中完成，以确保第 14 天结算死亡的玩家不会传送。
重开会向六名玩家补发血量、库存及通用状态通知，供已连接的界面刷新。

血条可监听 `health_changed(player_id, health, maximum)`；库存界面监听
`inventory_changed(player_id, inventory)`；通用 UI 监听 `player_changed`。

## 测试

```powershell
godot --headless --path . --editor --quit
godot --headless --path . res://tests/GameManagerTest.tscn
```

测试覆盖六玩家分配、42 时段边界、死亡处理、血量上限、库存校验、状态快照、
职业状态、实体传送及速度清零、重开恢复和同步重入保护。失败以退出码 1 返回。

原全局管理系统曾使用官方 Godot 4.4.1 验证；本次 ARPG 集成的验证版本见下文。

## ARPG 接入与兼容规则

本次集成已使用 Godot 4.7.2 验证。`arpg_core/` 是完整本地模块，无须引用 map 项目，也无新增 Autoload。`GameManager` 为六名玩家各持有一个持久化 `ARPGCharacter`，场景切换不会重建它们。实时物理帧推进资源、效果和冷却，策略日历仍只能通过 `advance_period()` 推进。

- 保留初始 HP 100、原职业枚举、六玩家、库存及全部旧接口。整数 `health/max_health` 是战斗池的向上取整快照，精确 HP 见 `get_combat_state()`。
- 战士：耐力上限 140、法力上限 60；被动加快耐力恢复。Q 重斩、W 减伤、E 翻滚、R 自疗。
- 法师：耐力上限 80、法力上限 200；被动每秒额外恢复 4 法力。Q 奥术弹、W 减伤、E 疾行、R 伤害与眩晕。
- 未选择、游侠、采集者、治疗者保留职业身份，暂不分配主动或被动技能；耐力、法力上限均为 100。
- 切职业不补 HP、耐力或法力，降低资源上限时截断当前值。切换后保留按槽位的冷却与临时效果，防止通过换职业刷新技能。
- 旧 `damage_player()` 现在经过减伤再扣战斗 HP；`heal_player()` 治疗同一资源池，不复活死亡角色。HP 不自动恢复。
- 战斗结算更新 `health_changed`、`player_changed`、`player_died`；新增 `resource_changed(id, kind, value, maximum)` 和 `skill_cast(id, slot, reason)`。
- 致命伤害先提交资源与角色死亡再通知 UI；通知回调中不能重开或重复结算，需重开时使用 `call_deferred`。
- 玩家技能必须通过 `try_cast_skill()`，它检查玩家、存活、同大陆、技能目标、距离、冷却、眩晕和费用。伤害/定向位移不接受自身或无效目标。
- 终焉传送保留 HP、耐力、法力、冷却、效果、职业、库存；清除速度、输入和未完成冲刺，避免传送后继续位移。死亡玩家不传送。
- `start_new_game()` 为所有玩家重建资源和技能状态，职业恢复未选择，清除效果与冷却。

### 体验战斗

F5 打开管理面板，选择战士或法师，点击“进入 ARPG 战斗”。点击“测试：推进至终焉”会真实推进剩余时段并执行日末结算，便于把六名幸存者集中到同一大陆。此按钮是调试捷径。

方向键移动，数字 1—5 选择 AI 目标，QWER 施法。战士 Q 需要距离 100 以内；法师 Q/R 分别为 400/450。右侧显示真人三资源、技能冷却、施法结果和目标 HP。W、自疗 R 和无目标 E 不需目标。返回管理面板保留战斗状态，重开则重置。

战斗场景目前使用圆形占位图与无障碍平面，不启用实体间碰撞，以免尚未加载独立大陆时出现跨大陆碰撞。没有动画、投射物或自动攻击；伤害即时结算。

### 新接口示例

```gdscript
GameManager.set_profession(0, GameManager.Profession.WARRIOR)
GameManager.set_move_input(0, Vector2.RIGHT)
GameManager.try_cast_skill(0, &"Q", 1) # 不同大陆、超距等情况下返回 false。
GameManager.try_cast_skill(0, &"W")
GameManager.try_cast_skill(0, &"E")
var state := GameManager.get_combat_state(0) # 深拷贝资源和冷却数据。
```

`get_combatant(id)` 返回持久化的运行时实体，供 UI 绑定和高级扩展使用；业务代码应通过管理器施法和改血，避免绕过大陆与事务校验。手动将角色挂入场景不是必需步骤，管理器已经持有实体。外部实体仍可使用原 `register_player_body` / `update_player_position` 接口；移动后必须同步位置，管理器会同步冲刺与传送。核心实体的物理处理由管理器统一推进，不应再次开启其物理处理或重复调用 tick。

注册外部 `CharacterBody2D` 时，管理器通过该实体的 `move_and_slide()` 处理走路和冲刺，再将碰撞后的最终位置同步给战斗代理和玩家快照；不会每帧直接覆盖其位置。输入控制器应调用 `set_move_input()`，不要在同一帧另行执行第二次移动。旧移动脚本若继续自行移动，仍须调用 `update_player_position()`；迁移到管理器输入后应删除原移动调用。普通 Node2D 没有碰撞能力，地图角色应使用带碰撞形状的 CharacterBody2D。重开和终焉传送仍直接设置落点并清零速度。

致命伤害先提交死亡状态并发送旧血量/死亡信号，之后由资源组件唯一一次 HP 通知发布 `resource_changed`，避免资源监听者重复处理。

### 模块位置

`arpg_core/character.gd` 管理角色、效果和冷却；`resource_manager.gd` 管理三资源；`skill.gd` 及四种子类实现技能；`passive_skill.gd` / `status_effect.gd` 定义常驻与临时效果；`heroes.gd` 提供英雄配置；`resource_ui.gd` 绑定资源条。与管理器的兼容适配集中在 `scripts/GameManager.gd`，场景控制为 `scripts/CombatArena.gd`。

### 集成测试

```powershell
godot --headless --path . res://tests/GameManagerTest.tscn
godot --headless --path . res://tests/CombatIntegrationTest.tscn
godot --headless --path . res://tests/CombatRegressionTest.tscn
```

新增测试覆盖职业技能配置、跨大陆拒绝、旧接口与核心 HP 一致、资源恢复、独立冷却、减伤和眩晕、死亡通知、日结算死亡、传送保留资源、切职业不刷新、重开重置及 UI 重绑。失败以退出码 1 返回。

回归测试另覆盖致命伤害事件次数、外部实体走路与冲刺的墙体碰撞、贴墙移动、眩晕/死亡停步、实体释放后回退，以及重开与传送落点。

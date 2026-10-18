# Godot 4.x ARPG 核心系统

原封面与地图的完整集成已完成，游戏入口和存档兼容说明见 [ARPG_INTEGRATION.md](../ARPG_INTEGRATION.md)。以下为模块独立演示说明。

全部脚本位于 `res://arpg_core/`。独立演示不会替换现有 Player 或主场景。

## 运行示例

用 Godot 4.x 导入上一级 `map/project.godot`，等待脚本扫描完成，打开 `arpg_core/demo.tscn`，按 F6。

- 1 / 2：切换战士与法师；方向键：移动。
- Q / W / E / R：施放技能。伤害技能以另一名英雄为目标。
- H：受到 25 点伤害；J：眩晕 2 秒；T：满资源复活并清除冷却。
- 战士 Q 距离 100；法师 Q 距离 400。失败时显示原因且不扣费。

## 模块及职责

| 文件 | 职责 |
| --- | --- |
| resource_manager.gd | 三资源上限、扣费、伤害、治疗、恢复、变化信号 |
| character.gd | CharacterBody2D、技能槽、冷却、死亡、眩晕、效果、移动 |
| skill.gd | 技能基类：cooldown / mana_cost / stamina_cost / level |
| damage_skill.gd | 距离与存活检查、伤害、命中效果 |
| buff_skill.gd | 为自身增加状态效果 |
| healing_skill.gd | 主动治疗自身，不复活 |
| utility_skill.gd | 按朝向冲刺，使用物理碰撞 |
| passive_skill.gd | 无冷却、无费用的常驻属性效果 |
| status_effect.gd | Buff / Debuff 配置 |
| heroes.gd | 战士与法师工厂和全部技能配置 |
| resource_ui.gd | 通过信号显示 HP / Stamina / Mana |
| demo.gd / demo.tscn | 场景、按键、目标选择和 UI 使用示例 |

## 资源规则

HP 永不自动恢复，只能主动治疗或复活。耐力默认每秒恢复 30，消耗后延迟 0.6 秒，战斗中同样生效；法力按恒定速率恢复，不受耐力延迟影响。可在 Resources 节点 Inspector 配置所有上限及速率。死亡后停止恢复。

`spend(mana_cost, stamina_cost)` 先检查两种费用，再同时扣除；不足时两种资源都不扣。角色先验证死亡、眩晕、槽位、冷却和目标，成功后才消费并启动冷却。冷却存在角色字典中，技能 Resource 只存配置，多个角色可共用同一技能配置。技能升级请复制配置再改变 level，避免影响其他共享者。

## 两个英雄

| 槽位 | 战士（HP 220 / 耐力 140 / 法力 60） | 法师（HP 120 / 耐力 80 / 法力 200） |
| --- | --- | --- |
| passive | 坚韧：耐力恢复 +30% | 奥术源泉：法力每秒额外恢复 4 |
| Q | 重斩：30 伤害，25 耐力，2 秒冷却 | 奥术弹：40 伤害，20 法力、5 耐力，2 秒冷却 |
| W | 铁壁：减伤 40%，4 秒，20 耐力 | 奥术护体：减伤 40%，4 秒，25 法力 |
| E | 翻滚：20 耐力，3 秒冷却 | 疾行：20 耐力，3 秒冷却 |
| R | 战斗复苏：治疗 60，25 法力，15 秒冷却 | 冰封裁决：100 伤害和 2 秒眩晕，70 法力，15 秒冷却 |

W 冷却均为 10 秒。示例伤害为即时单目标结算；没有投射物、动画、AOE、敌我阵营过滤或 AI。接入实战时由目标选择器/命中检测提供合法敌方角色，扩展 `can_execute` 和 `execute`。

伤害与定向位移仅接受存活、范围内且非自身的 ARPGCharacter；普通场景节点、已释放对象及超距目标均返回失败且不扣费。E 不传目标时仍按朝向冲刺。致命伤害先禁用资源并同步角色死亡，再发送 HP 变化信号，避免回调中零血施法或治疗。

## 场景集成

手动创建英雄场景：

```text
Hero (CharacterBody2D, character.gd)
├── CollisionShape2D
├── Sprite2D / AnimatedSprite2D（可选）
└── Resources (Node, resource_manager.gd)

GameUI (CanvasLayer)
└── ResourceUI (VBoxContainer, resource_ui.gd)
```

在 Hero Inspector 的 passive / q / w / e / r 中创建对应自定义 Resource，填写费用、冷却及效果。Resources 可省略，角色会自动创建默认组件。手动场景必须自行添加碰撞形状。核心自带圆形绘制便于原型测试，可在正式角色中删除 `_draw()`。

也可直接使用工厂：

```gdscript
var warrior := ARPGHeroes.create(false)
var mage := ARPGHeroes.create(true)
add_child(warrior)
add_child(mage)
mage.position = Vector2(80, 0)
# 角色进入树且 ready 后，组件已经初始化。
$GameUI/ResourceUI.bind_character(warrior)
warrior.try_cast(&"Q", mage)
warrior.take_damage(20.0)
```

如在父节点 `_enter_tree()` 或异步加载流程中生成角色，应等待角色 ready 再访问 resources。UI 也必须先 ready 再绑定。已有 Player 若不能更换基类，可把 ARPGCharacter 作为战斗代理，但必须统一伤害入口和位置同步，避免两套 HP 并行运行。

正式输入可在 Project Settings > Input Map 配置 `move_left/right/up/down` 与 `skill_q/w/e/r`，控制器设置：

```gdscript
hero.move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
if Input.is_action_just_pressed("skill_q"):
    hero.try_cast(&"Q", selected_enemy)
```

## Buff、Debuff 和扩展

同 id 效果覆盖并刷新持续时间，不同 id 的加成相加；负的 speed_bonus 表示减速，负的 damage_bonus 表示虚弱。减伤上限 90%，速度与伤害倍率最低为 0。临时效果按秒计时，被动效果忽略 duration 并在存活时常驻。死亡清除临时效果，复活恢复被动。使用 `remove_effect(id)` 驱散。

```gdscript
var slow := ARPGStatusEffect.new()
slow.id = &"ice_slow"
slow.duration = 3.0
slow.speed_bonus = -0.4
enemy.add_effect(slow)
```

新增英雄可复用工厂结构，替换配置；新增技能继承 ARPGSkill，覆写目标检查与效果。`execute` 应同步完成且不失败；如果加入蓄力、异步动画或可打断施法，需要额外定义预付/退款、取消与命中时机。

## 验证清单

已使用 Godot 4.7.2 headless 运行 `smoke_test.gd` 并通过断言，覆盖资源原子扣费、HP 不恢复、耐力延迟、独立冷却、效果刷新、眩晕、死亡、复活及法师命中效果。运行方式：`godot --headless --path map --script res://arpg_core/smoke_test.gd`。其他 4.x 小版本尚未逐一验证。

运行 F6 后检查：HP 受伤后不自动恢复；耐力消耗后延迟恢复；法力稳定恢复；资源不足/冷却/距离无效时不扣费；眩晕时不能移动或施法；死亡后不恢复或施法；T 复活；两个同类英雄冷却互不影响；重复施放同 id Buff 只刷新、不叠加；UI 切换后只显示所选角色。

Godot Resource 的配置共享机制参见官方文档：https://docs.godotengine.org/en/stable/classes/class_resource.html 。

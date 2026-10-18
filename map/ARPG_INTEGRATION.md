# 逐神终焉：原封面、地图与战斗系统

完整游戏的入口是本目录 `project.godot`，F5 从原封面进入原地图。`../zhushen-zhongyan` 保留为独立管理器测试工程，不是正式游戏入口。也可双击项目根目录的“启动逐神终焉.cmd”。

## 操作

- WASD / 方向键移动；E 采集、交易和祭坛交互；Q 保留原太阳神力。
- Shift+Q/W/E/R 或左侧技能按钮释放当前职业技能；T 循环选择 AI 1—5。
- Tab/B 玩家面板；Y 大陆图、M 区域图；F5 保存；F10 保存并返回原菜单。
- 1—6 调试切图，空格推进时段。生存阶段允许切图，终焉阶段禁止逃离终焉地图。

初始战士，法师继续通过原职业仪式获得；最近获得的职业决定技能配置。游侠暂未配置 QWER，原有职业、仪式和成神技能继续保留。战士 Q/W/E/R 分别是重斩、铁壁、翻滚、战斗复苏；法师为奥术弹、奥术护体、疾行、冰封裁决。

左侧红/绿/蓝条对应 HP、耐力、法力；HP 不自动恢复。耐力消耗后延迟快速恢复，法力恒定恢复。目标必须存活且同大陆，并满足技能距离和费用要求。AI 当前为静止战斗目标，尚未接入决策。

实际移动时体力默认每秒消耗 12，移动期间不恢复；停止后等待 0.6 秒再逐渐恢复。恢复基础速率每秒 30，战士被动额外提高 30%。顶墙但没有实际位移、眩晕或打开面板停止移动时不会持续扣体力。体力最低为 0，不禁止基础走路；技能仍需支付体力。`ARPGResources.movement_stamina_drain` 可配置消耗速率。

## 接入结构

- `scripts/game/survival_manager.gd`：逐神终焉六玩家、14 天、日末结算、资源与技能管理。
- `scripts/GameManager.gd`：保留地图的 `continent_switched`、`time_updated`、`next_time_period` 等旧接口，并适配原权威背包与存档。
- `scripts/Player.gd`：保留原外观、碰撞和相机；`hp` 属性代理到真人战斗资源。地图实例由管理器调用真实 CharacterBody2D 的碰撞移动，不会双重移动。
- `scripts/game/map_combat.gd`：原地图的三资源 HUD、技能输入、职业仪式同步、AI 显示和安全落点。
- `arpg_core/`：技能、资源、角色、Buff 与被动模块。

真人在全局管理器中 ID 为 0，在原 ClassManager 中仍为 1；桥接代码负责映射，不能直接把两套 ID 混用。原 ClassManager 的伤害入口会进入同一战斗池，命中可中断仪式，死亡会清除成神状态。

42 次时段推进后进入终焉阶段，载入原 `continent_5` 地图，在无碰撞地块为幸存者分配独立落点。死亡角色不参与传送；资源、冷却、效果、职业和背包保留。

## 存档兼容

原 version 1 存档仍可读取；新增可选 `combat` 字段保存六玩家的资源、冷却、临时效果、职业、位置和终焉阶段。读取时验证数值、资源上限、职业一致性、大陆和阶段。新游戏从初始状态开始，不删除已有磁盘存档；继续游戏恢复战斗状态。旧存档没有 combat 时恢复原 HP/职业/地图，其余战斗状态使用默认值。超过 14 天的旧存档日期收敛到第 14 天。

菜单暂停实时战斗。AI 圆形占位图及血量标签只显示在当前大陆；正式地形、封面、菜单、背包和地图 UI 均沿用原资源。

## 验证

使用 Godot 4.7.2；原地图使用 TileMapLayer，运行版本须为 4.3 或更高。

```text
godot --headless --path . --script res://tests/MapCombatIntegrationTest.gd
godot --headless --path . --script res://tests/MovementStaminaTest.gd
godot --headless --path . --script res://tests/MainMenuTest.gd
godot --headless --path . --script res://tests/ProgressionIntegrationTest.gd
godot --headless --path . --script res://tests/GameBugRegressionTest.gd
godot --headless --path . res://tests/ContinentIntegrationTest.tscn
godot --headless --path . res://tests/ItemWorldIntegrationTest.tscn
godot --headless --path . res://tests/DualMapTest.tscn
godot --headless --path . res://tests/PlayerPanelTest.tscn
```

完整流程测试覆盖真实封面、新游戏、地图战斗、旧伤害、职业外观、保存/继续、旧存档读取、终焉地图及安全落点。视觉验证截图在 `.validation/integrated-*.png`。

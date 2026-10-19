# 已接入六大陆地图的物品、合成与商店

## 环形像素玩家界面

正式游戏现在使用环形玩家窗口：从上级 `map/project.godot` 运行，经过原封面和菜单进入地图，按 **Tab/B** 打开，**Esc/Tab/B** 关闭。悬停四个入口切换背包、合成、人物、职业；窗口内 **1–4** 切换模块、**T** 切换森林/熔岩/冰雪主题，关闭窗口后原地图快捷键照常生效。

背包直接读取角色共享 Inventory；合成走原 CraftingSystem，职业印记走原 progression_world.craft。人物显示真实生命、体力、法力和减伤；职业显示已完成仪式的职业及当前战斗技能。正式游戏尚无自由加点、通用装备或药剂使用接口，环形窗口不会套用演示中的虚拟加点、装备和回血规则。职业获取继续要求印记、地点、日期与时段校验。

环形左下角 **商店 / 存档 / 原职业面板** 保留原界面，点击右下角 **返回环形界面** 返回；F5/F10 沿用原保存和返回菜单逻辑。地图查看与窗口互斥，玩家移动/战斗输入仍遵循原窗口阻断逻辑。存档格式未变；主题仅在当前地图场景保留。

正式适配场景为 `scenes/ui/game_radial_ui.tscn`，脚本为 `scripts/ui/game_radial_ui.gd`，由 `world_items.gd` 在原 PlayerPanel 内绑定。`radial_ui_demo/` 继续作为独立演示，不能作为完整游戏入口。

接入回归：在 map 目录执行 `godot --headless --path . --script res://shop-and-object/tests/test_game_radial.gd`，另运行原 `ProgressionIntegrationTest.gd`、`MainMenuTest.gd` 和 `ItemWorldIntegrationTest.tscn`。

请打开上一级 `map/project.godot`，按 F5 运行原来的地图主场景。不要把本目录作为独立 Godot 项目导入。

- WASD / 方向键：原有移动。
- 1–6：切换原有大陆。
- 空格：推进原游戏早/中/晚，背包合成交易共用该时间。
- E：靠近绿色资源标记采集；一次性资源在本局切图后仍保持耗尽，容量不足不消耗。
- B：显示/隐藏右侧背包与合成商店面板。
- F3：GM 调试，直接操作角色背包，天数调整同步原游戏。

每个大陆出生点生成一个交易所标记。交易日为第 5、11、14 天，10:00–22:00 开放；原游戏早/中/晚分别映射到 06:00、12:00、18:00，因此中午和晚上可以交易。可以用 F3 调到第 5 天，再按空格进入中午体验。

右侧选择物品和数量，点击买入/卖出；同一 TradeManager 检查双方库存、信仰点、承重、容量及可交易属性后原子提交。初始信仰点、商人库存和采集映射在 resources/integration.json 配置，价格沿用物品 base_value，出售与买入同价。

角色的真实背包可从 `player.get_meta("inventory")` 取得；UI、采集、GM、合成与交易都引用同一实例。角色 job_changed 信号同步职业条件，默认无职业。进入/离开地图特殊地点同步配方地点要求。原地图当前采用的编号大陆只生成交易所；神格配方仍需游戏提供 central_altar 地点和 creator 职业，不会默认绕过这些要求。

本次提供本地 NPC 商人，不包含六人联网、存档或 NPC 移动。关闭游戏后背包、库存和采集状态会重置。GM 应仅用于开发。

## 验证命令

在 map 目录执行：

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . res://tests/ItemWorldIntegrationTest.tscn
godot --headless --path . res://shop-and-object/tests/test_item_system.tscn
godot --headless --path . res://tests/ContinentIntegrationTest.tscn
godot --headless --path . res://tests/MapLoaderTest.tscn
```

shop-and-object/backups 下保留接入前的 project.godot 与 MapDemo.gd 文本备份。

## 职业功能恢复

已恢复旧版本的 ClassManager、人物信息、职业印记合成、祭坛转职、半神及成神流程。Tab 显示人物职业/血量/技能；B 显示背包商店，两面板交替显示。E 统一处理剧情物品、采集与祭坛；Q 使用神力。角色初始为战士，大陆1/2夜晚分别可用印记学习法师/游侠；大陆3剧情遗物给太阳神印记，大陆6第12～14天夜晚可举行成神仪式。

职业材料矿石/药草/木材及职业/神印都进入同一个 Inventory；ProgressionInventory 只作为旧职业 API 的兼容适配器。合成校验输出容量后整笔提交，仪式从同一背包消耗印记。职业条件同步全部已拥有职业。

新增验证：`godot --headless --path . --script res://tests/ProgressionIntegrationTest.gd`，覆盖完整职业与成神流程以及共享背包。

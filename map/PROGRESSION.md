# 地图内职业进阶与成神

使用 Godot 4.3+ 打开本目录 `project.godot`，F5 启动原有 `MapDemo.tscn`。
本次直接使用已有 CharacterBody2D 玩家、AppearanceManager、JSON 地图及 GameManager 时钟。
`class-progression/` 仍作为独立参考示例保留；当前游戏运行入口是 `map/`。

## 实际操作

1. 初始拥有战士一个职业。WASD/方向键移动，1～6 切换大陆，N键推进早→中→晚。
   人物信息面板默认隐藏，按 Tab 打开/关闭，包含实时职业、血量、技能、材料和印记。合成和调试按钮也在面板内。
2. 靠近绿色资源按 E，采集矿石、药草、木材，每处 6 个。切图不会刷新已经采集的资源。
3. 右侧面板合成法师印记（矿石3+药草2）和游侠印记（木材3+药草2）。合成只授予资格。
4. 在大陆1出生点的法师祭坛，夜晚按 E 并停留8秒，获得法师；大陆2出生点的游侠祭坛同样授予游侠。
5. 大陆3出生点附近的太阳神遗物，靠近按 E 获得太阳神印记，每个会话仅领取一次。
6. 三职业即半神。推进到第12～14天夜晚，前往大陆6出生点的太阳神祭坛按 E，持续12秒后成神。
7. 成神显示金色光环，按 Q 释放太阳爆发，半径120、伤害50、冷却5秒。只有服务端登记且处于范围内的其他玩家会受伤。
8. 读条期间离开祭坛、切图、受伤、死亡或时间窗口关闭会中断；失败保留印记，成功消耗一个。
9. 调试面板可模拟敌方已确认命中和致死伤害。神明死亡不会结束地图游戏，会清除神力、光环及神明血量增益，保留三个职业；死亡后不能移动、交互或施法。

地图当前没有真实敌人、完整多人会话和复活系统；攻击按钮明确属于调试功能。神力范围伤害接口已接通，集成测试使用第二个真实 Player 场景验证伤害。
切换地图和手动推进时间沿用现有调试能力。角色外观仍使用项目现有图片配置；缺失图片显示原来的占位角色，神明额外绘制光环。

## 配置与代码

- `progression/data/*.tres`：编辑器可配置的职业、配方、仪式和神明。当前职业战士/法师/游侠，成神结果太阳神。
- `progression/catalog.gd`：加载配置。
- `progression/systems/class_manager.gd`：职业状态、服务端校验、读条、提交及战斗/死亡。
- `progression/world.gd`：连接原有地图标记、采集、剧情奖励、合成和祭坛。
- `progression/panel.gd`：原地图右侧交互面板和读条。
- `scripts/Player.gd`：原有移动/外观保留，新增 HP、职业技能和神明光环。
- `scripts/GameManager.gd`：原时钟新增查询接口，晚映射为 `night`。
- `scripts/MapLoader.gd`：旧格式大陆现在保留 special_locations，三类资源按矿石/药草/木材加载。

基础 HP 100。战士/法师/游侠分别加20/40/20；三个职业最大HP为180，太阳神为280。成神只更新上限，不免费回血。死亡恢复180上限且当前HP保持0。
属性和技能累计，外观采用最后获得的职业；神明优先显示神明形态。死亡恢复最后职业外观。

已有地图项目是本地单玩家演示，LOCAL_PLAYER_ID=1 与默认离线 peer 对齐。服务端战斗只能调用 `apply_confirmed_damage`；客户端不能直接调用打断RPC。未来接入真实网络时，还需要宿主项目维护玩家生成、账号到peer映射、权威坐标/区域、请求限流和快照就绪握手。
库存、采集耗尽和剧情领奖状态目前保存在当前会话；退出游戏后不持久化。

## 验证

```shell
godot --headless --path map --editor --quit
godot --headless --path map --script res://tests/ProgressionIntegrationTest.gd
godot --headless --path map --script res://tests/CharacterInfoUITest.gd
godot --headless --path map --script res://tests/GameBugRegressionTest.gd
godot --headless --path map res://tests/ContinentIntegrationTest.tscn
godot --headless --path map res://tests/MapLoaderTest.tscn
godot --headless --path map --script res://tests/PlayerTest.gd
```

集成测试覆盖真实玩家生成、材料采集、合成、时段/地点、受伤与移动打断、切图、剧情领奖去重、三职业上限、成神窗口、基础HP倍率、原外观切换、神力范围伤害及冷却、死亡与场景清理。

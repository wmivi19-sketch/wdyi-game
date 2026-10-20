# 代码检查与验证（2026-10-20）

本次将当前正式map工程同步到已有GitHub仓库，保留原主菜单、职业、共享背包、战斗和旧存档。新游戏从烛井独立教学关开始，完成后进入六大陆。

## 本次修复

- 破碎地板只检查地面XY和楼层，忽略角色仍在跳跃，导致飞越裂洞时提前落层。现在击打/失去支撑均要求角色已落地；天窗主动跃下继续允许空中进入。新增TutorialFloorJumpTest：修复前6项中2项失败，修复后6项全部通过。
- 玻璃图集从原始文件读取改为Godot的Texture2D preload，使图集成为显式导出依赖，移除“原始图片读取不适用于导出”的警告。已做资源导入和运行时回归；本次未生成发行版导出包。
- 战斗集成测试仍使用旧L1教学出口，导致无法继续进入大陆。更新为实际L0东出口，原39项战斗/旧存档检查全部保留。
- 楼梯README更新为64×32网格、中心(512,256)、圆弧旋梯、三个平台、当前输入方式、可读照明及四处下一层落点。

同步包含此前已完成的入口普通键码兼容、屏幕方向移动、Floating俯视碰撞、入口拓宽、路线指引、楼梯端点边界、一次性玻璃和独立教学存档。

## 验证

使用Godot4.7.2，在准备提交的干净仓库副本中导入资源并运行。APPDATA定向工作区测试目录，不使用真实玩家存档。

|测试|结果|
|---|---|
|TutorialFloorJumpTest|6项通过|
|EntryMobilityTest|39项通过|
|GlassStairRouteTest|75项通过|
|SmoothWellTest|22项通过|
|GlassPlatformTest|22项通过|
|ReferenceSaveTest|半层存档、旧版验证与入口迁移通过|
|TutorialJumpTest|空格、跳跃曲线、重复输入与碰撞锚点通过|
|MainMenuTest|46项通过|
|MapCombatIntegrationTest|39项通过|
|MovementStaminaTest|24项通过|
|PlayerJumpTest|跳跃/落地/换肤/传送/死亡/UI通过|
|GameBugRegressionTest|12项通过|

命令示例（从仓库根运行）：

```sh
godot --headless --editor --path map --quit
godot --headless --fixed-fps 60 --path map --script tests/TutorialFloorJumpTest.gd
godot --headless --fixed-fps 60 --path map --script tests/EntryMobilityTest.gd
godot --headless --fixed-fps 60 --path map --script tests/GlassStairRouteTest.gd
godot --headless --fixed-fps 60 --path map --script tests/MainMenuTest.gd
```

新手关渲染为2D伪纵深，实际碰撞在地面XY中进行，高度独立同步。Godot导出兼容修复通过资源导入和运行验证，尚未进行发行包启动验证。

提交排除.godot、验证截图、日志、临时文件、本地备份和工具缓存；未发现超过GitHub单文件限制的必要资源。现有调试工程保留，不覆盖正式入口。

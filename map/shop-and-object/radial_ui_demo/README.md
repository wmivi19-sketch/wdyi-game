# 遗迹旅人：Godot 4 环形像素 UI

这是原创复古冒险 UI 示例，独立于正式游戏数据。Godot 4.x，已使用 4.7.2 验证。完整游戏仍由上级 `map/project.godot` 启动。

## 运行

在 Godot 项目管理器导入本文件夹的 `project.godot`，F6 运行 `radial_ui.tscn` 或 F5 运行演示。

```text
radial_ui_demo/
  project.godot       演示配置及入口
  radial_ui.tscn      全屏 Control 场景
  radial_ui.gd        布局、Theme、四个面板与交互
  pixel_art.gd        原创 16×16 索引色角色与四种图标
  test_radial.gd      无窗口行为验证
  README.md
```

鼠标悬停左侧环形的四个入口展开对应面板；鼠标离开后保持选中，便于进入右侧面板操作。点击、键盘 1–4 也可选择，Tab 可聚焦按钮。T 或右上按钮循环切换森林、熔岩、冰雪主题。

- 背包：12 格展示，剑可装备/卸下，药剂恢复 25 HP；满血不扣药剂。
- 合成：点击材料查看用途，选择配方预览结果，合成会检查数量、扣除材料并添加产物。
- 人物：生命、体力、灵能像素条及属性；模拟受伤可测试回血。
- 职业：三职业身份切换；5 个共享技能点，每节点最高三级，依次满足前置条件。加点影响属性面板。

体力/灵能是展示数据；所有交互状态仅在当前会话有效，未实现存档、战斗、正式职业仪式或共享背包接入。

## 节点结构与视觉

场景根为 Control。脚本在运行时创建逻辑画布 Control、四个入口 Button、中心 TextureRect、右侧 PanelContainer → ScrollContainer → VBoxContainer，以及 GridContainer、ProgressBar 和提示 Label。1120×760 逻辑尺寸按窗口等比例缩放并居中。详情区固定边界，长内容自动换行并可纵向滚动，键盘焦点自动跟随滚动。Theme 资源运行时生成并赋给根节点，切换主题保留业务数据、提示、滚动位置和可用按钮的焦点。重复悬停当前模块不会重建内容。

素材使用 16 色索引表（含透明色），图案由 ImageTexture 生成，无外部下载依赖。边框无圆角，环形用离散像素绘制；TextureRect 使用最近邻过滤。中文优先使用系统宋体并关闭字体抗锯齿形成点阵感；缺少宋体时回退 CJK/系统字体，因此不同系统字形可能不同。字体未随项目分发。

如需统一像素字体：将有合法授权、覆盖中文字符的 TTF/OTF 放入本目录 `assets/fonts/`，导入设置关闭抗锯齿；把 `_build()` 中 `SystemFont` 替换为 `load("相对于脚本的字体路径")`，赋给 `ui_theme.default_font`。外部像素 PNG 可放 `assets/`，用 `load` 替换 `Art.texture()`；保持最近邻过滤。建议整数倍窗口尺寸以获得最清晰像素。

## 嵌入正式工程

在正式工程实例化 `shop-and-object/radial_ui_demo/radial_ui.tscn`，置于 CanvasLayer 中。场景与脚本使用相对资源路径。嵌入时只使用场景与脚本，不替换正式工程 project.godot。正式接入应将演示 stock 替换为角色 `get_meta("inventory")` 的同一背包实例，合成交由现有 CraftingSystem，职业切换交由原仪式和 ClassManager 校验；本示例不会直接修改这些系统或旧存档。

## 验证

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://test_radial.gd
```

回归覆盖合成交易、材料不足、满血不扣药、无武器不装备、技能前置和非法索引、刷新/主题切换后的键盘焦点与提示、三种窗口比例下的面板边界及重复悬停稳定性。测试具有 20 秒失败超时，脚本错误不会让自动化一直等待。若引擎提示系统证书存储读取失败，这是当前本机引擎环境提示；本示例无网络请求。

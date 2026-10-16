# 统一玩家面板（Godot 4.3+）

已接入当前地图主场景。打开本目录 project.godot，F5 运行。

## 操作

- Tab 或 B：打开/关闭同一个玩家窗口，重新打开保留当前页。
- 底部左右箭头或键盘左右键：切换背包/职业页。
- 在内容区水平拖动或触摸滑动至少 50 像素：翻页；纵向滚动、短距离点击与窗口外拖动不翻页。
- Esc 或右上角关闭按钮：关闭窗口。
- 背包格子点击查看详情；下滚可操作合成与商人。
- 职业页展示最多三个职业槽、详情、诅咒列表，以及原有职业印记合成、仪式、神力和调试按钮。

打开窗口期间移动与地图热键不穿透，页面切换动画期间禁用导航。游戏模拟继续运行，仪式原有的时间、位置、伤害校验仍然生效。

## 文件

- scenes/ui/player_panel.tscn：统一窗口，固定裁剪视口 PageContainer，内部 Pages 轨道容纳页面。
- scripts/ui/player_panel.gd：导航、Tween、尺寸重排和可见页刷新。
- scripts/ui/backpack_page.gd、inventory_slot.gd：格子、详情、承重及高负重警示。
- scripts/ui/profession_page.gd、profession_slot.gd、curse_item.gd：职业及诅咒显示。
- scripts/utils/swipe_detector.gd：独立手势检测，使用 Control 屏幕坐标，不依赖 Area2D 物理射线。
- scenes/ui/inventory_slot.tscn、profession_slot.tscn、curse_item.tscn：可复用列表项。
- scripts/professions/profession_database.gd：读取已有 ClassManager 的只读查询适配。
- resources/themes/player_panel_theme.tres：深色金边、18 号白色粗体主题。
- resources/ui/player_panel.json：动画时长、50 像素阈值、1.1 悬停比例、槽位尺寸、承重阈值与显示文本。
- assets/ui/*.svg：可替换的导航图标占位符。

PageContainer 保持单页宽度用于裁剪，宽度为页面数倍的是内部 Pages 轨道，避免移动裁剪区域导致窗口外内容泄漏。项目关闭固定画布拉伸，使 UI 按真实窗口尺寸重新排版；窗口变小时减少背包列数并纵向滚动。

## 数据接口与限制

GameState.player_inventory 指向原角色共享 Inventory。职业数据仍由 ClassManager 维护，ProfessionDatabase 仅提供查询。隐藏页只标脏，重新显示时读取最新数据；已选物品与职业在仍有效时保留。

现有职业系统没有等级，显示“已掌握”，不会虚构等级。GameState 提供 player_curses、add_curse(id)、remove_curse(id) 及变更信号，列表配置在 UI JSON 的 curse_definitions；默认没有诅咒。该接口仅用于展示，不新增战斗或诅咒数值规则。

添加第三页：将页面 Control 追加到 Pages，提供 refresh()（可选），将显示标题追加到 page_titles，并在 setup 中注入自己的数据。导航边界和页码按实际页面数量计算，无需改背包/职业页。

## 演示和测试

```powershell
# 含配置示例物品的互动演示，进入即打开统一面板
godot --path . res://scenes/test/test_player_panel.tscn
# UI 真实鼠标/触摸输入、数据与响应式测试
godot --headless --path . res://tests/PlayerPanelTest.tscn
# 原职业人物面板 CI 入口也转到统一面板测试
godot --headless --path . --script res://tests/CharacterInfoUITest.gd
# 完整职业/神格及共享背包验证
godot --headless --path . --script res://tests/ProgressionIntegrationTest.gd
# 地图采集、合成、商店
godot --headless --path . res://tests/ItemWorldIntegrationTest.tscn
# 物品、堆叠、合成与交易底层测试
godot --headless --path . res://shop-and-object/tests/test_item_system.tscn
# 使用实际渲染器生成背包、职业和480像素窄窗截图
godot --path . res://tests/PlayerPanelTest.tscn -- --capture-ui
```

截图保存在 .validation/player-panel-*.png。实际触屏设备尚未测试；触摸输入使用 Godot InputEventScreenTouch 注入验证。修改前的实际工程文件保存在 shop-and-object/backups/before-player-panel 中。

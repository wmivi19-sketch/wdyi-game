# Godot 4.3 主菜单与资源替换

项目入口现为 `res://scenes/ui/main_menu.tscn`，新游戏和继续游戏接入原有 `MapDemo.tscn`，保留职业、背包、交易及双地图。

## 使用

- 新游戏：创建初始角色与背包；不会直接删除磁盘旧存档，下一次保存才覆盖。
- 继续游戏：只有完整且有效的存档才可点击。损坏或不兼容存档不会部分覆盖当前状态。
- 游戏中 F5 保存，F10 保存并返回菜单，也可点击游戏界面的对应按钮。
- 设置：声音总开关、音乐/音效音量、全屏；配置持久保存在 `user://menu_settings.cfg`。
- 菜单支持鼠标、键盘焦点与窄屏滚动；设置和制作人员窗口可按 Esc 关闭。

## 交付文件

- `scenes/ui/main_menu.tscn`、`settings_menu.tscn`、`credits_screen.tscn`
- `scripts/ui/main_menu.gd`、`menu_resources.gd`、`settings_menu.gd`、`credits_screen.gd`
- `scripts/game/game_session.gd`：真实单机状态存取适配，作为 GameSession 自动加载。
- `resources/ui/main_menu_config.json`：资源、文字、动作、路径、布局配置。
- `resources/themes/menu_button_theme.tres`：可替换的按钮主题。
- `tests/MainMenuTest.gd`：隔离存档目录的端到端测试。

## 替换封面、Logo

所有菜单资源路径均在 `resources/ui/main_menu_config.json` 中。

1. 将封面放到 `assets/ui/main_menu/background.png`，建议 1920×1080。
2. 将透明 Logo 放到 `assets/ui/main_menu/logo.png`，建议 512×128。
3. 如果使用其他文件名，修改 `visual.background_image` 和 `visual.logo_image`。
4. 修改 `visual.title_text`、`subtitle_text` 调整占位标题和副标题。

背景等比铺满，超出部分裁切；Logo 保持比例。缺图时生成纯色背景与带标题的 Logo 占位。当前没有提供正式菜单美术，不复用世界地图作为菜单封面。

## 替换按钮样式

`visual.button_theme_path` 指向可编辑的 Godot Theme 资源。默认 `.tres` 包含正常、悬停、按下、禁用、焦点样式。

- 想使用 JSON 颜色样式：将主题路径清空，在 `style` 中配置字体、字号、颜色、边框、圆角。
- 想使用图片按钮：设置 `visual.button_textures.normal/hover/pressed/disabled` 的 PNG 路径，覆盖对应状态样式。
- 主题或图片缺失时使用代码生成的 StyleBoxFlat。
- 默认中文字体使用系统字体，目标设备需有中文字体；正式发布可在 Theme 中指定项目内字体。

`buttons` 数组控制顺序、显示文字、ID 和动作。动作白名单为 `start_new_game`、`load_game`、`open_settings`、`show_credits`、`quit_game`。存档按钮 ID 应保留 `continue`。

## 替换音频

默认目录为 `audio/music/` 与 `audio/sfx/`（位于项目根目录，不在 assets 下）。

- `audio.bgm_path`：默认 `res://audio/music/main_menu_bgm.ogg`。
- `audio.hover_sound`：默认 `res://audio/sfx/button_hover.wav`。
- `audio.click_sound`：默认 `res://audio/sfx/button_click.wav`。
- BGM、音效均支持 OGG Vorbis 或 WAV；原始 WAV 热加载支持 PCM 8/16 位单声道或双声道。
- `bgm_volume`、`sfx_volume` 范围 0～1，与用户设置音量相乘。
- `enable_audio=false` 完全禁用；资源缺失默认静音。
- `generate_placeholders=true` 可为缺失的 UI 音效生成简短提示音。频率、时长和振幅也在 JSON 中配置；不会生成背景音乐。
- 音频总线不存在时自动创建。BGM 循环设置在音频流上，兼容 Godot 4.3。

## 热替换与容错

菜单每隔 `layout.poll_seconds` 秒检查 JSON 和直接引用的资源内容哈希。保存 JSON、替换同路径图片或音频后即可生效，不必改脚本或重启菜单；也可调用菜单的 `reload_config()`。

无效 JSON 保留上一份有效配置；首次缺配置使用内置默认值。资源缺失或类型错误回退到占位/静音。场景加载失败会在菜单显示错误并恢复操作。转场进行时暂停重载，防止重复点击进入两次场景。

Godot Theme 的嵌套依赖若修改，建议同时保存 `.tres` 或重新加载配置。配置文件路径本身由场景导出属性 `config_path` 决定，可设为 `user://main_menu_config.json`，适合发布后让玩家替换。

## 导出注意

编辑器项目的 `res://` 文件可直接替换。导出的 PCK 内文件不能在外部直接覆盖；需重新导出，或将配置及可替换资源放在 `user://` 并在 JSON 引用对应路径。

导出预设应包含 JSON 等非资源文件；如果依赖原始资源热加载，也要包含原始 PNG/JPG/WAV/OGG。可用非资源包含过滤器 `*.json,*.png,*.jpg,*.jpeg,*.wav,*.ogg`，并检查导出产物。导出包内已导入图片另有 ResourceLoader 回退。发布前请在目标平台验证字体、音频和用户数据目录访问。

## 存档

默认 `user://save_game.json`，版本 1，单槽单机存档；修改 `storage.save_path` 可换槽。Godot 的 user:// 位于项目应用数据目录，可在编辑器“项目 → 打开用户数据文件夹”定位。

保存内容包括：大陆与位置、日期/时段、共享背包、商人库存、职业/神祇/基础属性/血量、诅咒、资源耗尽及剧情领取标记。继续游戏等待真实地图加载后再恢复，恢复完成后发布 UI 更新。

写入先创建临时文件再替换旧存档。合成、仪式或交易进行时拒绝保存，避免恢复半完成的动作。校验会检查地图可走位置、库存容量与物品 ID、职业及神祇资格、数值范围；后续修改数据平衡、地图或删除资源 ID 可能使旧存档失效，需要显式设计迁移。该存档不保存联网会话或进行中的协作交易。

## 验证

使用 Godot 4.3：

```powershell
Godot_v4.3-stable_win64_console.exe --headless --path <项目目录> --script res://tests/MainMenuTest.gd
```

非 headless 可增加 `--audio-driver Dummy` 并在末尾加 `-- --capture-menu`，以生成默认与窄屏截图到 `.validation/`。测试使用独立的 `user://main-menu-tests/`，不会覆盖正常玩家存档。

本次菜单测试 45 项通过；另有世界地图 43、双地图 46、玩家面板 32、职业整合 36、既有问题回归 12 项通过，物品世界整合测试通过。已实际使用 OpenGL 渲染检查默认与 480×640 菜单，并验证同路径同尺寸图片热替换。音频加载/循环/静音使用 Dummy 驱动验证，未进行扬声器听感评估。

读档回归：从第三大陆非出生点保存后继续，验证角色准确恢复保存位置，大陆下拉框与实际地图同步。出生点初始化信号先连接，存档恢复在其后运行。

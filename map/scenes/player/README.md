# 主角图片接入

Godot 项目根目录是 `map`，打开此目录的 `project.godot`。
实际游戏地图使用 `scenes/player/player.tscn`，新游戏与继续游戏都通过该主角场景进入地图。此场景继承 `scenes/Player.tscn`，可直接拖入其他关卡或按 F6 运行。

节点树：
```text
Player (CharacterBody2D, player_controller.gd)
├── BaseBody (Sprite2D)
├── Outfit (Sprite2D)
├── Accessory (Sprite2D)
├── CollisionShape2D
├── Camera2D
├── AnimationPlayer
└── AppearanceManager (player_appearance.gd)
```

WASD / 方向键移动，斜向速度归一化。移动速度通过 Player 的 speed 属性调整。
属性与职业逻辑继续位于 scripts/Player.gd；不额外建立第二份属性状态。
当前图片只有一帧，移动时保持同一姿势。AnimationPlayer 保留未来序列帧支持。
在 resources/config/scale_config.json 中修改 player.sprite_size 的高度可调整角色大小，单张角色图始终等比缩放。

其他场景中创建主角：
```gdscript
var player = preload("res://scenes/player/player.tscn").instantiate()
add_child(player)
player.position = Vector2(300, 300)
```

动态换图（新资源应放在 assets/characters/player/sprites/，确保已由 Godot 导入）：
```gdscript
$Player/AppearanceManager.replace_image("res://assets/characters/player/sprites/mage.png")
```

图片缺失时自动使用色块占位。职业外观映射位于 data/skins.json；default 和 warrior 使用 warrior.png，未提供的其他职业图片保留原有占位行为。未虚构法师、成神和头像资源。

warrior.png 使用内置 imagegen 从用户图片生成透明版本，可能存在少量重绘差异。
使用的提示词：去除灰色棋盘格背景与地面阴影，输出真实 alpha 透明，保留战士姿势、斗笠、刀、蓝色围巾披风、服装和像素画风，完整单角色，边缘留少量透明边距，无文字，非序列帧。

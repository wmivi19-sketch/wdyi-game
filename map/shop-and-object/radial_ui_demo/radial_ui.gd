extends Control
## Standalone presentation model: never writes the host game's inventory or saves.
const Art = preload("pixel_art.gd")
const THEMES = [
 {"name":"自然森林", "bg":"101e1c", "panel":"1b3029", "edge":"638451", "accent":"d5dd99", "muted":"9aac88"},
 {"name":"火焰熔岩", "bg":"24171b", "panel":"3b2426", "edge":"a5553d", "accent":"ffc77b", "muted":"c5937b"},
 {"name":"冰雪极地", "bg":"121f30", "panel":"203449", "edge":"57859d", "accent":"d6eff0", "muted":"91b7cc"}
]
const MODULES = ["背包", "合成", "人物", "职业"]
var theme_index := 0
var active := 0
var stock := {"herb":8, "ore":5, "potion":2, "sword":1}
var hp := 64
var profession := 0
var points := 5
var ranks := [0, 0, 0]
var selected_recipe := 0
var selected_material := "herb"
var equipped := false
var detail: VBoxContainer
var tabs: Array[Button] = []
var message: Label
var center_info: Label
var canvas: Control
var theme_button: Button
var detail_scroll: ScrollContainer

func _ready() -> void:
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 canvas = Control.new()
 add_child(canvas)
 canvas.size = Vector2(1120, 760)
 resized.connect(_layout)
 _build()
 _layout()

func color(key: String) -> Color:
 return Color(THEMES[theme_index][key])

func box(fill: Color, border: Color, width: int = 2) -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color = fill
 style.border_color = border
 style.set_border_width_all(width)
 style.content_margin_left = 14
 style.content_margin_right = 14
 style.content_margin_top = 10
 style.content_margin_bottom = 10
 return style

func _build() -> void:
 var ui_theme := Theme.new()
 var bitmap_font := SystemFont.new()
 bitmap_font.font_names = PackedStringArray(["SimSun", "Noto Sans CJK SC", "monospace"])
 bitmap_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
 ui_theme.default_font = bitmap_font
 ui_theme.default_font_size = 16
 ui_theme.set_color("font_color", "Label", color("accent"))
 ui_theme.set_color("font_color", "Button", color("accent"))
 ui_theme.set_color("font_hover_color", "Button", Color.WHITE)
 ui_theme.set_color("font_focus_color", "Button", Color.WHITE)
 ui_theme.set_color("font_disabled_color", "Button", color("muted").darkened(0.25))
 ui_theme.set_stylebox("normal", "Button", box(color("panel"), color("edge")))
 ui_theme.set_stylebox("hover", "Button", box(color("edge"), color("accent")))
 ui_theme.set_stylebox("pressed", "Button", box(color("edge"), color("accent"), 3))
 ui_theme.set_stylebox("focus", "Button", box(Color.TRANSPARENT, color("accent"), 3))
 ui_theme.set_stylebox("disabled", "Button", box(color("panel"), color("muted").darkened(0.4)))
 theme = ui_theme
 var title := Label.new()
 title.text = "遗 迹 旅 人    /    RELIC WANDERER"
 title.position = Vector2(38, 28)
 title.add_theme_font_size_override("font_size", 24)
 canvas.add_child(title)
 theme_button = Button.new()
 theme_button.name = "ThemeButton"
 theme_button.text = "主题 · " + THEMES[theme_index].name + "   [T]"
 theme_button.position = Vector2(820, 26)
 theme_button.size = Vector2(260, 48)
 theme_button.pressed.connect(_next_theme)
 canvas.add_child(theme_button)
 tabs.clear()
 for i in 4:
  var button := Button.new()
  button.name = "Module%d" % i
  button.text = ["01  行囊 / 背包", "02  工坊 / 合成", "03  旅者 / 人物", "04  星轨 / 职业"][i]
  button.size = Vector2(184, 66)
  button.mouse_entered.connect(_activate.bind(i))
  button.focus_entered.connect(_activate.bind(i))
  button.pressed.connect(_activate.bind(i))
  canvas.add_child(button)
  tabs.append(button)
 var portrait := TextureRect.new()
 portrait.texture = Art.texture("hero")
 portrait.position = Vector2(249, 258)
 portrait.size = Vector2(144, 144)
 portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
 canvas.add_child(portrait)
 center_info = Label.new()
 center_info.position = Vector2(216, 408)
 center_info.size = Vector2(210, 60)
 center_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 canvas.add_child(center_info)
 var panel := PanelContainer.new()
 panel.name = "DetailPanel"
 panel.position = Vector2(632, 116)
 panel.size = Vector2(448, 532)
 panel.add_theme_stylebox_override("panel", box(color("panel"), color("edge"), 3))
 canvas.add_child(panel)
 detail_scroll = ScrollContainer.new()
 detail_scroll.name = "Scroll"
 detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 detail_scroll.follow_focus = true
 panel.add_child(detail_scroll)
 detail = VBoxContainer.new()
 detail.name = "Content"
 detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 detail.add_theme_constant_override("separation", 8)
 detail_scroll.add_child(detail)
 message = Label.new()
 message.position = Vector2(38, 678)
 message.size = Vector2(1040, 50)
 message.text = "悬停环形入口展开面板 · 1–4 切换模块 · T 更换主题"
 message.add_theme_color_override("font_color", color("muted"))
 canvas.add_child(message)
 _select(active)
 queue_redraw()

func _layout() -> void:
 # Fixed logical canvas scales uniformly; host viewport can use any aspect ratio.
 var factor := minf(size.x / 1120.0, size.y / 760.0)
 canvas.scale = Vector2.ONE * factor
 canvas.position = (size - Vector2(1120, 760) * factor) / 2.0
 var positions := [Vector2(229, 124), Vector2(420, 307), Vector2(229, 500), Vector2(38, 307)]
 for i in tabs.size(): tabs[i].position = positions[i]
 queue_redraw()

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO, size), color("bg"))
 if not is_instance_valid(canvas): return
 var f := canvas.scale.x
 var origin := canvas.position
 for x in range(24, 1120, 24):
  for y in range(96, 660, 24):
   draw_rect(Rect2(origin + Vector2(x, y) * f, Vector2.ONE * 2 * f), color("panel"))
 var c := origin + Vector2(321, 340) * f
 for radius in [148, 157, 224]:
  for i in 64:
   var a := TAU * i / 64.0
   var p: Vector2 = (Vector2(cos(a), sin(a)) * float(radius) / 4.0).round() * 4.0
   draw_rect(Rect2(c + p * f, Vector2.ONE * (4 if radius == 157 else 2) * f), color("edge"))
 draw_rect(Rect2(origin + Vector2(215, 235) * f, Vector2(212, 244) * f), color("panel"))

func label(text_value: String, large: bool = false) -> Label:
 var node := Label.new()
 node.text = text_value
 node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 node.add_theme_font_size_override("font_size", 22 if large else 16)
 detail.add_child(node)
 return node

func action(text_value: String, callback: Callable, enabled: bool = true) -> Button:
 var button := Button.new()
 button.name = "Action%d" % detail.get_child_count()
 button.text = text_value
 button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 button.disabled = not enabled
 button.pressed.connect(callback)
 detail.add_child(button)
 return button

func _activate(index: int) -> void:
 if index != active:
  _select(index)

func _restore_focus(path: NodePath) -> void:
 var target := canvas.get_node_or_null(path) as Control
 if target != null and target.is_visible_in_tree() and target.focus_mode != Control.FOCUS_NONE:
  if not target is BaseButton or not target.disabled:
   target.grab_focus()

func _select(index: int) -> void:
 if index < 0 or index >= MODULES.size(): return
 var focus_path := NodePath()
 var focused := get_viewport().gui_get_focus_owner()
 if index == active and focused != null and detail.is_ancestor_of(focused):
  focus_path = canvas.get_path_to(focused)
 if index != active:
  detail_scroll.scroll_vertical = 0
 active = index
 for child in detail.get_children():
  detail.remove_child(child)
  child.queue_free()
 for i in tabs.size():
  tabs[i].add_theme_color_override("font_color", Color.WHITE if i == active else color("accent"))
 center_info.text = "LV.12  林间旅者\n" + ["守卫", "游侠", "术士"][profession] + "  /  HP %d" % hp
 label("0%d  /  %s" % [index + 1, MODULES[index]], true)
 label(["随身物资 · 点击格子装备或使用", "材料 → 配方 → 结果", "荒野中的每一步，都需要准备", "职业可自由切换 · 技能点共享"][index])
 match index:
  0: _inventory()
  1: _crafting()
  2: _stats()
  3: _skills()
 if not focus_path.is_empty():
  _restore_focus.call_deferred(focus_path)

func _inventory() -> void:
 label("装备栏  /  " + ("青铜短剑  ·  攻击 +8" if equipped else "尚未装备武器"))
 var grid := GridContainer.new()
 grid.name = "Slots"
 grid.columns = 4
 grid.add_theme_constant_override("h_separation", 8)
 grid.add_theme_constant_override("v_separation", 8)
 detail.add_child(grid)
 var kinds := ["sword", "herb", "ore", "potion"]
 for i in 12:
  var b := Button.new()
  b.name = "Slot%d" % i
  b.custom_minimum_size = Vector2(92, 84)
  grid.add_child(b)
  if i >= 4:
   b.disabled = true
   b.text = "·"
   continue
  var kind: String = kinds[i]
  b.icon = Art.texture(kind)
  b.expand_icon = true
  b.add_theme_constant_override("icon_max_width", 32)
  b.text = "×%d" % stock[kind]
  b.tooltip_text = {"sword":"青铜短剑：点击装备/卸下", "herb":"月露草：用于合成", "ore":"蓝晶矿：用于合成", "potion":"生命药剂：恢复 25 生命"}[kind]
  b.pressed.connect(_use.bind(kind))
 label("材料  /  月露草 · 蓝晶矿\n消耗品  /  生命药剂恢复 25 HP")

func _use(kind: String) -> void:
 if kind == "sword":
  if stock.sword <= 0: return
  equipped = not equipped
  message.text = "已装备青铜短剑" if equipped else "已卸下青铜短剑"
 elif kind == "potion" and stock.potion > 0 and hp < 100:
  stock.potion -= 1
  hp = mini(100, hp + 25)
  message.text = "使用生命药剂 · 当前生命 %d / 100" % hp
 else:
  message.text = "材料可在工坊使用；药剂需要有库存且生命未满。"
 _select(active)

func _crafting() -> void:
 label("材料选择区  /  点击查看用途")
 var row := HBoxContainer.new()
 row.name = "Materials"
 detail.add_child(row)
 for kind in ["herb", "ore"]:
  var b := Button.new()
  b.name = kind
  b.text = ("月露草" if kind == "herb" else "蓝晶矿") + " ×%d" % stock[kind]
  b.icon = Art.texture(kind)
  b.pressed.connect(_material.bind(kind))
  row.add_child(b)
 label("已选：" + ("月露草 · 药剂原料" if selected_material == "herb" else "蓝晶矿 · 药剂催化 / 铸剑原料"))
 action(("▶ " if selected_recipe == 0 else "") + "生命药剂  /  月露草 ×2 + 蓝晶矿 ×1", _recipe.bind(0))
 action(("▶ " if selected_recipe == 1 else "") + "青铜短剑  /  蓝晶矿 ×3", _recipe.bind(1))
 var preview := TextureRect.new()
 preview.texture = Art.texture("potion" if selected_recipe == 0 else "sword")
 preview.custom_minimum_size = Vector2(64, 64)
 preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 detail.add_child(preview)
 label("结果预览：" + ("生命药剂 ×1 · 恢复 25 HP" if selected_recipe == 0 else "青铜短剑 ×1 · 攻击 +8"))
 action("合 成  /  消耗所示材料", _craft, _can_craft())

func _material(kind: String) -> void:
 if kind not in ["herb", "ore"]: return
 selected_material = kind
 _select(active)

func _recipe(index: int) -> void:
 if index < 0 or index > 1: return
 selected_recipe = index
 _select(active)

func _can_craft() -> bool:
 if selected_recipe < 0 or selected_recipe > 1: return false
 return (stock.herb >= 2 and stock.ore >= 1) if selected_recipe == 0 else stock.ore >= 3

func _craft() -> void:
 if not _can_craft(): return
 if selected_recipe == 0:
  stock.herb -= 2
  stock.ore -= 1
  stock.potion += 1
 else:
  stock.ore -= 3
  stock.sword += 1
 message.text = "合成成功 · 结果已放入行囊"
 _select(active)

func _bar(caption: String, value: int, maximum: int, tint: Color) -> void:
 label("%s   %d / %d" % [caption, value, maximum])
 var bar := ProgressBar.new()
 bar.custom_minimum_size.y = 22
 bar.max_value = maximum
 bar.value = value
 bar.show_percentage = false
 bar.add_theme_stylebox_override("background", box(color("bg"), color("edge")))
 bar.add_theme_stylebox_override("fill", box(tint, tint))
 detail.add_child(bar)

func _stats() -> void:
 _bar("生命", hp, 100, Color("bd5246"))
 _bar("体力", 72, 90, Color("77aa59"))
 _bar("灵能", 36, 60, Color("83c9ca"))
 label("攻击  %d       防御  %d" % [18 + (8 if equipped else 0) + ranks[0] * 3, 12 + ranks[1] * 2])
 label("敏捷  %d       等级  12" % (14 + ranks[2] * 2))
 label("当前位置  /  翡翠林地\n职业  /  " + ["守卫", "游侠", "术士"][profession])
 action("模拟受伤  −15 HP", _damage)

func _damage() -> void:
 hp = maxi(0, hp - 15)
 _select(active)

func _skills() -> void:
 var row := HBoxContainer.new()
 row.name = "Professions"
 detail.add_child(row)
 for i in 3:
  var b := Button.new()
  b.name = "Profession%d" % i
  b.text = ("◆ " if profession == i else "") + ["守卫", "游侠", "术士"][i]
  b.pressed.connect(_profession.bind(i))
  row.add_child(b)
 label("星轨  /  剩余能力点 %d" % points, true)
 label("力量 I  ──→  坚韧 I  ──→  灵巧 I\n先学习前置节点，再解锁下一节点。")
 for i in 3:
  action("%s  %d / 3   [+]" % [["力量 · 攻击 +3", "坚韧 · 防御 +2", "灵巧 · 敏捷 +2"][i], ranks[i]], _upgrade.bind(i), points > 0 and ranks[i] < 3 and (i == 0 or ranks[i - 1] > 0))
 label("演示职业切换只改变身份标记。\n接入正式游戏时由职业仪式系统校验。")

func _profession(index: int) -> void:
 if index < 0 or index >= 3: return
 profession = index
 _select(active)

func _upgrade(index: int) -> void:
 if index < 0 or index >= ranks.size(): return
 if points <= 0 or ranks[index] >= 3 or (index > 0 and ranks[index - 1] == 0): return
 points -= 1
 ranks[index] += 1
 _select(active)

func _next_theme() -> void:
 var status := message.text
 var scroll_position := detail_scroll.scroll_vertical
 var focused := get_viewport().gui_get_focus_owner()
 var focus_path := canvas.get_path_to(focused) if focused != null and canvas.is_ancestor_of(focused) else NodePath()
 theme_index = (theme_index + 1) % THEMES.size()
 for child in canvas.get_children():
  canvas.remove_child(child)
  child.queue_free()
 _build()
 _layout()
 message.text = status
 detail_scroll.set_deferred("scroll_vertical", scroll_position)
 if not focus_path.is_empty():
  _restore_focus.call_deferred(focus_path)

func _unhandled_key_input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo: return
 if event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return
 if event.keycode == KEY_T:
  _next_theme()
  get_viewport().set_input_as_handled()
 elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
  _select(event.keycode - KEY_1)
  get_viewport().set_input_as_handled()

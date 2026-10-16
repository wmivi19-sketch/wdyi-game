class_name ProfessionPage
extends ScrollContainer
## 职业页读取 ClassManager、GameState；仪式按钮沿用已验证职业流程。
@onready var profession_list: VBoxContainer = $Layout/ProfessionList
@onready var curse_list: VBoxContainer = $Layout/CurseList
@onready var detail_label: Label = $Layout/ProfessionDetailPanel/Detail
var progression_panel: VBoxContainer
var settings: Dictionary = {}
var dirty: bool = true
var selected_profession: String = ""
## world 是职业流程适配器；ui_settings 为页面配置。
func setup(world: Node, ui_settings: Dictionary) -> void:
 settings = ui_settings
 progression_panel = preload("res://progression/panel.gd").new()
 $Layout.add_child(progression_panel)
 progression_panel.setup(world)
 progression_panel.custom_minimum_size.x = 0
 for label in [progression_panel.summary, progression_panel.feedback]: label.custom_minimum_size.x = 0
 GameState.profession_changed.connect(mark_dirty)
 GameState.curse_added.connect(mark_dirty)
 GameState.curse_removed.connect(mark_dirty)
 world.player.health_changed.connect(func(_hp, _max): mark_dirty())
 mark_dirty()
## 隐藏时只标脏，下一次显示读取最新数据；无参数。
func mark_dirty() -> void:
 dirty = true
 if is_visible_in_tree(): refresh()
## 重建职业及诅咒列表并更新职业行为面板；无参数。
func refresh() -> void:
 if settings.is_empty() or not is_visible_in_tree(): return
 dirty = false
 for child in profession_list.get_children():
  profession_list.remove_child(child)
  child.queue_free()
 for index in int(settings.profession_slots):
  var slot = preload("res://scenes/ui/profession_slot.tscn").instantiate()
  profession_list.add_child(slot)
  if index < GameState.player_professions.size(): slot.setup(GameState.player_professions[index], index)
  else: slot.setup_empty(index)
  slot.profession_selected.connect(show_profession_detail)
 for child in curse_list.get_children():
  curse_list.remove_child(child)
  child.queue_free()
 var title := Label.new()
 title.text = "诅咒：无" if GameState.player_curses.is_empty() else "当前诅咒"
 curse_list.add_child(title)
 for id in GameState.player_curses:
  var curse = preload("res://scenes/ui/curse_item.tscn").instantiate()
  curse_list.add_child(curse)
  curse.setup(id, settings.curse_definitions.get(id, {}))
 show_profession_detail(selected_profession)
 progression_panel.refresh()
## id 为选中的职业；显示现有技能和属性加成。
func show_profession_detail(id: String) -> void:
 selected_profession = id
 var data := ProfessionDatabase.get_profession(id)
 if data.is_empty() or id not in GameState.player_professions:
  detail_label.text = "选择职业查看技能与属性加成"
  selected_profession = ""
  return
 var skills: Array[String] = []
 for skill in data.skills: skills.append(str(settings.skill_names.get(skill, skill)))
 var bonuses: Array[String] = []
 for key in data.bonuses: bonuses.append("%s +%s" % [settings.stat_names.get(key, key), data.bonuses[key]])
 detail_label.text = "%s · %s\n技能：%s\n属性加成：%s" % [data.name, settings.power_names.get(data.power_system, data.power_system), "、".join(skills), "、".join(bonuses)]

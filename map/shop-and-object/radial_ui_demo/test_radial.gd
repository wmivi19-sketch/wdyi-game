extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 # Fail rather than leaving CI running if a script error aborts this coroutine.
 create_timer(20.0).timeout.connect(func(): quit(1))
 var scene_path: String = get_script().resource_path.get_base_dir().path_join("radial_ui.tscn")
 var ui = load(scene_path).instantiate()
 root.add_child(ui)
 await process_frame
 ui._select(1)
 ui._craft()
 assert(ui.stock.herb == 6 and ui.stock.ore == 4 and ui.stock.potion == 3, "Craft transaction")
 ui._use("potion")
 assert(ui.hp == 89 and ui.stock.potion == 2, "Potion consumption")
 ui._upgrade(2)
 assert(ui.points == 5, "Prerequisite guard")
 ui._upgrade(0)
 ui._upgrade(1)
 ui._upgrade(2)
 assert(ui.points == 2 and ui.ranks == [1, 1, 1], "Skill progression")
 ui._profession(2)
 for i in 3:
  ui._next_theme()
  await process_frame
 assert(ui.theme_index == 0 and ui.hp == 89 and ui.profession == 2, "Theme persistence")
 ui.selected_recipe = 1
 ui._craft()
 assert(ui.stock.ore == 1 and ui.stock.sword == 2, "Sword recipe")
 ui._craft()
 assert(ui.stock.ore == 1 and ui.stock.sword == 2, "Insufficient materials")
 ui.hp = 100
 var potions: int = ui.stock.potion
 ui._use("potion")
 assert(ui.hp == 100 and ui.stock.potion == potions, "Full health must not consume")
 ui.stock.sword = 0
 ui.equipped = false
 ui._use("sword")
 assert(not ui.equipped, "Cannot equip absent sword")
 ui._upgrade(-1)
 ui._upgrade(99)
 ui._profession(-1)
 ui._profession(99)
 ui._recipe(99)
 ui._select(-1)
 assert(ui.profession == 2 and ui.selected_recipe == 1, "Invalid indices must not mutate")
 ui.selected_recipe = -1
 assert(not ui._can_craft(), "Invalid recipe guard")
 ui.selected_recipe = 1
 ui._select(0)
 await process_frame
 await process_frame
 var slot: Button = ui.detail.get_node("Slots/Slot1")
 slot.grab_focus()
 slot.pressed.emit()
 await process_frame
 var focused: Control = root.gui_get_focus_owner()
 assert(focused != null and focused.name == "Slot1", "Refresh preserves keyboard focus")
 var status: String = ui.message.text
 ui._next_theme()
 await process_frame
 focused = root.gui_get_focus_owner()
 assert(focused != null and focused.name == "Slot1", "Theme preserves keyboard focus")
 assert(ui.message.text == status, "Theme preserves feedback")
 for viewport_size in [Vector2(1120, 760), Vector2(800, 600), Vector2(600, 900)]:
  ui.size = viewport_size
  ui._layout()
  for module_index in 4:
   ui._select(module_index)
   await process_frame
   await process_frame
   var panel: Control = ui.canvas.get_node("DetailPanel")
   assert(panel.size.is_equal_approx(Vector2(448, 532)), "Content must not grow panel")
   assert(ui.detail.size.x <= ui.detail_scroll.size.x + 1.0, "No horizontal overflow")
   assert(ui.canvas.position.x >= -0.1 and ui.canvas.position.y >= -0.1, "Canvas centered inside viewport")
 # Hovering the already selected entry should not recreate its controls.
 var first: Node = ui.detail.get_child(0)
 ui._activate(ui.active)
 assert(ui.detail.get_child(0) == first, "Repeated hover is stable")
 ui.size = Vector2(800, 600)
 ui._layout()
 assert(ui.canvas.scale.x > 0.0, "Responsive layout")
 print("PASS: transactions, boundary guards, keyboard focus, theme state, panel bounds, resizing, hover")
 ui.queue_free()
 await process_frame
 quit()

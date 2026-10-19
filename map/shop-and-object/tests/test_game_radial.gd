extends SceneTree
var failures := 0
var checks := 0

func _initialize() -> void:
 call_deferred("run")

func check(value: bool, description: String) -> void:
 checks += 1
 if value:
  print("PASS: ", description)
 else:
  failures += 1
  push_error(description)

func key(code: int) -> void:
 var event := InputEventKey.new()
 event.keycode = code
 event.physical_keycode = code
 event.pressed = true
 Input.parse_input_event(event)
 await process_frame

func run() -> void:
 create_timer(40).timeout.connect(func(): quit(1))
 var world = load("res://scenes/MapDemo.tscn").instantiate()
 root.add_child(world)
 for i in 6: await process_frame
 var items = world.get_node("WorldItems")
 var host = world.character_info_ui.character_info_panel
 var radial = host.get_node_or_null("RadialUI")
 check(radial != null, "radial mounted in original player window")
 if radial == null:
  quit(1)
  return
 check(radial.source.inventory == world.player.get_meta("inventory"), "same authoritative inventory")
 check(not host.visible, "player window initially closed")
 await key(KEY_B)
 check(host.visible and radial.visible, "B opens radial window")
 var continent: int = root.get_node("GameManager").current_continent_id
 await key(KEY_2)
 check(radial.active == 1, "2 selects crafting")
 check(root.get_node("GameManager").current_continent_id == continent, "module key does not switch continent")
 var theme_before: int = radial.theme_index
 await key(KEY_T)
 check(radial.theme_index == (theme_before + 1) % 3, "T changes in-game theme")
 items.inventory.add_item("ore", 3)
 items.inventory.add_item("herb", 2)
 var ore: int = items.inventory.get_item_count("ore")
 var marks: int = items.inventory.get_item_count("mage_mark")
 radial._craft_mark("mage_recipe")
 check(items.inventory.get_item_count("ore") == ore - 3, "mark crafting consumes real materials")
 check(items.inventory.get_item_count("mage_mark") == marks + 1, "mark output in shared bag")
 check(root.get_node("GameState").player_professions == ["warrior"], "crafting cannot grant profession")
 var crafting = root.get_node("CraftingSystem")
 var fixture := Recipe.new()
 fixture.id = "radial_test"
 fixture.name = "UI 集成测试配方"
 fixture.inputs.assign([{"item_id":"herb", "count":1}])
 fixture.output_item_id = "ore"
 fixture.output_count = 1
 fixture.success_rate = 1.0
 fixture.craft_time = 0.01
 fixture.time_start = "00:00"
 fixture.time_end = "23:59"
 crafting.recipes[fixture.id] = fixture
 items.inventory.add_item("herb", 1)
 var herb: int = items.inventory.get_item_count("herb")
 ore = items.inventory.get_item_count("ore")
 radial._pick_recipe(fixture.id)
 check(radial.recipe_id == fixture.id, "real recipe can be selected")
 await radial._craft_game(fixture.id)
 check(items.inventory.get_item_count("herb") == herb - 1 and items.inventory.get_item_count("ore") == ore + 1, "async crafting updates authoritative bag")
 check(not crafting.busy.has(items.inventory), "crafting releases inventory lock")
 crafting.recipes.erase(fixture.id)
 radial._select(2)
 check(radial.center_info.text.contains("%.0f" % world.player.hp), "real health displayed")
 radial._select(3)
 radial.show_legacy()
 check(not radial.visible and host.page_container.visible and radial.return_button.visible, "original shop/profession UI remains accessible")
 radial.show_radial()
 check(radial.visible and not host.page_container.visible, "return from legacy to radial")
 await key(KEY_ESCAPE)
 check(not host.visible, "Escape closes original host")
 await key(KEY_TAB)
 check(host.visible and radial.visible, "Tab reopens radial")
 world.player.velocity = Vector2(10, 0)
 world.player._physics_process(0.016)
 check(world.player.velocity == Vector2.ZERO, "existing movement guard active with radial open")
 await key(KEY_M)
 check(not host.visible and world.map_system.any_open(), "map remains mutually exclusive")
 world.map_system.close_all()
 host.show()
 for i in 4:
  radial._select(i)
  await process_frame
  await process_frame
  var panel: Control = radial.canvas.get_node("DetailPanel")
  check(panel.size.is_equal_approx(Vector2(448, 532)), "module %d keeps panel bounds" % i)
 check(items.inventory.fits(items.inventory.snapshot()), "inventory remains valid")
 world.queue_free()
 for i in 3: await process_frame
 print("Game radial: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)

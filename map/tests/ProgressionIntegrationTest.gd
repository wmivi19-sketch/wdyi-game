extends SceneTree

var failures: int = 0
var checks: int = 0
var manager: Node
var clock: Node
var demo: Node2D
var world: Node
var actor: ProgressionPlayer

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)

func switch_map(id: int) -> void:
	clock.switch_to_continent(id)
	for i in range(3):
		await process_frame
	await physics_frame
	actor.set_physics_process(false)

func _run() -> void:
	manager = root.get_node("ClassManager")
	clock = root.get_node("GameManager")
	demo = load("res://scenes/MapDemo.tscn").instantiate()
	root.add_child(demo)
	for i in range(4):
		await process_frame
	await physics_frame
	world = demo.progression_world
	actor = demo.player
	actor.set_physics_process(false)
	var state = manager.players[1]
	check(state.class_ids == ["warrior"], "existing player starts with exactly one class")
	check(actor.appearance.current_job == "warrior", "initial class updates existing appearance")
	check(actor.stats.max_hp == 120.0, "existing player receives class HP")
	# Harvest actual JSON markers, not injected inventory grants.
	for marker in demo.loader.resource_points.get_children():
		actor.teleport_to(marker.global_position)
		world.interact()
	check(world.inventory.count_item("ore") == 6 and world.inventory.count_item("herb") == 6 and world.inventory.count_item("wood") == 6, "map resources populate authoritative inventory")
	world.interact()
	check(world.inventory.count_item("wood") == 6, "resource cannot be harvested twice")
	check(world.craft("mage_recipe") and world.craft("ranger_recipe"), "existing inventory crafts both marks")
	check(state.class_ids.size() == 1, "crafting does not directly grant classes")
	var altar: RitualAltar = world.current_altars[0]
	actor.teleport_to(altar.global_position)
	clock.current_period = 0
	world.interact()
	check(not manager.active.has(1), "existing morning clock rejects night ritual")
	clock.current_period = 2
	world.interact()
	check(manager.active.has(1), "E interaction starts ritual at existing map altar")
	manager.apply_confirmed_damage(1, 5.0)
	check(not manager.active.has(1) and world.inventory.count_item("mage_mark") == 1, "combat interrupts and preserves mark")
	world.interact()
	actor.position += Vector2(60, 0)
	manager._physics_process(9.0)
	check(state.class_ids.size() == 1 and not manager.active.has(1), "walking away cancels channel")
	actor.teleport_to(altar.global_position)
	world.interact()
	# A local completion callback attempts interruption; committed state must survive.
	var interrupt_on_form := func(id: int, _form: Dictionary): manager.interrupt_ritual(id)
	manager.form_changed.connect(interrupt_on_form)
	manager._physics_process(9.0)
	manager.form_changed.disconnect(interrupt_on_form)
	check(state.class_ids == ["warrior", "mage"] and world.inventory.count_item("mage_mark") == 0, "successful channel consumes exactly one mark")
	check(actor.appearance.current_job == "mage", "ritual updates real AppearanceManager")
	# Verify map reload does not regenerate collected resources.
	await switch_map(1)
	await switch_map(0)
	check(not demo.loader.resource_points.get_child(0).visible, "map reload preserves depletion")
	await switch_map(1)
	actor.teleport_to(world.current_altars[0].global_position)
	world.interact()
	await switch_map(2)
	check(not manager.active.has(1) and world.inventory.count_item("ranger_mark") == 1, "map switch interrupts without consuming mark")
	# Claim existing map story marker once, including after revisiting.
	var artifact: Node2D
	for marker in demo.loader.special_locations.get_children():
		if marker.get_meta("map_data").kind == "artifact": artifact = marker
	actor.teleport_to(artifact.global_position)
	world.interact()
	world.interact()
	check(world.inventory.count_item("sun_mark") == 1, "story event reward is idempotent")
	await switch_map(1)
	actor.teleport_to(world.current_altars[0].global_position)
	world.interact()
	manager._physics_process(9.0)
	check(state.class_ids.size() == 3 and manager.replicated_forms[1].is_demigod, "third class produces demigod")
	check(actor.appearance.current_job == "ranger", "third class changes existing skin")
	check(not manager.add_class_slot("warrior", 1), "duplicate class cannot exceed cap")
	var fourth := ClassInfo.new()
	fourth.class_id = "fourth"
	manager.classes["fourth"] = fourth
	check(not manager.add_class_slot("fourth", 1), "fourth distinct class rejected")
	await switch_map(5)
	actor.teleport_to(world.current_altars[0].global_position)
	clock.current_day = 11
	world.interact()
	check(not manager.active.has(1), "existing day 11 blocks ascension")
	clock.current_day = 14
	world.interact()
	clock.current_day = 15
	manager._physics_process(13.0)
	check(state.deity == null and world.inventory.count_item("sun_mark") == 1, "window closure cancels ascension")
	clock.current_day = 12
	world.interact()
	manager._physics_process(13.0)
	check(state.deity != null and actor.stats.max_hp == 280.0, "real player ascends with doubled base HP")
	check(actor.skill_ids.has("sun_burst"), "divine ability is available")
	check(actor.appearance.current_job == "sun_god", "deity form reaches appearance pipeline")
	check(actor.deity_active, "deity receives visible golden aura")
	var enemy := load("res://scenes/Player.tscn").instantiate() as ProgressionPlayer
	demo.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.position = actor.position + Vector2(30, 0)
	manager.register_player(2, enemy, ProgressionInventory.new(), {}, "warrior")
	check(world.cast_sun_burst() and enemy.hp == 50.0, "divine skill damages registered target in range")
	check(not world.cast_sun_burst() and enemy.hp == 50.0, "divine cooldown prevents repeated damage")
	manager.apply_confirmed_damage(1, 9999.0)
	check(actor.hp == 0.0 and state.deity == null and state.class_ids.size() == 3, "death removes deity and preserves classes")
	check(actor.stats.max_hp == 180.0 and not actor.skill_ids.has("sun_burst"), "death removes divine HP and skill")
	check(actor.appearance.current_job == "ranger" and not world.cast_sun_burst(), "death restores class skin and blocks casting")
	check(not actor.deity_active, "death removes deity aura")
	manager.unregister_player(2)
	demo.queue_free()
	await process_frame
	check(not manager.players.has(1), "scene exit unregisters player")
	print("Progression integration: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

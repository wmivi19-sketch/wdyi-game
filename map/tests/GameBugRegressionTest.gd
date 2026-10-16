extends SceneTree

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)

func _run() -> void:
	var manager: Node = root.get_node("ClassManager")
	var clock: Node = root.get_node("GameManager")
	var demo = load("res://scenes/MapDemo.tscn").instantiate()
	root.add_child(demo)
	for i in range(5): await process_frame
	var actor: ProgressionPlayer = demo.player
	actor.set_physics_process(false)
	var world: Node = demo.progression_world
	var selector: OptionButton
	for child in demo.character_info_ui.get_children():
		if child is OptionButton: selector = child
	clock.switch_to_continent(1)
	for i in range(3): await process_frame
	check(selector.selected == 1, "keyboard/API map changes synchronize continent selector")
	demo.loader.location_entered.emit("test_altar", "altar", actor)
	check(demo.status.text.contains("第 1 天") and demo.status.text.contains("test_altar"), "location hint preserves day and period")
	demo.loader.location_exited.emit("test_altar", "altar", actor)
	check(demo.status.text.contains("第 1 天"), "leaving location preserves clock display")
	var previous_status: String = demo.status.text
	var unrelated_actor := Node2D.new()
	demo.loader.location_entered.emit("other_player_altar", "altar", unrelated_actor)
	unrelated_actor.free()
	check(demo.status.text == previous_status, "other actors cannot overwrite local HUD")
	clock.switch_to_continent(0)
	for i in range(3): await process_frame
	clock.current_period = 2
	actor.teleport_to(world.current_altars[0].global_position)
	world.inventory.add_item("mage_mark", 1)
	world.interact()
	check(manager.active.has(1), "night ritual starts for transition regression")
	for i in range(3): clock.next_time_period()
	check(not manager.active.has(1) and world.inventory.count_item("mage_mark") == 1,
		"advance-day button cannot skip forbidden daytime during ritual")
	manager.interrupt_ritual(1)
	var previous_hp: float = actor.hp
	manager.apply_confirmed_damage(1, NAN)
	manager.apply_confirmed_damage(1, INF)
	check(actor.hp == previous_hp, "invalid damage cannot corrupt player HP")
	check(not manager.register_player(77, null, ProgressionInventory.new(), {}, "warrior"),
		"null actor cannot create a broken player registration")
	actor.skill_ids.append("sun_burst")
	var enemy := load("res://scenes/Player.tscn").instantiate() as ProgressionPlayer
	demo.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.position = actor.position + Vector2(20, 0)
	enemy.current_area_tag = "continent_5"
	manager.register_player(2, enemy, ProgressionInventory.new(), {}, "warrior")
	world.next_divine_cast_ms = 0
	world.cast_sun_burst()
	check(enemy.hp == 100.0, "divine range damage cannot hit another continent")
	enemy.current_area_tag = actor.current_area_tag
	world.next_divine_cast_ms = 0
	world.cast_sun_burst()
	check(enemy.hp == 50.0, "same-continent target still receives divine damage")
	manager.unregister_player(2)
	var replacement := load("res://scenes/Player.tscn").instantiate() as ProgressionPlayer
	demo.add_child(replacement)
	replacement.set_physics_process(false)
	manager.register_player(2, replacement, ProgressionInventory.new(), {}, "warrior")
	enemy.queue_free()
	await process_frame
	check(manager.players.has(2) and manager.players[2].actor == replacement,
		"old actor exit cannot unregister a replacement using the same ID")
	replacement.queue_free()
	await process_frame
	check(not manager.players.has(2) and not manager.replicated_forms.has(2),
		"removed actor automatically releases player registration and cache")
	manager.unregister_player(2)
	demo.queue_free()
	await process_frame
	print("Game bug regression: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

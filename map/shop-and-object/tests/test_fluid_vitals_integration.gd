extends SceneTree
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")
	create_timer(45).timeout.connect(func(): quit(1))

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var manager := root.get_node("GameManager")
	manager.set_physics_process(false)
	var session := root.get_node("GameSession")
	session.initialize_new_game()
	var world = load("res://scenes/MapDemo.tscn").instantiate()
	root.add_child(world)
	for frame in range(10): await process_frame
	var adapter = world.get_node("WorldItems/FluidVitals")
	var hud = adapter.hud
	var combat = world.get_node("MapCombat")
	var hero = manager.get_combatant(0)
	check(hud != null and adapter.visible, "HUD mounted in formal map")
	check(hud.position == Vector2(24, 24), "HUD stays in top-left screen coordinates")
	check(not combat.hud.visible and combat.info.is_visible_in_tree(), "Replaces old bars and retains combat controls")
	check(hud.hp.current_value == world.player.hp, "Initial HP uses original player")
	check(world.player.get_meta("inventory") == world.get_node("WorldItems").inventory, "Shared inventory unchanged")
	hero.resources.damage(17)
	check(hud.hp.current_value == hero.resources.hp, "Damage signal updates HP")
	hero.resources.stamina = 27
	hero.resources.mana = 13
	hero.resources.publish()
	check(hud.stamina.current_value == 27 and hud.mp.current_value == 13, "Stamina and mana publish updates UI")
	var local_hp: float = hud.hp.current_value
	manager.resource_changed.emit(1, &"hp", 1, 100)
	check(hud.hp.current_value == local_hp, "AI resources cannot overwrite player HUD")
	root.get_node("ClassManager").add_class_slot("mage", 1)
	check(hud.mp.maximum_value == hero.resources.max_mana, "Profession maximum changes propagate")
	var host = world.character_info_ui.character_info_panel
	host.show()
	await process_frame
	await process_frame
	check(not adapter.visible, "Character panel hides HUD")
	host.hide()
	world.map_system.is_local_open = true
	await process_frame
	await process_frame
	check(not adapter.visible, "Map hides HUD")
	world.map_system.is_local_open = false
	await process_frame
	await process_frame
	check(adapter.visible, "HUD returns after overlays close")
	manager.switch_to_continent(1)
	for frame in range(8): await process_frame
	check(world.get_node("WorldItems/FluidVitals") == adapter, "Switching continents does not duplicate HUD")
	check(is_equal_approx(hud.hp.displayed_value, hero.resources.hp), "Map sync snaps to authoritative resources")
	var snapshot: Dictionary = manager.export_combat()
	hero.resources.mana = 1
	hero.resources.publish()
	manager.restore_combat(snapshot)
	check(hud.mp.current_value == hero.resources.mana, "Combat snapshot restoration refreshes HUD")
	var resource_connections: int = manager.resource_changed.get_connections().size()
	world.free()
	await process_frame
	check(manager.resource_changed.get_connections().size() < resource_connections, "World teardown disconnects resource listeners")
	print("Fluid vitals integration: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

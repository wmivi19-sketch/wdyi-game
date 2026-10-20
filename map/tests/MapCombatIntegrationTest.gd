extends SceneTree
var failures: int = 0
var checks: int = 0
var clock: Node
var session: Node

func _initialize() -> void:
	call_deferred("run")
	create_timer(45.0).timeout.connect(func(): quit(1))

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func wait_scene(path: String) -> void:
	for frame in range(3000):
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path:
			for extra in range(8):
				await process_frame
			return
	check(false, "scene transition: " + path)

func run() -> void:
	clock = root.get_node("GameManager")
	session = root.get_node("GameSession")
	clock.set_physics_process(false)
	session.storage_override = {"save_path": "user://map-combat-tests/save.json", "preferences_path": "user://map-combat-tests/preferences.cfg"}
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await wait_scene("res://scenes/ui/main_menu.tscn")
	check(current_scene.bg_sprite.texture != null, "original cover loads")
	await capture("integrated-cover")
	current_scene._start_new_game()
	await wait_scene("res://scenes/TutorialCandleWell.tscn")
	current_scene.returned_via_sky = true
	current_scene.opened["G4"] = true
	current_scene.load_level(0,[60,16])
	current_scene.finish_tutorial()
	await wait_scene("res://scenes/MapDemo.tscn")
	var world = current_scene
	var hero = clock.get_combatant(0)
	check(world.loader.current_data.id == "continent_0", "cover starts original map")
	check(world.player.combat_managed, "original player uses combat pool")
	check(world.player.hp == hero.resources.hp, "single HP source")
	check(world.player.appearance.current_job == "warrior", "original appearance retained")
	check(hero.q is ARPGDamageSkill, "warrior loadout configured")
	await capture("integrated-map")
	check(not clock.try_cast_skill(0, &"Q", 1), "cross-continent damage rejected")
	clock.switch_to_continent(1)
	for frame in range(8):
		await process_frame
	world.player.teleport_to(world.loader.to_global(world.loader.spawn_position))
	var enemy = clock.get_combatant(1)
	check(enemy.visible, "current-continent AI visible on original map")
	check(clock.try_cast_skill(0, &"Q", 1), "map melee hits selected AI")
	check(enemy.resources.hp == 70.0, "AI damage persists in same manager")
	var old_hp: float = world.player.hp
	root.get_node("ClassManager").apply_confirmed_damage(1, 10.0)
	check(world.player.hp == old_hp - 10.0 and hero.resources.hp == world.player.hp, "old damage API shares pool")
	root.get_node("ClassManager").add_class_slot("mage", 1)
	check(hero.r is ARPGDamageSkill and world.player.appearance.current_job == "mage", "existing progression updates combat and appearance")
	check(clock.try_cast_skill(0, &"W"), "map self buff")
	var mana_before: float = hero.resources.mana
	check(session.save_game(), "save original map with combat extension")
	var saved: Dictionary = session.read_snapshot()
	check(saved.has("combat"), "save includes resources cooldowns effects and AI")
	var legacy := saved.duplicate(true)
	legacy.erase("combat")
	check(session.valid_snapshot(legacy), "legacy saves remain valid")
	var bad := saved.duplicate(true)
	bad.combat.players[0].mana = -1
	check(not session.valid_snapshot(bad), "invalid combat resource rejected")
	bad = saved.duplicate(true)
	bad.combat.players[0].cooldowns["Q"] = INF
	check(not session.valid_snapshot(bad), "invalid cooldown rejected")
	check(session.return_to_menu(false), "return to original cover")
	await wait_scene("res://scenes/ui/main_menu.tscn")
	check(not clock.world_active, "menu pauses combat")
	current_scene._load_game()
	await wait_scene("res://scenes/MapDemo.tscn")
	world = current_scene
	hero = clock.get_combatant(0)
	check(world.loader.current_data.id == "continent_1", "continue restores map")
	check(is_equal_approx(hero.resources.mana, mana_before), "continue restores mana")
	check(float(hero.cooldowns.get(&"W", 0.0)) == 10.0 and hero.effects.has(&"guard"), "continue restores cooldown and buff")
	check(clock.get_combatant(1).resources.hp == 70.0, "continue restores AI health")
	check(world.player.hp == old_hp - 10.0, "continue restores shared HP")
	clock.damage_player(5, 1000)
	for period in range(42):
		clock.next_time_period()
	for frame in range(8):
		await process_frame
	check(clock.current_day == 14 and clock.phase == clock.Phase.ENDGAME, "42 periods enter endgame")
	check(world.loader.current_data.id == "continent_5", "endgame loads existing final map")
	await capture("integrated-endgame")
	check(clock.get_player(5).continent_id != clock.END_CONTINENT_ID, "dead AI excluded from teleport")
	var positions := {}
	for id in range(5):
		var actor = clock.get_combatant(id)
		positions[actor.global_position] = true
		var cell: Vector2i = world.loader.terrain_layer.local_to_map(world.loader.terrain_layer.to_local(actor.global_position))
		var tile = world.loader.terrain_layer.get_cell_tile_data(cell)
		check(tile != null and tile.get_collision_polygons_count(0) == 0, "safe final-map landing %d" % id)
	check(positions.size() == 5, "survivor landing points do not overlap")
	check(session.save_game(), "endgame save remains valid")
	clock.switch_to_continent(0)
	check(clock.current_continent_id == 5, "cannot leave final map through debug selector")
	# 实际读取不含 combat 字段的旧存档，不能只验证格式。
	var old_path := "user://map-combat-tests/legacy.json"
	var file := FileAccess.open(old_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	session.return_to_menu(false)
	await wait_scene("res://scenes/ui/main_menu.tscn")
	check(session.load_game(old_path), "legacy save loads")
	change_scene_to_file("res://scenes/MapDemo.tscn")
	await wait_scene("res://scenes/MapDemo.tscn")
	check(clock.get_player(0).continent_id == clock.CONTINENTS[1].id, "legacy save continent aligns with original map")
	check(current_scene.player.hp == float(legacy.hp), "legacy save HP restores into combat pool")
	print("Map combat integration: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.validation"))
	root.get_texture().get_image().save_png("res://.validation/%s.png" % label)

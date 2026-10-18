extends Node
var failures: int = 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	GameManager.set_physics_process(false)
	GameManager.start_new_game()
	check(GameManager.get_player(0)["health"] == 100, "legacy initial HP")
	check(GameManager.get_combatant(0).q == null, "unassigned has no skills")
	GameManager.set_profession(0, GameManager.Profession.WARRIOR)
	GameManager.set_profession(1, GameManager.Profession.MAGE)
	var actor := GameManager.get_combatant(0)
	var enemy := GameManager.get_combatant(1)
	check(actor.q is ARPGDamageSkill and enemy.r is ARPGDamageSkill, "hero loadouts")
	check(actor.resources.max_stamina == 140.0 and enemy.resources.max_mana == 200.0, "hero resource capacities")
	GameManager.update_player_position(0, Vector2(100, 300))
	GameManager.update_player_position(1, Vector2(160, 300))
	var stamina_before := actor.resources.stamina
	check(not GameManager.try_cast_skill(0, &"Q", 1), "cross-continent attack rejected")
	check(actor.resources.stamina == stamina_before, "rejected attack costs nothing")
	GameManager.add_item(0, "wood", 2)
	GameManager.damage_player(0, 20)
	check(actor.resources.hp == 80.0, "legacy damage reaches combat pool")
	enemy.resources.spend(40.0, 0.0)
	GameManager.tick_combat(2.0)
	check(actor.resources.hp == 80.0 and GameManager.current_day == 1, "no HP regen or automatic strategy advancement")
	check(is_equal_approx(enemy.resources.mana, 84.0), "mage constant regeneration plus passive")
	check(GameManager.try_cast_skill(0, &"E"), "untargeted dash before teleport")
	var stamina_at_teleport := actor.resources.stamina
	for index in range(42):
		GameManager.advance_period()
	check(GameManager.phase == GameManager.Phase.ENDGAME, "legacy endgame boundary")
	check(actor.resources.hp == 80.0, "teleport preserves HP")
	check(actor.global_position == GameManager.END_SPAWNS[0], "combat actor teleported")
	check(float(actor.cooldowns[&"E"]) == 3.0 and actor.resources.stamina == stamina_at_teleport, "teleport preserves cooldown and stamina")
	check(actor.dash_left == 0.0, "teleport cancels pending motion")
	check(GameManager.get_player(0)["inventory"]["wood"] == 2, "teleport preserves inventory")
	GameManager.update_player_position(1, actor.global_position + Vector2(60, 0))
	check(GameManager.try_cast_skill(0, &"Q", 1), "same-continent melee attack")
	check(enemy.resources.hp == 70.0 and GameManager.get_player(1)["health"] == 70, "skill synchronizes old health API")
	check(not GameManager.try_cast_skill(0, &"Q", 1), "cooldown enforced")
	check(enemy.cooldowns.is_empty(), "independent cooldowns")
	var snapshot := GameManager.get_combat_state(0)
	snapshot["cooldowns"][&"Q"] = 999.0
	check(float(actor.cooldowns[&"Q"]) == 2.0, "combat snapshot detached")
	check(GameManager.try_cast_skill(0, &"W"), "self buff")
	GameManager.damage_player(0, 10)
	check(is_equal_approx(actor.resources.hp, 74.0), "legacy damage respects mitigation")
	GameManager.tick_combat(4.1)
	check(not actor.effects.has(&"guard"), "buff expiration")
	GameManager.heal_player(0, 10)
	check(actor.resources.hp == 84.0, "legacy healing reaches combat pool")
	GameManager.set_profession(0, GameManager.Profession.MAGE)
	actor.resources.mana = 150.0
	check(GameManager.try_cast_skill(1, &"W"), "target guard before ultimate")
	check(GameManager.try_cast_skill(0, &"R", 1), "mage ultimate")
	check(enemy.is_stunned() and not enemy.dead, "ultimate applies stun after mitigated hit")
	check(not GameManager.try_cast_skill(1, &"E"), "stunned target cannot cast")
	GameManager.tick_combat(2.1)
	check(not enemy.is_stunned(), "stun expires through manager tick")
	GameManager.damage_player(1, 1000)
	check(enemy.dead and not GameManager.get_player(1)["alive"], "skill death synchronized")
	check(not GameManager.heal_player(1, 20), "legacy healing cannot revive")
	check(not GameManager.try_cast_skill(1, &"E"), "dead cannot cast")
	check(not GameManager.try_cast_skill(0, &"Q", 1), "dead target rejected")
	var cooldown_before := float(actor.cooldowns[&"R"])
	var hp_before := actor.resources.hp
	GameManager.set_profession(0, GameManager.Profession.WARRIOR)
	check(float(actor.cooldowns[&"R"]) == cooldown_before and actor.resources.hp == hp_before, "profession change does not reset cooldown or heal")
	GameManager.set_profession(0, GameManager.Profession.RANGER)
	check(actor.q == null and GameManager.get_player(0)["profession"] == GameManager.Profession.RANGER, "other professions remain valid")
	# 日末结算通过旧入口死亡后，核心实体也应死亡且不传送。
	GameManager.start_new_game()
	var settlement := func(day):
		if day == 14:
			GameManager.damage_player(5, 100)
	GameManager.day_finished.connect(settlement)
	for index in range(42):
		GameManager.advance_period()
	GameManager.day_finished.disconnect(settlement)
	check(GameManager.get_combatant(5).dead, "daily settlement kills combat actor")
	check(GameManager.get_player(5)["continent_id"] != GameManager.END_CONTINENT_ID, "daily death excluded from teleport")
	# 通知监听者不能在一次扣血事务内重开，或在零血时再施法。
	GameManager.start_new_game()
	GameManager.set_profession(0, GameManager.Profession.WARRIOR)
	var observed := {"calls": 0, "deaths": 0}
	var on_health := func(id, health, _maximum):
		if id == 0 and health == 0:
			observed.calls += 1
			check(not GameManager.get_player(0)["alive"], "notification observes committed death")
			check(not GameManager.try_cast_skill(0, &"E"), "zero HP listener cannot cast")
			GameManager.start_new_game()
	var on_death := func(id):
		if id == 0:
			observed.deaths += 1
	GameManager.health_changed.connect(on_health)
	GameManager.player_died.connect(on_death)
	GameManager.damage_player(0, 1000)
	GameManager.health_changed.disconnect(on_health)
	GameManager.player_died.disconnect(on_death)
	check(observed.calls == 1 and observed.deaths == 1, "single death notification and blocked reset reentry")
	GameManager.start_new_game()
	check(GameManager.get_player(0)["alive"] and GameManager.get_combatant(0).cooldowns.is_empty(), "restart resets combat")
	# 实际挂载 UI，覆盖重开后重绑和离开场景隐藏实体。
	var scene := preload("res://scenes/CombatArena.tscn").instantiate()
	add_child(scene)
	GameManager.set_profession(0, GameManager.Profession.MAGE)
	GameManager.start_new_game()
	check(scene.hud.bound == GameManager.get_combatant(0).resources, "arena HUD rebinds after restart")
	GameManager.tick_combat(0.016)
	scene.free()
	check(not GameManager.get_combatant(0).visible, "arena exit hides persistent actors")
	if failures == 0:
		print("PASS: ARPG integration, legacy health, loadouts, resources, death, teleport and arena UI")
	get_tree().quit(0 if failures == 0 else 1)

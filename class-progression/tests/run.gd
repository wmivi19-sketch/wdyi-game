extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
	else:
		print("PASS: ", description)

func _run() -> void:
	var demo := load("res://demo/main.gd").new() as Node3D
	root.add_child(demo)
	# Access autoloads through root so the runner also works as a --script entry.
	var manager: Node = root.get_node("ClassManager")
	var clock: Node = root.get_node("TimeManager")
	var state = manager.players[1]
	var inventory: ProgressionInventory = state.inventory
	var actor: ProgressionPlayer = state.actor
	var recipe := ClassRecipe.new()
	recipe.materials = {"ore": 5}
	recipe.output_mark_id = "mage_mark"
	check(not inventory.craft(recipe) and inventory.count_item("ore") == 4, "failed craft is atomic")
	recipe.materials = {"ore": 2}
	check(inventory.craft(recipe), "craft grants qualification only")
	check(state.class_ids.size() == 2, "mark does not grant a class")
	actor.position = Vector3(100, 0, 0)
	check(not manager.check_ritual_readiness("learn_mage", 1, "holy"), "altar distance checked")
	actor.position = Vector3.ZERO
	manager.start_ritual("learn_mage", "holy")
	manager.apply_confirmed_damage(1, 1.0)
	check(not manager.active.has(1) and inventory.count_item("mage_mark") == 1, "damage interrupts without consuming mark")
	manager.start_ritual("learn_mage", "holy")
	actor.current_area_tag = "elsewhere"
	manager._physics_process(9.0)
	check(state.class_ids.size() == 2 and inventory.count_item("mage_mark") == 1, "leaving area cancels ritual")
	actor.current_area_tag = "holy_altar"
	manager.start_ritual("learn_mage", "holy")
	# Changing original requirements must not alter an active ritual snapshot.
	manager.rituals["learn_mage"].start_day = 99
	manager._physics_process(9.0)
	check(state.class_ids.size() == 3 and inventory.count_item("mage_mark") == 0, "snapshot completion consumes mark once")
	check(not manager.add_class_slot("rogue", 1), "fourth class rejected")
	check(not manager.add_class_slot("mage", 1), "duplicate class rejected")
	check(actor.stats["max_hp"] == 160.0, "default base HP applied before class bonuses")
	check(actor.skill_ids.count("shared_skill") == 1, "skills deduplicated")
	check(not manager.ascend_to_deity(manager.deities["sun"], 1), "direct ascension bypass rejected")
	clock.current_day = 11
	check(not manager.check_ritual_readiness("sun_ascension", 1, "holy"), "day 11 rejected")
	clock.current_day = 14
	manager.start_ritual("sun_ascension", "holy")
	clock.current_day = 15
	manager._physics_process(13.0)
	check(state.deity == null and inventory.count_item("sun_mark") == 1, "closing window interrupts without consumption")
	clock.current_day = 12
	manager.start_ritual("sun_ascension", "holy")
	manager._physics_process(13.0)
	check(state.deity != null and actor.stats["max_hp"] == 260.0, "ascension doubles base HP only")
	check(actor.skill_ids.has("sun_burst"), "divine skill granted")
	manager.apply_confirmed_damage(1, 9999.0)
	check(state.deity == null and state.class_ids.size() == 3, "death removes deity and preserves classes")
	check(actor.hp == 0.0 and actor.stats["max_hp"] == 160.0, "death does not heal and restores normal HP limit")
	check(not actor.skill_ids.has("sun_burst"), "divine skill removed on death")
	print("Failures: ", failures)
	quit(0 if failures == 0 else 1)

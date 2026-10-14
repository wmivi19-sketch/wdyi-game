extends Node

var _failures: int = 0
var _teleports: int = 0
var _endgames: int = 0


func _ready() -> void:
	GameManager.player_teleported.connect(func(_id, _continent, _position): _teleports += 1)
	GameManager.endgame_started.connect(func(): _endgames += 1)
	GameManager.start_new_game()
	_check(GameManager.get_players().size() == 6, "six players")
	var ai_count: int = 0
	var homes: Dictionary = {}
	for player in GameManager.get_players():
		if player["is_ai"]:
			ai_count += 1
		homes[player["home_continent_id"]] = true
	_check(ai_count == 5 and homes.size() == 6, "five AI and six unique continents")
	_check(not GameManager.damage_player(99, 10), "invalid player rejected")
	_check(not GameManager.add_item(0, "wood", -1), "negative amount rejected")
	GameManager.add_item(0, "wood", 3)
	_check(not GameManager.remove_item(0, "wood", 4), "cannot overspend inventory")
	_check(GameManager.remove_item(0, "wood", 3), "consume stack")
	_check(GameManager.get_player(0)["inventory"].is_empty(), "empty stack removed")
	GameManager.add_item(0, "wood", 2)
	var snapshot: Dictionary = GameManager.get_player(0)
	snapshot["inventory"]["wood"] = 999
	_check(GameManager.get_player(0)["inventory"]["wood"] == 2, "snapshot isolation")
	GameManager.set_profession(0, GameManager.Profession.WARRIOR)
	GameManager.set_profession_status(0, "skill_cooldown", 2)
	_check(GameManager.get_player(0)["profession_status"]["skill_cooldown"] == 2, "profession status")
	GameManager.damage_player(0, 20)
	GameManager.heal_player(0, 200)
	_check(GameManager.get_player(0)["health"] == 100, "healing capped")
	GameManager.damage_player(5, 1000)
	_check(not GameManager.heal_player(5, 100), "dead player cannot heal")
	var body := CharacterBody2D.new()
	add_child(body)
	_check(GameManager.register_player_body(0, body), "register actor")
	_check(body.global_position == GameManager.get_player(0)["spawn_position"], "actor birth position")
	body.velocity = Vector2(30, 50)
	# 41 transitions reach day 14 evening without premature teleport.
	for index in range(41):
		_check(GameManager.advance_period(), "advance %d" % index)
	_check(GameManager.current_day == 14 and GameManager.current_period == GameManager.Period.EVENING, "day 14 evening boundary")
	_check(GameManager.phase == GameManager.Phase.SURVIVAL and _teleports == 0, "no early teleport")
	GameManager.advance_period()
	_check(GameManager.phase == GameManager.Phase.ENDGAME, "endgame after 42 periods")
	_check(_teleports == 5 and _endgames == 1, "only five survivors teleported once")
	_check(body.global_position == GameManager.END_SPAWNS[0] and body.velocity == Vector2.ZERO, "physical actor teleport")
	_check(GameManager.get_player(5)["continent_id"] != GameManager.END_CONTINENT_ID, "dead player stays")
	_check(GameManager.get_player(0)["inventory"]["wood"] == 2, "inventory preserved")
	_check(GameManager.get_player(0)["profession"] == GameManager.Profession.WARRIOR, "profession preserved")
	_check(not GameManager.advance_period() and _endgames == 1, "endgame idempotent")
	GameManager.start_new_game()
	_check(GameManager.current_day == 1 and GameManager.current_period == GameManager.Period.MORNING, "reset time")
	_check(GameManager.get_player(5)["alive"] and GameManager.get_player(0)["inventory"].is_empty(), "reset players")
	_check(body.global_position == GameManager.get_player(0)["spawn_position"], "reset actor position")
	# Reentrant callbacks must not cause double advancement.
	var listener := func(_day, _period): GameManager.advance_period()
	GameManager.period_changed.connect(listener)
	GameManager.advance_period()
	_check(GameManager.current_period == GameManager.Period.NOON, "reentrant advance blocked")
	GameManager.period_changed.disconnect(listener)
	GameManager.unregister_player_body(0, body)
	body.queue_free()
	GameManager.start_new_game()
	_teleports = 0
	_endgames = 0
	for index in range(42):
		GameManager.advance_period()
	_check(_teleports == 6 and _endgames == 1, "all six survivors transported")
	var landing_positions: Dictionary = {}
	for player in GameManager.get_players():
		landing_positions[player["position"]] = true
		_check(player["continent_id"] == GameManager.END_CONTINENT_ID, "end continent for every survivor")
	_check(landing_positions.size() == 6, "six separate landing points")
	GameManager.start_new_game()
	_teleports = 0
	_endgames = 0
	for id in range(6):
		GameManager.damage_player(id, 100)
	for index in range(42):
		GameManager.advance_period()
	_check(_teleports == 0 and _endgames == 1, "all dead boundary stays valid")
	if _failures == 0:
		print("PASS: GameManager time, players, inventory, health and teleport tests")
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)

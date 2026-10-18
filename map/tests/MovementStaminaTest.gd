extends SceneTree
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func run() -> void:
	var pool := ARPGResources.new()
	root.add_child(pool)
	pool.reset()
	pool.mana = 50.0
	pool.tick(1.0, 1.0, 0.0, true)
	check(is_equal_approx(pool.stamina, 88.0), "moving drains 12 stamina per second without regeneration")
	check(pool.mana == 55.0 and pool.hp == 100.0, "movement preserves mana regeneration and HP")
	pool.tick(0.6)
	check(is_equal_approx(pool.stamina, 88.0), "stopping respects recovery delay")
	pool.tick(1.0)
	check(pool.stamina == 100.0, "stopping restores up to maximum")
	pool.tick(100.0, 1.0, 0.0, true)
	check(pool.stamina == 0.0, "movement cannot produce negative stamina")
	var split := ARPGResources.new()
	root.add_child(split)
	split.reset()
	for frame in range(60):
		split.tick(1.0 / 60.0, 1.0, 0.0, true)
	check(is_equal_approx(split.stamina, 88.0), "drain is frame-rate independent")
	pool.free()
	split.free()
	var hero := ARPGHeroes.create(false)
	root.add_child(hero)
	hero.set_physics_process(false)
	hero.collision_layer = 0 # 与正式地图代理一致，避免和外部角色自身碰撞。
	hero.collision_mask = 0
	# 使用实际带碰撞的外部角色，验证位移后才结算体力。
	var body := CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	body.add_child(shape)
	root.add_child(body)
	var wall := StaticBody2D.new()
	wall.position = Vector2(30, 0)
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(10, 100)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	hero.move_input = Vector2.RIGHT
	var before := hero.resources.stamina
	for frame in range(8):
		await physics_frame
		hero.tick(1.0 / 60.0, body)
	check(body.position.x > 0.0 and hero.resources.stamina < before, "actual walking drains stamina")
	for frame in range(100):
		await physics_frame
		hero.tick(1.0 / 60.0, body)
	check(body.position.x < 20.0 and is_equal_approx(hero.resources.stamina, hero.resources.max_stamina), "holding direction against wall recovers stamina")
	hero.move_input = Vector2.DOWN
	await physics_frame
	hero.tick(1.0 / 60.0, body)
	check(hero.resources.stamina < hero.resources.max_stamina, "sliding along wall consumes stamina")
	hero.move_input = Vector2.ZERO
	for frame in range(65):
		await physics_frame
		hero.tick(1.0 / 60.0, body)
	check(is_equal_approx(hero.resources.stamina, hero.resources.max_stamina), "idle movement body recovers stamina")
	var stun := ARPGStatusEffect.new()
	stun.stun = true
	stun.duration = 1.0
	hero.add_effect(stun)
	hero.move_input = Vector2.DOWN
	hero.resources.spend(0.0, 20.0)
	before = hero.resources.stamina
	var position_before := body.position
	await physics_frame
	hero.tick(0.8, body)
	check(body.position == position_before and hero.resources.stamina > before, "stun blocks motion without draining stamina")
	hero.take_damage(10000.0)
	before = hero.resources.stamina
	hero.tick(2.0, body)
	check(hero.resources.stamina == before, "dead characters neither drain nor regenerate")
	hero.free()
	body.free()
	wall.free()
	print("Movement stamina: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

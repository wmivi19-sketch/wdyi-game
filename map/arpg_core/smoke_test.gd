extends SceneTree
## 命令行：godot --headless --path map --script res://arpg_core/smoke_test.gd
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	test_death_notification()
	test_invalid_targets()
	var a := ARPGHeroes.create(false)
	var b := ARPGHeroes.create(false)
	root.add_child(a)
	root.add_child(b)
	a.set_physics_process(false)
	b.set_physics_process(false)
	b.position = Vector2(60, 0)
	assert(a.try_cast(&"Q", b))
	assert(b.resources.hp == 190.0)
	assert(a.resources.stamina == 115.0)
	assert(not a.try_cast(&"Q", b))
	assert(b.try_cast(&"Q", a)) # 不共享冷却。
	var before := a.resources.hp
	a.resources.tick(1.0)
	assert(a.resources.hp == before) # HP 不自动恢复。
	assert(is_equal_approx(a.resources.stamina, 127.0))
	a.resources.mana = 0.0
	before = a.resources.stamina
	assert(not a.resources.spend(1.0, 10.0))
	assert(a.resources.stamina == before)
	var stun := ARPGStatusEffect.new()
	stun.id = &"test"
	stun.stun = true
	stun.duration = 1.0
	a.add_effect(stun)
	a.add_effect(stun)
	assert(a.effects.size() == 1)
	assert(not a.try_cast(&"E"))
	a._physics_process(1.1)
	assert(not a.is_stunned())
	a.take_damage(10000.0)
	assert(a.dead)
	assert(not a.try_cast(&"E"))
	a.resources.tick(5.0)
	assert(a.resources.hp == 0.0)
	a.revive()
	assert(not a.dead and a.resources.hp == a.resources.max_hp)
	assert(a.cooldowns.is_empty())
	var mage := ARPGHeroes.create(true)
	root.add_child(mage)
	mage.set_physics_process(false)
	assert(mage.try_cast(&"R", b))
	assert(b.is_stunned())
	print("ARPG smoke tests passed")
	a.free()
	b.free()
	mage.free()
	quit()

func test_death_notification() -> void:
	var hero := ARPGHeroes.create(false)
	root.add_child(hero)
	hero.set_physics_process(false)
	var notifications := {"hp": 0, "death": 0}
	var stamina_before := hero.resources.stamina
	hero.died.connect(func(): notifications.death += 1)
	hero.resources.changed.connect(func(kind, value, _maximum):
		if kind != &"hp" or value != 0.0:
			return
		notifications.hp += 1
		assert(hero.dead and not hero.resources.enabled)
		assert(not hero.try_cast(&"E"))
		hero.resources.heal(30.0)
		hero.take_damage(10.0)
	)
	hero.take_damage(10000.0)
	assert(notifications.hp == 1 and notifications.death == 1)
	assert(hero.resources.hp == 0.0)
	assert(hero.resources.stamina == stamina_before)
	assert(hero.cooldowns.is_empty())
	hero.free()

func test_invalid_targets() -> void:
	var hero := ARPGHeroes.create(false)
	var enemy := ARPGHeroes.create(false)
	root.add_child(hero)
	root.add_child(enemy)
	hero.set_physics_process(false)
	enemy.set_physics_process(false)
	var scenery := Node2D.new()
	var plain_node := Node.new()
	root.add_child(scenery)
	root.add_child(plain_node)
	var stamina_before := hero.resources.stamina
	for target in [null, scenery, plain_node, hero]:
		assert(not hero.try_cast(&"Q", target))
	for target in [scenery, plain_node, hero]:
		assert(not hero.try_cast(&"E", target))
	enemy.position = Vector2(1000, 0)
	assert(not hero.try_cast(&"E", enemy))
	enemy.position = Vector2(60, 0)
	enemy.take_damage(10000.0)
	assert(not hero.try_cast(&"Q", enemy))
	assert(not hero.try_cast(&"E", enemy))
	var freed_target := Node2D.new()
	freed_target.free()
	assert(not hero.q.valid_target(hero, freed_target))
	assert(not hero.e.can_execute(hero, freed_target))
	assert(hero.resources.stamina == stamina_before)
	assert(hero.cooldowns.is_empty())
	assert(hero.try_cast(&"E")) # 保留无目标冲刺。
	hero.cooldowns.clear()
	enemy.revive()
	assert(hero.try_cast(&"E", enemy))
	scenery.free()
	plain_node.free()
	hero.free()
	enemy.free()

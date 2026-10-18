class_name ARPGHeroes
extends RefCounted
## 工厂每次构造新配置，可安全生成多个英雄。
static func create(mage: bool = false) -> ARPGCharacter:
	var hero := ARPGCharacter.new()
	hero.name = "Mage" if mage else "Warrior"
	hero.tint = Color.MEDIUM_PURPLE if mage else Color.CORAL
	var pool := ARPGResources.new()
	pool.name = "Resources"
	pool.max_hp = 120.0 if mage else 220.0
	pool.max_stamina = 80.0 if mage else 140.0
	pool.max_mana = 200.0 if mage else 60.0
	pool.mana_regen = 8.0 if mage else 3.0
	hero.add_child(pool)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	hero.add_child(shape)
	hero.passive = ARPGPassiveSkill.new()
	hero.passive.title = "奥术源泉" if mage else "坚韧"
	hero.passive.effect = ARPGStatusEffect.new()
	if mage:
		hero.passive.effect.mana_regen_bonus = 4.0
	else:
		hero.passive.effect.stamina_regen_bonus = 0.3
	var attack := ARPGDamageSkill.new()
	attack.title = "奥术弹" if mage else "重斩"
	attack.damage = 40.0 if mage else 30.0
	attack.cast_range = 400.0 if mage else 100.0
	attack.cooldown = 2.0
	attack.mana_cost = 20.0 if mage else 0.0
	attack.stamina_cost = 5.0 if mage else 25.0
	hero.q = attack
	var guard := ARPGBuffSkill.new()
	guard.title = "奥术护体" if mage else "铁壁"
	guard.cooldown = 10.0
	guard.mana_cost = 25.0 if mage else 0.0
	guard.stamina_cost = 0.0 if mage else 20.0
	guard.effect = ARPGStatusEffect.new()
	guard.effect.id = &"guard"
	guard.effect.duration = 4.0
	guard.effect.damage_reduction = 0.4
	hero.w = guard
	var dash := ARPGUtilitySkill.new()
	dash.title = "疾行" if mage else "翻滚"
	dash.cooldown = 3.0
	dash.stamina_cost = 20.0
	hero.e = dash
	if mage:
		var nova := ARPGDamageSkill.new()
		nova.title = "冰封裁决"
		nova.damage = 100.0
		nova.cast_range = 450.0
		nova.cooldown = 15.0
		nova.mana_cost = 70.0
		nova.on_hit = ARPGStatusEffect.new()
		nova.on_hit.id = &"frozen"
		nova.on_hit.duration = 2.0
		nova.on_hit.stun = true
		hero.r = nova
	else:
		var heal := ARPGHealingSkill.new()
		heal.title = "战斗复苏"
		heal.healing = 60.0
		heal.cooldown = 15.0
		heal.mana_cost = 25.0
		hero.r = heal
	return hero

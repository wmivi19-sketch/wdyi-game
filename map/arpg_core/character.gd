class_name ARPGCharacter
extends CharacterBody2D
signal died
signal cast_result(slot: StringName, reason: String)
@export var move_speed: float = 160.0
@export var tint: Color = Color.CORNFLOWER_BLUE
@export var passive: ARPGPassiveSkill
@export var q: ARPGSkill
@export var w: ARPGSkill
@export var e: ARPGSkill
@export var r: ARPGSkill
var resources: ARPGResources
var dead: bool = false
var facing: Vector2 = Vector2.RIGHT
var move_input: Vector2 = Vector2.ZERO
var cooldowns: Dictionary = {}
var effects: Dictionary = {}
var dash_left: float = 0.0
var dash_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	resources = get_node_or_null("Resources") as ARPGResources
	if resources == null:
		resources = ARPGResources.new()
		resources.name = "Resources"
		add_child(resources)
	resources.depleted.connect(_die)
	resources.reset()
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 18.0, tint)
	draw_line(Vector2.ZERO, facing * 26.0, Color.WHITE, 3.0)

func all_effects() -> Array:
	var result: Array = []
	if not dead and passive != null and passive.effect != null:
		result.append(passive.effect)
	for entry in effects.values():
		result.append(entry.effect)
	return result

func modifier(property: StringName) -> float:
	var total: float = 0.0
	for effect in all_effects():
		total += float(effect.get(property))
	return total

func is_stunned() -> bool:
	for effect in all_effects():
		if effect.stun:
			return true
	return false

func add_effect(effect: ARPGStatusEffect) -> void:
	if not dead and effect.duration > 0.0:
		effects[effect.id] = {"effect": effect.duplicate(true), "remaining": effect.duration}

func remove_effect(id: StringName) -> void:
	effects.erase(id)

func damage_multiplier() -> float:
	return maxf(0.0, 1.0 + modifier(&"damage_bonus"))

func take_damage(amount: float) -> void:
	resources.damage(maxf(0.0, amount) * (1.0 - clampf(modifier(&"damage_reduction"), -1.0, 0.9)))

func start_dash(direction: Vector2, speed: float, duration: float) -> void:
	dash_velocity = direction.normalized() * speed
	dash_left = duration

func try_cast(slot: StringName, target = null) -> bool:
	var skill: ARPGSkill = null
	match slot:
		&"Q": skill = q
		&"W": skill = w
		&"E": skill = e
		&"R": skill = r
	var reason := ""
	if dead: reason = "角色已死亡"
	elif is_stunned(): reason = "眩晕中"
	elif skill == null: reason = "技能槽为空"
	elif float(cooldowns.get(slot, 0.0)) > 0.0: reason = "冷却中"
	elif not skill.can_execute(self, target): reason = "目标无效或超出距离"
	elif not resources.can_pay(skill.mana_cost, skill.stamina_cost): reason = "资源不足"
	if not reason.is_empty():
		cast_result.emit(slot, reason)
		return false
	resources.spend(skill.mana_cost, skill.stamina_cost)
	cooldowns[slot] = maxf(0.0, skill.cooldown)
	skill.execute(self, target)
	cast_result.emit(slot, "施放成功：" + skill.title)
	return true

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float, movement_body: Node2D = null) -> void:
	# 外部实体存在时由它执行物理移动，代理只同步最终位置。
	if not is_instance_valid(movement_body):
		movement_body = self
	for slot in cooldowns.keys():
		cooldowns[slot] = maxf(0.0, float(cooldowns[slot]) - delta)
	if dead:
		if movement_body is CharacterBody2D:
			movement_body.velocity = Vector2.ZERO
		return
	var stamina_multiplier := maxf(0.0, 1.0 + modifier(&"stamina_regen_bonus"))
	var mana_bonus := modifier(&"mana_regen_bonus")
	var previous_position := movement_body.global_position
	var stunned := is_stunned()
	for id in effects.keys():
		effects[id].remaining -= delta
		if effects[id].remaining <= 0.0:
			effects.erase(id)
	velocity = Vector2.ZERO
	if stunned:
		dash_left = 0.0
	elif dash_left > 0.0:
		velocity = dash_velocity * minf(1.0, dash_left / delta)
		dash_left = maxf(0.0, dash_left - delta)
	else:
		velocity = move_input.limit_length() * move_speed * maxf(0.0, 1.0 + modifier(&"speed_bonus"))
	if velocity.length_squared() > 0.0:
		facing = velocity.normalized()
	var attempted_movement := velocity.length_squared() > 0.0
	if movement_body is CharacterBody2D:
		movement_body.velocity = velocity
		movement_body.move_and_slide()
		velocity = movement_body.velocity
	elif movement_body is PhysicsBody2D:
		movement_body.move_and_collide(velocity * delta)
	else:
		movement_body.global_position += velocity * delta
	global_position = movement_body.global_position
	# 按碰撞后的实际位移结算：顶墙、眩晕、停止输入均可恢复体力。
	var moving := attempted_movement and movement_body.global_position.distance_squared_to(previous_position) > 0.000001
	resources.tick(delta, stamina_multiplier, mana_bonus, moving)
	queue_redraw()

func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	dash_left = 0.0
	effects.clear()
	died.emit()

func revive() -> void:
	dead = false
	effects.clear()
	cooldowns.clear()
	dash_left = 0.0
	move_input = Vector2.ZERO
	resources.reset()

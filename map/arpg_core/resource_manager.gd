class_name ARPGResources
extends Node
## 所有资源写入均通过此组件；HP 不参与自动恢复。
signal changed(kind: StringName, value: float, maximum: float)
signal depleted
@export var max_hp: float = 100.0
@export var max_stamina: float = 100.0
@export var max_mana: float = 100.0
@export var stamina_regen: float = 8.0
@export var mana_regen: float = 5.0
@export var stamina_delay: float = 0.0 # 保留旧配置字段，停步恢复不再等待。
@export var movement_stamina_drain: float = 12.0
var hp: float = 100.0
var stamina: float = 100.0
var mana: float = 100.0
var delay_left: float = 0.0
var enabled: bool = true

func reset() -> void:
	max_hp = maxf(1.0, max_hp)
	max_stamina = maxf(0.0, max_stamina)
	max_mana = maxf(0.0, max_mana)
	hp = max_hp
	stamina = max_stamina
	mana = max_mana
	delay_left = 0.0
	enabled = true
	publish()

func publish() -> void:
	changed.emit(&"hp", hp, max_hp)
	changed.emit(&"stamina", stamina, max_stamina)
	changed.emit(&"mana", mana, max_mana)

func can_pay(mana_cost: float, stamina_cost: float) -> bool:
	return enabled and mana_cost >= 0.0 and stamina_cost >= 0.0 and mana >= mana_cost and stamina >= stamina_cost

func spend(mana_cost: float, stamina_cost: float) -> bool:
	# 先同时检查，再扣除，避免只扣掉一种资源。
	if not can_pay(mana_cost, stamina_cost):
		return false
	mana -= mana_cost
	stamina -= stamina_cost
	if stamina_cost > 0.0:
		delay_left = maxf(0.0, stamina_delay)
	publish()
	return true

func damage(amount: float) -> void:
	if not enabled or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	if hp <= 0.0:
		# 先禁止资源操作并同步角色死亡，再通知 HP 监听者。
		# 信号同步调用回调，顺序错误会使零血回调仍可施法/治疗。
		enabled = false
		depleted.emit()
	changed.emit(&"hp", hp, max_hp)

func heal(amount: float) -> void:
	if enabled:
		hp = minf(max_hp, hp + maxf(0.0, amount))
		changed.emit(&"hp", hp, max_hp)

func tick(delta: float, stamina_multiplier: float = 1.0, mana_bonus: float = 0.0, moving: bool = false) -> void:
	if not enabled:
		return
	if moving:
		# 移动帧只消耗、不恢复。
		stamina = maxf(0.0, stamina - maxf(0.0, movement_stamina_drain) * delta)
		delay_left = 0.0
	else:
		# 也清除旧存档中的延迟，停步第一帧就缓慢恢复。
		delay_left = 0.0
		stamina = minf(max_stamina, stamina + maxf(0.0, stamina_regen * stamina_multiplier) * delta)
	mana = minf(max_mana, mana + maxf(0.0, mana_regen + mana_bonus) * delta)
	publish()

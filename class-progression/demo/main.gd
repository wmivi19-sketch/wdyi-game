extends Node3D

var player: ProgressionPlayer
var inventory: ProgressionInventory
var label: Label
var progress: ProgressBar
var remaining: float = 0.0
var duration: float = 1.0
var running: bool = false

func _ready() -> void:
	configure()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var box := VBoxContainer.new()
	box.position = Vector2(30, 30)
	canvas.add_child(box)
	label = Label.new()
	box.add_child(label)
	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(650, 30)
	box.add_child(progress)
	_button(box, "1. 合成职业印记", _craft)
	_button(box, "2. 在祭坛转职（8 秒）", func(): _start("learn_mage"))
	_button(box, "3. 在祭坛成神（12 秒，需要三个职业）", func(): _start("sun_ascension"))
	_button(box, "模拟另一玩家已确认命中（打断，扣 10 HP）", func(): ClassManager.apply_confirmed_damage(1, 10.0))
	_button(box, "模拟死亡（移除神力）", func(): ClassManager.apply_confirmed_damage(1, 10000.0))
	ClassManager.notice.connect(func(id: int, message: String):
		if id == 1: label.text = message)
	ClassManager.ritual_started.connect(_started)
	ClassManager.ritual_ended.connect(_ended)
	ClassManager.form_changed.connect(func(_id: int, _form: Dictionary): _show_form())
	_show_form()

func configure() -> void:
	player = ProgressionPlayer.new()
	add_child(player)
	inventory = ProgressionInventory.new()
	inventory.add_item("ore", 4)
	inventory.add_item("sun_mark", 1)
	for id in ["warrior", "priest", "mage", "rogue"]:
		var info := ClassInfo.new()
		info.class_id = id
		info.stat_bonuses = {"max_hp": 20.0, "attack": 5.0}
		info.skill_ids.assign(["shared_skill", id + "_skill"])
		ClassManager.classes[id] = info
	var deity := DeityInfo.new()
	deity.deity_id = "sun"
	deity.divine_skill_ids.assign(["sun_burst"])
	ClassManager.deities["sun"] = deity
	var learn := RitualRequirement.new()
	learn.ritual_id = "learn_mage"
	learn.required_mark_id = "mage_mark"
	learn.granted_class_id = "mage"
	learn.duration_seconds = 8.0
	learn.allowed_phases.assign(["night"])
	learn.allowed_area_tags.assign(["holy_altar"])
	ClassManager.rituals[learn.ritual_id] = learn
	var ascend := RitualRequirement.new()
	ascend.ritual_id = "sun_ascension"
	ascend.kind = RitualRequirement.Kind.DEITY_ASCENSION
	ascend.required_mark_id = "sun_mark"
	ascend.granted_deity_id = "sun"
	ascend.duration_seconds = 12.0
	ascend.allowed_phases.assign(["night"])
	ascend.allowed_area_tags.assign(["holy_altar"])
	ClassManager.rituals[ascend.ritual_id] = ascend
	var altar := RitualAltar.new()
	altar.altar_id = "holy"
	altar.ritual_ids.assign(["learn_mage", "sun_ascension"])
	add_child(altar)
	ClassManager.altars[altar.altar_id] = altar
	ClassManager.register_player(1, player, inventory, {}, "warrior")
	# Demo starts with two classes; the third must be acquired through a ritual.
	ClassManager.add_class_slot("priest", 1)

func _button(box: VBoxContainer, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	box.add_child(button)

func _craft() -> void:
	var recipe := ClassRecipe.new()
	recipe.materials = {"ore": 2}
	recipe.output_mark_id = "mage_mark"
	label.text = "合成成功" if inventory.craft(recipe) else "材料不足"

func _start(ritual_id: String) -> void:
	label.text = "正在请求仪式……"
	ClassManager.start_ritual(ritual_id, "holy")

func _started(id: int, ritual_id: String, seconds: float, ascension: bool) -> void:
	if ascension:
		print("全服公告：玩家 %s 正在成神" % id)
	if id != 1:
		return
	duration = seconds
	remaining = seconds
	running = true
	label.text = "仪式进行中：" + ritual_id

func _ended(id: int, _ritual_id: String, success: bool, reason: String) -> void:
	if id != 1:
		return
	running = false
	progress.value = 100.0 if success else 0.0
	_show_form()
	label.text += "\n" + ("仪式完成" if success else reason)

func _process(delta: float) -> void:
	if running:
		remaining = maxf(0.0, remaining - delta)
		progress.value = (1.0 - remaining / duration) * 100.0

func _show_form() -> void:
	var form: Dictionary = ClassManager.replicated_forms.get(1, {})
	label.text = "职业：%s\n神明：%s，HP：%s / %s" % [
		form.get("class_ids", []), form.get("is_deity", false),
		player.hp, player.stats.get("max_hp", 100.0)]

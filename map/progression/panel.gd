extends VBoxContainer

var world: Node
var summary: Label
var feedback: Label
var progress: ProgressBar
var remaining: float = 0.0
var duration: float = 1.0
var running: bool = false

func setup(progression_world: Node) -> void:
	world = progression_world
	position = Vector2(720, 100)
	custom_minimum_size = Vector2(335, 0)
	var title := Label.new()
	title.text = "职业进阶 · E 交互 / Q 神力"
	add_child(title)
	summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size.x = 335
	add_child(summary)
	progress = ProgressBar.new()
	add_child(progress)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size = Vector2(335, 60)
	add_child(feedback)
	_button("合成法师印记：矿石3 + 药草2", func(): world.craft("mage_recipe"))
	_button("合成游侠印记：木材3 + 药草2", func(): world.craft("ranger_recipe"))
	_button("附近交互 / 发起祭坛仪式（E）", func(): world.interact())
	_button("释放神力：太阳爆发（Q）", func(): world.cast_sun_burst())
	_button("推进一个时段（空格）", func(): GameManager.next_time_period())
	_button("推进一天", func():
		for i in range(3): GameManager.next_time_period())
	_button("调试：模拟敌方命中，打断仪式", func():
		ClassManager.apply_confirmed_damage(1, 10.0)
		refresh())
	_button("调试：致死伤害", func(): ClassManager.apply_confirmed_damage(1, 10000.0))
	world.message.connect(func(text: String): feedback.text = text)
	world.inventory_changed.connect(refresh)
	world.player.health_changed.connect(func(_hp: float, _maximum: float): refresh())
	ClassManager.form_changed.connect(func(id: int, _form: Dictionary):
		if id == 1: refresh())
	ClassManager.notice.connect(func(id: int, text: String):
		if id == 1: feedback.text = text)
	ClassManager.ritual_started.connect(_started)
	ClassManager.ritual_ended.connect(_ended)
	refresh()
	feedback.text = "采集绿色资源：靠近按E。\n大陆1/2夜晚转职；大陆3遗物给神印；大陆6第12～14天夜晚成神。"

func _button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	add_child(button)

func refresh() -> void:
	var form: Dictionary = ClassManager.replicated_forms.get(1, {})
	var names: Array[String] = []
	for id in form.get("class_ids", []):
		names.append(ClassManager.classes[id].display_name)
	var status := "神明" if form.get("is_deity", false) else ("半神" if form.get("is_demigod", false) else "凡人")
	summary.text = "%s · %s\nHP %.0f / %.0f\n矿石%d 药草%d 木材%d\n法师印%d 游侠印%d 神印%d" % [
		" + ".join(names), status, world.player.hp, world.player.stats["max_hp"],
		world.inventory.count_item("ore"), world.inventory.count_item("herb"),
		world.inventory.count_item("wood"), world.inventory.count_item("mage_mark"),
		world.inventory.count_item("ranger_mark"), world.inventory.count_item("sun_mark")]

func _started(id: int, ritual_id: String, seconds: float, ascension: bool) -> void:
	if ascension:
		feedback.text = "全服公告：玩家 %d 正在举行成神仪式" % id
	if id != 1:
		return
	running = true
	remaining = seconds
	duration = seconds
	feedback.text = "仪式：%s\n请留在祭坛附近，受伤会被打断" % ritual_id

func _ended(id: int, _ritual_id: String, success: bool, reason: String) -> void:
	if id != 1:
		return
	running = false
	progress.value = 100.0 if success else 0.0
	feedback.text = "仪式成功" if success else reason
	refresh()

func _process(delta: float) -> void:
	if running:
		remaining = maxf(0.0, remaining - delta)
		progress.value = 100.0 * (1.0 - remaining / duration)

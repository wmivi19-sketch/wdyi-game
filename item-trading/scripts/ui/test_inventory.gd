extends VBoxContainer
var inventory: Inventory
var content := Label.new()
## 创建交互测试与共享背包 GM 面板；无参数。
func _ready() -> void:
 inventory = Inventory.new()
 var add := Button.new()
 add.text = "添加测试物品"
 add.pressed.connect(add_test)
 add_child(add)
 add_child(content)
 var panel = load("res://scenes/ui/gm_panel.tscn").instantiate()
 panel.setup(inventory)
 add_child(panel)
 inventory.inventory_changed.connect(refresh)
 inventory.weight_changed.connect(weight_refresh)
 refresh()
## 按配置添加测试物品；无参数。
func add_test() -> void:
 inventory.add_item(Config.data.test_item, int(Config.data.test_count))
## 重量变化时刷新；current 和 maximum 为重量信号参数。
func weight_refresh(_current: float, _maximum: float) -> void:
 refresh()
## 更新背包文字；无参数。
func refresh() -> void:
 content.text = "第 %s 天  重量 %.2f / %.2f\n%s" % [GameState.current_day, inventory.current_weight, inventory.max_weight, JSON.stringify(inventory.snapshot(), "  ")]

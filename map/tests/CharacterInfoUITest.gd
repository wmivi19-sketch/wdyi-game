extends SceneTree
## 保留旧 CI 入口，运行覆盖背包与职业的统一 UI 回归；无参数。
func _initialize() -> void:
 call_deferred("run")
## 自动加载就绪后载入新的 UI 测试场景；无参数。
func run() -> void:
 root.add_child(load("res://tests/PlayerPanelTest.tscn").instantiate())

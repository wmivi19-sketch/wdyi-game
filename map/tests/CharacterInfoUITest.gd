extends SceneTree

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)

func key(code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func _run() -> void:
	var demo = load("res://scenes/MapDemo.tscn").instantiate()
	root.add_child(demo)
	for i in range(5):
		await process_frame
	var ui: CanvasLayer = demo.character_info_ui
	var panel: Control = ui.get_node("CharacterInfoPanel")
	var contents: VBoxContainer = panel.get_node("ProgressionPanel")
	check(not panel.visible, "character info is hidden at startup")
	check(demo.player.camera.offset == Vector2.ZERO, "hidden panel does not reserve camera space")
	key(KEY_F, true)
	key(KEY_F, false)
	await process_frame
	check(not panel.visible, "other gameplay keys do not open panel")
	key(KEY_TAB, true)
	await process_frame
	check(panel.visible, "actual Tab input opens panel")
	check(demo.player.camera.offset == Vector2(180, 0), "open panel keeps player clear of sidebar")
	check(contents.summary.text.contains("战士") and contents.summary.text.contains("斩击"), "panel shows real class and skills")
	key(KEY_TAB, true, true)
	await process_frame
	check(panel.visible, "key repeat does not toggle")
	key(KEY_TAB, false)
	await process_frame
	check(panel.visible, "key release does not toggle")
	if OS.get_cmdline_user_args().has("--capture-ui"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.validation/character-info-open.png")
	var button: Button
	for child in contents.get_children():
		if child is Button:
			check(child.focus_mode == Control.FOCUS_NONE, "panel button cannot capture Tab focus")
			if button == null: button = child
	var click := InputEventMouseButton.new()
	click.position = button.get_global_rect().get_center()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	var release := click.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
	check(root.gui_get_focus_owner() == null, "mouse click does not acquire keyboard focus")
	key(KEY_TAB, true)
	key(KEY_TAB, false)
	await process_frame
	check(not panel.visible, "Tab closes after clicking a panel button")
	var manager: Node = root.get_node("ClassManager")
	manager.apply_confirmed_damage(1, 10.0)
	manager.add_class_slot("mage", 1)
	check(not panel.visible, "game updates do not force panel open")
	check(contents.summary.text.contains("90 / 160") and contents.summary.text.contains("法师") and contents.summary.text.contains("火球"), "hidden panel keeps health class and skills current")
	key(KEY_TAB, true)
	key(KEY_TAB, false)
	await process_frame
	check(panel.visible and contents.summary.text.contains("火球"), "reopening shows latest character state")
	demo.queue_free()
	await process_frame
	print("Character info UI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

extends TextEdit


func _ready() -> void:
	Tools.set_title("System Error")
	set_scroll_bars()
	text = Globals.bsod
	Globals.bsod = ""
	grab_focus.call_deferred()


func set_scroll_bars() -> void:
	var vscroll_bar:VScrollBar = get_v_scroll_bar()
	vscroll_bar.add_theme_stylebox_override("grabber",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_highlight",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_pressed",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll_focus",StyleBoxEmpty.new())
	vscroll_bar.size.x = 0
	vscroll_bar.custom_minimum_size.x = 0


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_released("esc_shortcut"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			System.load_preferences()
		match Globals.return_from_runtime_to:
			"editor":
				get_tree().change_scene_to_file.call_deferred("res://Scenes/General/code_editor.tscn")
			"terminal":
				get_tree().change_scene_to_file.call_deferred("res://Scenes/General/main_terminal.tscn")

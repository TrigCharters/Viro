extends CodeEdit

@onready var auto_save: Timer = $"../../../AutoSave"
@onready var line_edit: LineEdit = $"../LineEdit"
@onready var editor_mode: int = 0 #default editing mode
@onready var prompt_length: int = 0
@onready var last_find_text: String = ""
@onready var last_find_line: int = -1
@onready var find_for_replace: String = ""
@onready var debounce: int = Time.get_ticks_msec()

# Dialogs
@onready var color_picker: PackedScene = preload("res://Scenes/Dialogs/color_picker_dialog.tscn")
@onready var key_listener: PackedScene = preload("res://Scenes/Dialogs/listener_dialog.tscn")
@onready var string_editor: PackedScene = preload("res://Scenes/Dialogs/strings_dialog.tscn")
@onready var font_editor: PackedScene = preload("res://Scenes/Dialogs/font_editor_dialog.tscn")
@onready var ports_list: PackedScene = preload("res://Scenes/Dialogs/ports_dialog.tscn")
@onready var directives_list: PackedScene = preload("res://Scenes/Dialogs/directives_dialog.tscn")
@onready var constants_list: PackedScene = preload("res://Scenes/Dialogs/constants_dialog.tscn")

func _ready() -> void:
	Tools.set_title("Code Editor")
	setup()
	grab_focus.call_deferred()


# Setup the code editor with all the options
func setup() -> void:
	text = Globals.source_code	
	clear_undo_history()

	Signals.dialogconfirmedwithvalue.connect(dialog_confirmed_with_value)
	Signals.dialogcancelled.connect(dialog_cancelled)

	set_scroll_bars()
	set_line_spacing()
	set_caret_line(Globals.editor_caret_line)
	set_caret_column(Globals.editor_caret_column)
	get_v_scroll_bar().value = Globals.editor_scroll_value
	get_h_scroll_bar().value = 0

	gutters_draw_line_numbers = Globals.editor_use_line_numbers
	gutters_zero_pad_line_numbers = Globals.editor_pad_line_numbers

	if Globals.editor_enable_wrapping:
		wrap_mode = CodeEdit.LINE_WRAPPING_BOUNDARY
	else:
		wrap_mode = CodeEdit.LineWrappingMode.LINE_WRAPPING_NONE

	if Globals.flag_autosave: auto_save.start()


# Connected Signals 
func dialog_confirmed_with_value(data: String) -> void:
	insert_text_at_caret(data)
	grab_focus()


func dialog_cancelled() -> void:
	grab_focus()


# Save the source when leaving the scene
func _on_tree_exiting() -> void:
	Globals.source_code = text


func _input(event: InputEvent) -> void:
	if Input.is_action_just_released("esc_shortcut"):
		if editor_mode == 0 and Time.get_ticks_msec() - debounce > 250:
			get_tree().change_scene_to_file.call_deferred("res://Scenes/General/main_terminal.tscn")
		return
	
	if Input.is_action_just_released("v_shortcut"):
		if Globals.memory.size() > 0:
			get_tree().change_scene_to_file.call_deferred("res://Scenes/General/memory_viewer.tscn")
		else:
			line_edit.text = "No memory to view."
		return

	if Input.is_action_just_released("c_shortcut"):
		if text.is_empty():
			line_edit.text = "Nothing to compile."
		else:
			Globals.debug_mode = true
			Globals.compile_and_run = false
			Globals.return_from_compiler_to = "editor"
			get_tree().change_scene_to_file.call_deferred("res://Scenes/Compiler/compiler.tscn")
		return

	if Input.is_action_just_released("n_shortcut"):
		var constantsList: Node = constants_list.instantiate()
		add_child.call_deferred(constantsList)
		return
		
	if Input.is_action_just_released("o_shortcut"):
		var colorPicker: Node = color_picker.instantiate()
		add_child.call_deferred(colorPicker)
		return

	if Input.is_action_just_released("d_shortcut"):
		var directivesList: Node = directives_list.instantiate()
		add_child.call_deferred(directivesList)
		return

	if Input.is_action_just_released("k_shortcut"):
		var keylistener: Node = key_listener.instantiate()
		add_child.call_deferred(keylistener)
		return

	if Input.is_action_just_released("f_shortcut"):
		Globals.source_code = text # Need to backup code for editor to detect
		var fontEditor: Node = font_editor.instantiate()
		add_child.call_deferred(fontEditor)
		return

	if Input.is_action_just_released("s_shortcut"):
		var data: String = get_selected_text()
		var stringEditor: Node = string_editor.instantiate()
		add_child.call_deferred(stringEditor)
		stringEditor.selectedData = data
		return

	if Input.is_action_just_released("p_shortcut"):
		var portList: Node = ports_list.instantiate()
		add_child.call_deferred(portList)
		return

	if Input.is_action_just_released("m_shortcut"):
		if Globals.metrics.size() > 0 and Globals.flag_metrics:
			get_tree().change_scene_to_file.call_deferred("res://Scenes/General/metrics_viewer.tscn")
		else:
			if not Globals.flag_metrics:
				line_edit.text = "Metrics system not enabled. "
			else:
				line_edit.text = "No metrics to display. "
		return

	if Input.is_action_just_released("r_shortcut"):
		if text.is_empty():
			line_edit.text = "Nothing to run. "
		else:
			Globals.debug_mode = true # Must be for the debug runtime
			Globals.compile_and_run = true
			Globals.return_from_runtime_to = "editor"
			Globals.return_from_compiler_to = "editor"
			get_tree().change_scene_to_file.call_deferred("res://Scenes/Compiler/compiler.tscn")
		return	

	if Input.is_action_just_released("save_shortcut"):
		if text.is_empty():
			line_edit.text = "Nothing to save. "
		elif Globals.file_name.is_empty():
			line_edit.text = "No file name set. Save from the main terminal first. "
		else:
			Globals.source_code = text #Grab the unsave source
			var save_result: String = Tools.save_vr_program_file(Globals.file_name)
			if save_result.findn("error") > -1:
				line_edit.text = save_result
			else:
				Tools.set_title("Code Editor")
				line_edit.text = "File '" + Globals.file_name + "' saved. "
		return
			
	if Input.is_action_just_released("find_shortcut"):
		editor_mode = 1
		change_focus()
		return
		
	if Input.is_action_just_released("replace_shortcut"):
		editor_mode = 2
		change_focus()
		return

	if Input.is_action_just_released("find_next_shortcut"):
		if last_find_text.is_empty():
			line_edit.text = "No previous search term. "
		else:
			find_text(last_find_text, last_find_line)
		return
	
	if event is InputEventKey and event.is_released():	
		match OS.get_keycode_string(event.physical_keycode):
			"Home":
				set_caret_line(0)
				set_caret_column(0)
			"End":
				set_caret_line(get_line_count())
				set_caret_column(0)


func change_focus() -> void:
	deselect()
	release_focus()
	line_edit.editable = true
	line_edit.text = "Find:"
	line_edit.alignment = HORIZONTAL_ALIGNMENT_LEFT
	line_edit.set_focus_mode(Control.FOCUS_ALL)
	line_edit.grab_focus()
	prompt_length = 5
	line_edit.caret_column = prompt_length + 1


func restore_focus() -> void:
	editor_mode = 0
	release_focus()
	line_edit.editable = false
	line_edit.text = ""
	line_edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line_edit.set_focus_mode(Control.FOCUS_NONE)
	debounce = Time.get_ticks_msec()
	grab_focus()


func _on_focus_entered() -> void:
	# Stop key bouncing
	debounce = Time.get_ticks_msec()


func _on_text_changed() -> void:
	if not Globals.source_changed:
		Tools.set_source_changed(true)
	

func set_line_spacing() -> void:
	if Globals.editor_use_reduced_line_spacing:
		add_theme_constant_override("line_spacing", -2)


func _on_caret_changed() -> void:
	line_edit.text = str(get_caret_column()) + "," + str(get_caret_line()+1) + " "
	Globals.editor_caret_line = get_caret_line()
	Globals.editor_caret_column = get_caret_column()
	Globals.editor_scroll_value = int(get_v_scroll_bar().value)
	if get_caret_column() < 69:
		get_h_scroll_bar().value = 0


func _on_line_edit_text_submitted(new_text: String) -> void:
	new_text = new_text.right(new_text.length() - prompt_length)

	match editor_mode:
		1: # Normal find
			restore_focus()
			find_text(new_text, -1)

		2: # Find for Replace
			if text.findn(new_text, 0) > -1:
				editor_mode = 3
				find_for_replace = new_text
				line_edit.text = "Replace With:"
				prompt_length = line_edit.text.length()
				line_edit.caret_column = line_edit.text.length()
			else:
				editor_mode = 0
				restore_focus()
				line_edit.text = "No occurances of search string '" + new_text + "' "
				set_caret_line(Globals.editor_caret_line)
				set_caret_column(Globals.editor_caret_column)

		3: # Do actual replace
			restore_focus()
			editor_mode = 0
			if new_text.is_empty():
				restore_focus()	
			else:
				text = text.replacen(find_for_replace, new_text)
				find_for_replace = ""
				if not Globals.source_changed:
					Tools.set_source_changed(true)

			set_caret_line(Globals.editor_caret_line)
			set_caret_column(Globals.editor_caret_column)


func find_text(search_text: String, find_line: int) -> void:
	var find_lines: Array = []
	var text_found: bool = false
	find_lines = text.split("\n", true)
	for i: int in find_lines.size():
		if i > find_line:
			var find_pos: int = find_lines[i].findn(search_text,0)
			if find_pos > -1:
				last_find_line = i
				set_caret_line(i)
				set_caret_column(find_pos)
				text_found = true
				break

	last_find_text = search_text

	if not text_found:
		if last_find_line == -1:
			line_edit.text = "No occurances of search string '" + search_text + "' "	
		else:
			line_edit.text = "No further occurances of search string '" + search_text + "' "	
		last_find_line = -1


func _on_line_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		match OS.get_keycode_string(event.physical_keycode):
			"Backspace","Left","Space":
				if line_edit.caret_column <= prompt_length:
					accept_event()
			"Escape":
				restore_focus()


func _on_line_edit_focus_exited() -> void:
	restore_focus()


func _on_auto_save_timeout() -> void:
	if Globals.file_name and Globals.source_changed and not text.is_empty():
		Globals.source_code = text
		var save_result: String = Tools.save_vr_program_file(Globals.file_name)
		if save_result.findn("error") > -1:
			line_edit.text = "AutoSave: " + save_result
		else:
			Tools.set_title("Code Editor")
			line_edit.text = "AutoSave: File '" + Globals.file_name + "' saved. "


func set_scroll_bars() -> void:
	var vscroll_bar:VScrollBar = get_v_scroll_bar()
	vscroll_bar.add_theme_stylebox_override("grabber",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_highlight",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_pressed",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll_focus",StyleBoxEmpty.new())
	vscroll_bar.size.x = 0
	vscroll_bar.custom_minimum_size.x = 0

	var hscroll_bar:HScrollBar = get_h_scroll_bar()
	hscroll_bar.add_theme_stylebox_override("grabber",StyleBoxEmpty.new())
	hscroll_bar.add_theme_stylebox_override("grabber_highlight",StyleBoxEmpty.new())
	hscroll_bar.add_theme_stylebox_override("grabber_pressed",StyleBoxEmpty.new())
	hscroll_bar.add_theme_stylebox_override("scroll",StyleBoxEmpty.new())
	hscroll_bar.add_theme_stylebox_override("scroll_focus",StyleBoxEmpty.new())
	hscroll_bar.size.x = 0
	hscroll_bar.custom_minimum_size.x = 0


func _on_line_edit_editing_toggled(toggled_on: bool) -> void:
	if editor_mode == 3 and not toggled_on:
		line_edit.edit()

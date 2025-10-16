extends Panel


func _ready() -> void:
	get_tree().paused = true
	$cancelButton.grab_focus.call_deferred()
	load_options()


func load_options() -> void:
	$auto_save.button_pressed = Globals.flag_autosave
	$line_numbers.button_pressed = Globals.editor_use_line_numbers
	$line_number_padding.button_pressed = Globals.editor_pad_line_numbers
	$line_wrapping.button_pressed = Globals.editor_enable_wrapping
	$line_spacing.button_pressed = Globals.editor_use_reduced_line_spacing
	$auto_run.button_pressed = Globals.flag_autorun
	$run_fullscreen.button_pressed = Globals.flag_fullscreen
	$metrics.button_pressed = Globals.flag_metrics
	$auto_edit.button_pressed = Globals.flag_autoedit
	$auto_load.button_pressed = Globals.flag_autoload
	$full_screen.button_pressed = Globals.flag_editorFullScreen
	$save_prompt.button_pressed = Globals.flag_savePrompt
	
	match Globals.debug_pane_update_frequency:
		15:
			$frequency_fast.button_pressed = true
		30:
			$frequency_medium.button_pressed = true
		60:
			$frequency_slow.button_pressed = true
		_:
			$frequency_medium.button_pressed = true
	
	if not Globals.source_locked:
		$run_fullscreen.disabled = false
		$auto_run.disabled = false
		$project_locked_status.text = "(Unlocked)"
	


func save_options() -> void:
	Globals.flag_autosave = $auto_save.button_pressed 
	Globals.editor_use_line_numbers = $line_numbers.button_pressed
	Globals.editor_pad_line_numbers = $line_number_padding.button_pressed
	Globals.editor_enable_wrapping = $line_wrapping.button_pressed
	Globals.editor_use_reduced_line_spacing = $line_spacing.button_pressed
	Globals.flag_autorun = $auto_run.button_pressed
	Globals.flag_fullscreen = $run_fullscreen.button_pressed
	Globals.flag_metrics = $metrics.button_pressed 
	Globals.flag_autoedit = $auto_edit.button_pressed
	Globals.flag_autoload = $auto_load.button_pressed
	Globals.flag_editorFullScreen = $full_screen.button_pressed
	Globals.flag_savePrompt = $save_prompt.button_pressed
	if $frequency_slow.button_pressed: Globals.debug_pane_update_frequency = 60
	if $frequency_medium.button_pressed: Globals.debug_pane_update_frequency = 30
	if $frequency_fast.button_pressed: Globals.debug_pane_update_frequency = 15


func _on_ok_button_pressed() -> void:
	save_options()
	System.save_preferences()
	System.load_preferences()
	dialog_cancelled()


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_released("esc_shortcut"):
		accept_event()
		dialog_cancelled()


func dialog_cancelled() -> void:
	get_tree().paused = false
	Signals.dialogcancelled.emit()
	queue_free()


func _on_gui_input(_event: InputEvent) -> void:
	accept_event()

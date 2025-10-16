extends Panel

@onready var ok_button: Button = $okButton
@onready var string_data: TextEdit = $dialogtitleBackground/stringData
@onready var zero_check_box: CheckBox = $dialogtitleBackground/zero_check_box
var selectedData: String = ""

func _ready() -> void:
	get_tree().paused = true
	set_scroll_bars()
	if not selectedData.is_empty() and selectedData.to_lower().begins_with(".data"):
		if selectedData.findn(".data") > -1:
			selectedData = selectedData.replacen(".data","")
			selectedData = selectedData.replacen(",0","")
			selectedData = selectedData.replacen(" ","")
			var values: Array = selectedData.split(",",false)
			var trueString: bool = true
			for i: int in values.size():
				if values[i].is_valid_int():
					if values[i].to_int() < 0 or values[i].to_int() > 127:
						trueString = false
						break
				else:
					trueString = false
					break
			if trueString:
				for i: int in values.size():
					if values[i].is_valid_int():
						string_data.text += char(values[i].to_int())

	string_data.grab_focus.call_deferred()
	string_data.set_caret_column.call_deferred(string_data.text.length())


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():	
		if OS.get_keycode_string(event.keycode) == "Tab":
			if string_data.has_focus() and not string_data.text.is_empty():
				ok_button.grab_focus()
			else:
				string_data.grab_focus()
				string_data.set_caret_column(string_data.text.length())
			accept_event()

	if Input.is_action_just_released("esc_shortcut"):
		accept_event()
		dialog_cancelled()


func _on_string_data_text_changed() -> void:
	ok_button.disabled = string_data.text.is_empty()


func _on_ok_button_pressed() -> void:
	var dataStatement: String = ""
	var vals: Array = string_data.text.to_ascii_buffer()

	dataStatement = ".data"

	for i: int in vals.size():
		if i == 0:
			dataStatement += " " + str(int(vals[i]))
		else:
			dataStatement += "," + str(int(vals[i]))

	if zero_check_box.button_pressed:
		dataStatement += ",0"
	
	#Clear the field as we're inserting this string
	string_data.text = ""
	
	dialog_confirmed(dataStatement)


func dialog_confirmed(data: String) -> void:
	get_tree().paused = false
	Signals.dialogconfirmedwithvalue.emit(data)
	queue_free()


func dialog_cancelled() -> void:
	get_tree().paused = false
	Signals.dialogcancelled.emit()
	queue_free()


func set_scroll_bars() -> void:
	var vscroll_bar:VScrollBar = string_data.get_v_scroll_bar()
	vscroll_bar.add_theme_stylebox_override("grabber",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_highlight",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_pressed",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll_focus",StyleBoxEmpty.new())
	vscroll_bar.size.x = 0
	vscroll_bar.custom_minimum_size.x = 0


func _on_gui_input(_event: InputEvent) -> void:
	accept_event()

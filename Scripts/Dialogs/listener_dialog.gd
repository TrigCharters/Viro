extends Panel

@onready var timebar: ColorRect = $dialogtitleBackground/timebar
@onready var key_insert_timer: Timer = $KeyInsertTimer
@onready var dialog_text: Label = $dialogtitleBackground/dialogText
@onready var keyInsertText: String = ""
@onready var constantNames: Array[String] = []

func _ready() -> void:
	get_tree().paused = true
	var constants: Array[Dictionary] = []
	Tools.load_dictionary_db("constants.edf", constants, true)
	for i: int in constants.size():
		constantNames.append(constants[i].name.to_lower())


func find_contant_name(constant: String) -> int:
	for i: int in constantNames.size():
		if constantNames[i] == constant.to_lower():
			return i
	return -1


func _input(event: InputEvent) -> void:
	
	if event is InputEventKey and event.is_pressed():
	
		if not key_insert_timer.is_stopped():

			if Input.is_action_just_pressed("esc_shortcut"):
				timebar.visible = false
				timebar.size.x = 200
				key_insert_timer.stop()
				dialog_text.text = "Listening..."
				
			if OS.get_keycode_string(event.keycode) in ["Enter", "Kp Enter"]:
				accept_event()
				dialog_confirmed()

		else:
			var keyName: String = OS.get_keycode_string(event.keycode)
			var keyUnicode: int = event.unicode
			
			if keyName in ["Shift","Command", "Option", "Ctrl"]:
				return

			if keyUnicode > 0 and keyUnicode <= 127:
				keyInsertText = "#" + str(keyUnicode)

				if keyUnicode == 32:
					dialog_text.text = "Unicode : ( SPACE ) " + keyInsertText
				else:
					dialog_text.text = "Unicode : ( " + char(keyUnicode) + " ) " + keyInsertText

				if keyUnicode == 32:
					keyInsertText += " ;space key"
				else:
					keyInsertText += " ;" + char(keyUnicode) + " key"
			else:
				keyInsertText = OS.get_keycode_string(event.keycode)
				keyInsertText = "const_key" + keyInsertText
				keyInsertText = keyInsertText.to_camel_case()
				keyInsertText = keyInsertText.replacen("const", "const_")
				
				if find_contant_name(keyInsertText) > -1:
					dialog_text.text = keyInsertText
				else:
					return

			timebar.visible = true
			key_insert_timer.start()


func _on_key_insert_timer_timeout() -> void:
	timebar.size.x -= 40
	if timebar.size.x == 0:
		key_insert_timer.stop()
		dialog_confirmed()


func dialog_confirmed() -> void:
	get_tree().paused = false
	if keyInsertText == "const_KeyEscape":
		keyInsertText = keyInsertText + " ;Escape not detected in debug engine."
	Signals.dialogconfirmedwithvalue.emit(keyInsertText)
	queue_free()


func dialog_cancelled() -> void:
	get_tree().paused = false
	Signals.dialogcancelled.emit()
	queue_free()


func _on_gui_input(_event: InputEvent) -> void:
	accept_event()

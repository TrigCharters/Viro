extends Panel

@onready var password_field: LineEdit = $password_field
@onready var unlockMode: bool = true
@onready var clear_button: Button = $clearButton

func _ready() -> void:
	get_tree().paused = true

	if Globals.password_hash.is_empty():
		unlockMode = false

	password_field.grab_focus.call_deferred()


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_released("esc_shortcut"):
		accept_event()
		dialog_cancelled()


func dialog_cancelled() -> void:
	get_tree().paused = false
	Signals.dialogcancelled.emit()
	queue_free()


func _on_password_field_text_submitted(new_text: String) -> void:
	var value: String = ""
	if unlockMode:
		if str(new_text.hash()) == Globals.password_hash:
			Globals.source_locked = false
			value = "Unlocked."
		else:
			value = "Incorrect Password."
	else:
		if new_text.length() < 5:
			value = "Invalid Password. Must be a minimum of 5 characters."
		else:
			Globals.password_hash = str(new_text.hash())
			Globals.source_locked = true
			value = "Locked."
	
	get_tree().paused = false		
	Signals.dialogconfirmedwithvalue.emit(value)
	queue_free()


func _on_clear_button_pressed() -> void:
	Globals.password_hash = ""
	Globals.source_locked = false
	get_tree().paused = false
	Signals.dialogconfirmedwithvalue.emit("Password Cleared.")
	queue_free()


func _on_password_field_text_changed(new_text: String) -> void:
	if unlockMode:
		if str(new_text.hash()) == Globals.password_hash and not Globals.password_hash.is_empty():
			clear_button.visible = true
		else:
			clear_button.visible = false

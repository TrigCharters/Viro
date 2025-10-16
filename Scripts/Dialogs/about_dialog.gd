extends Panel

@onready var ok_button: Button = $okButton
@onready var dialog_text: Label = $dialogtitleBackground/dialogText


func _ready() -> void:
	dialog_text.text = dialog_text.text.replace("%NAME%", Globals.sys_name)
	dialog_text.text = dialog_text.text.replace("%VER%", Globals.version)
	dialog_text.text = dialog_text.text.replace("%DATE%", Globals.build_date)
	dialog_text.text = dialog_text.text.replace("%TYPE%", Globals.build_type)
	ok_button.grab_focus.call_deferred()
	get_tree().paused = true


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_released("esc_shortcut"):
		accept_event()
		dialog_cancelled()


func _on_ok_button_pressed() -> void:
	dialog_cancelled()


func dialog_cancelled() -> void:
	get_tree().paused = false
	Signals.dialogcancelled.emit()
	queue_free()

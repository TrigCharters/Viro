extends Panel

@onready var cancel_button: Button = $cancelButton

func _ready() -> void:
	cancel_button.grab_focus.call_deferred()
	get_tree().paused = true


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_released("esc_shortcut"):
		accept_event()
		dialog_cancelled()


func _on_ok_button_pressed() -> void:
	get_tree().paused = false
	if System.unSavedflag:
		Globals.last_command = "exit"
	Globals.source_changed = false
	dialog_confirmed()
	

func dialog_confirmed() -> void:
	get_tree().paused = false
	System.unSavedflag = false
	Signals.dialogconfirmed.emit()
	queue_free()

func dialog_cancelled() -> void:
	get_tree().paused = false
	System.unSavedflag = false
	Signals.dialogcancelled.emit()
	queue_free()

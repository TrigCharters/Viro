extends Panel

@onready var directives_list: ItemList = $DirectivesList
@onready var directives: Array[String] = [".alloc", ".data", ".debugMode", ".ignoreLocal", ".ignoreKeyboard", ".ignoreMouse",".link", ".org", ".title","_start:","_irq_subroutine:"]

func _ready() -> void:
	get_tree().paused = true
	set_scroll_bars()
	directives.sort()
	for i: int in directives.size():
		directives_list.add_item(directives[i])
		directives_list.set_item_tooltip_enabled(i,false)


func set_scroll_bars() -> void:
	var vscroll_bar:VScrollBar = directives_list.get_v_scroll_bar()
	vscroll_bar.add_theme_stylebox_override("grabber",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_highlight",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_pressed",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll_focus",StyleBoxEmpty.new())
	vscroll_bar.size.x = 0
	vscroll_bar.custom_minimum_size.x = 0


func _on_directives_list_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	var data: String = directives_list.get_item_text(index)
	if data.to_lower() == "_irq_subroutine:":
		data += "\n\n\trti\n"
	dialog_confirmed(data)


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_released("esc_shortcut"):
		accept_event()
		dialog_cancelled()


func dialog_confirmed(dataValue: String) -> void:
	get_tree().paused = false
	Signals.dialogconfirmedwithvalue.emit(dataValue)
	queue_free()


func dialog_cancelled() -> void:
	get_tree().paused = false
	Signals.dialogcancelled.emit()
	queue_free()

func _on_gui_input(_event: InputEvent) -> void:
	accept_event()

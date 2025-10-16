extends Panel


@onready var constants_list: ItemList = $ConstantsList
@onready var constants: Array[Dictionary] = []


func _ready() -> void:
	get_tree().paused = true
	Tools.load_dictionary_db("constants.edf", constants, true)
	set_scroll_bars()
	display_constants()


func display_constants() -> void:
	var names: Array[String] = []
	for i: int in constants.size():
		names.append(constants[i].name)
	names.sort()
	for i: int in names.size():
		constants_list.add_item(names[i])
		constants_list.set_item_tooltip_enabled(i,false)


func set_scroll_bars() -> void:
	var vscroll_bar:VScrollBar = constants_list.get_v_scroll_bar()
	vscroll_bar.add_theme_stylebox_override("grabber",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_highlight",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_pressed",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll_focus",StyleBoxEmpty.new())
	vscroll_bar.size.x = 0
	vscroll_bar.custom_minimum_size.x = 0


func _on_constants_list_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	dialog_confirmed(constants_list.get_item_text(index))


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

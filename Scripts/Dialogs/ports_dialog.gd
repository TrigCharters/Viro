extends Panel

@onready var port_list: ItemList = $PortList
@onready var ports: Array[Dictionary] = []
@onready var hidden_ports: Array[int] = []


func _ready() -> void:
	get_tree().paused = true
	Tools.load_dictionary_db("ports.edf", ports, true)
	Tools.load_array_data("hidden_ports.edf", hidden_ports, true) 
	set_scroll_bars()
	display_ports()


func display_ports() -> void:
	var idx: int = 0
	for i: int in ports.size():
		if hidden_ports.has(ports[i].data):
			continue
		var portName: String = ports[i].name
		port_list.add_item(portName)
		port_list.set_item_tooltip_enabled(idx,false)
		idx += 1


func set_scroll_bars() -> void:
	var vscroll_bar:VScrollBar = port_list.get_v_scroll_bar()
	vscroll_bar.add_theme_stylebox_override("grabber",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_highlight",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_pressed",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll_focus",StyleBoxEmpty.new())
	vscroll_bar.size.x = 0
	vscroll_bar.custom_minimum_size.x = 0


func _on_port_list_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	dialog_confirmed(port_list.get_item_text(index))


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

extends Panel

@onready var color_picker_rect: TextureRect = $color_picker_rect
@onready var color_image: Image 
@onready var color_texture : ImageTexture
@onready var colors: Array[Color] = []
@onready var color_details_label: Label = $colorDetailsLabel

func _ready() -> void:
	get_tree().paused = true
	generate_color_table()
	draw_color_table()


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_released("esc_shortcut"):
		accept_event()
		dialog_cancelled()


func _on_color_picker_rect_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var index: int = int(event.position.y / 25) * 8 + int(event.position.x / 25)
		color_details_label.text = "Index:" + str(index).rpad(3," ")
		color_details_label.text += " R:" + str(colors[index].r8).rpad(3," ")
		color_details_label.text += " G:" + str(colors[index].g8).rpad(3," ")
		color_details_label.text += " B:" + str(colors[index].b8).rpad(3," ")

	if event is InputEventMouseButton and event.is_released():
		var colorIndex: int = int(event.position.y / 25) * 8 + int(event.position.x / 25)
		dialog_confirmed("#" + str(colorIndex) + " ;Color")


func dialog_confirmed(dataValue: String) -> void:
	get_tree().paused = false
	Signals.dialogconfirmedwithvalue.emit(dataValue)
	queue_free()


func dialog_cancelled() -> void:
	get_tree().paused = false
	Signals.dialogcancelled.emit()
	queue_free()


func draw_color_table() -> void:
	color_image = Image.create_empty(200,200,true,Image.FORMAT_RGBA8)
	color_image.fill(Color.BLACK)
	var x: int = 0
	var xo: int = 0
	var y: int = 0
	var yo: int = 0
	var index: int = 0
	for row: int in 8:
		for column: int in 8:
			if column == 7: xo = 1
			if row == 7: yo = 1
			color_image.fill_rect(Rect2i(x+1,y+1,24-xo,24-yo), colors[index])
			x += 25
			index += 1
		x = 0
		xo = 0
		y += 25

	color_picker_rect.texture = ImageTexture.create_from_image(color_image)


func generate_color_table() -> void:
	var vals: Array[int] = [0,85,170,255]
	var red: int = 0
	var green: int = 0
	var blue: int = 0
	while blue < 4:
		colors.append(Color8(vals[red], vals[green], vals[blue], 255))
		red += 1
		if red > 3:
			red = 0
			green += 1
			if green > 3:
				green = 0
				blue += 1


func _on_gui_input(_event: InputEvent) -> void:
	accept_event()

extends TextEdit

@onready var startaddr: int = 0

func _ready() -> void:
	Tools.set_title("Memory Viewer")
	set_scroll_bars()
	draw_memory_table(startaddr)	
	grab_focus.call_deferred()


func set_scroll_bars() -> void:
	var vscroll_bar:VScrollBar = get_v_scroll_bar()
	vscroll_bar.add_theme_stylebox_override("grabber",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_highlight",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_pressed",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll_focus",StyleBoxEmpty.new())
	vscroll_bar.size.x = 0
	vscroll_bar.custom_minimum_size.x = 0


func draw_memory_table(start_address: int) -> void:
	var address: int = start_address
	var output: String = ""
	text = ""
		
	text += str(Globals.default_memory)
	text += " Bytes of (User Configured) Memory."
	text += "\n" + "\n"
	
	for i: int in 32:
		output = ""
		
		#first do the main address
		var addrString: String = "%X" % address
		addrString = addrString.lpad(4,"0")
		output += addrString + " "
		
		#now build memory contents list
		var cellString: String = ""
		var asciitable: String = ""
		for t: int in 10:
			cellString = "%X" % Globals.memory[address + t]
			cellString = cellString.lpad(2,"0")
			if Globals.memory[address + t] > 31 and Globals.memory[address + t] < 127:
				asciitable += char(int(Globals.memory[address + t]))
			else:
				asciitable += "."
			if cellString.length() > 5:
				cellString = "##"
			cellString = cellString.lpad(6," ")
			output += cellString
			
		output += "  " + asciitable

		address += 10
		if i < 31:
			text += output + "\n"
		else:
			text += output


func _input(event: InputEvent) -> void:
	if Input.is_action_just_released("esc_shortcut"):
		get_tree().change_scene_to_file.call_deferred("res://Scenes/General/code_editor.tscn")
				
	if event is InputEventKey and event.is_pressed():
		match OS.get_keycode_string(event.physical_keycode):
			"Up":
				startaddr -= 10
			"Down":
				startaddr += 10
			"Home":
				startaddr = 0
			"End":
				startaddr = Globals.default_memory - 320
			"PageUp":
				startaddr -= 320
			"PageDown":
				startaddr += 320
			_:
				return
				
		if startaddr < 0: startaddr = 0
		if startaddr > Globals.default_memory - 320: startaddr = Globals.default_memory - 320
		draw_memory_table(startaddr)

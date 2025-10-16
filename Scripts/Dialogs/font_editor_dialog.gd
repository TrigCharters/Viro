extends Panel

@onready var font_glyph_rect: TextureRect = $font_glyph_rect
@onready var glyph_image: Image 
@onready var glyph_texture : ImageTexture
@onready var activechar: int = 0
@onready var chardb: Array[String] = []
@onready var charFlag: Array[int] = []
@onready var max_chars: int = 0
@onready var font_db_locked: bool = true
@onready var font_db_path: String = "res://Resources/db/"
@onready var action_button: Button = $actionButton
@onready var mode_label: Label = $modeLabel
@onready var changes: bool = false
@onready var error: bool = false
@onready var char_details: Label = $charDetails
@onready var btn_tool_tip: Label = $btnToolTip
@onready var dialog_title: Label = $dialogtitleBackground/dialogTitle


func _ready() -> void:
	get_tree().paused = true
	activechar = Globals.font_active_char
	set_fontdb_values()
	setup_graphics()
	load_font_db()


func dialog_cancelled() -> void:
	if changes and not error: save_font_db()
	get_tree().paused = false
	Globals.font_active_char = activechar
	Signals.dialogcancelled.emit()
	queue_free()


func _on_action_button_pressed() -> void:
	if error: return
	if action_button.text == "Create":
		font_db_path = Tools.get_file_path()
		save_font_db()
	else:
		font_db_path = "res://Resources/db/"
		load_font_db()
		font_db_path = Tools.get_file_path()
		save_font_db()
	changes = false
	action_button.release_focus()
	set_fontdb_values()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		
		if error: return
		
		var keyName: String = OS.get_keycode_string(event.keycode).to_lower()
		
		if event.unicode > 0 and event.unicode <= 127:
			activechar = event.unicode
			drawChar()
			return
		
		if OS.get_keycode_string(event.keycode).to_lower() in ["up","down","left","right","home","end"]:
			match keyName:
				"home":
					activechar = 0
				"end":
					activechar = max_chars
				"up":
					activechar += 10
					if activechar > max_chars:
						activechar = 0
				"down":
					activechar -= 10
					if activechar < 0:
						activechar = max_chars
				"left":
					if activechar > 0:
						activechar -= 1
					else:
						activechar = max_chars
				"right":
					if activechar < max_chars:
						activechar += 1
					else:
						activechar = 0
			drawChar()
			return

	if Input.is_action_just_released("esc_shortcut"):
		accept_event()
		dialog_cancelled()



func _on_font_glyph_rect_gui_input(event: InputEvent) -> void:
	if error: return
	
	if event is InputEventMouseButton and event.is_released():
		flipBit( int(event.position.x / 25) ,  int(event.position.y / 25) )


func _on_action_button_focus_entered() -> void:
	if action_button.disabled:
		action_button.release_focus()


func _on_action_button_mouse_entered() -> void:
	if error: return
	
	if not action_button.disabled:
		if action_button.text == "Reset":
			btn_tool_tip.text = "Reset glyphs to default."
		else:
			btn_tool_tip.text = "Create local database."
		mode_label.visible = not mode_label.visible
		btn_tool_tip.visible = not btn_tool_tip.visible
		char_details.visible = not char_details.visible


func _on_action_button_mouse_exited() -> void:
	if error: return
	
	if not action_button.disabled:
		mode_label.visible = not mode_label.visible
		btn_tool_tip.visible = not btn_tool_tip.visible
		char_details.visible = not char_details.visible


func set_fontdb_values() -> void:
	action_button.text = "Create"
	action_button.disabled = true
	mode_label.text = "MODE: System (Locked)"
	font_db_path = "res://Resources/db/"
	font_db_locked = true
	
	# Need diable button, if .ignoreLocal is found
	var ignoreLocalpos: int = Globals.source_code.findn(".ignoreLocal")
	if ignoreLocalpos > -1:
		var priorcr: int = Globals.source_code.rfindn("\n", ignoreLocalpos)
		if Globals.source_code.findn(";", priorcr) > ignoreLocalpos or Globals.source_code.findn(";", priorcr) == -1:
			if OS.is_debug_build():
				mode_label.text = "Debug Mode (Editable)"
			return
	
	action_button.disabled = false
	
	# Need to enable button with 'Create Local' text	
	if not Tools.get_file_exists(Tools.get_file_path(),"font.edf"):
		if OS.is_debug_build():
			mode_label.text = "Debug Mode (Editable)"
			action_button.disabled = true
		return

	# Need to enable button with 'Reset Defaults."
	if Tools.get_file_exists(Tools.get_file_path(),"font.edf"):
		mode_label.text = "MODE: Local (Editable)"
		action_button.text = "Reset"
		font_db_path = Tools.get_file_path()
		font_db_locked = false


func set_char_details() -> void:
	char_details.text = "Unicode: " + str(activechar)
	if activechar in [9,10,12,13,32] or font_db_locked:
		if not mode_label.text in ["MODE: System (Locked)","Debug Mode (Editable)"]:
			char_details.text += " (locked)"


func flipBit(x: int, y: int) -> void:
	if error: return
	
	if OS.is_debug_build():
		pass
	elif activechar in [9,10,12,13,32] or font_db_locked:
		return

	var charLine: String = chardb[(8 * activechar) + y]
	if charLine.is_empty():
		charLine = "00000000"

	var charBits: Array = charLine.split("",true)
	if charBits[x] == "0":
		charBits[x] = "1"
	else:
		charBits[x] = "0"

	chardb[(8 * activechar) + y] = "".join(charBits)

	var startline: int = 7
	var endLine: int = 0

	#Set the has data flag
	charFlag[activechar] = 0
	for i: int in 8:
		if chardb[(8 * activechar) + i].is_empty() or chardb[(8 * activechar) + i] == "00000000":
			pass
		else:
			charFlag[activechar] = 1
			if i < startline: startline = i
			if i > endLine: endLine = i

	if charFlag[activechar]:
		charFlag[activechar] = ((endLine + 1) * 100) + startline
	
	if not dialog_title.text.ends_with("*"):
		dialog_title.text = dialog_title.text + " *"
	
	changes = true
	drawChar()


func drawChar() -> void:
	if error: return
	
	set_char_details()
	drawGrid()

	var charLine: int = 8 * activechar
	for i: int in 8:
		var charLineBits: String = chardb[charLine + i]
		if not charLineBits.is_empty():
			var BitPos: int = charLineBits.find("1",0)
			while BitPos > -1:
				var yn: int = 0
				var xn: int = 0
				if i == 7:
					yn = 1
				if BitPos == 7:
					xn = 1
				
				glyph_image.fill_rect(Rect2i((BitPos*25)+1 ,(i*25)+1 , 24-xn, 24-yn ),Color8(40,40,40,255))
				glyph_image.fill_rect(Rect2i((BitPos*25) + 2 ,(i*25) + 2 , 22-xn, 22-yn ),Color.WHITE)
				BitPos = charLineBits.find("1",BitPos + 1)

	font_glyph_rect.texture.update(glyph_image)


func drawGrid() -> void:
	if error: return
	
	glyph_image.fill(Color.DARK_GRAY)
	var x: int = 0
	var xo: int = 0
	var y: int = 0
	var yo: int = 0
	for row: int in 8:
		for column: int in 8:
			if column == 7: xo = 1
			if row == 7: yo = 1
			glyph_image.fill_rect(Rect2i(x+1,y+1,24-xo,24-yo), Color8(40,40,40,255))
			x += 25
		x = 0
		xo = 0
		y += 25


func setup_graphics() -> void:
	glyph_image = Image.create_empty(200,200,true,Image.FORMAT_RGBA8)
	glyph_image.fill(Color.BLACK)
	font_glyph_rect.texture = ImageTexture.create_from_image(glyph_image)


func save_font_db() -> void:
	var savedb: Array[String] = chardb.duplicate(true)
	var flagdb: Array[String] = []

	for i: int in charFlag.size():
		flagdb.append(str(charFlag[i]))

	for i: int in savedb.size():
		if savedb[i].is_empty() or savedb[i] == "00000000":
			savedb[i] = "0"

	for i: int in savedb.size():
		if savedb[i] != "0":
			var val: int = savedb[i].bin_to_int()
			savedb[i] = str(val)

	var flagData: String = ",".join(flagdb)
	var fileData: String = ",".join(savedb)
	
	fileData = Tools.cipher_text(flagData + "|" + fileData)
	
	var saveMsg: String = Tools.save_file(font_db_path, "font.edf", fileData)
	
	if saveMsg.begins_with("Error"):
		mode_label.text = "Error saving."
		error = true


func load_font_db() -> void:
	var fileData: String = Tools.get_file_contents(font_db_path, "font.edf")
	if fileData.begins_with("Error"):
		mode_label.text = "Error loading."
		error = true
	else:
		chardb.clear()
		charFlag.clear()
		
		fileData = Tools.cipher_text(fileData)

		var sectionData: Array = fileData.split("|",false)
		var charFlags: Array = sectionData[0].split(",",false)
		for i in charFlags.size():
			charFlag.append(charFlags[i].to_int())

		var fileLines: Array = sectionData[1].split(",",false)
		for i: int in fileLines.size():
			if fileLines[i] == "0":
				chardb.append("")
			else:
				chardb.append(int_to_binary(fileLines[i].to_int()))

		max_chars = charFlag.size() - 1
		
		if activechar > max_chars:
			activechar = 0

		changes = false
		drawChar()


func int_to_binary(intValue: int) -> String:
	var bin_str: String = ""
	bin_str = String.num_int64(absi(intValue), 2, false)
	bin_str = bin_str.lpad(8,"0")
	if bin_str.length() > 8:
		bin_str = bin_str.right(8)
	return bin_str


func _on_gui_input(_event: InputEvent) -> void:
	accept_event()

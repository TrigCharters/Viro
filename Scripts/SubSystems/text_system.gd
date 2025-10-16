extends Node

class_name TextSystem

# Font Data base
var fontDB: Array[String] = []
var charFlag: Array[int] = []
var max_character_count: int = 0

# Local Variables
var foregroundcolor: Color = Color.WHITE
var backgroundcolor: Color = Color.BLUE
var gWidth: int = Globals.min_resolution_x
var gHeight: int = Globals.min_resolution_y
var tRegionX: int = 0
var tRegionY: int = 0
var tRegionWidth: int = Globals.min_resolution_x
var tRegionHeight: int = Globals.min_resolution_y
var linePrintActive: bool = false

# Global data
var memory: Array[float] = Globals.memory
var memory_blocks: Array[Dictionary] = Globals.memory_blocks
var data_stack: Array[float] = Globals.data_stack
var graphics_buffer: Array[Image] = Globals.graphics_buffer
var colors: Array[Color] = Globals.colors

#--------------------------------------------------
# System Init
#--------------------------------------------------
func _init() -> void:
	connect_signals()
	load_font_db()

#--------------------------------------------------
# Signal Connections
#--------------------------------------------------
func connect_signals() -> void:
	Signals.text_reset_cursor.connect(reset_cursor)
	Signals.colors_changed.connect(colors_changed)
	Signals.resolution_changed.connect(resolution_changed)


func resolution_changed() -> void:
	reset_text_region()
	gWidth = memory[56] - 1 # Graphics screen is always set to less by one
	gHeight = memory[57] - 1
	clear_text_region()


func colors_changed() -> void:
	foregroundcolor = colors[memory[49]]
	backgroundcolor = colors[memory[48]]


func reset_cursor() -> void:
	memory[35] = tRegionX
	memory[36] = tRegionY

#--------------------------------------------------
# Text Subsystem Routines
#--------------------------------------------------
func process_call(param: int) -> void:
	match param:
		0:
			clear_text_region()

		1:
			reset_cursor()

		2:
			reset_text_region()

		3: # Set Text Region
			if data_stack.size() != 4: return # Must have exact param count
			if data_stack[0] < 0 or data_stack[0] > memory[56]: return # X must be in screen
			if data_stack[1] < 0 or data_stack[1] > memory[57]: return # Y must be in screen
			if data_stack[2] < 8 or data_stack[3] < 8: return # W & H must be at least 8
			if (data_stack[0] + data_stack[2]) > memory[56]: return # X + W must be in screen
			if (data_stack[1] + data_stack[3]) > memory[57]: return # Y + H must be in screen
			if int(data_stack[2]) % 8 != 0 or int(data_stack[3]) % 8 != 0: return # W & H must be multiples of 8
			set_text_region(data_stack[0],data_stack[1],data_stack[2],data_stack[3])

		4:
			scroll_text_region()

		5: # get line print string length
			if data_stack.size() != 1: return # must have exact param count
			memory[1] = get_line_print_length(data_stack[0])

		6: # Line Print
			if data_stack.size() != 3: return # must have exact param count
			select_print(data_stack[0],true)

		7: # Region height
			memory[1] = tRegionHeight

		8: # Region Width
			memory[1] = tRegionWidth

#--------------------------------------------------
# Text Routines
#--------------------------------------------------
func draw_chararcter(char_code: int) -> void:
	# Draw the Character
	match char_code:
		9: # Tab Code
			memory[35] += 24
		10,12,13: # Cariage return and line feed
			memory[35] = tRegionWidth
		32: # Space code
			pass
		_:
			if char_code < 0: return
			if char_code > max_character_count: return
			if not charFlag[char_code]: return

			var startLine: int = charFlag[char_code] % 100
			var endLine: int = charFlag[char_code] / 100
			var charData: int = 8 * char_code
			var BitPos: int = -1
			var charLineData: String = ""
			var cx: int = int(memory[35])
			var cy: int = int(memory[36])

			while startLine < endLine:
				charLineData = fontDB[charData + startLine]
				if not charLineData.is_empty():
					BitPos = charLineData.find("1",0)
					while BitPos > -1:
						plot_pixel(cx + BitPos, cy + startLine)
						BitPos = charLineData.find("1",BitPos + 1)
				startLine += 1
			#Finally schedule a refresh if char had data
			schedule_screen_refresh()

	#increment the text cursor
	memory[35] += 8 # X Cursor position
	if not linePrintActive: check_cursor()


func check_cursor() -> void:
	if memory[35] > (tRegionX + tRegionWidth) - 8: # Check X
		memory[35] = tRegionX # Reset X
		memory[36] += 8 # Increment Y

		if memory[36] > (tRegionY + tRegionHeight) - 8: # Check Y 
			scroll_text_region()
			memory[36] = (tRegionY + tRegionHeight) - 8 #Reset the Y cursor to the bottom line


func clear_text_region() -> void:
	graphics_buffer[memory[44]].fill_rect(Rect2i(tRegionX, tRegionY, tRegionWidth, tRegionHeight), backgroundcolor)
	reset_cursor()
	schedule_screen_refresh()


func scroll_text_region() -> void:
	graphics_buffer[memory[44]].blit_rect(graphics_buffer[memory[44]],Rect2i(tRegionX, tRegionY + 8, tRegionWidth, tRegionHeight - 8), Vector2i(tRegionX,tRegionY))
	graphics_buffer[memory[44]].fill_rect(Rect2i(tRegionX , (tRegionY + tRegionHeight) - 8 , tRegionWidth, 8), backgroundcolor)
	schedule_screen_refresh()


func set_text_region(x: int, y: int, width: int, height: int) -> void:
	tRegionX = x
	tRegionY = y
	tRegionWidth = width
	tRegionHeight = height
	reset_cursor()


func reset_text_region() -> void:
	tRegionX = 0
	tRegionY = 0
	tRegionWidth = memory[56]
	tRegionHeight = memory[57]
	reset_cursor()


func schedule_screen_refresh() -> void:
	if not memory[58] and memory[47]:
		memory[58] = 1


func cursor_setx() -> void:
	memory[35] = roundf(memory[35])
	memory[35] = tRegionX + (memory[35] * 8) # X
	if memory[35] > (tRegionX + tRegionWidth) - 8:
		memory[35] = tRegionX


func cursor_sety() -> void:
	memory[36] = roundf(memory[36])
	memory[36] = tRegionY + (memory[36] * 8) # Y
	if memory[36] > (tRegionY + tRegionHeight) - 8:
		memory[36] = tRegionY


func select_print(address: float, linePrint: bool) -> void:
	print_custom_string(get_print_string(address),linePrint)


func print_custom_string(data: String, linePrint: bool) -> void:
	var old_cx: int = memory[35]
	var old_cy: int = memory[36]
	if linePrint:
		linePrintActive = true
		memory[35] = data_stack[1]
		memory[36] = data_stack[2]
		data = get_line_print_string(data)

	var charData: PackedByteArray = data.to_ascii_buffer()
	for i in charData.size():
		draw_chararcter(charData[i])

	if linePrint:
		linePrintActive = false
		memory[35] = old_cx
		memory[36] = old_cy


func get_line_print_length(data: int) -> int:
	var lineString: String = get_print_string(data)
	lineString = get_line_print_string(lineString)
	return lineString.length() * 8


func get_line_print_string(data: String) -> String:
	data = data.strip_edges()
	data = data.strip_escapes()
	while data.containsn("  "):
		data = data.replacen("  "," ")
	return data


func get_print_string(address: int) -> String:
	if is_valid_string(address):
		var mb_size: int = mb_get_size(address)
		var stringData: String = ""
		for i: int in mb_size:
			stringData += char(int(memory[address + i]))
		return stringData
	else:
		if str(memory[40]).is_valid_int():
			return str(int(memory[40]))
		else:
			var numValue: String = Tools.num_to_str(snappedf(memory[40],0.0001))
			return numValue


func is_valid_string(address: float) -> bool:
	if memory_blocks.size() == 0:
		return false

	if floor(address) != address:
		return false

	var mb_size: int = mb_get_size(address)
	if mb_size == -1: return false

	var has_printables: bool = false
	for i: int in mb_size:
		if memory[address + i] < 0 or memory[address + i] > max_character_count:
			return false
		if floor(memory[address + i]) != memory[address + i]:
			return false
		if charFlag[memory[address + i]]:
			has_printables = true

	if has_printables:
		return true
	else:
		return false


func plot_pixel(x: int, y:int) -> void:
	if x < 0: return
	if x > gWidth: return
	if y < 0: return
	if y > gHeight: return
	graphics_buffer[memory[44]].set_pixel(x,y,foregroundcolor)


func load_font_db() -> void:
	var font_path: String = ""
	if not Globals.ignore_local and Tools.get_file_exists(Tools.get_file_path(), "font.edf"):
		font_path = Tools.get_file_path()
	else:
		font_path = "res://Resources/db/"

	var fileData: String = Tools.get_file_contents(font_path,"font.edf")
	if fileData.begins_with("Error"):
		Signals.throw_system_error.emit(0, "Error Loading Font Database.", 0, true)
		return

	fileData = Tools.cipher_text(fileData)

	var sectionData: Array = fileData.split("|",false)
	var charFlags: Array = sectionData[0].split(",",false)
	for i in charFlags.size():
		charFlag.append(charFlags[i].to_int())

	var fileLines: Array = sectionData[1].split(",",false)
	for i: int in fileLines.size():
		if fileLines[i] == "0":
			fontDB.append("")
		else:
			fontDB.append(int_to_binary(fileLines[i].to_int()))
	max_character_count = charFlag.size() - 1


func mb_get_size(address: int) -> int:
	for i: int in memory_blocks.size():
		if memory_blocks[i].address == address:
			return memory_blocks[i].length
	return -1


func int_to_binary(intValue: int) -> String:
	var bin_str: String = ""
	bin_str = String.num_int64(absi(intValue), 2, false)
	bin_str = bin_str.lpad(8,"0")
	if bin_str.length() > 8:
		bin_str = bin_str.right(8)
	return bin_str

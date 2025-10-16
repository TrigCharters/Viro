extends Node

class_name GraphicsSystem

# Local
var lineToX: int = -1000
var lineToY: int = -1000
var foregroundcolor: Color = Color.WHITE
var backgroundcolor: Color = Color.BLUE
var pixelColor: Color = Color.WHITE
var filePath: String = Tools.get_file_path()
var gRegionX: int = 0
var gRegionY: int = 0
var gRegionWidth: int = Globals.min_resolution_x
var gRegionHeight: int = Globals.min_resolution_y

# Global
var memory: Array[float] = Globals.memory
var data_stack: Array[float] = Globals.data_stack
var graphics_buffer: Array[Image] = Globals.graphics_buffer
var resources: Array[Dictionary] = Globals.resources
var colors: Array[Color] = Globals.colors
var memory_blocks: Array[Dictionary] = Globals.memory_blocks

func _init() -> void:
	connect_signals()
	generate_color_table()
	resolution_mode_changed(0)

#--------------------------------------------------
# Signal Connections
#--------------------------------------------------
func connect_signals() -> void:
	Signals.resolution_mode_changed.connect(resolution_mode_changed)
	Signals.colors_changed.connect(colors_changed)


func colors_changed() -> void:
	foregroundcolor = colors[memory[49]]
	backgroundcolor = colors[memory[48]]
	pixelColor = foregroundcolor


func resolution_mode_changed(mode: int) -> void:
	# Setup graphics array
	graphics_buffer.resize(5)

	# Colors Defaults
	memory[48] = 52
	memory[49] = 63
	Signals.colors_changed.emit()

	# Save width and height
	memory[56] = Globals.min_resolution_x * (mode + 1)
	memory[57] = Globals.min_resolution_y * (mode + 1)
	memory[58] = 1 # First Refresh

	# Generate screens
	for i: int in 5:
		graphics_buffer[i] = Image.create_empty(memory[56],memory[57],true,Image.FORMAT_RGBA8)

	#Save to local variables
	Signals.resolution_changed.emit()

	# Clear all buffers on resolution change
	clear_screen(true, true)

	#save the default region settings
	reset_graphics_region()


#--------------------------------------------------
# Refresh system
#--------------------------------------------------
func schedule_screen_refresh() -> void:
	if not memory[58] and memory[47]:
		memory[58] = 1

#--------------------------------------------------
# Graphics Sub System
#--------------------------------------------------
func process_call(gtype: int) -> void:
	match gtype:
		0: # fill
			clear_screen(false, false)
			schedule_screen_refresh()

		1: # pixel
			if data_stack.size() != 2 : return
			plot_pixel(data_stack[0], data_stack[1])
			schedule_screen_refresh()

		2: # Line
			if data_stack.size() != 4 : return
			plot_line(data_stack[0], data_stack[1], data_stack[2], data_stack[3])
			schedule_screen_refresh()

		3: # Circle
			if data_stack.size() != 3 : return
			plot_circle(data_stack[0], data_stack[1], data_stack[2])
			schedule_screen_refresh()

		4,5,8: # Filled / Unfilled / clear Rectangle
			if data_stack.size() != 4 : return
			rectangle(data_stack[0], data_stack[1],data_stack[2], data_stack[3], gtype)
			schedule_screen_refresh()

		6,7: # Unfilled Square / Filled
			if data_stack.size() != 3 : return
			square(data_stack[0], data_stack[1], data_stack[2], gtype)
			schedule_screen_refresh()

		9: # LineTO
			if data_stack.size() != 2: return
			lineto(data_stack[0],data_stack[1])
			schedule_screen_refresh()

		10,11: # PolyLine & PolyGon
			if data_stack.size() != 1: return
			var address: int = data_stack[0]
			var mb_size: int = mb_get_size(address)
			if not mb_size >= 4 or not mb_size % 2 == 0: return
			polygon(mb_size, address, gtype)
			schedule_screen_refresh()

		12: # sgon
			if data_stack.size() < 3 or data_stack.size() > 6: return
			if data_stack.size() != 6: 
				data_stack.resize(6)
				data_stack[5] = 1 # Default to close unless set
			var mb_size: int = mb_get_size(data_stack[2])
			if not mb_size >= 4 or not mb_size % 2 == 0: return
			sgon(data_stack[0], data_stack[1], data_stack[2], data_stack[3], data_stack[4], data_stack[5], mb_size)
			schedule_screen_refresh()

		13: # gColor
			if data_stack.size() < 4 or data_stack.size() > 5: return
			if data_stack.size() != 5: data_stack.resize(5)
			set_color_index(data_stack[0], data_stack[1], data_stack[2], data_stack[3], data_stack[4])

		14: # const_gCopyBuffer
			if data_stack.size() != 1: return
			if data_stack[0] == memory[44]: return
			if int(data_stack[0]) not in [0,1,2,3,4]: return
			copy_buffer(data_stack[0])
			schedule_screen_refresh()

		15: # Get the color under the passed x and y
			if data_stack.size() != 2: return
			memory[1] = get_pixel_color(data_stack[0],data_stack[1])

		16: # LineToReset
			reset_lineTo()

		17: # Load image into a specified buffer
			if data_stack.size() != 2: return
			if not check_image_resource(data_stack[0]): return
			if int(data_stack[1]) not in [0,1,2,3,4]: return
			load_buffer_with_image(data_stack[1], filePath + resources[data_stack[0]].filename)
			if data_stack[1] == memory[44]:
				schedule_screen_refresh()

		18: # Copy Rect
			if data_stack.size() != 7: return # check for correct number of params
			if data_stack[0] == memory[44]: return # check that source buffer is not the active
			if int(data_stack[0]) not in [0,1,2,3,4]: return
			copy_rect(data_stack[0],\
			Rect2i(data_stack[1],data_stack[2],data_stack[3],data_stack[4]),\
			Vector2i(data_stack[5],data_stack[6]))
			schedule_screen_refresh()

		19: # Clear Screen
			if data_stack.size() > 1: return
			if not data_stack.size(): data_stack.resize(1)
			clear_screen(data_stack[0], true) # All buffer switch
			schedule_screen_refresh()

		20: # Immediate screen refresh
			Signals.screen_refresh.emit(true)

		21,22,23,24: # get region dimensions, w, h, cx, cy
			memory[1] = get_region_dimensions(gtype)

		25: # clear graphics region
			clear_graphics_region()
			schedule_screen_refresh()

		26: # set graphics region
			if data_stack.size() != 4: return
			set_graphics_region(data_stack[0],data_stack[1],data_stack[2],data_stack[3])

		27: # reset graphics region
			reset_graphics_region()

#--------------------------------------------------
# Sub-System functions
#--------------------------------------------------
func clear_graphics_region() -> void:
	graphics_buffer[memory[44]].fill_rect(Rect2i(gRegionX,gRegionY,gRegionWidth,gRegionHeight), backgroundcolor)


func clear_screen(allBuffers: bool, resetTextCursor: bool) -> void:
	if allBuffers:
		for i: int in 5:
			graphics_buffer[i].fill(backgroundcolor)
	else:
		graphics_buffer[memory[44]].fill(backgroundcolor)
	if resetTextCursor:
		Signals.text_reset_cursor.emit()


func copy_buffer(fromBuffer: int) -> void:
	graphics_buffer[memory[44]].copy_from(graphics_buffer[fromBuffer])


func copy_rect(fromBuffer: int, bufferRect: Rect2i, destPoint: Vector2i) -> void:
	# Offset the destination point
	destPoint.x += gRegionX
	destPoint.y += gRegionY

	# Check that any of the copied image appears in the region
	if destPoint.x > (gRegionX + gRegionWidth): return
	if destPoint.y > (gRegionY + gRegionHeight): return
	if (destPoint.x + bufferRect.size.x) < gRegionX: return
	if (destPoint.y + bufferRect.size.y) < gRegionY: return

	# Reduce the copy rect if needed
	if (destPoint.x + bufferRect.size.x) > (gRegionX + gRegionWidth):
		bufferRect.size.x -= (destPoint.x + bufferRect.size.x) - (gRegionX + gRegionWidth)
	if (destPoint.y + bufferRect.size.y) > (gRegionY + gRegionHeight):
		bufferRect.size.y -= (destPoint.y + bufferRect.size.y) - (gRegionY + gRegionHeight)

	graphics_buffer[memory[44]].blit_rect(graphics_buffer[fromBuffer], bufferRect, destPoint)


func get_pixel_color(x: int, y: int) -> int:
	var pixel_color: Color = graphics_buffer[memory[44]].get_pixel(x,y)
	# Store the color values
	memory[26] = pixel_color.r8
	memory[29] = pixel_color.g8
	memory[32] = pixel_color.b8
	memory[43] = pixel_color.a8
	# return the color value if in the color database
	return colors.find(pixel_color)


func get_region_dimensions(pType: int) -> int:
	match pType:
		21: return gRegionWidth
		22: return gRegionHeight
		23: return (gRegionX + gRegionWidth) / 2
		24: return (gRegionY + gRegionHeight) /2
	return -1


func lineto(x: int, y: int) -> void:
	if lineToX == -1000 and lineToY == -1000:
		plot_line(x ,y , x, y)
	else:
		plot_line(lineToX, lineToY, x, y)
	lineToX = x
	lineToY = y


func load_buffer_with_image(bufferID: int, fileName: String) -> void:
	var tmpImage: Image = Image.load_from_file(fileName)
	if tmpImage.get_width() != memory[56] or tmpImage.get_height() != memory[57]: return
	tmpImage.generate_mipmaps(true)
	graphics_buffer[bufferID].copy_from(tmpImage)


func polygon(mb_size: int, address: int, gtype: int) -> void:
	var addr: int  = address
	for i: int in (mb_size / 2) - 1:
		plot_line(memory[addr], memory[addr + 1], memory[addr+2], memory[addr+3])
		addr += 2
	if gtype == 11: #Closing line for polygon
		plot_line(memory[addr], memory[addr + 1], memory[address], memory[address + 1])


func rectangle(x: int, y:int, width: int, height: int, gtype: int) -> void:
	match gtype:
		4,8: 
			if (x + gRegionX) > (gRegionX + gRegionWidth): return
			if (y + gRegionY) > (gRegionY + gRegionHeight): return
			if (x + gRegionX + width) < gRegionX: return
			if (y + gRegionY + height) < gRegionY: return
						
			var drawColor: Color = foregroundcolor
			if gtype == 8: drawColor = backgroundcolor
			
			var rectWidth: int = width
			var rectHeight: int = height
			if (x + gRegionX + width) > (gRegionX + gRegionWidth):
				rectWidth -= (x + gRegionX + width) - (gRegionX + gRegionWidth)
			if (y + gRegionY + height) > (gRegionY + gRegionHeight):
				rectHeight -= (y + gRegionY + height) - (gRegionY + gRegionHeight)
			
			graphics_buffer[memory[44]].fill_rect(Rect2i(gRegionX + x, gRegionX + y, rectWidth, rectHeight), drawColor)
		5:
			plot_line(x, y, x + width, y)
			plot_line(x, y, x, y + height)
			plot_line(x + width, y, x + width, y + height)
			plot_line(x, y + height, x + width, y + height)


func reset_graphics_region() -> void:
	gRegionX = 0
	gRegionY = 0
	gRegionWidth = memory[56] - 1
	gRegionHeight = memory[57] - 1 
	
	
func set_graphics_region(x: int, y:int, width: int, height: int) -> void:
	if x < 0: return
	if y < 0: return
	if (x + width) > memory[56] - 1: return
	if (y + height) > memory[57] - 1: return 
	gRegionX = x
	gRegionY = y
	gRegionWidth = width
	gRegionHeight = height


func reset_lineTo() -> void:
	lineToX = -1000
	lineToY = -1000


func set_color_index(index: int, r: int, g: int, b: int, alpha: int) -> void:
	if index >=0 and index <= 63:
		colors[index] = Color8(r ,g ,b, 255-alpha)
		if index == memory[48] or index == memory[49]:
			Signals.colors_changed.emit()


func sgon(x: int, y: int, address: int, rotation: int, scale: int, closed: bool, points: int) -> void:
	var center_point: Vector2 = Vector2(x, y)
	var start_point: Vector2 = Vector2(memory[address], memory[address + 1])
	var lPoints: int = (points / 2) - 1
	if rotation:
		start_point = start_point.rotated(deg_to_rad(rotation))
	if scale:
		start_point = start_point * scale
	var line_start: Vector2
	var line_end: Vector2 
	for i: int in lPoints:
		line_start = Vector2(memory[address],  memory[address + 1])
		line_end = Vector2(memory[address+2],  memory[address + 3])
		# rotation
		if rotation:
			line_start = line_start.rotated(deg_to_rad(rotation))
			line_end = line_end.rotated(deg_to_rad(rotation))
		# Scaling
		if scale:
			line_start = line_start * scale
			line_end = line_end * scale
		# Draw Actual line	
		plot_line(center_point.x + line_start.x, center_point.y + line_start.y, center_point.x + line_end.x, center_point.y + line_end.y)
		address += 2
	# Draw Closing line
	if closed:
		plot_line(center_point.x + line_end.x, center_point.y + line_end.y, center_point.x + start_point.x, center_point.y + start_point.y)


func square(x: int, y:int, size: int, gtype: int) -> void:
	if gtype == 6:
		plot_line(x, y, x + size, y)
		plot_line(x, y, x, y + size)
		plot_line(x + size, y, x + size, y + size)
		plot_line(x, y + size, x + size, y + size)
	else:
		if (x + gRegionX) > (gRegionX + gRegionWidth): return
		if (y + gRegionY) > (gRegionY + gRegionHeight): return
			
		var rectWidth: int = size
		var rectHeight: int = size
		if (x + gRegionX + size) > (gRegionX + gRegionWidth):
			rectWidth -= (x + gRegionX + size) - (gRegionX + gRegionWidth)
		if (y + gRegionY + size) > (gRegionY + gRegionHeight):
			rectHeight -= (y + gRegionY + size) - (gRegionY + gRegionHeight)
		
		graphics_buffer[memory[44]].fill_rect(Rect2i(x, y, rectWidth, rectHeight), foregroundcolor)

#--------------------------------------------------
# Utilities
#--------------------------------------------------
func get_mouse_translation_in_region(orgMouseCoords: Vector2) -> Vector2:
	memory[33] = 0
	if orgMouseCoords.x < gRegionX: return orgMouseCoords
	if orgMouseCoords.x > gRegionX + gRegionWidth: return orgMouseCoords
	if orgMouseCoords.y < gRegionY: return orgMouseCoords
	if orgMouseCoords.y > gRegionY + gRegionHeight: return orgMouseCoords
	memory[33] = 1
	return Vector2(orgMouseCoords.x - gRegionX, orgMouseCoords.y - gRegionY)


func check_image_resource(id: int) -> bool:
	if id < 0 or id > resources.size() - 1:
		Signals.throw_system_error.emit("Not a valid resource ID.", id, false )
		return false
	if not resources[id].type == "image":
		Signals.throw_system_error.emit("Not a IMAGE resource type.", id, false )
		return false
	if not FileAccess.file_exists(filePath + resources[id].filename):
		Signals.throw_system_error.emit("Resource file " + resources[id].filename + " not found.", id, false )
		return false
	return true


func mb_get_size(address: int) -> int:
	for i: int in memory_blocks.size():
		if memory_blocks[i].address == address:
			return memory_blocks[i].length
	return -1

#-------------------------------------------------
# Core Graphics commands
#------------------------------------------------- 
func plot_pixel(x: int, y:int) -> void:
	x += gRegionX
	y += gRegionY
	if x < gRegionX: return
	if x > gRegionX + gRegionWidth: return
	if y < gRegionY: return
	if y > gRegionY + gRegionHeight: return
	graphics_buffer[memory[44]].set_pixel(x, y,pixelColor)


func plot_circle(cx: int, cy: int, radius: int) -> void:
	var t1: int = radius / 8
	var x: int = radius
	var y: int = 0
	var t2: int = 0
	while x > y:
		plot_pixel(cx + x, cy + y)
		plot_pixel(cx - x, cy + y)
		plot_pixel(cx + x, cy - y)
		plot_pixel(cx - x, cy - y)
		plot_pixel(cx + y, cy + x)
		plot_pixel(cx - y, cy + x)
		plot_pixel(cx + y, cy - x)
		plot_pixel(cx - y, cy - x)
		y += 1
		t1 += y
		t2 = t1 - x
		if t2 >= 0:
			t1 = t2
			x -= 1


func plot_line(x0: int, y0: int, x1: int, y1: int) -> void:
	var dx: int = absi(x1 - x0)
	var sx: int = -1
	if x0 < x1: sx = 1 
	var dy: int = - absi(y1 - y0)
	var sy: int = -1
	if y0 < y1: sy = 1 
	var error: int = dx + dy
	var e2: int = 0
	while true:
		plot_pixel(x0, y0)
		if x0 == x1 and y0 == y1: break
		e2 = 2 * error
		if e2 >= dy:
			if x0 == x1: break
			error = error + dy
			x0 = x0 + sx
		if e2 <= dx:
			if y0 == y1: break
			error = error + dx
			y0 = y0 + sy


func get_color_value(color_val: int) -> int:
	if color_val < 0:
		return 0
	elif color_val > 63:
		return 63
	else:
		return color_val


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

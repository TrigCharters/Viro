extends Control

# general Data
@onready var bitCode: int = 0
@onready var data_stack: Array[float] = Globals.data_stack
@onready var port_addresses: Array[int] = []
@onready var protected_addresses: Array[int] = []
@onready var execution_stack: Array[int] = Globals.execution_stack
@onready var stack: Array[float] = Globals.stack
@onready var store_trigger_addresses: Array[int] = []
@onready var memory: Array[float] = Globals.memory
@onready var memory_bitmask: PackedByteArray = Globals.memory_bitmask
@onready var memory_blocks: Array[Dictionary] = Globals.memory_blocks
@onready var memory_bounds: int = 0
@onready var pc: int = 0
@onready var read_trigger_addresses: Array[int] = []
@onready var resources: Array[Dictionary] = Globals.resources
@onready var runable: bool = false
@onready var yield_frequency: int = 0
@onready var yield_max: int = 0

# Graphics System
@onready var graphics_buffer: Array[Image] = Globals.graphics_buffer
@onready var graphics_texture : ImageTexture

# Scene Elements
@onready var graphics_screen: TextureRect = $GraphicsScreen

# Sub system Scripts
@onready var runtimeTools: RuntimeTools = preload("res://Scripts/Runtime/runtime_tools.gd").new()
@onready var irq: IRQSystem = preload("res://Scripts/SubSystems/irq_system.gd").new()
@onready var fileio: FileIOSystem = preload("res://Scripts/SubSystems/fileio_system.gd").new()
@onready var sounds: SoundSystem = preload("res://Scripts/SubSystems/sound_system.gd").new()
@onready var maths: MathsSystem = preload("res://Scripts/SubSystems/maths_system.gd").new()
@onready var memoryBlocks: MemoryBlockSystem = preload("res://Scripts/SubSystems/memory_block_system.gd").new()
@onready var text: TextSystem = preload("res://Scripts/SubSystems/text_system.gd").new()
@onready var graphics: GraphicsSystem = preload("res://Scripts/SubSystems/graphics_system.gd").new()

#--------------------------------------------------
# Main runtime start point
#--------------------------------------------------
func _ready() -> void:
	# Setup
	Tools.set_title("")
	connect_signals()
	setup_runtime_system()
	graphics_screen.grab_focus.call_deferred()
	
	#Check for setup errors or start engine
	if not Globals.bsod.is_empty():
		execution_stopped()
	else:
		execution_scheduler()

#--------------------------------------------------
# Signal Connections
#--------------------------------------------------
func connect_signals() -> void:
	Signals.screen_refresh.connect(screen_refresh)
	Signals.terminate.connect(terminate)
	Signals.store_pc.connect(store_pc)


func screen_refresh(force: bool) -> void:
	if memory[58] or force:
		graphics_texture.update(graphics_buffer[memory[44]])
		memory[58] = 0


func store_pc() -> void:
	memory[0] = pc


func terminate() -> void:
	runable = false

#--------------------------------------------------
# Core Runtime Routines
#
# This loop will continue to run even when the
# Game Tree is paused
#--------------------------------------------------
func execution_scheduler() -> void:
	runable = true # start the engine
	while runable: # execution loop / runable flag
		if yield_frequency < yield_max: # Engine Performace Register
			if not get_tree().paused:
				execute()
			yield_frequency += 1
			continue

		screen_refresh(false) # Refresh the screen
		await get_tree().process_frame # ALERT Never remove from here
		yield_frequency = 0

	if is_inside_tree(): get_tree().paused = false # Just to make sure
	screen_refresh(false) # Final screen refresh
	execution_stopped() # Progam finished

#--------------------------------------------------
# Stop / After Execution
#--------------------------------------------------
func execution_stopped() -> void:
	# Do clean up
	runtimeTools.post_execution_cleanup()

	# switch to bluescreen if needed
	if not Globals.bsod.is_empty():
		get_tree().change_scene_to_file.call_deferred("res://Scenes/Runtime/bluescreen.tscn")
	else:
		# Stop window moving after performance mode / switch back to preferred mode.
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			System.load_preferences()
		get_tree().change_scene_to_file.call_deferred("res://Scenes/General/main_terminal.tscn")

#--------------------------------------------------
# Main code execution statement
#--------------------------------------------------
func execute() -> void:
	# Check Program counter position
	if not is_valid_pc(): return

	# IRQ Activated by address / trigger time / Active Register
	if memory[10]:
		if memory[12] and not memory[59]:
			if Time.get_ticks_msec() - memory[11] >= memory[12]:
				runtimeTools.frame_create(pc)
				pc = irq.start(pc,false)

	# Get the current Bitcode from memory at the program counter
	bitCode = memory[pc]

	if bitCode > 0:

		if bitCode < 29:
			single_opcodes()
			return
		elif bitCode < 46:
			constants_opcodes()
			return
		elif bitCode < 66:
			address_opcodes()
			return
		elif bitCode < 70:
			pointer_opcodes()
			return
		elif bitCode < 81:
			branch_opcodes()
			return
		elif bitCode == 81:
			call_opcodes()
			return
		else:
			Signals.throw_system_error.emit("Invalid OP code.", bitCode, false )
			return

	elif bitCode == 0:
		pc += 1 #Handle Nops
	else:
		Signals.throw_system_error.emit("Invalid OP code.", bitCode, false )
		return

#--------------------------------------------------
# Op Code Functions
#--------------------------------------------------
func single_opcodes() -> void:
	match bitCode:
		1: #BRK
			runable = false
			return
		2: #INC
			memory[1] += 1
		3: #DEC
			memory[1] -= 1
		4: # STC
			memory[3] = memory[1]
		5: # OUT
			text.draw_chararcter(memory[1])
		6: # IN
			memory[1] = memory[20]
			memory[20] = 0
		7: # RTS
			if execution_stack.is_empty():
				Signals.throw_system_error.emit("Execution Stack Empty, on return from subroutine.", memory[pc], false)
				return
			runtimeTools.frame_restore(pc)
			pc = execution_stack.pop_back()
			return
		8: # yld
			yield_frequency = yield_max
		9: # RND
			memory[1] = randi_range(0, int(memory[1]))
		10: # SHL
			memory[1] = int(memory[1]) << 1
		11: # SHR
			memory[1] = int(memory[1]) >> 1
		12: # HLT
			get_tree().paused = true
		13: # NEG
			memory[1] = - memory[1]
		14: # NOT
			memory[1] = runtimeTools.not_binary(memory[1])
		15: # RTI
			runtimeTools.frame_restore(pc)
			pc = irq.rti(pc)
			return
		16: # SQRT
			memory[1] = sqrt(memory[1])
		17: # PUSHA
			runtimeTools.pusha(pc)
		18: # POPA
			runtimeTools.popa(pc)
		19: # SIN
			memory[1] = sin(memory[1])
		20: # COS
			memory[1] = cos(memory[1])
		21: # TAN
			memory[1] = tan(memory[1])
		22: # Ceil
			memory[1] = ceilf(memory[1])
		23: # Floor
			memory[1] = floorf(memory[1])
		24: # Round
			memory[1] = roundf(memory[1])
		25: # ABS function
			memory[1] = absf(memory[1])
		26: # ror 
			memory[1] = runtimeTools.ror_binary(memory[1])
		27: # rol
			memory[1] = runtimeTools.rol_binary(memory[1])
		28: # software irq
			if memory[10] and not memory[59]:
				runtimeTools.frame_create(pc)
				pc = irq.start(pc, true)
				return
	pc += 1


func constants_opcodes() -> void:
	match bitCode:
		29: #get.time
			memory[1] = Time.get_ticks_msec() - memory[13 + memory[pc + 1]]
		30: #LDA Constant
			memory[1] = memory[pc + 1]
		31: #CMP,CONSTANT
			memory[1] = memory[pc + 1] - memory[1]
		32: #ADD CONSTANT
			memory[1] += memory[pc + 1]
		33: #SUB CONSTANT
			memory[1] -= memory[pc + 1]
		34: #MUL CONSTANT
			memory[1] *= memory[pc + 1]
		35: #DIV CONSTANT
			if memory[1] and memory[pc + 1]:
				memory[1] = memory[1] / memory[pc + 1]
			else:
				memory[1] = 0
		36: #AND CONSTANT
			memory[1] = int(memory[1]) & int(memory[pc + 1]) 
		37: #XOR CONSTANT
			memory[1] = int(memory[1]) ^ int(memory[pc + 1])
		38: #OR CONSTANT
			memory[1] = int(memory[1]) | int(memory[pc + 1])
		39: #Reset Timer
			memory[13 + memory[pc + 1]] = Time.get_ticks_msec()
		40: #MOD CONSTANT
			if memory[1] and memory[pc + 1]:
				memory[1] = fmod(memory[1], memory[pc + 1])
			else:
				memory[1] = 0
		41: # POW CONSTANT
			memory[1] = memory[1] ** memory[pc + 1]
		42: #PUSH constant
			stack.push_back(memory[pc + 1])
			runtimeTools.check_system_stack(pc)
		43: # iDiv
			if memory[1] and memory[pc + 1]:
				memory[1] = memory[1] / memory[pc + 1]
				memory[1] = floorf(memory[1])
			else:
				memory[1] = 0
		44: # pushd Constant
			data_stack.append(memory[pc + 1])
			runtimeTools.check_data_stack(pc)
		45: # CSP Clear Stack Pointet
			runtimeTools.clear_stack(memory[pc + 1])
	pc += 2


func address_opcodes() -> void:
	# Populate Address	
	var address: int = memory[pc + 1]
	#if not is_valid_address(address): return
	
	match bitCode:
		46: #LDA Address
			memory[1] = memory[address]
		47:	#STA Address
			memory[address] = memory[1]
		48: #CMP,ADDRESS
			memory[1] = memory[address] - memory[1]
		49: #PUSH address
			stack.push_back(memory[address])
			runtimeTools.check_system_stack(pc)
		50: #POP Address
			if stack.is_empty():
				Signals.throw_system_error.emit("Stack empty.", memory[pc], false)
				return
			memory[address] = stack.pop_back()
		51: #ADD Address
			memory[1] += memory[address]
		52: #SUB Address
			memory[1] -= memory[address]
		53: #MUL Address
			memory[1] *= memory[address]
		54: #DIV Address
			if memory[1] and memory[address]:
				memory[1] = memory[1] / memory[address]
			else:
				memory[1] = 0
		55: #XCH Address
			var tmp: float = memory[address]
			memory[address] = memory[1]
			memory[1] = tmp
		56: #AND Address
			memory[1] = int(memory[1]) & int(memory[address]) 
		57: #XOR Address
			memory[1] = int(memory[1]) ^ int(memory[address]) 
		58: #OR Address
			memory[1] = int(memory[1]) | int(memory[address]) 
		59: #MOD Address
			if memory[1] and memory[address]:
				memory[1] = fmod(memory[1], memory[address])
			else:
				memory[1] = 0
		60: #POW Address
			memory[1] = memory[1] ** memory[address]
		61: #IN Port
			if read_trigger_addresses.has(address): 
				trigger_read(address)
			else:
				memory[1] = memory[address]
		62: #OUT Port
			if store_trigger_addresses.has(address): 
				trigger_store(address)
			else:
				memory[address] = memory[1]
		63: # iDiv
			if memory[1] and memory[address]:
				memory[1] = memory[1] / memory[address]
				memory[1] = floorf(memory[1])
			else:
				memory[1] = 0	
		64: # STB
			memory[address] = 1
		65: # pushd Address
			data_stack.append(memory[address])
			runtimeTools.check_data_stack(pc)
	pc += 2


func pointer_opcodes() -> void:
	# Populate Pointer and check
	var pointer_address: int = memory[ memory[pc + 1] ]
	if not is_valid_pointer(pointer_address): return

	match bitCode:
		66: #LDA Pointer
			memory[1] = memory[pointer_address]
		67: #STA Pointer
			memory[pointer_address] = memory[1]
		68: #CMP,Pointer
			memory[1] = memory[pointer_address] - memory[1]
		69: #XCH Pointer
			var tmp: float = memory[pointer_address]
			memory[pointer_address] = memory[1]
			memory[1] = tmp
	pc += 2


func branch_opcodes() -> void:
	match bitCode:
		70: #JP
			pc = memory[pc + 1]
			return
		71: #JZ
			if memory[1] == 0:
				pc = memory[pc + 1]
				return
		72: #JNZ
			if memory[1] != 0:
				pc = memory[pc + 1]
				return
		73: #JG
			if memory[1] > 0:
				pc = memory[pc + 1]
				return
		74: #Jl
			if memory[1] < 0:
				pc = memory[pc + 1]
				return
		75: #JGZ
			if memory[1] >= 0:
				pc = memory[pc + 1]
				return
		76: #JlZ
			if memory[1] <= 0:
				pc = memory[pc + 1]
				return
		77: #JSR
			execution_stack.push_back(pc + 2)
			runtimeTools.frame_create(pc)
			runtimeTools.check_execution_stack(pc)
			pc = memory[pc + 1]
			return
		78: #LP
			memory[3] -= 1
			if memory[3] > 0:
				pc = memory[pc + 1]
				return
		79: #JSRZ
			if memory[1] == 0:
				execution_stack.push_back(pc + 2)
				runtimeTools.frame_create(pc)
				runtimeTools.check_execution_stack(pc)
				pc = memory[pc + 1]
				return
		80: #JSRNZ
			if memory[1] != 0:
				execution_stack.push_back(pc + 2)
				runtimeTools.frame_create(pc)
				runtimeTools.check_execution_stack(pc)
				pc = memory[pc + 1]
				return
	pc += 2


func call_opcodes() -> void:
	call_subsystem(memory[pc +1], memory[pc + 2])
	pc += 3


#--------------------------------------------------
# Execution Memory checking
#--------------------------------------------------
func is_valid_pc() -> bool:
	if not memory_bitmask.decode_s8(pc):
		Signals.throw_system_error.emit("Program Counter variable space overrun.", pc, false)
		return false
	return true


func is_valid_pointer(pointer_address: int) -> bool:
	if port_addresses.has(pointer_address): 
		Signals.throw_system_error.emit("Attempted pointer access to port address.", pointer_address, false)
		return false
	if protected_addresses.has(pointer_address): 
		Signals.throw_system_error.emit("Attempted pointer access to protected memory.", pointer_address, false)
		return false
	if pointer_address < 0 or pointer_address > memory_bounds:
		Signals.throw_system_error.emit("Pointer address out of bounds.", pointer_address, false )
		return false
	if memory_bitmask.decode_s8(pointer_address):
		Signals.throw_system_error.emit("Invalid pointer address, program memory overrun.", pointer_address, false)
		return false
	return true

#--------------------------------------------------
# Processor mode switch
#--------------------------------------------------
func _on_tree_entered() -> void:
	OS.low_processor_usage_mode = false


func _on_tree_exited() -> void:
	OS.low_processor_usage_mode = true
	runtimeTools.free()
	irq.free()
	fileio.free()
	maths.free()
	memoryBlocks.free()
	text.free()
	graphics.free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		OS.low_processor_usage_mode = true
	if what == NOTIFICATION_UNPAUSED:
		OS.low_processor_usage_mode = false

#--------------------------------------------------
# Call subsystems
#--------------------------------------------------
func call_subsystem(subsystem: int, param: int) -> void:
	match subsystem:
		0:
			graphics.process_call(param)
		1:
			maths.process_call(param)
		2:
			memoryBlocks.process_call(param)
		3:
			text.process_call(param)

	data_stack.clear() # Always clear the data stack of a call

#--------------------------------------------------
# Trigger port functions
#--------------------------------------------------
func trigger_read(trigger_address: int) -> void:
	match trigger_address:
		42: # File IO
			memory[1] = fileio.read()

		35: # X Text Cursor
			memory[1] = memory[35] / 8

		36: # Y Text Cursor
			memory[1] = memory[36] / 8

		51: # Get Audio Status
			memory[51] = sounds.get_sound_status(resources[memory[1]].filename)
			memory[1] = memory[51]


# Trigger ports for store commands
func trigger_store(trigger_address: int) -> void:
	# Store the prior value for checking purposes
	memory[trigger_address] = memory[1]

	match trigger_address:
		12: # IRQ Trigger value
			if memory[12] < 0:
				memory[12] = 0
			else:
				memory[11] = Time.get_ticks_msec()

		24: # Mouse visible but check for ignore flag
			if not Globals.ignore_mouse: 
				runtimeTools.set_mouse_visible(memory[24])

		27: # Plays audio files.
			sounds.play_sound(memory[27], memory[45])
			memory[45] = 0 # always turn off pitch shift after

		28: # Stops audio files.
			sounds.stop_sound(memory[28])

		30: # Set Screen Mode
			if int(memory[30]) in [0,1]: 
				Signals.resolution_mode_changed.emit(memory[30])
				graphics_texture = ImageTexture.create_from_image(graphics_buffer[memory[44]])
				graphics_screen.texture = graphics_texture
				screen_refresh(true)
			else:
				Signals.throw_system_error.emit("Not a valid screen mode.", memory[30], false )

		31: # Engine performance, changed to a percent based around 100
			if memory[31] < 0.01: memory[31] = 0.01
			if memory[31] > 100: memory[31] = 100
			yield_max = ceili((Globals.one_percent_performance + 20) * memory[31])
			yield_frequency = yield_max # Force an immediate yield on change

		35: # Cursor_x
			text.cursor_setx()

		36: # Cursor_Y
			text.cursor_sety()

		40: # Print a number or string
			text.select_print(memory[40], false)

		41: # Binary Resolution
			if int(memory[41]) not in [8,16,32,64]:
				memory[41] = 8

		42: # File IO open and load data or reset current file
			fileio.write(memory[42])
		
		44: # Change the work and visual screen
			if int(memory[44]) not in [0,1,2,3,4]:
				memory[44] = 0
			if memory[47] and not memory[58]: memory[58] = 1

		47: # Screen autoupdate
			if not memory[47]:
				memory[58] = 0 # Clear any current refresh flags

		46: # Set audio volume
			memory[46] = sounds.set_volume(memory[46])

		48: # Set background color
			memory[48] = graphics.get_color_value(memory[48])
			Signals.colors_changed.emit()

		49: # Set foreground color
			memory[49] = graphics.get_color_value(memory[49])
			Signals.colors_changed.emit()

		52: # Audio auto pause
			memory[52] = sounds.set_auto_pause(memory[52])
			
		53: # Allow polyphony
			memory[53] = sounds.set_allow_polyphony(memory[53])
			memory[54] = sounds.get_max_polyphony()

		54: # max polphony
			if int(memory[54]) in [1,2,3,4,5]:
				sounds.set_max_polyphony(memory[54])
				memory[53] = sounds.get_allowed_polyphony()
				memory[54] = sounds.get_max_polyphony()

		55: # audio.enabled
			memory[55] = sounds.set_sound_enabled(memory[55])

		60: # audio reset
			sounds.sound_reset(memory[60])
			memory[60] = 0

#--------------------------------------------------
# GUI Routines
#--------------------------------------------------
func _gui_input(event: InputEvent) -> void:
	if Input.is_action_just_released("k_shortcut"):
		runable = false # Turn off engine
		return
	
	# Only handle any inputs when runable is true
	if runable:
		if not Globals.ignore_mouse:
			if event is InputEventMouseButton and event.is_pressed():
				if get_tree().paused:
					get_tree().paused = false
				memory[21] = event.button_index
				memory[25] = 1
				return

			if event is InputEventMouseButton and event.is_released():
				memory[25] = 0
				return

			if event is InputEventMouseMotion:
				var divisor: float = roundf(2 - memory[30])
				var mousePos: Vector2 = Vector2(event.position.x / divisor, event.position.y / divisor)
				if memory[34]:
					mousePos = graphics.get_mouse_translation_in_region(mousePos)
				memory[22] = roundf(mousePos.x)
				memory[23] = roundf(mousePos.y)
				return

		if not Globals.ignore_keyboard:
			if event is InputEventKey and event.is_pressed():
				if get_tree().paused:
					get_tree().paused = false
				if event.unicode > 0 and event.unicode <= 127:
					memory[20] = event.unicode
					return
				else:
					match OS.get_keycode_string(event.keycode):
						"Enter", "Kp Enter":
							memory[20] = "\n".to_ascii_buffer()[0]
						"Tab":
							memory[20] = 9
						"Escape":
							memory[20] = 27
						"Shift":
							memory[19] = 1
						"Command":
							memory[16] = 1
						"Option":
							memory[17] = 1
						"Ctrl":
							memory[18] = 1
						"Delete":
							memory[20] = 16
						"Backspace":
							memory[20] = 8
						_:
							memory[20] = event.keycode - 4194100
							if memory[20] < 0: memory[20] = 0
				return

			if event is InputEventKey and event.is_released():
				match OS.get_keycode_string(event.physical_keycode):
					"Shift":
						memory[19] = 0
					"Command":
						memory[16] = 0
					"Option":
						memory[17] = 0
					"Ctrl":
						memory[18] = 0	
				return

#--------------------------------------------------
# Setup Routines
#--------------------------------------------------
func setup_runtime_system() -> void:
	# Load the databases
	setup_load_runtime_db()

	# Registers
	runtimeTools.set_register_defaults(false)
	yield_max = ceili((Globals.one_percent_performance + 20) * 5)
	pc = memory[0]

	# Setup memory bounds
	memory_bounds = memory.size() - 11

	# Setup graphic screen
	graphics_texture = ImageTexture.create_from_image(graphics_buffer[memory[44]])
	graphics_screen.texture = graphics_texture


func setup_load_runtime_db() -> void:
	Globals.db_load_error = false
	Tools.load_array_data("store_trigger_addresses.edf", store_trigger_addresses, true) 
	Tools.load_array_data("read_trigger_addresses.edf", read_trigger_addresses, true)
	Tools.load_array_data("protected_addresses.edf", protected_addresses, true)
	Tools.load_array_data("port_addresses.edf", port_addresses, true)
	if Globals.db_load_error:
		Signals.throw_system_error.emit("Error loading runtime databases.", 0, true)

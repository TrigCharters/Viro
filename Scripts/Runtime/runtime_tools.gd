extends Node

class_name RuntimeTools

# Globals

var memory: Array[float] = Globals.memory
var stack: Array[float] = Globals.stack
var frames: Array[float] = Globals.frames
var data_stack: Array[float] = Globals.data_stack
var execution_stack: Array[int] = Globals.execution_stack

#Local
const BSOD = preload("res://Scripts/Runtime/system_error.gd")


func _init() -> void:
	Signals.throw_system_error.connect(throw_system_error)

#--------------------------------------------------
# System tools
#--------------------------------------------------
func post_execution_cleanup() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.reset(true) # Completely reset the audio
	Tools.clear_memory(not Globals.debug_mode) # Reset memory but keep snapshot and metrics
	Globals.debug_mode = true


func set_register_defaults(isDebug: bool) -> void:
	# Setup register defaults
	memory[11] = Time.get_ticks_msec() # IRQ Counter
	memory[12] = 500 # IRQ Timeout in miliseconds
	memory[13] = memory[11] # Timer0 Start time
	memory[14] = memory[11] # Timer1 Start time
	memory[15] = memory[11] # Timer2 Start time
	# Hide the mouse if ignore set to true
	if Globals.ignore_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	else:
		memory[24] = 1 
	memory[30] = 0 # default screen mode
	memory[31] = 5 # Default engine performace 5%
	memory[33] = 0 # Default for inGraphicsRegionTranslation
	memory[34] = 0 # Default for mouse translation
	memory[35] = 0 # cursor X
	memory[36] = 0 # cursor Y
	memory[41] = 8 # Default binary resolution
	memory[44] = 0 # Active graphics buffer
	memory[46] = 50 # Audio Volume
	memory[47] = 1 # Auto update on graphics screen
	memory[48] = 52 # Background color
	memory[49] = 63 # Forground color
	memory[52] = 0 # Audio Auto Pause
	memory[53] = 0 # Polyphony
	memory[54] = 2 # Max polyphony
	memory[55] = 1 # Audio Enabled
	if not isDebug: memory[50] = 1 # sys.mode register

#---------------------------------------------------
# Binary Tools
#---------------------------------------------------
func int_to_binary(intValue: int) -> String:
	var bin_str: String = ""
	bin_str = String.num_int64(absi(intValue), 2, false)
	bin_str = bin_str.lpad(memory[41],"0")
	if bin_str.length() > memory[41]:
		bin_str = bin_str.right(memory[41])
	return bin_str


func not_binary(intValue: int) -> int:
	var bin_str: String = int_to_binary(intValue)
	bin_str = bin_str.replacen("0","2")
	bin_str = bin_str.replacen("1","0")
	bin_str = bin_str.replacen("2","1")
	if bin_str.length() == 64:
		bin_str = "0" + bin_str.right(63)
	return bin_str.bin_to_int()


func ror_binary(intValue: int) -> int:
	var bin_str: String = int_to_binary(intValue)
	if bin_str.length() == 64:
		bin_str = "0" + bin_str.right(63)
	return (bin_str.right(1) + bin_str.left(memory[41] - 1)).bin_to_int()


func rol_binary(intValue: int) -> int:
	var bin_str: String = int_to_binary(intValue)
	if bin_str.length() == 64:
		bin_str = "0" + bin_str.right(63)
	return (bin_str.right(memory[41] - 1) + bin_str.left(1)).bin_to_int()

#--------------------------------------------------
# GUI Tools
#--------------------------------------------------
func set_mouse_visible(mouse_visible: bool) -> void:
	if mouse_visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else: 	
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

#--------------------------------------------------
# Stack Tools
#--------------------------------------------------
func clear_stack(stack_id: int) -> void:
	match stack_id:
		0: stack.clear()
		1: data_stack.clear()
		2: execution_stack.clear()


func check_system_stack(pc: int) -> void:
	if stack.size() > 1024:
		throw_system_error("Stack overflow.", Globals.memory[pc], false)
		return


func check_data_stack(pc: int) -> void:
	if data_stack.size() > 100:
		throw_system_error("Data Stack overflow.", memory[pc], false)
		return


func check_frames(pc: int) -> void:
	if frames.size() > 200:
		throw_system_error("Stack Frames Overflow.", memory[pc], false)
		return


func check_execution_stack(pc: int) -> void:
	if execution_stack.size() > 100:
		throw_system_error("Execution Stack overflow.", memory[pc], false)
		return


func pusha(pc: int) -> void:
	for i: int in range(1,7):
		stack.push_back(memory[i])
	check_system_stack(pc)


func popa(pc: int) -> void:
	if stack.is_empty() or stack.size() < 6:
		throw_system_error("Invalid Stack Item Count.", memory[pc], false)
		return
	var i: int = 6
	while i > 0:
		memory[i] = stack.pop_back()
		i -= 1

		
func frame_create(pc: int) -> void:
	for i: int in range(1,5):
		frames.push_back(memory[i])
	check_frames(pc)


func frame_restore(pc: int) -> void:
	if frames.is_empty() or frames.size() < 4:
		throw_system_error("Invalid Frame Count.", memory[pc], false)
		return
	var i: int = 4
	while i > 0:
		memory[i] = frames.pop_back()
		i -= 1
		

#--------------------------------------------------
# Error Trapping
#--------------------------------------------------
func throw_system_error(msg: String, address: float, simple: bool) -> void:
	Signals.store_pc.emit()
	var error: Dictionary = {
	"message" = msg, 
	"address" = address,
	"simple" = simple, 
	"program_counter" = memory[0]
	}
	var err: BSOD = SystemError.new(error) # Create the error display
	err.free()
	Signals.terminate.emit()

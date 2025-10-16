extends Node

class_name IRQSystem

var memory: Array[float] = Globals.memory
var execution_stack: Array[int] = Globals.execution_stack
var data_stack: Array[float] = Globals.data_stack
var data_stack_backup: Array[float] = []

#--------------------------------------------------
#IRQ Sub System
#--------------------------------------------------
func rti(pc: int) -> int:
	if execution_stack.is_empty():
		Signals.throw_system_error.emit("Execution Stack Empty, on return from irq.", memory[pc], false)
		return pc
	if not memory[59]:
		Signals.throw_system_error.emit("RTI called but interrupt not active.", memory[pc], false)
		return pc
	restore()
	memory[59] = 0
	memory[11] = Time.get_ticks_msec()
	return execution_stack.pop_back()


func start(pc: int, isSoft: bool) -> int:
	memory[59] = 1
	backup()
	if isSoft: pc += 1
	execution_stack.push_back(pc)
	if execution_stack.size() > 100:
		Signals.throw_system_error.emit("Execution Stack overflow.", memory[pc], false)
		return pc
	return memory[10]


func backup() -> void:
	data_stack_backup = data_stack.duplicate(true)
	data_stack.clear()


func restore() -> void:
	data_stack = data_stack_backup.duplicate(true)
	data_stack_backup.clear()

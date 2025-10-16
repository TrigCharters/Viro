extends Node

class_name SystemError

#------------------------------------------------------
# System for generating the system error BSOD text
#------------------------------------------------------
func _init(error: Dictionary) -> void:
	system_error(error)


func system_error(error: Dictionary) -> void:
	var pc: int = error.program_counter
	var memory: Array[float] = Globals.memory
	var memory_bounds: int = memory.size() - 10
	var stack: Array[float] = Globals.stack
	var frames: Array[float] = Globals.frames
	var data_stack: Array[float] = Globals.data_stack
	var execution_stack: Array[int] = Globals.execution_stack
	
	Globals.bsod = Globals.sys_name + " - System Error\n"	
	Globals.bsod += "Version " + Globals.version + " " + Globals.build_type + "\n\n"
	Globals.bsod += error.message + "\n\n"
	
	if not error.simple: 
		var avo: String = "%X" % error.address
		if not avo.begins_with("-"):avo = avo.lpad(2,"0")
		Globals.bsod += "Address/Value/OP Code : " + avo + "\n"
		var pcs: String = "%X" % pc
		if not pcs.begins_with("-"):pcs = pcs.lpad(4,"0")
		Globals.bsod += "Program Counter : " + pcs + "\n"
		Globals.bsod += "Configured Memory : " + str(memory_bounds) + " Bytes\n"
		Globals.bsod += "Debug Mode : " + str(Globals.debug_mode) + "\n"

		if Globals.file_name.is_empty():
			Globals.bsod += "Project Name : Untitled"
		else:
			Globals.bsod += "Project Name : " + Globals.file_name

		Globals.bsod += "\n\n" + "Stack Frame Count: "
		if frames.is_empty():
			Globals.bsod += "Empty."
		else:
			Globals.bsod += Tools.num_to_str(frames.size() / 4) + " "

		Globals.bsod += "\n" + "Stack : "
		if stack.is_empty():
			Globals.bsod += "Empty."
		else:
			for i in stack.size():
				Globals.bsod += Tools.num_to_str(stack[i]) + " "

		Globals.bsod += "\n" + "Data Stack : "
		if data_stack.is_empty():
			Globals.bsod += "Empty."
		else:
			for i in data_stack.size():
				Globals.bsod += Tools.num_to_str(data_stack[i]) + " "

		Globals.bsod += "\n" + "Execution Stack Return Points : "
		if execution_stack.is_empty():
			Globals.bsod += "Empty."
		else:
			for i in execution_stack.size():
				var extext: String = "%X" % execution_stack[i]
				extext = extext.lpad(4,"0")
				Globals.bsod += extext + " "

		Globals.bsod += "\n\n" + "Memory : " 
		var mempointer: int = pc - 7
		var memtext: String = ""
		for i in 14:
			if mempointer >= 0 and mempointer < memory_bounds:
				memtext = "%X" % memory[mempointer]
				if memtext.length() == 1:
					memtext = "0" + memtext 
				if mempointer == pc:
					memtext = "["+ memtext.replacen(" ","") + "]"
				Globals.bsod += memtext + " "
			mempointer += 1

		var patterns: Array[String] = []
		Tools.load_array_data("patterns.edf", patterns, false)
				
		if pc >= 0 and pc < memory_bounds:
			Globals.bsod += "\n" + "Faulting OP Code : "
			if memory[pc] >=0 and memory[pc] < patterns.size():
				var opcode:String =  "%X" % memory[pc]
				opcode = opcode.lpad(2,"0")
				Globals.bsod += opcode + " : " + patterns[memory[pc]].replacen(","," ")
			else:	
				Globals.bsod += "Invalid / Unknown"

extends Control

@onready var text_edit: TextEdit = $MarginContainer/TextEdit
@onready var source: Array = []
@onready var org_source: Array[String] = []
@onready var patterns: Array[String] = []
@onready var reserved_words: Array[String] = []
@onready var jump_commands: Array[String] = []
@onready var register_commands: Array[String] = []
@onready var registers: Array[String] = []
@onready var read_only_addresses: Array[int] = []
@onready var port_addresses: Array[int] = []
@onready var hidden_ports: Array[int] = []
@onready var protected_addresses: Array[int] = []
@onready var labels: Array[Dictionary] = []
@onready var constants: Array[Dictionary] = []
@onready var code_pointer: int = 0
@onready var compile_error: bool = false
@onready var compile_start_time: int = 0

#--------------------------------------------------
# Main Compiler Start Point
#--------------------------------------------------
func _ready() -> void:
	Tools.set_title("Compiler")
	await get_tree().process_frame
	compile()

#--------------------------------------------------
# Setup / Compile and Clean up
#--------------------------------------------------
func compile() -> void:
	setup_compiler() # Setup the environment
	
	if not compile_error:
		prepare_code()  # Prepare the code for compiling
		replace_constants() # Replace the constants and flags
		build_label_list() # Generate the labels, registers, mb and Resources
		process_source_lines() # Compile each line of code
		check_for_irq_label() # Check for irg subroutine
		check_for_start_label() # Check for program counter
		clear_single_instance() # Clear MBs with 1 value

	# Final Error Check
	if compile_error:
		compile_failure()
	else:
		compile_success()


#--------------------------------------------------
# Environment setup / Clean up
#--------------------------------------------------
func setup_compiler() -> void:
	set_scroll_bars()
	text_edit.grab_focus()
	compile_start_time = Time.get_ticks_msec()
	add_to_console("Compiling...") # Start the process
	if Globals.source_locked: add_to_console("Project is locked. Error messages will be supressed!")
	load_compiler_db() # Load the compiler database files
	
	if not compile_error: # Stop if there was an error loading the databases
		Tools.allocate_memory()
		Globals.game_title = ""
		Globals.ignore_local = false
		Globals.ignore_mouse = false
		Globals.ignore_keyboard = false
		code_pointer = Globals.user_memory_lower_bounds # All below are for system


func compile_failure() -> void:
	add_to_console("Compile Failed...")
	add_to_console("\nEsc to return.")
	Tools.clear_memory(true)
	Globals.max_codepointer = 0


func compile_success() -> void:
	Globals.max_codepointer = code_pointer # Used for free command
	add_to_console("Compile Time: " + str (Time.get_ticks_msec() -  compile_start_time)  + " ms" )
	add_to_console("Compile Successful...")
	
	if not Globals.compile_and_run:
		await get_tree().create_timer(1.0).timeout
		
	if Globals.compile_and_run:
		if Globals.debug_mode:
			get_tree().change_scene_to_file.call_deferred("res://Scenes/Runtime/debug_runtime.tscn")
		else:
			get_tree().change_scene_to_file.call_deferred("res://Scenes/Runtime/performance_runtime.tscn")
	else:
		match Globals.return_from_compiler_to:
			"editor":
				get_tree().change_scene_to_file.call_deferred("res://Scenes/General/code_editor.tscn")
			"terminal":
				get_tree().change_scene_to_file.call_deferred("res://Scenes/General/main_terminal.tscn")


func set_scroll_bars() -> void:
	var vscroll_bar:VScrollBar = text_edit.get_v_scroll_bar()
	vscroll_bar.add_theme_stylebox_override("grabber",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_highlight",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_pressed",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll_focus",StyleBoxEmpty.new())
	vscroll_bar.size.x = 0
	vscroll_bar.custom_minimum_size.x = 0


func _input(_event: InputEvent) -> void:
	# Return to prior screen
	if Input.is_action_just_released("esc_shortcut"):
		match Globals.return_from_compiler_to:
			"editor":
				get_tree().change_scene_to_file.call_deferred("res://Scenes/General/code_editor.tscn")
			"terminal":
				get_tree().change_scene_to_file.call_deferred("res://Scenes/General/main_terminal.tscn")


#--------------------------------------------------
# Compiler Line Processor
#--------------------------------------------------
func process_source_lines() -> void:
	# Process each line of source
	for i: int in source.size():
		if not source[i].is_empty() and not source[i].begins_with(";"):
			compile_line(i)
	store_memory_value(1,true) # Add auto brk at the end
	store_memory_value(255,false) # End of program marker


func compile_line(line_number: int) -> void:
	var bit_code: int = -1
	var word: String = ""
	var word_count: int = 0
	
	Tools.split_phrase(source[line_number])
	word_count = Tools.get_word_count()
	word = Tools.get_word(1)
	
	# make sure first word is a reserved word
	if not reserved_words.has(word):
		add_error(line_number,"", false)
		return
		
	# Single Word Instructions
	if word_count == 1:
		bit_code = patterns.find(word)
		if bit_code > -1:
			store_memory_value(bit_code,true)
		else:
			add_error(line_number, "", false)
		return
		
	# Everything else
	match word:
		".org":
			compile_org(line_number, word_count)
		".data":
			compile_data(line_number)
		".alloc":
			compile_mb(line_number, word_count)
		_: # Check all other patterns
			var pattern: String = word
			var i: int = 2
			while i < Tools.get_word_count() + 1:
				pattern += "," + get_param_type_pattern(i)
				i += 1

			# Check pattern is valid
			bit_code = patterns.find(pattern)
			if bit_code > -1:
				
				# Check valid pattern for usage errors
				if not check_valid_pattern(pattern, word, line_number):
					return
				
				# Store the code in memory after all checks	
				store_memory_value(bit_code,true)
				i = 2
				while i < Tools.get_word_count() + 1:
					store_memory_value(Tools.get_word(i).to_float(),true)
					i += 1
					
			else:
				# Check Invalid patterns and display reason
				if not check_invalid_pattern(pattern,word,line_number):
					return
				# Display default final error
				add_error(line_number,"", false)


func compile_title(line_number:int) -> void:
	var phrase: String = Tools.get_phrase()
	if phrase.begins_with(".title \"") and phrase.ends_with("\"") and phrase.countn("\"") == 2:
		phrase = phrase.replacen(".title \"", "")
		phrase = phrase.replacen("\"","")
		if Globals.game_title.is_empty() and not phrase.is_empty():
			Globals.game_title = phrase
		else:
			if phrase.is_empty() and Globals.game_title.is_empty():
				add_error(line_number,"Invalid Program Title", false)
			else:
				add_error(line_number,"Program Title Already Set", false)
			return		
	else:
		add_error(line_number,"Invalid Title Format", false)


func compile_link(line_number:int, word_count:int) -> void:
	if word_count != 2: 
		add_error(line_number,"", false)
		return

	var file_name:String = Tools.get_word(2)
	if file_name.begins_with("\"") and file_name.ends_with("\"")\
	 and file_name.countn("\"") == 2 and file_name.countn(".") == 1:
		file_name = file_name.replacen("\"","")
	else:
		add_error(line_number,"Resource Syntax Error", false)
		return
	
	if file_name.contains("\\") or file_name.contains("/"):
		add_error(line_number,"Resource Syntax Error", false)
		return

	if not Tools.get_file_exists(Tools.get_file_path(), file_name):
		add_error(line_number,"Resource file not found", false)
		return
	
	var linked_file: Dictionary = {}
	linked_file.filename = file_name
	var extension: String = file_name.right( (file_name.length() - file_name.findn( ".", 0)) - 1 )
	match extension:
		"txt":
			linked_file.type = "text"
		"mp3":
			linked_file.type = "audio"
		"png":
			linked_file.type = "image"
		_:
			add_error(line_number,"Unknown Resource Type", false)
			return
		
	if get_linked_resource_id(linked_file.filename) > -1:
		add_error(line_number,"Resource already linked", false)
		return	
	else:
		Globals.resources.append(linked_file)


func compile_mb(line_number:int, word_count:int) -> void:
	if word_count != 2: 
		add_error(line_number,"", false)
		return

	if not Tools.get_word(2).is_valid_int():
		add_error(line_number,"Error not a valid integer value", false)	
		return
	
	var mb_count: int = Tools.get_word(2).to_int()
	
	if mb_count < 1:
		add_error(line_number,"Error value not a positive non zero integer", false)
		return
		
	for i: int in mb_count:
		store_memory_value(0,false)


func compile_data(line_number:int) -> void:
	var data: String = ""
	var i: int = 2
	while i < Tools.get_word_count() + 1:
		data = Tools.get_word(i)
		i += 1
		if not data.is_valid_float():
			add_error(line_number,"Error not a valid list of numbers", false)	
			break
		store_memory_value(data.to_float(),false)


func compile_org(line_number:int, word_count: int) -> void:
	if word_count != 2: 
		add_error(line_number,"", false)
		return

	var org_address_int: int = Tools.get_word(2).to_int()
	if org_address_int >= code_pointer:
		code_pointer = org_address_int
	else:
		add_error(line_number,"Error invalid ORG address", false)


func check_invalid_pattern(pattern: String, word: String, line_number: int) -> bool:
	if word in ["in","out"]:
		if not pattern.ends_with("port") or hidden_ports.has(Tools.get_word(2).to_int()):
			add_error(line_number,"Invalid address for port operation", false)
			return false
							
	if jump_commands.has(word):
		if Tools.get_word(2).ends_with(":"):
			add_error(line_number,"Error ':' suffix", false)
			return false
		else:
			add_error(line_number,"Error not a defined label", false)
			return false
	
	return true


func check_valid_pattern(pattern: String, word: String, line_number: int) -> bool:
	if mb_get_size(Tools.get_word(2).to_int()) == 1 and pattern.ends_with(",constant"):
		add_error(line_number,"Invalid use of variable address", false)
		return false
	
	if word == "call":
		if Tools.get_word(2).to_int() not in [0,1,2,3]:
			add_error(line_number,"Error not a valid subsystem identifier", false)
			return false

	if word == "csp":
		if Tools.get_word(2).to_int() not in [0,1,2]:
			add_error(line_number,"Error not a valid stack identifier", false)
			return false

	if word not in ["in", "out"] and pattern.ends_with(",address"):
		if port_addresses.has(Tools.get_word(2).to_int()):
			add_error(line_number,"Invalid instuctions for port operation.", false)
			return false

	if jump_commands.has(word):
		if mb_get_size(Tools.get_word(2).to_int()) > -1 or Tools.get_word(2).to_int() < Globals.user_memory_lower_bounds:
			add_error(line_number,"Invalid label for jump instruction", false)
			return false

	if not compile_error:
		if word == "lp" and Tools.get_word(2).to_int() > code_pointer:
			add_error(line_number,"Error invalid loop label address", false)
			return false

	if word == "out":
		if read_only_addresses.has(Tools.get_word(2).to_int()):
			add_error(line_number,"Error read only address", false)
			return false

	if pattern.ends_with(",pointer"):
		var pointer_addr: int = Tools.get_word(2).to_int()
		if port_addresses.has(pointer_addr):
			add_error(line_number,"Invalid memory address for pointer", false)
			return false

	if pattern.ends_with(",address") or pattern.ends_with(",pointer"):
		if Tools.get_word(2).to_int() < 0 or Tools.get_word(2).to_int() >= Globals.default_memory:
			add_error(line_number,"Error outside memory bounds", false)
			return false
		elif protected_addresses.has(Tools.get_word(2).to_int()):
			add_error(line_number,"Error protected memory address", false)
			return false
		elif get_is_label_address(Tools.get_word(2).to_int()) and mb_get_size(Tools.get_word(2).to_int()) == -1:
			add_error(line_number,"Invalid memory address", false)
			return false
		elif not get_is_register_address(Tools.get_word(2).to_int()):
			if mb_get_size(Tools.get_word(2).to_int()) == -1:
				add_error(line_number,"Invalid memory address", false)
				return false

	if word in ["gt","rt"]:
		if Tools.get_word(2).to_int() not in [0,1,2]:
			add_error(line_number,"Error not a valid timer identifier", false)
			return false

	return true


#--------------------------------------------------
# Parameter Checking
#--------------------------------------------------
func get_param_type_pattern(word: int) -> String:
	if check_param_for_type(word,"constant"):
		return "constant"
	if check_param_for_type(word,"label"):
		return "label"
	if check_param_for_type(word,"port"):
		return "port"
	if check_param_for_type(word,"pointer"):
		return "pointer"
	if check_param_for_type(word,"address"):
		return "address"
	return "error"


func check_param_for_type(word: int, param_type: String) -> bool:
	var check_word: String = Tools.get_word(word)

	match param_type:
		"pointer":
			if check_word.begins_with("[") and check_word.ends_with("]") and check_word.length() >= 3 and not check_word.contains("#") and not check_word.contains("$"):
				if check_word.countn("[") == 1 and check_word.countn("]") == 1:
					check_word = check_word.replacen("[","")
					check_word = check_word.replacen("]","")
					
					if check_word.is_valid_float(): # to stop numeric pointers
						add_error(0,"Error numeric address not allowed.", true)
						return false
				else:
					return false
			else:
				return false

		"constant":
			# Check for Linked resource name
			if check_word.begins_with("\"") and check_word.ends_with("\""):
				check_word = get_linked_resource_constant(check_word)
			
			# Check for binary and hex values
			if check_word.begins_with("&b") or check_word.begins_with("&h"):
				if check_word.begins_with("&b"):
					if check_word.length() >= 10:
						check_word = check_word.right(check_word.length() - 2)
						var count: int = check_word.countn("0") + check_word.countn("1")
						if count in [8,16,32,64] and count == check_word.length():
							if count == 64:
								check_word = "0" + check_word.right(63)
							check_word = "#" + str(check_word.bin_to_int())
						else:
							return false
					else:
						return false	
				if check_word.begins_with("&h"):
					if check_word.length() >= 3 and check_word.length() <= 10:
						check_word = check_word.right(check_word.length() - 2)
						if check_word.is_valid_hex_number(false):
							check_word = "#" + str(check_word.hex_to_int()) 
						else:
							return false
					else:
						return false

			# do proper constant check			
			if check_word.begins_with("#") and check_word.length() >= 2:
				if check_word.count("#",0,0) == 1:
					check_word = check_word.replacen("#","")
				else:
					return false
			else:
				return false

		"port":
			if not port_addresses.has(get_label_address(check_word)) or not Tools.get_word(1) in ["in","out"] or hidden_ports.has(get_label_address(check_word)):
				if Tools.get_word(1) in ["in","out"] and hidden_ports.has(get_label_address(check_word)):
					add_error(0,"Error port address is protected.", true)
				return false

		"label":
			if get_label_address(check_word) == -1 or not jump_commands.has(Tools.get_word(1)):
				return false

		"address":
			if check_word.is_valid_float():# to stop numeric addresses
				if Tools.get_word(1) not in [".org"]:
					add_error(0,"Error numeric address not allowed.", true)
					return false	

	if check_word.is_valid_float():
		Tools.set_word(word, check_word)
		return true

	var label_addr: int = get_label_address(check_word)
	if label_addr > -1:
		if param_type == "constant":
			if mb_get_size(label_addr) == -1:
				add_error(0,"Error label does not resolve to variable.", true)
				return false
		Tools.set_word(word, str(label_addr))
		return true

	var register_addr: int = registers.find(check_word)
	if register_addr > -1:
		if param_type == "constant":
			add_error(0,"Error invalid use of register address.", true)
			return false
		Tools.set_word(word, str(register_addr))
		return true

	return false


#--------------------------------------------------
# Label / MB Building
#--------------------------------------------------
func build_label_list() -> void:
	var lcp: int = Globals.user_memory_lower_bounds # User code start position
	var word: String = ""
	var word_count: int = 0
	for i: int in source.size():
		
		if source[i].is_empty() or source[i].begins_with(";"):
			continue
					
		Tools.split_phrase(source[i])
		word_count = Tools.get_word_count()
		word = Tools.get_word(1)
		
		if word_count == 1:
			if get_is_valid_label_name(word):
				# Save the label and position
				if get_label_address(word.left(word.length() - 1)) == -1:
					var label: Dictionary = { "name" = word.left(word.length() -1),"data" = lcp }
					labels.append(label)
					source[i] = ""
				else:
					add_error(i, "Error duplicate label or matches port name", false)
					source[i] = ""
			elif word.to_lower() == ".ignorelocal":
				Globals.ignore_local = true
				source[i] = ""
			elif word.to_lower() == ".ignoremouse":
				Globals.ignore_mouse = true
				source[i] = ""
			elif word.to_lower() == ".ignorekeyboard":
				Globals.ignore_keyboard = true
				source[i] = ""
			elif word.to_lower() == ".debugmode":
				Globals.debug_mode = true
				if not Globals.source_locked:
					Globals.return_from_compiler_to ="editor"
					Globals.return_from_runtime_to = "editor"
				source[i] = ""
			else:
				if reserved_words.has(word):
					lcp += 1
				else:
					add_error(i,"", false)
					source[i] = ""
		elif word_count > 1:
			match word.to_lower(): 
				".title":
					compile_title(i)
					source[i] = ""
				".link":
					compile_link(i, word_count)
					source[i] = ""
				".data":
					Globals.memory_blocks.append({"address" = lcp, "length" = word_count - 1, "pointer" = 0})
					lcp += word_count - 1
				".alloc":
					if word_count == 2:
						if Tools.get_word(2).is_valid_int():
							var mb_count: int = Tools.get_word(2).to_int()
							if  mb_count > 0:
								Globals.memory_blocks.append({"address" = lcp, "length" = mb_count, "pointer" = 0})
								lcp += mb_count
				".org":
					if word_count == 2:
						var org_address_int: int = Tools.get_word(2).to_int()
						if org_address_int > lcp:
							lcp = org_address_int
				_:
					lcp += word_count


func get_is_valid_label_name(label: String) -> bool:
	if label in ["_start:","_irq_subroutine:"]: return true
	var invalid_chars: Array[String] = ["#","[","]","\"","\t","$","."]
	if label.begins_with("_") or label.begins_with("."):
		return false
	if not label.ends_with(":"):
		return false
	if reserved_words.has(label.left(label.length() -1)):
		return false
	if registers.has(label.left(label.length() -1)):
		return false
	if get_is_constant(label):
		return false
	for i: int in invalid_chars.size():
		if label.findn(invalid_chars[i]) > -1:
			return false
	return true


#--------------------------------------------------
# Memory Storage
#--------------------------------------------------
func store_memory_value(val: float, isCode: bool) -> void:
	if not compile_error:
		if code_pointer >= Globals.default_memory:
			add_error(0,"Memory Size Overflow.", true)	
			return
		if not isCode: # Update the memory bitmask
			Globals.memory_bitmask.encode_s8(code_pointer,0)
		Globals.memory[code_pointer] = val # Store the data
		code_pointer += 1

#--------------------------------------------------
# Utilities
#--------------------------------------------------
func mb_get_size(address: int) -> int:
	for i: int in Globals.memory_blocks.size():
		if Globals.memory_blocks[i].address == address:
			return Globals.memory_blocks[i].length
	return -1


func clear_single_instance() -> void:
	# Removes memory blocks for single instance variables
	var i: int = Globals.memory_blocks.size() -1
	while i >= 0:
		if Globals.memory_blocks[i].length == 1:
			Globals.memory_blocks.remove_at(i)
		i -= 1

func check_for_start_label() -> void:
	# Check for _start label
	var start_label_addr: int = get_label_address("_start")
	if start_label_addr > -1:
		if mb_get_size(start_label_addr) == -1:
			Globals.memory[0] = start_label_addr
		else:
			add_error(0,"Error: _start: label defined as variable.", true)
	else:
		add_error(0,"Error: No _start: label found.", true)


func check_for_irq_label() -> void:
	# Check for _irq_subroutine label
	var irq_addr: int = get_label_address("_irq_subroutine")
	if irq_addr > -1:
		if mb_get_size(irq_addr) == -1:
			Globals.memory[10] = irq_addr
		else:
			add_error(0,"Error: IRQ subroutine address defined as variable.", true)


func get_linked_resource_id(file_name: String) -> int:
	for i: int in Globals.resources.size():
		if Globals.resources[i].filename == file_name:
			return i
	return -1


func get_linked_resource_constant(resource_name: String) -> String:
	var check_name: String = resource_name.replacen("\"","")
	for i: int in Globals.resources.size():
		if Globals.resources[i].filename == check_name:
			return "#" + str(i)
	return resource_name
	
	
func prepare_code() -> void:
	#Get a local copy of the source
	var local_source: String = Globals.source_code
	#Split source into array of lines
	source = local_source.split("\n", true)
	org_source.resize(source.size())
	#Clean up each line ready for compile
	for i: int in source.size():
		source[i] = Tools.clean_up_phrase(source[i], true)
		org_source[i] = source[i]


func replace_constants() -> void:
	for i: int in source.size():
		if source[i].is_empty() or source[i].begins_with(";"):
			continue
		var words: Array = source[i].split(" ",false)
		if words.size() > 1 or words[0].begins_with("_"):
			for word: int in words.size():
				if word == 0 and not words[0].begins_with("_"):
					continue
				for constant: int in constants.size():
					if words[word].to_lower() == constants[constant].name.to_lower():
						words[word] = constants[constant].data
						break
			source[i] = " ".join(words)


func get_is_constant(test_name: String) -> bool:
	for i: int in constants.size():
		if constants[i].name == test_name:
			return true
	return false


func get_label_address(label_name: String) -> int:
	for i: int in labels.size():
		if labels[i].name.to_lower() == label_name.to_lower():
			return labels[i].data
	return -1


func get_is_label_address(address: int) -> bool:
	for i: int in labels.size():
		if labels[i].data == address:
			return true
	return false


func get_is_register_address(address: int) -> bool:
	if address in [1,2,3,4,5,6]:
		return true
	return false

#--------------------------------------------------
# Error Display
#--------------------------------------------------
func add_error(line_number: int, msg: String, override: bool) -> void:
	compile_error = true
	if not Globals.source_locked:
		if msg.is_empty():
			add_to_console("Error compiling line: " + str(line_number + 1) + " : " + org_source[line_number])
		else:
			if override:
				add_to_console(msg)
			else:
				add_to_console(msg + ": line: " + str(line_number + 1) + " : " + org_source[line_number])


func add_to_console(msg: String) -> void:
	if text_edit.text == "":
		text_edit.text = msg
	else:
		text_edit.text += "\n" + msg 
	await get_tree().process_frame

#--------------------------------------------------
# Database
#--------------------------------------------------
func load_compiler_db() -> void:
	# Compiler Databases
	Globals.db_load_error = false
	Tools.load_array_data("port_addresses.edf", port_addresses, true)
	Tools.load_array_data("protected_addresses.edf", protected_addresses, true) 
	Tools.load_array_data("readonly_addresses.edf", read_only_addresses, true) 
	Tools.load_array_data("jump_commands.edf", jump_commands, false) 	
	Tools.load_array_data("registers.edf", registers, false)
	Tools.load_array_data("patterns.edf", patterns, false)
	Tools.load_array_data("reserved_words.edf", reserved_words, false)
	Tools.load_dictionary_db("ports.edf", labels, true)
	Tools.load_dictionary_db("constants.edf", constants, false)
	Tools.load_array_data("hidden_ports.edf", hidden_ports, true) 
	
	if Globals.db_load_error:
		add_error(0,"Error loading compiler databases.", true)

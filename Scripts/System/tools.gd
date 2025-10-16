extends Node

@onready var phrase_words: Array = []
@onready var strings_db: Array[Dictionary] = []
@onready var current_title: String = ""

#---------------------------------------------------
# Memory Management
#---------------------------------------------------
func allocate_memory() -> void:
	clear_memory(true)
	Globals.memory.resize(Globals.default_memory + 10)
	Globals.memory.fill(0)
	Globals.memory_bitmask.resize(Globals.default_memory + 10)
	# Create the memory bitmask but blank the register area
	Globals.memory_bitmask.fill(1)
	for i: int in 100:
		Globals.memory_bitmask.encode_s8(i,0)


func clear_memory(doComplete: bool) -> void:
	if doComplete:
		Globals.memory.clear()
		Globals.metrics.clear()

	Globals.data_stack.clear()
	Globals.execution_stack.clear()
	Globals.memory_bitmask.clear()
	Globals.memory_blocks.clear()
	Globals.resources.clear()
	Globals.stack.clear()
	Globals.frames.clear()
	Globals.graphics_buffer.clear()
	Globals.colors.clear()

#---------------------------------------------------
# General Utilities
#---------------------------------------------------
func set_title(title: String) -> void:
	var title_string: String = ""
	current_title = title
	# Set the Title
	if not Globals.debug_mode:
		if Globals.game_title.is_empty():
			title_string = Globals.sys_name
		else:
			title_string = Globals.sys_name + " - " + Globals.game_title
	else:
		if title != "Main Terminal":
			title_string = Globals.sys_name + " - " + title + " - Esc to exit"
		else:
			title_string = Globals.sys_name + " - " + title
		
		if Globals.file_name.is_empty():
			title_string += " - Untitled Project"
		else:
			title_string += " - " + Globals.file_name

		if Globals.source_changed:
			title_string += " *"
	
	# Set the title
	get_window().title = title_string


func set_source_changed(force: bool) -> void:
	if not Globals.file_name.is_empty() or not Globals.source_code.is_empty() or force:
		Globals.source_changed = true
		set_title(current_title)


func new_program() -> void:
	clear_memory(true)
	Globals.max_codepointer = 0
	Globals.source_locked = false
	Globals.flag_autorun = false
	Globals.flag_fullscreen = false
	Globals.game_title = ""
	Globals.password_hash = ""
	Globals.file_name = ""
	Globals.source_code = ""
	Globals.source_changed = false
	Globals.font_active_char = 0


func num_to_str(num: float) -> String:
	var numstr: String = str(num)
	if numstr.ends_with(".0"):
		return numstr.left(numstr.length() - 2)
	return numstr

#---------------------------------------------------
# Cipher Tools
#---------------------------------------------------
func cipher_text(org_text: String) -> String:
	var encrypt_data: String = ""
	var source_data: Array = org_text.to_ascii_buffer()
	for i: int in source_data.size():
		encrypt_data += char(127 - source_data[i])
	encrypt_data = encrypt_data.reverse()
	return encrypt_data

#---------------------------------------------------
# Database
#---------------------------------------------------
func load_strings_database() -> void:
	var string_file_data: String = get_file_contents("res://Resources/db/", "strings.edf")
	
	if string_file_data.begins_with("Error"):
		print_debug("Error loading strings database")
		return

	string_file_data = Tools.cipher_text(string_file_data)

	var strings: Array = string_file_data.split("\n")
	var sections: Array = []
	for i in strings.size():
		sections = strings[i].split("|")
		if sections.size() == 3:
			strings_db.append({"section" = sections[0],"name" = sections[1],"data" = sections[2]})


func get_help_string(section_name: String, string_name: String) -> String:
	if not strings_db.size(): # Only load when needed
		load_strings_database() # Help file for main terminal
		
	for i in strings_db.size():
		if strings_db[i].section == section_name and strings_db[i].name == string_name:
			return strings_db[i].data
	return "No help found."

	
func load_dictionary_db(filename: String, array_name: Array, data_is_number: bool) -> void:
	var file_text: String = get_file_contents("res://Resources/db/",filename)
	
	if file_text.begins_with("Error"):
		print_debug("Error loading database file : " + filename)
		Globals.db_load_error = true
		return
		
	if file_text.is_empty():
		return
		
	file_text = Tools.cipher_text(file_text)
		
	var file_data: Array = file_text.split("\n",false)
	for i: int in file_data.size():
		file_data[i] = file_data[i] # Just in case
		var file_line: Array = file_data[i].split(",",false)
		if file_line.size() > 0:
			if data_is_number:
				array_name.append({ "name" = file_line[0], "data" = file_line[1].to_int() })
			else:
				array_name.append({ "name" = file_line[0], "data" = file_line[1] })


func load_array_data(filename: String, array_name: Array, is_number: bool) -> void:
	var file_text: String = get_file_contents("res://Resources/db/",filename)
	
	if file_text.begins_with("Error"):
		print_debug("Error loading database file : " + filename)
		Globals.db_load_error = true
		return
		
	if file_text.is_empty():
		return
	
	file_text = Tools.cipher_text(file_text)
	
	var file_data: Array = file_text.split("\n",false)
	for i: int in file_data.size():
		file_data[i] = file_data[i] # Just in case
		if is_number:
			array_name.append(file_data[i].to_int())
		else:
			array_name.append(file_data[i])

#---------------------------------------------------
# File IO
#---------------------------------------------------
#return the file path for runtime and compiler / terminal
func get_file_path() -> String:
	return Globals.work_path + Globals.sub_path


# cleans up the filename, removing quotes and adding the extension
func correct_vr_filename(filename: String) -> String:
	if filename.contains("\""):
		filename = filename.replacen("\"","")
	if not filename.ends_with(".vr"):
		filename += ".vr"
	return filename


func save_vr_program_file(filename: String) -> String:
	# Construct XML
	var filedata: String = "<VirtuallyRetro-File>\n"
	filedata = add_key("source", Globals.source_code, filedata)
	filedata = add_key("mem", str(Globals.default_memory), filedata)
	filedata = add_key("row", str(Globals.editor_caret_line), filedata)
	filedata = add_key("col", str(Globals.editor_caret_column), filedata)
	filedata = add_key("hash", Globals.password_hash, filedata)
	filedata = add_key("scroll", str(Globals.editor_scroll_value), filedata)
	filedata = add_key("autorun", str(Globals.flag_autorun), filedata)
	filedata = add_key("fullscreen", str(Globals.flag_fullscreen), filedata)
	
	# Encrypt
	if not Globals.password_hash.is_empty():
		filedata = cipher_text(filedata)
	
	var return_value: String = save_file(get_file_path(), filename, filedata)
	if return_value == "File Saved.":
		Globals.source_changed = false
		Globals.file_name = filename
	
	return return_value


func load_vr_program_file(filename: String) -> String:
	# Load the file data and pass
	var filedata: String = get_file_contents(get_file_path(), filename)
	
	if filedata.begins_with("Error"):
		return filedata
	
	if filedata.is_empty():
		return "File Empty."
	
	# Decrypt
	if not filedata.begins_with("<VirtuallyRetro-File>"):
		filedata = cipher_text(filedata)
		
	# Check for valid file
	if not filedata.begins_with("<VirtuallyRetro-File>"):
		return "Invalid Viro file."
		
	# load password hash
	Globals.password_hash = get_key("hash", filedata)
	
	# set lock
	if not Globals.password_hash.is_empty():
		Globals.source_locked = true
	else:
		Globals.source_locked = false
	
	# Load source
	Globals.source_code = get_key("source", filedata)
	
	# options flags
	Globals.flag_autorun = get_bool_key("autorun",filedata)
	Globals.flag_fullscreen = get_bool_key("fullscreen",filedata)

	# Rows and column
	Globals.editor_caret_line = get_int_key("row",filedata)
	Globals.editor_caret_column = get_int_key("col",filedata)
	Globals.editor_scroll_value = get_int_key("scroll",filedata)
		
	# Set the memory saved with the program
	Globals.default_memory = get_int_key("mem",filedata)
	if Globals.default_memory < 1024: Globals.default_memory = 1024
	if Globals.default_memory > 65536: Globals.default_memory = 65536
	
	Globals.file_name = filename
	Globals.source_changed = false

	return "Loaded."


func get_file_exists(path: String, filename: String) -> bool:
	var fileList: PackedStringArray = DirAccess.get_files_at(path)
	if fileList.find(filename) == -1: return false
	return FileAccess.file_exists(path + filename)


func get_file_contents(path: String, filename: String) -> String:
	var file: FileAccess = FileAccess.open(path + filename, FileAccess.READ)
	if not file:
		return "Error Opening File."
		
	var filedata: String = file.get_as_text()
	var error: int = file.get_error()
	file.close()
	if error == OK:
		return filedata
	else:
		return "Error Reading File."


func save_file(path: String, filename: String, filedata: String) -> String:
	var file: FileAccess = FileAccess.open(path + filename, FileAccess.WRITE)
	if not file:
		return "Error occurred when trying to save the file."
		
	file.store_string(filedata)
	var error: int = file.get_error()
	file.close()
	if error == OK:
		return "File Saved."
	else:
		return "Error saving file."


func is_directory(path: String) -> bool:
	return DirAccess.dir_exists_absolute(path)


func delete_file(filename: String) -> String:
	var dir: DirAccess = DirAccess.open(get_file_path())
	if not dir:
		return "Error opening path."
		
	# Clean up file name
	if filename.contains("\""):
		filename = filename.replacen("\"","")
	
	if is_directory(get_file_path() + filename):
		if OS.get_name() == "macOS":
			dir.remove(get_file_path() + filename + "/.DS_Store")

		var error: int = dir.remove(get_file_path() + filename)
		if error == OK:
			return "Ok."
		else:
			return "Directory Not Empty."

	else:
		if not filename.ends_with(".vr") and not filename.contains("."):
			filename += ".vr"

		# Delete the file		
		if dir.file_exists(get_file_path() + filename):
			dir.remove(get_file_path() + filename)
			if not dir.file_exists(get_file_path() + filename):
				return "Ok."
			else:
				return "Error deleting file."
		else:
			return "Error File doesn't exist."


func dir_contents(Ext: String, mode: int) -> String:
	var files: Array[String] = []

	var dir: DirAccess = DirAccess.open(get_file_path())


	if not dir:
		return("An error occurred when trying to access the path.")
		
	dir.list_dir_begin()
	if not Globals.sub_path.is_empty():
		files.append("[..]")
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			if file_name.ends_with(Ext):
				if not Ext.is_empty() and mode == 0:
					file_name = file_name.replace(".vr", "")
				files.append(file_name)
		else:
			files.append("[" + file_name + "]")
		file_name = dir.get_next()
	files.sort()
	if mode in [0,1]:
		return "  ".join(files)
	else:
		var longestFileName: int = 0
		var longestFileLength: int = 0
		var time_offset: int = 3600 * Globals.time_zone
		var fileLengths: Array[String] = []
		fileLengths.resize(files.size())
		for i in files.size():
			if files[i].begins_with("["):
				continue
			if files[i].length() > longestFileName:
				longestFileName = files[i].length()
			var lsFile: FileAccess = FileAccess.open(get_file_path() + files[i], FileAccess.READ)
			var fileLength: int = lsFile.get_length()
			lsFile.close()
			fileLengths[i] = str(fileLength)
			if fileLengths[i].length() > longestFileLength:
				longestFileLength = fileLengths[i].length()
		for i in files.size():
			if files[i].begins_with("["):
				continue
			var filetime: String = Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(get_file_path() + files[i]) + time_offset, true)
			files[i] = files[i].rpad(longestFileName," ")
			fileLengths[i] = fileLengths[i].lpad(longestFileLength," ")
			files[i] = files[i] + " " + filetime + " " + fileLengths[i] + " bytes"
		return "\n".join(files)

#---------------------------------------------------
# Phrase and word tools
#---------------------------------------------------
# Specifically used by the main terminal
func clean_up_and_split(phrase: String) -> String:
	phrase = clean_up_phrase(phrase, false)
	split_phrase(phrase)
	return get_word(1)


# Cleans up a phrase for spliting into seperate params
func clean_up_phrase(phrase: String, compiler_mode: bool) -> String:
	# basic clean up
	phrase = phrase.replacen(","," ")
		
	# To make the calc command easier to use
	if not compiler_mode and phrase.begins_with("calc"):
		var calc_operators: Array[String] = ["-","**","*","/","%","+","<<",">>","&","^","|"]
		for i: int in calc_operators.size():
			if phrase.findn(calc_operators[i]) > -1:
				phrase = phrase.replacen(calc_operators[i], " "+calc_operators[i]+" ")
				break
	
	# Specific compiler options
	if compiler_mode:
		# Replace Tabs with spaces
		phrase = phrase.replacen("\t", " ")	#Tabs
				
		# Remove inline comments
		var comment_loc: int = phrase.find(";", 0)
		if comment_loc > 1:
			phrase = phrase.left(comment_loc)
		
	# Loop until all double spaces have been removed	
	while phrase.contains("  "):
		phrase = phrase.replacen("  "," ")
	
	# Clean up the edges
	phrase = phrase.strip_edges()

	return phrase


# Split the phrase into individual words
func split_phrase(phrase: String) -> void:
	phrase_words = phrase.split(" ",false)


# Return the number of words
func get_word_count() -> int:
	return phrase_words.size()


# Return a specific word
func get_word(word_number: int) -> String:
	if word_number >= 1 and word_number <= phrase_words.size():
		return phrase_words[word_number - 1]
	else:
		return ""


# set a specific word
func set_word(word_number: int, word_val: String) -> void:
	if word_number >= 1 and word_number <= phrase_words.size():
		phrase_words[word_number - 1] = word_val


# Return an entire cleaned up line
func get_phrase() -> String:
	return " ".join(phrase_words)

#---------------------------------------------------
# XML Tools 1.5
#---------------------------------------------------
func get_key_exists(key: String, xml_data: String) -> bool:
	var key_start: int = xml_data.findn("<" + key + ">", 0)
	var key_end: int = xml_data.findn("</" + key + ">", 0)
	
	if key_start == key_end or key_end < key_start:
		return false
	return true


func get_int_key(key: String, xml_data: String) -> int:
	var keyData: String = get_key(key, xml_data)
	if not keyData.is_empty() and keyData.is_valid_int():
		return keyData.to_int()
	else:
		return -1


func get_float_key(key: String, xml_data: String) -> float:
	var keyData: String = get_key(key, xml_data)
	if not keyData.is_empty() and keyData.is_valid_float():
		return keyData.to_float()
	else:
		return -1


func get_bool_key(key: String, xml_data: String) -> bool:
	var keyData: String = get_key(key, xml_data)
	if not keyData.is_empty() and keyData == "true":
		return true
	else:
		return false


func get_key(key: String, xml_data: String) -> String:
	if not get_key_exists(key, xml_data):
		return ""
	
	var xml_split: PackedStringArray = xml_data.split("<"+key+">", true)
	
	if xml_split.size() > 1:
		xml_split = xml_split[1].split("</"+key+">", true)
		if xml_split.size() > 1:
			return xml_split[0]
		else:
			return ""
	else:
		return ""


func delete_key(key: String, xml_data: String) -> String:
	if not get_key_exists(key, xml_data):
		return xml_data
	
	var header: String
	var xml_split: PackedStringArray = xml_data.split("<"+key+">", true)
	
	if xml_split.size() > 1:
		header = xml_split[0]
		xml_split = xml_split[1].split("</"+key+">", true)
		if xml_split.size() > 1:
			return header + xml_split[1]
		else:
			return xml_data
	else:
		return xml_data


func get_key_list(xml_data: String) -> PackedStringArray:
	xml_data = xml_data.strip_escapes()
	var keyList: PackedStringArray = []
	var splitList: PackedStringArray = xml_data.split("</",false)
	for i: int in splitList.size():
		if not splitList[i].begins_with("<"):
			if splitList[i].contains(">"):
				var keyName: String = splitList[i].split(">",false)[0]
				if keyList.find(keyName) == -1:
					keyList.append(splitList[i].split(">",false)[0])
		
	return keyList


func add_key(key: String, key_data: String, xml_data: String) -> String:
	if get_key_exists(key, xml_data):
		return update_key(key, key_data, xml_data)

	return xml_data + "<"+key+">" + key_data + "</"+key+">"


func update_key(key: String, key_data: String, xml_data: String) -> String:
	if not get_key_exists(key, xml_data):
		return add_key(key, key_data, xml_data)

	var header: String
	var footer: String
	var xml_split: PackedStringArray = xml_data.split("<"+key+">", true)

	if xml_split.size() <= 2:
		header = xml_split[0]
		xml_split = xml_split[1].split("</"+key+">", true)
		if xml_split.size() == 2:
			footer =  xml_split[1]
			return header + "<"+key+">" + key_data + "</"+key+">" + footer 
		else:
			return xml_data
	else:
		return xml_data

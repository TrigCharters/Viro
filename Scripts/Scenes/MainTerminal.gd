extends TextEdit

@onready var alert_dialog: PackedScene = preload("res://Scenes/Dialogs/alert_dialog.tscn")
@onready var about_dialog: PackedScene = preload("res://Scenes/Dialogs/about_dialog.tscn")
@onready var options_dialog: PackedScene = preload("res://Scenes/Dialogs/options_dialog.tscn")
@onready var password_dialog: PackedScene = preload("res://Scenes/Dialogs/password_dialog.tscn")

func _ready() -> void:
	Tools.set_title("Main Terminal")
	get_tree().paused = false # Just in case
	set_scroll_bars()
	set_contents()
	clear_undo_history()
	
	# Connect our signal
	Signals.dialogconfirmed.connect(signal_dialogconfirmed)
	Signals.dialogcancelled.connect(signal_dialogcancelled)
	Signals.dialogconfirmedwithvalue.connect(signal_dialogconfirmedwithvalue)
		
	if Globals.initial_open: # Check for auto loading last file
		Globals.initial_open = false
		if Globals.flag_autoload and not Globals.file_name.is_empty():
			await get_tree().process_frame # Wait for the screen to catch up
			text += "load " + Globals.file_name
			process_command("load " + Globals.file_name)

	if is_inside_tree(): # Needed if an autoload / not saved / autoedit happens
		# Check here for unsaved flag on exit
		if System.unSavedflag:		
			var alert: Node = alert_dialog.instantiate()
			add_child.call_deferred(alert)
		else:
			grab_focus.call_deferred()


# Dialog Comfirmed Signal
func signal_dialogconfirmed() -> void:
	grab_focus()
	process_command(Globals.last_command)


# Dialog Cancelled Signal
func signal_dialogcancelled() -> void:
	grab_focus()
	if not text.ends_with(">"):
		text += "\n>"


# Dialog confirmed with value
func signal_dialogconfirmedwithvalue(data: String) -> void:
	grab_focus()
	text += "\n" + data + "\n>"


# Standard input events
func _input(event: InputEvent) -> void:
	if Input.is_action_just_released("save_shortcut"):
		text += "save"
		process_command("save")
		return

	if Input.is_action_just_released("e_shortcut"):
		process_command("edit")
		return
		
	if Input.is_action_just_released("o_shortcut"):
		process_command("options")
		return
	
	if event is InputEventKey and event.is_pressed():
		#Stop special actions
		if Input.is_action_just_released("ui_text_caret_line_start") or Input.is_action_just_released("ui_text_caret_word_left") or Input.is_action_just_released("ui_text_select_all") or Input.is_action_just_released("ui_text_indent") or Input.is_action_just_released("ui_undo") :
			accept_event()
			return

		match OS.get_keycode_string(event.physical_keycode):
			"Enter", "Kp Enter":
				if get_caret_line() + 1 < get_line_count():
					process_command("")
					accept_event()
				else:
					set_caret_column(text.length())
					var cmd: String = text.substr(text.length() - get_caret_column() + 1, get_caret_column() - 1 )
					
					if cmd.length() == 0:	
						process_command("")
					else:
						Globals.last_command = cmd #.to_lower()
						process_command(cmd)
					
					accept_event()

			"Up":
				if not Globals.last_command.is_empty():
					if get_caret_line() + 1 == get_line_count() and get_caret_column() == 1:
						text += Globals.last_command
						set_caret_column(text.length())
					accept_event()

			"Down":
				accept_event()

			"Backspace","Left","Space":
				if get_caret_column() <= 1:
					accept_event()


# Apple About message
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_ABOUT:
		process_command("about")


func _on_tree_exiting() -> void:
	Globals.terminal_history = text


func invalid_command() -> void:
	text += "\nInvalid command."


func process_command(command: String) -> void:
	command = Tools.clean_up_and_split(command)
	command = command.to_lower()
	var word_count:int = Tools.get_word_count()

	#new help system
	if word_count == 2 and Tools.get_word(2) == "?":
		var help_text: String = Tools.get_help_string("terminal", command)
		help_text = help_text.replacen("%", "\n")
		text += "\n" + help_text + "\n>"
		return

	match command:
		"about","ver","version":
			if word_count == 1:
				var about: Node = about_dialog.instantiate()
				add_child.call_deferred(about)
				return
			else:
				invalid_command()

		"calc":
			match word_count:
				1:
					text += "\nUsage: calc <value> <operator> <value>"
				2:
					if Tools.get_word(2).is_valid_int() and not Tools.get_word(2).begins_with("0"):
						var hexString: String = "%X" % Tools.get_word(2).to_int()
						hexString = hexString.lpad(4,"0")
						text += "\n" + hexString
					elif Tools.get_word(2).is_valid_hex_number(): 
						var decimal_value: int = Tools.get_word(2).hex_to_int()
						text += "\n" + str(decimal_value)
					else:
						text += "\nInvalid value for conversion."
				4:
					var calc_operators: Array[String] = ["-","*","/","%","+","<<",">>","&","^","|","**"]
					if Tools.get_word(2).is_valid_float() and Tools.get_word(4).is_valid_float() and calc_operators.has(Tools.get_word(3)):
						var our_exp: String = Tools.get_phrase()
						our_exp = our_exp.right(our_exp.length() - 5)
						var expression: Expression = Expression.new()
						expression.parse(our_exp)
						var result: float = expression.execute()
						text += "\n" + Tools.num_to_str(result)
					else:
						text += "\nInvalid expression."
				_:
					invalid_command()

		"cd":
			if word_count == 1:
				Globals.sub_path = ""
			elif Tools.get_word(2) == ".." and word_count == 2:
				if Globals.sub_path.is_empty():
					text += "\nNot possible."
				else:
					var sub_count: int = Globals.sub_path.countn("/")
					if sub_count == 1:
						Globals.sub_path = ""
					else:
						var prior_fs: int = 0
						for i: int in sub_count:
							prior_fs = Globals.sub_path.findn("/",i+1)
						Globals.sub_path = Globals.sub_path.left(prior_fs + 1)
			elif word_count >= 2:
				var sub_dir: String = Tools.get_phrase().right(Tools.get_phrase().length() - 3)
				var dirlist: PackedStringArray = DirAccess.get_directories_at(Tools.get_file_path())
				if Tools.is_directory(Tools.get_file_path() + sub_dir) and dirlist.find(sub_dir) > -1:
					if not sub_dir.ends_with("/"):
						sub_dir += "/"
						Globals.sub_path += sub_dir
				else:
					text += "\nNot a directory or incorrect case."

		"cls":
			if word_count == 1:
				text = ">"
				return
			else:
				invalid_command()

		"compile":
			if word_count == 1:
				if Globals.source_code.is_empty():
					text += "\nNothing to compile."
				else:
					Globals.compile_and_run = false
					Globals.return_from_compiler_to = "terminal"
					text += "\n>"
					get_tree().change_scene_to_file.call_deferred("res://Scenes/Compiler/compiler.tscn")
			else:
				invalid_command()

		"delete","del":
			if word_count == 1:
				text += "\nUsage: delete <filename/directory>"
			elif word_count == 2:
				var filename: String = Tools.get_word(2)
				var delete_result: String = Tools.delete_file(filename)
				text += "\n" + delete_result
			else:
				invalid_command()

		"edit","list":
			if word_count == 1:
				if not Globals.source_locked:
					get_tree().change_scene_to_file.call_deferred("res://Scenes/General/code_editor.tscn")
					if text.ends_with(">"): return
				else:
					text += "\nSource code is locked."
			else:
				invalid_command()

		"exit","quit":
			if word_count == 1:
				get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
			else:
				invalid_command()

		"free","mem":
			if word_count == 1:
				text += "\n" + str(Globals.default_memory - Globals.max_codepointer) + " Bytes free. "
				if Globals.max_codepointer > 0:
					text += str(Globals.max_codepointer) + " Total bytes used. "
					text += str(Globals.max_codepointer - Globals.user_memory_lower_bounds - 1) + " Bytes used by program. "
					text += "\n" + str(Globals.default_memory) + " Total bytes of configured memory."
			else:
				invalid_command()

		"help","?":
			if word_count == 1:
				var help_text: String = Tools.get_help_string("terminal","help")
				text += "\n" + help_text
			else:
				invalid_command()

		"load":
			if word_count == 1:
				text += "\nUsage: load <filename>"
			elif word_count == 2:
				if Globals.source_changed and Globals.flag_savePrompt:
					var alert: Node = alert_dialog.instantiate()
					add_child.call_deferred(alert)
					return

				# Save the filename
				var filename: String = Tools.correct_vr_filename(Tools.get_word(2))
				if Tools.get_file_exists(Tools.get_file_path(), filename):

					#Clear all before load
					Tools.new_program()

					# Load and check result
					var load_result: String = Tools.load_vr_program_file(filename)
					Tools.set_title("Main Terminal")
					text += "\n" + load_result

					# File options checks
					if load_result == "Loaded.":
						if Globals.flag_autorun:
							process_command("run")
						elif Globals.flag_autoedit and not Globals.source_locked: 
							process_command("edit")
				else:
					text += "\nFile not found."
			else:
				invalid_command()

		"lock":
			match word_count:
				1:
					if Globals.password_hash.is_empty():
						var password: Node = password_dialog.instantiate()
						add_child.call_deferred(password)
						return
					else:
						if Globals.source_locked:
							text += "\nProject Already Locked."
						else:
							Globals.source_locked = true
							text += "\nLocked."
				_:
					invalid_command()

		"ls","dir","cat":
			var files: String = ""
			match word_count:
				1:
					files = Tools.dir_contents("vr",0)
				2:
					match Tools.get_word(2):
						"-a":
							files = Tools.dir_contents("",1)
						"-al", "-la":
							files = Tools.dir_contents("",2)
						"-l":
							files = Tools.dir_contents("vr",3)
						_:
							invalid_command()
							text += "\n>"
							return
				_:
					invalid_command()
					text += "\n>"
					return
			if files.is_empty():
				text += "\nNo files found."
			else:
				text += "\n" + files

		"mkdir","md":
			match word_count:
				1:
					text += "\nUsage: mkdir <directory name>"
				2:
					var new_dir: String = Tools.get_phrase()
					if command == "mkdir":
						new_dir = new_dir.right(new_dir.length() - 6)
					else:
						new_dir = new_dir.right(new_dir.length() - 3)
				
					if new_dir.contains("\""):
						new_dir = new_dir.replacen("\"","")
				
					if Tools.is_directory(Tools.get_file_path() + new_dir):
						text += "\nA directoy with that name already exists."
					else:
						var dir: DirAccess = DirAccess.open(Tools.get_file_path())
						if dir:
							if dir.file_exists(Tools.get_file_path() + new_dir):
								text += "\nA directoy or file with that name already exists."
							else:
								var error: int = dir.make_dir(Tools.get_file_path() + new_dir)
								if error == OK:
									text += "\nOk."
								else:
									text += "\nError creating directory."
						else:
							text += "\nError opening path."
				_:
					invalid_command()

		"new":
			if word_count == 1:
				if Globals.source_changed and Globals.flag_savePrompt:
					var alert: Node = alert_dialog.instantiate()
					add_child.call_deferred(alert)
					return
				
				Tools.new_program()
				Tools.set_title("Main Terminal")
			else:
				invalid_command()

		"options":
			if word_count == 1:
				var options: Node = options_dialog.instantiate()
				add_child.call_deferred(options)
				return
			else:
				invalid_command()

		"path":
			if word_count == 1:
				if OS.get_name() == "Windows":
					text += "\nCurrent Path: " + Tools.get_file_path().replacen("/","\\")
				else:
					text += "\nCurrent Path: " + Tools.get_file_path()
			elif word_count == 2 and Tools.get_word(2) == "-reset":
				Globals.work_path = "user://"
				Globals.sub_path = ""
				text += "\nPath reset."
			elif word_count > 1:
				var new_path: String = Tools.get_phrase()
				new_path = new_path.right(new_path.length() - 5)
				
				#Check for windows style paths
				if new_path.contains("\\"):
					new_path = new_path.replacen("\\","/")
								
				# Check all directories in path for case
				var pathElements: PackedStringArray = new_path.split("/",false)
				var composePath: String = ""
				if pathElements[0].contains(":"):
					composePath = pathElements[0] # Check for windows style path ID's
					pathElements.remove_at(0)
				else:
					composePath = "/"
				
				var validDirectory: bool = true
				for i: int in pathElements.size():
					var dir: DirAccess = DirAccess.open(composePath)
					if dir:
						var pathDirectories: PackedStringArray = DirAccess.get_directories_at(composePath)
						if pathDirectories.find(pathElements[i]) == -1:
							validDirectory = false
							break
						composePath += pathElements[i] + "/"
					else:
						validDirectory = false

				if not validDirectory:
					text += "\n" + composePath
					text += "\nNot a valid path, or incorrect case."
				else:
					if not new_path.ends_with("/"):
						new_path += "/"
					Globals.work_path = new_path
					Globals.sub_path = ""
					text += "\nSet."

			else:
				invalid_command()

		"reset":
			if word_count == 1:
				if Globals.source_changed and Globals.flag_savePrompt:
					var alert: Node = alert_dialog.instantiate()
					add_child.call_deferred(alert)
					return
				
				Globals.default_memory = 1024
				Tools.new_program()
				text = ""
				get_tree().reload_current_scene()
			else:
				invalid_command()

		"run":
			if word_count == 1:
				
				if Globals.source_code.is_empty():
					text += "\nNothing to run."
				else:
					Globals.debug_mode = false
					Globals.compile_and_run = true
					Globals.return_from_runtime_to = "terminal"
					Globals.return_from_compiler_to = "terminal"
					text += "\n" + ">"
					
					if Globals.flag_fullscreen:
						DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
						
					get_tree().change_scene_to_file.call_deferred("res://Scenes/Compiler/compiler.tscn")
			else:
				invalid_command()

		"save":
			var allow_save: bool = true
			var handled: bool = false
			var filename: String = ""
			if word_count == 1 and Globals.file_name.is_empty():
				text += "\nNo file name set. Save with a filename first."
				handled = true
				allow_save = false
			elif word_count == 1 and not Globals.file_name.is_empty():
				filename = Globals.file_name
				text += "\nSaving : " + filename + " : "
			elif word_count == 2:
				filename = Tools.correct_vr_filename(Tools.get_word(2))
			if allow_save: 
				var save_result: String = Tools.save_vr_program_file(filename)
				if word_count == 1:
					text += save_result
				else:
					text += "\n" + save_result
				Tools.set_title("Main Terminal")
			else:
				if not handled:
					invalid_command()

		"setmem":	
			match word_count:
				1:
					text += "\nUsage: setmem <value>"
				2:
					if Tools.get_word(2).is_valid_int():
						# Work out memory multiple of 1024
						var mem_count: int = Tools.get_word(2).to_int()
						if mem_count <= 1024:
							mem_count = 1024
						elif mem_count >= 65536:
							mem_count = 65536
						else:
							var new_mem: int = 1024
							while new_mem < mem_count:
								new_mem += 1024
							mem_count = new_mem

						Globals.default_memory = mem_count
						Tools.set_source_changed(false)
						text += "\nSet."
					else:
						text += "\nInvalid value type."
				_:
					invalid_command()

		"timezone":
			match word_count:
				1:
					text += "\nUsage: timezone <UTC Offset>"
					text += "\nCurrent UTC timezone offset : "
					if Globals.time_zone > 0:
						text += "+"
					text += str(Globals.time_zone)
				2:
					match Tools.get_word(2):
						"-reset":
							Globals.time_zone = 0
							text += "\nTimezone reset."
						_:
							if not Tools.get_word(2).is_valid_int():
								text += "\nOffset must be a valid integer."
							else:
								if Tools.get_word(2).to_int() < -12 or Tools.get_word(2).to_int() > 14:
									text += "\nNot a valid UTC timezone offset."
								else:
									Globals.time_zone = Tools.get_word(2).to_int()
									text += "\nTimezone Set."
				_:
					invalid_command()

		"unlock":
			match word_count:
				1:
					if not Globals.password_hash.is_empty():
						var password: Node = password_dialog.instantiate()
						add_child.call_deferred(password)
						return
					else:
						text += "\nNo password currently set."
				_:
					invalid_command()

		_:
			if command != "":
				invalid_command()

	# Default text if the command does not return
	text += "\n>"
	
	
func set_caret() -> void:
	set_caret_line(get_line_count())
	set_caret_column(get_line(get_line_count()-1).length())



func set_contents() -> void:
	if Globals.terminal_history.is_empty():
		text = text.replace("%NAME%", Globals.sys_name)
		text = text.replace("%MEM%", str(Globals.default_memory))
		text = text.replace("%VER%", Globals.version)
		text = text.replace("%DATE%", Globals.build_date)
		text = text.replace("%TYPE%", Globals.build_type)
	else:
		if Globals.terminal_history.length() > 1500:
			text = Globals.terminal_history.right(1500)
		else:
			text = Globals.terminal_history

func set_scroll_bars() -> void:
	var vscroll_bar:VScrollBar = get_v_scroll_bar()
	vscroll_bar.add_theme_stylebox_override("grabber",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_highlight",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_pressed",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll_focus",StyleBoxEmpty.new())
	vscroll_bar.size.x = 0
	vscroll_bar.custom_minimum_size.x = 0

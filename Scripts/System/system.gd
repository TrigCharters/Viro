extends Node

@onready var first_load: bool = true
@onready var unSavedflag: bool = false

#---------------------------------------------------
# Setup routines
#---------------------------------------------------
func _ready() -> void:
	# Get the build date
	if OS.is_debug_build():
		encrypt_db_files()
	else:
		if Tools.get_file_exists("res://Resources/db/", "builddate.edf"):
			Globals.build_date = Tools.cipher_text(Tools.get_file_contents("res://Resources/db/", "builddate.edf"))
		else:
			Globals.build_date = Globals.build_year
	
	# Change the auto quit behaviour
	get_tree().set_auto_accept_quit(false)

	# Handle screen resizing here
	get_tree().tree_changed.connect(check_display_size)

	# load save program prefs
	load_preferences()


#---------------------------------------------------
# Window Clousure Notification
#---------------------------------------------------
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		unSavedflag = false
		if Globals.source_changed and Globals.flag_savePrompt:
			unSavedflag = true
			await get_tree().process_frame
			get_tree().change_scene_to_file.call_deferred("res://Scenes/General/main_terminal.tscn")
		else:
			save_preferences()
			get_tree().quit()


func check_display_size() -> void:
	if not Globals.flag_editorFullScreen:
		var scale_factor: int = DisplayServer.get_display_safe_area().size.y / Globals.max_resolution_y
		if DisplayServer.window_get_size().y != int(Globals.max_resolution_y * scale_factor):
			DisplayServer.window_set_size(Vector2(Globals.max_resolution_x * scale_factor,Globals.max_resolution_y * scale_factor), 0)

#---------------------------------------------------
# System Preferences
#---------------------------------------------------
func load_preferences() -> void:
	var file_data: String = Tools.get_file_contents("user://", "viro.prefs")

	if file_data.is_empty(): return

	if file_data.begins_with("Error"):
		print_debug("Error loading vr.prefs file.")
		return

	if first_load: # Only load these prefs the first time
		# Terminal
		Globals.work_path = Tools.get_key("path",file_data)
		Globals.sub_path = Tools.get_key("subpath",file_data)
		if not Tools.is_directory(Tools.get_file_path()):
			Globals.sub_path = ""
		if not Tools.is_directory(Tools.get_file_path()):
			Globals.work_path = "user://"
		
		Globals.time_zone = Tools.get_int_key("timezone", file_data)
		Globals.flag_autoedit = Tools.get_bool_key("autoedit",file_data)
		Globals.flag_autoload = Tools.get_bool_key("autoload",file_data)

		if Globals.flag_autoload and not Tools.get_key("filename",file_data).is_empty():
			Globals.file_name = Tools.get_key("filename",file_data)
		
		Globals.flag_editorFullScreen = Tools.get_bool_key("editorfullscreen",file_data)
		Globals.flag_savePrompt = Tools.get_bool_key("saveprompt",file_data)

		Globals.debug_pane_update_frequency = Tools.get_int_key("updatefrequency",file_data)
		if Globals.debug_pane_update_frequency not in [15,30,60]:
			Globals.debug_pane_update_frequency = 30

		# Runtime
		Globals.debug_pane_visible = Tools.get_bool_key("debug",file_data)
		
		# Code editor
		Globals.flag_metrics = Tools.get_bool_key("metrics",file_data)
		Globals.flag_autosave = Tools.get_bool_key("autosave",file_data)
		Globals.editor_use_reduced_line_spacing = Tools.get_bool_key("spacing",file_data)
		Globals.editor_use_line_numbers = Tools.get_bool_key("linenumbers",file_data)
		Globals.editor_pad_line_numbers = Tools.get_bool_key("padding",file_data)
		Globals.editor_enable_wrapping = Tools.get_bool_key("wrapping",file_data)

		first_load = false

	# System
	if not Globals.flag_editorFullScreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var scale_factor: int = DisplayServer.get_display_safe_area().size.y / Globals.max_resolution_y
			var posx: int = (DisplayServer.get_display_safe_area().size.x / 2)
			posx -= (Globals.max_resolution_x * scale_factor) / 2
			var posy: int= (DisplayServer.get_display_safe_area().size.y / 2)
			posy -= (Globals.max_resolution_y * scale_factor) / 2
			DisplayServer.window_set_position(Vector2(posx,posy),0)
	else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func save_preferences() -> void:
	var file_data: String

	# Runtime
	file_data = Tools.add_key("debug", str(Globals.debug_pane_visible), file_data)
	file_data = Tools.add_key("updatefrequency", str(Globals.debug_pane_update_frequency), file_data)
	
	# Terminal
	file_data = Tools.add_key("timezone", str(Globals.time_zone), file_data)
	file_data = Tools.add_key("autoload", str(Globals.flag_autoload), file_data)
	file_data = Tools.add_key("path", Globals.work_path, file_data)
	file_data = Tools.add_key("subpath", Globals.sub_path, file_data)
	file_data = Tools.add_key("autoedit", str(Globals.flag_autoedit), file_data)
	file_data = Tools.add_key("editorfullscreen", str(Globals.flag_editorFullScreen), file_data)
	file_data = Tools.add_key("saveprompt", str(Globals.flag_savePrompt), file_data)
	if Globals.flag_autoload and not Globals.file_name.is_empty():
		file_data = Tools.add_key("filename", Globals.file_name, file_data)

	# Editor
	file_data = Tools.add_key("autosave", str(Globals.flag_autosave), file_data)
	file_data = Tools.add_key("metrics", str(Globals.flag_metrics), file_data)
	file_data = Tools.add_key("spacing", str(Globals.editor_use_reduced_line_spacing), file_data)
	file_data = Tools.add_key("linenumbers", str(Globals.editor_use_line_numbers), file_data)
	file_data = Tools.add_key("padding", str(Globals.editor_pad_line_numbers), file_data)
	file_data = Tools.add_key("wrapping", str(Globals.editor_enable_wrapping), file_data)

	# Save
	var save_result: String = Tools.save_file("user://", "viro.prefs", file_data)
	if save_result != "File Saved.":
		print_debug("Error saving vr.prefs file.")

#---------------------------------------------------
# Encrypt Database files
#---------------------------------------------------
func encrypt_db_files() -> void:
	# Save Build Date
	Globals.build_date = Time.get_date_string_from_system(false)
	Tools.save_file("res://Resources/db/","builddate.txt", Globals.build_date)
	
	var fileList: PackedStringArray = DirAccess.get_files_at("res://Resources/db/")
	for i: int in fileList.size():
		if fileList[i].ends_with("txt"):
			var fileName: String = fileList[i].replacen(".txt",".edf")
			Tools.save_file("res://Resources/db/",fileName, Tools.cipher_text(Tools.get_file_contents("res://Resources/db/",fileList[i])))

	#Tools.save_file("res://Resources/db/","font.edf", Tools.cipher_text(Tools.get_file_contents("res://Resources/db/","font.fdb")))

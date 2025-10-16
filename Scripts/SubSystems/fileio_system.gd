extends Node

class_name FileIOSystem

#globals
var data_stack: Array[float] = Globals.data_stack
var resources: Array[Dictionary] = Globals.resources

# Local
var filePointer: int = 0
var fileBuffer: PackedByteArray = []
var filePath: String = Tools.get_file_path()


func read() -> int:
	if filePointer < fileBuffer.size():
		var filebyte: int = fileBuffer.decode_s8(filePointer)
		filePointer += 1
		
		# To stop null values in the file
		if filebyte == 0 and filePointer < fileBuffer.size():
			filebyte = -1
		
		return filebyte
	else:
		return 0


func write(param: int) -> void:
	match param:
		-1: # Clear
			filePointer = 0
			fileBuffer.clear()
		-2: # Reset
			filePointer = 0
		-3: # Advance file pointer
			if data_stack.is_empty(): return
			filePointer += data_stack.pop_back()
			if filePointer > fileBuffer.size(): filePointer = fileBuffer.size()
			if filePointer < 0: filePointer = 0
		_:
			if not check_text_resource(param): return
			
			var file: FileAccess = FileAccess.open(filePath + resources[param].filename , FileAccess.READ)
			if not file:
				Signals.throw_system_error.emit("Error reading file " + resources[param].filename, param, false )
				return
				
			var filedata: String = file.get_as_text()
			file.close()
			fileBuffer = filedata.to_ascii_buffer()
			filePointer = 0


func check_text_resource(id: int) -> bool:
	if id < 0 or id > resources.size() - 1:
		Signals.throw_system_error.emit("Not a valid resource ID.", id, false )
		return false
	if not resources[id].type == "text":
		Signals.throw_system_error.emit("Not a TEXT resource type.", id, false )
		return false
	if not FileAccess.file_exists(filePath + resources[id].filename):
		Signals.throw_system_error.emit("Resource file " + resources[id].filename + " not found.", id, false )
		return false
	return true

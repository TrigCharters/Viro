extends Node

class_name SoundSystem

# Globals
var resources: Array[Dictionary] = Globals.resources

# Local
var filePath: String = Tools.get_file_path()


func _init() -> void:
	Audio.reset(true)
	Audio.soundFilesPath = filePath


func get_sound_status(fileName: String) -> int:
	return Audio.get_sound_status_by_name(fileName)


func play_sound(id: int, pitchShift: bool) -> void:
	if check_sound_resource(id):
		Audio.play_sound_by_name(resources[id].filename, pitchShift)


func stop_sound(id: int) -> void:
	Audio.stop_sound_by_name(resources[id].filename)


func set_volume(vol: int) -> int:
	Audio.set_volume(vol)
	return Audio.soundDefaultVolume * 100


func set_auto_pause(auto_pause: bool) -> int:
	Audio.set_sound_autopause(auto_pause)
	if auto_pause:
		return 1
	return 0


func set_allow_polyphony(allowPolyphony: bool) -> int:
	Audio.set_sound_allow_polyphony(allowPolyphony)
	if Audio.soundMaxPolyphony > 1:
		return Audio.soundMaxPolyphony
	return 0


func set_max_polyphony(max_polyphony: int) -> void:
	Audio.set_sound_max_polyphony(max_polyphony)


func get_allowed_polyphony() -> int:
	if Audio.soundAllowPolyphony:
		return 1
	return 0


func get_max_polyphony() -> int:
	return Audio.soundMaxPolyphony


func set_sound_enabled(enabled: bool) -> int:
	Audio.set_sound_enabled(enabled)
	if enabled:
		return 1
	return 0


func sound_reset(reset: bool) -> void:
	if reset:
		Audio.reset(true)
		Audio.soundFilesPath = filePath


func check_sound_resource(id: int) -> bool:
	if id < 0 or id > resources.size() - 1:
		Signals.throw_system_error.emit("Not a valid resource ID.", id, false )
		return false
	if not resources[id].type == "audio":
		Signals.throw_system_error.emit("Not a AUDIO resource type.", id, false )
		return false
	if not FileAccess.file_exists(filePath + resources[id].filename):
		Signals.throw_system_error.emit("Resource file " + resources[id].filename + " not found.", id, false )
		return false
	return true

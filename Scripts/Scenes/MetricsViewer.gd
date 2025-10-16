extends TextEdit

@onready var patterns: Array[String] = []
@onready var metrics: Array[int] = []
@onready var opcodes: Array[int] = []
@onready var pattern: Array[String] = []

func _ready() -> void:
	Tools.set_title("Metrics Viewer")
	set_scroll_bars()
	Tools.load_array_data("patterns.edf", patterns, false) 
	display_metrics()	
	grab_focus.call_deferred()


func set_scroll_bars() -> void:
	var vscroll_bar:VScrollBar = get_v_scroll_bar()
	vscroll_bar.add_theme_stylebox_override("grabber",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_highlight",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("grabber_pressed",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll",StyleBoxEmpty.new())
	vscroll_bar.add_theme_stylebox_override("scroll_focus",StyleBoxEmpty.new())
	vscroll_bar.size.x = 0
	vscroll_bar.custom_minimum_size.x = 0


func _input(event: InputEvent) -> void:
	if Input.is_action_just_released("esc_shortcut"):
		get_tree().change_scene_to_file.call_deferred("res://Scenes/General/code_editor.tscn")

	if event is InputEventKey and event.is_released():
		match OS.get_keycode_string(event.keycode):
			"Up","Home":
				set_caret_line(0)
				set_caret_column(0)
			"Down","End":
				set_caret_line(get_line_count())
				set_caret_column(get_line(get_line_count()-1).length())


# Return a float as a string with a specific number of digits
func get_float_digits(index: int, percent: float) -> String:
	var value: String = str(snappedf( float(metrics[index]) / percent, 0.0001))
	if not value.contains("."):
		value += "."
	value = value.rpad(6,"0")
	return value

# Build and sort the metrics list
func build_list() -> void:
	for i: int in Globals.metrics.size():
		if Globals.metrics[i] > 0:
			metrics.append(Globals.metrics[i])
			opcodes.append(i)
			pattern.append(patterns[i])

	var switch: bool = true
	var count: int = 0
	
	while switch:
		switch = false

		for i: int in (metrics.size() - 1) - count:
			if metrics[i] < metrics[i + 1]:
				switch_values(i)
				switch = true
			elif metrics[i] == metrics[i + 1] and opcodes[i] > opcodes[i + 1]:
				switch_values(i)

		count =+ 1 


func switch_values(i: int) -> void:
	var tmpInt: int = 0
	var tmpStr: String = ""

	tmpInt = metrics[i]
	metrics[i] = metrics[i + 1]
	metrics[i + 1] = tmpInt
				
	tmpInt = opcodes[i]
	opcodes[i] = opcodes[i + 1]
	opcodes[i + 1] = tmpInt
				
	tmpStr = pattern[i]
	pattern[i] = pattern[i + 1]
	pattern[i + 1] = tmpStr


func display_metrics() -> void:
		text = "Viro - Metrics Viewer - Op Code Access. \n\n"
		if not Globals.file_name.is_empty():
			text += "Program File: " + Globals.file_name + "\n\n"
		else:
			text += "Program File: Untitled\n\n"
		text += "Op Code:   Percent:    Instruction:\n\n"

		# Construct the metrics list
		build_list()

		# Work out what a percent is
		var percent: float = 0.0
		for i: int in Globals.metrics.size():
			percent += Globals.metrics[i]
		var total_instructions_called: int = percent
		percent /= 100

		# Display the table
		var total: float = 0
		for i: int in metrics.size():
			total += metrics[i] / percent
			text += " " + str(opcodes[i]).lpad(2,"0") + "\t\t\t"
			text += get_float_digits(i, percent)  + "\t\t"
			text += pattern[i].replacen(","," ") + "\t"
			text += "\n"

		text += "\n\t Total: " + Tools.num_to_str(total) + "\t\t\tTotal Engine Calls: " + str(total_instructions_called) + "\n"
		text += "\nTable only shows the number of times an op code was accessed\n"
		text += "not whether or if the branch / comparison was true or false."

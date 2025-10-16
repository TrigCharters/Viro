extends Node

class_name MathsSystem

var data_stack: Array[float] = Globals.data_stack
var memory: Array[float] = Globals.memory

#--------------------------------------------------
# Maths Sub System
#--------------------------------------------------
func process_call(callType: int) -> void:
	match callType:
		0: # Distance To
			if data_stack.size() != 4: return
			memory[1] = Vector2(data_stack[0], data_stack[1]).distance_to(Vector2(data_stack[2], data_stack[3]))
		1:	# Rotate
			if data_stack.size() != 4: return
			memory[1] = rad_to_deg(Vector2(data_stack[0], data_stack[1]).angle_to_point(Vector2(data_stack[2],	 data_stack[3])))
		2: # Sphere collider
			if data_stack.size() != 6: return
			var dist: float = Vector2(data_stack[0],data_stack[1]).distance_to(Vector2(data_stack[3], data_stack[4]))
			var rad: float = data_stack[2] + data_stack[5]
			memory[1] = 1
			if rad > dist: memory[1] = 0
		3: # Distance Collider
			if data_stack.size() != 5: return
			memory[1] = 1
			if Vector2(data_stack[0], data_stack[1]).distance_to(Vector2(data_stack[2], data_stack[3])) <= data_stack[4]: memory[1] = 0

extends Node

class_name MemoryBlockSystem

var data_stack: Array[float] = Globals.data_stack
var memory: Array[float] = Globals.memory
var memory_blocks: Array[Dictionary] = Globals.memory_blocks

#--------------------------------------------------
# Memory Block Sub System
#--------------------------------------------------
func process_call(callType: int) -> void:
	# Check for correct data stack lengths
	if data_stack.size() != 1: return

	var mb_data: Array[float] = []
	var mb_length: int = 0
	mb_length = mb_get_size(data_stack[0])
	if mb_length == -1: return

	# For all those mb function types which need to get the mb data
	if callType in [0,2,3,4,5,13]:
		for i:int in mb_length:
			mb_data.append(memory[data_stack[0] + i])

	# Different functions
	match callType:
		0: # Sort
			mb_data.sort()
		
		1: # Length
			memory[1] = mb_length
		
		2: # Get Smallest
			memory[1] = mb_data.min()
		
		3: # Get Largest
			memory[1] = mb_data.max()
		
		4: # Has
			if mb_data.has(memory[1]): memory[1] = 0
			else: memory[1] = 1
		
		5: # Count
			memory[1] = mb_data.count(memory[1])
		
		6: # Sum
			var mb_total: float = 0
			for i: int in mb_length:
				mb_total += memory[data_stack[0]+i]
			memory[1] = mb_total
		
		7: # Get Random
			memory[1] = memory[data_stack[0] + randi_range(0, mb_length-1)]
		
		8: # Fill
			for i:int in mb_length:
				memory[data_stack[0] + i] = memory[1]
		
		9: # Copy
			if mb_get_size(memory[1]) != mb_length: return
			if memory[1] == data_stack[0]: return
			for i:int in mb_length:
				memory[data_stack[0] + i] = memory[memory[1] + i]
		
		10, 11: # Read / Write
			var mb_id: int = mb_get_id(data_stack[0])
			if callType == 10: 
				memory[1] = memory[data_stack[0] + memory_blocks[mb_id].pointer]
			else: 
				memory[data_stack[0] + memory_blocks[mb_id].pointer] = memory[1]
			memory_blocks[mb_id].pointer += 1
			if memory_blocks[mb_id].pointer >= mb_length: memory_blocks[mb_id].pointer = 0
		
		12: # Reset pointer
			var mb_id: int = mb_get_id(data_stack[0])
			memory_blocks[mb_id].pointer = 0
		
		13: # Shuffle
			mb_data.shuffle()

	# Which Actions need to put the data back
	if callType in [0,13]:
		for i:int in mb_length:
			memory[data_stack[0] + i] = mb_data[i]


func mb_get_size(address: int) -> int:
	for i: int in memory_blocks.size():
		if memory_blocks[i].address == address:
			return memory_blocks[i].length
	return -1


func mb_get_id(address: int) -> int:
	for i: int in memory_blocks.size():
		if memory_blocks[i].address == address:
			return i
	return -1

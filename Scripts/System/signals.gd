extends Node

#---------------------------------------------------
# This is where all global signals are defined.
#---------------------------------------------------

# System
signal throw_system_error(pc: int, msg: String, address: int, simple: bool)
signal store_pc
signal terminate
signal dialogconfirmed
signal dialogconfirmedwithvalue(data: String)
signal dialogcancelled 

# Screen
signal screen_refresh
signal resolution_mode_changed(mode: int)
signal resolution_changed

# Registers
signal colors_changed

# Text System
signal text_reset_cursor

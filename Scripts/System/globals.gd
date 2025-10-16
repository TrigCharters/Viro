extends Node

# BSOD
@onready var bsod: String = ""

# Code Editor
@onready var editor_caret_line: int = 0
@onready var editor_caret_column: int = 0
@onready var editor_scroll_value: int = 0
@onready var editor_use_reduced_line_spacing: bool = true
@onready var editor_use_line_numbers: bool = true
@onready var editor_pad_line_numbers: bool = true
@onready var editor_enable_wrapping: bool = true
@onready var source_code: String = ""
@onready var source_changed: bool = false

# Compiler 
@onready var compile_and_run: bool = false
@onready var default_memory: int = 1024
@onready var game_title: String = ""
@onready var user_memory_lower_bounds: int = 100

# Engine (CORE)
@onready var execution_stack: Array[int] = []
@onready var data_stack: Array[float] = []
@onready var ignore_local: bool = false
@onready var ignore_mouse: bool = false
@onready var ignore_keyboard: bool = false
@onready var useGraphicsRegionTranslation: bool = false
@onready var memory: Array[float] = []
@onready var memory_bitmask: PackedByteArray = []
@onready var memory_blocks: Array[Dictionary] = []
@onready var one_percent_performance: float = 300
@onready var resources: Array[Dictionary] = []
@onready var stack: Array[float] = []
@onready var frames: Array[float] = [] # Register backup

# Engine Debug
@onready var debug_pane_display_mode: int = 0
@onready var metrics: Array[int] = []
@onready var debug_pane_visible: bool = false
@onready var debug_pane_update_frequency: int = 30

# Font Editor
@onready var font_active_char: int = 0

#Graphics
@onready var graphics_buffer: Array[Image] = []
@onready var colors: Array[Color] = []

# System
@onready var build_date: String = ""
@onready var build_year: String = "2025"
@onready var build_type: String = "Release"
@onready var db_load_error: bool = false
@onready var debug_mode: bool = true
@onready var file_name: String = ""
@onready var initial_open: bool = true
@onready var return_from_compiler_to: String = ""
@onready var return_from_runtime_to: String = ""
@onready var sub_path: String = ""
@onready var sys_name: String = "Viro"
@onready var time_zone: int = 0
@onready var version: String = "1.2"
@onready var work_path: String = "user://"
@onready var max_resolution_x: int = 640
@onready var max_resolution_y: int = 480
@onready var min_resolution_x: int = 320
@onready var min_resolution_y: int = 240
@onready var letter_box_mode: bool = true

# Terminal
@onready var flag_autoedit: bool = true
@onready var flag_autosave: bool = true
@onready var flag_metrics: bool = true
@onready var flag_autoload: bool = false
@onready var flag_autorun: bool = false
@onready var flag_fullscreen: bool = false
@onready var flag_editorFullScreen: bool = false
@onready var flag_savePrompt: bool = true
@onready var last_command: String = ""
@onready var max_codepointer: int = 0
@onready var password_hash: String = ""
@onready var source_locked: bool = false
@onready var terminal_history: String = ""

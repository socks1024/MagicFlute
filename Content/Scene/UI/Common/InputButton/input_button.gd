class_name InputButton extends CommonButton

@export var initial_text: String
@export var waiting_text: String
@export var catch_mouse_move: bool = false
@export_range(0,1,0.01) var joypad_motion_deadzone:float = 0.5
@export_range(10,1000,1) var mouse_motion_deadzone:float = 10

signal input_catched(event: InputEvent)

var _catching_input: bool = false

func _ready() -> void:
	super._ready()
	button_anim_finish.connect(_start_catch_input)
	text = initial_text

func _input(event: InputEvent) -> void:
	if _catching_input && event:
		# 此处应有死区判定
		if event is InputEventJoypadMotion && abs(event.axis_value) < joypad_motion_deadzone: return
		if event is InputEventMouseMotion && (!catch_mouse_move || (event as InputEventMouseMotion).velocity.length() > mouse_motion_deadzone): return
		_catching_input = false
		text = InputUtils.get_text(event)
		input_catched.emit(event)

func _start_catch_input() -> void:
	_catching_input = true
	text = waiting_text

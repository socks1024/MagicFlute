extends ConfigControl

@export var default_check:bool = false

@onready var common_check_button: CheckButton = $CommonCheckButton

func get_default_value() -> Variant:
	return default_check

func set_control_editable(editable: bool) -> void:
	common_check_button.disabled = !editable

func set_control_value(value: Variant) -> void:
	common_check_button.button_pressed = value as bool

func connect_control_input() -> void:
	common_check_button.toggled.connect(_set_config_value)

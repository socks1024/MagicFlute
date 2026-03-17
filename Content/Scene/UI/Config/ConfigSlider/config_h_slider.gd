extends ConfigControl

@export var min_value:float = 0

@export var max_value:float = 1

@export var default_value:float = 0

@onready var common_h_slider: HSlider = $CommonHSlider

func _ready() -> void:
	common_h_slider.min_value = min_value
	common_h_slider.max_value = max_value
	super._ready()

func get_default_value() -> Variant:
	return clamp(default_value, min_value, max_value)

func set_control_editable(editable: bool) -> void:
	common_h_slider.editable = editable

func set_control_value(value: Variant) -> void:
	common_h_slider.value = value as float

func connect_control_input() -> void:
	common_h_slider.value_changed.connect(_set_config_value)

extends ConfigControl

@onready var common_option_button: OptionButton = $CommonOptionButton

func get_default_value() -> Variant:
	return 0

func set_control_editable(editable: bool) -> void:
	common_option_button.disabled = !editable

func set_control_value(value: Variant) -> void:
	common_option_button.selected = value as int

func connect_control_input() -> void:
	common_option_button.item_selected.connect(_set_config_value)

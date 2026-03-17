extends Control

@export var config_input_action: PackedScene
@export var button_count: int = 3
@export var auto_gen_buttons: bool = true

@onready var actions: VBoxContainer = $MarginContainer/ScrollContainer/Actions

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if auto_gen_buttons:
		for action_name: StringName in SettingsManager.get_action_names():
			var c: ConfigInputAction = config_input_action.instantiate()
			c.button_count = button_count
			c.action_description = action_name.capitalize()
			c.config_section = "Input"
			c.config_key = action_name
			actions.add_child(c)

class_name ConfigInputAction extends ConfigControl
## 将输入设置以 Dictionary[int,InputEvent] 的形式保存

@export var button_count: int = 3
@export var action_description: String = "Action"

const INPUT_BUTTON = preload("uid://mx5v06pw2aqd")

@onready var label: Label = $Label

var input_buttons: Array[InputButton]

func _ready() -> void:
	label.text = action_description
	for i in range(button_count):
		var n = INPUT_BUTTON.instantiate()
		add_child(n)
		input_buttons.append(n)
	super._ready()

func get_default_value() -> Variant:
	return SettingsManager.get_event_dic(config_key)

func set_control_value(value: Variant) -> void:
	if !value: return
	var d = value as Dictionary
	for i in range(button_count):
		var s:String = " "
		if d.size() > i:
			s = InputUtils.get_text(d[i])
		input_buttons[i].text = s

func set_control_editable(editable: bool) -> void:
	for b in input_buttons:
		b.disabled = !editable

func connect_control_input() -> void:
	for i in range(button_count):
		input_buttons[i].input_catched.connect(_set_input_action_value.bind(i))

func _set_input_action_value(event: InputEvent, idx: int) -> void:
	var events: Dictionary = _get_config_value()
	events[idx] = event
	_set_config_value(events)

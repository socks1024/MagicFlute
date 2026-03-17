@abstract class_name ConfigControl
extends Control
## 用于编辑配置的UI控件基类。具体的输入处理和控件更新逻辑应在子类中实现。

@export var config_section: String = ""
@export var config_key: String = ""

## 当配置更改时发出信号
signal config_changed(value)

func _ready() -> void:
	connect_control_input()
	set_control_value(_get_config_value())

func _set_config_value(value: Variant) -> void:
	ConfigUtils.save_setting(config_section, config_key, value)
	CLog.o("Config updated - Section:", config_section, "Key:", config_key, "Value:", value)
	config_changed.emit(value)

func _get_config_value() -> Variant:
	return ConfigUtils.load_setting(config_section, config_key, get_default_value())

## 获取默认值
@abstract func get_default_value() -> Variant;


## 更新控件的值
@abstract func set_control_value(value: Variant) -> void;


## 设置控件是否可编辑
@abstract func set_control_editable(editable: bool) -> void;


## 绑定控件输入信号以更新配置
@abstract func connect_control_input() -> void;

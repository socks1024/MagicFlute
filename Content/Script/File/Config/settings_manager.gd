# Generated Class Name SettingsManager
extends Node

func _ready() -> void:
	_load_audio_config()
	_load_input_config()
	_load_video_config()
	_load_game_config()

func reset_all_settings() -> void:
	ConfigUtils.erase_config()
	_reset_audio_config()
	_reset_input_config()
	_reset_video_config()
	_reset_game_config()

#region Audio

func _load_audio_config() -> void:
	for bus_index in AudioServer.get_bus_count():
		var bus_name = AudioServer.get_bus_name(bus_index)
		if ConfigUtils.has_section_key("Audio", bus_name + "Volume"):
			var volume_db = ConfigUtils.load_setting("Audio", bus_name + "Volume", 0.0)
			set_bus_volume_db(bus_name, volume_db)

func _reset_audio_config() -> void:
	for bus_index in AudioServer.get_bus_count():
		var bus_name = AudioServer.get_bus_name(bus_index)
		set_bus_volume_db(bus_name, 0.0)

## 获取总线音量
func get_bus_volume_db(bus_name: String) -> float:
	var bus_index = AudioServer.get_bus_index(bus_name)
	return AudioServer.get_bus_volume_db(bus_index)

## 设定总线音量
func set_bus_volume_db(bus_name: String, volume_db: float) -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(bus_index, volume_db)

## 设定总线静音
func mute_bus(bus_name: String, mute: bool) -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(bus_index, mute)

#endregion

#region Input

var _default_actions:Dictionary

func _load_input_config() -> void:
	for action_name in get_action_names():
		_default_actions.set(action_name, InputMap.action_get_events(action_name))
	
	for action_name in get_action_names():
		if ConfigUtils.has_section_key("Input",action_name):
			var events = ConfigUtils.load_setting("Input", action_name, null)
			set_input_events(action_name, events.values())

func _reset_input_config() -> void:
	for action_name in get_action_names():
		var events = _default_actions[action_name]
		set_input_events(action_name, events)

## 获取所有 InputAction 的名称
func get_action_names() -> Array:
	var actions = InputMap.get_actions()
	actions = actions.filter(InputUtils.not_internal_ui_action)
	return actions

## 根据已加载的输入配置生成输入配置字典
func get_event_dic(action_name: String) -> Dictionary:
	var d: Dictionary
	var es: Array = InputMap.action_get_events(action_name)
	for i in range(es.size()):
		d[i] = es[i]
	return d

## 设定指定输入动作的事件列表
func set_input_events(action_name: String, events: Array) -> void:
	InputMap.action_erase_events(action_name)
	for event in events:
		InputMap.action_add_event(action_name, event)

#endregion

#region Video

func _load_video_config() -> void:
	var b = ConfigUtils.load_setting("Video","Fullscreen",false)
	toggle_full_screen(b)

func _reset_video_config() -> void:
	toggle_full_screen(false)

## 切换全屏
func toggle_full_screen(value: bool) -> void:
	if value: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

#endregion

#region Game

func _load_game_config() -> void:
	var lang:LocalizationUtils.Lang = ConfigUtils.load_setting("Game","Language", LocalizationUtils.get_default_lang())
	set_locale_by_lang(lang)

func _reset_game_config() -> void:
	TranslationServer.set_locale(OS.get_locale())

## 根据本地化枚举设置地区
func set_locale_by_lang(lang:LocalizationUtils.Lang) -> void:
	var locale_lang = LocalizationUtils.get_locale_by_lang(lang)
	TranslationServer.set_locale(locale_lang)

#endregion

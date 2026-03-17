class_name ConfigUtils

const CONFIG_PATH = "user://config.cfg"

static var _config:ConfigFile = null
static var config:ConfigFile = null:
	get:
		if _config == null: 
			var cf:ConfigFile = ConfigFile.new()
			var load_err:Error = cf.load(CONFIG_PATH)
			if load_err:
				CLog.o("No config found, creating new config file...")
				_config = ConfigFile.new()
				_save_config()
			else:
				_config = cf
			CLog.o("Config File loaded, last save time:", "UTC", Time.get_datetime_string_from_unix_time(_config.get_value("Meta", "SaveTime", "???"), true))
		return _config

static func _save_config() -> void:
	config.set_value("Meta", "SaveTime", Time.get_unix_time_from_system())
	var save_error : int = config.save(CONFIG_PATH)
	if save_error:
		CLog.e("failed to save config with error code:", save_error)

## 将设置保存到配置文件中
static func save_setting(section: String, key: String, default = null) -> void:
	config.set_value(section, key, default)
	_save_config()

## 从配置文件中加载设置，如果没有找到则返回默认值
static func load_setting(section: String, key: String, default = null) -> Variant:
	return config.get_value(section, key, default)

## 是否存在某个设置类别
static func has_section(section: String) -> bool:
	return config.has_section(section)

## 是否存在某个设置项
static func has_section_key(section: String, key: String) -> bool:
	return config.has_section_key(section, key)

## 删除设置文件
static func erase_config() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		var err:Error = DirAccess.remove_absolute(CONFIG_PATH)
		if err:
			CLog.e("Failed to erase config file with error code:", err)
		else:
			config = null
			CLog.o("Config file erased successfully.")
	else:
		CLog.o("No config file to erase.")

## 删除整个设置类别
static func erase_section(section: String) -> void:
	if has_section(section):
		config.erase_section(section)
		_save_config()

## 删除某个设置项
static func erase_section_key(section: String, key: String) -> void:
	if has_section_key(section, key):
		config.erase_section_key(section, key)
		_save_config()

## 获取某个设置类别下的所有设置项
static func get_keys_by_section(section: String) -> PackedStringArray:
	if config.has_section(section):
		return config.get_section_keys(section)
	return PackedStringArray()

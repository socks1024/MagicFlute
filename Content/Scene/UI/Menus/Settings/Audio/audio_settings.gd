extends Control

func _on_master_volume_changed(value: Variant) -> void:
	SettingsManager.set_bus_volume_db("Master", value)

func _on_music_volume_changed(value: Variant) -> void:
	SettingsManager.set_bus_volume_db("Music", value)

func _on_sfx_volume_changed(value: Variant) -> void:
	SettingsManager.set_bus_volume_db("SFX", value)

func _on_ui_volume_changed(value: Variant) -> void:
	SettingsManager.set_bus_volume_db("UI", value)

func _on_voice_volume_changed(value: Variant) -> void:
	SettingsManager.set_bus_volume_db("Voice", value)

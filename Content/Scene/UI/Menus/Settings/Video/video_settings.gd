extends Control


func _on_fullscreen_changed(value: Variant) -> void:
	SettingsManager.toggle_full_screen(value)

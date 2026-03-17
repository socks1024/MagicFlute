extends Control

signal back_clicked

func _on_back_button_anim_finish() -> void:
	back_clicked.emit()


func _on_reset_all_button_anim_finish() -> void:
	SettingsManager.reset_all_settings()
	for c in find_children("*","ConfigControl",true,false):
		c.set_control_value(c.get_default_value())

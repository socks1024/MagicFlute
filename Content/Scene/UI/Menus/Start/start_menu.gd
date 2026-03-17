extends Control

signal new_game_clicked
signal continue_clicked
signal settings_clicked
signal credits_clicked
signal exit_clicked


func _on_new_game_button_anim_finish() -> void:
	new_game_clicked.emit()


func _on_continue_button_anim_finish() -> void:
	continue_clicked.emit()


func _on_settings_button_anim_finish() -> void:
	settings_clicked.emit()


func _on_credits_button_anim_finish() -> void:
	credits_clicked.emit()


func _on_exit_button_anim_finish() -> void:
	exit_clicked.emit()

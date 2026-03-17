extends Control

signal back_clicked


func _on_back_button_anim_finish() -> void:
	back_clicked.emit()

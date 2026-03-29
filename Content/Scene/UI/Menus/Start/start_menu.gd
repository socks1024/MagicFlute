extends Control

signal new_game_clicked
signal continue_clicked
signal settings_clicked
signal credits_clicked
signal exit_clicked

@export var curtain_duration: float = 2.0

@onready var texture_button: CommonTextureButton = $StartCurtain/Car/TextureButton
@onready var curtain: TextureRect = $StartCurtain/Curtain
@onready var animated_sprite_2d: AnimatedSprite2D = $StartCurtain/Car/AnimatedSprite2D


func _ready() -> void:
	animated_sprite_2d.play("default")	


func _on_new_game_button_anim_finish() -> void:
	animated_sprite_2d.play("open")
	texture_button.hide()

	var mat: ShaderMaterial = curtain.material as ShaderMaterial
	mat.set_shader_parameter("progress", 0.0)
	var tween: Tween = create_tween()
	tween.tween_method(
		func(value: float) -> void: mat.set_shader_parameter("progress", value),
		0.0,
		1.0,
		curtain_duration
	)
	tween.finished.connect(func():
		texture_button.show()
		animated_sprite_2d.play("default")
		mat.set_shader_parameter("progress", 0.0)
		new_game_clicked.emit()
		)


func _on_continue_button_anim_finish() -> void:
	continue_clicked.emit()


func _on_settings_button_anim_finish() -> void:
	settings_clicked.emit()


func _on_credits_button_anim_finish() -> void:
	credits_clicked.emit()


func _on_exit_button_anim_finish() -> void:
	exit_clicked.emit()

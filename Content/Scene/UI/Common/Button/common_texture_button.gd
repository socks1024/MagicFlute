class_name CommonTextureButton extends TextureButton

signal button_anim_finish

@export var duration: float
@export var ease_curve: Curve
@export var press_sound: AudioEvent

var _tween: Tween

func _ready() -> void:
	ease_curve.bake()
	pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	if _tween and _tween.is_running():
		return
	AudioManager.play_sound(press_sound)
	scale = Vector2.ONE
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ZERO, duration).set_custom_interpolator(TweenUtils.curve_interpolator(ease_curve))
	_tween.finished.connect(
		func():
		button_anim_finish.emit()
		_tween.kill()
		)

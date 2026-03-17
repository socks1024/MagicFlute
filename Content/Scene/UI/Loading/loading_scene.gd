extends LoadControl

@onready var progress_bar: ProgressBar = $Panel/ProgressBar

func _init_progress_control() -> void:
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.value = progress_bar.min_value

func _update_progress_control(value:float) -> void:
	progress_bar.value = value

func _free_progress_control() -> void:
	queue_free()

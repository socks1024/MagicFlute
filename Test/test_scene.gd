extends Node2D

const BGM_LOADING = preload("uid://ck3n662l1ecri")
const BGM_SLOW_TRAVEL = preload("uid://hq8cgr0bpkxv")

@export var load_time:float = 30

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	CLog.o("ready")
	AudioManager.play_music(BGM_LOADING, "BGM", 5.0)
	get_tree().create_timer(load_time).timeout.connect(_on_switch_music.bind(BGM_SLOW_TRAVEL))

func _on_switch_music(res) -> void:
	CLog.o("switch music")
	if res && res is AudioEvent:
		AudioManager.play_music(res, "BGM", 5.0)

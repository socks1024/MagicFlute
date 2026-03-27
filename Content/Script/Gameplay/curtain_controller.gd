extends Node2D
## 幕布动画控制器：游戏开始时播放开幕动画，播完后循环播放幕布飘动动画。

# ── 内部引用 ─────────────────────────────────────────
@onready var _curtain_open: AnimatedSprite2D = $CurtainOpen
@onready var _curtain_move: AnimatedSprite2D = $CurtainMove

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	_curtain_open.animation_finished.connect(_on_open_finished)
	# 初始状态：显示开幕，隐藏飘动
	_curtain_open.visible = true
	_curtain_move.visible = false
	_curtain_open.play("default")

# ── 信号回调 ─────────────────────────────────────────

func _on_open_finished() -> void:
	_curtain_open.visible = false
	_curtain_move.visible = true
	_curtain_move.play("default")

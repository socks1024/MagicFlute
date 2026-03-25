class_name SpawnWarning
extends Node2D
## 出怪预警提示：在指定位置显示闪烁警示
##
## 由 EnemySpawner 在出怪前生成，仅负责视觉闪烁效果。
## 生命周期由 EnemySpawner 通过 finish() 方法控制，
## 确保预警时间与节拍同步（lane 模式下自动暂停）。

# ── 信号 ──────────────────────────────────────────────
## 预警结束时发出（由 finish() 触发，EnemySpawner 监听此信号来实际生成敌人）
signal warning_finished

# ── 导出属性 ─────────────────────────────────────────
## 闪烁周期（秒），一次完整的亮→暗→亮
@export var blink_period: float = 0.3
## 闪烁时的最低透明度
@export_range(0.0, 1.0) var blink_min_alpha: float = 0.2
## 闪烁时的最高透明度
@export_range(0.0, 1.0) var blink_max_alpha: float = 0.8

# ── 内部变量 ─────────────────────────────────────────
## 闪烁 Tween 引用
var _blink_tween: Tween

# ── @onready 引用 ────────────────────────────────────
@onready var _sprite: Sprite2D = $Sprite2D

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	_start_blink()


## 由 EnemySpawner 调用：结束预警，发出信号并销毁自身
func finish() -> void:
	warning_finished.emit()
	if _blink_tween != null:
		_blink_tween.kill()
	queue_free()

# ── 内部方法 ─────────────────────────────────────────

## 启动循环闪烁 Tween
func _start_blink() -> void:
	if _sprite == null:
		return
	_sprite.modulate.a = blink_max_alpha
	_blink_tween = create_tween().set_loops()
	var half_period: float = blink_period * 0.5
	_blink_tween.tween_property(_sprite, "modulate:a", blink_min_alpha, half_period)
	_blink_tween.tween_property(_sprite, "modulate:a", blink_max_alpha, half_period)

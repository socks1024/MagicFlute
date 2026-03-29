extends Node2D
## Boss Joker 控制脚本，管理下属节点的动画播放

## 触发头部 spawn_enemy 动画的网格位置列表（在编辑器中配置）
@export var spawn_anim_positions: Array[Vector2i] = []

@onready var head: AnimatedSprite2D = $JokerHead
@onready var left_hand: AnimatedSprite2D = $JokerLeftHand
@onready var right_hand: AnimatedSprite2D = $JokerRightHand
@onready var body: AnimatedSprite2D = $JokerBody
@onready var _enemy_spawner: EnemySpawner = %EnemySpawner


func _ready() -> void:
	head.play()
	left_hand.play()
	right_hand.play()
	body.play()
	# 连接敌人生成信号
	if _enemy_spawner != null:
		_enemy_spawner.enemy_spawned.connect(_on_enemy_spawned)
	# 头部 spawn_enemy 动画播完后回到默认动画
	head.animation_finished.connect(_on_head_animation_finished)


## 敌人生成时检查是否在触发位置，是则播放 spawn_enemy 动画
func _on_enemy_spawned(grid_pos: Vector2i, _enemy: Enemy) -> void:
	if grid_pos in spawn_anim_positions:
		head.play(&"spawn_enemy")


## 头部动画播放完毕后回到默认动画
func _on_head_animation_finished() -> void:
	if head.animation == &"spawn_enemy":
		head.play(&"default")

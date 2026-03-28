extends Node2D
## Boss Joker 控制脚本，管理下属节点的动画播放

@onready var head: AnimatedSprite2D = $JokerHead
@onready var left_hand: AnimatedSprite2D = $JokerLeftHand
@onready var right_hand: AnimatedSprite2D = $JokerRightHand


func _ready() -> void:
	head.play()
	left_hand.play()
	right_hand.play()

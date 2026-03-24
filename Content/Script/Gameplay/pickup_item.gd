class_name PickupItem
extends Area2D
## 拾取物：放置在网格上，玩家踩上去即可拾取
##
## 通过 body_entered 检测玩家碰撞，拾取后发出信号并自动销毁。

# ── 信号 ──────────────────────────────────────────────
## 被拾取时发出，携带拾取物自身引用
signal picked_up(item: PickupItem)

# ── 导出属性 ─────────────────────────────────────────

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	# 连接碰撞信号
	body_entered.connect(_on_body_entered)


## 碰撞回调：仅响应 RhythmPlayer
func _on_body_entered(body: Node2D) -> void:
	if body is RhythmPlayer:
		picked_up.emit(self)
		queue_free()

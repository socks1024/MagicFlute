extends Enemy

## 收到移动节拍信号：向右移动一格（lane 模式时 Conductor 不会发出此信号）
func _on_move_beat_tick(_beat_index: int) -> void:
	_move(Vector2i.RIGHT)

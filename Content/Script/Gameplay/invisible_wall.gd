@tool
class_name InvisibleWall
extends GridEntity2D
## 空气墙：不可见的阻挡实体
##
## 放置在网格上后，通过 block_mask 机制阻挡其他实体移动。
## 编辑器中显示为带叉号的半透明方框，运行时不可见。

## 绘制尺寸（像素），应与 GridSystem2D 的格子尺寸一致
@export var draw_size: Vector2 = Vector2(100, 100)

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var half: Vector2 = draw_size * 0.5
	var rect: Rect2 = Rect2(-half, draw_size)
	var color: Color = Color(1.0, 0.3, 0.3, 0.35)
	var line_color: Color = Color(1.0, 0.2, 0.2, 0.7)
	# 半透明填充
	draw_rect(rect, color, true)
	# 边框
	draw_rect(rect, line_color, false, 2.0)
	# 叉号
	draw_line(-half, half, line_color, 2.0)
	draw_line(Vector2(-half.x, half.y), Vector2(half.x, -half.y), line_color, 2.0)

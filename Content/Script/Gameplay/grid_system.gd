class_name GridSystem
extends Resource
## 统一网格系统：定义网格尺寸、边界，提供坐标转换工具方法
##
## 作为 Resource 供玩家、拾取物生成器等多个系统共用，
## 确保所有网格相关的逻辑使用同一套参数。

# ── 网格参数 ─────────────────────────────────────────
## 每个格子的像素大小
@export var cell_size: float = 100.0
## 网格列数（水平方向格子数量）
@export var columns: int = 32
## 网格行数（垂直方向格子数量）
@export var rows: int = 18
## 网格原点在世界坐标中的偏移（左上角位置）
@export var origin: Vector2 = Vector2.ZERO

# ── 边界查询 ─────────────────────────────────────────

## 网格覆盖的世界矩形区域
func get_world_rect() -> Rect2:
	return Rect2(origin, Vector2(columns * cell_size, rows * cell_size))

## 网格最大列索引（0 ~ columns-1）
func max_col() -> int:
	return columns - 1

## 网格最大行索引（0 ~ rows-1）
func max_row() -> int:
	return rows - 1

# ── 坐标转换 ─────────────────────────────────────────

## 网格坐标 → 世界坐标（返回格子中心位置）
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return origin + Vector2(grid_pos.x * cell_size + cell_size * 0.5,
							grid_pos.y * cell_size + cell_size * 0.5)

## 世界坐标 → 网格坐标（四舍五入到最近的格子）
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = world_pos - origin
	var gx: int = int(roundf(local.x / cell_size - 0.5))
	var gy: int = int(roundf(local.y / cell_size - 0.5))
	return Vector2i(clampi(gx, 0, max_col()), clampi(gy, 0, max_row()))

# ── 边界钳制 ─────────────────────────────────────────

## 将网格坐标钳制到合法范围内
func clamp_grid(grid_pos: Vector2i) -> Vector2i:
	return Vector2i(clampi(grid_pos.x, 0, max_col()), clampi(grid_pos.y, 0, max_row()))

## 判断网格坐标是否在合法范围内
func is_in_bounds(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x <= max_col() and grid_pos.y >= 0 and grid_pos.y <= max_row()

# ── 随机位置 ─────────────────────────────────────────

## 获取一个不与已占用位置重叠的随机网格坐标
func get_random_grid_pos(occupied: Array[Vector2i] = []) -> Vector2i:
	# 最多尝试 50 次避免死循环
	for attempt: int in range(50):
		var gx: int = randi_range(0, max_col())
		var gy: int = randi_range(0, max_row())
		var candidate: Vector2i = Vector2i(gx, gy)
		if candidate not in occupied:
			return candidate
	# 兜底：返回第一个未被占用的位置
	for x: int in range(columns):
		for y: int in range(rows):
			var pos: Vector2i = Vector2i(x, y)
			if pos not in occupied:
				return pos
	return Vector2i.ZERO

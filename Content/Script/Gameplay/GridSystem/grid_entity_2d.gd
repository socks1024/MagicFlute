class_name GridEntity2D
extends Node2D
## 网格实体基类：所有放置在网格上的物体的统一基类
##
## 定义实体在网格中的数据（如占据尺寸）和简单行为。
## 子类只需配置 cell_size 即可支持多格占用。

# ── 导出属性 ─────────────────────────────────────────
## 实体在网格上占据的尺寸（以格子为单位，默认 1×1）
@export var cell_size: Vector2i = Vector2i(1, 1)

# ── 公开方法 ─────────────────────────────────────────

## 获取实体占据的所有网格坐标（基于锚点格子向右下扩展）
## anchor: 实体的锚点网格坐标（左上角格子）
func get_occupied_cells(anchor: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x: int in range(cell_size.x):
		for y: int in range(cell_size.y):
			cells.append(anchor + Vector2i(x, y))
	return cells

## 获取实体占据的格子数量
func get_cell_count() -> int:
	return cell_size.x * cell_size.y

## 是否为单格实体（1×1）
func is_single_cell() -> bool:
	return cell_size == Vector2i(1, 1)

# ── 虚方法（子类可覆写） ─────────────────────────────

## 实体被放置到网格时由 GridSystem2D 调用
## 子类可覆写此方法以执行放置相关的逻辑
func _on_placed(_grid_pos: Vector2i) -> void:
	pass

## 实体注册完成后由 GridSystem2D 调用（owner 已修正，可安全使用 % 唯一名称）
## 子类可覆写此方法以获取外部节点引用、连接信号等
func _entity_ready() -> void:
	pass

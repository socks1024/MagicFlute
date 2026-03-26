class_name GridEntity2D
extends Node2D
## 网格实体基类：所有放置在网格上的物体的统一基类
##
## 定义实体在网格中的数据（如占据尺寸）和简单行为。
## 子类只需配置 cell_size 即可支持多格占用。

# ── 导出属性 ─────────────────────────────────────────
## 实体在网格上占据的尺寸（以格子为单位，默认 1×1）
@export var cell_size: Vector2i = Vector2i(1, 1)

# ── 网格层常量 ───────────────────────────────────────
## 网格层位定义（与 @export_flags 中的顺序一一对应）
const LAYER_PLAYER: int = 1    ## bit 0 - 玩家
const LAYER_ENEMY: int = 2     ## bit 1 - 敌人
const LAYER_PICKUP: int = 4    ## bit 2 - 拾取物
const LAYER_WALL: int = 8      ## bit 3 - 空气墙

# ── 网格层属性 ───────────────────────────────────────
## 实体所在的网格层（位掩码，表示"我在哪些层"）
@export_flags("Player", "Enemy", "Pickup", "Wall") var grid_layer: int = 0
## 实体的阻挡掩码（位掩码，表示"哪些层会阻挡我的移动"）
@export_flags("Player", "Enemy", "Pickup", "Wall") var block_mask: int = 0
## 实体的重叠掩码（位掩码，表示"哪些层会与我触发重叠回调"）
@export_flags("Player", "Enemy", "Pickup", "Wall") var overlap_mask: int = 0

# ── 内部变量 ─────────────────────────────────────────
## 所属网格系统引用（由 GridSystem2D.place_entity 自动注入，勿手动赋值）
var _grid_system: GridSystem2D

# ── 公开方法 ─────────────────────────────────────────

## 从网格系统中移除自身并释放节点（所有主动销毁路径的统一入口）
func remove_and_free() -> void:
	if _grid_system != null:
		_grid_system.remove_entity(self)
	queue_free()

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

## 实体从网格中移除时由 GridSystem2D 调用（数据已清除，节点仍存活）
## 子类可覆写此方法以执行移除相关的逻辑（如断开信号、清理状态等）
func _on_removed(_grid_pos: Vector2i) -> void:
	pass

## 移动被阻挡时由 GridSystem2D 调用
## 子类可覆写此方法以处理被阻挡后的行为（如销毁、反弹等）
func _on_blocked(_blocker: GridEntity2D) -> void:
	pass

## 与其他实体重叠时由 GridSystem2D 调用
## 子类可覆写此方法以处理重叠后的行为（如拾取、伤害等）
func _on_overlap(_other: GridEntity2D) -> void:
	pass

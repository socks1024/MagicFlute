class_name GridSystem
extends Node2D
## 统一网格系统：管理空间中的无限网格，承载 Gameplay 信息
##
## 作为场景中的 Node2D 节点，以自身 position 为网格原点，
## 提供坐标转换、格子占用追踪等功能。网格无固定边界，可向任意方向延伸。
## 玩家、拾取物生成器等系统通过 NodePath 引用此节点。

# ── 信号 ──────────────────────────────────────────────
## 实体被放置到格子上时发出
signal entity_placed(grid_pos: Vector2i, entity: Node)
## 实体从格子上移除时发出
signal entity_removed(grid_pos: Vector2i, entity: Node)
## 实体在格子间移动时发出
signal entity_moved(from: Vector2i, to: Vector2i, entity: Node)

# ── 网格参数 ─────────────────────────────────────────
## 格子宽度（像素）
@export var cell_width: float = 100.0
## 格子高度（像素）
@export var cell_height: float = 100.0

# ── 内部变量 ─────────────────────────────────────────
## 格子占用字典：key = Vector2i（网格坐标），value = Node（占用该格子的实体）
var _cells: Dictionary = {}
## 地形层引用（Zone / 地形瓦片）
@onready var _zone_layer: TileMapLayer = $ZoneLayer
## 实体层引用（Scene Collection 场景瓦片）
@onready var _entity_layer: TileMapLayer = $EntityLayer

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	assert(_zone_layer != null, "GridSystem: 缺少子节点 ZoneLayer")
	assert(_entity_layer != null, "GridSystem: 缺少子节点 EntityLayer")
	# 延迟到首帧后扫描 EntityLayer，确保 Scene Collection 场景瓦片已实例化
	_register_entity_layer_children.call_deferred()
	CLog.o("GridSystem 就绪 | 格子=%dx%dpx  原点=%s" % [int(cell_width), int(cell_height), position])

# ── 坐标转换 ─────────────────────────────────────────

## 网格坐标 → 世界坐标（返回格子中心位置）
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return position + Vector2(grid_pos.x * cell_width + cell_width * 0.5,
							grid_pos.y * cell_height + cell_height * 0.5)

## 世界坐标 → 网格坐标（四舍五入到最近的格子）
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = world_pos - position
	var gx: int = int(roundf(local.x / cell_width - 0.5))
	var gy: int = int(roundf(local.y / cell_height - 0.5))
	return Vector2i(gx, gy)

# ── 占用追踪 ─────────────────────────────────────────

## 在指定格子放置实体（覆盖已有实体）
## 同时监听实体的 tree_exiting 信号，销毁时自动从占用中移除
func place_entity(grid_pos: Vector2i, entity: Node) -> void:
	_cells[grid_pos] = entity
	if not entity.tree_exiting.is_connected(_on_entity_tree_exiting):
		entity.tree_exiting.connect(_on_entity_tree_exiting.bind(entity))
	entity_placed.emit(grid_pos, entity)

## 移除指定格子上的实体
func remove_entity(grid_pos: Vector2i) -> void:
	if _cells.has(grid_pos):
		var entity: Node = _cells[grid_pos]
		_cells.erase(grid_pos)
		entity_removed.emit(grid_pos, entity)

## 移除指定实体（按实体查找并清除）
func remove_entity_by_ref(entity: Node) -> void:
	var pos: Vector2i = find_entity(entity)
	if pos != Vector2i(-1, -1):
		remove_entity(pos)

## 将实体从一个格子移动到另一个格子
func move_entity(from: Vector2i, to: Vector2i) -> void:
	if not _cells.has(from):
		return
	var entity: Node = _cells[from]
	_cells.erase(from)
	_cells[to] = entity
	entity_moved.emit(from, to, entity)

## 查询指定格子上的实体，无实体返回 null
func get_entity_at(grid_pos: Vector2i) -> Node:
	return _cells.get(grid_pos, null)

## 判断指定格子是否为空（无实体占用）
func is_cell_empty(grid_pos: Vector2i) -> bool:
	return not _cells.has(grid_pos)

## 查找指定实体所在的网格坐标，未找到返回 Vector2i(-1, -1)
func find_entity(entity: Node) -> Vector2i:
	for pos: Vector2i in _cells:
		if _cells[pos] == entity:
			return pos
	return Vector2i(-1, -1)

## 获取所有被占用的格子坐标
func get_occupied_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for pos: Vector2i in _cells:
		result.append(pos)
	return result

# ── 实体层扫描 ───────────────────────────────────────

## 扫描 EntityLayer 下所有由场景瓦片实例化的子节点，注册到占用追踪
func _register_entity_layer_children() -> void:
	for child: Node in _entity_layer.get_children():
		if child is Node2D and find_entity(child) == Vector2i(-1, -1):
			var node_2d: Node2D = child as Node2D
			var grid_pos: Vector2i = world_to_grid(node_2d.global_position)
			place_entity(grid_pos, node_2d)
			CLog.o("EntityLayer 注册: %s -> %s" % [node_2d.name, grid_pos])

## 实体即将离开场景树时，自动从占用字典中移除
func _on_entity_tree_exiting(entity: Node) -> void:
	var pos: Vector2i = find_entity(entity)
	if pos != Vector2i(-1, -1):
		_cells.erase(pos)
		entity_removed.emit(pos, entity)

# ── 瓦片层查询 ───────────────────────────────────────

## 获取指定格子的 TileData，无瓦片返回 null
func get_cell_data(grid_pos: Vector2i) -> TileData:
	return _zone_layer.get_cell_tile_data(grid_pos)

## 获取指定格子的 custom data 值，无瓦片或无该属性返回 default
func get_cell_custom_data(grid_pos: Vector2i, key: String, default: Variant = null) -> Variant:
	var tile_data: TileData = get_cell_data(grid_pos)
	if tile_data == null:
		return default
	return tile_data.get_custom_data(key)

## 判断格子是否存在（瓦片层中有画瓦片）
func has_cell(grid_pos: Vector2i) -> bool:
	return _zone_layer.get_cell_tile_data(grid_pos) != null

## 获取所有已绘制的格子坐标（即关卡的有效区域）
func get_all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for pos: Vector2i in _zone_layer.get_used_cells():
		cells.append(pos)
	return cells

# ── 随机位置 ─────────────────────────────────────────

## 在已绘制的格子中获取一个随机空格子坐标，无空格子返回 Vector2i(-1, -1)
## filter: 可选的过滤回调，签名 func(grid_pos: Vector2i) -> bool，返回 true 表示该格子可用
func get_random_empty_cell(filter: Callable = Callable()) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for pos: Vector2i in _zone_layer.get_used_cells():
		if _cells.has(pos):
			continue
		if filter.is_valid() and not filter.call(pos):
			continue
		candidates.append(pos)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[randi() % candidates.size()]

## 在已绘制的格子中获取一个不与已占用位置重叠的随机网格坐标
## filter: 可选的过滤回调，签名 func(grid_pos: Vector2i) -> bool，返回 true 表示该格子可用
func get_random_grid_pos(filter: Callable = Callable(), occupied: Array[Vector2i] = []) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for pos: Vector2i in _zone_layer.get_used_cells():
		if _cells.has(pos) or pos in occupied:
			continue
		if filter.is_valid() and not filter.call(pos):
			continue
		candidates.append(pos)
	if candidates.is_empty():
		return Vector2i.ZERO
	return candidates[randi() % candidates.size()]

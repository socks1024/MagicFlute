class_name GridSystem2D
extends Node2D
## 统一网格系统：管理空间中的无限网格，承载 Gameplay 信息
##
## 作为场景中的 Node2D 节点，以自身 position 为网格原点，
## 提供坐标转换、格子占用追踪等功能。网格无固定边界，可向任意方向延伸。
## 玩家、拾取物生成器等系统通过 NodePath 引用此节点。

# ── 信号 ──────────────────────────────────────────────
## 实体被放置到格子上时发出
signal entity_placed(grid_pos: Vector2i, entity: GridEntity2D)
## 实体从格子上移除时发出
signal entity_removed(grid_pos: Vector2i, entity: GridEntity2D)
## 实体在格子间移动时发出
signal entity_moved(from: Vector2i, to: Vector2i, entity: GridEntity2D)

# ── 网格参数 ─────────────────────────────────────────
## 格子宽度（像素）
@export var cell_width: float = 100.0
## 格子高度（像素）
@export var cell_height: float = 100.0

# ── 内部变量 ─────────────────────────────────────────
## 格子占用字典：key = Vector2i（网格坐标），value = Array[GridEntity2D]（占用该格子的实体列表）
var _cells: Dictionary = {}
## 地形层引用（Zone / 地形瓦片）
@onready var _zone_layer: TileMapLayer = $ZoneLayer
## 实体层引用（Scene Collection 场景瓦片）
@onready var _entity_layer: TileMapLayer = $EntityLayer

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	assert(_zone_layer != null, "GridSystem2D: 缺少子节点 ZoneLayer")
	assert(_entity_layer != null, "GridSystem2D: 缺少子节点 EntityLayer")
	# 延迟到首帧后扫描 EntityLayer，确保 Scene Collection 场景瓦片已实例化
	_register_entity_layer_children.call_deferred()
	CLog.o("GridSystem2D 就绪 | 格子=%dx%dpx  原点=%s" % [int(cell_width), int(cell_height), position])

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

## 在指定格子放置实体（追加到该格子的实体列表中）
## 同时监听实体的 tree_exiting 信号，销毁时自动从占用中移除
## 以 grid_pos 为锚点，根据实体的 cell_size 占用对应格子
func place_entity(grid_pos: Vector2i, entity: GridEntity2D) -> void:
	var positions: Array[Vector2i] = entity.get_occupied_cells(grid_pos)
	for pos: Vector2i in positions:
		if not _cells.has(pos):
			var arr: Array[GridEntity2D] = []
			_cells[pos] = arr
		(_cells[pos] as Array[GridEntity2D]).append(entity)
	if not entity.tree_exiting.is_connected(_on_entity_tree_exiting):
		entity.tree_exiting.connect(_on_entity_tree_exiting.bind(entity))
	entity._on_placed(grid_pos)
	entity_placed.emit(grid_pos, entity)

## 精确移除指定格子上的某个实体（若为多格实体，会一并清除所有占用格子）
func remove_entity(grid_pos: Vector2i, entity: GridEntity2D) -> void:
	if _cells.has(grid_pos):
		var arr: Array[GridEntity2D] = _cells[grid_pos] as Array[GridEntity2D]
		if entity in arr:
			_erase_all_cells_of(entity)
			entity_removed.emit(grid_pos, entity)

## 移除指定格子上的所有实体
func remove_all_entities(grid_pos: Vector2i) -> void:
	if _cells.has(grid_pos):
		var arr: Array[GridEntity2D] = (_cells[grid_pos] as Array[GridEntity2D]).duplicate()
		for entity: GridEntity2D in arr:
			_erase_all_cells_of(entity)
			entity_removed.emit(grid_pos, entity)

## 移除指定实体（按实体引用查找并清除所有占用格子）
func remove_entity_by_ref(entity: GridEntity2D) -> void:
	var pos: Vector2i = find_entity(entity)
	if pos != Vector2i(-1, -1):
		_erase_all_cells_of(entity)
		entity_removed.emit(pos, entity)

## 将指定实体移动到新的锚点格子（必须传入实体引用，支持多格实体）
func move_entity(entity: GridEntity2D, to: Vector2i) -> void:
	var from: Vector2i = find_entity(entity)
	if from == Vector2i(-1, -1):
		return
	_erase_all_cells_of(entity)
	var new_positions: Array[Vector2i] = entity.get_occupied_cells(to)
	for pos: Vector2i in new_positions:
		if not _cells.has(pos):
			var arr: Array[GridEntity2D] = []
			_cells[pos] = arr
		(_cells[pos] as Array[GridEntity2D]).append(entity)
	entity_moved.emit(from, to, entity)

## 查询指定格子上的所有实体，无实体返回空数组
func get_entity_at(grid_pos: Vector2i) -> Array[GridEntity2D]:
	if _cells.has(grid_pos):
		return _cells[grid_pos] as Array[GridEntity2D]
	var empty: Array[GridEntity2D] = []
	return empty

## 判断指定格子是否为空（无实体占用）
func is_cell_empty(grid_pos: Vector2i) -> bool:
	if not _cells.has(grid_pos):
		return true
	return (_cells[grid_pos] as Array[GridEntity2D]).is_empty()

## 查找指定实体所在的网格坐标，未找到返回 Vector2i(-1, -1)
func find_entity(entity: GridEntity2D) -> Vector2i:
	for pos: Vector2i in _cells:
		var arr: Array[GridEntity2D] = _cells[pos] as Array[GridEntity2D]
		if entity in arr:
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
	var scene_owner: Node = owner
	for child: Node in _entity_layer.get_children():
		# 场景瓦片实例化的子节点 owner 为 null，需修正为场景根节点以支持 % 唯一名称
		if child.owner == null and scene_owner != null:
			child.owner = scene_owner
		if child is GridEntity2D and find_entity(child) == Vector2i(-1, -1):
			var entity: GridEntity2D = child as GridEntity2D
			var grid_pos: Vector2i = world_to_grid(entity.global_position)
			place_entity(grid_pos, entity)
			entity._entity_ready()
			CLog.o("EntityLayer 注册: %s -> %s" % [entity.name, grid_pos])

## 实体即将离开场景树时，自动从占用字典中移除（支持多格实体）
func _on_entity_tree_exiting(entity: GridEntity2D) -> void:
	var pos: Vector2i = find_entity(entity)
	if pos != Vector2i(-1, -1):
		_erase_all_cells_of(entity)
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

# ── 格子查询 ─────────────────────────────────────────

## 获取所有通过 filter 的格子坐标
## filter: 可选的过滤回调，签名 func(grid_pos: Vector2i) -> bool，返回 true 表示该格子可用
func get_filtered_cells(filter: Callable = Callable()) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for pos: Vector2i in _zone_layer.get_used_cells():
		if filter.is_valid() and not filter.call(pos):
			continue
		result.append(pos)
	return result

# ── 内部辅助 ─────────────────────────────────────────

## 从占用字典中清除指定实体占据的所有格子（数组为空时删除 key）
func _erase_all_cells_of(entity: GridEntity2D) -> void:
	var keys_to_clean: Array[Vector2i] = []
	for pos: Vector2i in _cells:
		var arr: Array[GridEntity2D] = _cells[pos] as Array[GridEntity2D]
		if entity in arr:
			keys_to_clean.append(pos)
	for pos: Vector2i in keys_to_clean:
		var arr: Array[GridEntity2D] = _cells[pos] as Array[GridEntity2D]
		arr.erase(entity)
		if arr.is_empty():
			_cells.erase(pos)

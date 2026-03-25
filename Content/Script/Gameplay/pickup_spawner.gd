class_name PickupSpawner
extends Node2D
## 拾取物生成器：在网格上随机刷新拾取物
##
## 运行时从 pickup_scene 实例化拾取物，放置到随机网格位置。
## 每次拾取物被捡起后，等待下一次 lane 模式结束再延迟生成新的拾取物。

# ── 导出属性 ─────────────────────────────────────────
## 拾取物场景资源
@export var pickup_scene: PackedScene
## lane 模式结束后生成拾取物的等待时间（秒）
@export var spawn_delay: float = 2.0

# ── 内部变量 ─────────────────────────────────────────
## 网格系统引用（通过唯一名称获取）
@onready var _grid: GridSystem2D = %GridSystem2D
## 节拍指挥引用（通过唯一名称获取）
@onready var _conductor: RhythmConductor = %RhythmConductor
## 当前场景中活跃的拾取物
var _active_item: PickupItem = null

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	# 首次延迟生成拾取物
	get_tree().create_timer(spawn_delay).timeout.connect(_spawn_one)
	# 监听 lane 序列结束信号，在结束后延迟补充拾取物
	if _conductor != null:
		_conductor.lane_sequence_finished.connect(_on_lane_sequence_finished)


## lane 模式结束后的回调：若拾取物缺失，延迟一段时间后生成
func _on_lane_sequence_finished(_is_full_combo: bool) -> void:
	CLog.o("lane 模式结束，等待 %f 秒后生成拾取物" % spawn_delay)
	if _active_item == null:
		get_tree().create_timer(spawn_delay).timeout.connect(_spawn_one)

# ── 生成逻辑 ─────────────────────────────────────────

## 判断格子是否可用于生成拾取物（可通行且未被占用）
func _is_spawnable(grid_pos: Vector2i) -> bool:
	if not (_grid.get_cell_custom_data(grid_pos, "Passable", false) as bool):
		return false
	if not _grid.get_entity_at(grid_pos).is_empty():
		return false
	return true


## 生成一个拾取物到随机网格位置
func _spawn_one() -> void:
	if pickup_scene == null or _grid == null:
		return
	if _active_item != null:
		return
	# 获取所有可生成的格子并随机选取
	var candidates: Array[Vector2i] = _grid.get_filtered_cells(_is_spawnable)
	if candidates.is_empty():
		return
	var grid_pos: Vector2i = candidates[randi() % candidates.size()]
	var world_pos: Vector2 = _grid.grid_to_world(grid_pos)
	var item: PickupItem = pickup_scene.instantiate() as PickupItem
	item.position = world_pos
	item.picked_up.connect(_on_item_picked_up)
	add_child(item)
	_active_item = item
	# 在网格系统中注册拾取物占用
	_grid.place_entity(grid_pos, item)

# ── 信号回调 ─────────────────────────────────────────

## 拾取物被捡起的回调（占用由 GridSystem2D 的 tree_exiting 自动移除）
func _on_item_picked_up(item: PickupItem) -> void:
	_active_item = null

class_name PickupSpawner
extends Node2D
## 拾取物生成器：在网格上随机刷新拾取物
##
## 运行时从 pickup_scene 实例化拾取物，放置到随机网格位置。
## 玩家拾取后自动补充新的拾取物。

# ── 导出属性 ─────────────────────────────────────────
## 拾取物场景资源
@export var pickup_scene: PackedScene
## 关联的玩家节点路径（用于排除玩家当前位置）
@export var player_path: NodePath
## 网格系统节点路径（场景中静态配置）
@export var grid_path: NodePath
## 同时存在的最大拾取物数量
@export var max_items: int = 3
## 拾取后重新生成的最短延迟（秒）
@export var respawn_delay_min: float = 1.0
## 拾取后重新生成的最长延迟（秒）
@export var respawn_delay_max: float = 3.0

# ── 内部变量 ─────────────────────────────────────────
## 关联的玩家引用
var _player: RhythmPlayer
## 网格系统引用
var _grid: GridSystem
## 当前场景中活跃的拾取物列表
var _active_items: Array[PickupItem] = []

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	if not player_path.is_empty():
		_player = get_node(player_path) as RhythmPlayer
	if not grid_path.is_empty():
		_grid = get_node(grid_path) as GridSystem
	# 初始生成一批拾取物
	for i: int in range(max_items):
		_spawn_one()

# ── 生成逻辑 ─────────────────────────────────────────

## 判断格子是否可通行（用于生成点过滤）
func _is_passable(grid_pos: Vector2i) -> bool:
	return _grid.get_cell_custom_data(grid_pos, "Passable", false) as bool


## 生成一个拾取物到随机网格位置
func _spawn_one() -> void:
	if pickup_scene == null or _player == null or _grid == null:
		return
	# 利用网格系统的占用追踪获取空位（仅在可通行格子上生成）
	var grid_pos: Vector2i = _grid.get_random_empty_cell(_is_passable)
	if grid_pos == Vector2i(-1, -1):
		return
	var world_pos: Vector2 = _grid.grid_to_world(grid_pos)
	var item: PickupItem = pickup_scene.instantiate() as PickupItem
	item.position = world_pos
	item.picked_up.connect(_on_item_picked_up)
	add_child(item)
	_active_items.append(item)
	# 在网格系统中注册拾取物占用
	_grid.place_entity(grid_pos, item)

## 延迟生成一个拾取物
func _spawn_one_delayed() -> void:
	var delay: float = randf_range(respawn_delay_min, respawn_delay_max)
	get_tree().create_timer(delay).timeout.connect(_spawn_one)

# ── 信号回调 ─────────────────────────────────────────

## 拾取物被捡起的回调（占用由 GridSystem 的 tree_exiting 自动移除）
func _on_item_picked_up(item: PickupItem) -> void:
	_active_items.erase(item)
	# 延迟后补充新的拾取物
	_spawn_one_delayed()

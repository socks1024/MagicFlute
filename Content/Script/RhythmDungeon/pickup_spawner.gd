class_name PickupSpawner
extends Node2D
## 拾取物生成器：在网格上随机刷新拾取物
##
## 运行时从 pickup_scene 实例化拾取物，放置到随机网格位置。
## 玩家拾取后自动补充新的拾取物。

# ── 信号 ──────────────────────────────────────────────
## 有拾取物被捡起时发出
signal item_picked_up(item: PickupItem)

# ── 导出属性 ─────────────────────────────────────────
## 拾取物场景资源
@export var pickup_scene: PackedScene
## 关联的玩家节点路径（用于排除玩家当前位置）
@export var player_path: NodePath
## 网格大小（像素），应与玩家的 tile_size 一致
@export var tile_size: float = 64.0
## 生成区域半径（以网格数计），拾取物会在玩家周围此范围内生成
@export var spawn_radius: int = 5
## 同时存在的最大拾取物数量
@export var max_items: int = 3
## 拾取后重新生成的最短延迟（秒）
@export var respawn_delay_min: float = 1.0
## 拾取后重新生成的最长延迟（秒）
@export var respawn_delay_max: float = 3.0

# ── 内部变量 ─────────────────────────────────────────
## 关联的玩家引用
var _player: RhythmPlayer
## 当前场景中活跃的拾取物列表
var _active_items: Array[PickupItem] = []

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	if not player_path.is_empty():
		_player = get_node(player_path) as RhythmPlayer
	# 初始生成一批拾取物
	for i: int in range(max_items):
		_spawn_one()

# ── 生成逻辑 ─────────────────────────────────────────

## 生成一个拾取物到随机网格位置
func _spawn_one() -> void:
	if pickup_scene == null or _player == null:
		return
	var grid_pos: Vector2 = _get_random_grid_position()
	var world_pos: Vector2 = grid_pos * tile_size
	var item: PickupItem = pickup_scene.instantiate() as PickupItem
	item.position = world_pos
	item.picked_up.connect(_on_item_picked_up)
	add_child(item)
	_active_items.append(item)


## 获取一个不与玩家重叠也不与现有拾取物重叠的随机网格坐标
func _get_random_grid_position() -> Vector2:
	var player_grid: Vector2 = _world_to_grid(_player.position)
	var occupied: Array[Vector2] = [player_grid]
	for item: PickupItem in _active_items:
		if is_instance_valid(item):
			occupied.append(_world_to_grid(item.position))
	# 最多尝试 50 次避免死循环
	for attempt: int in range(50):
		var gx: int = randi_range(-spawn_radius, spawn_radius)
		var gy: int = randi_range(-spawn_radius, spawn_radius)
		var candidate: Vector2 = player_grid + Vector2(gx, gy)
		if candidate not in occupied:
			return candidate
	# 兜底：直接返回一个偏移位置
	return player_grid + Vector2(spawn_radius, 0)


## 世界坐标转网格坐标
func _world_to_grid(world_pos: Vector2) -> Vector2:
	return Vector2(roundf(world_pos.x / tile_size), roundf(world_pos.y / tile_size))

## 延迟生成一个拾取物
func _spawn_one_delayed() -> void:
	var delay: float = randf_range(respawn_delay_min, respawn_delay_max)
	get_tree().create_timer(delay).timeout.connect(_spawn_one)

# ── 信号回调 ─────────────────────────────────────────

## 拾取物被捡起的回调
func _on_item_picked_up(item: PickupItem) -> void:
	_active_items.erase(item)
	item_picked_up.emit(item)
	# 延迟后补充新的拾取物
	_spawn_one_delayed()

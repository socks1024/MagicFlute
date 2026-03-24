class_name RhythmPlayer
extends Node2D
## 节奏地牢玩家：响应节拍指挥的信号，执行移动、闪白、拾取

# ── 信号 ──────────────────────────────────────────────
## 成功踩点移动时发出
signal beat_move(direction: Vector2)
## 踩点失败（Miss）时发出
signal beat_miss
## 拾取物品时发出
signal item_collected

# ── 移动参数 ─────────────────────────────────────────
## 网格系统节点路径（场景中静态配置）
@export var grid_path: NodePath
## 移动补间时长（秒），纯视觉过渡
@export var move_tween_duration: float = 0.1

# ── 闪白参数 ─────────────────────────────────────────
## 精灵节点路径（用于闪白效果）
@export var sprite_path: NodePath
## 闪白持续时长（秒）
@export var flash_duration: float = 0.15

# ── 节拍指挥 ─────────────────────────────────────────
## RhythmConductor 节点路径（场景中静态配置）
@export var conductor_path: NodePath

# ── 内部变量（运行时） ───────────────────────────────
## 是否正在执行移动补间（防止连点）
var _is_moving: bool = false
## 精灵节点引用
var _sprite: Sprite2D
## 闪白用的 ShaderMaterial
var _flash_material: ShaderMaterial
## 节拍指挥引用
var _conductor: RhythmConductor
## 网格系统引用
var _grid: GridSystem

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	# 获取网格系统引用
	if not grid_path.is_empty():
		_grid = get_node(grid_path) as GridSystem
	# 在网格系统中注册玩家初始位置，并对齐到格子中心
	if _grid != null:
		var initial_grid_pos: Vector2i = _grid.world_to_grid(position)
		position = _grid.grid_to_world(initial_grid_pos)
		_grid.place_entity(initial_grid_pos, self)
	# 获取精灵并初始化闪白 Shader
	if not sprite_path.is_empty():
		_sprite = get_node(sprite_path) as Sprite2D
	if _sprite != null:
		var shader: Shader = load("res://Content/Art/Shader/Sprite/Color/color.gdshader") as Shader
		_flash_material = ShaderMaterial.new()
		_flash_material.shader = shader
		_flash_material.set_shader_parameter("base_color", Color.WHITE)
		_flash_material.set_shader_parameter("color_amount", 0.0)
		_sprite.material = _flash_material
	# 获取节拍指挥引用并连接信号
	if not conductor_path.is_empty():
		_conductor = get_node(conductor_path) as RhythmConductor
	if _conductor != null:
		_conductor.move_requested.connect(_on_move_requested)
		_conductor.move_miss.connect(_on_move_miss)
		_conductor.lane_note_hit.connect(_on_lane_note_hit)
		_conductor.lane_sequence_finished.connect(_on_lane_sequence_finished)
	CLog.o("RhythmPlayer 就绪 | 格子=%dx%dpx" % [int(_grid.cell_width) if _grid != null else 0, int(_grid.cell_height) if _grid != null else 0])

# ── 信号回调（来自 Conductor） ───────────────────────

## 收到移动请求：执行卡点移动
func _on_move_requested(direction: Vector2) -> void:
	if _is_moving:
		return
	_do_beat_move(direction)


## 收到 Miss 通知
func _on_move_miss() -> void:
	beat_miss.emit()
	CLog.w("Miss!")


## 轨道音符命中回调
func _on_lane_note_hit(_direction: Vector2) -> void:
	_flash_white()
	CLog.o("轨道命中! 方向=%s" % _direction)


## 轨道序列结束回调
func _on_lane_sequence_finished() -> void:
	CLog.o("轨道序列结束，恢复移动")

# ── 移动执行 ─────────────────────────────────────────

## 判断指定格子是否可通行（读取 TileSet 的 Passable 自定义数据）
func _is_passable(grid_pos: Vector2i) -> bool:
	return _grid.get_cell_custom_data(grid_pos, "Passable", false) as bool


## 执行卡点移动（Tween 过渡）
func _do_beat_move(direction: Vector2) -> void:
	# 通过网格系统计算目标位置
	var current_grid: Vector2i = _grid.world_to_grid(position)
	var target_grid: Vector2i = current_grid + Vector2i(int(direction.x), int(direction.y))
	# 检查目标格子是否可通行，不可通行则不移动
	if not _is_passable(target_grid):
		CLog.o("目标格 %s 不可通行，移动取消" % target_grid)
		return
	_is_moving = true
	# 移动期间禁用 Conductor 输入，防止连点
	if _conductor != null:
		_conductor.set_input_enabled(false)
	var target_pos: Vector2 = _grid.grid_to_world(target_grid)
	# 在移动前检查目标格子是否有拾取物
	var target_entity: Node = _grid.get_entity_at(target_grid)
	# 更新网格系统中的占用状态
	_grid.move_entity(current_grid, target_grid)
	beat_move.emit(direction)
	_flash_white()
	CLog.o("Hit! 方向=%s  目标格=%s" % [direction, target_grid])

	if move_tween_duration <= 0.0:
		position = target_pos
		_on_move_finished(target_entity)
		return

	var tween: Tween = create_tween()
	tween.tween_property(self, "position", target_pos, move_tween_duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.finished.connect(_on_move_finished.bind(target_entity))


## 移动完成（补间结束或瞬移后）
func _on_move_finished(entity: Node) -> void:
	_is_moving = false
	# 恢复 Conductor 输入
	if _conductor != null:
		_conductor.set_input_enabled(true)
	_try_pickup(entity)

# ── 拾取 & 闪白 ─────────────────────────────────────

## 尝试拾取目标实体（如果是拾取物）
func _try_pickup(entity: Node) -> void:
	if entity is PickupItem:
		entity.do_pickup()
		_on_pickup_collected()


## 拾取物收集后的统一处理（闪白 + 触发轨道等）
func _on_pickup_collected() -> void:
	item_collected.emit()
	_flash_white()
	# 触发音游轨道序列
	if _conductor != null:
		_conductor.start_lane_sequence()
	CLog.o("拾取物品!")


## 播放闪白效果：color_amount 从 1 → 0
func _flash_white() -> void:
	if _flash_material == null:
		return
	_flash_material.set_shader_parameter("color_amount", 1.0)
	var tween: Tween = create_tween()
	tween.tween_method(_set_flash_amount, 1.0, 0.0, flash_duration)


## Tween 回调：设置 shader 的 color_amount
func _set_flash_amount(value: float) -> void:
	if _flash_material != null:
		_flash_material.set_shader_parameter("color_amount", value)

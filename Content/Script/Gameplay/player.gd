class_name RhythmPlayer
extends GridEntity2D
## 节奏地牢玩家：响应节拍指挥的信号，执行移动、闪白、拾取

# ── 信号 ──────────────────────────────────────────────
## 踩点失败（Miss）时发出
signal beat_miss
## 拾取物品时发出
signal item_collected
## HP 变化时发出（current_hp, max_hp）
signal hp_changed(current_hp: int, max_hp: int)
## 玩家死亡时发出
signal died

# ── HP 参数 ──────────────────────────────────────────
## 最大生命值
@export var max_hp: int = 3

@export_group("Spring")
## 位移弹簧阻尼（0~1，越大越快停下）
@export_range(0.0, 1.0) var spring_position_damping: float = 0.65
## 位移弹簧频率（越大弹得越快）
@export_range(1.0, 20.0) var spring_position_frequency: float = 8.0
## 挤压拉伸弹簧阻尼
@export_range(0.0, 1.0) var spring_scale_damping: float = 0.5
## 挤压拉伸弹簧频率
@export_range(1.0, 20.0) var spring_scale_frequency: float = 10.0
## 挤压拉伸 bump 幅度（移动方向轴）
@export var squash_stretch_amount: float = 0.3

# ── 震屏 ─────────────────────────────────────────────
## 清屏震屏发射器（Player 场景中的子节点）
@onready var _screen_shake_emitter: PhantomCameraNoiseEmitter2D = $ScreenShakeEmitter

# ── 内部变量（运行时） ───────────────────────────────
## 当前生命值
var _current_hp: int = 0
## 节拍指挥引用（在 _on_placed 中获取）
var _conductor: RhythmConductor
## 位移弹簧（纯视觉，实现弹性过冲）
var _spring_position: SpringVector2
## 挤压拉伸弹簧（驱动精灵缩放）
var _spring_scale: SpringVector2

# ── @onready 引用 ────────────────────────────────────
## 精灵节点引用
@onready var _sprite: Sprite2D = $Sprite2D

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	_current_hp = max_hp
	# 初始化弹簧系统（使用全局坐标，确保与 GridSystem2D 的坐标转换一致）
	_spring_position = SpringVector2.new(global_position, spring_position_damping, spring_position_frequency)
	_spring_scale = SpringVector2.new(Vector2.ONE, spring_scale_damping, spring_scale_frequency)
	CLog.o("RhythmPlayer 就绪 | HP=%d/%d" % [_current_hp, max_hp])


## 实体被放置到网格时调用，此时 owner 已修正，可安全使用 % 唯一名称
func _on_placed(_grid_pos: Vector2i) -> void:
	_conductor = %RhythmConductor as RhythmConductor
	if _conductor != null:
		_conductor.move_requested.connect(_on_move_requested)
		_conductor.move_miss.connect(_on_move_miss)
		_conductor.lane_note_hit.connect(_on_lane_note_hit)
		_conductor.lane_sequence_finished.connect(_on_lane_sequence_finished)
	else:
		CLog.e("RhythmPlayer 未找到 Conductor")


func _physics_process(delta: float) -> void:
	# 在固定时间步长中更新弹簧，确保不同帧率下行为一致
	_spring_position.update(delta)
	_spring_scale.update(delta)
	# 用位移弹簧驱动视觉位置（使用全局坐标，与网格系统坐标一致）
	global_position = _spring_position.current
	# 用缩放弹簧驱动精灵缩放
	if _sprite != null:
		_sprite.scale = _spring_scale.current

# ── 信号回调（来自 Conductor） ───────────────────────

## 收到移动请求：执行卡点移动
func _on_move_requested(direction: Vector2) -> void:
	_do_beat_move(direction)


## 收到 Miss 通知
func _on_move_miss() -> void:
	beat_miss.emit()
	CLog.w("Miss!")


## 轨道音符命中回调
func _on_lane_note_hit(_direction: Vector2) -> void:
	CLog.o("轨道命中! 方向=%s" % _direction)


## 轨道序列结束回调
func _on_lane_sequence_finished(is_full_combo: bool) -> void:
	if is_full_combo:
		_clear_screen()
	CLog.o("轨道序列结束，恢复移动 | Full Combo=%s" % is_full_combo)


## 清屏：击杀当前网格上所有敌人并触发震屏
func _clear_screen() -> void:
	var entities: Array[GridEntity2D] = _grid_system.get_all_entities(GridEntity2D.LAYER_ENEMY)
	for entity: GridEntity2D in entities:
		if is_instance_valid(entity):
			(entity as Enemy).destroy()
	# 触发震屏
	if _screen_shake_emitter != null:
		_screen_shake_emitter.emit()

# ── 移动执行 ─────────────────────────────────────────

## 执行卡点移动（网格逻辑瞬时完成，Spring 只负责视觉过渡）
func _do_beat_move(direction: Vector2) -> void:
	# 通过反向索引获取当前网格位置
	var current_grid: Vector2i = _grid_system.find_entity(self)
	var target_grid: Vector2i = current_grid + Vector2i(int(direction.x), int(direction.y))
	
	# 尝试移动（阻挡/重叠检测由 GridSystem2D 的 block_mask 机制统一处理）
	if not _grid_system.move_entity(self, target_grid):
		return
	var target_pos: Vector2 = _grid_system.grid_to_world(target_grid)
	CLog.o("Hit! 方向=%s  目标格=%s" % [direction, target_grid])
	# 用位移弹簧驱动视觉过渡（动画未结束时再次调用会自然过渡到新目标）
	_spring_position.move_to(target_pos)
	# 挤压拉伸：沿移动方向拉伸，垂直方向压缩
	# 先重置速度，防止连续移动时冲量累加导致 scale 爆炸
	var stretch: Vector2 = Vector2(
		absf(direction.x) * squash_stretch_amount - absf(direction.y) * squash_stretch_amount,
		absf(direction.y) * squash_stretch_amount - absf(direction.x) * squash_stretch_amount
	)
	_spring_scale.bump(stretch)

# ── 重叠回调（由 GridSystem2D 在 move_entity 时自动调用） ────

## 与其他实体重叠时的处理（拾取物品、敌人接触等）
func _on_overlap(other: GridEntity2D) -> void:
	if other is PickupItem:
		other.do_pickup()
		_on_pickup_collected()
	elif other is Enemy:
		var enemy: Enemy = other as Enemy
		take_damage(enemy.contact_damage)
		enemy.vanish()
		CLog.o("玩家碰到敌人，受到 %d 点伤害" % enemy.contact_damage)


## 拾取物收集后的统一处理（恢复生命 + 触发轨道等）
func _on_pickup_collected() -> void:
	item_collected.emit()
	heal(1)
	# 触发音游轨道序列
	if _conductor != null:
		_conductor.start_lane_sequence()
	CLog.o("拾取物品!")

# ── HP 管理 ──────────────────────────────────────────

## 恢复生命值
func heal(amount: int) -> void:
	_current_hp = mini(_current_hp + amount, max_hp)
	hp_changed.emit(_current_hp, max_hp)
	CLog.o("玩家恢复 +%d  HP=%d/%d" % [amount, _current_hp, max_hp])


## 受到伤害
func take_damage(amount: int) -> void:
	_current_hp = maxi(_current_hp - amount, 0)
	hp_changed.emit(_current_hp, max_hp)
	CLog.o("玩家受伤 -%d  HP=%d/%d" % [amount, _current_hp, max_hp])
	if _current_hp <= 0:
		_die()


## 死亡处理
func _die() -> void:
	died.emit()
	CLog.o("玩家死亡!")

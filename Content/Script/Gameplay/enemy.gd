class_name Enemy
extends GridEntity2D
## 敌人：在网格上按节拍持续向右移动
##
## 每次收到节拍信号时向右移动一格，超出网格或被空气墙阻挡后自动销毁。
## 使用 SpringVector2 实现视觉弹性位移。

# ── 战斗参数 ─────────────────────────────────────────
## 接触伤害（碰到玩家时造成的伤害值）
@export var contact_damage: int = 1

@export_group("Spring")
## 位移弹簧阻尼（0~1，越大越快停下）
@export_range(0.0, 1.0) var spring_position_damping: float = 0.65
## 位移弹簧频率（越大弹得越快）
@export_range(1.0, 20.0) var spring_position_frequency: float = 8.0
## 挤压拉伸弹簧阻尼
@export_range(0.0, 1.0) var spring_scale_damping: float = 0.5
## 挤压拉伸弹簧频率
@export_range(1.0, 20.0) var spring_scale_frequency: float = 10.0
## 挤压拉伸 bump 幅度（移动方向轴拉伸，垂直方向压缩）
@export var squash_stretch_amount: float = 0.3
## 旋转弹簧阻尼
@export_range(0.0, 1.0) var spring_rotation_damping: float = 0.5
## 旋转弹簧频率
@export_range(1.0, 20.0) var spring_rotation_frequency: float = 8.0
## 旋转 bump 幅度（弧度）
@export var rotation_bump_amount: float = 0.15

# ── 内部变量（运行时） ───────────────────────────────
## 节拍指挥引用（在 _on_placed 中获取）
var _conductor: RhythmConductor
## 位移弹簧（纯视觉，实现弹性过冲）
var _spring_position: SpringVector2
## 挤压拉伸弹簧（驱动精灵缩放）
var _spring_scale: SpringVector2
## 旋转弹簧（驱动精灵旋转）
var _spring_rotation: SpringFloat

# ── @onready 引用 ────────────────────────────────────
## 精灵节点引用
@onready var _sprite: Sprite2D = $Sprite2D
## 死亡粒子节点引用
@onready var _death_particles: CPUParticles2D = $DeathParticles

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	_spring_position = SpringVector2.new(position, spring_position_damping, spring_position_frequency)
	_spring_scale = SpringVector2.new(Vector2.ONE, spring_scale_damping, spring_scale_frequency)
	_spring_rotation = SpringFloat.new(0.0, spring_rotation_damping, spring_rotation_frequency)
	CLog.o("Enemy 就绪")


## 实体被放置到网格时调用，此时 owner 已修正，可安全使用 % 唯一名称
func _on_placed(_grid_pos: Vector2i) -> void:
	_conductor = %RhythmConductor as RhythmConductor
	if _conductor != null:
		_conductor.move_beat_tick.connect(_on_move_beat_tick)
	else:
		CLog.e("Enemy 未找到 RhythmConductor")


func _physics_process(delta: float) -> void:
	_spring_position.update(delta)
	_spring_scale.update(delta)
	_spring_rotation.update(delta)
	position = _spring_position.current
	if _sprite != null:
		_sprite.scale = _spring_scale.current
		_sprite.rotation = _spring_rotation.current

# ── 信号回调 ─────────────────────────────────────────

## 收到移动节拍信号：向右移动一格（lane 模式时 Conductor 不会发出此信号）
func _on_move_beat_tick(_beat_index: int) -> void:
	_move(Vector2i.RIGHT)

# ── 移动逻辑 ─────────────────────────────────────────

## 向指定方向移动一格，不可通行则销毁自身
func _move(direction: Vector2i) -> void:
	if _grid_system == null:
		return
	var current_grid: Vector2i = _grid_system.find_entity(self)
	var target_grid: Vector2i = current_grid + direction
	# 尝试移动（阻挡/重叠检测由 GridSystem2D 统一处理，回调 _on_blocked / _on_overlap）
	if not _grid_system.move_entity(self, target_grid):
		# 被空气墙等阻挡时也销毁
		CLog.o("Enemy 被阻挡于 %s，销毁" % target_grid)
		vanish()
		return
	if _grid_system == null:
		return
	# 弹簧驱动视觉位移
	var target_pos: Vector2 = _grid_system.grid_to_world(target_grid)
	_spring_position.move_to(target_pos)
	# 挤压拉伸：沿移动方向拉伸，垂直方向压缩
	# 先重置速度，防止连续移动时冲量累加导致 scale 爆炸
	var dir_f: Vector2 = Vector2(direction).normalized()
	var stretch: Vector2 = Vector2(
		abs(dir_f.x) * squash_stretch_amount - abs(dir_f.y) * squash_stretch_amount,
		abs(dir_f.y) * squash_stretch_amount - abs(dir_f.x) * squash_stretch_amount
	)
	_spring_scale.bump(stretch)
	# 旋转 bump：根据移动方向决定旋转符号（右/下为正，左/上为负）
	var rot_sign: float = sign(dir_f.x + dir_f.y)
	_spring_rotation.bump(rotation_bump_amount * rot_sign)
	# CLog.o("Enemy 移动 -> %s" % target_grid)


## 消失（并非被杀死）
func vanish() -> void:
	remove_and_free()


## 销毁(被杀死)
func destroy() -> void:
	_emit_death_particles()
	remove_and_free()

# ── 重叠回调（由 GridSystem2D 在 move_entity 时自动调用） ────

## 与玩家重叠时，造成伤害并销毁自身
func _on_overlap(other: GridEntity2D) -> void:
	if other is RhythmPlayer:
		var player: RhythmPlayer = other as RhythmPlayer
		player.take_damage(contact_damage)
		CLog.o("Enemy 碰到玩家，造成 %d 点伤害，销毁自身" % contact_damage)
		vanish()


## 将死亡粒子从自身移出并挂载到父节点，触发发射，确保敌人销毁后粒子仍能播放完毕
func _emit_death_particles() -> void:
	if _death_particles == null:
		return
	var particles: CPUParticles2D = _death_particles
	# 从 Enemy 上摘下来挂到父节点，这样 Enemy queue_free 后粒子继续播放
	remove_child(particles)
	particles.global_position = global_position
	get_parent().add_child(particles)
	particles.emitting = true
	# 播放完毕后自动清理
	get_tree().create_timer(particles.lifetime + 0.1).timeout.connect(particles.queue_free)

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

@export_group("Sprite")
## 普通行走模式精灵图
@export var texture_normal: Texture2D
## Lane 音游模式精灵图
@export var texture_lane: Texture2D

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
## 旋转 bump 幅度（弧度）
@export var rotation_bump_amount: float = 0.15
## 旋转弹簧阻尼
@export_range(0.0, 1.0) var spring_rotation_damping: float = 0.5
## 旋转弹簧频率
@export_range(1.0, 20.0) var spring_rotation_frequency: float = 10.0

@export_group("Camera Zoom Pulse")
## 每拍 Zoom 脉动幅度（正值 = zoom in）
@export var zoom_beat_bump: float = 0.005
## 清屏 Zoom 脉动幅度（负值方向 = zoom out）
@export var zoom_clear_bump: float = 0.03
## Zoom 弹簧阻尼
@export_range(0.0, 1.0) var spring_zoom_damping: float = 0.5
## Zoom 弹簧频率
@export_range(1.0, 20.0) var spring_zoom_frequency: float = 8.0

# ── 震屏 ─────────────────────────────────────────────
## 清屏震屏发射器（Player 场景中的子节点）
@onready var _clear_shake_emitter: PhantomCameraNoiseEmitter2D = $ClearShakeEmitter
## 受伤震屏发射器（轻度震屏）
@onready var _hurt_shake_emitter: PhantomCameraNoiseEmitter2D = $HurtShakeEmitter
## PhantomCamera 宿主（用于获取当前活跃的 PCam）
@onready var _pcam_host: Node = $Camera2D/PhantomCameraHost

# ── 内部变量（运行时） ───────────────────────────────
## 当前生命值
var _current_hp: int = 0
## 节拍指挥引用（在 _on_placed 中获取）
var _conductor: RhythmConductor
## 位移弹簧（纯视觉，实现弹性过冲）
var _spring_position: SpringVector2
## 挤压拉伸弹簧（驱动精灵缩放）
var _spring_scale: SpringVector2
## Zoom 弹簧（驱动相机 Zoom 脉动）
var _spring_zoom: SpringFloat
## 旋转弹簧（驱动精灵旋转抖动）
var _spring_rotation: SpringFloat

# ── @onready 引用 ────────────────────────────────────
## 精灵节点引用
@onready var _sprite: Sprite2D = $Sprite2D

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	_current_hp = max_hp
	# 初始化弹簧系统（使用全局坐标，确保与 GridSystem2D 的坐标转换一致）
	_spring_position = SpringVector2.new(global_position, spring_position_damping, spring_position_frequency)
	_spring_scale = SpringVector2.new(Vector2.ONE, spring_scale_damping, spring_scale_frequency)
	# 初始化 Zoom 弹簧（基础 zoom 从活跃 PCam 读取，若无则默认 1.0）
	var base_zoom: float = 1.0
	var active_pcam: Node = _pcam_host.get_active_pcam()
	if active_pcam != null:
		base_zoom = active_pcam.zoom.x
	_spring_zoom = SpringFloat.new(base_zoom, spring_zoom_damping, spring_zoom_frequency)
	_spring_rotation = SpringFloat.new(0.0, spring_rotation_damping, spring_rotation_frequency)
	CLog.o("RhythmPlayer 就绪 | HP=%d/%d" % [_current_hp, max_hp])


## 实体被放置到网格时调用，此时 owner 已修正，可安全使用 % 唯一名称
func _on_placed(_grid_pos: Vector2i) -> void:
	_conductor = %RhythmConductor as RhythmConductor
	if _conductor != null:
		_conductor.move_requested.connect(_on_move_requested)
		_conductor.move_miss.connect(_on_move_miss)
		_conductor.lane_note_hit.connect(_on_lane_note_hit)
		_conductor.lane_sequence_started.connect(_on_lane_sequence_started)
		_conductor.lane_sequence_finished.connect(_on_lane_sequence_finished)
		_conductor.beat_tick.connect(_on_beat_zoom_pulse)
	else:
		CLog.e("RhythmPlayer 未找到 Conductor")


func _physics_process(delta: float) -> void:
	# 在固定时间步长中更新弹簧，确保不同帧率下行为一致
	_spring_position.update(delta)
	_spring_scale.update(delta)
	_spring_zoom.update(delta)
	_spring_rotation.update(delta)
	# 用位移弹簧驱动视觉位置（使用全局坐标，与网格系统坐标一致）
	global_position = _spring_position.current
	# 用缩放弹簧驱动精灵缩放
	if _sprite != null:
		_sprite.scale = _spring_scale.current
		_sprite.rotation = _spring_rotation.current
	# 用 Zoom 弹簧驱动相机 Zoom
	var active_pcam: Node = _pcam_host.get_active_pcam()
	if active_pcam != null:
		active_pcam.zoom = Vector2.ONE * _spring_zoom.current

# ── 信号回调（来自 Conductor） ───────────────────────

## 收到移动请求：执行卡点移动
func _on_move_requested(direction: Vector2) -> void:
	_do_beat_move(direction)


## 每拍 Zoom 脉动回调
## 直接将 current 偏移到峰值，让弹簧从峰值回弹，
## 这样拍点时刻恰好是 zoom 最大值，而非从零加速产生延迟。
func _on_beat_zoom_pulse(_beat_index: int) -> void:
	_spring_zoom.current += zoom_beat_bump
	_spring_zoom.velocity = 0.0
	_spring_zoom.is_resting = false


## 收到 Miss 通知
func _on_move_miss() -> void:
	beat_miss.emit()
	_play_miss_feedback()
	CLog.w("Miss!")


## 轨道音符命中回调
func _on_lane_note_hit(_direction: Vector2) -> void:
	# 挤压拉伸 bump：沿命中方向拉伸，垂直方向压缩
	var stretch: Vector2 = Vector2(
		absf(_direction.x) * squash_stretch_amount - absf(_direction.y) * squash_stretch_amount,
		absf(_direction.y) * squash_stretch_amount - absf(_direction.x) * squash_stretch_amount
	)
	_spring_scale.bump(stretch)
	# 旋转 bump：根据方向决定旋转符号
	var rot_sign: float = sign(_direction.x + _direction.y)
	_spring_rotation.bump(rotation_bump_amount * rot_sign)
	CLog.o("轨道命中! 方向=%s" % _direction)


## 轨道序列开始回调：进入音游模式时暗角加深
func _on_lane_sequence_started() -> void:
	_set_vignette(true, 0.6, 0.6)
	# 切换到 lane 模式精灵图
	if texture_lane != null and _sprite != null:
		_sprite.texture = texture_lane


## 轨道序列结束回调：恢复暗角并处理清屏
func _on_lane_sequence_finished(is_full_combo: bool) -> void:
	# 恢复暗角到当前 HP 对应的状态
	_update_vignette_by_hp()
	# 切换回普通模式精灵图
	if texture_normal != null and _sprite != null:
		_sprite.texture = texture_normal
	if is_full_combo:
		_clear_screen()
	CLog.o("轨道序列结束，恢复移动 | Full Combo=%s" % is_full_combo)


## 清屏：击杀当前网格上所有敌人并触发震屏 + 暗角呼吸
func _clear_screen() -> void:
	var entities: Array[GridEntity2D] = _grid_system.get_all_entities(GridEntity2D.LAYER_ENEMY)
	for entity: GridEntity2D in entities:
		if is_instance_valid(entity):
			(entity as Enemy).destroy()
	# 触发震屏
	if _clear_shake_emitter != null:
		_clear_shake_emitter.emit()
	# Zoom out 弹回（直接偏移到峰值，拍点时刻即最大效果）
	_spring_zoom.current -= zoom_clear_bump
	_spring_zoom.velocity = 0.0
	_spring_zoom.is_resting = false
	# 暗角呼吸：瞬间放开 → 缓慢恢复
	_vignette_breathe()

# ── 移动执行 ─────────────────────────────────────────

## 执行卡点移动（网格逻辑瞬时完成，Spring 只负责视觉过渡）
func _do_beat_move(direction: Vector2) -> void:
	# 通过反向索引获取当前网格位置
	var current_grid: Vector2i = _grid_system.find_entity(self)
	var target_grid: Vector2i = current_grid + Vector2i(int(direction.x), int(direction.y))
	
	# 尝试移动（阻挡/重叠检测由 GridSystem2D 的 block_mask 机制统一处理）
	if not _grid_system.move_entity(self, target_grid):
		_play_miss_feedback()
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
	# 旋转 bump：根据移动方向决定旋转符号（右/下为正，左/上为负）
	var rot_sign: float = sign(direction.x + direction.y)
	_spring_rotation.bump(rotation_bump_amount * rot_sign)

## Miss / 撞墙反馈：随机方向摇头 + 均匀缩一下
func _play_miss_feedback() -> void:
	var rot_sign: float = [-1.0, 1.0].pick_random()
	_spring_rotation.bump(rotation_bump_amount * 1.5 * rot_sign)
	_spring_scale.bump(Vector2(-squash_stretch_amount * 0.5, -squash_stretch_amount * 0.5))

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
	_update_vignette_by_hp()
	CLog.o("玩家恢复 +%d  HP=%d/%d" % [amount, _current_hp, max_hp])


## 受到伤害
func take_damage(amount: int) -> void:
	_current_hp = maxi(_current_hp - amount, 0)
	hp_changed.emit(_current_hp, max_hp)
	# 触发受伤震屏
	if _hurt_shake_emitter != null:
		_hurt_shake_emitter.emit()
	# 触发受伤闪白
	_flash_white()
	# 更新暗角
	_update_vignette_by_hp()
	CLog.o("玩家受伤 -%d  HP=%d/%d" % [amount, _current_hp, max_hp])
	if _current_hp <= 0:
		_die()


## 受伤闪白（通过 color.gdshader 的 color_amount 参数实现）
func _flash_white() -> void:
	var mat: ShaderMaterial = _sprite.material as ShaderMaterial
	if mat == null:
		return
	# 瞬间设为全白，然后快速衰减回原色
	mat.set_shader_parameter("color_amount", 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(mat, "shader_parameter/color_amount", 0.0, 0.12)


## 死亡处理
func _die() -> void:
	died.emit()
	CLog.o("玩家死亡!")


## 控制暗角效果
func _set_vignette(enabled: bool, strength: float = 0.4, radius: float = 0.8) -> void:
	var pp: PostProcess2DController = %PostProcessing as PostProcess2DController
	if pp == null:
		return
	if enabled:
		pp.enable_effect("Vignette")
		pp.set_effect_param("Vignette", "vignette_strength", strength)
		pp.set_effect_param("Vignette", "vignette_radius", radius)
	else:
		pp.disable_effect("Vignette")


## 低 HP 时暗角收紧（满血时关闭暗角）
func _update_vignette_by_hp() -> void:
	var hp_ratio: float = float(_current_hp) / float(max_hp)
	if hp_ratio >= 1.0:
		_set_vignette(false)
		return
	var target_strength: float = 0.4 + (1.0 - hp_ratio) * 0.3  # 0.4 ~ 0.7
	var target_radius: float = 0.8 - (1.0 - hp_ratio) * 0.2    # 0.8 ~ 0.6
	_set_vignette(true, target_strength, target_radius)


## 清屏暗角呼吸：瞬间放开（减弱）再缓慢恢复到当前 HP 状态
func _vignette_breathe() -> void:
	var pp: PostProcess2DController = %PostProcessing as PostProcess2DController
	if pp == null:
		return
	# 瞬间放开暗角（强度降低、半径增大）
	pp.enable_effect("Vignette")
	pp.set_effect_param("Vignette", "vignette_strength", 0.1)
	pp.set_effect_param("Vignette", "vignette_radius", 1.0)
	# 用 Tween 缓慢恢复到当前 HP 对应的暗角状态
	var hp_ratio: float = float(_current_hp) / float(max_hp)
	var restore_strength: float = 0.4 + (1.0 - hp_ratio) * 0.3
	var restore_radius: float = 0.8 - (1.0 - hp_ratio) * 0.2
	var mat: ShaderMaterial = pp.get_effect_material("Vignette")
	if mat == null:
		return
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(mat, "shader_parameter/vignette_strength", restore_strength, 0.5)
	tween.tween_property(mat, "shader_parameter/vignette_radius", restore_radius, 0.5)

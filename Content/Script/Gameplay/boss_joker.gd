class_name BossJoker
extends Node2D
## Boss Joker 控制脚本，管理下属节点的动画播放

## 处决动画完成信号（下坠渐隐结束后发射）
signal death_finished

## 触发头部 spawn_enemy 动画的网格位置列表（在编辑器中配置）
@export var spawn_anim_positions: Array[Vector2i] = []
## 头部浮动的基础偏移（静止时的中心高度）
@export var head_float_base_offset: float = -8.0
## 头部浮动的振幅（上下浮动的像素范围）
@export var head_float_amplitude: float = 4.0
## 头部浮动的速度
@export var head_float_speed: float = 2.0

@export_group("受击效果")
## 受击闪红颜色
@export var hit_flash_color: Color = Color(1.0, 0.2, 0.2, 1.0)
## 受击闪红持续时间（秒）
@export var hit_flash_duration: float = 0.35
## 受击抖动幅度（x, y 像素范围）
@export var hit_shake_bump: Vector2 = Vector2(6.0, 3.0)
## 受击抖动持续时间（秒）
@export var hit_shake_duration: float = 0.3
## 受击抖动频率（每秒抖动次数）
@export var hit_shake_frequency: float = 30.0
## 死亡动画下坠距离（像素）
@export var fall_distance: float = 120.0
## 死亡动画下坠时间（秒）
@export var fall_duration: float = 10

var _head_float_time: float = 0.0
var _is_head_floating: bool = true
var _head_float_offset: float = 0.0
## 所有身体部位的引用列表（用于批量操作）
var _all_parts: Array[AnimatedSprite2D] = []
## 受击抖动 Tween
var _hit_shake_tween: Tween
## 受击闪红 Tween
var _hit_flash_tween: Tween
## 是否已进入死亡状态（所有阶段通关）
var _is_dead: bool = false

@onready var head: AnimatedSprite2D = $JokerHead
@onready var left_hand: AnimatedSprite2D = $JokerLeftHand
@onready var right_hand: AnimatedSprite2D = $JokerRightHand
@onready var body: AnimatedSprite2D = $JokerBody
@onready var _enemy_spawner: EnemySpawner = %EnemySpawner
@onready var _conductor: RhythmConductor = %RhythmConductor
@onready var _death_shake_emitter: PhantomCameraNoiseEmitter2D = $DeathShakeEmitter
@onready var _confetti_left: GPUParticles2D = %ConfettiLeft
@onready var _confetti_right: GPUParticles2D = %ConfettiRight


func _ready() -> void:
	head.play()
	left_hand.play()
	right_hand.play()
	body.play()
	_all_parts = [head, left_hand, right_hand, body]
	# 为所有部位设置闪色 Shader
	_setup_hit_shader()
	# 连接敌人生成信号
	if _enemy_spawner != null:
		_enemy_spawner.enemy_spawned.connect(_on_enemy_spawned)
	# 头部 spawn_enemy 动画播完后回到默认动画
	head.animation_finished.connect(_on_head_animation_finished)
	# 连接轨道序列结束信号（清屏时触发受击效果）
	if _conductor != null:
		_conductor.lane_sequence_finished.connect(_on_lane_sequence_finished)
		_conductor.all_stages_cleared.connect(_on_all_stages_cleared)


func _process(delta: float) -> void:
	if not _is_head_floating:
		return
	_head_float_time += delta
	_head_float_offset = head_float_base_offset + sin(_head_float_time * head_float_speed) * head_float_amplitude
	head.offset.y = _head_float_offset


## 敌人生成时检查是否在触发位置，是则播放 spawn_enemy 动画
func _on_enemy_spawned(grid_pos: Vector2i, _enemy: Enemy) -> void:
	if _is_dead:
		return
	if grid_pos in spawn_anim_positions:
		# 停止浮动，offset 归零后播放动画
		_is_head_floating = false
		head.offset.y = 0.0
		head.play(&"spawn_enemy")


## 头部动画播放完毕后回到默认动画并恢复浮动
func _on_head_animation_finished() -> void:
	if _is_dead:
		return
	if head.animation == &"spawn_enemy":
		head.play(&"default")
		_is_head_floating = true
		_head_float_time = 0.0


## 轨道序列结束回调：Full Combo 时触发受击效果
func _on_lane_sequence_finished(is_full_combo: bool) -> void:
	if is_full_combo:
		# 死亡状态下播放死亡动画，否则播放普通受击
		if _is_dead:
			_play_death_effect()
		else:
			_play_hit_effect()


## 所有阶段通关回调：标记死亡状态
func _on_all_stages_cleared() -> void:
	_is_dead = true
	CLog.o("BossJoker 进入死亡状态")


## 为所有部位创建闪色 ShaderMaterial（复用 color.gdshader）
func _setup_hit_shader() -> void:
	var shader: Shader = preload("res://Content/Art/Shader/Sprite/Color/color.gdshader")
	for part: AnimatedSprite2D in _all_parts:
		if part.material == null:
			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("base_color", hit_flash_color)
			mat.set_shader_parameter("color_amount", 0.0)
			part.material = mat


## 播放死亡效果：停止浮动，闪红 + 抖动 + 下坠渐隐
func _play_death_effect() -> void:
	# 停止头部浮动
	_is_head_floating = false
	head.offset.y = 0.0
	# 先播放一次受击闪红 + 抖动
	_play_hit_flash()
	_play_hit_shake()
	# 抖动 Tween 完成后，通过 finished 信号触发下坠渐隐
	_hit_shake_tween.finished.connect(_start_death_fall, CONNECT_ONE_SHOT)
	CLog.o("BossJoker 播放死亡动画（等待抖动结束后下坠）")


## 抖动结束后执行下坠 + 渐隐
func _start_death_fall() -> void:
	# 触发处决震屏
	if _death_shake_emitter != null:
		_death_shake_emitter.emit()
	# 触发礼花效果
	if _confetti_left != null:
		_confetti_left.emitting = true
	if _confetti_right != null:
		_confetti_right.emitting = true
	# 停止所有帧动画
	for part: AnimatedSprite2D in _all_parts:
		part.stop()
	# 将 shader 的 base_color 设为全透明，用 color_amount 从 0→1 实现渐隐
	for part: AnimatedSprite2D in _all_parts:
		var mat: ShaderMaterial = part.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("base_color", Color(0.0, 0.0, 0.0, 0.0))
			mat.set_shader_parameter("color_amount", 0.0)
	# 下坠 + 渐隐
	var death_tween: Tween = create_tween().set_parallel(true)
	for part: AnimatedSprite2D in _all_parts:
		death_tween.tween_property(part, "position:y", part.position.y + fall_distance, fall_duration) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		var mat: ShaderMaterial = part.material as ShaderMaterial
		if mat != null:
			death_tween.tween_property(mat, "shader_parameter/color_amount", 1.0, fall_duration) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	death_tween.finished.connect(func() -> void:
		death_finished.emit()
		CLog.o("BossJoker 处决动画完成")
	)
	CLog.o("BossJoker 下坠渐隐开始")


## 播放受击效果：所有部位闪红 + 抖动
func _play_hit_effect() -> void:
	_play_hit_flash()
	_play_hit_shake()


## 闪红效果：瞬间变红后缓慢恢复
func _play_hit_flash() -> void:
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	_hit_flash_tween = create_tween().set_parallel(true)
	for part: AnimatedSprite2D in _all_parts:
		var mat: ShaderMaterial = part.material as ShaderMaterial
		if mat == null:
			continue
		mat.set_shader_parameter("base_color", hit_flash_color)
		mat.set_shader_parameter("color_amount", 1.0)
		_hit_flash_tween.tween_property(mat, "shader_parameter/color_amount", 0.0, hit_flash_duration)


## 抖动效果：高频随机偏移后恢复原位
func _play_hit_shake() -> void:
	if _hit_shake_tween and _hit_shake_tween.is_valid():
		_hit_shake_tween.kill()
	# 记录各部位原始位置
	var original_positions: Array[Vector2] = []
	for part: AnimatedSprite2D in _all_parts:
		original_positions.append(part.position)
	# 计算抖动步数
	var step_count: int = int(hit_shake_duration * hit_shake_frequency)
	var step_time: float = hit_shake_duration / float(step_count)
	_hit_shake_tween = create_tween()
	for i: int in range(step_count):
		# 每步随机偏移
		_hit_shake_tween.tween_callback(func() -> void:
			for idx: int in range(_all_parts.size()):
				var offset: Vector2 = Vector2(
					randf_range(-hit_shake_bump.x, hit_shake_bump.x),
					randf_range(-hit_shake_bump.y, hit_shake_bump.y)
				)
				_all_parts[idx].position = original_positions[idx] + offset
		)
		_hit_shake_tween.tween_interval(step_time)
	# 抖动结束后恢复原位
	_hit_shake_tween.tween_callback(func() -> void:
		for idx: int in range(_all_parts.size()):
			_all_parts[idx].position = original_positions[idx]
	)

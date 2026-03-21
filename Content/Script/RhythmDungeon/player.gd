class_name RhythmPlayer
extends CharacterBody2D
## 节奏地牢玩家：卡点移动

# ── 信号 ──────────────────────────────────────────────
## 成功踩点移动时发出
signal beat_move(direction: Vector2)
## 踩点失败（Miss）时发出
signal beat_miss
## 拾取物品时发出
signal item_collected

# ── 节拍参数 ─────────────────────────────────────────
## 全局 BPM
@export var bpm: float = 120.0
## 首拍偏移时间（秒），用于对齐音乐
@export var first_beat_time_sec: float = 0.0
## 判定窗口提前量（秒）
@export var hit_window_early_sec: float = 0.15
## 判定窗口滞后量（秒）
@export var hit_window_late_sec: float = 0.15

# ── 移动参数 ─────────────────────────────────────────
## 每次移动的格子大小（像素）
@export var tile_size: float = 64.0
## 移动补间时长（秒），纯视觉过渡
@export var move_tween_duration: float = 0.1

# ── 输入上下文 ───────────────────────────────────────
## 移动输入上下文资源（场景中静态配置）
@export var move_input_context: InputContext

# ── 音频事件 ─────────────────────────────────────────
## 节拍音效事件（场景中静态配置 AudioEvent 资源）
@export var beat_sound: AudioEvent

# ── 闪白参数 ─────────────────────────────────────────
## 精灵节点路径（用于闪白效果）
@export var sprite_path: NodePath
## 闪白持续时长（秒）
@export var flash_duration: float = 0.15

# ── 音游轨道 ─────────────────────────────────────────
## RhythmLane 节点路径（场景中静态配置）
@export var rhythm_lane_path: NodePath

# ── 节拍指示器 ───────────────────────────────────────
## BeatIndicator 节点路径（场景中静态配置）
@export var beat_indicator_path: NodePath

# ── 内部变量（运行时） ───────────────────────────────
## 每拍时长（秒），由 BPM 推导
var _seconds_per_beat: float = 0.5
## 节拍主时钟（秒）
var _song_time_sec: float = 0.0
## 当前节拍索引
var _current_beat_index: int = -1
## 节拍时钟是否运行中
var _clock_running: bool = false
## 是否正在执行移动补间（防止连点）
var _is_moving: bool = false
## 当前拍是否已经行动过（每拍只允许一次行动）
var _beat_acted: bool = false
## 精灵节点引用
var _sprite: Sprite2D
## 闪白用的 ShaderMaterial
var _flash_material: ShaderMaterial
## 音游轨道引用
var _rhythm_lane: RhythmLane
## 节拍指示器引用
var _beat_indicator: BeatIndicator
## 轨道是否正在激活（激活时禁用移动输入）
var _lane_active: bool = false

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	_seconds_per_beat = 60.0 / bpm
	# 激活移动输入上下文
	if move_input_context != null:
		InputManager.add_context(move_input_context)
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
	# 获取音游轨道引用并连接信号
	if not rhythm_lane_path.is_empty():
		_rhythm_lane = get_node(rhythm_lane_path) as RhythmLane
	if _rhythm_lane != null:
		_rhythm_lane.sequence_finished.connect(_on_lane_sequence_finished)
	# 获取节拍指示器引用
	if not beat_indicator_path.is_empty():
		_beat_indicator = get_node(beat_indicator_path) as BeatIndicator
	# 自动启动节拍时钟
	_start_clock()
	CLog.o("RhythmPlayer 就绪 | BPM=%.1f  每拍=%.3fs  格子=%dpx" % [bpm, _seconds_per_beat, int(tile_size)])


func _process(delta: float) -> void:
	if not _clock_running:
		return
	_tick_clock(delta)


func _unhandled_input(event: InputEvent) -> void:
	# 轨道激活时，输入由 RhythmLane 自行处理，玩家不移动
	if _lane_active:
		return
	if _is_moving or _beat_acted:
		return
	# 检测四个方向的按下事件
	var dir: Vector2 = Vector2.ZERO
	if event.is_action_pressed("move_up"):
		dir = Vector2.UP
	elif event.is_action_pressed("move_down"):
		dir = Vector2.DOWN
	elif event.is_action_pressed("move_left"):
		dir = Vector2.LEFT
	elif event.is_action_pressed("move_right"):
		dir = Vector2.RIGHT
	else:
		return
	# 进行节拍判定
	if _is_in_hit_window():
		_do_beat_move(dir)
	else:
		_on_miss()


func _exit_tree() -> void:
	# 移除输入上下文
	if move_input_context != null:
		InputManager.remove_context(move_input_context.context_name)

# ── 节拍时钟 ─────────────────────────────────────────

## 启动节拍时钟
func _start_clock() -> void:
	_song_time_sec = 0.0
	_current_beat_index = -1
	_clock_running = true


## 推进节拍时钟
func _tick_clock(delta: float) -> void:
	_song_time_sec += delta
	var new_beat_index: int = _compute_beat_index(_song_time_sec)
	if new_beat_index > _current_beat_index:
		_current_beat_index = new_beat_index
		_beat_acted = false
		# 每拍播放音效
		if beat_sound != null:
			AudioManager.play_sound(beat_sound)


## 根据时间计算节拍索引
func _compute_beat_index(at_time_sec: float) -> int:
	if _seconds_per_beat <= 0.0:
		return 0
	var elapsed: float = at_time_sec - first_beat_time_sec
	if elapsed < 0.0:
		return -1
	return int(elapsed / _seconds_per_beat)


## 获取指定节拍索引对应的绝对时间
func _get_beat_time_sec(beat_index: int) -> float:
	return first_beat_time_sec + beat_index * _seconds_per_beat

# ── 判定逻辑 ─────────────────────────────────────────

## 判断当前输入时间是否落在最近拍点的判定窗口内
func _is_in_hit_window() -> bool:
	# 检查当前拍点
	var current_beat_time: float = _get_beat_time_sec(_current_beat_index)
	var diff_current: float = _song_time_sec - current_beat_time
	if diff_current >= 0.0 and diff_current <= hit_window_late_sec:
		return true
	# 检查下一拍点（提前量）
	var next_beat_time: float = _get_beat_time_sec(_current_beat_index + 1)
	var diff_next: float = next_beat_time - _song_time_sec
	if diff_next >= 0.0 and diff_next <= hit_window_early_sec:
		return true
	return false

# ── 移动执行 ─────────────────────────────────────────

## 执行卡点移动（Tween 过渡）
func _do_beat_move(direction: Vector2) -> void:
	_is_moving = true
	_beat_acted = true
	var target_pos: Vector2 = position + direction * tile_size
	beat_move.emit(direction)
	CLog.o("Hit! 方向=%s  目标=%s" % [direction, target_pos])

	if move_tween_duration <= 0.0:
		position = target_pos
		_is_moving = false
		return

	var tween: Tween = create_tween()
	tween.tween_property(self, "position", target_pos, move_tween_duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.finished.connect(_on_move_tween_finished)


## 移动补间完成回调
func _on_move_tween_finished() -> void:
	_is_moving = false


## 踩点失败处理
func _on_miss() -> void:
	beat_miss.emit()
	CLog.w("Miss! song_time=%.3f  beat_index=%d  beat_time=%.3f" % [
		_song_time_sec, _current_beat_index, _get_beat_time_sec(_current_beat_index)
	])

# ── 拾取 & 闪白 ─────────────────────────────────────────

## 被拾取物调用（由外部连接信号）
func on_item_picked_up(_item: PickupItem) -> void:
	item_collected.emit()
	_flash_white()
	# 触发音游轨道序列
	if _rhythm_lane != null and not _rhythm_lane.is_active():
		_lane_active = true
		_rhythm_lane.start_sequence()
		# 隐藏节拍指示器
		if _beat_indicator != null:
			_beat_indicator.visible = false
	CLog.o("拾取物品! 轨道激活=%s" % _lane_active)


## 轨道音符命中回调（由 RhythmLane.note_hit 信号连接）
func on_lane_note_hit(_direction: Vector2) -> void:
	_flash_white()
	CLog.o("轨道命中! 方向=%s" % _direction)


## 轨道序列结束回调：恢复玩家移动
## 延迟一帧再恢复，防止最后一个音符的按键穿透到移动输入
func _on_lane_sequence_finished() -> void:
	await get_tree().process_frame
	_lane_active = false
	# 恢复节拍指示器显示
	if _beat_indicator != null:
		_beat_indicator.visible = true
	CLog.o("轨道序列结束，恢复移动")


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

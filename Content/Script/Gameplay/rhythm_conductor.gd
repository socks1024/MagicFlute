class_name RhythmConductor
extends Node
## 节拍指挥：统一管理 BPM 时钟、节拍判定、输入处理、音效播放，
## 并驱动 RhythmLane 和 BeatIndicator 等 UI 节点。

# ── 信号 ──────────────────────────────────────────────
## 新拍点到达时发出
signal beat_tick(beat_index: int)
## 玩家踩点成功，请求移动（方向）
signal move_requested(direction: Vector2)
## 玩家踩点失败（Miss）
signal move_miss
## 轨道音符命中时转发
signal lane_note_hit(direction: Vector2)
## 轨道音符 Miss 时转发
signal lane_note_miss(direction: Vector2)
## 轨道序列结束时转发
signal lane_sequence_finished

# ── 常量 ─────────────────────────────────────────────
## 轨道方向对应的输入动作（与 RhythmLane.LANE_DIRECTIONS 一致）
const LANE_ACTIONS: Array[StringName] = [
	&"move_up",    # 轨道 0
	&"move_left",  # 轨道 1
	&"move_down",  # 轨道 2
	&"move_right", # 轨道 3
]

# ── 导出属性 ─────────────────────────────────────────
@export_group("节拍")
## 全局 BPM
@export var bpm: float = 120.0
## 首拍偏移时间（秒），用于对齐音乐
@export var first_beat_time_sec: float = 0.0
## 判定窗口（秒）：输入时间与拍点的允许偏差
@export var hit_window_sec: float = 0.15
## 节拍音效事件（场景中静态配置 AudioEvent 资源）
@export var beat_sound: AudioEvent

@export_group("轨道序列")
## 音符从生成到到达判定线所需的拍数（滚动提前量）
@export var scroll_beats: float = 4.0
## 按触发次数预配置的谱面序列
## 每个元素是一个 Array[int]，表示依次出现的轨道索引（0=W,1=A,2=S,3=D）
@export var chart_sequences: Array[PackedInt32Array] = []
## 每次随机生成的默认音符数量
@export var random_note_count: int = 4

@export_group("引用")
## 移动输入上下文资源（场景中静态配置）
@export var move_input_context: InputContext
## RhythmLane 节点路径（场景中静态配置）
@export var rhythm_lane_path: NodePath
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
## 音游轨道引用
var _rhythm_lane: RhythmLane
## 节拍指示器引用
var _beat_indicator: BeatIndicator
## 轨道是否正在激活
var _lane_active: bool = false
## 轨道序列的独立时钟（秒），从序列启动时独立计时
var _lane_time_sec: float = 0.0
## 当前拍是否已经行动过（每拍只允许一次行动）
var _beat_acted: bool = false
## 是否允许处理输入（由外部控制，如移动补间期间禁用）
var _input_enabled: bool = true
## 轨道序列已触发的次数（用于索引 chart_sequences）
var _trigger_count: int = 0

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	_seconds_per_beat = 60.0 / bpm
	# 获取音游轨道引用并连接信号
	if not rhythm_lane_path.is_empty():
		_rhythm_lane = get_node(rhythm_lane_path) as RhythmLane
	if _rhythm_lane != null:
		_rhythm_lane.note_hit.connect(func(dir: Vector2) -> void: lane_note_hit.emit(dir))
		_rhythm_lane.note_miss.connect(func(dir: Vector2) -> void: lane_note_miss.emit(dir))
		_rhythm_lane.sequence_finished.connect(_on_lane_sequence_finished)
		_rhythm_lane.configure(_seconds_per_beat, first_beat_time_sec, hit_window_sec)
	# 获取节拍指示器引用并配置
	if not beat_indicator_path.is_empty():
		_beat_indicator = get_node(beat_indicator_path) as BeatIndicator
	if _beat_indicator != null:
		_beat_indicator.configure(_seconds_per_beat)
	# 激活移动输入上下文
	if move_input_context != null:
		InputManager.add_context(move_input_context)
	# 自动启动节拍时钟
	_start_clock()
	CLog.o("RhythmConductor 就绪 | BPM=%.1f  每拍=%.3fs" % [bpm, _seconds_per_beat])


func _process(delta: float) -> void:
	if not _clock_running:
		return
	_tick_clock(delta)


func _unhandled_input(event: InputEvent) -> void:
	# 轨道激活时，转发输入给 RhythmLane
	if _lane_active:
		for i: int in range(4):
			if event.is_action_pressed(LANE_ACTIONS[i]):
				_try_hit_lane(i)
				return
		return
	if not _input_enabled or _beat_acted:
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
	if is_in_hit_window():
		_beat_acted = true
		move_requested.emit(dir)
		flash_hit()
	else:
		move_miss.emit()
		flash_miss()


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
		# 每拍播放音效
		if beat_sound != null:
			AudioManager.play_sound(beat_sound)
		_beat_acted = false
		beat_tick.emit(_current_beat_index)
	# 每帧向 UI 推送时间数据
	var current_beat_time: float = _get_beat_time_sec(_current_beat_index)
	if _rhythm_lane != null and _rhythm_lane.is_active():
		_lane_time_sec += delta
		_rhythm_lane.update_time(_lane_time_sec)
	if _beat_indicator != null and _beat_indicator.visible:
		_beat_indicator.update_beat(_song_time_sec, current_beat_time)


## 根据时间计算节拍索引
func _compute_beat_index(at_time_sec: float) -> int:
	if _seconds_per_beat <= 0.0:
		return 0
	var elapsed: float = at_time_sec - first_beat_time_sec
	if elapsed < 0.0:
		return -1
	return int(elapsed / _seconds_per_beat)


## 获取指定节拍索引对应的绝对时间
func _get_beat_time_sec(beat_idx: int) -> float:
	return first_beat_time_sec + beat_idx * _seconds_per_beat

# ── 判定逻辑（供外部查询） ───────────────────────────

## 判断当前输入时间是否落在最近拍点的判定窗口内
func is_in_hit_window() -> bool:
	# 检查当前拍点（滞后量）
	var current_beat_time: float = _get_beat_time_sec(_current_beat_index)
	var diff_current: float = _song_time_sec - current_beat_time
	if diff_current >= 0.0 and diff_current <= hit_window_sec:
		return true
	# 检查下一拍点（提前量）
	var next_beat_time: float = _get_beat_time_sec(_current_beat_index + 1)
	var diff_next: float = next_beat_time - _song_time_sec
	if diff_next >= 0.0 and diff_next <= hit_window_sec:
		return true
	return false

# ── 外部控制 ─────────────────────────────────────────

## 设置输入是否启用（Player 移动补间期间应禁用）
func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled


## 启动一段轨道序列
func start_lane_sequence() -> void:
	if _rhythm_lane == null or _rhythm_lane.is_active():
		return
	# 构建本次谱面
	var chart: Array[Dictionary] = _build_chart_for_trigger(_trigger_count)
	_trigger_count += 1
	_lane_active = true
	# 初始化轨道独立时钟：从负的滚动时长开始，与 RhythmLane 内部一致
	var scroll_duration: float = scroll_beats * _seconds_per_beat
	_lane_time_sec = -scroll_duration
	_rhythm_lane.start_sequence(chart, scroll_beats)
	# 隐藏节拍指示器
	if _beat_indicator != null:
		_beat_indicator.visible = false
	CLog.o("RhythmConductor 轨道序列启动 #%d | 音符数=%d" % [_trigger_count, chart.size()])


## 转发输入给 RhythmLane
func _try_hit_lane(lane_idx: int) -> void:
	if _rhythm_lane != null and _lane_active:
		_rhythm_lane.try_hit_lane(lane_idx)


## 触发命中闪烁
func flash_hit() -> void:
	if _beat_indicator != null:
		_beat_indicator.flash_hit()


## 触发 Miss 闪烁
func flash_miss() -> void:
	if _beat_indicator != null:
		_beat_indicator.flash_miss()

# ── 内部回调 ─────────────────────────────────────────

## 轨道序列结束回调：延迟一帧再恢复，防止按键穿透
func _on_lane_sequence_finished() -> void:
	await get_tree().process_frame
	_lane_active = false
	# 恢复节拍指示器显示
	if _beat_indicator != null:
		_beat_indicator.visible = true
	lane_sequence_finished.emit()
	CLog.o("RhythmConductor 轨道序列结束")

# ── 谱面构建 ─────────────────────────────────────────

## 根据触发次数构建谱面：优先使用预配置序列，超出后随机生成
func _build_chart_for_trigger(trigger_index: int) -> Array[Dictionary]:
	var chart: Array[Dictionary] = []
	if trigger_index < chart_sequences.size():
		# 使用预配置的谱面
		var lanes: PackedInt32Array = chart_sequences[trigger_index]
		for beat_idx: int in range(lanes.size()):
			chart.append({"beat": beat_idx, "lane": lanes[beat_idx]})
	else:
		# 随机生成
		for beat_idx: int in range(random_note_count):
			var lane_idx: int = randi_range(0, 3)
			chart.append({"beat": beat_idx, "lane": lane_idx})
	return chart

class_name RhythmLane
extends Control
## 横向 FNF 式音游轨道
##
## 平时隐藏，外部调用 start_sequence() 后显示并播放一段谱面。
## 所有音符结算后自动隐藏并发出 sequence_finished 信号。

# ── 信号 ──────────────────────────────────────────────
## 音符命中时发出（携带命中方向）
signal note_hit(direction: Vector2)
## 音符未命中（飘过判定线）时发出
signal note_miss(direction: Vector2)
## 当前序列的所有音符已结算（命中或 Miss），轨道即将隐藏
signal sequence_finished

# ── 轨道方向映射 ─────────────────────────────────────
## 四条轨道对应的方向与输入动作
const LANE_DIRECTIONS: Array[Vector2] = [
	Vector2.UP,    # W - 轨道 0
	Vector2.LEFT,  # A - 轨道 1
	Vector2.DOWN,  # S - 轨道 2
	Vector2.RIGHT, # D - 轨道 3
]
const LANE_ACTIONS: Array[StringName] = [
	&"move_up",
	&"move_left",
	&"move_down",
	&"move_right",
]
const LANE_LABELS: Array[String] = ["W", "A", "S", "D"]
const LANE_COLORS: Array[Color] = [
	Color(0.3, 0.85, 1.0, 1.0),   # W - 青色
	Color(0.3, 1.0, 0.4, 1.0),    # A - 绿色
	Color(1.0, 0.4, 0.6, 1.0),    # S - 粉色
	Color(1.0, 0.8, 0.2, 1.0),    # D - 黄色
]

# ── 节拍 & 滚动参数 ─────────────────────────────────
## BPM（应与 RhythmPlayer 一致）
@export var bpm: float = 120.0
## 首拍偏移（秒）
@export var first_beat_time_sec: float = 0.0
## 音符从生成到到达判定线所需的拍数（决定滚动提前量）
@export var scroll_beats: float = 4.0

# ── 布局参数 ─────────────────────────────────────────
## 音符大小（像素）
@export var note_size: float = 44.0

# ── 判定窗口 ─────────────────────────────────────────
## 命中判定窗口（秒）：音符中心与判定线的时间差在此范围内算命中
@export var hit_window_sec: float = 0.18

# ── 谱面序列配置 ─────────────────────────────────────
## 按触发次数预配置的谱面序列
## 每个元素是一个 Array[int]，表示依次出现的轨道索引（0=W,1=A,2=S,3=D）
## 例如 [[0,1,2,3], [3,2,1,0]] 表示第 1 次触发用 W-A-S-D，第 2 次用 D-S-A-W
## 超出配置数量后随机生成 4 个音符
@export var chart_sequences: Array[PackedInt32Array] = []

## 每次随机生成的默认音符数量
@export var random_note_count: int = 4

# ── 音符场景 ─────────────────────────────────────────
## 音符场景资源（FallingNote）
@export var note_scene: PackedScene

# ── 内部变量 ─────────────────────────────────────────
## 每拍时长（秒）
var _seconds_per_beat: float = 0.5
## 主时钟（秒）
var _song_time_sec: float = 0.0
## 时钟是否运行
var _clock_running: bool = false
## 已生成的音符列表（活跃中）
var _active_notes: Array[FallingNote] = []
## 谱面中下一个待生成的音符索引
var _next_chart_index: int = 0
## 判定线的 X 坐标（相对于本节点）
var _judge_x: float = 0.0
## 每条轨道的 Y 中心坐标
var _lane_centers: Array[float] = []
## 当前序列的谱面数据
var _current_chart: Array[Dictionary] = []
## 当前序列的总音符数
var _total_notes_in_sequence: int = 0
## 当前序列已结算的音符数（命中 + Miss）
var _settled_notes_count: int = 0
## 已触发的次数（用于索引 chart_sequences）
var _trigger_count: int = 0

# ── 场景中静态配置的视觉节点 ────────────────────────
@onready var _judge_line: ColorRect = $JudgeLine

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	_seconds_per_beat = 60.0 / bpm
	# 从判定线节点位置推算判定 X（取判定线中心）
	_judge_x = _judge_line.position.x + _judge_line.size.x * 0.5
	# 从自身尺寸计算每条轨道的 Y 中心
	var lane_h: float = size.y / 4.0
	for i: int in range(4):
		_lane_centers.append(lane_h * i + lane_h * 0.5)
	# 初始隐藏
	visible = false
	CLog.o("RhythmLane 就绪 | BPM=%.1f  判定线X=%.0f" % [bpm, _judge_x])


func _process(delta: float) -> void:
	if not _clock_running:
		return
	_song_time_sec += delta
	# 生成即将进入可视范围的音符
	_spawn_pending_notes()
	# 更新所有活跃音符的位置
	_update_note_positions()
	# 检查飘过判定线的音符（Miss）
	_check_missed_notes()


func _unhandled_input(event: InputEvent) -> void:
	if not _clock_running:
		return
	for i: int in range(4):
		if event.is_action_pressed(LANE_ACTIONS[i]):
			_try_hit(i)
			return

# ── 外部接口 ─────────────────────────────────────────

## 启动一段音符序列：显示轨道，生成谱面，开始滚动
func start_sequence() -> void:
	# 清理上一次残留
	_cleanup()
	# 根据触发次数决定谱面内容
	_current_chart = _build_chart_for_trigger(_trigger_count)
	_trigger_count += 1
	# 按 beat 排序
	_current_chart.sort_custom(_compare_chart_entry)
	# 初始化序列状态
	_total_notes_in_sequence = _current_chart.size()
	_settled_notes_count = 0
	_next_chart_index = 0
	# 从负的滚动时长开始计时，确保最早的音符也从最左侧完整滚入
	var scroll_duration: float = scroll_beats * _seconds_per_beat
	_song_time_sec = -scroll_duration
	# 显示并启动
	visible = true
	_clock_running = true
	CLog.o("RhythmLane 启动序列 #%d | 音符数=%d" % [_trigger_count, _total_notes_in_sequence])


## 是否正在播放序列
func is_active() -> bool:
	return _clock_running

# ── 谱面构建 ─────────────────────────────────────────

## 根据触发次数构建谱面
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


## 谱面排序比较函数
func _compare_chart_entry(a: Dictionary, b: Dictionary) -> bool:
	return int(a["beat"]) < int(b["beat"])

# ── 音符生成 & 位置更新 ─────────────────────────────

## 计算指定节拍索引的绝对时间（秒）
func _get_beat_time(beat_index: int) -> float:
	return first_beat_time_sec + beat_index * _seconds_per_beat


## 根据音符的节拍时间计算其当前 X 坐标
func _get_note_x(beat_time: float) -> float:
	var scroll_duration: float = scroll_beats * _seconds_per_beat
	var elapsed: float = _song_time_sec - (beat_time - scroll_duration)
	var progress: float = elapsed / scroll_duration
	return progress * _judge_x


## 生成即将进入可视范围的音符
func _spawn_pending_notes() -> void:
	if note_scene == null:
		return
	var scroll_duration: float = scroll_beats * _seconds_per_beat
	while _next_chart_index < _current_chart.size():
		var entry: Dictionary = _current_chart[_next_chart_index]
		var beat_idx: int = int(entry["beat"])
		var lane_idx: int = int(entry["lane"])
		var beat_time: float = _get_beat_time(beat_idx)
		var spawn_time: float = beat_time - scroll_duration
		# 只生成 spawn_time 已到达的音符（提前 0.1 秒生成以避免视觉跳变）
		if spawn_time > _song_time_sec + 0.1:
			break
		# 实例化音符
		var note: FallingNote = note_scene.instantiate() as FallingNote
		note.lane_index = lane_idx
		note.beat_index = beat_idx
		note.color = LANE_COLORS[lane_idx]
		note.custom_minimum_size = Vector2(note_size, note_size)
		note.size = Vector2(note_size, note_size)
		# 设置初始位置
		var x: float = _get_note_x(beat_time)
		var y: float = _lane_centers[lane_idx] - note_size * 0.5
		note.position = Vector2(x, y)
		add_child(note)
		# @onready 的 label 在 add_child 后才可用
		note.label.text = LANE_LABELS[lane_idx]
		_active_notes.append(note)
		_next_chart_index += 1


## 更新所有活跃音符的 X 坐标
func _update_note_positions() -> void:
	for note: FallingNote in _active_notes:
		if not is_instance_valid(note):
			continue
		var beat_time: float = _get_beat_time(note.beat_index)
		var x: float = _get_note_x(beat_time)
		note.position.x = x

# ── 判定逻辑 ─────────────────────────────────────────

## 尝试命中指定轨道上最近的音符
func _try_hit(lane_idx: int) -> void:
	var best_note: FallingNote = null
	var best_diff: float = INF
	for note: FallingNote in _active_notes:
		if not is_instance_valid(note):
			continue
		if note.lane_index != lane_idx:
			continue
		var beat_time: float = _get_beat_time(note.beat_index)
		var diff: float = absf(_song_time_sec - beat_time)
		if diff < best_diff:
			best_diff = diff
			best_note = note
	# 判定窗口检查
	if best_note != null and best_diff <= hit_window_sec:
		_on_note_hit(best_note)
	# 若无可命中音符，不做额外惩罚（FNF 风格允许空按）


## 音符命中处理
func _on_note_hit(note: FallingNote) -> void:
	var dir: Vector2 = LANE_DIRECTIONS[note.lane_index]
	note_hit.emit(dir)
	_active_notes.erase(note)
	note.queue_free()
	_settled_notes_count += 1
	CLog.o("音符命中! 轨道=%d  方向=%s  (%d/%d)" % [note.lane_index, dir, _settled_notes_count, _total_notes_in_sequence])
	_check_sequence_complete()


## 检查飘过判定线且超出判定窗口的音符，判为 Miss
func _check_missed_notes() -> void:
	var to_remove: Array[FallingNote] = []
	for note: FallingNote in _active_notes:
		if not is_instance_valid(note):
			to_remove.append(note)
			continue
		var beat_time: float = _get_beat_time(note.beat_index)
		# 若音符已过判定线且超出判定窗口
		if _song_time_sec - beat_time > hit_window_sec:
			var dir: Vector2 = LANE_DIRECTIONS[note.lane_index]
			note_miss.emit(dir)
			to_remove.append(note)
			_settled_notes_count += 1
			CLog.w("音符 Miss! 轨道=%d  beat=%d  (%d/%d)" % [note.lane_index, note.beat_index, _settled_notes_count, _total_notes_in_sequence])
	for note: FallingNote in to_remove:
		_active_notes.erase(note)
		if is_instance_valid(note):
			note.queue_free()
	if to_remove.size() > 0:
		_check_sequence_complete()

# ── 序列结束检查 ─────────────────────────────────────

## 检查当前序列是否所有音符都已结算
func _check_sequence_complete() -> void:
	if _settled_notes_count >= _total_notes_in_sequence:
		_stop_sequence()


## 停止当前序列，隐藏轨道
func _stop_sequence() -> void:
	_clock_running = false
	_cleanup()
	visible = false
	sequence_finished.emit()
	CLog.o("RhythmLane 序列结束，轨道隐藏")


## 清理所有活跃音符
func _cleanup() -> void:
	for note: FallingNote in _active_notes:
		if is_instance_valid(note):
			note.queue_free()
	_active_notes.clear()
	_current_chart.clear()
	_next_chart_index = 0

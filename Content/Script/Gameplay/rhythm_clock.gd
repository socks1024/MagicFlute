class_name RhythmClock
extends Node
## 纯节拍时钟：只负责 BPM 计时、拍点推进、判定窗口查询，
## 不涉及输入处理和 UI 驱动。

# ── 信号 ──────────────────────────────────────────────
## 新拍点到达时发出
signal beat_tick(beat_index: int)

# ── 导出属性 ─────────────────────────────────────────
## 全局 BPM
@export var bpm: float = 120.0
## 首拍偏移时间（秒），用于对齐音乐
@export var first_beat_time_sec: float = 0.0
## 判定窗口（秒）：输入时间与拍点的允许偏差
@export var hit_window_sec: float = 0.15

# ── 内部变量（运行时） ───────────────────────────────
## 每拍时长（秒），由 BPM 推导
var _seconds_per_beat: float = 0.5
## 节拍主时钟（秒）
var _song_time_sec: float = 0.0
## 当前节拍索引
var _current_beat_index: int = -1
## 节拍时钟是否运行中
var _clock_running: bool = false

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	_seconds_per_beat = 60.0 / bpm
	start()
	CLog.o("RhythmClock 就绪 | BPM=%.1f  每拍=%.3fs" % [bpm, _seconds_per_beat])


func _process(delta: float) -> void:
	if not _clock_running:
		return
	_tick(delta)

# ── 时钟控制 ─────────────────────────────────────────

## 启动节拍时钟
func start() -> void:
	_song_time_sec = 0.0
	_current_beat_index = -1
	_clock_running = true


## 停止节拍时钟
func stop() -> void:
	_clock_running = false

# ── 时钟推进 ─────────────────────────────────────────

## 推进节拍时钟（每帧由 _process 调用）
func _tick(delta: float) -> void:
	_song_time_sec += delta
	var new_beat_index: int = _compute_beat_index(_song_time_sec)
	if new_beat_index > _current_beat_index:
		_current_beat_index = new_beat_index
		beat_tick.emit(_current_beat_index)

# ── 查询接口（供外部读取） ───────────────────────────

## 获取当前歌曲时间（秒）
func get_song_time_sec() -> float:
	return _song_time_sec


## 获取每拍时长（秒）
func get_seconds_per_beat() -> float:
	return _seconds_per_beat


## 获取当前节拍索引
func get_current_beat_index() -> int:
	return _current_beat_index


## 获取指定节拍索引对应的绝对时间
func get_beat_time_sec(beat_idx: int) -> float:
	return first_beat_time_sec + beat_idx * _seconds_per_beat


## 判断当前输入时间是否落在最近拍点的判定窗口内
func is_in_hit_window() -> bool:
	# 检查当前拍点（滞后量）
	var current_beat_time: float = get_beat_time_sec(_current_beat_index)
	var diff_current: float = _song_time_sec - current_beat_time
	if diff_current >= 0.0 and diff_current <= hit_window_sec:
		return true
	# 检查下一拍点（提前量）
	var next_beat_time: float = get_beat_time_sec(_current_beat_index + 1)
	var diff_next: float = next_beat_time - _song_time_sec
	if diff_next >= 0.0 and diff_next <= hit_window_sec:
		return true
	return false

# ── 内部工具 ─────────────────────────────────────────

## 根据时间计算节拍索引
func _compute_beat_index(at_time_sec: float) -> int:
	if _seconds_per_beat <= 0.0:
		return 0
	var elapsed: float = at_time_sec - first_beat_time_sec
	if elapsed < 0.0:
		return -1
	return int(elapsed / _seconds_per_beat)

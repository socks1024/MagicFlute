class_name RhythmConductor
extends Node
## 节拍指挥：协调 RhythmClock、输入处理、音效播放，
## 并驱动 RhythmLane 和 BeatIndicator 等 UI 节点。

# ── 信号 ──────────────────────────────────────────────
## 新拍点到达时发出（转发自 RhythmClock）
signal beat_tick(beat_index: int)
## 玩家踩点成功，请求移动（方向）
signal move_requested(direction: Vector2)
## 玩家踩点失败（Miss）
signal move_miss
## 轨道音符命中时转发
signal lane_note_hit(direction: Vector2)
## 轨道音符 Miss 时转发
signal lane_note_miss(direction: Vector2)
## 轨道序列开始时发出
signal lane_sequence_started
## 轨道序列结束时转发（is_full_combo: 是否全部命中）
signal lane_sequence_finished(is_full_combo: bool)
## 移动节拍：仅在非 lane 模式的拍点时发出，供需要按拍移动的实体使用
signal move_beat_tick(beat_index: int)
## 阶段推进时发出（新阶段索引）
signal stage_advanced(stage_index: int)

# ── 导出属性 ─────────────────────────────────────────
@export_group("轨道序列")
## 音符从生成到到达判定线所需的拍数（滚动提前量）
@export var scroll_beats: float = 4.0
## 按阶段配置的音符序列组（每个 LaneStage 包含若干段 lane 序列）
@export var lane_stages: Array[LaneStage] = []



@export_group("引用")
## 移动输入上下文资源（场景中静态配置）
@export var move_input_context: InputContext
## RhythmClock 节点路径（场景中静态配置）
@export var rhythm_clock_path: NodePath
## RhythmLane 节点路径（场景中静态配置）
@export var rhythm_lane_path: NodePath
## BeatIndicator 节点路径（场景中静态配置）
@export var beat_indicator_path: NodePath

# ── 内部变量（运行时） ───────────────────────────────
## 节拍时钟引用
var _clock: RhythmClock
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
## 当前阶段索引（对应 lane_stages 中的下标）
var _current_stage: int = 0
## 当前阶段内已消费的序列索引
var _stage_seq_index: int = 0

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	# 获取节拍时钟引用并连接信号
	if not rhythm_clock_path.is_empty():
		_clock = get_node(rhythm_clock_path) as RhythmClock
	if _clock != null:
		_clock.beat_tick.connect(_on_beat_tick)
	# 获取音游轨道引用并连接信号
	if not rhythm_lane_path.is_empty():
		_rhythm_lane = get_node(rhythm_lane_path) as RhythmLane
	if _rhythm_lane != null and _clock != null:
		_rhythm_lane.note_hit.connect(func(dir: Vector2) -> void: lane_note_hit.emit(dir))
		_rhythm_lane.note_miss.connect(func(dir: Vector2) -> void: lane_note_miss.emit(dir))
		_rhythm_lane.sequence_finished.connect(_on_lane_sequence_finished)
		_rhythm_lane.configure(_clock.get_seconds_per_beat(), _clock.first_beat_time_sec, _clock.hit_window_sec)
	# 获取节拍指示器引用并配置
	if not beat_indicator_path.is_empty():
		_beat_indicator = get_node(beat_indicator_path) as BeatIndicator
	if _beat_indicator != null and _clock != null:
		_beat_indicator.configure(_clock.get_seconds_per_beat())
	# 激活移动输入上下文
	if move_input_context != null:
		InputManager.add_context(move_input_context)
	CLog.o("RhythmConductor 就绪")


func _process(delta: float) -> void:
	if _clock == null:
		return
	# 每帧向 UI 推送时间数据
	var song_time: float = _clock.get_song_time_sec()
	var current_beat_time: float = _clock.get_beat_time_sec(_clock.get_current_beat_index())
	if _rhythm_lane != null and _rhythm_lane.is_active():
		_lane_time_sec += delta
		_rhythm_lane.update_time(_lane_time_sec)
	if _beat_indicator != null and _beat_indicator.visible:
		_beat_indicator.update_beat(song_time, current_beat_time)


func _unhandled_input(event: InputEvent) -> void:
	# 轨道激活时，将方向输入映射为轨道索引转发给 RhythmLane
	if _lane_active:
		var lane_idx: int = _get_lane_index_from_event(event)
		if lane_idx >= 0:
			_try_hit_lane(lane_idx)
		return
	if _beat_acted:
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
	if _clock != null and _clock.is_in_hit_window():
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

# ── 时钟回调 ─────────────────────────────────────────

## 节拍到达回调（来自 RhythmClock）
func _on_beat_tick(beat_index: int) -> void:
	_beat_acted = false
	beat_tick.emit(beat_index)
	# 非 lane 模式时发出移动节拍信号
	if not _lane_active:
		move_beat_tick.emit(beat_index)

# ── 外部控制 ─────────────────────────────────────────

## 启动一段轨道序列
func start_lane_sequence() -> void:
	if _rhythm_lane == null or _rhythm_lane.is_active() or _clock == null:
		return
	# 构建本次谱面
	var chart: Array[Dictionary] = _build_chart_for_trigger()
	_lane_active = true
	# 初始化轨道独立时钟：从负的滚动时长开始，与 RhythmLane 内部一致
	var scroll_duration: float = scroll_beats * _clock.get_seconds_per_beat()
	_lane_time_sec = -scroll_duration
	_rhythm_lane.start_sequence(chart, scroll_beats)
	lane_sequence_started.emit()
	# 隐藏节拍指示器
	if _beat_indicator != null:
		_beat_indicator.visible = false
	CLog.o("RhythmConductor 轨道序列启动 | 阶段=%d 序列=%d 音符数=%d" % [_current_stage, _stage_seq_index, chart.size()])


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
## 仅在 Full Combo 时推进到下一段序列，否则下次触发仍播放同一段
func _on_lane_sequence_finished(is_full_combo: bool) -> void:
	await get_tree().process_frame
	_lane_active = false
	# Full Combo → 推进序列索引
	if is_full_combo:
		_stage_seq_index += 1
		# 本阶段序列用完 → 推进阶段
		if _current_stage < lane_stages.size():
			var stage: LaneStage = lane_stages[_current_stage]
			if _stage_seq_index >= stage.sequences.size():
				_advance_stage()
		CLog.o("序列推进 → 阶段=%d 序列=%d" % [_current_stage, _stage_seq_index])
	else:
		CLog.o("未通关，下次重复当前序列 | 阶段=%d 序列=%d" % [_current_stage, _stage_seq_index])
	# 恢复节拍指示器显示
	if _beat_indicator != null:
		_beat_indicator.visible = true
	lane_sequence_finished.emit(is_full_combo)

# ── 输入映射 ─────────────────────────────────────────

## 从输入事件解析轨道索引（0~3），无匹配返回 -1
func _get_lane_index_from_event(event: InputEvent) -> int:
	if event.is_action_pressed("move_up"):
		return 0
	if event.is_action_pressed("move_left"):
		return 1
	if event.is_action_pressed("move_down"):
		return 2
	if event.is_action_pressed("move_right"):
		return 3
	return -1

# ── 谱面构建 ─────────────────────────────────────────

## 构建谱面：按阶段消费预配置序列；全部用完后重复最后一段
## 注意：此处只读取当前序列，不推进索引；推进由 _on_lane_sequence_finished 控制
func _build_chart_for_trigger() -> Array[Dictionary]:
	var seq: LaneSequence = _resolve_current_sequence()
	var chart: Array[Dictionary] = []
	for beat_idx: int in range(seq.notes.size()):
		chart.append({"beat": beat_idx, "lane": seq.notes[beat_idx] as int})
	return chart


## 获取当前应播放的序列；若索引越界则回退到最后一个阶段的最后一段序列
func _resolve_current_sequence() -> LaneSequence:
	assert(not lane_stages.is_empty(), "RhythmConductor: lane_stages 不能为空，请在编辑器中配置音符序列")
	# 当前阶段仍有序列可用
	if _current_stage < lane_stages.size():
		var stage: LaneStage = lane_stages[_current_stage]
		if _stage_seq_index < stage.sequences.size():
			return stage.sequences[_stage_seq_index]
	# 所有阶段已用完 → 取最后一个阶段的最后一段序列
	var last_stage: LaneStage = lane_stages[lane_stages.size() - 1]
	assert(not last_stage.sequences.is_empty(), "RhythmConductor: 最后一个 LaneStage 的 sequences 不能为空")
	return last_stage.sequences[last_stage.sequences.size() - 1]


## 推进到下一阶段，重置阶段内序列计数器
func _advance_stage() -> void:
	_current_stage += 1
	_stage_seq_index = 0
	stage_advanced.emit(_current_stage)
	CLog.o("RhythmConductor 阶段推进 → #%d" % _current_stage)

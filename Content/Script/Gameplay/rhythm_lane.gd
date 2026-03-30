class_name RhythmLane
extends Control
## 横向 FNF 式音游轨道（支持通用音符贴图）
##
## 平时隐藏，外部调用 start_sequence() 后显示并播放一段谱面。
## 所有音符结算后自动隐藏并发出 sequence_finished 信号。
## 本节点不负责逻辑时钟和输入处理，所有数据由外部（RhythmConductor）传入。

# ── 信号 ──────────────────────────────────────────────
## 音符命中时发出（携带命中方向）
signal note_hit(direction: Vector2)
## 音符未命中（飘过判定线）时发出
signal note_miss(direction: Vector2)
## 当前序列的所有音符已结算（命中或 Miss），轨道即将隐藏
## is_full_combo: 是否全部命中（无 Miss）
signal sequence_finished(is_full_combo: bool)

# ── 轨道方向映射 ─────────────────────────────────────
## 四条轨道对应的方向与输入动作
const LANE_DIRECTIONS: Array[Vector2] = [
	Vector2.UP,    # W - 轨道 0
	Vector2.LEFT,  # A - 轨道 1
	Vector2.DOWN,  # S - 轨道 2
	Vector2.RIGHT, # D - 轨道 3
]
const LANE_LABELS: Array[String] = ["↑", "←", "↓", "→"]
const LANE_COLORS: Array[Color] = [
	Color(0.3, 0.85, 1.0, 1.0),   # W - 青色
	Color(0.3, 1.0, 0.4, 1.0),    # A - 绿色
	Color(1.0, 0.4, 0.6, 1.0),    # S - 粉色
	Color(1.0, 0.8, 0.2, 1.0),    # D - 黄色
]

# ── 布局参数（纯视觉） ──────────────────────────────
## 音符大小（像素）
@export var note_size: float = 44.0

# ── 轨道位置自定义 ──────────────────────────────────
## 是否显示轨道轨迹线（仅在编辑器中可见）
@export var show_track_lines: bool = true:
	set(value):
		show_track_lines = value
		queue_redraw()

## 轨道 Y 坐标（像素），可以手动调整每条轨道的 Y 中心位置
@export var track_y_positions: Array[float] = [80.0, 160.0, 240.0, 320.0]:
	set(value):
		track_y_positions = value
		_update_lane_centers()
		queue_redraw()

## 是否使用自定义轨道位置（false 时自动计算）
@export var use_custom_track_positions: bool = true:
	set(value):
		use_custom_track_positions = value
		_update_lane_centers()
		queue_redraw()

# ── 音符贴图资源（通用）─────────────────────────────
## 通用音符贴图（所有方向使用同一张贴图）
@export var note_texture: Texture2D

# ── 音符场景 ─────────────────────────────────────────
## 音符场景资源（FallingNote）
@export var note_scene: PackedScene

# ── 内部变量 ─────────────────────────────────────────
## 每拍时长（秒），由外部通过 configure() 设置
var _seconds_per_beat: float = 0.5
## 首拍偏移（秒），由外部通过 configure() 设置
var _first_beat_time_sec: float = 0.0
## 命中判定窗口（秒），由外部通过 configure() 设置
var _hit_window_sec: float = 0.18
## 当前序列的滚动拍数，由外部通过 start_sequence() 传入
var _scroll_beats: float = 4.0
## 主时钟（秒），由外部通过 update_time() 每帧推入
var _song_time_sec: float = 0.0
## 序列是否正在运行
var _active: bool = false
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
## 当前序列的 Miss 次数
var _miss_count: int = 0

# ── 场景中静态配置的视觉节点 ────────────────────────
@onready var _judge_line: ColorRect = $JudgeLine

# ── 四个轨道的粒子系统（需要在场景中创建并命名）────
@onready var firework_w: GPUParticles2D = $Firework_W
@onready var firework_a: GPUParticles2D = $Firework_A
@onready var firework_s: GPUParticles2D = $Firework_S
@onready var firework_d: GPUParticles2D = $Firework_D

# ── 四个轨道的打击感贴图（需要在场景中创建并命名）────
@onready var hit_effect_w: TextureRect = $HitEffect_W
@onready var hit_effect_a: TextureRect = $HitEffect_A
@onready var hit_effect_s: TextureRect = $HitEffect_S
@onready var hit_effect_d: TextureRect = $HitEffect_D

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	# 从判定线节点位置推算判定 X（取判定线中心）
	_judge_x = _judge_line.position.x + _judge_line.size.x * 0.5
	# 初始化轨道位置
	_update_lane_centers()
	# 初始隐藏
	visible = false
	
	# 调试：检查节点是否存在
	print("=== 检查打击感节点 ===")
	print("HitEffect_W: ", hit_effect_w)
	print("HitEffect_A: ", hit_effect_a)
	print("HitEffect_S: ", hit_effect_s)
	print("HitEffect_D: ", hit_effect_d)
	
	# 设置打击感贴图的初始状态（正常显示）
	_setup_hit_effects()
	
	CLog.o("RhythmLane 就绪 | 判定线X=%.0f" % _judge_x)


## 初始化打击感效果节点
func _setup_hit_effects() -> void:
	var effects = [hit_effect_w, hit_effect_a, hit_effect_s, hit_effect_d]
	for effect in effects:
		if effect != null:
			# 设置为正常显示（完全不透明）
			effect.modulate = Color(1.0, 1.0, 1.0, 1.0)


## 播放打击感闪烁效果（缩放 + 闪烁，更明显）
func _play_hit_flash(effect: TextureRect) -> void:
	if effect == null:
		print("错误：打击感节点为空")
		return
	
	print("播放打击效果: ", effect.name)
	
	# 停止当前所有动画
	var tween = effect.create_tween()
	tween.kill()
	
	# 保存原始状态
	var original_scale = effect.scale
	var original_color = effect.modulate
	
	# 第一步：瞬间放大并变色
	effect.scale = original_scale * 1.3
	effect.modulate = Color(1.0, 0.5, 0.0, 1.0)  # 橙色
	
	# 第二步：缩小并恢复颜色
	tween = effect.create_tween()
	tween.set_parallel(true)  # 并行执行
	
	# 缩放动画
	tween.tween_property(effect, "scale", original_scale, 0.12).set_ease(Tween.EASE_OUT)
	
	# 颜色动画（金色 -> 白色）
	tween.tween_property(effect, "modulate", Color(1.0, 0.9, 0.3, 1.0), 0.05)
	tween.tween_property(effect, "modulate", original_color, 0.1).set_delay(0.05)


func _process(_delta: float) -> void:
	if not _active:
		return
	# 生成即将进入可视范围的音符
	_spawn_pending_notes()
	# 更新所有活跃音符的位置
	_update_note_positions()
	# 检查飘过判定线的音符（Miss）
	_check_missed_notes()


func _input(event: InputEvent) -> void:
	# 只在序列激活时处理输入
	if not _active:
		return
	
	# 检测 WASD 按键
	if event.is_pressed() and not event.is_echo():
		if event.is_action_pressed("move_up"):      # W 键
			print("按下 W 键")
			_play_hit_flash(hit_effect_w)
			_play_firework_at_lane(0)
			try_hit_lane(0)
		elif event.is_action_pressed("move_left"):   # A 键
			print("按下 A 键")
			_play_hit_flash(hit_effect_a)
			_play_firework_at_lane(1)
			try_hit_lane(1)
		elif event.is_action_pressed("move_down"):   # S 键
			print("按下 S 键")
			_play_hit_flash(hit_effect_s)
			_play_firework_at_lane(2)
			try_hit_lane(2)
		elif event.is_action_pressed("move_right"):  # D 键
			print("按下 D 键")
			_play_hit_flash(hit_effect_d)
			_play_firework_at_lane(3)
			try_hit_lane(3)


func _draw() -> void:
	# 绘制轨道轨迹线（仅在编辑器中显示，用于可视化调整）
	if not Engine.is_editor_hint() and not show_track_lines:
		return
	
	# 绘制判定线位置的辅助线（垂直线）
	var judge_line_x: float = _judge_line.position.x + _judge_line.size.x * 0.5
	draw_line(Vector2(judge_line_x, 0), Vector2(judge_line_x, size.y), Color(1.0, 1.0, 0.0, 0.5), 2.0)
	
	# 绘制每条轨道的轨迹线
	for i: int in range(_lane_centers.size()):
		var y_center: float = _lane_centers[i]
		var y_top: float = y_center - note_size * 0.5
		var y_bottom: float = y_center + note_size * 0.5
		var lane_color: Color = LANE_COLORS[i]
		lane_color.a = 0.3  # 半透明
		
		# 绘制轨道区域（矩形）
		var rect: Rect2 = Rect2(0, y_top, size.x, note_size)
		draw_rect(rect, lane_color, false, 2.0)
		
		# 绘制轨道中心线
		draw_line(Vector2(0, y_center), Vector2(size.x, y_center), lane_color, 1.0)
		
		# 绘制轨道标签文字（仅在编辑器中）
		if Engine.is_editor_hint():
			var label_text: String = LANE_LABELS[i]
			var font: Font = ThemeDB.fallback_font
			var font_size: int = 16
			var text_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var text_pos: Vector2 = Vector2(5, y_center - text_size.y * 0.5)
			draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, lane_color)


## 更新轨道中心位置
func _update_lane_centers() -> void:
	_lane_centers.clear()
	
	if use_custom_track_positions and track_y_positions.size() == 4:
		# 使用自定义位置
		for i: int in range(4):
			_lane_centers.append(track_y_positions[i])
	else:
		# 自动计算位置（平分高度）
		var lane_h: float = size.y / 4.0
		for i: int in range(4):
			_lane_centers.append(lane_h * i + lane_h * 0.5)
	
	# 输出调试信息
	CLog.o("轨道位置已更新: %s" % _lane_centers)


func _resized() -> void:
	# 当节点大小改变时重新计算轨道位置
	if not use_custom_track_positions:
		_update_lane_centers()
	queue_redraw()

# ── 烟花效果 ─────────────────────────────────────────

## 在指定轨道播放烟花效果（使用场景中配置好的粒子系统）
func _play_firework_at_lane(lane_idx: int) -> void:
	# 根据轨道索引获取对应的粒子系统
	var particles: GPUParticles2D = null
	match lane_idx:
		0: particles = firework_w   # W 键
		1: particles = firework_a   # A 键
		2: particles = firework_s   # S 键
		3: particles = firework_d   # D 键
	
	# 检查粒子系统是否存在
	if particles == null:
		CLog.w("轨道 %d 的粒子系统不存在" % lane_idx)
		return
	
	# 播放烟花（重启粒子系统）
	particles.restart()
	particles.emitting = true
	CLog.o("播放烟花 - 轨道: %d" % lane_idx)

# ── 辅助函数 ─────────────────────────────────────────

## 获取通用音符贴图
func _get_note_texture() -> Texture2D:
	return note_texture

# ── 外部接口 ─────────────────────────────────────────

## 配置节拍参数（由 RhythmConductor 在初始化或 BPM 变化时调用）
func configure(seconds_per_beat: float, first_beat_time: float, hit_window: float) -> void:
	_seconds_per_beat = seconds_per_beat
	_first_beat_time_sec = first_beat_time
	_hit_window_sec = hit_window
	CLog.o("RhythmLane 配置更新 | SPB=%.3f  首拍偏移=%.3f  判定窗口=%.3f" % [_seconds_per_beat, _first_beat_time_sec, _hit_window_sec])


## 每帧由外部推入当前歌曲时间
func update_time(song_time_sec: float) -> void:
	_song_time_sec = song_time_sec


## 启动一段音符序列：显示轨道，播放外部传入的谱面
## chart: 谱面数据数组，每项为 {"beat": int, "lane": int}
## scroll_beats: 音符从生成到到达判定线所需的拍数
func start_sequence(chart: Array[Dictionary], scroll_beats: float) -> void:
	# 清理上一次残留
	_cleanup()
	# 接收外部传入的谱面与滚动拍数
	_scroll_beats = scroll_beats
	_current_chart = chart
	_current_chart.sort_custom(_compare_chart_entry)
	# 初始化序列状态
	_total_notes_in_sequence = _current_chart.size()
	_settled_notes_count = 0
	_miss_count = 0
	_next_chart_index = 0
	# 从负的滚动时长开始计时，确保最早的音符也从最左侧完整滚入
	var scroll_duration: float = _scroll_beats * _seconds_per_beat
	_song_time_sec = -scroll_duration
	# 显示并启动
	visible = true
	_active = true
	CLog.o("RhythmLane 启动序列 | 音符数=%d  滚动拍数=%.1f" % [_total_notes_in_sequence, _scroll_beats])


## 是否正在播放序列
func is_active() -> bool:
	return _active


## 外部调用：尝试命中指定轨道（由 Player 转发输入时调用）
func try_hit_lane(lane_idx: int) -> void:
	if not _active:
		return
	_try_hit(lane_idx)

## 谱面排序比较函数
func _compare_chart_entry(a: Dictionary, b: Dictionary) -> bool:
	return int(a["beat"]) < int(b["beat"])

# ── 音符生成 & 位置更新 ─────────────────────────────

## 计算指定节拍索引的绝对时间（秒）
func _get_beat_time(beat_index: int) -> float:
	return _first_beat_time_sec + beat_index * _seconds_per_beat


## 根据音符的节拍时间计算其当前 X 坐标
func _get_note_x(beat_time: float) -> float:
	var scroll_duration: float = _scroll_beats * _seconds_per_beat
	var elapsed: float = _song_time_sec - (beat_time - scroll_duration)
	var progress: float = elapsed / scroll_duration
	return progress * _judge_x


## 生成即将进入可视范围的音符
func _spawn_pending_notes() -> void:
	if note_scene == null:
		return
	var scroll_duration: float = _scroll_beats * _seconds_per_beat
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
		# 设置大小
		note.custom_minimum_size = Vector2(note_size, note_size)
		note.size = Vector2(note_size, note_size)
		
		# 设置通用音符贴图
		var note_texture_common: Texture2D = _get_note_texture()
		if note_texture_common != null:
			# 如果 FallingNote 是 TextureRect，直接设置 texture 属性
			if note is TextureRect:
				note.texture = note_texture_common
			# 或者如果有 texture 属性
			elif "texture" in note:
				note.texture = note_texture_common
		
		# 设置标签文字
		if note.label:
			note.label.text = LANE_LABELS[lane_idx]
			# 如果使用了贴图，可以隐藏文字
			if note_texture_common != null:
				note.label.visible = false
			else:
				note.label.visible = true
		
		# 设置初始位置 - 使用更新后的轨道中心
		var x: float = _get_note_x(beat_time)
		var y: float = _lane_centers[lane_idx] - note_size * 0.5
		note.position = Vector2(x, y)
		add_child(note)
		
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
	if best_note != null and best_diff <= _hit_window_sec:
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
## 一旦出现 Miss 立即结束整段序列（is_full_combo = false）
func _check_missed_notes() -> void:
	for note: FallingNote in _active_notes:
		if not is_instance_valid(note):
			continue
		var beat_time: float = _get_beat_time(note.beat_index)
		# 若音符已过判定线且超出判定窗口 → Miss，直接结束序列
		if _song_time_sec - beat_time > _hit_window_sec:
			var dir: Vector2 = LANE_DIRECTIONS[note.lane_index]
			note_miss.emit(dir)
			_miss_count += 1
			CLog.w("音符 Miss! 轨道=%d  beat=%d → 序列中断" % [note.lane_index, note.beat_index])
			_stop_sequence()
			return

# ── 序列结束检查 ─────────────────────────────────────

## 检查当前序列是否所有音符都已结算
func _check_sequence_complete() -> void:
	if _settled_notes_count >= _total_notes_in_sequence:
		_stop_sequence()


## 停止当前序列，隐藏轨道
func _stop_sequence() -> void:
	_active = false
	_cleanup()
	visible = false
	var is_full_combo: bool = _miss_count == 0
	sequence_finished.emit(is_full_combo)
	CLog.o("RhythmLane 序列结束，轨道隐藏 | Full Combo=%s" % is_full_combo)


## 清理所有活跃音符
func _cleanup() -> void:
	for note: FallingNote in _active_notes:
		if is_instance_valid(note):
			note.queue_free()
	_active_notes.clear()
	_current_chart.clear()
	_next_chart_index = 0

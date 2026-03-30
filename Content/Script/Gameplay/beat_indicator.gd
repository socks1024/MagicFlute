class_name BeatIndicator
extends Control
## 节拍指示条：屏幕底部的心跳条，辅助玩家打拍子（节奏地牢式）
##
## 水平条上有一条中心判定线，光标从两侧同时向中心匀速汇聚，
## 每个光标到达中心即为拍点，光标之间间隔 1 拍。
## 本节点不负责逻辑，所有节拍数据由外部（RhythmConductor）传入。

# ── 子节点引用（场景中静态配置） ─────────────────────
@onready var _background: ColorRect = $Background
@onready var _center_line: TextureRect = $Line/CenterLine

# ── 光标参数 ──────────────────────────────────────
## 光标场景资源
@export var cursor_scene: PackedScene
## 同时在条上流动的光标数量（必须为偶数，左右各一半）
@export var cursor_count: int = 4
## 光标竖条宽度（像素）
@export var cursor_width: float = 4.0
## 光标竖条高度（像素），0 表示与背景条等高
@export var cursor_height: float = 0.0

# ── 闪烁颜色 ─────────────────────────────────────────
## 光标默认颜色（shader 着色目标色，默认不着色）
@export var cursor_default_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## 光标命中时闪烁色
@export var cursor_hit_color: Color = Color(1.0, 0.95, 0.2, 1.0)
## 光标 Miss 时闪烁色
@export var cursor_miss_color: Color = Color(1.0, 0.2, 0.2, 1.0)

# ── 内部变量（由外部通过方法传入） ─────────────────
## 每拍时长（秒）
var _seconds_per_beat: float = 0.5
## 当前歌曲时间（秒）
var _song_time_sec: float = 0.0
## 当前拍点时间（秒）
var _current_beat_time: float = 0.0

## 所有光标竖条节点（运行时动态实例化）
var _cursors: Array[TextureRect] = []
## 光标是否属于左侧组（true=从左往中间，false=从右往中间）
var _cursor_from_left: Array[bool] = []
## 光标闪烁计时器
var _flash_timer: float = 0.0
## 闪烁持续时长（秒）
var _flash_duration: float = 0.15
## 当前闪烁颜色
var _flash_color: Color = Color.TRANSPARENT
## CenterLine 缩放弹簧
var _spring_scale: SpringVector2

@export_group("CenterLine Spring")
## 弹簧阻尼（0~1，越大越快停下）
@export_range(0.0, 1.0) var spring_damping: float = 0.5
## 弹簧频率（越大弹得越快）
@export_range(1.0, 30.0) var spring_frequency: float = 12.0
## 命中时缩放 bump 幅度
@export var scale_bump_amount: float = 0.3

# ── 生命周期 ───────────────────────────────────────

func _ready() -> void:
	# 确保光标数量为偶数（左右对称）
	if cursor_count % 2 != 0:
		cursor_count += 1
	# 动态实例化光标，前半从左侧进入，后半从右侧进入
	if cursor_scene != null:
		@warning_ignore("INTEGER_DIVISION")
		var half: int = cursor_count / 2
		for i: int in range(cursor_count):
			var cursor: TextureRect = cursor_scene.instantiate() as TextureRect
			cursor.name = "Cursor%d" % i
			# 右侧组的光标水平翻转，增加视觉区分
			if i >= half:
				cursor.flip_h = true
			add_child(cursor)
			_cursors.append(cursor)
			_cursor_from_left.append(i < half)

	# 设置自身不拦截鼠标
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 当背景条尺寸变化时重新布局（由容器驱动）
	if _background != null:
		_background.resized.connect(_setup_layout)
	# 初始化子节点尺寸（只设置大小和水平位置，不改变Y坐标）
	_setup_layout()
	# 初始化中心线缩放弹簧（以场景中的 scale 为基准）
	var base_scale: Vector2 = _center_line.scale if _center_line != null else Vector2.ONE
	_spring_scale = SpringVector2.new(base_scale, spring_damping, spring_frequency)


func _process(delta: float) -> void:
	# 闪烁衰减
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_timer = 0.0
	# 更新中心线闪烁颜色
	_update_center_line_flash()
	# 更新所有光标位置
	_update_cursors()


func _physics_process(delta: float) -> void:
	# 在固定时间步长中更新弹簧，确保不同帧率下行为一致
	_spring_scale.update(delta)
	if _center_line != null:
		_center_line.scale = _spring_scale.current

# ── 外部接口 ─────────────────────────────────────────

## 配置节拍参数（由 RhythmConductor 在初始化或 BPM 变化时调用）
func configure(seconds_per_beat: float) -> void:
	_seconds_per_beat = seconds_per_beat


## 每帧由外部推入当前节拍数据
func update_beat(song_time_sec: float, current_beat_time: float) -> void:
	_song_time_sec = song_time_sec
	_current_beat_time = current_beat_time


## 触发命中闪烁（由 RhythmConductor 在成功移动时调用）
func flash_hit() -> void:
	_flash_timer = _flash_duration
	_flash_color = cursor_hit_color
	# 在中心线处播放礼花
	_play_hit_particles()
	_spring_scale.bump(Vector2(scale_bump_amount, scale_bump_amount))


## 触发 Miss 闪烁（由 RhythmConductor 在踩点失败时调用）
func flash_miss() -> void:
	_flash_timer = _flash_duration
	_flash_color = cursor_miss_color

# ── 中心线礼花效果 ───────────────────────────────────

## 在中心线处播放礼花粒子，并用弹簧 bump 让中心线弹一下
func _play_hit_particles() -> void:
	if _center_line == null:
		return
	# 播放礼花粒子
	var particles: GPUParticles2D = _center_line.get_node_or_null("HitParticles") as GPUParticles2D
	if particles != null:
		particles.restart()
		particles.emitting = true
	

# ── 布局初始化 ─────────────────────────────────────

## 根据背景条的实际尺寸，初始化中心线和光标的大小与位置
func _setup_layout() -> void:
	if _background == null:
		return
	# 将 Background 的局部坐标转换为 BeatIndicator 本地坐标
	# var bar_pos: Vector2 = _background.get_global_rect().position - get_global_rect().position
	var bar_size: Vector2 = _background.size

	# ── 中心拍点线：保留场景中摆放的位置，不重新定位 ──
	# 只设置中心线的大小，不修改位置
	# if _center_line != null:
		# 只设置宽度和高度，位置完全保留你在场景中设置的
		# _center_line.size = Vector2(2.0, bar_size.y + 4.0)

	# ── 所有光标竖条的尺寸 ──
	# 只设置大小，不修改任何位置（包括X和Y）
	var ch: float = cursor_height if cursor_height > 0.0 else bar_size.y
	for cur: TextureRect in _cursors:
		cur.size = Vector2(cursor_width, ch)
		# 完全不修改位置，保留场景中摆放的X和Y坐标

# ── 光标更新 ──────────────────────────────────────

## 更新所有光标的水平位置和颜色
func _update_cursors() -> void:
	if _background == null or _cursors.is_empty():
		return
	# 将 Background 的全局位置转换为 BeatIndicator 本地坐标
	var bar_x: float = _background.get_global_rect().position.x - get_global_rect().position.x
	var bar_w: float = _background.size.x

	for i: int in range(_cursors.size()):
		var progress: float = _get_cursor_progress(i)
		var cur: TextureRect = _cursors[i]
		# 光标中心 = bar_x + progress * bar_w
		cur.position.x = bar_x + progress * bar_w - cur.size.x * 0.5
		# 超出背景条范围时隐藏
		cur.visible = (progress >= 0.0 and progress <= 1.0)

## 更新中心线的闪烁颜色
func _update_center_line_flash() -> void:
	if _center_line == null:
		return
	var mat: ShaderMaterial = _center_line.material as ShaderMaterial
	if mat == null:
		return
	var amount: float = 0.0
	var col: Color = cursor_default_color
	if _flash_timer > 0.0:
		amount = _flash_timer / _flash_duration
		col = _flash_color
	mat.set_shader_parameter("base_color", col)
	mat.set_shader_parameter("color_amount", amount)

# ── 节拍进度（节奏地牢式：两侧向中间汇聚） ─────────

## 获取第 i 个光标在条上的进度（0.0 ~ 1.0）
## 左组光标：从 0.0（左边缘）→ 0.5（中心），到达中心即拍点
## 右组光标：从 1.0（右边缘）→ 0.5（中心），到达中心即拍点
## 左右两侧的配对光标同时到达中心线
func _get_cursor_progress(cursor_index: int) -> float:
	if _seconds_per_beat <= 0.0:
		return 0.0
	var spb: float = _seconds_per_beat
	@warning_ignore("INTEGER_DIVISION")
	var half: int = _cursors.size() / 2
	var from_left: bool = _cursor_from_left[cursor_index]

	# 在本侧组内的序号（0, 1, 2...）
	var group_index: int = cursor_index if from_left else cursor_index - half

	# 光标从边缘走到中心的时长 = 每侧光标数 × 每拍时长
	var total_time: float = spb * half

	# 计算半程内的归一化进度 [0, 1)
	# +1.0 使得 song_time 恰好在拍点时光标处于半程末端（即中心线）
	var raw: float = (_song_time_sec - group_index * spb) / total_time + 1.0
	var half_progress: float = fmod(raw, 1.0)
	if half_progress < 0.0:
		half_progress += 1.0

	# 左组：0 → 0.5（边缘到中心）
	# 右组：1 → 0.5（边缘到中心）
	if from_left:
		return half_progress * 0.5
	else:
		return 1.0 - half_progress * 0.5

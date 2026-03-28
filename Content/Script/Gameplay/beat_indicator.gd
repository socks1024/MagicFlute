class_name BeatIndicator
extends Control
## 节拍指示条：屏幕底部的心跳条，辅助玩家打拍子
##
## 水平条上有一条中心判定线和多个从左向右匀速流动的光标竖条，
## 每个光标到达中心即为拍点，光标之间间隔 1 拍。
## 本节点不负责逻辑，所有节拍数据由外部（RhythmConductor）传入。

# ── 子节点引用（场景中静态配置） ─────────────────────
@onready var _background: ColorRect = $Margin/Background
@onready var _center_line: ColorRect = $CenterLine
@onready var _cursor_template: TextureRect = $Cursor  # 改为 TextureRect

# ── 光标参数 ──────────────────────────────────────
## 同时在条上流动的光标数量（也是光标走完全程所需的拍数）
@export var cursor_count: int = 4
## 光标竖条宽度（像素）
@export var cursor_width: float = 4.0
## 光标竖条高度（像素），0 表示与背景条等高
@export var cursor_height: float = 0.0

# ── 闪烁颜色 ─────────────────────────────────────────
## 光标默认颜色（与贴图混合，白色表示完全显示贴图原色）
@export var cursor_default_color: Color = Color(1.0, 1.0, 1.0, 0.0)  # 透明，不可见
## 光标命中时闪烁色
@export var cursor_hit_color: Color = Color(1.0, 0.95, 0.2, 1.0)
## 光标 Miss 时闪烁色
@export var cursor_miss_color: Color = Color(1.0, 0.2, 0.2, 1.0)

# ── 贴图资源 ─────────────────────────────────────────
## 光标贴图
@export var cursor_texture: Texture2D

# ── 内部变量（由外部通过方法传入） ─────────────────
## 每拍时长（秒）
var _seconds_per_beat: float = 0.5
## 当前歌曲时间（秒）
var _song_time_sec: float = 0.0
## 当前拍点时间（秒）
var _current_beat_time: float = 0.0

## 所有光标竖条节点（包括模板 + 克隆）
var _cursors: Array[TextureRect] = []  # 改为 TextureRect
## 光标闪烁计时器
var _flash_timer: float = 0.0
## 闪烁持续时长（秒）
var _flash_duration: float = 0.15
## 当前闪烁颜色
var _flash_color: Color = Color.TRANSPARENT

# ── 生命周期 ───────────────────────────────────────

func _ready() -> void:
	# 设置光标贴图
	if _cursor_template != null and cursor_texture != null:
		_cursor_template.texture = cursor_texture
	
	# 使用模板光标克隆出额外的光标
	if _cursor_template != null:
		_cursors.append(_cursor_template)
		for i: int in range(1, cursor_count):
			var clone: TextureRect = _cursor_template.duplicate() as TextureRect
			clone.name = "Cursor%d" % i
			add_child(clone)
			_cursors.append(clone)
		
		# 设置所有光标的贴图
		for cur in _cursors:
			cur.texture = cursor_texture

	# 设置自身不拦截鼠标
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 当背景条尺寸变化时重新布局（由容器驱动）
	if _background != null:
		_background.resized.connect(_setup_layout)
	# 初始化子节点尺寸（只设置大小和水平位置，不改变Y坐标）
	_setup_layout()


func _process(delta: float) -> void:
	# 闪烁衰减
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_timer = 0.0
	# 更新所有光标位置和颜色
	_update_cursors()

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


## 触发 Miss 闪烁（由 RhythmConductor 在踩点失败时调用）
func flash_miss() -> void:
	_flash_timer = _flash_duration
	_flash_color = cursor_miss_color

# ── 布局初始化 ─────────────────────────────────────

## 根据背景条的实际尺寸，初始化中心线和光标的大小与位置
func _setup_layout() -> void:
	if _background == null:
		return
	# 将 Background 的局部坐标转换为 BeatIndicator 本地坐标
	var bar_pos: Vector2 = _background.get_global_rect().position - get_global_rect().position
	var bar_size: Vector2 = _background.size

	# ── 中心拍点线：保留场景中摆放的位置，不重新定位 ──
	# 只设置中心线的大小，不修改位置
	if _center_line != null:
		# 只设置宽度和高度，位置完全保留你在场景中设置的
		_center_line.size = Vector2(2.0, bar_size.y + 4.0)

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

	# 计算当前颜色（用于 modulate，实现闪烁效果）
	var cur_color: Color = cursor_default_color
	if _flash_timer > 0.0:
		var flash_alpha: float = _flash_timer / _flash_duration
		cur_color = _flash_color * flash_alpha + cursor_default_color * (1.0 - flash_alpha)

	for i: int in range(_cursors.size()):
		var progress: float = _get_cursor_progress(i)
		var cur: TextureRect = _cursors[i]
		# 光标中心 = bar_x + progress * bar_w
		cur.position.x = bar_x + progress * bar_w - cur.size.x * 0.5
		cur.modulate = cur_color  # TextureRect 使用 modulate 而不是 color
		# 超出背景条范围时隐藏
		cur.visible = (progress >= 0.0 and progress <= 1.0)

# ── 节拍进度 ──────────────────────────────────────

## 获取第 i 个光标在条上的进度（0.0 ~ 1.0）
## 每个光标用 cursor_count 拍走完全程，到达 0.5（中心）时恰好是拍点
## 光标之间间隔 1 拍
func _get_cursor_progress(cursor_index: int) -> float:
	if _seconds_per_beat <= 0.0:
		return 0.0
	var spb: float = _seconds_per_beat
	# 光标走完全程的总时长 = cursor_count 拍
	var total_time: float = spb * cursor_count
	# 相对于当前拍点的时间偏移
	var elapsed: float = _song_time_sec - _current_beat_time
	# 第 i 个光标相对于第 0 个光标延迟 i 拍
	# 第 0 个光标在 elapsed=0 时到达中心（progress=0.5）
	# progress = (elapsed + i * spb) / total_time + 0.5
	var raw: float = (elapsed - cursor_index * spb) / total_time + 0.5
	# 用 fmod 使其循环
	var progress: float = fmod(raw, 1.0)
	if progress < 0.0:
		progress += 1.0
	return progress

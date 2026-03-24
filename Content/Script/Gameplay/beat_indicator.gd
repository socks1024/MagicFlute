class_name BeatIndicator
extends Control
## 节拍指示条：屏幕底部的心跳条，辅助玩家打拍子
##
## 水平条上有一条中心判定线和多个从左向右匀速流动的光标竖条，
## 每个光标到达中心即为拍点，光标之间间隔 1 拍。
## 光标数量越多，单个光标越慢（用 cursor_count 拍走完全程）。

# ── 外部引用 ───────────────────────────────────────
## 关联的 RhythmPlayer 节点路径
@export var player_path: NodePath
## 背景横条节点路径
@export var background_path: NodePath
## 中心拍点竖线节点路径
@export var center_line_path: NodePath
## 光标模板节点路径（场景中静态配置的那个 ColorRect）
@export var cursor_path: NodePath

## 运行时解析到的 RhythmPlayer 引用
var player: RhythmPlayer
## 运行时解析到的子节点引用
var background: ColorRect
var center_line: ColorRect

# ── 光标参数 ──────────────────────────────────────
## 同时在条上流动的光标数量（也是光标走完全程所需的拍数）
@export var cursor_count: int = 4
## 光标竖条宽度（像素）
@export var cursor_width: float = 4.0
## 光标竖条高度（像素），0 表示与背景条等高
@export var cursor_height: float = 0.0

# ── 闪烁颜色 ─────────────────────────────────────────
## 光标默认颜色
@export var cursor_default_color: Color = Color(0.3, 0.85, 1.0, 1.0)
## 光标命中时闪烁色
@export var cursor_hit_color: Color = Color(1.0, 0.95, 0.2, 1.0)
## 光标 Miss 时闪烁色
@export var cursor_miss_color: Color = Color(1.0, 0.2, 0.2, 1.0)

# ── 内部变量 ───────────────────────────────────────
## 所有光标竖条节点（包括模板 + 克隆）
var _cursors: Array[ColorRect] = []
## 光标闪烁计时器
var _flash_timer: float = 0.0
## 闪烁持续时长（秒）
var _flash_duration: float = 0.15
## 当前闪烁颜色
var _flash_color: Color = Color.TRANSPARENT

# ── 生命周期 ───────────────────────────────────────

func _ready() -> void:
	# 通过 NodePath 获取引用
	if not player_path.is_empty():
		player = get_node(player_path) as RhythmPlayer
	if not background_path.is_empty():
		background = get_node(background_path) as ColorRect
	if not center_line_path.is_empty():
		center_line = get_node(center_line_path) as ColorRect

	# 获取模板光标并克隆出额外的光标
	var cursor_template: ColorRect = null
	if not cursor_path.is_empty():
		cursor_template = get_node(cursor_path) as ColorRect
	if cursor_template != null:
		_cursors.append(cursor_template)
		# 克隆出 cursor_count - 1 个额外光标
		for i: int in range(1, cursor_count):
			var clone: ColorRect = cursor_template.duplicate() as ColorRect
			clone.name = "Cursor%d" % i
			add_child(clone)
			_cursors.append(clone)

	# 连接玩家信号以驱动闪烁反馈
	if player != null:
		player.beat_move.connect(_on_player_beat_move)
		player.beat_miss.connect(_on_player_beat_miss)
	# 设置自身不拦截鼠标
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 当背景条尺寸变化时重新布局（由容器驱动）
	if background != null:
		background.resized.connect(_setup_layout)
	# 初始化子节点尺寸
	_setup_layout()


func _process(delta: float) -> void:
	if player == null:
		return
	# 闪烁衰减
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_timer = 0.0
	# 更新所有光标位置和颜色
	_update_cursors()

# ── 布局初始化 ─────────────────────────────────────

## 根据背景条的实际尺寸，初始化中心线和光标的大小与位置
func _setup_layout() -> void:
	if background == null:
		return
	# 将 Background 的局部坐标转换为 BeatIndicator 本地坐标
	var bar_pos: Vector2 = background.get_global_rect().position - get_global_rect().position
	var bar_size: Vector2 = background.size
	var center_x: float = bar_pos.x + bar_size.x * 0.5

	# ── 中心拍点线：2px 宽，比背景条上下各多 2px ──
	if center_line != null:
		var line_w: float = 2.0
		center_line.position = Vector2(center_x - line_w * 0.5, bar_pos.y - 2.0)
		center_line.size = Vector2(line_w, bar_size.y + 4.0)

	# ── 所有光标竖条的尺寸和垂直位置 ──
	var ch: float = cursor_height if cursor_height > 0.0 else bar_size.y
	for cur: ColorRect in _cursors:
		cur.size = Vector2(cursor_width, ch)
		cur.position.y = bar_pos.y + (bar_size.y - ch) * 0.5

# ── 光标更新 ──────────────────────────────────────

## 更新所有光标的水平位置和颜色
func _update_cursors() -> void:
	if background == null or _cursors.is_empty():
		return
	# 将 Background 的全局位置转换为 BeatIndicator 本地坐标
	var bar_x: float = background.get_global_rect().position.x - get_global_rect().position.x
	var bar_w: float = background.size.x

	# 计算当前颜色
	var cur_color: Color = cursor_default_color
	if _flash_timer > 0.0:
		var flash_alpha: float = _flash_timer / _flash_duration
		cur_color = _flash_color * flash_alpha + cursor_default_color * (1.0 - flash_alpha)

	for i: int in range(_cursors.size()):
		var progress: float = _get_cursor_progress(i)
		var cur: ColorRect = _cursors[i]
		# 光标中心 = bar_x + progress * bar_w
		cur.position.x = bar_x + progress * bar_w - cur.size.x * 0.5
		cur.color = cur_color
		# 超出背景条范围时隐藏
		cur.visible = (progress >= 0.0 and progress <= 1.0)

# ── 节拍进度 ──────────────────────────────────────

## 获取第 i 个光标在条上的进度（0.0 ~ 1.0）
## 每个光标用 cursor_count 拍走完全程，到达 0.5（中心）时恰好是拍点
## 光标之间间隔 1 拍
func _get_cursor_progress(cursor_index: int) -> float:
	if player == null or player._seconds_per_beat <= 0.0:
		return 0.0
	var spb: float = player._seconds_per_beat
	# 光标走完全程的总时长 = cursor_count 拍
	var total_time: float = spb * cursor_count
	# 当前拍的拍点时间
	var current_beat_time: float = player._get_beat_time_sec(player._current_beat_index)
	# 相对于当前拍点的时间偏移
	var elapsed: float = player._song_time_sec - current_beat_time
	# 第 i 个光标相对于第 0 个光标延迟 i 拍
	# 第 0 个光标在 elapsed=0 时到达中心（progress=0.5）
	# progress = (elapsed + i * spb) / total_time + 0.5
	var raw: float = (elapsed - cursor_index * spb) / total_time + 0.5
	# 用 fmod 使其循环
	var progress: float = fmod(raw, 1.0)
	if progress < 0.0:
		progress += 1.0
	return progress

# ── 信号回调 ──────────────────────────────────────

## 触发命中闪烁
func _on_player_beat_move(_direction: Vector2) -> void:
	_flash_timer = _flash_duration
	_flash_color = cursor_hit_color


## 触发 Miss 闪烁
func _on_player_beat_miss() -> void:
	_flash_timer = _flash_duration
	_flash_color = cursor_miss_color

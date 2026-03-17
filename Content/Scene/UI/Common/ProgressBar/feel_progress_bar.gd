@tool
## Feel 风格进度条
## 包含主进度条和延迟跟随的过渡条（拖尾效果）
class_name FeelProgressBar extends Control

## 动画播放完成信号
signal anim_finished

#region Properties

## 当前进度值（0.0 ~ 1.0）
@export_range(0.0, 1.0) var value: float = 1.0:
	set(v):
		_old_value = value
		value = clampf(v, 0.0, 1.0)
		_animate_bars()

## 主进度条颜色
@export var bar_color: Color = Color(0.2, 0.8, 0.3):
	set(v):
		bar_color = v
		_set_panel_color(_bar, v)

## 背景条颜色
@export var bg_color: Color = Color(0.15, 0.15, 0.15):
	set(v):
		bg_color = v
		_set_panel_color(_bg, v)

@export_group("增加过渡")

## 过渡条预填充颜色（进度增加时显示）
@export var trail_increase_color: Color = Color(0.9, 0.8, 0.2):
	set(v):
		trail_increase_color = v
		_set_panel_color(_trail_increase, v)

## 主条追赶延迟（秒）：过渡条扩展后，主条等待多久再跟上
@export var increase_delay: float = 0.3

## 主条追赶动画时长（秒）
@export var increase_duration: float = 0.5

## 主条追赶缓动曲线（可选，为空则使用默认缓出曲线）
@export var increase_ease_curve: Curve

@export_group("减少过渡")

## 过渡条拖尾颜色（进度减少时显示）
@export var trail_decrease_color: Color = Color(0.9, 0.9, 0.9):
	set(v):
		trail_decrease_color = v
		_set_panel_color(_trail_decrease, v)

## 过渡条追赶延迟（秒）：主条缩短后，过渡条等待多久再追赶
@export var decrease_delay: float = 0.3

## 过渡条追赶动画时长（秒）
@export var decrease_duration: float = 0.5

## 过渡条追赶缓动曲线（可选，为空则使用默认缓入缓出曲线）
@export var decrease_ease_curve: Curve

#endregion

# 内部节点引用
@onready var _bg: Panel = $BG
@onready var _trail_increase: Panel = $TrailIncrease
@onready var _trail_decrease: Panel = $TrailDecrease
@onready var _bar: Panel = $Bar

## 用于增长动画的 tween，控制 _bar 增长到 _trail_increase
var _increase_tween: Tween

## 用于减少动画的 tween，控制 _trail_decrease 缩短到 _bar
var _decrease_tween: Tween

# 上一次的进度值（用于判断增减方向）
var _old_value: float = 1.0


func _ready() -> void:
	# 编辑器中的值需要重新同步，很诡异
	_set_panel_color(_bg, bg_color)
	_set_panel_color(_trail_increase, trail_increase_color)
	_set_panel_color(_trail_decrease, trail_decrease_color)
	_set_panel_color(_bar, bar_color)

	# 预烘焙缓动曲线
	if increase_ease_curve != null:
		increase_ease_curve.bake()
	if decrease_ease_curve != null:
		decrease_ease_curve.bake()

	# 初始化显示
	_set_bar_ratio(_bar, value)
	_set_bar_ratio(_trail_increase, value)
	_set_bar_ratio(_trail_decrease, value)


## 设置进度值
## new_value: 目标进度（0.0 ~ 1.0）
## animated: 是否播放过渡动画，默认为 true
func set_value(new_value: float, animated: bool = true) -> void:
	value = new_value

	if not animated:
		if _increase_tween and _increase_tween.is_valid():	_increase_tween.kill()
		if _decrease_tween and _decrease_tween.is_valid():	_decrease_tween.kill()

		_set_bar_ratio(_bar, value)
		_set_bar_ratio(_trail_increase, value)
		_set_bar_ratio(_trail_decrease, value)


# 应用新的进度值，驱动动画
func _animate_bars() -> void:
	if not is_node_ready():
		return

	if value == _old_value:
		return

	if value < _old_value:
		_apply_decrease()
	else:
		_apply_increase()

#region progress animation

# 进度减少：主条立即缩短，减少过渡条延迟后追赶（拖尾效果）
func _apply_decrease() -> void:
	if _decrease_tween and _decrease_tween.is_valid(): _decrease_tween.kill()
	if _increase_tween and _increase_tween.is_valid(): 
		_increase_tween.kill()
		_set_bar_ratio(_trail_decrease, _old_value)

	_set_bar_ratio(_bar, value)
	_set_bar_ratio(_trail_increase, value)
	
	_decrease_tween = create_tween()
	_start_tween(_decrease_tween, _trail_decrease, decrease_delay, decrease_duration, decrease_ease_curve)


# 进度增加：增加过渡条先扩展到目标值，主条延迟后追上
func _apply_increase() -> void:
	if _increase_tween and _increase_tween.is_valid(): _increase_tween.kill()
	if _decrease_tween and _decrease_tween.is_valid(): _decrease_tween.kill()

	_set_bar_ratio(_trail_decrease, _get_bar_ratio(_bar))
	_set_bar_ratio(_trail_increase, value)

	_increase_tween = create_tween()
	_start_tween(_increase_tween, _bar, increase_delay, increase_duration, increase_ease_curve)


# 创建追赶 tween 并执行动画
func _start_tween(tween: Tween, rect: Panel, delay: float, duration: float, ease_curve: Curve) -> void:
	tween.tween_interval(delay)

	var tweener: MethodTweener = tween.tween_method(
		func(r: float) -> void: _set_bar_ratio(rect, r),
		_get_bar_ratio(rect), value, duration
	)
	
	if ease_curve != null:
		tweener.set_custom_interpolator(TweenUtils.curve_interpolator(ease_curve))
	else:
		tweener.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# 动画结束后发出信号
	tween.tween_callback(func() -> void: 
		_set_bar_ratio(_trail_increase, value)
		_set_bar_ratio(_trail_decrease, value)
		anim_finished.emit()
	)

#endregion

# 设置 Panel 的背景颜色
func _set_panel_color(panel: Panel, color: Color) -> void:
	if panel == null: return
	(panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = color


# 设置某个 Panel 的宽度比例（0.0 ~ 1.0）
func _set_bar_ratio(rect: Panel, ratio: float) -> void:
	if rect == null:
		return
	rect.size.x = size.x * ratio


# 获取某个 Panel 当前的宽度比例
func _get_bar_ratio(rect: Panel) -> float:
	if rect == null or size.x <= 0.0:
		return 0.0
	return rect.size.x / size.x


# 当容器尺寸变化时，同步更新各条的宽度和高度
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if not is_node_ready():
			return
		# 先保存 trail 的当前比例（基于旧 size.x），再用新 size 重新设置
		var trail_decrease_ratio: float = _get_bar_ratio(_trail_decrease)
		var trail_increase_ratio: float = _get_bar_ratio(_trail_increase)
		_set_bar_ratio(_bar, value)
		_set_bar_ratio(_trail_decrease, trail_decrease_ratio)
		_set_bar_ratio(_trail_increase, trail_increase_ratio)

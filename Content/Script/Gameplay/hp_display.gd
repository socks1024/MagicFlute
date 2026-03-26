class_name HpDisplay
extends MarginContainer
## 血量 UI：塞尔达式心形显示，每颗心代表 1 点 HP
##
## 通过 GridSystem2D 的 entity_placed 信号自动发现 RhythmPlayer，
## 连接其 hp_changed 信号以更新心形图标。

# ── 导出变量 ──────────────────────────────────────────
## 心形图标大小（字号）
@export var heart_font_size: int = 28
## 心形之间的间距
@export var heart_separation: int = 2
## 满心颜色
@export var full_heart_color: Color = Color(0.9, 0.15, 0.15, 1.0)
## 空心颜色
@export var empty_heart_color: Color = Color(0.3, 0.3, 0.3, 0.6)

# ── 动画导出变量 ─────────────────────────────────────
@export_group("心形动画")
## 是否启用心形摇晃动画
@export var anim_enabled: bool = true
## 摇晃驱动频率（Hz），控制左右摇晃的快慢
@export var anim_frequency: float = 1.5
## 旋转弹簧刚度，值越大弹簧响应越快
@export var spring_rotation_stiffness: float = 80.0
## 旋转弹簧阻尼，值越大振荡衰减越快
@export var spring_rotation_damping: float = 6.0
## 旋转驱动力幅度（度），控制摇晃角度大小
@export var rotation_amplitude: float = 15.0
## 缩放弹簧刚度
@export var spring_scale_stiffness: float = 60.0
## 缩放弹簧阻尼
@export var spring_scale_damping: float = 5.0
## 缩放驱动力幅度，控制拉伸/压缩程度（0.0 ~ 1.0）
@export var scale_amplitude: float = 0.15
## 缩放驱动频率偏移（Hz），让缩放和旋转不完全同步
@export var scale_frequency_offset: float = 0.3
## 每颗心的动画相位偏移（度），让相邻心形错开运动
@export var phase_offset_per_heart: float = 30.0

# ── 内部变量 ──────────────────────────────────────────
## 心形 Label 节点列表
var _hearts: Array[Label] = []
## 弹簧状态：旋转 [当前值, 速度]
var _spring_rotations: Array[Array] = []
## 弹簧状态：缩放 [当前值, 速度]
var _spring_scales: Array[Array] = []
## 动画时间累加器
var _anim_time: float = 0.0

# ── 子节点引用 ────────────────────────────────────────
@onready var _container: HBoxContainer = $HBoxContainer

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	# 监听 GridSystem2D 的实体放置信号，自动发现 RhythmPlayer
	var grid: GridSystem2D = %GridSystem2D as GridSystem2D
	if grid != null:
		grid.entity_placed.connect(_on_entity_placed)
	# 设置心形间距
	if _container != null:
		_container.add_theme_constant_override("separation", heart_separation)
	CLog.o("HpDisplay 就绪（心形模式）")

func _process(delta: float) -> void:
	if not anim_enabled:
		return
	if _hearts.is_empty():
		return

	_anim_time += delta

	for i: int in range(_hearts.size()):
		var heart: Label = _hearts[i]
		if not is_instance_valid(heart):
			continue

		# 确保弹簧状态数组足够长
		while _spring_rotations.size() <= i:
			_spring_rotations.append([0.0, 0.0])
		while _spring_scales.size() <= i:
			_spring_scales.append([0.0, 0.0])

		# 每颗心的相位偏移
		var phase: float = deg_to_rad(phase_offset_per_heart * i)

		# ── 旋转弹簧 ──
		var rot_target: float = sin(_anim_time * anim_frequency * TAU + phase) * rotation_amplitude
		var rot_state: Array = _spring_rotations[i]
		var rot_current: float = rot_state[0]
		var rot_velocity: float = rot_state[1]
		# 弹簧加速度 = -刚度 * (当前 - 目标) - 阻尼 * 速度
		var rot_accel: float = -spring_rotation_stiffness * (rot_current - rot_target) - spring_rotation_damping * rot_velocity
		rot_velocity += rot_accel * delta
		rot_current += rot_velocity * delta
		_spring_rotations[i] = [rot_current, rot_velocity]

		# ── 缩放弹簧 ──
		var scale_freq: float = anim_frequency + scale_frequency_offset
		var scale_target: float = sin(_anim_time * scale_freq * TAU + phase) * scale_amplitude
		var scl_state: Array = _spring_scales[i]
		var scl_current: float = scl_state[0]
		var scl_velocity: float = scl_state[1]
		var scl_accel: float = -spring_scale_stiffness * (scl_current - scale_target) - spring_scale_damping * scl_velocity
		scl_velocity += scl_accel * delta
		scl_current += scl_velocity * delta
		_spring_scales[i] = [scl_current, scl_velocity]

		# 应用变换
		heart.rotation = deg_to_rad(rot_current)
		# 拉伸时 X 增大 Y 减小，压缩时反过来，保持面积感
		heart.scale = Vector2(1.0 + scl_current, 1.0 - scl_current)

# ── 信号回调 ─────────────────────────────────────────

## 实体放置回调：检测是否为 RhythmPlayer，如果是则连接 hp_changed 信号
func _on_entity_placed(_grid_pos: Vector2i, entity: GridEntity2D) -> void:
	if entity is RhythmPlayer:
		var player: RhythmPlayer = entity as RhythmPlayer
		if not player.hp_changed.is_connected(_on_hp_changed):
			player.hp_changed.connect(_on_hp_changed)
			# 初始化显示
			_on_hp_changed(player._current_hp, player.max_hp)
			CLog.o("HpDisplay 已连接玩家 hp_changed 信号")


## 血量变化回调：更新心形图标
func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	_ensure_heart_count(max_hp)
	for i: int in range(_hearts.size()):
		var heart: Label = _hearts[i]
		if i < current_hp:
			heart.text = "❤"
			heart.add_theme_color_override("font_color", full_heart_color)
		else:
			heart.text = "♡"
			heart.add_theme_color_override("font_color", empty_heart_color)

# ── 内部方法 ─────────────────────────────────────────

## 确保心形数量与最大 HP 一致
func _ensure_heart_count(max_hp: int) -> void:
	if _container == null:
		return
	# 数量已匹配，无需调整
	if _hearts.size() == max_hp:
		return
	# 清空旧的心形
	for child: Node in _container.get_children():
		child.queue_free()
	_hearts.clear()
	# 创建新的心形
	for i: int in range(max_hp):
		var heart: Label = Label.new()
		heart.text = "❤"
		heart.add_theme_font_size_override("font_size", heart_font_size)
		heart.add_theme_color_override("font_color", full_heart_color)
		heart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heart.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# 设置旋转锚点为中心
		heart.pivot_offset = Vector2(heart_font_size * 0.5, heart_font_size * 0.5)
		_container.add_child(heart)
		_hearts.append(heart)
	# 重置弹簧状态
	_spring_rotations.clear()
	_spring_scales.clear()
	_anim_time = 0.0

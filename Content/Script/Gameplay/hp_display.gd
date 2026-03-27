class_name HpDisplay
extends MarginContainer
## 血量 UI：塞尔达式心形显示，每颗心代表 1 点 HP
##
## 通过 GridSystem2D 的 entity_placed 信号自动发现 RhythmPlayer，
## 连接其 hp_changed 信号以更新心形图标。
## 心形精灵跟随节拍左右扭动 + 拉伸缩短，营造心跳感。

# ── 导出变量 ──────────────────────────────────────────
## 心形精灵图
@export var heart_texture: Texture2D
## 心形图标大小
@export var heart_size: Vector2 = Vector2(28, 28)
## 心形之间的间距
@export var heart_separation: int = 2
## 空心调制色（变暗半透明表示已失去的 HP）
@export var empty_heart_modulate: Color = Color(0.3, 0.3, 0.3, 0.4)

@export_group("Beat Animation")
## 旋转目标角度（弧度），每拍在 +/- 之间交替 move_to
@export var rotation_amount: float = 0.15
## 旋转弹簧阻尼
@export_range(0.0, 1.0) var spring_rotation_damping: float = 0.35
## 旋转弹簧频率
@export_range(1.0, 20.0) var spring_rotation_frequency: float = 5.0
## 缩放 bump 幅度（拉伸量）
@export var scale_bump_amount: float = 0.15
## 缩放弹簧阻尼
@export_range(0.0, 1.0) var spring_scale_damping: float = 0.35
## 缩放弹簧频率
@export_range(1.0, 20.0) var spring_scale_frequency: float = 5.0

# ── 内部变量 ──────────────────────────────────────────
## 心形 TextureRect 节点列表
var _hearts: Array[TextureRect] = []
## 旋转弹簧（驱动心形左右扭动）
var _spring_rotation: SpringFloat
## 缩放弹簧（驱动心形拉伸缩短）
var _spring_scale: SpringVector2
## 当前旋转目标方向（true = 正方向，false = 负方向）
var _rotation_target_positive: bool = false

# ── 子节点引用 ────────────────────────────────────────
@onready var _container: HBoxContainer = $HBoxContainer

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	# 初始化弹簧系统
	_spring_rotation = SpringFloat.new(0.0, spring_rotation_damping, spring_rotation_frequency)
	_spring_scale = SpringVector2.new(Vector2.ONE, spring_scale_damping, spring_scale_frequency)
	# 监听 GridSystem2D 的实体放置信号，自动发现 RhythmPlayer
	var grid: GridSystem2D = %GridSystem2D as GridSystem2D
	if grid != null:
		grid.entity_placed.connect(_on_entity_placed)
	# 设置心形间距
	if _container != null:
		_container.add_theme_constant_override("separation", heart_separation)
	# 连接节拍信号
	var conductor: RhythmConductor = %RhythmConductor as RhythmConductor
	if conductor != null:
		conductor.beat_tick.connect(_on_beat_tick)
	else:
		CLog.e("HpDisplay 未找到 RhythmConductor")


func _physics_process(delta: float) -> void:
	_spring_rotation.update(delta)
	_spring_scale.update(delta)
	# 将弹簧值应用到所有心形
	var rot: float = _spring_rotation.current
	var scl: Vector2 = _spring_scale.current
	for heart: TextureRect in _hearts:
		heart.rotation = rot
		heart.scale = scl

# ── 信号回调 ─────────────────────────────────────────

## 节拍到达回调：触发心形扭动 + 拉伸
func _on_beat_tick(_beat_index: int) -> void:
	# 旋转：每拍切换目标方向，弹簧弹性移动过去（两拍一个完整循环）
	_rotation_target_positive = not _rotation_target_positive
	var rot_target: float = rotation_amount if _rotation_target_positive else -rotation_amount
	_spring_rotation.move_to(rot_target)
	# 缩放：每拍 bump 拉伸（X 拉伸 Y 压缩），到极值时最明显
	_spring_scale.bump(Vector2(scale_bump_amount, -scale_bump_amount))

## 实体放置回调：检测是否为 RhythmPlayer，如果是则连接 hp_changed 信号
func _on_entity_placed(_grid_pos: Vector2i, entity: GridEntity2D) -> void:
	if entity is RhythmPlayer:
		var player: RhythmPlayer = entity as RhythmPlayer
		if not player.hp_changed.is_connected(_on_hp_changed):
			player.hp_changed.connect(_on_hp_changed)
			# 初始化显示
			_on_hp_changed(player._current_hp, player.max_hp)


## 血量变化回调：更新心形图标
func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	_ensure_heart_count(max_hp)
	for i: int in range(_hearts.size()):
		var heart: TextureRect = _hearts[i]
		if i < current_hp:
			heart.modulate = Color.WHITE
		else:
			heart.modulate = empty_heart_modulate

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
		var heart: TextureRect = TextureRect.new()
		heart.texture = heart_texture
		heart.custom_minimum_size = heart_size
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# 设置旋转/缩放的中心点为心形中心
		heart.pivot_offset = heart_size * 0.5
		_container.add_child(heart)
		_hearts.append(heart)

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

# ── 内部变量 ──────────────────────────────────────────
## 心形 Label 节点列表
var _hearts: Array[Label] = []

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
		_container.add_child(heart)
		_hearts.append(heart)

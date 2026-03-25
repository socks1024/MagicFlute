class_name HpDisplay
extends MarginContainer
## 血量 UI：通过进度条显示玩家当前血量
##
## 通过 GridSystem2D 的 entity_placed 信号自动发现 RhythmPlayer，
## 连接其 hp_changed 信号以更新 FeelProgressBar。

# ── 子节点引用 ────────────────────────────────────────
@onready var _bar: FeelProgressBar = $FeelProgressBar
@onready var _label: Label = $Label

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	# 监听 GridSystem2D 的实体放置信号，自动发现 RhythmPlayer
	var grid: GridSystem2D = %GridSystem2D as GridSystem2D
	if grid != null:
		grid.entity_placed.connect(_on_entity_placed)
	CLog.o("HpDisplay 就绪")

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


## 血量变化回调：更新进度条和文字
func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	if _bar != null:
		var ratio: float = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
		_bar.value = ratio
	if _label != null:
		_label.text = "%d / %d" % [current_hp, max_hp]

class_name GameOverScreen
extends CanvasLayer
## 游戏结束画面：玩家死亡时停止游戏并显示 GAME OVER
##
## 通过 GridSystem2D 的 entity_placed 信号自动发现 RhythmPlayer，
## 连接其 died 信号以触发游戏结束流程。

# ── 信号 ──────────────────────────────────────────────
## 玩家点击重试按钮
signal retry_clicked
## 玩家点击返回主界面按钮
signal back_to_start_clicked

# ── 子节点引用 ────────────────────────────────────────
@onready var _panel: Panel = $Panel
@onready var _label: Label = $Panel/Label
@onready var _btn_retry: Button = $Panel/ButtonContainer/RetryButton
@onready var _btn_back: Button = $Panel/ButtonContainer/BackButton

# ── 内部变量 ─────────────────────────────────────────
## 节拍时钟引用
var _clock: RhythmClock
## 节拍指挥引用
var _conductor: RhythmConductor
## 音乐管理器引用
var _music_manager: RhythmMusicManager

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	# 初始隐藏
	_panel.visible = false
	# 获取引用
	_clock = %RhythmClock as RhythmClock
	_conductor = %RhythmConductor as RhythmConductor
	_music_manager = %RhythmMusicManager as RhythmMusicManager
	# 监听 GridSystem2D 的实体放置信号，自动发现 RhythmPlayer
	var grid: GridSystem2D = %GridSystem2D as GridSystem2D
	if grid != null:
		grid.entity_placed.connect(_on_entity_placed)
	CLog.o("GameOverScreen 就绪")


## 实体放置回调：检测是否为 RhythmPlayer，如果是则连接 died 信号
func _on_entity_placed(_grid_pos: Vector2i, entity: GridEntity2D) -> void:
	if entity is RhythmPlayer:
		var player: RhythmPlayer = entity as RhythmPlayer
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)
			CLog.o("GameOverScreen 已连接玩家 died 信号")

# ── 游戏结束逻辑 ─────────────────────────────────────

## 玩家死亡回调：停止游戏并显示 GAME OVER
func _on_player_died() -> void:
	# 停止节拍时钟
	if _clock != null:
		_clock.stop()
	# 移除移动输入上下文（阻止后续输入）
	if _conductor != null and _conductor.move_input_context != null:
		InputManager.remove_context(_conductor.move_input_context.context_name)
	# 停止 BGM
	if _music_manager != null:
		_music_manager.stop_bgm()
	# 显示 GAME OVER 画面（带淡入）
	_show_game_over()
	CLog.o("GAME OVER!")


## 显示 GAME OVER 画面（淡入动画）
func _show_game_over() -> void:
	_panel.visible = true
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# 显示鼠标光标以便点击按钮
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# ── 按钮回调 ─────────────────────────────────────────

## 重试按钮回调
func _on_retry_button_pressed() -> void:
	retry_clicked.emit()


## 返回主界面按钮回调
func _on_back_button_pressed() -> void:
	back_to_start_clicked.emit()

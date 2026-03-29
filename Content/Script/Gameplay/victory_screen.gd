class_name VictoryScreen
extends CanvasLayer
## 胜利结算画面：BOSS 处决动画结束后显示 VICTORY
##
## 监听 BossJoker 的 death_finished 信号，
## 触发胜利结算流程：停止游戏并显示胜利画面。

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
	# 监听 BossJoker 的处决完成信号
	var boss: BossJoker = _find_boss_joker()
	if boss != null:
		boss.death_finished.connect(_on_boss_death_finished)
		CLog.o("VictoryScreen 已连接 BossJoker death_finished 信号")
	CLog.o("VictoryScreen 就绪")


## 在场景树中查找 BossJoker 节点
func _find_boss_joker() -> BossJoker:
	var stage: Node = get_parent()
	if stage == null:
		return null
	for child: Node in stage.get_children():
		if child is BossJoker:
			return child as BossJoker
	return null

# ── 胜利逻辑 ─────────────────────────────────────────

## BOSS 处决动画结束回调：停止游戏并显示胜利画面
func _on_boss_death_finished() -> void:
	# 停止节拍时钟
	if _clock != null:
		_clock.stop()
	# 移除移动输入上下文（阻止后续输入）
	if _conductor != null and _conductor.move_input_context != null:
		InputManager.remove_context(_conductor.move_input_context.context_name)
	# 停止 BGM
	if _music_manager != null:
		_music_manager.stop_bgm()
	# 显示胜利画面（带淡入）
	_show_victory()
	CLog.o("VICTORY!")


## 显示胜利画面（淡入动画）
func _show_victory() -> void:
	_panel.visible = true
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# 显示鼠标光标以便点击按钮
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# ── 按钮回调 ─────────────────────────────────────────

## 重试按钮回调
func _on_retry_button_pressed() -> void:
	retry_clicked.emit()


## 返回主界面按钮回调
func _on_back_button_pressed() -> void:
	back_to_start_clicked.emit()

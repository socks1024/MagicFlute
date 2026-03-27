class_name RhythmMusicManager
extends Node
## 音乐管理器：集中负责 BGM 的播放与停止。
## 通过连接 RhythmConductor 的信号感知 lane 模式状态变化，
## 提供对应的回调钩子供扩展音乐行为（如切换 BGM、调整音量等）。
## 本节点不包含任何音游判定或序列逻辑。

# ── 导出属性 ─────────────────────────────────────────
## 主 BGM 音乐事件（场景中静态配置 AudioEvent 资源）
@export var bgm_music: AudioEvent
## Lane 序列全连音效
@export var lane_full_combo_sfx: AudioEvent
## Lane 序列失败音效
@export var lane_fail_sfx: AudioEvent

# ── 内部变量 ─────────────────────────────────────────
## 指挥引用
@onready var _conductor: RhythmConductor = %RhythmConductor

# ── 生命周期 ─────────────────────────────────────────

func _ready() -> void:
	# 连接指挥信号
	_conductor.lane_sequence_started.connect(_on_lane_sequence_started)
	_conductor.lane_sequence_finished.connect(_on_lane_sequence_finished)
	# 启动时播放主 BGM
	play_bgm()
	CLog.o("RhythmMusicManager 就绪")

# ── BGM 控制 ─────────────────────────────────────────

## 播放主 BGM
func play_bgm() -> void:
	if bgm_music != null:
		AudioManager.start_music(bgm_music, &"BGM", 0.3)


## 停止主 BGM
func stop_bgm() -> void:
	AudioManager.start_music(null, &"BGM", 0.3)

# ── Lane 模式信号回调（扩展点） ──────────────────────

## lane 序列开始时的回调（可在此扩展音乐行为）
func _on_lane_sequence_started() -> void:
	stop_bgm()


## lane 序列结束时的回调（可在此扩展音乐行为）
func _on_lane_sequence_finished(is_full_combo: bool) -> void:
	if is_full_combo and lane_full_combo_sfx != null:
		AudioManager.play_sound(lane_full_combo_sfx)
	elif not is_full_combo and lane_fail_sfx != null:
		AudioManager.play_sound(lane_fail_sfx)
	play_bgm()

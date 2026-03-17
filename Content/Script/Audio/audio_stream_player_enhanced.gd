class_name AudioEventPlayer
extends AudioStreamPlayer
## 音频流播放器增强版，通过AudioEvent资源配置音频事件的属性，自身不保存任何数据

## 要播放的AudioEvent资源，可以在编辑器中配置，也可以通过代码设置
@export var audio_event:AudioEvent

## 通过AudioEvent资源获取的事件名称
var event_name:StringName:
	get:
		return audio_event.name

## 设置要播放的AudioEvent
func set_audio_event(in_audio_event:AudioEvent) -> void:
	if !in_audio_event:
		CLog.e("AudioEvent is not assigned to AudioEventPlayer!!!")
	else:
		self.audio_event = in_audio_event
		self.bus = in_audio_event.bus

## 播放音频事件，可以传入一个AudioEvent参数，如果不传则使用当前配置的audio_event
func play_audio(in_audio_event:AudioEvent = null) -> void:
	if in_audio_event:
		set_audio_event(in_audio_event)
	if !self.audio_event:
		CLog.e("AudioEvent is not assigned to AudioEventPlayer!!!")
		return
	self.stream = self.audio_event.get_random_audio_stream()
	self.volume_db = self.audio_event.get_random_volume_db()
	self.pitch_scale = self.audio_event.get_random_pitch_scale()
	self.play()

## 暂停播放音频事件，并保持当前播放位置，等待恢复播放
func pause_audio() -> void:
	self.stream_paused = true

## 停止播放音频事件，可以清除当前配置的audio_event
func stop_audio(clear_event:bool = false) -> void:
	self.stop()
	if clear_event:
		self.audio_event = null
		self.bus = "Master"
		self.stream = null
		self.volume_db = 0.0
		self.pitch_scale = 1.0

## 淡入播放音频事件，可以指定淡入时间和淡入完成后的回调函数
func fade_in(fade_time:float, callback = null) -> void:
	var initial_volume_db = self.volume_db
	self.volume_db = -40.0
	self.play()
	var tween = create_tween()
	tween.tween_property(self, "volume_db", initial_volume_db, fade_time)
	if callback != null && callback is Callable:
		tween.finished.connect(callback)

## 淡出停止播放音频事件，可以指定淡出时间和淡出完成后的回调函数
func fade_out(fade_time:float, callback = null) -> void:
	var tween = create_tween()
	tween.tween_property(self, "volume_db", -40.0, fade_time)
	if callback != null && callback is Callable:
		tween.finished.connect(callback)

func _ready() -> void:
	self.finished.connect(_on_audio_finished)

func _on_audio_finished() -> void:
	if audio_event.is_loop:
		self.play()

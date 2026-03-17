class_name AudioEvent
extends Resource
## 音频事件资源类，包含音频事件的属性和方法，可以在编辑器中配置，也可以通过代码创建和修改

## 音频事件的名称
@export var name:StringName = &""

## 音频事件的基础AudioStream资源
@export var audio_stream:AudioStream

## 音频事件是否循环播放
@export var is_loop:bool = false

## 音频事件的优先级，数值越小优先级越高
@export_range(0,100,1) var priority:int = 0

## 音频事件所属的总线
@export var bus:StringName = &"Master"

## 音频事件的相对于总线的音量偏移
@export_range(-80,24,0.01,"suffix:dB") var volume:float = 0

## 音频事件的随机音量范围，单位为dB
@export_range(0,6,0.01,"suffix:dB") var random_volume_range:float = 0

## 音频事件的音调
@export_range(0.01,4,0.01) var pitch:float = 1

## 音频事件的随机音调范围
@export_range(0,1,0.01) var random_pitch_range:float = 0

## 音频事件的变体列表，每个变体都是一个AudioStream资源
@export var variants:Array[AudioStream] = []

## 获取一个随机变体的AudioStream资源，如果没有变体则返回基础AudioStream资源
func get_random_audio_stream() -> AudioStream:
	var audios:Array[AudioStream] = variants
	audios.append(audio_stream)
	if audios.size() == 0:
		CLog.e("AudioEvent has no audio stream assigned!!!")
		return null
	return audios[randi() % audios.size()]

## 获取最终的音量值，考虑基础音量和随机音量范围
func get_random_volume_db() -> float:
	return volume + randf_range(-random_volume_range, random_volume_range)

## 获取最终的音调值，考虑基础音调和随机音调范围
func get_random_pitch_scale() -> float:
	return pitch + randf_range(-random_pitch_range, random_pitch_range)

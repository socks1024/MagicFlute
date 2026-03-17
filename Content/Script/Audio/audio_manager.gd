# Generated Class Name AudioManager
extends Node

## 音效池的容量，超过这个数量的同时播放的音效将会被优先级最低的音效替换
const SOUND_POOL_CAPACITY = 16

## 音效池，保存正在播放的音效的AudioEventPlayer
var sound_pool:Array[AudioEventPlayer] = []

## 音乐轨道，保存每个音乐轨道当前正在播放的AudioEventPlayer
var music_track_players:Dictionary[StringName, AudioEventPlayer] = {}

## 根据事件名称获取正在播放该事件的AudioEventPlayer，如果没有则返回null
func get_player_by_event_name(event_name:StringName) -> AudioEventPlayer:
	var players:Array[AudioEventPlayer] = []
	players.append_array(sound_pool)
	players.append_array(music_track_players.values())
	for player in players:
		if player.is_playing() and player.get("event_name") == event_name:
			return player
	return null

## 播放音效事件
func play_sound(event:AudioEvent) -> void:
	# 获取一个可用的AudioEventPlayer，如果音效池已满则移除优先级最低的音效
	var player:AudioEventPlayer = null
	for p in sound_pool:
		if not p.is_playing():
			player = p
			break
	if player == null:
		if sound_pool.size() >= SOUND_POOL_CAPACITY:
			player = _get_lowest_priority_sound_player()
			player.stop()
		else:
			player = AudioEventPlayer.new()
			player.name = str(sound_pool.size()) + "_SoundPoolPlayer"
			add_child(player)
			sound_pool.append(player)
	# 配置并播放音效
	player.play_audio(event)

## 播放音乐事件，可以指定轨道、淡入时间和是否交叉淡入淡出
func play_music(event:AudioEvent, track_name:StringName, fade_time:float = 1.0, cross_fade:bool = false) -> void:
	# 如果指定的音乐轨道不存在，则创建一个新的AudioEventPlayer来播放该轨道的音乐事件
	if not music_track_players.has(track_name):
		var new_player = AudioEventPlayer.new()
		new_player.name = str(track_name) + "_MusicTrackPlayer"
		add_child(new_player)
		music_track_players[track_name] = new_player
	
	var player:AudioEventPlayer = music_track_players[track_name]
	
	if !player.is_playing():
		player.play_audio(event)
		player.fade_in(fade_time)
	else:
		if cross_fade:
			# 创建一个新的AudioEventPlayer来淡入新的音乐事件
			var new_player = AudioEventPlayer.new()
			new_player.name = str(track_name) + "_CrossFadePlayer"
			add_child(new_player)
			new_player.play_audio(event)
			new_player.fade_in(fade_time)
			
			# 淡出旧的播放器并在淡出完成后切换到新的播放器
			player.fade_out(fade_time, func() -> void:
				player.stop_audio(true)
				remove_child(player)
				player.queue_free()
				music_track_players[track_name] = new_player
				new_player.name = str(track_name) + "_MusicTrackPlayer"
			)
		else:
			player.fade_out(fade_time, func() -> void:
				player.play_audio(event)
				player.fade_in(fade_time)
			)

func _get_lowest_priority_sound_player() -> AudioEventPlayer:
	var lowest_player:AudioEventPlayer = null
	for player in sound_pool:
		if lowest_player == null or \
		player.audio_event.priority < lowest_player.audio_event.priority or \
		(player.audio_event.priority == lowest_player.audio_event.priority and player.get_playback_position() > lowest_player.get_playback_position()):
			lowest_player = player
	return lowest_player

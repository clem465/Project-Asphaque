extends Node

@onready var music_player: AudioStreamPlayer2D = $MusicPlayer

var music_stack: Array[AudioStream] = []
var current_music: AudioStream = null
var _transition_id: int = 0
var _stream_ref_counts: Dictionary = {}
var _music_volume_db: float = 0.0

func play_music(stream: AudioStream) -> void:
	if stream == null:
		return

	music_stack.clear()
	_stream_ref_counts.clear()
	if _is_current_stream(stream) and music_player.playing:
		return

	_transition_id += 1
	var transition_id := _transition_id

	if music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -30, 0.5)
		await tween.finished
		if transition_id != _transition_id:
			return
		music_player.stop()

	current_music = stream
	music_player.stream = stream
	_stream_ref_counts[_stream_key(stream)] = 1
	music_player.play()
	music_player.volume_db = -30

	var tween2 = create_tween()
	tween2.tween_property(music_player, "volume_db", _music_volume_db, 0.5)

func stop_music() -> void:
	_transition_id += 1
	music_player.stop()
	current_music = null
	music_stack.clear()
	_stream_ref_counts.clear()

func push_music(stream: AudioStream) -> void:
	if stream == null:
		return

	if _is_current_stream(stream) and music_player.playing:
		var key := _stream_key(stream)
		_stream_ref_counts[key] = int(_stream_ref_counts.get(key, 1)) + 1
		return

	_transition_id += 1
	var transition_id := _transition_id
	var tween := create_tween()

	if music_player.playing and current_music != null:
		music_stack.append(current_music)

		tween.tween_property(music_player, "volume_db", -30.0, 0.4)
		await tween.finished
		if transition_id != _transition_id:
			return
		music_player.stop()
		
	current_music = stream
	music_player.stream = stream
	_stream_ref_counts[_stream_key(stream)] = 1
	music_player.play()
	music_player.volume_db = -30.0

	var tween_in := create_tween()
	tween_in.tween_property(music_player, "volume_db", _music_volume_db, 0.4)

func pop_music() -> void:
	if current_music != null:
		var current_key := _stream_key(current_music)
		var current_count := int(_stream_ref_counts.get(current_key, 1))
		if current_count > 1:
			_stream_ref_counts[current_key] = current_count - 1
			return
		_stream_ref_counts.erase(current_key)

	if music_stack.is_empty():
		current_music = null
		music_player.stop()
		return

	var previous: AudioStream = music_stack.pop_back()
	if previous == null:
		pop_music()
		return

	_transition_id += 1
	current_music = previous
	music_player.stream = previous
	_stream_ref_counts[_stream_key(previous)] = 1
	music_player.volume_db = _music_volume_db
	music_player.play()

func set_music_volume_percent(percent: float) -> void:
	var normalized: float = clamp(percent / 100.0, 0.0, 1.0)
	_music_volume_db = linear_to_db(normalized) if normalized > 0.0 else -80.0
	if music_player:
		music_player.volume_db = _music_volume_db

func _is_current_stream(stream: AudioStream) -> bool:
	if current_music == null or stream == null:
		return false

	if current_music == stream:
		return true

	return current_music.resource_path != "" and current_music.resource_path == stream.resource_path

func _stream_key(stream: AudioStream) -> String:
	if stream == null:
		return ""
	if stream.resource_path != "":
		return stream.resource_path
	return str(stream.get_instance_id())

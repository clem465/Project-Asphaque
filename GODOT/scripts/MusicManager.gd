extends Node

@onready var music_player: AudioStreamPlayer2D = $MusicPlayer

var music_stack: Array[AudioStream] = []
var current_music: AudioStream = null

func play_music(stream: AudioStream) -> void:
	if music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -30, 0.5)
		await tween.finished
		music_player.stop()

	current_music = stream
	music_player.stream = stream
	music_player.play()
	music_player.volume_db = -30

	var tween2 = create_tween()
	tween2.tween_property(music_player, "volume_db", 0, 0.5)

func stop_music() -> void:
	music_player.stop()
	current_music = null
	music_stack.clear()

func push_music(stream: AudioStream) -> void:
	var tween := create_tween()

	if music_player.playing:
		music_stack.append(current_music)

		tween.tween_property(music_player, "volume_db", -30.0, 0.4)
		await tween.finished
		music_player.stop()
		
	current_music = stream
	music_player.stream = stream
	music_player.play()
	music_player.volume_db = -30.0

	var tween_in := create_tween()
	tween_in.tween_property(music_player, "volume_db", 0.0, 0.4)

func pop_music() -> void:
	if music_stack.is_empty():
		return

	var previous: AudioStream = music_stack.pop_back()

	current_music = previous
	music_player.stream = previous
	music_player.play()

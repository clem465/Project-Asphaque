extends Node2D

@onready var village_music = preload("res://assets/audio/music/village_music.wav")

func _ready() -> void:
	MusicManager.play_music(village_music)

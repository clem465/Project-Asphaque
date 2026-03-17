extends Node2D

@export var target_scene: PackedScene
@export var target_spawn_point: String

func action() -> void:
	if target_scene == null:
		push_warning("No target_scene set for teleport")
		return

	get_tree().change_scene_to_packed(target_scene)

extends Area2D

@export var target_scene: String = "res://maps/house1.tscn"
@export var spawn_position: Vector2 = Vector2(128, 110)
@export var return_spawn_position: Vector2 = Vector2.ZERO
@export var return_spawn_offset: Vector2 = Vector2(44, 52)

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	print("enter_house: body entered:", body)
	if body.is_in_group("player"):
		teleport_to_house()

func teleport_to_house() -> void:
	if target_scene == "":
		return
	# sauvegarde AVANT de changer de scène
	if GameState.has_method("save_gold"):
		GameState.save_gold()
	GameState.house_return_spawn_position = _get_return_spawn_position()
	GameState.house_return_spawn_once = true
	GameState.next_spawn_position = spawn_position
	GameState.next_spawn_once = true
	call_deferred("_change_scene")


func _get_return_spawn_position() -> Vector2:
	if return_spawn_position != Vector2.ZERO:
		return return_spawn_position
	return global_position + return_spawn_offset

func _change_scene() -> void:
	get_tree().change_scene_to_file(target_scene)

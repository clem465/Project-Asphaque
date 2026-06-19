extends Area2D

@export var target_scene: String = "res://maps/village.tscn"
@export var spawn_position: Vector2 = Vector2(27, 135)  # Devant l'entrée de la maison


func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))


func _on_body_entered(body: Node) -> void:
	print("exit_house: body entered:", body)
	# Vérifier si c'est le joueur
	if body.is_in_group("player"):
		teleport_to_village()


func teleport_to_village() -> void:
	if target_scene == "":
		return
	if GameState.has_method("save_gold"):
		GameState.save_gold()
	# mémoriser la position où le joueur doit apparaître dans la scène cible
	var return_position := spawn_position
	if GameState.house_return_spawn_once:
		return_position = GameState.house_return_spawn_position
		GameState.house_return_spawn_once = false
		GameState.house_return_spawn_position = Vector2.ZERO
	print("exit_house: saving spawn_position:", return_position)
	GameState.next_spawn_position = return_position
	GameState.next_spawn_once = true
	get_tree().change_scene_to_file(target_scene)

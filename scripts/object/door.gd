extends Area2D

@export var dialogue_resource: Resource = preload("res://dialogue/door.dialogue")
@export var dialogue_start: String = "start"

@export var target_scene: String = "res://maps/village.tscn"

var player_in_area := false
var is_in_dialogue := false


func action():
	if not player_in_area:
		return
	
	if is_in_dialogue:
		return

	start_dialogue()


func start_dialogue():
	var balloon = DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_start)
	
	if balloon == null:
		print("Erreur : dialogue introuvable")
		return
	
	is_in_dialogue = true
	balloon.tree_exited.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)


func _on_dialogue_finished():
	is_in_dialogue = false

	if GameState.choice == "yes":
		teleport()

	# reset
	GameState.choice = ""


func teleport():
	if target_scene == "":
		return

	get_tree().change_scene_to_file(target_scene)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = false

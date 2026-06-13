extends Area2D

@export var dialogue_resource: Resource = preload("res://dialogue/door.dialogue")
@export var dialogue_resource_en: Resource = preload("res://dialogue/door_en.dialogue")
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
	var balloon = DialogueManager.show_dialogue_balloon(_get_dialogue_resource(), dialogue_start)
	
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

func _get_dialogue_resource() -> Resource:
	var locale_manager = get_node_or_null("/root/LocaleManager")
	if locale_manager and locale_manager.has_method("get_locale"):
		var locale: String = String(locale_manager.get_locale())
		if locale == "en" and dialogue_resource_en:
			return dialogue_resource_en
	return dialogue_resource


func teleport():
	if target_scene == "":
		return
	
	# ­ƒÆ¥ sauvegarde AVANT de quitter le donjon
	GameState.save_gold()

	get_tree().change_scene_to_file(target_scene)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = false

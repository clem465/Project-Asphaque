extends Area2D

@export var dialogue_resource: Resource = preload("res://dialogue/npc1.dialogue")
@export var dialogue_start: String = "start"

@export var target_scene: String = "res://maps/donjon.tscn"

var dialogue_done := false


func action():
	if not dialogue_done:
		start_dialogue()
	else:
		teleport()


func start_dialogue():
	var balloon = DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_start)
	
	if balloon:
		balloon.tree_exited.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)


func _on_dialogue_finished():
	dialogue_done = true
	teleport()


func teleport():
	get_tree().change_scene_to_file(target_scene)

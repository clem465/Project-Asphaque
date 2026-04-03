extends Area2D

@export var dialogue_resource: Resource = preload("res://dialogue/npc1.dialogue")
@export var dialogue_start: String = "start"

@export var target_scene: String = "res://maps/donjon.tscn"

var dialogue_done := false
var is_talking := false


func action():
	if is_talking:
		return

	if not dialogue_done:
		start_dialogue()
	else:
		check_choice()


func start_dialogue():
	is_talking = true

	var balloon = DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_start)

	if balloon:
		balloon.tree_exited.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)


func _on_dialogue_finished():
	is_talking = false
	check_choice()


func check_choice():
	print("CHOICE =", GameState.choice)

	if GameState.choice == "yes":
		dialogue_done = true
		teleport()

	# reset propre
	GameState.choice = ""


func teleport():
	get_tree().change_scene_to_file(target_scene)

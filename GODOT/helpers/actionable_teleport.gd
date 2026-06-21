extends Area2D

@export var dialogue_resource: Resource = preload("res://dialogue/npc1.dialogue")
@export var dialogue_resource_en: Resource = preload("res://dialogue/npc1_en.dialogue")
@export var dialogue_resource_es: Resource = preload("res://dialogue/npc1_es.dialogue")
@export var dialogue_resource_ja: Resource = preload("res://dialogue/npc1_ja.dialogue")
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

	var balloon = DialogueManager.show_dialogue_balloon(_get_dialogue_resource(), dialogue_start)

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
	if GameState.saved_gold == 0:
		# ­ƒÆ¥ sauvegarder les coins AVANT le donjon
		GameState.save_gold()
	get_tree().change_scene_to_file(target_scene)

func _get_dialogue_resource() -> Resource:
	var locale_manager = get_node_or_null("/root/LocaleManager")
	if not locale_manager or not locale_manager.has_method("get_locale"):
		return dialogue_resource

	var locale: String = String(locale_manager.get_locale())

	match locale:
		"en":
			return dialogue_resource_en if dialogue_resource_en else dialogue_resource
		"es":
			return dialogue_resource_es if dialogue_resource_es else dialogue_resource
		"ja":
			return dialogue_resource_ja if dialogue_resource_ja else dialogue_resource
		_:
			return dialogue_resource

extends Area2D

@export var dialogue_resource: Resource = preload("res://dialogue/questgiver.dialogue")
@export var dialogue_resource_en: Resource = preload("res://dialogue/questgiver_en.dialogue")
@export var dialogue_resource_es: Resource = preload("res://dialogue/questgiver_es.dialogue")
@export var dialogue_resource_ja: Resource = preload("res://dialogue/questgiver_ja.dialogue")
@export var quest_id := "slime_cleanup"

var is_talking := false


func action() -> void:
	if is_talking:
		return

	var dialogue_start := _get_dialogue_start_id()
	_start_dialogue(dialogue_start)


func _get_dialogue_start_id() -> String:
	var status := GameState.get_quest_status(quest_id)

	if status == GameState.QUEST_STATUS_NOT_STARTED:
		return "start"

	if status == GameState.QUEST_STATUS_IN_PROGRESS:
		if GameState.is_quest_ready_to_turn_in(quest_id):
			return "ready_to_turn_in"
		return "in_progress"

	return "completed"


func _start_dialogue(start_id: String) -> void:
	is_talking = true
	var balloon = DialogueManager.show_dialogue_balloon(_get_dialogue_resource(), start_id)

	if balloon:
		balloon.tree_exited.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)
	else:
		is_talking = false


func _on_dialogue_finished() -> void:
	is_talking = false

	match GameState.choice:
		"accept_quest":
			GameState.start_quest(quest_id)
		"turn_in_quest":
			GameState.complete_quest(quest_id)
		_:
			pass

	GameState.choice = ""

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

extends Node2D

@export var dialogue_resource: Resource
@export var dialogue_start: String = "start"

func action() -> void:
	DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_start)

extends Node

var gold := 100
var inventory := []

var choice := ""

const QUEST_STATUS_NOT_STARTED := "not_started"
const QUEST_STATUS_IN_PROGRESS := "in_progress"
const QUEST_STATUS_COMPLETED := "completed"

var quests := {
	"slime_cleanup": {
		"title": "Nettoyage du donjon",
		"status": QUEST_STATUS_NOT_STARTED,
		"target_kills": 5,
		"current_kills": 0,
		"reward_gold": 50,
	}
}

func add_item(item_name: String):
	inventory.append(item_name)
	print("Inventaire :", inventory)


func has_quest(quest_id: String) -> bool:
	return quests.has(quest_id)


func get_quest_status(quest_id: String) -> String:
	if not has_quest(quest_id):
		return ""
	return quests[quest_id]["status"]


func get_quest_progress(quest_id: String) -> Dictionary:
	if not has_quest(quest_id):
		return {"current": 0, "target": 0}

	var quest: Dictionary = quests[quest_id]
	return {
		"current": int(quest.get("current_kills", 0)),
		"target": int(quest.get("target_kills", 0)),
	}


func start_quest(quest_id: String) -> bool:
	if not has_quest(quest_id):
		return false

	var quest: Dictionary = quests[quest_id]
	if quest["status"] != QUEST_STATUS_NOT_STARTED:
		return false

	quest["status"] = QUEST_STATUS_IN_PROGRESS
	quest["current_kills"] = 0
	quests[quest_id] = quest

	print("Quete acceptee :", quest.get("title", quest_id))
	return true


func add_kill(enemy_type: String, amount: int = 1) -> void:
	if enemy_type != "slime":
		return

	_add_kills_to_quest("slime_cleanup", amount)


func is_quest_ready_to_turn_in(quest_id: String) -> bool:
	if not has_quest(quest_id):
		return false

	var quest: Dictionary = quests[quest_id]
	if quest["status"] != QUEST_STATUS_IN_PROGRESS:
		return false

	return int(quest.get("current_kills", 0)) >= int(quest.get("target_kills", 0))


func complete_quest(quest_id: String) -> bool:
	if not is_quest_ready_to_turn_in(quest_id):
		return false

	var quest: Dictionary = quests[quest_id]
	quest["status"] = QUEST_STATUS_COMPLETED
	quests[quest_id] = quest

	var reward_gold: int = int(quest.get("reward_gold", 0))
	gold += reward_gold

	print("Quete terminee :", quest.get("title", quest_id), "(+", reward_gold, " or)")
	return true


func _add_kills_to_quest(quest_id: String, amount: int) -> void:
	if amount <= 0 or not has_quest(quest_id):
		return

	var quest: Dictionary = quests[quest_id]
	if quest["status"] != QUEST_STATUS_IN_PROGRESS:
		return

	var target: int = int(quest.get("target_kills", 0))
	var current: int = int(quest.get("current_kills", 0))

	if current >= target:
		return

	current = min(current + amount, target)
	quest["current_kills"] = current
	quests[quest_id] = quest

	print("Progression quete ", quest.get("title", quest_id), ": ", current, "/", target)

extends Node

var gold := 100
var inventory := []
var inventory_counts: Dictionary = {}
var assigned_action_item: String = ""

var item_definitions := {
	"healing_potion": {
		"display_name": "Healing Potion",
		"heal_amount": 20,
	},
	"speed_potion": {
		"display_name": "Speed Boost Potion",
		"speed_multiplier": 1.6,
	}
}

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

func add_item(item_name: String, amount: int = 1) -> void:
	if amount <= 0:
		return

	for _i in range(amount):
		inventory.append(item_name)

	var current: int = int(inventory_counts.get(item_name, 0))
	inventory_counts[item_name] = current + amount
	print("Inventaire :", inventory_counts)


func get_inventory_counts() -> Dictionary:
	return inventory_counts.duplicate(true)


func get_item_count(item_name: String) -> int:
	return int(inventory_counts.get(item_name, 0))


func get_item_display_name(item_name: String) -> String:
	if item_definitions.has(item_name):
		return String(item_definitions[item_name].get("display_name", item_name))
	return item_name


func consume_item(item_name: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	var count: int = get_item_count(item_name)
	if count < amount:
		return false

	count -= amount
	if count == 0:
		inventory_counts.erase(item_name)
	else:
		inventory_counts[item_name] = count

	for _i in range(amount):
		var index: int = inventory.find(item_name)
		if index == -1:
			break
		inventory.remove_at(index)

	if assigned_action_item == item_name and get_item_count(item_name) <= 0:
		assigned_action_item = ""

	return true


func use_item(item_name: String, user: Node = null) -> bool:
	if get_item_count(item_name) <= 0:
		return false

	match item_name:
		"healing_potion":
			if user == null or not user.has_method("heal"):
				return false

			var heal_amount: int = int(item_definitions[item_name].get("heal_amount", 20))
			user.heal(heal_amount)
			return consume_item(item_name, 1)
		"speed_potion":
			if user == null or not user.has_method("apply_speed_boost"):
				return false

			var speed_multiplier: float = float(item_definitions[item_name].get("speed_multiplier", 1.5))
			user.apply_speed_boost(speed_multiplier)
			return consume_item(item_name, 1)
		_:
			return false


func set_assigned_action_item(item_name: String) -> void:
	if item_name == "":
		assigned_action_item = ""
		return

	if get_item_count(item_name) <= 0:
		assigned_action_item = ""
		return

	assigned_action_item = item_name


func get_assigned_action_item() -> String:
	return assigned_action_item


func toggle_assigned_action_item(item_name: String) -> bool:
	if assigned_action_item == item_name:
		assigned_action_item = ""
		return false

	if get_item_count(item_name) <= 0:
		assigned_action_item = ""
		return false

	assigned_action_item = item_name
	return true


func use_assigned_action_item(user: Node = null) -> bool:
	if assigned_action_item == "":
		return false

	var item_name: String = assigned_action_item
	var used: bool = use_item(item_name, user)
	if get_item_count(item_name) <= 0 and assigned_action_item == item_name:
		assigned_action_item = ""

	return used


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

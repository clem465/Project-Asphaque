extends Node

signal state_loaded(success: bool)
signal player_stats_increased(max_health_gain: int, attack_gain: int, defense_gain: int)
signal experience_gained(amount: int)

var _api_base_url: String = "http://127.0.0.1:8000"
var _auth_token: String = ""
var _state_http: HTTPRequest
var _save_timer: Timer
var _save_pending: bool = false
var _is_applying_state: bool = false
var _state_request_mode: String = ""

var _gold: int = 100
var gold: int:
	get:
		return _gold
	set(value):
		if _gold == value:
			return
		_gold = value
		_queue_save_if_ready()

var saved_gold := 0
var inventory: Array = []
var inventory_counts: Dictionary = {}
var assigned_action_item: String = ""
var _locale_manager: Node = null
var equipped_weapon: String = ""

var player_level: int = 1
var player_exp: int = 0
var player_exp_to_next: int = 50
var player_bonus_max_health: int = 0
var player_bonus_attack: int = 0
var player_bonus_defense: int = 0

# -------------------------
# SPAWN PONCTUEL (téléportations génériques hors donjon)
# -------------------------
## Si true, le joueur appliquera next_spawn_position une seule fois dans son
## _ready(), puis remettra ce flag à false. Utilisé par des portes/téléporteurs
## qui veulent placer le joueur à un endroit précis au chargement d'une scène.
var next_spawn_once: bool = false
## Position cible à appliquer une seule fois (voir next_spawn_once).
var next_spawn_position: Vector2 = Vector2.ZERO

## Même mécanisme, dédié au retour depuis une maison : où replacer le joueur
## dans la scène extérieure (devant la porte) quand il ressort.
var house_return_spawn_once: bool = false
var house_return_spawn_position: Vector2 = Vector2.ZERO

# -------------------------
# SYSTÈME D'ÉTAGES
# -------------------------
## Étage actuel dans le donjon (1 = premier sous-sol, 2 = deuxième, etc.)
var current_floor: int = 1
## Seed maîtresse du run en cours. Combinée au numéro d'étage pour générer
## une seed unique et reproductible par étage.
var dungeon_master_seed: int = 0
## D'où vient le joueur lors de la dernière transition d'étage.
## Utilisé par donjon.gd pour choisir le point d'apparition.
##   "village" → arrivé depuis le village (spawn près des escaliers montants)
##   "above"   → descendu depuis un étage supérieur (spawn près des escaliers montants)
##   "below"   → remonté depuis un étage inférieur (spawn près des escaliers descendants)
var player_came_from: String = "village"

# -------------------------

var item_definitions := {
	"healing_potion": {
		"display_name": "Healing Potion",
		"category": "consumable",
		"heal_amount": 20,
	},
	"speed_potion": {
		"display_name": "Speed Boost Potion",
		"category": "consumable",
		"speed_multiplier": 1.6,
	},
	"iron_sword": {
	"display_name": "Iron Sword",
	"category": "weapon",
	"attack": 10,
	"defense": 0
	},

	"steel_sword": {
		"display_name": "Steel Sword",
		"category": "weapon",
		"attack": 25,
		"defense": 0
	},

	"iron_axe": {
		"display_name": "Iron Axe",
		"category": "weapon",
		"attack": 15,
		"defense": 0
	},

	"knight_shield": {
		"display_name": "Knight Shield",
		"category": "weapon",
		"attack": 0,
		"defense": 10
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

func _ready() -> void:
	_ensure_state_http()
	_ensure_save_timer()
	_locale_manager = get_node_or_null("/root/LocaleManager")

func set_api_base_url(url: String) -> void:
	var trimmed := url.strip_edges().trim_suffix("/")
	if trimmed != "":
		_api_base_url = trimmed

func set_auth_token(token: String) -> void:
	_auth_token = token.strip_edges()

func load_state() -> void:
	if _auth_token == "" or _api_base_url == "":
		return
	_ensure_state_http()
	_state_request_mode = "load"
	var headers := _build_auth_headers()
	_state_http.request(_api_base_url + "/state", headers, HTTPClient.METHOD_GET)

func queue_save() -> void:
	if _auth_token == "" or _api_base_url == "":
		return
	_save_pending = true
	_ensure_save_timer()
	_save_timer.stop()
	_save_timer.start()

func _ensure_state_http() -> void:
	if _state_http:
		return
	_state_http = HTTPRequest.new()
	add_child(_state_http)
	_state_http.request_completed.connect(_on_state_request_completed)

func _ensure_save_timer() -> void:
	if _save_timer:
		return
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.6
	add_child(_save_timer)
	_save_timer.timeout.connect(_flush_state_save)

func _build_auth_headers() -> PackedStringArray:
	var headers := PackedStringArray()
	if _auth_token != "":
		headers.append("Authorization: Bearer %s" % _auth_token)
	return headers

func _flush_state_save() -> void:
	if not _save_pending:
		return
	_save_pending = false
	_post_state()

func _post_state() -> void:
	if _auth_token == "" or _api_base_url == "":
		return
	_ensure_state_http()
	_state_request_mode = "save"
	var payload := {
		"state": _build_state_payload()
	}
	var body := JSON.stringify(payload)
	var headers := _build_auth_headers()
	headers.append("Content-Type: application/json")
	_state_http.request(_api_base_url + "/state", headers, HTTPClient.METHOD_POST, body)

func _build_state_payload() -> Dictionary:
	var payload := {
		"gold": gold,
		"inventory_counts": inventory_counts.duplicate(true),
		"equipped_weapon": equipped_weapon,
		"assigned_action_item": assigned_action_item,
		"player_progression": _build_player_progression_payload(),
		"quests": quests.duplicate(true),
		"choice": choice,
		# Étages — permet de reprendre une session en cours
		"current_floor": current_floor,
		"dungeon_master_seed": dungeon_master_seed,
		"player_came_from": player_came_from,
	}

	# include fog discovered cells if FogOfWar node present
	var root = get_tree().current_scene
	if root:
		var fog = root.get_node_or_null("FogOfWar")
		if fog and fog.has_method("get_discovered_cells"):
			payload["fog_discovered"] = fog.get_discovered_cells()

	return payload

func _apply_state_payload(state: Dictionary) -> void:
	_is_applying_state = true

	gold = int(state.get("gold", gold))
	inventory_counts = _normalize_dict(state.get("inventory_counts", {}))
	assigned_action_item = String(state.get("assigned_action_item", ""))
	equipped_weapon = String(state.get("equipped_weapon", ""))
	_apply_player_progression_payload(_normalize_dict(state.get("player_progression", {})))
	quests = _normalize_dict(state.get("quests", quests))
	choice = String(state.get("choice", choice))

	# Restauration de l'état d'étage
	current_floor = int(state.get("current_floor", 1))
	dungeon_master_seed = int(state.get("dungeon_master_seed", 0))
	player_came_from = String(state.get("player_came_from", "village"))

	_rebuild_inventory_from_counts()
	_validate_assigned_action_item()

	_is_applying_state = false

	# apply fog discovered cells if present
	var root = get_tree().current_scene
	if root and state.has("fog_discovered"):
		var fog = root.get_node_or_null("FogOfWar")
		if fog and fog.has_method("set_discovered_cells"):
			fog.set_discovered_cells(state.get("fog_discovered", []))

func _normalize_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

func _rebuild_inventory_from_counts() -> void:
	inventory.clear()
	for item_id in inventory_counts.keys():
		var count: int = int(inventory_counts[item_id])
		for _i in range(count):
			inventory.append(item_id)

func _validate_assigned_action_item() -> void:
	if assigned_action_item == "":
		return
	if get_item_count(assigned_action_item) <= 0:
		assigned_action_item = ""

func _on_state_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		if _state_request_mode == "save":
			if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
				print("[GameState] State save successful.")
			else:
				print("[GameState] State save FAILED! result:", result, "code:", response_code)
			return

		if _state_request_mode == "load":
			var success := false
			if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
				var text := body.get_string_from_utf8()
				var data = JSON.parse_string(text)
				if data is Dictionary:
					var state_value = data.get("state", null)
					if state_value is Dictionary:
						_apply_state_payload(state_value)
					success = true
			emit_signal("state_loaded", success)

func _queue_save_if_ready() -> void:
	if _is_applying_state:
		return
	queue_save()

func _build_player_progression_payload() -> Dictionary:
	return {
		"level": player_level,
		"exp": player_exp,
		"exp_to_next": player_exp_to_next,
		"bonus_max_health": player_bonus_max_health,
		"bonus_attack": player_bonus_attack,
		"bonus_defense": player_bonus_defense,
	}

func _apply_player_progression_payload(value: Dictionary) -> void:
	player_level = max(1, int(value.get("level", player_level)))
	player_exp = max(0, int(value.get("exp", player_exp)))
	player_exp_to_next = max(1, int(value.get("exp_to_next", _get_exp_required_for_level(player_level))))
	player_bonus_max_health = max(0, int(value.get("bonus_max_health", player_bonus_max_health)))
	player_bonus_attack = max(0, int(value.get("bonus_attack", player_bonus_attack)))
	player_bonus_defense = max(0, int(value.get("bonus_defense", player_bonus_defense)))

func _get_exp_required_for_level(level: int) -> int:
	var safe_level: int = max(1, level)
	return 50 + ((safe_level - 1) * 35)

func calculate_monster_exp(enemy_stats: Dictionary) -> int:
	var enemy_max_health: int = max(1, int(enemy_stats.get("max_health", 1)))
	var enemy_attack: int = max(0, int(enemy_stats.get("attack", 0)))
	var enemy_defense: int = max(0, int(enemy_stats.get("defense", 0)))
	var enemy_speed: float = max(0.0, float(enemy_stats.get("speed", 0.0)))

	var exp_value: int = int(round(
		float(enemy_max_health) * 1.2
		+ float(enemy_attack) * 4.0
		+ float(enemy_defense) * 3.0
		+ enemy_speed * 0.05
	))

	return max(1, exp_value)

func add_experience(amount: int) -> void:
	if amount <= 0:
		return

	player_exp += amount
	emit_signal("experience_gained", amount)
	var levels_gained := 0
	var max_health_gain := 0
	var attack_gain := 0
	var defense_gain := 0

	while player_exp >= player_exp_to_next:
		player_exp -= player_exp_to_next
		player_level += 1
		levels_gained += 1

		player_bonus_max_health += 5
		max_health_gain += 5
		player_bonus_attack += 2
		attack_gain += 2
		if player_level % 2 == 0:
			player_bonus_defense += 1
			defense_gain += 1

		player_exp_to_next = _get_exp_required_for_level(player_level)

	print("Experience +", amount, " | niveau ", player_level, " | XP ", player_exp, "/", player_exp_to_next)
	if levels_gained > 0:
		print("Niveau gagne x", levels_gained, " | bonus HP +", player_bonus_max_health, " ATK +", player_bonus_attack, " DEF +", player_bonus_defense)
		emit_signal("player_stats_increased", max_health_gain, attack_gain, defense_gain)

	_queue_save_if_ready()

func get_player_max_health_bonus() -> int:
	return player_bonus_max_health

func get_player_attack_bonus() -> int:
	return player_bonus_attack

func get_player_defense_bonus() -> int:
	return player_bonus_defense

func get_player_progression_summary() -> Dictionary:
	return _build_player_progression_payload()

# =========================================================
# NAVIGATION INTER-ÉTAGES
# =========================================================

## Retourne la seed de bruit pour l'étage donné.
## Déterministe : même étage + même dungeon_master_seed → même layout.
func get_floor_seed(floor_num: int) -> int:
	if dungeon_master_seed == 0:
		dungeon_master_seed = randi() | 1  # Jamais 0
	# Multiplication par un nombre premier pour bien disperser les seeds
	return (dungeon_master_seed + floor_num * 7919) & 0x7FFFFFFF


## Appelé par la porte du village quand le joueur entre dans le donjon.
## Génère une seed maîtresse fraîche → nouveau run, nouvelles salles.
func enter_dungeon() -> void:
	current_floor = 1
	player_came_from = "village"
	dungeon_master_seed = randi() | 1
	_queue_save_if_ready()


## Descendre d'un étage (escaliers ▼).
func go_to_floor_below() -> void:
	current_floor += 1
	player_came_from = "above"
	_queue_save_if_ready()


## Remonter d'un étage (escaliers ▲).
## Appelé uniquement si current_floor > 1 (sinon on sort vers le village).
func go_to_floor_above() -> void:
	current_floor = max(1, current_floor - 1)
	player_came_from = "below"
	_queue_save_if_ready()


## Retour au village depuis l'étage 1 (escaliers ▲ à l'étage 1).
## Reset la seed : le prochain run généré sera forcément différent.
func exit_dungeon_to_village() -> void:
	current_floor = 1
	player_came_from = "village"
	dungeon_master_seed = 0
	_queue_save_if_ready()

# =========================================================

func add_item(item_name: String, amount: int = 1) -> void:
	if amount <= 0:
		return

	for _i in range(amount):
		inventory.append(item_name)

	var current: int = int(inventory_counts.get(item_name, 0))
	inventory_counts[item_name] = current + amount
	print("Inventaire :", inventory_counts)
	_queue_save_if_ready()

func get_inventory_counts() -> Dictionary:
	return inventory_counts.duplicate(true)

func get_item_count(item_name: String) -> int:
	return int(inventory_counts.get(item_name, 0))

func get_item_display_name(item_name: String) -> String:
	if _locale_manager == null:
		_locale_manager = get_node_or_null("/root/LocaleManager")
	if _locale_manager and _locale_manager.has_method("tr_key"):
		var key := "item.%s" % item_name
		var translated := String(_locale_manager.tr_key(key))
		if translated != key:
			return translated
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

	_queue_save_if_ready()
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
		_queue_save_if_ready()
		return

	if get_item_count(item_name) <= 0:
		assigned_action_item = ""
		_queue_save_if_ready()
		return

	assigned_action_item = item_name
	_queue_save_if_ready()

func get_assigned_action_item() -> String:
	return assigned_action_item

func toggle_assigned_action_item(item_name: String) -> bool:
	if assigned_action_item == item_name:
		assigned_action_item = ""
		_queue_save_if_ready()
		return false

	if get_item_count(item_name) <= 0:
		assigned_action_item = ""
		_queue_save_if_ready()
		return false

	assigned_action_item = item_name
	_queue_save_if_ready()
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
	_queue_save_if_ready()
	return true

func add_kill(enemy_type: String, amount: int = 1, enemy_stats: Dictionary = {}) -> void:
	if enemy_type != "slime":
		return

	_add_kills_to_quest("slime_cleanup", amount)

	if not enemy_stats.is_empty():
		add_experience(calculate_monster_exp(enemy_stats) * max(1, amount))

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
	_queue_save_if_ready()
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
	_queue_save_if_ready()

func save_gold():
	saved_gold = gold
	print("Gold saved:", saved_gold)

func restore_gold():
	gold = saved_gold
	print("Gold restored:", gold)

func equip_weapon(item_id: String) -> bool:

	if get_item_count(item_id) <= 0:
		return false

	if not item_definitions.has(item_id):
		return false

	if item_definitions[item_id].get("category", "") != "weapon":
		return false

	equipped_weapon = item_id
	_queue_save_if_ready()

	return true


func unequip_weapon() -> void:
	equipped_weapon = ""
	_queue_save_if_ready()


func get_weapon_attack() -> int:

	if equipped_weapon == "":
		return 0

	if not item_definitions.has(equipped_weapon):
		return 0

	return int(item_definitions[equipped_weapon].get("attack", 0))


func get_weapon_defense() -> int:

	if equipped_weapon == "":
		return 0

	if not item_definitions.has(equipped_weapon):
		return 0

	return int(item_definitions[equipped_weapon].get("defense", 0))

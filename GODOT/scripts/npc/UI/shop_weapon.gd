extends CanvasLayer

signal buy_item(item_name: String, price: int)

@onready var title_label: Label = $Panel/VBoxContainer/Marchand
@onready var item_list: ItemList = $Panel/VBoxContainer/ItemList
@onready var close_button: Button = $Panel/VBoxContainer/Fermer

@onready var sound_pay = $AudioStreamPlayer2D

var shop_items: Array[Dictionary] = [
	{
		"id": "iron_sword",
		"name": "Iron Sword",
		"category": "weapon",
		"price": 100,
		"attack": 10,
		"defense": 0
	},
	{
		"id": "steel_sword",
		"name": "Steel Sword",
		"category": "weapon",
		"price": 250,
		"attack": 25,
		"defense": 0
	},
	{
		"id": "iron_axe",
		"name": "Iron Axe",
		"category": "weapon",
		"price": 150,
		"attack": 15,
		"defense": 0
	},
	{
		"id": "knight_shield",
		"name": "Knight Shield",
		"category": "shield",
		"price": 200,
		"attack": 0,
		"defense": 10
	},
]

var _locale_manager: Node = null


func _ready() -> void:
	_locale_manager = get_node_or_null("/root/LocaleManager")
	_apply_locale()
	if _locale_manager and _locale_manager.has_signal("locale_changed"):
		if not _locale_manager.locale_changed.is_connected(_on_locale_changed):
			_locale_manager.locale_changed.connect(_on_locale_changed)
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_ensure_default_items()

	get_tree().paused = true
	_populate_shop()
	_refresh_title()

	close_button.pressed.connect(_on_close_pressed)
	close_button.text = _locale_manager.tr_key("ui.close_shop")

	
	item_list.item_activated.connect(_on_item_list_item_activated)


func _ensure_default_items() -> void:
	var default_items: Array[Dictionary] = [
		{
			"id": "iron_sword",
			"name": "Iron Sword",
			"category": "weapon",
			"price": 100,
			"attack": 10,
			"defense": 0
		},
		{
			"id": "steel_sword",
			"name": "Steel Sword",
			"category": "weapon",
			"price": 250,
			"attack": 25,
			"defense": 0
		},
		{
			"id": "iron_axe",
			"name": "Iron Axe",
			"category": "weapon",
			"price": 150,
			"attack": 15,
			"defense": 0
		},
		{
			"id": "knight_shield",
			"name": "Knight Shield",
			"category": "shield",
			"price": 200,
			"attack": 0,
			"defense": 10
		},
	]

	for default_item in default_items:
		var exists := false

		for existing_item in shop_items:
			if existing_item["id"] == default_item["id"]:
				exists = true
				break

		if not exists:
			shop_items.append(default_item)


func _populate_shop() -> void:
	item_list.clear()

	for item in shop_items:
		var item_id: String = String(item["id"])

		var item_name: String
		if _locale_manager:
			item_name = _locale_manager.tr_key("item." + item_id)
		else:
			item_name = String(item["name"])

		var text: String = item_name

		if item.has("attack"):
			text += " | " + _locale_manager.tr_key("ui.atk_a") + " +" + str(item["attack"])

		if item.has("defense"):
			text += " | DEF +" + str(item["defense"])

		text += " | " + str(item["price"]) + " " + _locale_manager.tr_key("ui.coins_a")

		item_list.add_item(text)


func _refresh_title() -> void:
	title_label.text = _locale_manager.tr_key("ui.blacksmith") + " | " + _locale_manager.tr_key("ui.coins_a") + ": %d" % int(GameState.gold)


func _on_item_list_item_activated(index: int) -> void:
	print("CLICK ITEM", index)
	if index < 0 or index >= shop_items.size():
		return

	# ItemList 'item_selected' only fires when selection changes.
	# Clearing selection allows repeated clicks on the same item.
	item_list.deselect_all()

	var item: Dictionary = shop_items[index]
	var item_id: String = String(item.get("id", ""))
	var item_price: int = int(item.get("price", 0))

	if item_id == "":
		return

	if int(GameState.gold) < item_price:
		title_label.text = _locale_manager.tr_key("ui.Not_enough_coins") + "(%d " + _locale_manager.tr_key("ui.needed") + ")" % item_price
		return
	
	sound_pay.play()
	GameState.gold -= item_price
	GameState.add_item(item_id)
	emit_signal("buy_item", item_id, item_price)
	_refresh_title()


func _on_close_pressed() -> void:
	get_tree().paused = false
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()

func _on_locale_changed(_locale: String) -> void:
	_apply_locale()


func _apply_locale() -> void:
	if _locale_manager == null:
		return

	close_button.text = _locale_manager.tr_key("ui.close_shop")

	_populate_shop()
	_refresh_title()

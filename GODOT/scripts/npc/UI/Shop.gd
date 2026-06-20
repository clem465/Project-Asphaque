extends CanvasLayer

signal buy_item(item_name: String, price: int)

@onready var title_label: Label = $Panel/VBoxContainer/Marchand
@onready var item_list: ItemList = $Panel/VBoxContainer/ItemList
@onready var close_button: Button = $Panel/VBoxContainer/Fermer

var shop_items: Array[Dictionary] = [
	{"id": "healing_potion","category": "consumable", "name": "Healing Potion", "price": 25},
	{"id": "speed_potion","category": "consumable", "name": "Speed Boost Potion", "price": 40}
]

var _locale_manager: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_ensure_default_items()

	_locale_manager = get_node_or_null("/root/LocaleManager")

	get_tree().paused = true

	_populate_shop()
	_refresh_title()

	close_button.pressed.connect(_on_close_pressed)

	_apply_locale()

	if _locale_manager and _locale_manager.has_signal("locale_changed"):
		if not _locale_manager.locale_changed.is_connected(_on_locale_changed):
			_locale_manager.locale_changed.connect(_on_locale_changed)


func _ensure_default_items() -> void:
	var default_items: Array[Dictionary] = [
		{"id": "healing_potion","category": "consumable", "name": "Healing Potion", "price": 25},
		{"id": "speed_potion","category": "consumable", "name": "Speed Boost Potion", "price": 40},
	]

	for default_item in default_items:
		var item_id: String = String(default_item.get("id", ""))
		if item_id == "":
			continue

		var exists: bool = false
		for existing_item in shop_items:
			if String(existing_item.get("id", "")) == item_id:
				exists = true
				break

		if not exists:
			shop_items.append(default_item)


func _populate_shop() -> void:
	item_list.clear()

	for item in shop_items:
		var item_id: String = String(item.get("id", ""))

		var item_name: String
		if _locale_manager:
			item_name = _locale_manager.tr_key("item." + item_id)
		else:
			item_name = String(item.get("name", "Unknown"))

		var item_price: int = int(item.get("price", 0))

		var coins_text := "Coins"
		if _locale_manager:
			coins_text = _locale_manager.tr_key("ui.coins_a")

		item_list.add_item(
			"%s - %d %s" % [item_name, item_price, coins_text]
		)


func _refresh_title() -> void:
	if _locale_manager:
		title_label.text = "%s | %s: %d" % [
			_locale_manager.tr_key("ui.shop"),
			_locale_manager.tr_key("ui.coins_a"),
			int(GameState.gold)
		]
	else:
		title_label.text = "Shop | Coins: %d" % int(GameState.gold)


func _on_item_list_item_activated(index: int) -> void:
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
		if _locale_manager:
			title_label.text = _locale_manager.tr_key(
				"ui.Not_enough_coins",
				{"count": item_price}
			)
		else:
			title_label.text = "Not enough gold (%d needed)" % item_price
		return

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

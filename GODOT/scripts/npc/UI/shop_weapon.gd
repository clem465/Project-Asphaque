extends CanvasLayer

signal buy_item(item_name: String, price: int)

@onready var title_label: Label = $Panel/VBoxContainer/Marchand
@onready var item_list: ItemList = $Panel/VBoxContainer/ItemList
@onready var close_button: Button = $Panel/VBoxContainer/Fermer

var shop_items: Array[Dictionary] = [
	{"id": "iron_sword", "name": "Iron Sword", "price": 100, "attack": 10, "defense": 0},
	{"id": "steel_sword", "name": "Steel Sword", "price": 250, "attack": 25, "defense": 0},
	{"id": "iron_axe", "name": "Iron Axe", "price": 150, "attack": 15, "defense": 0},
	{"id": "knight_shield", "name": "Knight Shield", "price": 200, "attack": 10, "defense": 10},
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_ensure_default_items()

	get_tree().paused = true
	_populate_shop()
	_refresh_title()

	close_button.pressed.connect(_on_close_pressed)
	close_button.text = "Close Shop"
	
	item_list.item_activated.connect(_on_item_list_item_activated)


func _ensure_default_items() -> void:
	var default_items: Array[Dictionary] = [
		{"id": "iron_sword", "name": "Iron Sword", "price": 100, "attack": 10},
		{"id": "steel_sword", "name": "Steel Sword", "price": 250, "attack": 25},
		{"id": "iron_axe", "name": "Iron Axe", "price": 150, "attack": 15},
		{"id": "knight_shield", "name": "Knight Shield", "price": 200, "defense": 20}
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
		var text: String = String(item["name"])

		if item.has("attack"):
			text += " | ATK +" + str(item["attack"])

		if item.has("defense"):
			text += " | DEF +" + str(item["defense"])

		text += " | " + str(item["price"]) + "G"

		item_list.add_item(text)


func _refresh_title() -> void:
	title_label.text = "Blacksmith | Gold: %d" % int(GameState.gold)


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

extends CanvasLayer

signal buy_item(item_name: String, price: int)

@onready var item_container: VBoxContainer = $Panel/VBoxContainer/Items
@onready var close_button: Button = $Panel/VBoxContainer/Button

var items = [
	{"name": "Potion", "price": 10},
	{"name": "Épée", "price": 50},
	{"name": "Armure", "price": 40}
]

func _ready():
	print("SHOP READY")
	get_tree().paused = true
	_populate_shop()

	close_button.pressed.connect(_on_close_pressed)


func _populate_shop():
	for child in item_container.get_children():
		child.queue_free()

	for item in items:
		var btn = Button.new()
		btn.text = item.name + " - " + str(item.price) + "G"

		btn.pressed.connect(func():
			_on_item_pressed(item)
		)

		item_container.add_child(btn)


func _on_item_pressed(item):
	emit_signal("buy_item", item.name, item.price)


func _on_close_pressed():
	get_tree().paused = false
	queue_free()

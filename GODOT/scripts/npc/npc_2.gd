extends Area2D

@export var dialogue_resource: Resource = preload("res://dialogue/shopkeeper.dialogue")
@export var dialogue_resource_en: Resource = preload("res://dialogue/shopkeeper_en.dialogue")
@export var dialogue_start: String = "start"
@export var shop_ui_scene: PackedScene = preload("res://scenes/npc/UI/Shop.tscn")

var dialogue_done := false
var shop_instance = null
var is_talking := false
var want_to_open_shop := false


func action():
	if is_talking:
		return

	if not dialogue_done:
		start_dialogue()
	else:
		open_shop()


func start_dialogue():
	is_talking = true

	var balloon = DialogueManager.show_dialogue_balloon(_get_dialogue_resource(), dialogue_start)

	if balloon:
		balloon.tree_exited.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)


func _on_dialogue_finished():
	is_talking = false

	# Ici on lit le choix
	if GameState.choice == "yes":
		want_to_open_shop = true
		dialogue_done = true
		open_shop()
	else:
		want_to_open_shop = false

	GameState.choice = ""

func _get_dialogue_resource() -> Resource:
	var locale_manager = get_node_or_null("/root/LocaleManager")
	if locale_manager and locale_manager.has_method("get_locale"):
		var locale: String = String(locale_manager.get_locale())
		if locale == "en" and dialogue_resource_en:
			return dialogue_resource_en
	return dialogue_resource


func open_shop():
	print("OPEN SHOP")

	if shop_instance != null and is_instance_valid(shop_instance):
		return

	shop_instance = shop_ui_scene.instantiate()
	get_tree().current_scene.add_child(shop_instance)

	shop_instance.show()
	shop_instance.visible = true

	print("Shop affiché")


func _on_buy_item(item_name: String, price: int):
	if GameState.gold < price:
		print("Pas assez d'or !")
		return

	GameState.gold -= price
	GameState.add_item(item_name)

	print("Achat :", item_name)

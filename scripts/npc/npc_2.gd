extends Area2D

@export var dialogue_resource: Resource = preload("res://dialogue/shopkeeper.dialogue")
@export var dialogue_start: String = "start"

@export var shop_ui_scene: PackedScene
var shop_instance

var dialogue_done := false


func action():
	if not dialogue_done:
		start_dialogue()
	else:
		open_shop()


func start_dialogue():
	var balloon = DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_start)
	
	if balloon:
		balloon.tree_exited.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)


func _on_dialogue_finished():
	dialogue_done = true
	
	# Tu peux ouvrir directement la boutique après le dialogue
	open_shop()


func open_shop():
	if shop_instance == null:
		shop_instance = shop_ui_scene.instantiate()
		get_tree().current_scene.add_child(shop_instance)

		# Connecte un signal d'achat
		shop_instance.buy_item.connect(_on_buy_item)


func _on_buy_item(item_name: String, price: int):
	if GameState.gold >= price:
		GameState.gold -= price
		
		# Ajoute l'objet à l’inventaire
		GameState.add_item(item_name)
		
		print("Achat réussi :", item_name)
	else:
		print("Pas assez d'or !")

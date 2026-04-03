extends Node

var gold := 100
var inventory := []

var choice := ""

func add_item(item_name: String):
	inventory.append(item_name)
	print("Inventaire :", inventory)

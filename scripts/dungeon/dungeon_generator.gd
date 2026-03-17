class_name DungeonGenerator
extends Node

var rng := RandomNumberGenerator.new()

func generate(seed: int) -> Array:
	rng.seed = seed

	var rooms = []
	rooms.append({"id": 0, "type": "start", "connections": []})

	var room_count = rng.randi_range(4, 7)

	for i in range(1, room_count + 1):
		rooms.append({"id": i, "type": "normal", "connections": []})

	var key_room_id = room_count + 1
	rooms.append({"id": key_room_id, "type": "key", "connections": []})

	var locked_room_id = room_count + 2
	rooms.append({"id": locked_room_id, "type": "locked", "connections": []})

	var boss_room_id = room_count + 3
	rooms.append({"id": boss_room_id, "type": "boss", "connections": []})

	_connect_rooms(rooms, room_count, key_room_id, locked_room_id, boss_room_id)

	return rooms


func _connect_rooms(rooms, room_count, key_room_id, locked_room_id, boss_room_id):
	for i in range(room_count):
		rooms[i]["connections"].append(i + 1)

	rooms[room_count]["connections"].append(locked_room_id)
	rooms[locked_room_id]["connections"].append(boss_room_id)

	var branch_from = rng.randi_range(1, room_count - 1)
	rooms[branch_from]["connections"].append(key_room_id)

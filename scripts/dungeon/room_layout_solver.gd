class_name RoomLayoutSolver
extends Node

func layout_rooms(rooms: Array) -> Dictionary:
	var layout := {}
	var current_pos = Vector2i(0, 0)
	layout[0] = current_pos

	for room in rooms:
		if room["id"] == 0:
			continue

		var parent = _find_parent(room, rooms)
		var parent_pos = layout[parent]

		var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
		dirs.shuffle()

		for d in dirs:
			var new_pos = parent_pos + d
			if not layout.values().has(new_pos):
				layout[room["id"]] = new_pos
				break

	return layout


func _find_parent(room, rooms):
	for r in rooms:
		if room["id"] in r["connections"]:
			return r["id"]
	return 0

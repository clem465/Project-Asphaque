class_name RoomRenderer
extends Node

var rng := RandomNumberGenerator.new()

func generate_room(tilemap: TileMap, room_data, seed: int):
	rng.seed = seed + room_data["id"]

	var w = 12
	var h = 8

	for x in range(w):
		for y in range(h):

			# --- BORDURES ---
			var is_left   = x == 0
			var is_right  = x == w - 1
			var is_top    = y == 0
			var is_bottom = y == h - 1

			# --- MURS ---
			if is_top:
				# Haut du mur
				tilemap.set_cell(0, Vector2i(x, y), 3)

			elif is_left:
				# Mur gauche
				tilemap.set_cell(0, Vector2i(x, y), 4)

			elif is_right:
				# Mur droite
				tilemap.set_cell(0, Vector2i(x, y), 5)

			elif is_bottom:
				# Mur simple en bas
				tilemap.set_cell(0, Vector2i(x, y), 2)

			else:
				# Sol
				tilemap.set_cell(0, Vector2i(x, y), 1)

	# --- DÉCOR ALÉATOIRE ---
	for i in range(rng.randi_range(2, 5)):
		var px = rng.randi_range(1, w - 2)
		var py = rng.randi_range(1, h - 2)
		tilemap.set_cell(0, Vector2i(px, py), 2) # décor = mur simple ou autre ID si tu veux

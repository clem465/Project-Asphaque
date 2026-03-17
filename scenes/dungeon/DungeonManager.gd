extends Node

@onready var generator := DungeonGenerator.new()
@onready var layout_solver := RoomLayoutSolver.new()
@onready var renderer := RoomRenderer.new()

var seed := 12345

func _ready():
	var rooms = generator.generate(seed)
	var layout = layout_solver.layout_rooms(rooms)
	print("DungeonManager READY")

	for room_data in rooms:
		var pos = layout[room_data["id"]]
		_spawn_room(room_data, pos)


func _spawn_room(room_data, grid_pos: Vector2i):
	var room_scene = preload("res://scenes/dungeon/DungeonRoom.tscn").instantiate()
	add_child(room_scene)

	var cell_size := Vector2(200, 150)
	room_scene.position = Vector2(
		grid_pos.x * cell_size.x,
		grid_pos.y * cell_size.y
	)

	renderer.generate_room(room_scene.get_node("TileMap"), room_data, seed)


	renderer.generate_room(room_scene.get_node("TileMap"), room_data, seed)

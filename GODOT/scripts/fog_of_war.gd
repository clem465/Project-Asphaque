extends Node2D

@export var fog_cell_size: float = 32.0
@export var visible_radius_world: float = 120.0
@export var fog_color_discovered: Color = Color(0.18, 0.18, 0.18, 0.55)
@export var fog_color_unseen: Color = Color(0.0, 0.0, 0.0, 1.0)

var _map_bounds: Rect2 = Rect2()
var _fog_grid_size: Vector2i = Vector2i(0, 0)
var _discovered_image: Image
var _fog_display_image: Image
var _fog_texture: ImageTexture
var _fog_sprite: Sprite2D
var _player_ref: Node2D = null
var _last_player_pos: Vector2 = Vector2.ZERO
var _has_last_player_pos: bool = false

func _ready() -> void:
	call_deferred("_init_fog")

func _init_fog() -> void:
	_map_bounds = _compute_map_bounds()
	if _map_bounds.size.x <= 0.0 or _map_bounds.size.y <= 0.0:
		print("[FogOfWar] Could not compute map bounds — falling back to player-centered area")
		var p = _get_player_ref()
		var center = Vector2.ZERO
		if p and is_instance_valid(p):
			center = p.global_position
		_map_bounds = Rect2(center - Vector2(512, 512), Vector2(1024, 1024))

	var grid_w: int = max(1, int(ceil(_map_bounds.size.x / fog_cell_size)))
	var grid_h: int = max(1, int(ceil(_map_bounds.size.y / fog_cell_size)))
	_fog_grid_size = Vector2i(grid_w, grid_h)

	_discovered_image = Image.create(grid_w, grid_h, false, Image.FORMAT_RGBA8)
	_discovered_image.fill(Color(0,0,0,1))
	_fog_display_image = Image.create(grid_w, grid_h, false, Image.FORMAT_RGBA8)
	_fog_display_image.fill(fog_color_unseen)

	_fog_texture = ImageTexture.create_from_image(_fog_display_image)

	_fog_sprite = Sprite2D.new()
	_fog_sprite.texture = _fog_texture
	_fog_sprite.centered = false
	_fog_sprite.position = _map_bounds.position
	_fog_sprite.scale = Vector2(fog_cell_size, fog_cell_size)
	_fog_sprite.z_index = 1000
	_fog_sprite.visible = true
	_fog_sprite.modulate = Color(1,1,1,1)
	add_child(_fog_sprite)

	_player_ref = _get_player_ref()
	_has_last_player_pos = false

	_update_fog_discovery()
	print("[FogOfWar] initialized: bounds=", _map_bounds, " grid=", _fog_grid_size)
	if _discovered_image:
		print("[FogOfWar] discovered image size:", _discovered_image.get_width(), _discovered_image.get_height())
	if _fog_display_image:
		print("[FogOfWar] display image size:", _fog_display_image.get_width(), _fog_display_image.get_height())
	if _fog_texture:
		if _fog_texture is ImageTexture:
			print("[FogOfWar] texture size:", _fog_texture.get_width(), _fog_texture.get_height())

func _update_fog_discovery() -> void:
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = _get_player_ref()
		if _player_ref == null:
			return

	var player_pos: Vector2 = _player_ref.global_position
	var center: Vector2i = _world_to_fog_cell(player_pos)
	var radius_cells: int = int(ceil(visible_radius_world / fog_cell_size))
	var radius_world_sq: float = visible_radius_world * visible_radius_world

	for y in range(-radius_cells, radius_cells + 1):
		for x in range(-radius_cells, radius_cells + 1):
			var cell = center + Vector2i(x, y)
			if cell.x < 0 or cell.y < 0 or cell.x >= _fog_grid_size.x or cell.y >= _fog_grid_size.y:
				continue

			var cell_world: Vector2 = _fog_cell_center_world(cell)
			if cell_world.distance_squared_to(player_pos) <= radius_world_sq:
				_discovered_image.set_pixel(cell.x, cell.y, Color(1,1,1,1))

	_rebuild_fog_display(player_pos, radius_world_sq)

func _process(_delta: float) -> void:
	if _fog_texture == null:
		return

	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = _get_player_ref()
		if _player_ref == null:
			return

	var player_pos: Vector2 = _player_ref.global_position
	if _has_last_player_pos and player_pos.distance_squared_to(_last_player_pos) < 1.0:
		return

	_last_player_pos = player_pos
	_has_last_player_pos = true

	var center: Vector2i = _world_to_fog_cell(player_pos)
	var radius_cells: int = int(ceil(visible_radius_world / fog_cell_size))
	var radius_world_sq: float = visible_radius_world * visible_radius_world

	for y in range(-radius_cells, radius_cells + 1):
		for x in range(-radius_cells, radius_cells + 1):
			var cell = center + Vector2i(x, y)
			if cell.x < 0 or cell.y < 0 or cell.x >= _fog_grid_size.x or cell.y >= _fog_grid_size.y:
				continue

			var cell_world: Vector2 = _fog_cell_center_world(cell)
			if cell_world.distance_squared_to(player_pos) <= radius_world_sq:
				_discovered_image.set_pixel(cell.x, cell.y, Color(1,1,1,1))

	_rebuild_fog_display(player_pos, radius_world_sq)

func _rebuild_fog_display(player_pos: Vector2, radius_world_sq: float) -> void:
	for y in range(_fog_grid_size.y):
		for x in range(_fog_grid_size.x):
			var fog_color: Color = fog_color_unseen
			if _discovered_image.get_pixel(x, y).r > 0.5:
				fog_color = fog_color_discovered

			var cell_world: Vector2 = _fog_cell_center_world(Vector2i(x, y))
			if cell_world.distance_squared_to(player_pos) <= radius_world_sq:
				fog_color = Color(0,0,0,0)

			_fog_display_image.set_pixel(x, y, fog_color)

	_fog_texture.update(_fog_display_image)

func get_fog_state_at_world(world_pos: Vector2) -> String:
	if _fog_grid_size.x <= 0 or _fog_grid_size.y <= 0:
		return "visible"
	var cell = _world_to_fog_cell(world_pos)
	if cell.x < 0 or cell.y < 0 or cell.x >= _fog_grid_size.x or cell.y >= _fog_grid_size.y:
		return "visible"

	# currently visible if display image alpha == 0
	var pix = _fog_display_image.get_pixel(cell.x, cell.y)
	if pix.a <= 0.01:
		return "visible"

	# discovered if discovered_image has flag
	var d = _discovered_image.get_pixel(cell.x, cell.y)
	if d.r > 0.5:
		return "discovered"

	return "unseen"

func get_discovered_cells() -> Array:
	var out: Array = []
	if _fog_grid_size.x <= 0 or _fog_grid_size.y <= 0:
		return out
	for y in range(_fog_grid_size.y):
		for x in range(_fog_grid_size.x):
			if _discovered_image.get_pixel(x, y).r > 0.5:
				out.append([x, y])
	return out

func set_discovered_cells(cells: Array) -> void:
	if _fog_grid_size.x <= 0 or _fog_grid_size.y <= 0:
		return
	# clear
	_discovered_image.fill(Color(0,0,0,1))
	for pair in cells:
		if pair.size() >= 2:
			var x = int(pair[0])
			var y = int(pair[1])
			if x >= 0 and y >= 0 and x < _fog_grid_size.x and y < _fog_grid_size.y:
				_discovered_image.set_pixel(x, y, Color(1,1,1,1))
	# rebuild display to reflect new discovered set
	var player_pos = Vector2.ZERO
	if _player_ref and is_instance_valid(_player_ref):
		player_pos = _player_ref.global_position
	var radius_world_sq = visible_radius_world * visible_radius_world
	_rebuild_fog_display(player_pos, radius_world_sq)

func _world_to_fog_cell(world_pos: Vector2) -> Vector2i:
	var local = world_pos - _map_bounds.position
	return Vector2i(
		int(floor(local.x / fog_cell_size)),
		int(floor(local.y / fog_cell_size))
	)

func _fog_cell_center_world(cell: Vector2i) -> Vector2:
	return _map_bounds.position + Vector2((float(cell.x) + 0.5) * fog_cell_size, (float(cell.y) + 0.5) * fog_cell_size)

func _get_player_ref() -> Node2D:
	var group_player: Node = get_tree().get_first_node_in_group("player")
	if group_player is Node2D:
		return group_player

	var root: Node = get_tree().current_scene
	if root:
		var fallback_player: Node = root.find_child("Player", true, false)
		if fallback_player is Node2D:
			return fallback_player
		var fallback: Node = root.find_child("Player1", true, false)
		if fallback is Node2D:
			return fallback
	return null

func _compute_map_bounds() -> Rect2:
	var root = get_tree().current_scene
	if root == null:
		return Rect2()

	var tilemaps = _find_all_tilemaps(root)
	var full_rect = Rect2()
	var is_first = true

	for tm in tilemaps:
		var used = tm.get_used_rect()
		if used.has_area():
			var cell_size = Vector2(16, 16)
			if tm.tile_set:
				cell_size = tm.tile_set.tile_size
			var local_rect = Rect2(Vector2(used.position) * Vector2(cell_size), Vector2(used.size) * Vector2(cell_size))
			var global_rect = Rect2(tm.to_global(local_rect.position), local_rect.size)

			if is_first:
				full_rect = global_rect
				is_first = false
			else:
				full_rect = full_rect.merge(global_rect)

	if not is_first:
		return full_rect
	return Rect2()

func _find_all_tilemaps(node: Node) -> Array:
	var result = []
	if node is TileMap:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_tilemaps(child))
	return result

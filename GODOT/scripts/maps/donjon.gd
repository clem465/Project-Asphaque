extends TileMap

var noise := FastNoiseLite.new()
var entity_rng := RandomNumberGenerator.new()

const SIZE := Vector2i(80, 60)
const SOURCE_ID := 0

@onready var dungeon_music = preload("res://assets/audio/music/elias_weber-auf-grunen-wiesen-127713.mp3")

# -------------------------
# MONSTRES
# -------------------------
const SLIME_1_SCENE = preload("res://scenes/monster/slime.tscn")
const SLIME_2_SCENE = preload("res://scenes/monster/slime2.tscn")
const SLIME_3_SCENE = preload("res://scenes/monster/slime3.tscn")

const MONSTER_COUNT := 15
const MIN_DISTANCE_FROM_SPAWN := 6

# Nombre minimum de Slime 3 par étage
const MIN_SLIME3_PER_FLOOR := 1

# -------------------------
# COFFRES
# -------------------------
const CHEST_SCENE = preload("res://scenes/object/chest.tscn")
const CHEST_COUNT := 6
const MIN_DISTANCE_CHEST_FROM_SPAWN := 5

# -------------------------
# ESCALIERS
# -------------------------
## Scène réutilisant le sprite et la hitbox de la porte d'origine.
const STAIRS_SCENE = preload("res://maps/dungeon_stairs.tscn")
const MIN_DISTANCE_STAIRS_FROM_SPAWN := 10
const MIN_DISTANCE_BETWEEN_STAIRS := 18

# -------------------------
# TILES
# -------------------------
const FLOOR := Vector2i(3, 3)

const WALL_TOP := Vector2i(2, 18)
const WALL_BOTTOM := Vector2i(6, 19)
const WALL_LEFT := Vector2i(2, 21)
const WALL_RIGHT := Vector2i(6, 19)

const CORNER_TL := Vector2i(6, 11)
const CORNER_TR := Vector2i(7, 11)
const CORNER_BL := Vector2i(6,11)
const CORNER_BR := Vector2i(7, 11)

# -------------------------
# SPAWN JOUEUR
# -------------------------
const SPAWN_POS := Vector2i(40, 30)
const SPAWN_RADIUS := 4

var _stairs_up_pos := Vector2i.ZERO
var _stairs_down_pos := Vector2i.ZERO


func _ready():
	MusicManager.play_music(dungeon_music)
	noise.seed = GameState.get_floor_seed(GameState.current_floor)
	noise.frequency = 0.08
	entity_rng.seed = noise.seed + 99991
	generate()
	call_deferred("_move_player_to_entry")
	print("=== Donjon étage %d | seed %d ===" % [GameState.current_floor, noise.seed])


# -------------------------
# GENERATION
# -------------------------
func generate():
	var grid = []

	# 1. bruit
	for x in range(SIZE.x):
		grid.append([])
		for y in range(SIZE.y):
			var n = noise.get_noise_2d(x, y)
			grid[x].append(n > 0.0)

	# 2. zone spawn propre
	for x in range(SPAWN_POS.x - SPAWN_RADIUS, SPAWN_POS.x + SPAWN_RADIUS):
		for y in range(SPAWN_POS.y - SPAWN_RADIUS, SPAWN_POS.y + SPAWN_RADIUS):
			if in_bounds(x, y):
				grid[x][y] = true

	# 3. bordures = murs
	for x in range(SIZE.x):
		grid[x][0] = false
		grid[x][SIZE.y - 1] = false
	for y in range(SIZE.y):
		grid[0][y] = false
		grid[SIZE.x - 1][y] = false

	# 4. smoothing
	grid = smooth(grid, 2)

	# 5. connectivité
	grid = keep_connected_area(grid)

	# 6. tiles
	place_tiles(grid)

	# 7. escaliers en premier (pour exclure leurs positions)
	spawn_stairs(grid)

	# 8. coffres
	spawn_chests(grid)

	# 9. monstres
	spawn_monsters(grid)


# -------------------------
# ESCALIERS
# -------------------------
func _find_safe_tiles(grid):
	var safe = []
	for x in range(2, SIZE.x - 2):
		for y in range(2, SIZE.y - 2):
			if not grid[x][y]:
				continue
			var pos = Vector2i(x, y)
			if pos.distance_to(SPAWN_POS) < MIN_DISTANCE_STAIRS_FROM_SPAWN:
				continue
			var all_floor = true
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if not grid[x + dx][y + dy]:
						all_floor = false
						break
				if not all_floor:
					break
			if all_floor:
				safe.append(pos)
	return safe


func spawn_stairs(grid):
	var safe_tiles = _find_safe_tiles(grid)

	if safe_tiles.size() < 2:
		push_error("[donjon] Pas assez de tuiles sûres pour les escaliers (trouvé : %d)" % safe_tiles.size())
		return

	# Escaliers montants : position aléatoire (déterministe via entity_rng)
	var idx_up = entity_rng.randi() % safe_tiles.size()
	_stairs_up_pos = safe_tiles[idx_up]

	# Escaliers descendants : tuile la plus éloignée des montants
	var best_dist = 0.0
	var best_idx = -1
	for i in range(safe_tiles.size()):
		if i == idx_up:
			continue
		var d = float(safe_tiles[i].distance_to(_stairs_up_pos))
		if d > best_dist and d >= MIN_DISTANCE_BETWEEN_STAIRS:
			best_dist = d
			best_idx = i

	# Fallback si aucune tile assez éloignée
	if best_idx == -1:
		for i in range(safe_tiles.size()):
			if i == idx_up:
				continue
			var d = float(safe_tiles[i].distance_to(_stairs_up_pos))
			if d > best_dist:
				best_dist = d
				best_idx = i

	if best_idx == -1:
		push_error("[donjon] Impossible de séparer les deux escaliers")
		return

	_stairs_down_pos = safe_tiles[best_idx]

	var stair_up = STAIRS_SCENE.instantiate()
	stair_up.direction = "up"
	stair_up.position = map_to_local(_stairs_up_pos) + Vector2(8, 8)
	add_child(stair_up)

	var stair_down = STAIRS_SCENE.instantiate()
	stair_down.direction = "down"
	stair_down.position = map_to_local(_stairs_down_pos) + Vector2(8, 8)
	add_child(stair_down)

	print("Escaliers ▲ : %s | ▼ : %s" % [_stairs_up_pos, _stairs_down_pos])


# -------------------------
# PLACEMENT DU JOUEUR
# -------------------------
func _move_player_to_entry():
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0]

	var target_grid_pos
	match GameState.player_came_from:
		"below":
			target_grid_pos = _stairs_down_pos if _stairs_down_pos != Vector2i.ZERO else SPAWN_POS
		_:
			target_grid_pos = _stairs_up_pos if _stairs_up_pos != Vector2i.ZERO else SPAWN_POS

	player.global_position = map_to_local(target_grid_pos) + Vector2(8, 24)


# -------------------------
# SPAWN COFFRES
# -------------------------
func spawn_chests(grid):
	var spawned = 0
	var attempts = 0
	var max_attempts = CHEST_COUNT * 40

	var used_positions = []
	if _stairs_up_pos != Vector2i.ZERO:
		used_positions.append(_stairs_up_pos)
	if _stairs_down_pos != Vector2i.ZERO:
		used_positions.append(_stairs_down_pos)

	while spawned < CHEST_COUNT and attempts < max_attempts:
		attempts += 1

		var x = entity_rng.randi() % SIZE.x
		var y = entity_rng.randi() % SIZE.y
		var pos = Vector2i(x, y)

		if not grid[x][y]:
			continue
		if pos.distance_to(SPAWN_POS) < MIN_DISTANCE_CHEST_FROM_SPAWN:
			continue

		var too_close = false
		for other in used_positions:
			if pos.distance_to(other) < 6:
				too_close = true
				break
		if too_close:
			continue

		var near_wall = false
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if not in_bounds(x + dx, y + dy):
					continue
				if not grid[x + dx][y + dy]:
					near_wall = true
		if near_wall:
			continue

		var chest = CHEST_SCENE.instantiate()
		chest.position = map_to_local(pos) + Vector2(8, 8)
		add_child(chest)

		used_positions.append(pos)
		spawned += 1

	print("Coffres spawn:", spawned)


# -------------------------
# CONNECTIVITÉ
# -------------------------
func keep_connected_area(grid):
	var visited = {}
	var stack = [SPAWN_POS]

	while stack.size() > 0:
		var current = stack.pop_back()

		if visited.has(current):
			continue
		visited[current] = true

		var dirs = [
			Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, 1), Vector2i(0, -1)
		]
		for d in dirs:
			var nx = current.x + d.x
			var ny = current.y + d.y
			if in_bounds(nx, ny) and grid[nx][ny]:
				stack.append(Vector2i(nx, ny))

	for x in range(SIZE.x):
		for y in range(SIZE.y):
			var pos = Vector2i(x, y)
			if grid[x][y] and not visited.has(pos):
				grid[x][y] = false

	return grid


# -------------------------
# SPAWN MONSTRES
# -------------------------
func get_random_monster_scene() -> PackedScene:
	var roll := entity_rng.randi_range(1, 100)

	# Slime 1 : commun
	if roll <= 75:
		return SLIME_1_SCENE

	# Slime 2 : rare
	if roll <= 97:
		return SLIME_2_SCENE

	# Slime 3 : très rare
	return SLIME_3_SCENE

func spawn_monsters(grid):

	var spawned := 0
	var attempts := 0
	var max_attempts := MONSTER_COUNT * 20

	var used_positions := []

	if _stairs_up_pos != Vector2i.ZERO:
		used_positions.append(_stairs_up_pos)

	if _stairs_down_pos != Vector2i.ZERO:
		used_positions.append(_stairs_down_pos)

	var monster_positions: Array[Vector2i] = []
	var monsters: Array[Node] = []

	while spawned < MONSTER_COUNT and attempts < max_attempts:
		attempts += 1

		var x = entity_rng.randi() % SIZE.x
		var y = entity_rng.randi() % SIZE.y

		var pos := Vector2i(x, y)

		if not grid[x][y]:
			continue

		if pos.distance_to(SPAWN_POS) < MIN_DISTANCE_FROM_SPAWN:
			continue

		if used_positions.has(pos):
			continue

		var scene := get_random_monster_scene()

		var monster = scene.instantiate()
		monster.position = map_to_local(pos) + Vector2(8, 8)

		add_child(monster)

		monsters.append(monster)
		monster_positions.append(pos)

		used_positions.append(pos)
		spawned += 1

	# Garantie d'au moins un Slime 3
	var slime3_count := 0

	for monster in monsters:
		if monster.scene_file_path.ends_with("slime3.tscn"):
			slime3_count += 1

	while slime3_count < MIN_SLIME3_PER_FLOOR and monsters.size() > 0:

		var replace_index := entity_rng.randi() % monsters.size()

		var old_monster = monsters[replace_index]
		var pos = monster_positions[replace_index]

		if is_instance_valid(old_monster):
			old_monster.queue_free()

		var slime3 = SLIME_3_SCENE.instantiate()
		slime3.position = map_to_local(pos) + Vector2(8, 8)

		add_child(slime3)

		monsters[replace_index] = slime3

		slime3_count += 1

	print(
		"Monstres spawn : ",
		spawned,
		" | Slime3 : ",
		slime3_count
	)


# -------------------------
# SMOOTH
# -------------------------
func smooth(grid, iterations):
	var current = grid

	for i in range(iterations):
		var new_grid = []

		for x in range(SIZE.x):
			new_grid.append([])
			for y in range(SIZE.y):
				var count = 0

				for nx in range(x - 1, x + 2):
					for ny in range(y - 1, y + 2):
						if nx == x and ny == y:
							continue
						if in_bounds(nx, ny) and current[nx][ny]:
							count += 1

				new_grid[x].append(count >= 4)

		current = new_grid

	return current


# -------------------------
# TILE PLACEMENT
# -------------------------
func place_tiles(grid):
	for x in range(SIZE.x):
		for y in range(SIZE.y):
			var pos = Vector2i(x, y)
			if grid[x][y]:
				set_cell(0, pos, SOURCE_ID, FLOOR)
			else:
				set_cell(0, pos, SOURCE_ID, get_wall_tile(grid, x, y))


# -------------------------
# AUTOTILE
# -------------------------
func get_wall_tile(grid, x, y):
	var n = is_floor(grid, x, y - 1)
	var e = is_floor(grid, x + 1, y)
	var s = is_floor(grid, x, y + 1)
	var w = is_floor(grid, x - 1, y)

	if n and w and not e and not s: return CORNER_TL
	if n and e and not w and not s: return CORNER_TR
	if s and w and not n and not e: return CORNER_BL
	if s and e and not n and not w: return CORNER_BR

	if n: return WALL_TOP
	if s: return WALL_BOTTOM
	if w: return WALL_LEFT
	if e: return WALL_RIGHT

	return WALL_TOP


# -------------------------
# UTILS
# -------------------------
func is_floor(grid, x, y):
	if not in_bounds(x, y):
		return false
	return grid[x][y]

func in_bounds(x, y):
	return x >= 0 and y >= 0 and x < SIZE.x and y < SIZE.y

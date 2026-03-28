extends TileMap

var noise := FastNoiseLite.new()

const SIZE := Vector2i(80, 60)
const SOURCE_ID := 0

# -------------------------
# MONSTRES
# -------------------------
const MONSTER_SCENE = preload("res://scenes/monster/slime.tscn")
const MONSTER_COUNT := 15
const MIN_DISTANCE_FROM_SPAWN := 6

# -------------------------
# TILES
# -------------------------
const FLOOR := Vector2i(3, 3)

const WALL_TOP := Vector2i(2, 2)
const WALL_BOTTOM := Vector2i(3, 6)
const WALL_LEFT := Vector2i(2, 3)
const WALL_RIGHT := Vector2i(6, 3)

const CORNER_TL := Vector2i(2, 2)
const CORNER_TR := Vector2i(6, 2)
const CORNER_BL := Vector2i(2, 6)
const CORNER_BR := Vector2i(6, 6)

# -------------------------
# SPAWN JOUEUR
# -------------------------
const SPAWN_POS := Vector2i(40, 30)
const SPAWN_RADIUS := 4

func _ready():
	randomize()
	noise.seed = randi()
	noise.frequency = 0.08
	generate()

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

	# 5. tiles
	place_tiles(grid)

	# 6. spawn monstres
	spawn_monsters(grid)

	print("Spawn joueur:", SPAWN_POS)

# -------------------------
# SPAWN MONSTRES (AMÉLIORÉ)
# -------------------------
func spawn_monsters(grid):
	var spawned = 0
	var attempts = 0
	var max_attempts = MONSTER_COUNT * 20

	var used_positions = []

	while spawned < MONSTER_COUNT and attempts < max_attempts:
		attempts += 1

		var x = randi() % SIZE.x
		var y = randi() % SIZE.y
		var pos = Vector2i(x, y)

		# Conditions de spawn
		if not grid[x][y]:
			continue

		if pos.distance_to(SPAWN_POS) < MIN_DISTANCE_FROM_SPAWN:
			continue

		if used_positions.has(pos):
			continue

		# Instanciation
		var monster = MONSTER_SCENE.instantiate()

		var world_pos = map_to_local(pos) + Vector2(8, 8)
		monster.position = world_pos

		add_child(monster)

		used_positions.append(pos)
		spawned += 1

	print("Monstres spawn:", spawned)

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

				for nx in range(x-1, x+2):
					for ny in range(y-1, y+2):
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
				var tile = get_wall_tile(grid, x, y)
				set_cell(0, pos, SOURCE_ID, tile)

# -------------------------
# AUTOTILE
# -------------------------
func get_wall_tile(grid, x, y):
	var n = is_floor(grid, x, y - 1)
	var e = is_floor(grid, x + 1, y)
	var s = is_floor(grid, x, y + 1)
	var w = is_floor(grid, x - 1, y)

	if n and w and not e and not s:
		return CORNER_TL
	if n and e and not w and not s:
		return CORNER_TR
	if s and w and not n and not e:
		return CORNER_BL
	if s and e and not n and not w:
		return CORNER_BR

	if n:
		return WALL_TOP
	if s:
		return WALL_BOTTOM
	if w:
		return WALL_LEFT
	if e:
		return WALL_RIGHT

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

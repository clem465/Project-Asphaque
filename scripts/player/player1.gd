extends TileMap

var fnl: FastNoiseLite = FastNoiseLite.new()

const SIZE: Vector2i = Vector2i(80, 60)
const SOURCE_ID: int = 0

const ATLAS_FLOOR: Vector2 = Vector2(3, 3)
const ATLAS_WALL_LEFT: Vector2 = Vector2(2, 3)
const ATLAS_WALL_RIGHT: Vector2 = Vector2(6, 3)
const ATLAS_WALL_TOP: Vector2 = Vector2(3, 2)
const ATLAS_WALL_BOTTOM: Vector2 = Vector2(3, 6)
const ATLAS_CORNER_TL: Vector2 = Vector2(2, 2)
const ATLAS_CORNER_TR: Vector2 = Vector2(6, 2)
const ATLAS_CORNER_BL: Vector2 = Vector2(2, 6)
const ATLAS_CORNER_BR: Vector2 = Vector2(6, 6)

const ATLAS_UNREACHABLE: Vector2 = Vector2(0, 0)  # remplace par ta tuile "inaccessible"
const ATLAS_SPAWN: Vector2 = Vector2(4, 3)        # remplace par ta tuile "spawn"

const NOISE_FREQ: float = 0.06
const NOISE_THRESHOLD: float = 0.12
const ROOM_ATTEMPTS: int = 30
const ROOM_MIN: Vector2i = Vector2i(4, 4)
const ROOM_MAX: Vector2i = Vector2i(12, 8)
const SMOOTH_ITER: int = 3

# --- spawn fixe : coordonnées de la salle qui ne bouge pas ---
# change la position et la taille si tu veux un autre emplacement
const SPAWN_ROOM_POS: Vector2i = Vector2i(6, 6)   # coin supérieur gauche de la salle fixe
const SPAWN_ROOM_SIZE: Vector2i = Vector2i(8, 6)  # largeur, hauteur de la salle fixe
var SPAWN_POS: Vector2i = Vector2i(-1, -1)        # sera défini au centre de la salle fixe
const SPAWN_CLEAR_RADIUS: int = 1

func _ready() -> void:
	randomize()
	fnl.seed = randi()
	fnl.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fnl.frequency = NOISE_FREQ
	generate_dungeon()
	# instancie automatiquement le joueur et l'ajoute comme enfant du parent du TileMap
	spawn_player("res://scenes/player.tscn")

func generate_dungeon() -> void:
	var grid: Array = _init_noise_grid()
	# créer la salle de spawn fixe en premier et la retourner dans la liste des salles
	var rooms: Array = _carve_rooms_with_fixed_spawn(grid)
	# s'assurer que le spawn est relié (fonction creuse un tunnel si nécessaire)
	_ensure_spawn_connected(grid, rooms)
	_connect_rooms(grid, rooms)
	grid = _smooth_grid(grid, SMOOTH_ITER)
	var keep: Dictionary = _get_largest_region_keep(grid)
	# forcer clear autour du spawn
	if SPAWN_POS.x >= 0:
		for sx in range(SPAWN_POS.x - SPAWN_CLEAR_RADIUS, SPAWN_POS.x + SPAWN_CLEAR_RADIUS + 1):
			for sy in range(SPAWN_POS.y - SPAWN_CLEAR_RADIUS, SPAWN_POS.y + SPAWN_CLEAR_RADIUS + 1):
				if sx >= 0 and sy >= 0 and sx < SIZE.x and sy < SIZE.y:
					keep[str(sx) + "," + str(sy)] = true
	# appliquer keep sur la grille (true = floor)
	for x in range(SIZE.x):
		for y in range(SIZE.y):
			var key: String = str(x) + "," + str(y)
			if keep.has(key):
				grid[x][y] = true
			else:
				grid[x][y] = false
	_place_tiles_from_grid(grid)

# --- initial noise grid (true = floor) ---
func _init_noise_grid() -> Array:
	var grid: Array = []
	for x in range(SIZE.x):
		grid.append([])
		for y in range(SIZE.y):
			var n: float = fnl.get_noise_2d(x, y)
			var is_floor: bool = n > NOISE_THRESHOLD
			grid[x].append(is_floor)
	return grid

# --- carve rooms but include a fixed spawn room first ---
func _carve_rooms_with_fixed_spawn(grid: Array) -> Array:
	var rooms: Array = []
	# 1) créer la salle fixe (ne bouge pas)
	var fx: int = SPAWN_ROOM_POS.x
	var fy: int = SPAWN_ROOM_POS.y
	var fw: int = SPAWN_ROOM_SIZE.x
	var fh: int = SPAWN_ROOM_SIZE.y
	var fixed_rect: Rect2i = Rect2i(fx, fy, fw, fh)
	rooms.append(fixed_rect)
	# marquer les cellules de la salle fixe comme floor
	for rx in range(fixed_rect.position.x, fixed_rect.position.x + fixed_rect.size.x):
		for ry in range(fixed_rect.position.y, fixed_rect.position.y + fixed_rect.size.y):
			if rx >= 0 and ry >= 0 and rx < SIZE.x and ry < SIZE.y:
				grid[rx][ry] = true
	# définir SPAWN_POS au centre de la salle fixe
	var cx: int = int(fixed_rect.position.x + fixed_rect.size.x / 2)
	var cy: int = int(fixed_rect.position.y + fixed_rect.size.y / 2)
	SPAWN_POS = Vector2i(cx, cy)

	# 2) générer les autres salles aléatoires comme avant
	for i in range(ROOM_ATTEMPTS):
		var w: int = randi_range(ROOM_MIN.x, ROOM_MAX.x)
		var h: int = randi_range(ROOM_MIN.y, ROOM_MAX.y)
		var x: int = randi_range(1, SIZE.x - w - 2)
		var y: int = randi_range(1, SIZE.y - h - 2)
		var rect: Rect2i = Rect2i(x, y, w, h)
		var ok: bool = true
		for r in rooms:
			if rect.grow(2).intersects(r):
				ok = false
				break
		if ok:
			rooms.append(rect)
			for rx in range(rect.position.x, rect.position.x + rect.size.x):
				for ry in range(rect.position.y, rect.position.y + rect.size.y):
					if rx >= 0 and ry >= 0 and rx < SIZE.x and ry < SIZE.y:
						grid[rx][ry] = true
	self.set_meta("dungeon_rooms", rooms)
	return rooms

# --- ensure spawn connected : creuse un tunnel entre SPAWN_POS et la salle la plus proche (ou cellule floor la plus proche) ---
func _ensure_spawn_connected(grid: Array, rooms: Array) -> void:
	# si spawn hors limites, on ignore
	if SPAWN_POS.x < 0 or SPAWN_POS.y < 0 or SPAWN_POS.x >= SIZE.x or SPAWN_POS.y >= SIZE.y:
		return
	# si spawn déjà floor, rien à faire
	if grid[SPAWN_POS.x][SPAWN_POS.y]:
		return
	# si on a des salles, trouver la salle la plus proche (par centre) et creuser
	if rooms != null and rooms.size() > 0:
		var best_room: Rect2i = null
		var best_dist: float = 1e9
		for r in rooms:
			# ignorer la salle fixe elle-même (si présente) — mais distance 0 sera ignorée par la condition grid[spawn]
			var cx: int = int(r.position.x + r.size.x / 2)
			var cy: int = int(r.position.y + r.size.y / 2)
			var d: float = SPAWN_POS.distance_to(Vector2i(cx, cy))
			if d < best_dist:
				best_dist = d
				best_room = r
		if best_room != null:
			var target: Vector2i = Vector2i(int(best_room.position.x + best_room.size.x / 2), int(best_room.position.y + best_room.size.y / 2))
			_carve_tunnel(grid, SPAWN_POS, target)
			grid[SPAWN_POS.x][SPAWN_POS.y] = true
			return
	# sinon BFS pour trouver la cellule floor la plus proche
	var visited: Array = []
	for x in range(SIZE.x):
		visited.append([])
		for y in range(SIZE.y):
			visited[x].append(false)
	var queue: Array = [SPAWN_POS]
	visited[SPAWN_POS.x][SPAWN_POS.y] = true
	while queue.size() > 0:
		var p: Vector2i = queue.pop_front()
		if p.x >= 0 and p.y >= 0 and p.x < SIZE.x and p.y < SIZE.y and grid[p.x][p.y]:
			_carve_tunnel(grid, SPAWN_POS, p)
			grid[SPAWN_POS.x][SPAWN_POS.y] = true
			return
		for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var nx: int = p.x + dir.x
			var ny: int = p.y + dir.y
			if nx >= 0 and ny >= 0 and nx < SIZE.x and ny < SIZE.y and not visited[nx][ny]:
				visited[nx][ny] = true
				queue.append(Vector2i(nx, ny))
	# si rien trouvé, forcer la case spawn en floor
	grid[SPAWN_POS.x][SPAWN_POS.y] = true

# --- relier les salles par tunnels simples (ligne droite en L) ---
func _connect_rooms(grid: Array, rooms: Array) -> void:
	if rooms == null or rooms.size() == 0:
		return
	rooms.sort_custom(Callable(self, "_rect_compare_by_x"))
	for i in range(rooms.size() - 1):
		var a: Rect2i = rooms[i]
		var b: Rect2i = rooms[i + 1]
		var ax: int = int(a.position.x + a.size.x / 2)
		var ay: int = int(a.position.y + a.size.y / 2)
		var bx: int = int(b.position.x + b.size.x / 2)
		var by: int = int(b.position.y + b.size.y / 2)
		_carve_tunnel(grid, Vector2i(ax, ay), Vector2i(bx, by))

func _rect_compare_by_x(a, b) -> int:
	var ax: float = a.position.x + a.size.x / 2
	var bx: float = b.position.x + b.size.x / 2
	return int(ax - bx)

func _carve_tunnel(grid: Array, a: Vector2i, b: Vector2i) -> void:
	var x: int = a.x
	var y: int = a.y
	if randi() % 2 == 0:
		while x != b.x:
			if x >= 0 and y >= 0 and x < SIZE.x and y < SIZE.y:
				grid[x][y] = true
			x += sign(b.x - x)
		while y != b.y:
			if x >= 0 and y >= 0 and x < SIZE.x and y < SIZE.y:
				grid[x][y] = true
			y += sign(b.y - y)
	else:
		while y != b.y:
			if x >= 0 and y >= 0 and x < SIZE.x and y < SIZE.y:
				grid[x][y] = true
			y += sign(b.y - y)
		while x != b.x:
			if x >= 0 and y >= 0 and x < SIZE.x and y < SIZE.y:
				grid[x][y] = true
			x += sign(b.x - x)

# --- smoothing : retourne la nouvelle grille ---
func _smooth_grid(grid: Array, iterations: int) -> Array:
	var current: Array = grid
	for i in range(iterations):
		var new_grid: Array = []
		for x in range(SIZE.x):
			new_grid.append([])
			for y in range(SIZE.y):
				var floor_neighbors: int = 0
				for nx in range(x - 1, x + 2):
					for ny in range(y - 1, y + 2):
						if nx == x and ny == y:
							continue
						if nx >= 0 and ny >= 0 and nx < SIZE.x and ny < SIZE.y:
							if current[nx][ny]:
								floor_neighbors += 1
				if floor_neighbors >= 4:
					new_grid[x].append(true)
				else:
					new_grid[x].append(false)
		current = new_grid
	return current

# --- retourne un dictionnaire des positions à garder (accessible) ---
func _get_largest_region_keep(grid: Array) -> Dictionary:
	var visited: Array = []
	for x in range(SIZE.x):
		visited.append([])
		for y in range(SIZE.y):
			visited[x].append(false)
	var best_region: Array = []
	for x in range(SIZE.x):
		for y in range(SIZE.y):
			if visited[x][y]:
				continue
			if not grid[x][y]:
				visited[x][y] = true
				continue
			var queue: Array = [Vector2i(x, y)]
			var region: Array = []
			visited[x][y] = true
			while queue.size() > 0:
				var p: Vector2i = queue.pop_front()
				region.append(p)
				for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var nx: int = p.x + dir.x
					var ny: int = p.y + dir.y
					if nx >= 0 and ny >= 0 and nx < SIZE.x and ny < SIZE.y:
						if not visited[nx][ny] and grid[nx][ny]:
							visited[nx][ny] = true
							queue.append(Vector2i(nx, ny))
			if region.size() > best_region.size():
				best_region = region
	var keep: Dictionary = {}
	for p in best_region:
		keep[str(p.x) + "," + str(p.y)] = true
	return keep

# --- placer les tiles en utilisant tes coordonnées atlas et la logique voisins ---
func _place_tiles_from_grid(grid: Array) -> void:
	for x in range(SIZE.x):
		for y in range(SIZE.y):
			var pos: Vector2i = Vector2i(x, y)
			if grid[x][y]:
				set_cell(0, pos, SOURCE_ID, ATLAS_FLOOR)
				if SPAWN_POS == pos:
					set_cell(0, pos, SOURCE_ID, ATLAS_SPAWN)
			else:
				var atlas: Vector2 = _choose_wall_tile_from_grid(grid, x, y)
				var n: bool = _is_floor(grid, x, y - 1)
				var e: bool = _is_floor(grid, x + 1, y)
				var s: bool = _is_floor(grid, x, y + 1)
				var w: bool = _is_floor(grid, x - 1, y)
				if not (n or e or s or w):
					set_cell(0, pos, SOURCE_ID, ATLAS_UNREACHABLE)
				else:
					set_cell(0, pos, SOURCE_ID, atlas)

func _is_floor(grid: Array, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= SIZE.x or y >= SIZE.y:
		return false
	return grid[x][y]

func _choose_wall_tile_from_grid(grid: Array, x: int, y: int) -> Vector2:
	var n: bool = _is_floor(grid, x, y - 1)
	var e: bool = _is_floor(grid, x + 1, y)
	var s: bool = _is_floor(grid, x, y + 1)
	var w: bool = _is_floor(grid, x - 1, y)

	if n and w and not (e or s):
		return ATLAS_CORNER_TL
	if n and e and not (w or s):
		return ATLAS_CORNER_TR
	if s and w and not (n or e):
		return ATLAS_CORNER_BL
	if s and e and not (n or w):
		return ATLAS_CORNER_BR

	if n and not (e or s or w):
		return ATLAS_WALL_TOP
	if s and not (n or e or w):
		return ATLAS_WALL_BOTTOM
	if w and not (n or e or s):
		return ATLAS_WALL_LEFT
	if e and not (n or s or w):
		return ATLAS_WALL_RIGHT

	if n and s and not (e or w):
		return ATLAS_WALL_LEFT
	if e and w and not (n or s):
		return ATLAS_WALL_TOP

	if n and w:
		return ATLAS_CORNER_TL
	if n and e:
		return ATLAS_CORNER_TR
	if s and w:
		return ATLAS_CORNER_BL
	if s and e:
		return ATLAS_CORNER_BR

	return ATLAS_WALL_LEFT

# --- utilitaire : instancier le joueur et le positionner sur SPAWN_POS ---
func spawn_player(path_to_scene: String = "res://scenes/player.tscn") -> Node:
	if SPAWN_POS.x < 0:
		push_error("SPAWN_POS invalide : aucune salle trouvée.")
		return null

	var scene: PackedScene = load(path_to_scene)
	if scene == null:
		push_error("Impossible de charger la scène joueur : " + path_to_scene)
		return null

	var player: Node = scene.instantiate()

	# récupérer la taille d'une cellule (Vector2)
	var cs: Vector2 = self.cell_size

	# position locale en pixels (coin supérieur gauche de la cellule)
	var local_px: Vector2 = Vector2(SPAWN_POS.x * cs.x, SPAWN_POS.y * cs.y)

	# convertir en position monde en tenant compte de la transformation du TileMap
	var world_pos: Vector2 = to_global(local_px) + cs * 0.5

	# positionner le joueur (Node2D attendu)
	if player is Node2D:
		(player as Node2D).global_position = world_pos

	# attacher le joueur au parent du TileMap (ton Node2D racine du donjon)
	var parent_node: Node = self.get_parent()
	if parent_node != null:
		parent_node.add_child(player)
	else:
		get_tree().current_scene.add_child(player)

	return player

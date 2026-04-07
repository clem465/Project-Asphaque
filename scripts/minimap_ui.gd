extends CanvasLayer

@export var toggle_button: Button
@export var minimap_window: Panel
@export var map_viewport: SubViewport
@export var map_camera: Camera2D

@export var fog_cell_size: float = 32.0
@export var visible_radius_world: float = 120.0
@export var fog_disabled_scene_keywords: PackedStringArray = ["hub", "village"]

@export var inventory_button: Button
@export var inventory_window: Panel

@export var stats_button: Button
@export var stats_window: Panel

@export var actions_button: Button
@export var actions_window: Panel

@onready var map_container: SubViewportContainer = $MinimapWindow/MapContainer
@onready var opacity_slider: HSlider = $MinimapWindow/TitleBar/Header/OpacitySlider
@onready var close_button: Button = $MinimapWindow/TitleBar/Header/CloseButton
@onready var inventory_close_button: Button = $InventoryWindow/TitleBar/Header/CloseButton
@onready var stats_close_button: Button = $StatsWindow/TitleBar/Header/CloseButton
@onready var actions_close_button: Button = $ActionsWindow/TitleBar/Header/CloseButton
@onready var inventory_opacity_slider: HSlider = $InventoryWindow/TitleBar/Header/OpacitySlider
@onready var stats_opacity_slider: HSlider = $StatsWindow/TitleBar/Header/OpacitySlider
@onready var actions_opacity_slider: HSlider = $ActionsWindow/TitleBar/Header/OpacitySlider
@onready var fog_overlay: TextureRect = $MinimapWindow/MapContainer/FogOverlay
@onready var inventory_placeholder: Label = $InventoryWindow/Content/InventoryPlaceholder
@onready var hp_label: Label = $StatsWindow/Content/StatsVBox/HpLabel
@onready var hp_bar: ProgressBar = $StatsWindow/Content/StatsVBox/HpBar
@onready var atk_label: Label = $StatsWindow/Content/StatsVBox/AtkLabel
@onready var def_label: Label = $StatsWindow/Content/StatsVBox/DefLabel
@onready var attack_toggle_button: Button = $ActionsWindow/Content/ActionsVBox/Action1

var _map_bounds: Rect2 = Rect2()
var _fog_grid_size: Vector2i = Vector2i.ZERO
var _discovered_image: Image
var _fog_display_image: Image
var _fog_texture: ImageTexture
var _fog_atlas: AtlasTexture
var _player_ref: Node2D
var _last_player_pos: Vector2 = Vector2.ZERO
var _has_last_player_pos: bool = false
var _fog_ready: bool = false
var _fog_enabled_for_scene: bool = true
var _is_syncing_attack_toggle: bool = false

func _ready() -> void:
	_disable_button_keyboard_focus(self)

	if toggle_button:
		toggle_button.pressed.connect(_on_toggle_pressed)
	if minimap_window:
		minimap_window.hide()
		minimap_window.resized.connect(_on_window_resized)

	if inventory_button:
		inventory_button.pressed.connect(_on_inventory_pressed)
	if inventory_window:
		inventory_window.hide()

	if stats_button:
		stats_button.pressed.connect(_on_stats_pressed)
	if stats_window:
		stats_window.hide()

	if actions_button:
		actions_button.pressed.connect(_on_actions_pressed)
	if actions_window:
		actions_window.hide()

	if opacity_slider:
		opacity_slider.value_changed.connect(_on_opacity_changed)

	if close_button:
		close_button.pressed.connect(_on_toggle_pressed)

	if inventory_opacity_slider:
		inventory_opacity_slider.value_changed.connect(_on_inventory_opacity_changed)

	if stats_opacity_slider:
		stats_opacity_slider.value_changed.connect(_on_stats_opacity_changed)

	if actions_opacity_slider:
		actions_opacity_slider.value_changed.connect(_on_actions_opacity_changed)

	if inventory_close_button:
		inventory_close_button.pressed.connect(_on_inventory_pressed)

	if stats_close_button:
		stats_close_button.pressed.connect(_on_stats_pressed)

	if actions_close_button:
		actions_close_button.pressed.connect(_on_actions_pressed)

	if attack_toggle_button:
		attack_toggle_button.toggled.connect(_on_attack_toggle_toggled)
		_update_attack_toggle_text(attack_toggle_button.button_pressed)

	if map_viewport:
		map_viewport.world_2d = get_viewport().world_2d
	
	if map_camera:
		map_camera.make_current()
		_configure_minimap_cull_mask()

	_setup_fog_overlay()

	call_deferred("_center_map")
	call_deferred("_sync_attack_toggle_from_player")

func _disable_button_keyboard_focus(node: Node) -> void:
	if node is Button:
		(node as Button).focus_mode = Control.FOCUS_NONE

	for child in node.get_children():
		_disable_button_keyboard_focus(child)

func _process(_delta: float) -> void:
	_update_player_panels()

	if not _fog_enabled_for_scene or not _fog_ready:
		return

	_update_fog_overlay_region()
	_update_fog_discovery()

func _setup_fog_overlay() -> void:
	if fog_overlay == null:
		return

	fog_overlay.texture = null
	fog_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fog_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	fog_overlay.visible = true

func _configure_minimap_cull_mask() -> void:
	# Keep only canvas layer 1 visible in minimap.
	# Health bars are moved to layer 2 in gameplay scripts.
	var configured := false

	if map_viewport and map_viewport.has_method("set_canvas_cull_mask_bit"):
		for layer_bit in range(0, 20):
			map_viewport.set_canvas_cull_mask_bit(layer_bit, layer_bit == 0)
		configured = true

	# Compatibility fallback in case viewport API differs.
	if not configured and map_camera:
		if map_camera.has_method("set_cull_mask_value"):
			for layer in range(1, 21):
				map_camera.set_cull_mask_value(layer, layer == 1)
		elif map_camera.has_method("set_canvas_cull_mask_bit"):
			for layer_bit in range(0, 20):
				map_camera.set_canvas_cull_mask_bit(layer_bit, layer_bit == 0)

func _on_window_resized() -> void:
	if map_container and map_viewport:
		map_viewport.size = map_container.size
	_update_fog_overlay_region()

func _on_opacity_changed(value: float) -> void:
	if minimap_window:
		minimap_window.modulate.a = value

func _on_inventory_opacity_changed(value: float) -> void:
	if inventory_window:
		inventory_window.modulate.a = value

func _on_stats_opacity_changed(value: float) -> void:
	if stats_window:
		stats_window.modulate.a = value

func _on_actions_opacity_changed(value: float) -> void:
	if actions_window:
		actions_window.modulate.a = value

func _on_toggle_pressed() -> void:
	if minimap_window:
		minimap_window.visible = not minimap_window.visible

func _on_inventory_pressed() -> void:
	if inventory_window:
		inventory_window.visible = not inventory_window.visible

func _on_stats_pressed() -> void:
	if stats_window:
		stats_window.visible = not stats_window.visible

func _on_actions_pressed() -> void:
	if actions_window:
		actions_window.visible = not actions_window.visible

func _on_attack_toggle_toggled(enabled: bool) -> void:
	if _is_syncing_attack_toggle:
		return

	var player: Node2D = _get_player_ref()
	if player:
		if player.has_method("set_attack_enabled"):
			player.set_attack_enabled(enabled)
		else:
			player.set("attack_enabled", enabled)

	_update_attack_toggle_text(enabled)

func _update_attack_toggle_text(enabled: bool) -> void:
	if attack_toggle_button:
		attack_toggle_button.text = "Attack: ON" if enabled else "Attack: OFF"

func _sync_attack_toggle_from_player() -> void:
	var player: Node2D = _get_player_ref()
	if player == null or attack_toggle_button == null:
		return

	var enabled := true
	if player.has_method("is_attack_enabled"):
		enabled = bool(player.is_attack_enabled())
	else:
		var raw_value = player.get("attack_enabled")
		if raw_value is bool:
			enabled = raw_value

	_is_syncing_attack_toggle = true
	attack_toggle_button.set_pressed_no_signal(enabled)
	_is_syncing_attack_toggle = false
	_update_attack_toggle_text(enabled)

func _update_player_panels() -> void:
	var player: Node2D = _get_player_ref()
	if player == null:
		return

	var current_hp: int = _read_player_int(player, "get_current_health", "health", 0)
	var max_hp: int = max(1, _read_player_int(player, "get_max_health", "max_health", 1))
	var atk: int = _read_player_int(player, "get_attack_value", "attack_damage", 0)
	var defense: int = _read_player_int(player, "get_defense_value", "defense", 0)
	var coins: int = _read_player_int(player, "get_coins", "coins", 0)

	if hp_label:
		hp_label.text = "HP: %d / %d" % [current_hp, max_hp]

	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = clamp(current_hp, 0, max_hp)

	if atk_label:
		atk_label.text = "ATK: %d" % atk

	if def_label:
		def_label.text = "DEF: %d" % defense

	if inventory_placeholder:
		inventory_placeholder.text = "Coins: %d" % coins

	_sync_attack_toggle_from_player()

func _read_player_int(player: Node2D, getter_name: String, property_name: String, default_value: int) -> int:
	if player.has_method(getter_name):
		return int(player.call(getter_name))

	var raw_value = player.get(property_name)
	if raw_value is int or raw_value is float:
		return int(raw_value)

	return default_value

func _center_map() -> void:
	var main_cam = get_viewport().get_camera_2d()
	if main_cam and map_camera:
		map_camera.global_position = main_cam.global_position

	_fog_enabled_for_scene = _should_enable_fog_for_scene()
	if not _fog_enabled_for_scene:
		_disable_fog_overlay()

	var bounds = _compute_map_bounds()
	if bounds.size.x > 0.0 and bounds.size.y > 0.0 and map_container:
		_map_bounds = bounds
		map_container.set_map_bounds(bounds)
		if _fog_enabled_for_scene:
			_initialize_fog(bounds)

func _should_enable_fog_for_scene() -> bool:
	var root: Node = get_tree().current_scene
	if root == null:
		return true

	var scene_path: String = root.scene_file_path.to_lower()
	for raw_keyword in fog_disabled_scene_keywords:
		var keyword: String = String(raw_keyword).to_lower()
		if keyword != "" and scene_path.contains(keyword):
			return false

	return true

func _disable_fog_overlay() -> void:
	_fog_ready = false
	if fog_overlay:
		fog_overlay.visible = false

func _initialize_fog(bounds: Rect2) -> void:
	if fog_overlay == null:
		return

	var grid_w: int = maxi(1, int(ceil(bounds.size.x / fog_cell_size)))
	var grid_h: int = maxi(1, int(ceil(bounds.size.y / fog_cell_size)))
	var next_grid := Vector2i(grid_w, grid_h)

	if _fog_ready and next_grid == _fog_grid_size:
		_update_fog_overlay_region()
		_update_fog_discovery()
		return

	_fog_grid_size = next_grid
	_discovered_image = Image.create(grid_w, grid_h, false, Image.FORMAT_RGBA8)
	_discovered_image.fill(Color(0, 0, 0, 1))
	_fog_display_image = Image.create(grid_w, grid_h, false, Image.FORMAT_RGBA8)
	_fog_display_image.fill(Color(0, 0, 0, 1))
	_fog_texture = ImageTexture.create_from_image(_fog_display_image)
	_fog_atlas = AtlasTexture.new()
	_fog_atlas.atlas = _fog_texture
	_fog_atlas.region = Rect2(Vector2.ZERO, Vector2(grid_w, grid_h))
	fog_overlay.texture = _fog_atlas
	fog_overlay.visible = true
	_has_last_player_pos = false
	_fog_ready = true

	_update_fog_overlay_region()
	_update_fog_discovery()

func _update_fog_overlay_region() -> void:
	if not _fog_ready or fog_overlay == null or _fog_atlas == null or map_camera == null or map_viewport == null:
		return

	var safe_zoom: Vector2 = map_camera.zoom
	if safe_zoom.x == 0.0:
		safe_zoom.x = 1.0
	if safe_zoom.y == 0.0:
		safe_zoom.y = 1.0

	# Camera2D zoom reduces visible world when values grow, so world size is viewport / zoom.
	var view_size_world: Vector2 = Vector2(map_viewport.size) / safe_zoom
	var view_min_world: Vector2 = map_camera.global_position - view_size_world * 0.5

	var tex_pos: Vector2 = (view_min_world - _map_bounds.position) / fog_cell_size
	var tex_size: Vector2 = view_size_world / fog_cell_size

	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	var max_x: float = float(_fog_grid_size.x) - tex_size.x
	var max_y: float = float(_fog_grid_size.y) - tex_size.y

	if max_x < 0.0:
		tex_pos.x = 0.0
		tex_size.x = float(_fog_grid_size.x)
	else:
		tex_pos.x = clamp(tex_pos.x, 0.0, max_x)

	if max_y < 0.0:
		tex_pos.y = 0.0
		tex_size.y = float(_fog_grid_size.y)
	else:
		tex_pos.y = clamp(tex_pos.y, 0.0, max_y)

	_fog_atlas.region = Rect2(tex_pos, tex_size)

func _get_player_ref() -> Node2D:
	if _player_ref and is_instance_valid(_player_ref):
		return _player_ref

	var group_player: Node = get_tree().get_first_node_in_group("player")
	if group_player is Node2D:
		_player_ref = group_player
		return _player_ref

	var root: Node = get_tree().current_scene
	if root:
		var fallback_player: Node = root.find_child("Player", true, false)
		if fallback_player is Node2D:
			_player_ref = fallback_player
			return _player_ref

		var fallback: Node = root.find_child("Player1", true, false)
		if fallback is Node2D:
			_player_ref = fallback

	return _player_ref

func _update_fog_discovery() -> void:
	if not _fog_ready or _discovered_image == null or _fog_display_image == null or _fog_texture == null:
		return

	var player: Node2D = _get_player_ref()
	if player == null:
		return

	var player_pos: Vector2 = player.global_position
	if _has_last_player_pos and player_pos.distance_squared_to(_last_player_pos) < 1.0:
		return

	_last_player_pos = player_pos
	_has_last_player_pos = true

	var center: Vector2i = _world_to_fog_cell(player_pos)
	var radius_cells: int = int(ceil(visible_radius_world / fog_cell_size))
	var radius_world_sq: float = visible_radius_world * visible_radius_world

	for y in range(-radius_cells, radius_cells + 1):
		for x in range(-radius_cells, radius_cells + 1):
			var cell := center + Vector2i(x, y)
			if cell.x < 0 or cell.y < 0 or cell.x >= _fog_grid_size.x or cell.y >= _fog_grid_size.y:
				continue

			var cell_world: Vector2 = _fog_cell_center_world(cell)
			if cell_world.distance_squared_to(player_pos) > radius_world_sq:
				continue

			_discovered_image.set_pixel(cell.x, cell.y, Color(1, 1, 1, 1))

	_rebuild_fog_display(player_pos, radius_world_sq)

func _rebuild_fog_display(player_pos: Vector2, radius_world_sq: float) -> void:

	for y in range(_fog_grid_size.y):
		for x in range(_fog_grid_size.x):
			var fog_color: Color = Color(0.0, 0.0, 0.0, 1.0)

			if _discovered_image.get_pixel(x, y).r > 0.5:
				fog_color = Color(0.18, 0.18, 0.18, 0.55)

			var cell_world: Vector2 = _fog_cell_center_world(Vector2i(x, y))
			if cell_world.distance_squared_to(player_pos) <= radius_world_sq:
				fog_color = Color(0.0, 0.0, 0.0, 0.0)

			_fog_display_image.set_pixel(x, y, fog_color)

	_fog_texture.update(_fog_display_image)

func _world_to_fog_cell(world_pos: Vector2) -> Vector2i:
	var local := world_pos - _map_bounds.position
	return Vector2i(
		int(floor(local.x / fog_cell_size)),
		int(floor(local.y / fog_cell_size))
	)

func _fog_cell_center_world(cell: Vector2i) -> Vector2:
	return _map_bounds.position + Vector2(
		(float(cell.x) + 0.5) * fog_cell_size,
		(float(cell.y) + 0.5) * fog_cell_size
	)

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
			var cell_size = tm.tile_set.tile_size if tm.tile_set else Vector2(16, 16)
			var local_rect = Rect2(Vector2(used.position) * Vector2(cell_size), Vector2(used.size) * Vector2(cell_size))
			var global_rect = Rect2(tm.to_global(local_rect.position), local_rect.size)

			if is_first:
				full_rect = global_rect
				is_first = false
			else:
				full_rect = full_rect.merge(global_rect)

	return full_rect if not is_first else Rect2()

func _find_all_tilemaps(node: Node) -> Array:
	var result = []
	if node is TileMap:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_tilemaps(child))
	return result

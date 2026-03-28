extends CanvasLayer

@export var toggle_button: Button
@export var minimap_window: Panel
@export var map_viewport: SubViewport
@export var map_camera: Camera2D

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

func _ready() -> void:
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

	if map_viewport:
		map_viewport.world_2d = get_viewport().world_2d
	
	if map_camera:
		map_camera.make_current()

	call_deferred("_center_map")

func _on_window_resized() -> void:
	if map_container and map_viewport:
		map_viewport.size = map_container.size

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

func _center_map() -> void:
	var main_cam = get_viewport().get_camera_2d()
	if main_cam and map_camera:
		map_camera.global_position = main_cam.global_position

	var bounds = _compute_map_bounds()
	if bounds.size.x > 0.0 and bounds.size.y > 0.0 and map_container:
		map_container.set_map_bounds(bounds)

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

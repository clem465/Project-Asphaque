extends SubViewportContainer

@export var map_camera: Camera2D

var _map_bounds: Rect2 = Rect2()
var _has_bounds: bool = false

var _panning: bool = false
var _pan_last_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func set_map_bounds(bounds: Rect2) -> void:
	_map_bounds = bounds
	_has_bounds = bounds.size.x > 0.0 and bounds.size.y > 0.0
	_clamp_camera_to_bounds()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if map_camera: map_camera.zoom *= 1.15
			_clamp_camera_to_bounds()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if map_camera: map_camera.zoom /= 1.15
			_clamp_camera_to_bounds()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_panning = true
				_pan_last_pos = event.position
				accept_event()
			else:
				_panning = false
				accept_event()
	elif event is InputEventMouseMotion and _panning:
		if map_camera:
			var delta = _pan_last_pos - event.position
			map_camera.global_position += delta / map_camera.zoom
			_pan_last_pos = event.position
			_clamp_camera_to_bounds()
		accept_event()

func _clamp_camera_to_bounds() -> void:
	if map_camera == null or not _has_bounds:
		return

	var view_size = size / map_camera.zoom
	var half = view_size * 0.5

	var min_x = _map_bounds.position.x + half.x
	var max_x = _map_bounds.position.x + _map_bounds.size.x - half.x
	var min_y = _map_bounds.position.y + half.y
	var max_y = _map_bounds.position.y + _map_bounds.size.y - half.y

	var target = map_camera.global_position

	if min_x > max_x:
		target.x = _map_bounds.get_center().x
	else:
		target.x = clamp(target.x, min_x, max_x)

	if min_y > max_y:
		target.y = _map_bounds.get_center().y
	else:
		target.y = clamp(target.y, min_y, max_y)

	map_camera.global_position = target

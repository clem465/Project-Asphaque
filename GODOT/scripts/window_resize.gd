extends ColorRect

@export var target_window: Control
@export var min_size: Vector2 = Vector2(200, 160)

var _resizing: bool = false
var _start_mouse: Vector2 = Vector2.ZERO
var _start_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_resizing = true
			_start_mouse = get_global_mouse_position()
			if target_window:
				_start_size = target_window.size
			accept_event()
		else:
			_resizing = false
			accept_event()
	elif event is InputEventMouseMotion and _resizing:
		if target_window:
			var delta = get_global_mouse_position() - _start_mouse
			var next_size = _start_size + delta
			next_size.x = max(next_size.x, min_size.x)
			next_size.y = max(next_size.y, min_size.y)

			var view_rect = get_viewport().get_visible_rect()
			var max_size = view_rect.position + view_rect.size - target_window.global_position
			next_size.x = min(next_size.x, max_size.x)
			next_size.y = min(next_size.y, max_size.y)

			target_window.size = next_size
		accept_event()

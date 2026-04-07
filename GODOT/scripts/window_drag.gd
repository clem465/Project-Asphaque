extends ColorRect

@export var target_window: Control

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			if target_window:
				_drag_offset = get_global_mouse_position() - target_window.global_position
			accept_event()
		else:
			_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		if target_window:
			target_window.global_position = get_global_mouse_position() - _drag_offset
			_clamp_window_to_screen()
		accept_event()

func _clamp_window_to_screen() -> void:
	if target_window == null:
		return

	var view_rect = get_viewport().get_visible_rect()
	var min_pos = view_rect.position
	var max_pos = view_rect.position + view_rect.size - target_window.size

	target_window.global_position.x = clamp(target_window.global_position.x, min_pos.x, max_pos.x)
	target_window.global_position.y = clamp(target_window.global_position.y, min_pos.y, max_pos.y)

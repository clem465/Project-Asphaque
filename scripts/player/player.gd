extends CharacterBody2D

@export var speed: float = 80.0
@onready var actionable_finder: Area2D = $Direction/ActionableFinder

var input_vector := Vector2.ZERO
var last_direction := "down"  # direction par défaut


func _process(delta: float) -> void:
	_get_input()
	_update_animation()
	
func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("interact"):
		var actionables = actionable_finder.get_overlapping_areas()
		if actionables.size() > 0:
			actionables[0].action()
			return

func _physics_process(delta: float) -> void:
	velocity = input_vector * speed
	move_and_slide()

func _get_input() -> void:
	input_vector = Vector2.ZERO	
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	if input_vector.length() > 1:
		input_vector = input_vector.normalized()
	

func _update_animation() -> void:
	var anim = $AnimatedSprite2D

	if input_vector == Vector2.ZERO: 
		anim.play("idle_" + last_direction)
		return

	# Détection de direction
	if abs(input_vector.x) > abs(input_vector.y):
		if input_vector.x > 0:
			last_direction = "right"
			anim.play("run_right")
		else:
			last_direction = "left"
			anim.play("run_left")
	else:
		if input_vector.y > 0:
			last_direction = "down"
			anim.play("run_down")
		else:
			last_direction = "up"
			anim.play("run_up")

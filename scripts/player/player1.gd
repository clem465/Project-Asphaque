extends CharacterBody2D

@export var speed: float = 80.0

@onready var actionable_finder: Area2D = $Direction/ActionableFinder
@onready var hitbox: Area2D = $Direction/Hitbox
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var input_vector := Vector2.ZERO
var last_direction := "down"
var is_attacking := false

var hitbox_offset := Vector2.ZERO

func _ready() -> void:
	# Position de base de la hitbox
	hitbox_offset = hitbox.position


func _unhandled_input(event: InputEvent) -> void:
	# Interaction
	if Input.is_action_just_pressed("interact"):
		var actionables = actionable_finder.get_overlapping_areas()
		
		if actionables.size() > 0:
			var target = actionables[0]
			if target.has_method("action"):
				target.action()
	
	# Attaque
	if Input.is_action_just_pressed("attack") and not is_attacking:
		_attack()


func _physics_process(delta: float) -> void:	
	if not is_attacking:
		_get_input()
	else:
		input_vector = Vector2.ZERO

	velocity = input_vector * speed
	move_and_slide()

	_update_animation()


func _get_input() -> void:
	input_vector = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	if input_vector.length() > 1:
		input_vector = input_vector.normalized()


func _update_animation() -> void:
	_update_hitbox_position()
	
	if is_attacking:
		animated_sprite.play("attack_" + last_direction)
		return

	if input_vector == Vector2.ZERO:
		animated_sprite.play("idle_" + last_direction)
		return

	if abs(input_vector.x) > abs(input_vector.y):
		if input_vector.x > 0:
			last_direction = "right"
			animated_sprite.play("run_right")
		else:
			last_direction = "left"
			animated_sprite.play("run_left")
	else:
		if input_vector.y > 0:
			last_direction = "down"
			animated_sprite.play("run_down")
		else:
			last_direction = "up"
			animated_sprite.play("run_up")


# 🔥 Position de la hitbox selon la direction
func _update_hitbox_position() -> void:
	var base := hitbox_offset

	match last_direction:
		"left":
			hitbox.position = Vector2(-base.x, base.y)

		"right":
			hitbox.position = base

		"up":
			hitbox.position = Vector2(base.y-2, -base.x)

		"down":
			hitbox.position = Vector2(-base.y+2, base.x)


func _attack() -> void:
	is_attacking = true

	hitbox.monitoring = true

	await get_tree().process_frame

	var targets = hitbox.get_overlapping_bodies()
	print("Targets:", targets.size())

	for target in targets:
		if target.has_method("take_damage"):
			target.take_damage(1, global_position)

	await get_tree().create_timer(0.2).timeout

	hitbox.monitoring = false
	is_attacking = false


func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_attacking:
		print(body.name)
		print("HIT")

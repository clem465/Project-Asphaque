extends CharacterBody2D

@export var speed: float = 80.0
@export var max_health: int = 25
@export var attack_damage: int = 10
@export var defense: int = 3
@export var attack_range: float = 34.0
@export var attack_cooldown: float = 0.2
@export var attack_facing_dot_threshold: float = 0.2
@onready var actionable_finder: Area2D = $Direction/ActionableFinder

var input_vector := Vector2.ZERO
var last_direction := "down"
var is_attacking := false
var attack_enabled := true

var health := 0


func _ready() -> void:
	add_to_group("player")
	health = max_health


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("interact"):
		var actionables = actionable_finder.get_overlapping_areas()
		
		if actionables.size() > 0:
			var target = actionables[0]
			
			if target.has_method("action"):
				target.action()

	if Input.is_action_just_pressed("attack") and attack_enabled and not is_attacking:
		_attack()


func _physics_process(_delta: float) -> void:
	_get_input()
	velocity = input_vector * speed
	move_and_slide()
	_update_animation()


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


func _attack() -> void:
	if not attack_enabled:
		return

	is_attacking = true
	_try_attack_enemies()
	await get_tree().create_timer(attack_cooldown).timeout
	is_attacking = false


func _try_attack_enemies() -> void:
	var facing := _get_facing_vector()

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy is Node2D:
			continue

		var enemy_node := enemy as Node2D
		var to_enemy := enemy_node.global_position - global_position
		var distance := to_enemy.length()

		if distance > attack_range or distance <= 0.001:
			continue

		var direction_to_enemy := to_enemy / distance
		if facing.dot(direction_to_enemy) < attack_facing_dot_threshold:
			continue

		if enemy_node.has_method("take_damage"):
			enemy_node.take_damage(attack_damage, global_position)


func _get_facing_vector() -> Vector2:
	match last_direction:
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		"up":
			return Vector2.UP
		_:
			return Vector2.DOWN


func take_damage(amount: int, source_position: Vector2) -> void:
	var damage: int = maxi(amount - defense, 1)
	health = maxi(health - damage, 0)

	var dir: Vector2 = (global_position - source_position).normalized()
	velocity += dir * 120.0

	if health <= 0:
		die()


func add_coin(amount: int) -> void:
	if amount <= 0:
		return

	GameState.gold += amount


func set_attack_enabled(enabled: bool) -> void:
	attack_enabled = enabled


func is_attack_enabled() -> bool:
	return attack_enabled


func get_current_health() -> int:
	return health


func get_max_health() -> int:
	return max_health


func get_attack_value() -> int:
	return attack_damage


func get_defense_value() -> int:
	return defense


func get_coins() -> int:
	return int(GameState.gold)


func die() -> void:
	queue_free()

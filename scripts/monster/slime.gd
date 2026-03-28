extends CharacterBody2D

@export var speed := 40.0
@export var acceleration := 200.0
@export var friction := 300.0

@export var aggro_range := 120.0
@export var stop_distance := 20.0

# errance
@export var wander_radius := 100.0
@export var change_dir_time_min := 1.0
@export var change_dir_time_max := 3.0

# pause
@export var pause_min := 0.5
@export var pause_max := 1.5

var target: Node2D
var last_dir := "down"

# état
var is_pausing := false
var pause_timer := 0.0

var wander_direction := Vector2.ZERO
var wander_timer := 0.0

# -------------------------
# INIT
# -------------------------
func _ready():
	target = get_tree().get_first_node_in_group("player")
	_pick_new_direction()

# -------------------------
# PHYSICS
# -------------------------
func _physics_process(delta):

	if target == null:
		_wander(delta)
		return

	var distance = global_position.distance_to(target.global_position)

	# 🎯 SI PROCHE → poursuite
	if distance < aggro_range:
		_chase_player(delta)
	else:
		# 🚶 SINON → errance
		_wander(delta)

# -------------------------
# ERRANCE (MOUVEMENT LIBRE)
# -------------------------
func _wander(delta):

	# pause
	if is_pausing:
		pause_timer -= delta
		_slow_down(delta)
		_update_animation(velocity)

		if pause_timer <= 0:
			is_pausing = false
			_pick_new_direction()
		return

	# chance de pause
	if randf() < 0.01:
		is_pausing = true
		pause_timer = randf_range(pause_min, pause_max)
		return

	# changement direction
	wander_timer -= delta
	if wander_timer <= 0:
		_pick_new_direction()

	var target_velocity = wander_direction * speed * 0.6
	velocity = velocity.move_toward(target_velocity, acceleration * delta)

	move_and_slide()
	_update_animation(velocity)

# -------------------------
# POURSUITE JOUEUR
# -------------------------
func _chase_player(delta):

	var dir = (target.global_position - global_position).normalized()
	var distance = global_position.distance_to(target.global_position)

	# évite de coller
	var repulsion = Vector2.ZERO
	if distance < stop_distance:
		repulsion = -dir * 1.2

	var final_dir = (dir + repulsion).normalized()

	var target_velocity = final_dir * speed
	velocity = velocity.move_toward(target_velocity, acceleration * delta)

	move_and_slide()
	_update_animation(velocity)

# -------------------------
# NOUVELLE DIRECTION
# -------------------------
func _pick_new_direction():
	wander_direction = Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized()

	wander_timer = randf_range(change_dir_time_min, change_dir_time_max)

# -------------------------
# RALENTISSEMENT
# -------------------------
func _slow_down(delta):
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()

# -------------------------
# ANIMATIONS
# -------------------------
func _update_animation(vel: Vector2):
	var anim := $AnimatedSprite2D

	if vel.length() < 5:
		if anim.animation != "idle_" + last_dir:
			anim.play("idle_" + last_dir)
		return

	var dir_name := _get_direction_name(vel)

	if anim.animation != "run_" + dir_name:
		anim.play("run_" + dir_name)

# -------------------------
# DIRECTION
# -------------------------
func _get_direction_name(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		last_dir = "right" if dir.x > 0 else "left"
	else:
		last_dir = "down" if dir.y > 0 else "up"

	return last_dir

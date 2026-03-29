extends CharacterBody2D

@export var speed := 40.0
@export var acceleration := 200.0
@export var friction := 300.0

@export var stop_distance := 20.0
@export var attack_cooldown := 1.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var target: Node2D = null

enum State {
	WANDER,
	CHASE
}

var state := State.WANDER

var wander_direction := Vector2.ZERO
var wander_timer := 0.0

@export var change_dir_time_min := 1.0
@export var change_dir_time_max := 3.0

var last_dir := "down"

# 🔥 attaque
var is_attacking := false
var can_attack := true

# 🔥 hitbox
@onready var hitbox: Area2D = $Hitbox
var player_in_hitbox := false


# -------------------------
# INIT
# -------------------------
func _ready():
	_pick_new_direction()


# -------------------------
# PHYSICS
# -------------------------
func _physics_process(delta):
	if is_attacking:
		move_and_slide()
		return

	match state:
		State.WANDER:
			_wander(delta)

		State.CHASE:
			_chase(delta)
			_try_attack()

	move_and_slide()
	_update_animation(velocity)


# -------------------------
# CHASE
# -------------------------
func _chase(delta: float) -> void:
	if is_attacking:
		return
	
	if target == null:
		state = State.WANDER
		return

	var direction = target.global_position - global_position
	var distance = direction.length()

	if distance > stop_distance:
		direction = direction.normalized()
		velocity = velocity.move_toward(direction * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


# -------------------------
# ATTAQUE
# -------------------------
func _try_attack() -> void:
	if not player_in_hitbox or not can_attack:
		return

	_attack()


func _attack() -> void:
	if is_attacking:
		return
	
	
	is_attacking = true
	can_attack = false
	
	velocity = Vector2.ZERO
	
	# 🔥 jouer l’animation d’attaque
	anim.play("attack_" + last_dir)

	print("💥 Attaque !")

	# 🔥 dégâts
	if target and target.has_method("take_damage"):
		target.take_damage(1, global_position)

	# 🔥 attendre cooldown
	await get_tree().create_timer(attack_cooldown).timeout

	is_attacking = false
	can_attack = true


# -------------------------
# WANDER
# -------------------------
func _wander(delta):
	if is_attacking:
		return
	
	wander_timer -= delta

	if wander_timer <= 0:
		_pick_new_direction()

	var target_velocity = wander_direction * speed * 0.6
	velocity = velocity.move_toward(target_velocity, acceleration * delta)


func _pick_new_direction():
	wander_direction = Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized()

	wander_timer = randf_range(change_dir_time_min, change_dir_time_max)


# -------------------------
# DETECTION (SIGHT)
# -------------------------
func _on_sight_body_entered(body: Node2D) -> void:
	if body.name == "Player1":
		target = body
		state = State.CHASE
		print("👀 Player détecté :", target)


func _on_sight_body_exited(body: Node2D) -> void:
	if body.name == "Player1":
		target = null
		state = State.WANDER
		print("❌ Player perdu")


# -------------------------
# HITBOX
# -------------------------
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.name == "Player1":
		print("uhzbfzefz")
		player_in_hitbox = true
		target = body


func _on_hitbox_body_exited(body: Node2D) -> void:
	if body.name == "Player1":
		player_in_hitbox = false


# -------------------------
# ANIMATION
# -------------------------
func _update_animation(vel: Vector2):

	# 🔥 PRIORITÉ ABSOLUE : attaque
	if is_attacking:
		return

	if vel.length() < 1:
		anim.play("idle_" + last_dir)
		return

	if abs(vel.x) > abs(vel.y):
		last_dir = "right" if vel.x > 0 else "left"
	else:
		last_dir = "down" if vel.y > 0 else "up"

	anim.play("run_" + last_dir)

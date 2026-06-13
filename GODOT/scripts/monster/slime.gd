extends CharacterBody2D

@export var speed := 40.0
@export var acceleration := 200.0
@export var friction := 300.0
@export var coin_drop_scene: PackedScene = preload("res://scenes/object/coinGold.tscn")

@export var stop_distance := 20.0
@export var attack_cooldown := 1.0
@export var minimap_live_radius_world := 120.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var health_bar: ProgressBar = $HealthBar

# -------------------------
# STATS
# -------------------------
@export var max_health := 5
@export var attack := 1
@export var defense := 0

var health := max_health
var invulnerable := false

# -------------------------
# IA
# -------------------------
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

# -------------------------
# ATTAQUE
# -------------------------
var is_attacking := false
var can_attack := true
var player_in_hitbox := false
var minimap_player_ref: Node2D = null
var _fog_ref = null
var _was_visible_under_fog: bool = true

# -------------------------
# INIT
# -------------------------
func _ready():
	add_to_group("enemy")
	_pick_new_direction()
	_fog_ref = null

	# ­ƒöÑ init barre de vie
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.visibility_layer = 2

	# ­ƒƒ® STYLE PROPRE (Godot 4)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.2, 0.2)

	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.8, 0.2)

	# Ô£à BONNE M├ëTHODE GODOT 4
	health_bar.set("theme_override_styles/background", bg)
	health_bar.set("theme_override_styles/fill", fill)

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
func _chase(delta):

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

func _try_attack():
	if not player_in_hitbox or not can_attack or target == null:
		return

	_attack()

func _attack():
	if not is_inside_tree():
		return

	is_attacking = true
	can_attack = false
	velocity = Vector2.ZERO

	anim.play("attack_" + last_dir)

	# moment où le coup touche
	await get_tree().create_timer(0.1).timeout

	if is_inside_tree() and player_in_hitbox:
		if target and is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(attack, global_position)

	var tree := get_tree()
	if tree:
		await tree.create_timer(attack_cooldown).timeout

	if not is_inside_tree():
		return

	is_attacking = false
	can_attack = true

# -------------------------
# WANDER
# -------------------------
func _wander(delta):

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
# DETECTION
# -------------------------
func _on_sight_body_entered(body):
	if body.is_in_group("player"):
		target = body
		state = State.CHASE

func _on_sight_body_exited(body):
	if body == target:
		target = null
		state = State.WANDER

# -------------------------
# HITBOX
# -------------------------
func _on_hitbox_body_entered(body):
	if body.is_in_group("player"):
		player_in_hitbox = true
		target = body

func _on_hitbox_body_exited(body):
	if body.is_in_group("player"):
		player_in_hitbox = false

# -------------------------
# D├ëG├éTS + EFFET ROUGE ­ƒö┤
# -------------------------
func take_damage(amount: int, source_position: Vector2):

	if invulnerable:
		return

	invulnerable = true

	var damage = max(amount - defense, 1)
	health -= damage

	health_bar.value = health

	# ­ƒö┤ FLASH ROUGE
	anim.modulate = Color(1, 0.2, 0.2)

	# ­ƒÆÑ knockback
	var dir = (global_position - source_position).normalized()
	velocity += dir * 80

	if health <= 0:
		die()

	# ÔÅ▒´©Å reset couleur
	await get_tree().create_timer(0.1).timeout
	anim.modulate = Color(1, 1, 1)

	await get_tree().create_timer(0.3).timeout
	invulnerable = false

# -------------------------
# MORT
# -------------------------
func die():
	# emp├¬che toute action
	set_physics_process(false)
	velocity = Vector2.ZERO
	is_attacking = false
	can_attack = false

	# joue l'animation de mort
	anim.play("die_" + last_dir)

	# attendre que l'animation se termine
	await anim.animation_finished

	if GameState.has_method("add_kill"):
		GameState.add_kill("slime")

	_spawn_coin_drop()

	# supprimer le slime
	queue_free()

func _spawn_coin_drop() -> void:
	if coin_drop_scene == null:
		return

	var root: Node = get_tree().current_scene
	if root == null:
		return

	var coin_instance: Node = coin_drop_scene.instantiate()
	root.add_child(coin_instance)

	if coin_instance is Node2D:
		(coin_instance as Node2D).global_position = global_position

# -------------------------
# ANIMATION
# -------------------------
func _update_animation(vel):

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

# -------------------------
# UI
# -------------------------
func _process(delta):
	health_bar.visible = health < max_health
	_update_minimap_visibility_layer()
	_update_visibility_by_fog()

func _update_visibility_by_fog() -> void:
	if _fog_ref == null or not is_instance_valid(_fog_ref):
		var root = get_tree().current_scene
		if root:
			_fog_ref = root.get_node_or_null("FogOfWar")
	if _fog_ref == null or not is_instance_valid(_fog_ref):
		return

	if not _fog_ref.has_method("get_fog_state_at_world"):
		return

	var state: String = _fog_ref.get_fog_state_at_world(global_position)
	var should_be_visible: bool = state == "visible"

	if should_be_visible and not _was_visible_under_fog:
		show()
		set_physics_process(true)
		_was_visible_under_fog = true
	elif not should_be_visible and _was_visible_under_fog:
		hide()
		set_physics_process(false)
		_was_visible_under_fog = false

func _update_minimap_visibility_layer() -> void:
	var player := _get_minimap_player_ref()
	if player == null:
		visibility_layer = 1
		return

	var radius_sq: float = minimap_live_radius_world * minimap_live_radius_world
	if global_position.distance_squared_to(player.global_position) <= radius_sq:
		visibility_layer = 1
	else:
		visibility_layer = 2

func _get_minimap_player_ref() -> Node2D:
	if minimap_player_ref and is_instance_valid(minimap_player_ref):
		return minimap_player_ref

	var candidate: Node = get_tree().get_first_node_in_group("player")
	if candidate is Node2D:
		minimap_player_ref = candidate

	return minimap_player_ref

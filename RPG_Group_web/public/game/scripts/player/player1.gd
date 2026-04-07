extends CharacterBody2D

@export var speed: float = 80.0

@onready var actionable_finder: Area2D = $Direction/ActionableFinder
@onready var hitbox: Area2D = $Direction/Hitbox
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var coin_sound: AudioStreamPlayer2D = $CoinSound  


# -------------------------
# STATS
# -------------------------
@export var max_health := 25
@export var attack := 10
@export var defense := 3

var health := 0

# -------------------------
# ├ëTAT
# -------------------------
var input_vector := Vector2.ZERO
var last_direction := "down"
var is_attacking := false
var attack_enabled := true
var _base_speed: float = 0.0
var _speed_boost_active: bool = false

var hitbox_offset := Vector2.ZERO
var already_hit: Array = []

# -------------------------
# INIT
# -------------------------
func _ready() -> void:
	add_to_group("player")

	health = max_health
	_base_speed = speed
	hitbox_offset = hitbox.position

	# UI
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.visibility_layer = 2

	# Style
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.2, 0.2)

	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.8, 0.2)

	health_bar.set("theme_override_styles/background", bg)
	health_bar.set("theme_override_styles/fill", fill)

# -------------------------
# INPUT
# -------------------------
func _unhandled_input(_event: InputEvent) -> void:

	if Input.is_action_just_pressed("interact"):
		var actionables = actionable_finder.get_overlapping_areas()
		if actionables.size() > 0:
			var target = actionables[0]
			if target.has_method("action"):
				target.action()

	if Input.is_action_just_pressed("attack") and attack_enabled and not is_attacking:
		_attack()

	if Input.is_action_just_pressed("use_assigned_item"):
		if GameState.has_method("use_assigned_action_item"):
			GameState.use_assigned_action_item(self)

# -------------------------
# PHYSICS
# -------------------------
func _physics_process(delta: float) -> void:

	if not is_attacking:
		_get_input()
	else:
		input_vector = Vector2.ZERO

	velocity = input_vector * speed
	move_and_slide()

	_update_animation()

	health_bar.visible = health < max_health

# -------------------------
# INPUT VECTOR
# -------------------------
func _get_input() -> void:
	input_vector = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	if input_vector.length() > 1:
		input_vector = input_vector.normalized()

# -------------------------
# ANIMATION
# -------------------------
func _update_animation() -> void:

	_update_hitbox_position()

	if is_attacking:
		animated_sprite.play("attack_" + last_direction)
		return

	if input_vector == Vector2.ZERO:
		animated_sprite.play("idle_" + last_direction)
		return

	# Direction + animation
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

# -------------------------
# HITBOX
# -------------------------
func _update_hitbox_position() -> void:
	var base := hitbox_offset

	match last_direction:
		"left":
			hitbox.position = Vector2(-abs(base.x), base.y)
		"right":
			hitbox.position = Vector2(abs(base.x), base.y)
		"up":
			hitbox.position = Vector2(0, -abs(base.y))
		"down":
			hitbox.position = Vector2(0, abs(base.y))

# -------------------------
# ATTAQUE
# -------------------------
func _attack() -> void:
	if not attack_enabled:
		return

	is_attacking = true
	already_hit.clear()

	hitbox.monitoring = true

	await get_tree().create_timer(0.2).timeout

	hitbox.monitoring = false
	is_attacking = false

# -------------------------
# HITBOX DETECTION
# -------------------------
func _on_hitbox_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemy"):
		return

	if not is_attacking:
		return

	if already_hit.has(body):
		return

	if body.has_method("take_damage"):
		body.take_damage(attack, global_position)
		already_hit.append(body)

# -------------------------
# DAMAGE
# -------------------------
func take_damage(amount: int, source_position: Vector2):
	_clear_speed_boost()

	var damage: int = maxi(amount - defense, 1)
	health -= damage

	health_bar.value = health

	print("Player prend", damage, "d├®g├óts | Vie:", health)

	# knockback propre
	var dir: Vector2 = (global_position - source_position).normalized()
	velocity += dir * 150

	if health <= 0:
		die()


func heal(amount: int) -> void:
	if amount <= 0:
		return

	health = mini(health + amount, max_health)
	health_bar.value = health


func apply_speed_boost(multiplier: float = 1.5) -> void:
	if multiplier <= 1.0:
		multiplier = 1.5

	if not _speed_boost_active:
		_base_speed = speed

	speed = _base_speed * multiplier
	_speed_boost_active = true


func _clear_speed_boost() -> void:
	if not _speed_boost_active:
		return

	speed = _base_speed
	_speed_boost_active = false

# -------------------------
# Ajout├® pi├¿ce
# -------------------------
func add_coin(amount: int):
	if amount <= 0:
		return

	GameState.gold += amount
	print("Coins:", GameState.gold)

	# ­ƒöè jouer le son ici (dans le player)
	if coin_sound:
		coin_sound.pitch_scale = randf_range(0.9, 1.1)
		coin_sound.play()

	# Ô£¿ texte flottant
	show_floating_text("+%d ­ƒ¬Ö" % amount)

func set_attack_enabled(enabled: bool) -> void:
	attack_enabled = enabled


func is_attack_enabled() -> bool:
	return attack_enabled


func get_coins() -> int:
	return int(GameState.gold)


func get_current_health() -> int:
	return health


func get_max_health() -> int:
	return max_health


func get_attack_value() -> int:
	return attack


func get_defense_value() -> int:
	return defense

# -------------------------
# Affiche le nombre de pi├¿ce gagn├®
# -------------------------
func show_floating_text(text: String):
	var label = Label.new()
	label.text = text

	# Style
	label.modulate = Color(1, 0.9, 0.2) # jaune
	label.add_theme_font_size_override("font_size", 16)

	add_child(label)

	# Position au-dessus du joueur
	label.position = Vector2(0, -20)

	# Animation
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 30, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)

	await tween.finished
	label.queue_free()

# -------------------------
# MORT
# -------------------------
func die():
	print("­ƒÆÇ Player mort")

	# ­ƒöü restaurer les coins
	GameState.restore_gold()

	# ­ƒöä retour village
	get_tree().change_scene_to_file("res://maps/village.tscn")

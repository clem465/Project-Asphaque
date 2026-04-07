extends Node2D

@export var speed := 40.0
@export var acceleration := 20.0
@export var stop_distance := 5.0

@onready var collect_sound = $collect_sound

var velocity := Vector2.ZERO
var target: Node2D = null

enum State {
	IDLE,
	CHASE
}

var state := State.IDLE


func _physics_process(delta):
	match state:
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, 500 * delta)

		State.CHASE:
			_chase(delta)

	position += velocity * delta


# -------------------------
# CHASE
# -------------------------
func _chase(delta):
	if not is_instance_valid(target):
		print("⚠️ Target invalide → retour IDLE")
		state = State.IDLE
		return

	var direction = target.global_position - global_position
	var distance = direction.length()

	if distance > stop_distance:
		direction = direction.normalized()
		velocity = velocity.move_toward(direction * speed, acceleration * delta)
	else:
		_collect()


# -------------------------
# COLLECT
# -------------------------
func _collect():
	print("🪙 Coin collecté")

	if target and target.has_method("add_coin"):
		target.add_coin(1)

	if collect_sound:
		collect_sound.pitch_scale = randf_range(0.9, 1.1)

		# 🔥 détacher le son de la pièce
		collect_sound.reparent(get_tree().current_scene)

		collect_sound.play()

	queue_free()


# -------------------------
# DETECTION
# -------------------------
func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		print("👤 Player détecté → CHASE")
		target = body
		state = State.CHASE

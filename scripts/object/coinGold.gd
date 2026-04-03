extends Node2D

@export var speed := 40.0
@export var acceleration := 20.0
@export var stop_distance := 5.0

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
# CHASE (repris du slime)
# -------------------------
func _chase(delta):

	if not is_instance_valid(target):
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
# COLLECTq
# -------------------------
func _collect():
	if target and target.has_method("add_coin"):
		target.add_coin(1)
	queue_free()


# -------------------------
# DETECTION
# -------------------------
func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		target = body
		state = State.CHASE

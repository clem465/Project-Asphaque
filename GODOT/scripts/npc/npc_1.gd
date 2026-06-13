extends Area2D

@export var target_scene: PackedScene
@export var target_spawn_point: String = "Entrance"

var player_in_range = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		player_in_range = true

func _on_body_exited(body):
	if body.name == "Player":
		player_in_range = false

func _process(delta):
	if player_in_range and Input.is_action_just_pressed("interact"):
		teleport()

func teleport():
	if target_scene == null:
		push_warning("No target_scene set")
		return

	get_tree().change_scene_to_packed(target_scene)

extends Area2D

@export var target_scene: String  = "res://maps/village.tscn"
@export var target_spawn_name: String = ""

var player_in_area := false


func _ready() -> void:
	print("Porte prête")
# -------------------------
# ACTION
# -------------------------
func action():
	if not player_in_area:
		return
	
	get_tree().change_scene_to_file(target_scene)

# -------------------------
# SIGNALS
# -------------------------
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = false

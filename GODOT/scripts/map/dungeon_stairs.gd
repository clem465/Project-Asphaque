extends Area2D

## Escaliers du donjon, inspirés de NetHack.
## Réutilise le sprite et la hitbox de la porte d'origine (door.tscn) via la
## scène dungeon_stairs.tscn, pour rester visuellement cohérent (même sprite,
## même collision_layer/mask = 16/2 que l'InteractionArea de la porte).
## "up"   (<) → remonte d'un étage, ou retourne au village si on est à l'étage 1
## "down" (>) → descend au prochain étage
@export var direction: String = "down"

const DUNGEON_SCENE := "res://maps/donjon.tscn"
const VILLAGE_SCENE := "res://maps/village.tscn"

var player_in_area := false


func _ready() -> void:
	_apply_tint()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Teinte le sprite de la porte pour différencier visuellement montée/descente,
## comme le faisaient les anciens triangles verts/orange.
func _apply_tint() -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	if direction == "up":
		sprite.modulate = Color(0.55, 1.0, 0.6)   # teinte verte = monter / sortir
	else:
		sprite.modulate = Color(1.0, 0.6, 0.35)   # teinte orange = descendre


func action() -> void:
	if not player_in_area:
		return
	_use_stairs()


func _use_stairs() -> void:
	match direction:
		"down":
			GameState.go_to_floor_below()
			get_tree().change_scene_to_file(DUNGEON_SCENE)
		"up":
			if GameState.current_floor <= 1:
				# Sortie du donjon → village
				GameState.save_gold()
				GameState.exit_dungeon_to_village()
				get_tree().change_scene_to_file(VILLAGE_SCENE)
			else:
				GameState.go_to_floor_above()
				get_tree().change_scene_to_file(DUNGEON_SCENE)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = false

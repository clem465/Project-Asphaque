extends Area2D

# -------------------------
# NODES
# -------------------------
@onready var sprite: AnimatedSprite2D = $"../AnimatedSprite2D"

# -------------------------
# ÉTAT
# -------------------------
var is_open := false

# -------------------------
# AUDIO
# -------------------------
@onready var chest_sound : AudioStreamPlayer2D = $"opening_chest"

# -------------------------
# READY
# -------------------------
func _ready():
	sprite.play("default")

# -------------------------
# INTERACTION (player)
# -------------------------
func action():
	if is_open:
		return

	is_open = true
	sprite.play("open_anim")
	
	if chest_sound:
		chest_sound.pitch_scale = randf_range(0.9, 1.1)
		chest_sound.play()

	await sprite.animation_finished

	spawn_loot()

# -------------------------
# LOOT
# -------------------------
func spawn_loot():
	print("Coffre ouvert !")

	var player = get_tree().get_first_node_in_group("player")

	if player and player.has_method("add_coin"):
		var amount = randi() % 10 + 5
		player.add_coin(amount)

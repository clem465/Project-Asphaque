extends Control

@onready var email_input = $VBoxContainer/email_input
@onready var password_input = $VBoxContainer/password_input
@onready var error_label = $VBoxContainer/error_label
@onready var http = $HTTPRequest
@onready var loader = $loader
@onready var anim = $AnimationPlayer

var api_url = "http://localhost:8000/login"


func _ready():
	# Connexions des boutons
	$VBoxContainer/login_button.pressed.connect(_on_login_pressed)
	$VBoxContainer/register_button.pressed.connect(_on_register_pressed)
	$VBoxContainer/show_password_button.pressed.connect(_toggle_password)

	# Signal HTTP
	http.request_completed.connect(_on_request_completed)

	# Animation
	anim.play("fade_in")

	# Auto login
	var token = load_token()
	if token != null and token != "":
		print("Auto connecté !")
		get_tree().change_scene_to_file("res://MainMenu.tscn")


# 🔐 LOGIN
func _on_login_pressed():
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()

	if email == "" or password == "":
		error_label.text = "Remplis tous les champs"
		return

	loader.visible = true
	error_label.text = ""

	var body = JSON.stringify({
		"email": email,
		"password": password
	})

	var headers = ["Content-Type: application/json"]

	var err = http.request(api_url, headers, HTTPClient.METHOD_POST, body)

	if err != OK:
		loader.visible = false
		error_label.text = "Erreur réseau"


# 🌐 RÉPONSE API
func _on_request_completed(result, response_code, headers, body):
	loader.visible = false

	var response_text = body.get_string_from_utf8()
	var response = JSON.parse_string(response_text)

	if response == null:
		error_label.text = "Réponse invalide du serveur"
		return

	if response_code == 200 and response.has("token"):
		var token = response["token"]
		print("Connecté !")

		save_token(token)

		get_tree().change_scene_to_file("res://MainMenu.tscn")
	else:
		if response.has("error"):
			error_label.text = response["error"]
		else:
			error_label.text = "Email ou mot de passe incorrect"


# 💾 SAUVEGARDE TOKEN
func save_token(token):
	var file = FileAccess.open("user://save.dat", FileAccess.WRITE)
	if file:
		file.store_string(token)


# 📂 CHARGER TOKEN
func load_token():
	if FileAccess.file_exists("user://save.dat"):
		var file = FileAccess.open("user://save.dat", FileAccess.READ)
		if file:
			return file.get_as_text()
	return null


# 👁️ AFFICHER / CACHER MOT DE PASSE
func _toggle_password():
	password_input.secret = !password_input.secret


# 🔄 PAGE INSCRIPTION
func _on_register_pressed():
	get_tree().change_scene_to_file("res://Register.tscn")

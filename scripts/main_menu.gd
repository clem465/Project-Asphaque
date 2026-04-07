extends Control

@onready var email_input = $VBoxContainer/email_input
@onready var password_input = $VBoxContainer/password_input
@onready var username_input = $VBoxContainer/username_input
@onready var error_label = $VBoxContainer/error_label
@onready var http = $HTTPRequest

var api_login = "http://127.0.0.1:8000/login"
var api_register = "http://127.0.0.1:8000/register"

var is_requesting = false
var is_login = true


func _ready():
	$VBoxContainer/HBoxContainer/login_button.pressed.connect(_on_login_pressed)
	$VBoxContainer/HBoxContainer/register_button.pressed.connect(_on_register_pressed)
	http.request_completed.connect(_on_request_completed)


# 🔐 LOGIN
func _on_login_pressed():
	if is_requesting:
		return
	
	is_requesting = true
	is_login = true

	var body = JSON.stringify({
		"email": email_input.text,
		"password": password_input.text
	})

	print("➡️ LOGIN:", body)

	http.request(api_login, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


# 📝 REGISTER
func _on_register_pressed():
	if is_requesting:
		return
	
	is_requesting = true
	is_login = false

	var body = JSON.stringify({
		"email": email_input.text,
		"password": password_input.text,
		"username": username_input.text
	})

	print("➡️ REGISTER:", body)

	http.request(api_register, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


# 🌐 RÉPONSE
func _on_request_completed(result, response_code, headers, body):
	is_requesting = false

	var text = body.get_string_from_utf8()

	print("⬅️ CODE:", response_code)
	print("⬅️ RESPONSE:", text)

	if result != HTTPRequest.RESULT_SUCCESS:
		error_label.text = "Erreur réseau"
		return

	if response_code != 200:
		error_label.text = "Erreur : " + text
		return

	var response = JSON.parse_string(text)

	if response == null:
		error_label.text = "JSON invalide"
		return

	if is_login:
		error_label.text = "Connexion réussie !"
		var token = response.get("token", "")
		print("🔐 TOKEN:", token)
		save_token(token)

	get_tree().change_scene_to_file("res://maps/village.tscn")


# 💾 TOKEN
func save_token(token):
	var file = FileAccess.open("user://save.dat", FileAccess.WRITE)
	file.store_string(token)

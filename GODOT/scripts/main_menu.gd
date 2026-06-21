extends Control

@onready var email_input = $VBoxContainer/email_input
@onready var password_input = $VBoxContainer/password_input
@onready var username_input = $VBoxContainer/username_input
@onready var error_label = $VBoxContainer/error_label
@onready var http = $HTTPRequest
@onready var title_label: Label = $Title
@onready var email_label: Label = $VBoxContainer/Email
@onready var pseudo_label: Label = $VBoxContainer/Pseudo
@onready var password_label: Label = $VBoxContainer/Password
@onready var login_button: Button = $VBoxContainer/TopCenter/HBoxContainer/login_button
@onready var register_button: Button = $VBoxContainer/TopCenter/HBoxContainer/register_button
@onready var submit_button: Button = $VBoxContainer/SubmitCenter/submit_button
@onready var loader: TextureRect = $loader
@onready var lang_toggle_button: Button = $LangToggleButton


const DEFAULT_API_BASE_URL = "http://127.0.0.1:8000"
const ACTIVE_BUTTON_COLOR: Color = Color(0.4, 0.7, 0.95, 1)
const INACTIVE_BUTTON_COLOR: Color = Color(0.85, 0.85, 0.85, 1)

var api_base_url = DEFAULT_API_BASE_URL
var api_login = ""
var api_register = ""

var is_requesting = false
var is_login = true
var _locale_manager: Node = null


func _ready():
	_center_login_layout()
	if not get_viewport().size_changed.is_connected(_center_login_layout):
		get_viewport().size_changed.connect(_center_login_layout)

	api_base_url = _resolve_api_base_url()
	api_login = "%s/login" % api_base_url
	api_register = "%s/register" % api_base_url
	print("API base URL:", api_base_url)
	GameState.set_api_base_url(api_base_url)
	_locale_manager = get_node_or_null("/root/LocaleManager")
	_apply_locale()
	if _locale_manager and _locale_manager.has_signal("locale_changed"):
		if not _locale_manager.locale_changed.is_connected(_on_locale_changed):
			_locale_manager.locale_changed.connect(_on_locale_changed)

	if not $VBoxContainer/TopCenter/HBoxContainer/login_button.pressed.is_connected(_on_login_pressed):
		$VBoxContainer/TopCenter/HBoxContainer/login_button.pressed.connect(_on_login_pressed)
	if not $VBoxContainer/TopCenter/HBoxContainer/register_button.pressed.is_connected(_on_register_pressed):
		$VBoxContainer/TopCenter/HBoxContainer/register_button.pressed.connect(_on_register_pressed)
	if not $VBoxContainer/SubmitCenter/submit_button.pressed.is_connected(_on_submit_pressed):
		$VBoxContainer/SubmitCenter/submit_button.pressed.connect(_on_submit_pressed)
	if not http.request_completed.is_connected(_on_request_completed):
		http.request_completed.connect(_on_request_completed)

	if login_button:
		login_button.toggle_mode = true
	if register_button:
		register_button.toggle_mode = true
	
	if lang_toggle_button:
		lang_toggle_button.pressed.connect(_on_lang_toggle_pressed)

	_update_form_ui()

func _center_login_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	size = viewport_size

	var background_panel := get_node_or_null("Panel") as Panel
	if background_panel:
		background_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		background_panel.offset_left = 0.0
		background_panel.offset_top = 0.0
		background_panel.offset_right = 0.0
		background_panel.offset_bottom = 0.0

	var content_width: float = min(560.0, viewport_size.x * 0.88)
	var title_height: float = min(150.0, viewport_size.y * 0.24)
	var form_height: float = min(400.0, viewport_size.y * 0.58)
	var gap: float = 14.0
	var total_height: float = title_height + gap + form_height
	var left: float = (viewport_size.x - content_width) * 0.5
	var top: float = max(24.0, (viewport_size.y - total_height) * 0.5)

	if title_label:
		title_label.position = Vector2(left, top)
		title_label.size = Vector2(content_width, title_height)

	var form := get_node_or_null("VBoxContainer") as VBoxContainer
	if form:
		form.position = Vector2(left, top + title_height + gap)
		form.size = Vector2(content_width, form_height)

	if loader:
		loader.position = (viewport_size - loader.size) * 0.5

func _on_locale_changed(_locale: String) -> void:
	_apply_locale()
	_update_lang_toggle_label()

func _apply_locale() -> void:
	if not _locale_manager:
		return
	if not _locale_manager.has_method("tr_key"):
		return
	if title_label:
		title_label.text = "Asphaque"
	if email_label:
		email_label.text = _locale_manager.tr_key("ui.email")
	if pseudo_label:
		pseudo_label.text = _locale_manager.tr_key("ui.pseudo")
	if password_label:
		password_label.text = _locale_manager.tr_key("ui.password")
	if login_button:
		login_button.text = _locale_manager.tr_key("ui.login")
	if register_button:
		register_button.text = _locale_manager.tr_key("ui.register")
	if submit_button:
		submit_button.text = login_button.text if is_login else register_button.text
	_update_lang_toggle_label()

func _update_form_ui() -> void:
	if pseudo_label:
		pseudo_label.visible = not is_login
	if username_input:
		username_input.visible = not is_login
	if login_button:
		login_button.modulate = ACTIVE_BUTTON_COLOR if is_login else INACTIVE_BUTTON_COLOR
	if register_button:
		register_button.modulate = INACTIVE_BUTTON_COLOR if is_login else ACTIVE_BUTTON_COLOR
	if submit_button:
		submit_button.text = login_button.text if is_login else register_button.text
	if error_label:
		error_label.text = ""

func _resolve_api_base_url() -> String:
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		var window = JavaScriptBridge.get_interface("window")
		if window and window.location:
			var params = JavaScriptBridge.create_object("URLSearchParams", window.location.search)
			if params and params.has("api"):
				var custom_api = String(params.get("api")).strip_edges()
				if custom_api != "":
					return custom_api.trim_suffix("/")

	return DEFAULT_API_BASE_URL


# 🔐 MODE SWITCH
func _on_login_pressed():
	is_login = true
	_update_form_ui()


# 📝 MODE SWITCH
func _on_register_pressed():
	is_login = false
	_update_form_ui()


# ▶️ SUBMIT
func _on_submit_pressed():
	if is_requesting:
		return

	is_requesting = true

	var body = {
		"email": email_input.text,
		"password": password_input.text
	}
	var endpoint = api_login

	if is_login:
		print("➡️ LOGIN:", JSON.stringify(body))
	else:
		body["username"] = username_input.text
		endpoint = api_register
		print("➡️ REGISTER:", JSON.stringify(body))

	http.request(endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))

func _on_lang_toggle_pressed() -> void:
	if not _locale_manager:
		return
	if not _locale_manager.has_method("get_locale") or not _locale_manager.has_method("set_locale"):
		return

	var current: String = String(_locale_manager.get_locale())
	var next: String = "en" if current == "fr" else "fr"
	_locale_manager.set_locale(next)

func _update_lang_toggle_label() -> void:
	if lang_toggle_button == null:
		return
	if not _locale_manager or not _locale_manager.has_method("get_locale"):
		return

	var current: String = String(_locale_manager.get_locale())
	lang_toggle_button.text = "EN" if current == "fr" else "FR"


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
		GameState.set_api_base_url(api_base_url)
		GameState.set_auth_token(token)
		GameState.load_state()

	get_tree().change_scene_to_file("res://maps/village.tscn")


# 💾 TOKEN
func save_token(token):
	var file = FileAccess.open("user://save.dat", FileAccess.WRITE)
	file.store_string(token)

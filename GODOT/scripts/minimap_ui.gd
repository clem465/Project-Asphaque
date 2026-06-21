extends CanvasLayer

@export var toggle_button: Button
@export var minimap_window: Panel
@export var map_viewport: SubViewport
@export var map_camera: Camera2D

@export var fog_cell_size: float = 32.0
@export var visible_radius_world: float = 120.0
@export var fog_disabled_scene_keywords: PackedStringArray = ["hub", "village"]

@export var inventory_button: Button
@export var inventory_window: Panel

@export var stats_button: Button
@export var stats_window: Panel

@export var actions_button: Button
@export var actions_window: Panel

@onready var map_container: SubViewportContainer = $MinimapWindow/MapContainer
@onready var opacity_slider: HSlider = $MinimapWindow/TitleBar/Header/OpacitySlider
@onready var close_button: Button = $MinimapWindow/TitleBar/Header/CloseButton
@onready var inventory_close_button: Button = $InventoryWindow/TitleBar/Header/CloseButton
@onready var stats_close_button: Button = $StatsWindow/TitleBar/Header/CloseButton
@onready var actions_close_button: Button = $ActionsWindow/TitleBar/Header/CloseButton
@onready var inventory_opacity_slider: HSlider = $InventoryWindow/TitleBar/Header/OpacitySlider
@onready var stats_opacity_slider: HSlider = $StatsWindow/TitleBar/Header/OpacitySlider
@onready var actions_opacity_slider: HSlider = $ActionsWindow/TitleBar/Header/OpacitySlider
@onready var fog_overlay: TextureRect = $MinimapWindow/FogOverlay
@onready var inventory_placeholder: Label = $InventoryWindow/Content/InventoryVBox/InventoryPlaceholder
@onready var inventory_items_list: VBoxContainer = $InventoryWindow/Content/InventoryVBox/ItemsList
@onready var hp_label: Label = $StatsWindow/Content/StatsVBox/HpLabel
@onready var hp_bar: ProgressBar = $StatsWindow/Content/StatsVBox/HpBar
@onready var atk_label: Label = $StatsWindow/Content/StatsVBox/AtkLabel
@onready var def_label: Label = $StatsWindow/Content/StatsVBox/DefLabel
@onready var weapon_label: Label = $StatsWindow/Content/StatsVBox/WeaponLabel
@onready var attack_toggle_button: Button = $ActionsWindow/Content/ActionsVBox/Action1
@onready var item_slot_toggle_button: Button = $ActionsWindow/Content/ActionsVBox/Action2
@onready var minimap_title_label: Label = $MinimapWindow/TitleBar/Header/TitleLabel
@onready var inventory_title_label: Label = $InventoryWindow/TitleBar/Header/TitleLabel
@onready var stats_title_label: Label = $StatsWindow/TitleBar/Header/TitleLabel
@onready var actions_title_label: Label = $ActionsWindow/TitleBar/Header/TitleLabel
@onready var action3_button: Button = $ActionsWindow/Content/ActionsVBox/Action3
@onready var lang_toggle_button: Button = $LangToggleButton

const SETTINGS_CONFIG_PATH := "user://settings.cfg"

var _locale_manager: Node = null

var _map_bounds: Rect2 = Rect2()
var _fog_grid_size: Vector2i = Vector2i.ZERO
var _discovered_image: Image
var _fog_display_image: Image
var _fog_texture: ImageTexture
var _fog_atlas: AtlasTexture
var _player_ref: Node2D
var _last_player_pos: Vector2 = Vector2.ZERO
var _has_last_player_pos: bool = false
var _fog_ready: bool = false
var _fog_enabled_for_scene: bool = true
var _is_syncing_attack_toggle: bool = false
var _is_syncing_item_slot_toggle: bool = false
var _action_item_id: String = "healing_potion"
var _last_inventory_signature: String = ""
var _fog_retry_frames: int = 0
var _mobile_controls: Control = null
var _mobile_joystick_base: Control = null
var _mobile_joystick_knob: ColorRect = null
var _mobile_joystick_dragging: bool = false
var _mobile_joystick_radius: float = 58.0
var _settings_button: Button = null
var _settings_window: Panel = null
var _settings_title_label: Label = null
var _settings_master_label: Label = null
var _settings_music_label: Label = null
var _settings_master_value_label: Label = null
var _settings_music_value_label: Label = null
var _settings_master_slider: HSlider = null
var _settings_music_slider: HSlider = null
var _settings_master_volume: float = 100.0
var _settings_music_volume: float = 100.0
var _is_loading_settings: bool = false
var _settings_dragging: bool = false
var _settings_drag_offset: Vector2 = Vector2.ZERO
var _settings_header: Control = null

func _ready() -> void:
	_disable_button_keyboard_focus(self)
	_build_settings_ui()
	_locale_manager = get_node_or_null("/root/LocaleManager")
	_apply_locale()
	if _locale_manager and _locale_manager.has_signal("locale_changed"):
		if not _locale_manager.locale_changed.is_connected(_on_locale_changed):
			_locale_manager.locale_changed.connect(_on_locale_changed)

	if toggle_button:
		toggle_button.pressed.connect(_on_toggle_pressed)
	if minimap_window:
		minimap_window.hide()
		minimap_window.resized.connect(_on_window_resized)
	if map_container and not map_container.resized.is_connected(_on_window_resized):
		map_container.resized.connect(_on_window_resized)

	if inventory_button:
		inventory_button.pressed.connect(_on_inventory_pressed)
	if inventory_window:
		inventory_window.hide()

	if stats_button:
		stats_button.pressed.connect(_on_stats_pressed)
	if stats_window:
		stats_window.hide()

	if actions_button:
		actions_button.pressed.connect(_on_actions_pressed)
	if actions_window:
		actions_window.hide()

	if lang_toggle_button:
		lang_toggle_button.pressed.connect(_on_lang_toggle_pressed)

	if opacity_slider:
		opacity_slider.value_changed.connect(_on_opacity_changed)

	if close_button:
		close_button.pressed.connect(_on_toggle_pressed)

	if inventory_opacity_slider:
		inventory_opacity_slider.value_changed.connect(_on_inventory_opacity_changed)

	if stats_opacity_slider:
		stats_opacity_slider.value_changed.connect(_on_stats_opacity_changed)

	if actions_opacity_slider:
		actions_opacity_slider.value_changed.connect(_on_actions_opacity_changed)

	if inventory_close_button:
		inventory_close_button.pressed.connect(_on_inventory_pressed)

	if stats_close_button:
		stats_close_button.pressed.connect(_on_stats_pressed)

	if actions_close_button:
		actions_close_button.pressed.connect(_on_actions_pressed)

	if attack_toggle_button:
		attack_toggle_button.toggled.connect(_on_attack_toggle_toggled)
		_update_attack_toggle_text(attack_toggle_button.button_pressed)

	if item_slot_toggle_button:
		item_slot_toggle_button.toggled.connect(_on_item_slot_toggle_toggled)
		_update_item_slot_toggle_text(item_slot_toggle_button.button_pressed)

	if map_viewport:
		map_viewport.world_2d = get_viewport().world_2d
	
	if map_camera:
		map_camera.make_current()
		_configure_minimap_cull_mask()

	_setup_fog_overlay()
	call_deferred("_on_window_resized")

	call_deferred("_center_map")
	call_deferred("_sync_attack_toggle_from_player")
	call_deferred("_sync_item_slot_toggle_from_state")
	call_deferred("_setup_mobile_controls")
	_load_audio_settings()
	_apply_audio_settings()
	call_deferred("_init_settings_drag")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if Input.is_action_just_pressed("toggle_map_window"):
		_on_toggle_pressed()
		get_viewport().set_input_as_handled()
	elif Input.is_action_just_pressed("toggle_inventory_window"):
		_on_inventory_pressed()
		get_viewport().set_input_as_handled()
	elif Input.is_action_just_pressed("toggle_stats_window"):
		_on_stats_pressed()
		get_viewport().set_input_as_handled()
	elif Input.is_action_just_pressed("toggle_actions_window"):
		_on_actions_pressed()
		get_viewport().set_input_as_handled()
	elif Input.is_action_just_pressed("toggle_settings_window"):
		_on_settings_pressed()
		get_viewport().set_input_as_handled()

func _on_locale_changed(_locale: String) -> void:
	_apply_locale()
	_update_attack_toggle_text(attack_toggle_button.button_pressed if attack_toggle_button else false)
	_update_item_slot_toggle_text(item_slot_toggle_button.button_pressed if item_slot_toggle_button else false)
	_last_inventory_signature = "__dirty__"
	_refresh_inventory_items_ui()
	_update_player_panels()
	_update_lang_toggle_label()

func _apply_locale() -> void:
	if not _locale_manager:
		return
	if not _locale_manager.has_method("tr_key"):
		return

	if toggle_button:
		toggle_button.text = _locale_manager.tr_key("ui.map")
	if inventory_button:
		inventory_button.text = _locale_manager.tr_key("ui.inventory")
	if stats_button:
		stats_button.text = _locale_manager.tr_key("ui.stats")
	if actions_button:
		actions_button.text = _locale_manager.tr_key("ui.actions")

	if minimap_title_label:
		minimap_title_label.text = _locale_manager.tr_key("ui.minimap")
	if inventory_title_label:
		inventory_title_label.text = _locale_manager.tr_key("ui.inventory")
	if stats_title_label:
		stats_title_label.text = _locale_manager.tr_key("ui.stats")
	if actions_title_label:
		actions_title_label.text = _locale_manager.tr_key("ui.actions")

	if action3_button:
		action3_button.text = _locale_manager.tr_key("ui.action_3")

	_update_settings_locale()
	_update_lang_toggle_label()

func _build_settings_ui() -> void:
	if _settings_button != null:
		return

	_settings_button = Button.new()
	_settings_button.name = "SettingsButton"
	_settings_button.text = "Parametres"
	_settings_button.focus_mode = Control.FOCUS_NONE
	_settings_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_settings_button.anchor_left = 1.0
	_settings_button.anchor_top = 1.0
	_settings_button.anchor_right = 1.0
	_settings_button.anchor_bottom = 1.0
	_settings_button.offset_left = -700.0
	_settings_button.offset_top = -70.0
	_settings_button.offset_right = -580.0
	_settings_button.offset_bottom = -20.0
	_settings_button.pressed.connect(_on_settings_pressed)
	add_child(_settings_button)

	_settings_window = Panel.new()
	_settings_window.name = "SettingsWindow"
	_settings_window.visible = false
	_settings_window.offset_left = 360.0
	_settings_window.offset_top = 150.0
	_settings_window.offset_right = 720.0
	_settings_window.offset_bottom = 360.0
	add_child(_settings_window)

	var title_bar := ColorRect.new()
	title_bar.name = "TitleBar"
	title_bar.color = Color(0.08, 0.08, 0.13, 0.95)
	title_bar.anchor_right = 1.0
	title_bar.offset_bottom = 30.0
	_settings_window.add_child(title_bar)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.anchor_right = 1.0
	header.anchor_bottom = 1.0
	header.offset_left = 8.0
	header.offset_right = -8.0
	title_bar.add_child(header)

	_settings_title_label = Label.new()
	_settings_title_label.text = "Parametres"
	_settings_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_settings_title_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(34, 24)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_on_settings_pressed)
	header.add_child(close_button)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.anchor_right = 1.0
	content.anchor_bottom = 1.0
	content.offset_left = 16.0
	content.offset_top = 48.0
	content.offset_right = -16.0
	content.offset_bottom = -16.0
	content.add_theme_constant_override("separation", 16)
	_settings_window.add_child(content)

	var master_row := _create_settings_slider_row("Volume general", _settings_master_volume)
	content.add_child(master_row)
	_settings_master_label = master_row.get_node("NameLabel") as Label
	_settings_master_slider = master_row.get_node("Slider") as HSlider
	_settings_master_value_label = master_row.get_node("ValueLabel") as Label
	_settings_master_slider.value_changed.connect(_on_master_volume_changed)

	var music_row := _create_settings_slider_row("Musique", _settings_music_volume)
	content.add_child(music_row)
	_settings_music_label = music_row.get_node("NameLabel") as Label
	_settings_music_slider = music_row.get_node("Slider") as HSlider
	_settings_music_value_label = music_row.get_node("ValueLabel") as Label
	_settings_music_slider.value_changed.connect(_on_music_volume_changed)

	_update_settings_locale()

func _create_settings_slider_row(label_text: String, value: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = label_text.replace(" ", "") + "Row"
	row.add_theme_constant_override("separation", 10)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.name = "Slider"
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var value_label := Label.new()
	value_label.name = "ValueLabel"
	value_label.text = "%d%%" % int(value)
	value_label.custom_minimum_size = Vector2(46, 0)
	row.add_child(value_label)

	return row

func _update_settings_locale() -> void:
	if _settings_button == null:
		return

	var title := "Parametres"
	var master := "Volume general"
	var music := "Musique"

	if _locale_manager and _locale_manager.has_method("tr_key"):
		title = _locale_manager.tr_key("ui.settings")
		master = _locale_manager.tr_key("ui.volume_master")
		music = _locale_manager.tr_key("ui.volume_music")

	_settings_button.text = title
	if _settings_title_label:
		_settings_title_label.text = title
	if _settings_master_label:
		_settings_master_label.text = master
	if _settings_music_label:
		_settings_music_label.text = music

func _on_settings_pressed() -> void:
	if _settings_window:
		_settings_window.visible = not _settings_window.visible

func _on_master_volume_changed(value: float) -> void:
	_settings_master_volume = value
	if _settings_master_value_label:
		_settings_master_value_label.text = "%d%%" % int(value)
	_apply_audio_settings()
	_save_audio_settings()

func _on_music_volume_changed(value: float) -> void:
	_settings_music_volume = value
	if _settings_music_value_label:
		_settings_music_value_label.text = "%d%%" % int(value)
	_apply_audio_settings()
	_save_audio_settings()

func _load_audio_settings() -> void:
	_is_loading_settings = true
	var config := ConfigFile.new()
	if config.load(SETTINGS_CONFIG_PATH) == OK:
		_settings_master_volume = float(config.get_value("audio", "master_volume", _settings_master_volume))
		_settings_music_volume = float(config.get_value("audio", "music_volume", _settings_music_volume))

	if _settings_master_slider:
		_settings_master_slider.set_value_no_signal(_settings_master_volume)
	if _settings_music_slider:
		_settings_music_slider.set_value_no_signal(_settings_music_volume)
	if _settings_master_value_label:
		_settings_master_value_label.text = "%d%%" % int(_settings_master_volume)
	if _settings_music_value_label:
		_settings_music_value_label.text = "%d%%" % int(_settings_music_volume)
	_is_loading_settings = false

func _save_audio_settings() -> void:
	if _is_loading_settings:
		return

	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", _settings_master_volume)
	config.set_value("audio", "music_volume", _settings_music_volume)
	config.save(SETTINGS_CONFIG_PATH)

func _apply_audio_settings() -> void:
	var master_normalized: float = clamp(_settings_master_volume / 100.0, 0.0, 1.0)
	var master_db: float = linear_to_db(master_normalized) if master_normalized > 0.0 else -80.0
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), master_db)

	if MusicManager and MusicManager.has_method("set_music_volume_percent"):
		MusicManager.set_music_volume_percent(_settings_music_volume)

func _on_lang_toggle_pressed() -> void:
	if not _locale_manager:
		return
	if not _locale_manager.has_method("get_locale") or not _locale_manager.has_method("set_locale"):
		return

	var current: String = String(_locale_manager.get_locale())
	var next: String

	match current:
		"fr":
			next = "en"
		"en":
			next = "es"
		"es":
			next = "ja"
		"ja":
			next = "fr"
		_:
			next = "fr"

	_locale_manager.set_locale(next)

func _update_lang_toggle_label() -> void:
	if lang_toggle_button == null:
		return
	if not _locale_manager or not _locale_manager.has_method("get_locale"):
		return

	var current: String = String(_locale_manager.get_locale())

	match current:
		"fr":
			lang_toggle_button.text = "FR"
		"en":
			lang_toggle_button.text = "EN"
		"es":
			lang_toggle_button.text = "ES"
		"ja":
			lang_toggle_button.text = "JA"
		_:
			lang_toggle_button.text = "?"

func _disable_button_keyboard_focus(node: Node) -> void:
	if node is Button:
		(node as Button).focus_mode = Control.FOCUS_NONE

	for child in node.get_children():
		_disable_button_keyboard_focus(child)

func _setup_mobile_controls() -> void:
	if not _should_show_mobile_controls():
		_release_mobile_move_actions()
		return

	if _mobile_controls != null:
		return

	_mobile_controls = Control.new()
	_mobile_controls.name = "MobileControls"
	_mobile_controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mobile_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_controls.z_index = 200
	add_child(_mobile_controls)

	_create_mobile_joystick()

	var right_pad := VBoxContainer.new()
	right_pad.anchor_left = 1.0
	right_pad.anchor_top = 1.0
	right_pad.anchor_right = 1.0
	right_pad.anchor_bottom = 1.0
	right_pad.offset_left = -178
	right_pad.offset_top = -222
	right_pad.offset_right = -18
	right_pad.offset_bottom = -18
	right_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_controls.add_child(right_pad)

	_add_mobile_action_button(right_pad, "Atk", "attack")
	_add_mobile_action_button(right_pad, "Use", "use_assigned_item")
	_add_mobile_action_button(right_pad, "Talk", "interact")

func _should_show_mobile_controls() -> bool:
	if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true

	if OS.has_feature("web") and ClassDB.class_exists("JavaScriptBridge"):
		var user_agent = JavaScriptBridge.eval("navigator.userAgent || ''", true)
		var ua := String(user_agent).to_lower()
		return ua.contains("android") or ua.contains("iphone") or ua.contains("ipad") or ua.contains("ipod") or ua.contains("mobile")

	return false

func _create_mobile_joystick() -> void:
	_mobile_joystick_base = Control.new()
	_mobile_joystick_base.name = "MoveJoystick"
	_mobile_joystick_base.anchor_left = 0.0
	_mobile_joystick_base.anchor_top = 1.0
	_mobile_joystick_base.anchor_right = 0.0
	_mobile_joystick_base.anchor_bottom = 1.0
	_mobile_joystick_base.offset_left = 24.0
	_mobile_joystick_base.offset_top = -168.0
	_mobile_joystick_base.offset_right = 144.0
	_mobile_joystick_base.offset_bottom = -48.0
	_mobile_joystick_base.mouse_filter = Control.MOUSE_FILTER_STOP
	_mobile_joystick_base.gui_input.connect(_on_mobile_joystick_input)
	_mobile_controls.add_child(_mobile_joystick_base)

	var base_visual := ColorRect.new()
	base_visual.name = "Base"
	base_visual.color = Color(0.05, 0.05, 0.08, 0.38)
	base_visual.set_anchors_preset(Control.PRESET_FULL_RECT)
	base_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_joystick_base.add_child(base_visual)

	_mobile_joystick_knob = ColorRect.new()
	_mobile_joystick_knob.name = "Knob"
	_mobile_joystick_knob.color = Color(1.0, 0.86, 0.28, 0.75)
	_mobile_joystick_knob.custom_minimum_size = Vector2(46, 46)
	_mobile_joystick_knob.size = Vector2(46, 46)
	_mobile_joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_joystick_base.add_child(_mobile_joystick_knob)
	_reset_mobile_joystick()

func _on_mobile_joystick_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_mobile_joystick_dragging = event.pressed
		if event.pressed:
			_update_mobile_joystick(event.position)
		else:
			_reset_mobile_joystick()
		_mobile_joystick_base.accept_event()
	elif event is InputEventScreenDrag:
		_update_mobile_joystick(event.position)
		_mobile_joystick_base.accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mobile_joystick_dragging = event.pressed
		if event.pressed:
			_update_mobile_joystick(event.position)
		else:
			_reset_mobile_joystick()
		_mobile_joystick_base.accept_event()
	elif event is InputEventMouseMotion and _mobile_joystick_dragging:
		_update_mobile_joystick(event.position)
		_mobile_joystick_base.accept_event()

func _update_mobile_joystick(local_position: Vector2) -> void:
	if _mobile_joystick_base == null:
		return

	var center: Vector2 = _mobile_joystick_base.size * 0.5
	var offset: Vector2 = local_position - center
	if offset.length() > _mobile_joystick_radius:
		offset = offset.normalized() * _mobile_joystick_radius

	if _mobile_joystick_knob:
		_mobile_joystick_knob.position = center + offset - (_mobile_joystick_knob.size * 0.5)

	var direction := offset / _mobile_joystick_radius
	_apply_mobile_move_vector(direction)

func _reset_mobile_joystick() -> void:
	if _mobile_joystick_base and _mobile_joystick_knob:
		_mobile_joystick_knob.position = (_mobile_joystick_base.size - _mobile_joystick_knob.size) * 0.5
	_release_mobile_move_actions()

func _apply_mobile_move_vector(direction: Vector2) -> void:
	var dead_zone := 0.25
	_set_mobile_action_state("move_left", direction.x < -dead_zone)
	_set_mobile_action_state("move_right", direction.x > dead_zone)
	_set_mobile_action_state("move_up", direction.y < -dead_zone)
	_set_mobile_action_state("move_down", direction.y > dead_zone)

func _set_mobile_action_state(action_name: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(action_name)
	else:
		Input.action_release(action_name)

func _release_mobile_move_actions() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")

func _add_mobile_action_button(parent: Control, label: String, action_name: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(52, 52)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.modulate = Color(1, 1, 1, 0.82)
	button.button_down.connect(_on_mobile_action_down.bind(action_name))
	button.button_up.connect(_on_mobile_action_up.bind(action_name))
	parent.add_child(button)
	return button

func _on_mobile_action_down(action_name: String) -> void:
	Input.action_press(action_name)

func _on_mobile_action_up(action_name: String) -> void:
	Input.action_release(action_name)

func _process(_delta: float) -> void:
	_update_player_panels()
	_refresh_inventory_items_ui()
	_sync_item_slot_toggle_from_state()

	if _fog_enabled_for_scene and not _fog_ready:
		if _fog_retry_frames < 10:
			_fog_retry_frames += 1
			_center_map()
		return

	if not _fog_enabled_for_scene or not _fog_ready:
		return

	_update_fog_overlay_region()
	_update_fog_discovery()

func _setup_fog_overlay() -> void:
	if fog_overlay == null:
		return

	fog_overlay.texture = null
	fog_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fog_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	fog_overlay.visible = true
	fog_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_overlay.z_index = 20

func _configure_minimap_cull_mask() -> void:
	# Keep only canvas layer 1 visible in minimap.
	# Health bars are moved to layer 2 in gameplay scripts.
	var configured := false

	if map_viewport and map_viewport.has_method("set_canvas_cull_mask_bit"):
		for layer_bit in range(0, 20):
			map_viewport.set_canvas_cull_mask_bit(layer_bit, layer_bit == 0)
		configured = true

	# Compatibility fallback in case viewport API differs.
	if not configured and map_camera:
		if map_camera.has_method("set_cull_mask_value"):
			for layer in range(1, 21):
				map_camera.set_cull_mask_value(layer, layer == 1)
		elif map_camera.has_method("set_canvas_cull_mask_bit"):
			for layer_bit in range(0, 20):
				map_camera.set_canvas_cull_mask_bit(layer_bit, layer_bit == 0)

func _on_window_resized() -> void:
	call_deferred("_sync_minimap_window_size")

func _sync_minimap_window_size() -> void:
	if map_container and map_viewport:
		map_viewport.size = map_container.size
		if _map_bounds.size.x > 0.0 and _map_bounds.size.y > 0.0:
			map_container.set_map_bounds(_map_bounds)
	_update_fog_overlay_region()

func _on_opacity_changed(value: float) -> void:
	if minimap_window:
		minimap_window.modulate.a = value

func _on_inventory_opacity_changed(value: float) -> void:
	if inventory_window:
		inventory_window.modulate.a = value

func _on_stats_opacity_changed(value: float) -> void:
	if stats_window:
		stats_window.modulate.a = value

func _on_actions_opacity_changed(value: float) -> void:
	if actions_window:
		actions_window.modulate.a = value

func _on_toggle_pressed() -> void:
	if minimap_window:
		minimap_window.visible = not minimap_window.visible
		if minimap_window.visible:
			call_deferred("_on_window_resized")
			call_deferred("_center_map")

func _on_inventory_pressed() -> void:
	if inventory_window:
		inventory_window.visible = not inventory_window.visible

func _on_stats_pressed() -> void:
	if stats_window:
		stats_window.visible = not stats_window.visible

func _on_actions_pressed() -> void:
	if actions_window:
		actions_window.visible = not actions_window.visible

func _on_attack_toggle_toggled(enabled: bool) -> void:
	if _is_syncing_attack_toggle:
		return

	var player: Node2D = _get_player_ref()
	if player:
		if player.has_method("set_attack_enabled"):
			player.set_attack_enabled(enabled)
		else:
			player.set("attack_enabled", enabled)

	_update_attack_toggle_text(enabled)

func _on_item_slot_toggle_toggled(enabled: bool) -> void:
	if _is_syncing_item_slot_toggle:
		return

	if GameState.has_method("toggle_assigned_action_item"):
		if enabled:
			GameState.set_assigned_action_item(_action_item_id)
		else:
			if GameState.get_assigned_action_item() == _action_item_id:
				GameState.set_assigned_action_item("")

	_sync_item_slot_toggle_from_state()

func _update_attack_toggle_text(enabled: bool) -> void:
	if attack_toggle_button:
		if _locale_manager and _locale_manager.has_method("tr_key"):
			attack_toggle_button.text = _locale_manager.tr_key("ui.attack_on" if enabled else "ui.attack_off")
		else:
			attack_toggle_button.text = "Attack: ON" if enabled else "Attack: OFF"

func _update_item_slot_toggle_text(enabled: bool) -> void:
	if item_slot_toggle_button == null:
		return

	var count: int = 0
	if GameState.has_method("get_item_count"):
		count = int(GameState.get_item_count(_action_item_id))

	if _locale_manager and _locale_manager.has_method("tr_key"):
		item_slot_toggle_button.text = _locale_manager.tr_key(
			"ui.potion_on" if enabled else "ui.potion_off",
			{"count": count}
		)
	else:
		if enabled:
			item_slot_toggle_button.text = "Potion Slot (R): ON x%d" % count
		else:
			item_slot_toggle_button.text = "Potion Slot (R): OFF x%d" % count

func _sync_attack_toggle_from_player() -> void:
	var player: Node2D = _get_player_ref()
	if player == null or attack_toggle_button == null:
		return

	var enabled := true
	if player.has_method("is_attack_enabled"):
		enabled = bool(player.is_attack_enabled())
	else:
		var raw_value = player.get("attack_enabled")
		if raw_value is bool:
			enabled = raw_value

	_is_syncing_attack_toggle = true
	attack_toggle_button.set_pressed_no_signal(enabled)
	_is_syncing_attack_toggle = false
	_update_attack_toggle_text(enabled)

func _sync_item_slot_toggle_from_state() -> void:
	if item_slot_toggle_button == null:
		return

	var assigned_item: String = ""
	if GameState.has_method("get_assigned_action_item"):
		assigned_item = String(GameState.get_assigned_action_item())

	var has_item: bool = true
	if GameState.has_method("get_item_count"):
		has_item = int(GameState.get_item_count(_action_item_id)) > 0

	var enabled: bool = assigned_item == _action_item_id and has_item

	_is_syncing_item_slot_toggle = true
	item_slot_toggle_button.set_pressed_no_signal(enabled)
	_is_syncing_item_slot_toggle = false
	item_slot_toggle_button.disabled = not has_item
	_update_item_slot_toggle_text(enabled)

func _refresh_inventory_items_ui() -> void:
	if inventory_items_list == null:
		return

	if not GameState.has_method("get_inventory_counts"):
		return

	var counts: Dictionary = GameState.get_inventory_counts()
	var signature: String = _build_inventory_signature(counts)
	if signature == _last_inventory_signature:
		return

	_last_inventory_signature = signature

	for child in inventory_items_list.get_children():
		child.queue_free()

	if counts.is_empty():
		var empty_label: Label = Label.new()
		if _locale_manager and _locale_manager.has_method("tr_key"):
			empty_label.text = _locale_manager.tr_key("ui.inventory_empty")
		else:
			empty_label.text = "(No items)"
		inventory_items_list.add_child(empty_label)
		return

	var assigned_item: String = ""
	if GameState.has_method("get_assigned_action_item"):
		assigned_item = String(GameState.get_assigned_action_item())

	for item_id_variant in counts.keys():
		var item_id: String = String(item_id_variant)
		var count: int = int(counts[item_id])
		if count <= 0:
			continue

		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var item_name: String = item_id
		if GameState.has_method("get_item_display_name"):
			item_name = String(GameState.get_item_display_name(item_id))

		var item_label: Label = Label.new()
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var text := "%s x%d" % [item_name, count]

		if GameState.equipped_weapon == item_id:
			if _locale_manager:
				text += " " + _locale_manager.tr_key("ui.equipped")
			else:
				text += " EQUIPPED"

		item_label.text = text
		
		row.add_child(item_label)

		var slot_button: Button = Button.new()
		slot_button.focus_mode = Control.FOCUS_NONE
		
		var category := String(
					GameState.item_definitions[item_id].get("category", "")
				)
		
		if category != "weapon":
			if _locale_manager and _locale_manager.has_method("tr_key"):
				slot_button.text = _locale_manager.tr_key("ui.slot_on" if assigned_item == item_id else "ui.slot_off")
			else:
				slot_button.text = "R: ON" if assigned_item == item_id else "R: OFF"
			slot_button.pressed.connect(_on_inventory_slot_toggle_pressed.bind(item_id))
		row.add_child(slot_button)

		var use_button: Button = Button.new()

		if _locale_manager and _locale_manager.has_method("tr_key"):
			if category == "weapon":
				use_button.text = _locale_manager.tr_key("ui.equip")
			else:
				use_button.text = _locale_manager.tr_key("ui.use")
				
		use_button.focus_mode = Control.FOCUS_NONE
		use_button.pressed.connect(_on_inventory_use_pressed.bind(item_id))
		row.add_child(use_button)

		inventory_items_list.add_child(row)

func _build_inventory_signature(counts: Dictionary) -> String:
	if counts.is_empty():
		var assigned_empty: String = ""
		if GameState.has_method("get_assigned_action_item"):
			assigned_empty = String(GameState.get_assigned_action_item())
		return "@assigned:%s" % assigned_empty

	var keys: Array = counts.keys()
	keys.sort()

	var parts := PackedStringArray()
	for key_variant in keys:
		var key: String = String(key_variant)
		parts.append("%s:%d" % [key, int(counts[key])])

	var assigned_item: String = ""
	if GameState.has_method("get_assigned_action_item"):
		assigned_item = String(GameState.get_assigned_action_item())
	parts.append("@assigned:%s" % assigned_item)

	return "|".join(parts)

func _on_inventory_slot_toggle_pressed(item_id: String) -> void:
	if not GameState.has_method("get_assigned_action_item") or not GameState.has_method("set_assigned_action_item"):
		return

	var current: String = String(GameState.get_assigned_action_item())
	if current == item_id:
		GameState.set_assigned_action_item("")
	else:
		GameState.set_assigned_action_item(item_id)

	_last_inventory_signature = "__dirty__"
	_sync_item_slot_toggle_from_state()

func _on_inventory_use_pressed(item_id: String) -> void:
	var player: Node2D = _get_player_ref()
	if player == null:
		return

	if not GameState.item_definitions.has(item_id):
		return

	var item_data: Dictionary = GameState.item_definitions[item_id]
	var category: String = String(item_data.get("category", ""))

	match category:

		"weapon":
			GameState.equip_weapon(item_id)
			print("Arme équipée :", item_id)

		"consumable":
			if GameState.has_method("use_item"):
				GameState.use_item(item_id, player)

		_:
			print("Catégorie inconnue :", category)

	_last_inventory_signature = "__dirty__"

func _update_player_panels() -> void:
	var coins: int = int(GameState.gold)

	if inventory_placeholder:
		if _locale_manager and _locale_manager.has_method("tr_key"):
			inventory_placeholder.text = _locale_manager.tr_key("ui.coins", {"count": coins})
		else:
			inventory_placeholder.text = "Coins: %d" % coins

	var player: Node2D = _get_player_ref()
	if player == null:
		return

	var current_hp: int = _read_player_int(player, "get_current_health", "health", 0)
	var max_hp: int = max(1, _read_player_int(player, "get_max_health", "max_health", 1))

	var base_atk: int = _read_player_int(player, "get_attack_value", "attack_damage", 0)
	var base_def: int = _read_player_int(player, "get_defense_value", "defense", 0)

	var weapon_atk := GameState.get_weapon_attack()
	var weapon_def := GameState.get_weapon_defense()

	var total_atk := base_atk + weapon_atk
	var total_def := base_def + weapon_def

	if hp_label:
		if _locale_manager and _locale_manager.has_method("tr_key"):
			hp_label.text = _locale_manager.tr_key("ui.hp", {"current": current_hp, "max": max_hp})
		else:
			hp_label.text = "HP: %d / %d" % [current_hp, max_hp]

	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = clamp(current_hp, 0, max_hp)

	if atk_label:
		atk_label.text = _locale_manager.tr_key("ui.atk_a") + ": %d (+%d)" % [total_atk, weapon_atk]

	if def_label:
		def_label.text = "DEF: %d (+%d)" % [total_def, weapon_def]

	# Affichage de l'arme équipée
	if weapon_label:
		var weapon_name := String(_locale_manager.tr_key("ui.none") if _locale_manager else "None")
		if GameState.equipped_weapon != "":
			if GameState.has_method("get_item_display_name"):
				weapon_name = GameState.get_item_display_name(GameState.equipped_weapon)
			elif GameState.item_definitions.has(GameState.equipped_weapon):
				weapon_name = String(
					GameState.item_definitions[GameState.equipped_weapon].get(
						"display_name",
						GameState.equipped_weapon
					)
				)

		if _locale_manager:
			weapon_label.text = "%s: %s" % [
				_locale_manager.tr_key("ui.weapon"),
				weapon_name
			]
		else:
			weapon_label.text = "Weapon: %s" % weapon_name

		var player_level: int = _read_player_int(player, "get_level_value", "player_level", GameState.player_level)
		var player_exp: int = _read_player_int(player, "get_experience_value", "player_exp", GameState.player_exp)
		var player_exp_to_next: int = max(1, _read_player_int(player, "get_experience_to_next_value", "player_exp_to_next", GameState.player_exp_to_next))
		weapon_label.text += "\nLVL: %d | XP: %d / %d" % [player_level, player_exp, player_exp_to_next]

	_sync_attack_toggle_from_player()

func _read_player_int(player: Node2D, getter_name: String, property_name: String, default_value: int) -> int:
	if player.has_method(getter_name):
		return int(player.call(getter_name))

	var raw_value = player.get(property_name)
	if raw_value is int or raw_value is float:
		return int(raw_value)

	return default_value

func _center_map() -> void:
	var main_cam = get_viewport().get_camera_2d()
	if main_cam and map_camera:
		map_camera.global_position = main_cam.global_position

	_fog_enabled_for_scene = _should_enable_fog_for_scene()
	if not _fog_enabled_for_scene:
		_disable_fog_overlay()

	var bounds = _compute_map_bounds()
	if bounds.size.x > 0.0 and bounds.size.y > 0.0 and map_container:
		_map_bounds = bounds
		map_container.set_map_bounds(bounds)
		if _fog_enabled_for_scene:
			_initialize_fog(bounds)

func _should_enable_fog_for_scene() -> bool:
	var root: Node = get_tree().current_scene
	if root == null:
		return true

	var scene_path: String = root.scene_file_path.to_lower()
	for raw_keyword in fog_disabled_scene_keywords:
		var keyword: String = String(raw_keyword).to_lower()
		if keyword != "" and scene_path.contains(keyword):
			return false

	return true

func _disable_fog_overlay() -> void:
	_fog_ready = false
	_fog_retry_frames = 0
	if fog_overlay:
		fog_overlay.visible = false

func _initialize_fog(bounds: Rect2) -> void:
	if fog_overlay == null:
		return

	var grid_w: int = maxi(1, int(ceil(bounds.size.x / fog_cell_size)))
	var grid_h: int = maxi(1, int(ceil(bounds.size.y / fog_cell_size)))
	var next_grid := Vector2i(grid_w, grid_h)

	if _fog_ready and next_grid == _fog_grid_size:
		_update_fog_overlay_region()
		_update_fog_discovery()
		return

	_fog_grid_size = next_grid
	_discovered_image = Image.create(grid_w, grid_h, false, Image.FORMAT_RGBA8)
	_discovered_image.fill(Color(0, 0, 0, 1))
	_fog_display_image = Image.create(grid_w, grid_h, false, Image.FORMAT_RGBA8)
	_fog_display_image.fill(Color(0, 0, 0, 1))
	_fog_texture = ImageTexture.create_from_image(_fog_display_image)
	_fog_atlas = AtlasTexture.new()
	_fog_atlas.atlas = _fog_texture
	_fog_atlas.region = Rect2(Vector2.ZERO, Vector2(grid_w, grid_h))
	fog_overlay.texture = _fog_atlas
	fog_overlay.visible = true
	_has_last_player_pos = false
	_fog_ready = true
	_fog_retry_frames = 0

	_update_fog_overlay_region()
	_update_fog_discovery()

func _update_fog_overlay_region() -> void:
	if not _fog_ready or fog_overlay == null or _fog_atlas == null or map_camera == null or map_viewport == null:
		return

	var safe_zoom: Vector2 = map_camera.zoom
	if safe_zoom.x == 0.0:
		safe_zoom.x = 1.0
	if safe_zoom.y == 0.0:
		safe_zoom.y = 1.0

	# Camera2D zoom reduces visible world when values grow, so world size is viewport / zoom.
	var view_size_world: Vector2 = Vector2(map_viewport.size) / safe_zoom
	var view_min_world: Vector2 = map_camera.global_position - view_size_world * 0.5

	var tex_pos: Vector2 = (view_min_world - _map_bounds.position) / fog_cell_size
	var tex_size: Vector2 = view_size_world / fog_cell_size

	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	var max_x: float = float(_fog_grid_size.x) - tex_size.x
	var max_y: float = float(_fog_grid_size.y) - tex_size.y

	if max_x < 0.0:
		tex_pos.x = 0.0
		tex_size.x = float(_fog_grid_size.x)
	else:
		tex_pos.x = clamp(tex_pos.x, 0.0, max_x)

	if max_y < 0.0:
		tex_pos.y = 0.0
		tex_size.y = float(_fog_grid_size.y)
	else:
		tex_pos.y = clamp(tex_pos.y, 0.0, max_y)

	_fog_atlas.region = Rect2(tex_pos, tex_size)

func _get_player_ref() -> Node2D:
	if _player_ref and is_instance_valid(_player_ref):
		return _player_ref

	var group_player: Node = get_tree().get_first_node_in_group("player")
	if group_player is Node2D:
		_player_ref = group_player
		return _player_ref

	var root: Node = get_tree().current_scene
	if root:
		var fallback_player: Node = root.find_child("Player", true, false)
		if fallback_player is Node2D:
			_player_ref = fallback_player
			return _player_ref

		var fallback: Node = root.find_child("Player1", true, false)
		if fallback is Node2D:
			_player_ref = fallback

	return _player_ref

func _update_fog_discovery() -> void:
	if not _fog_ready or _discovered_image == null or _fog_display_image == null or _fog_texture == null:
		return

	var player: Node2D = _get_player_ref()
	if player == null:
		return

	var player_pos: Vector2 = player.global_position
	if _has_last_player_pos and player_pos.distance_squared_to(_last_player_pos) < 1.0:
		return

	_last_player_pos = player_pos
	_has_last_player_pos = true

	var center: Vector2i = _world_to_fog_cell(player_pos)
	var radius_cells: int = int(ceil(visible_radius_world / fog_cell_size))
	var radius_world_sq: float = visible_radius_world * visible_radius_world

	for y in range(-radius_cells, radius_cells + 1):
		for x in range(-radius_cells, radius_cells + 1):
			var cell := center + Vector2i(x, y)
			if cell.x < 0 or cell.y < 0 or cell.x >= _fog_grid_size.x or cell.y >= _fog_grid_size.y:
				continue

			var cell_world: Vector2 = _fog_cell_center_world(cell)
			if cell_world.distance_squared_to(player_pos) > radius_world_sq:
				continue

			_discovered_image.set_pixel(cell.x, cell.y, Color(1, 1, 1, 1))

	_rebuild_fog_display(player_pos, radius_world_sq)

func _rebuild_fog_display(player_pos: Vector2, radius_world_sq: float) -> void:

	for y in range(_fog_grid_size.y):
		for x in range(_fog_grid_size.x):
			var fog_color: Color = Color(0.0, 0.0, 0.0, 1.0)

			if _discovered_image.get_pixel(x, y).r > 0.5:
				fog_color = Color(0.18, 0.18, 0.18, 0.55)

			var cell_world: Vector2 = _fog_cell_center_world(Vector2i(x, y))
			if cell_world.distance_squared_to(player_pos) <= radius_world_sq:
				fog_color = Color(0.0, 0.0, 0.0, 0.0)

			_fog_display_image.set_pixel(x, y, fog_color)

	_fog_texture.update(_fog_display_image)

func _world_to_fog_cell(world_pos: Vector2) -> Vector2i:
	var local := world_pos - _map_bounds.position
	return Vector2i(
		int(floor(local.x / fog_cell_size)),
		int(floor(local.y / fog_cell_size))
	)

func _fog_cell_center_world(cell: Vector2i) -> Vector2:
	return _map_bounds.position + Vector2(
		(float(cell.x) + 0.5) * fog_cell_size,
		(float(cell.y) + 0.5) * fog_cell_size
	)

func _compute_map_bounds() -> Rect2:
	var root = get_tree().current_scene
	if root == null:
		return Rect2()

	var tilemaps = _find_all_tilemaps(root)
	var full_rect = Rect2()
	var is_first = true

	for tm in tilemaps:
		var used := _get_tilemap_used_rect(tm)
		if used.has_area():
			var cell_size = _get_tilemap_cell_size(tm)
			var local_rect = Rect2(Vector2(used.position) * Vector2(cell_size), Vector2(used.size) * Vector2(cell_size))
			var global_rect = Rect2(tm.to_global(local_rect.position), local_rect.size)

			if is_first:
				full_rect = global_rect
				is_first = false
			else:
				full_rect = full_rect.merge(global_rect)

	return full_rect if not is_first else Rect2()

func _get_tilemap_cell_size(tilemap: TileMap) -> Vector2:
	if tilemap.tile_set:
		return tilemap.tile_set.tile_size
	if tilemap.has_method("get_tileset"):
		var ts = tilemap.get_tileset()
		if ts:
			return ts.tile_size
	return Vector2(16, 16)

func _get_tilemap_used_rect(tilemap: TileMap) -> Rect2i:
	if tilemap.has_method("update_internals"):
		tilemap.update_internals()

	var used := tilemap.get_used_rect()
	if used.has_area():
		return used

	if tilemap.has_method("get_layers_count") and tilemap.has_method("get_used_cells"):
		var layer_count: int = int(tilemap.get_layers_count())
		var min_cell := Vector2i(2147483647, 2147483647)
		var max_cell := Vector2i(-2147483648, -2147483648)
		var found := false

		for layer in range(layer_count):
			var cells: Array = tilemap.get_used_cells(layer)
			for cell_variant in cells:
				var cell: Vector2i = Vector2i(cell_variant)
				if not found:
					min_cell = cell
					max_cell = cell
					found = true
				else:
					min_cell.x = min(min_cell.x, cell.x)
					min_cell.y = min(min_cell.y, cell.y)
					max_cell.x = max(max_cell.x, cell.x)
					max_cell.y = max(max_cell.y, cell.y)

		if found:
			var size := (max_cell - min_cell) + Vector2i.ONE
			return Rect2i(min_cell, size)

	var size_prop = tilemap.get("SIZE")
	if size_prop is Vector2i:
		return Rect2i(Vector2i.ZERO, size_prop)

	return used

func _find_all_tilemaps(node: Node) -> Array:
	var result = []
	if node is TileMap:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_tilemaps(child))
	return result

func _init_settings_drag() -> void:
	if _settings_window == null:
		return

	# récupère la barre de titre créée dynamiquement
	var header = _settings_window.get_node("TitleBar/Header")
	if header:
		_settings_header = header
		header.mouse_filter = Control.MOUSE_FILTER_STOP
		header.gui_input.connect(_on_settings_header_input)


func _on_settings_header_input(event: InputEvent) -> void:
	if _settings_window == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_settings_dragging = true
			_settings_drag_offset = _settings_window.global_position - get_viewport().get_mouse_position()
		else:
			_settings_dragging = false

	elif event is InputEventMouseMotion and _settings_dragging:
		_settings_window.global_position = get_viewport().get_mouse_position() + _settings_drag_offset

extends Node

signal locale_changed(locale: String)

const DEFAULT_LOCALE := "fr"

var _current_locale: String = DEFAULT_LOCALE

var _translations := {
	"fr": {
		"ui.email": "Email",
		"ui.pseudo": "Pseudo",
		"ui.password": "Password",
		"ui.login": "Login",
		"ui.register": "Register",
		"ui.map": "Carte",
		"ui.inventory": "Inventaire",
		"ui.stats": "Stats",
		"ui.actions": "Actions",
		"ui.minimap": "Minimap",
		"ui.coins": "Coins: {count}",
		"ui.hp": "HP: {current} / {max}",
		"ui.atk": "ATK: {value}",
		"ui.def": "DEF: {value}",
		"ui.attack_on": "Attack: ON",
		"ui.attack_off": "Attack: OFF",
		"ui.potion_on": "Potion Slot (R): ON x{count}",
		"ui.potion_off": "Potion Slot (R): OFF x{count}",
		"ui.inventory_empty": "(No items)",
		"ui.slot_on": "R: ON",
		"ui.slot_off": "R: OFF",
		"ui.use": "Use",
		"ui.action_3": "Action 3",
		"item.healing_potion": "Potion de soin",
		"item.speed_potion": "Potion de vitesse"
	},
	"en": {
		"ui.email": "Email",
		"ui.pseudo": "Username",
		"ui.password": "Password",
		"ui.login": "Login",
		"ui.register": "Register",
		"ui.map": "Map",
		"ui.inventory": "Inventory",
		"ui.stats": "Stats",
		"ui.actions": "Actions",
		"ui.minimap": "Minimap",
		"ui.coins": "Coins: {count}",
		"ui.hp": "HP: {current} / {max}",
		"ui.atk": "ATK: {value}",
		"ui.def": "DEF: {value}",
		"ui.attack_on": "Attack: ON",
		"ui.attack_off": "Attack: OFF",
		"ui.potion_on": "Potion Slot (R): ON x{count}",
		"ui.potion_off": "Potion Slot (R): OFF x{count}",
		"ui.inventory_empty": "(No items)",
		"ui.slot_on": "R: ON",
		"ui.slot_off": "R: OFF",
		"ui.use": "Use",
		"ui.action_3": "Action 3",
		"item.healing_potion": "Healing Potion",
		"item.speed_potion": "Speed Potion"
	},
	"es": {
		"ui.email": "Email",
		"ui.pseudo": "Usuario",
		"ui.password": "Contrasena",
		"ui.login": "Iniciar sesion",
		"ui.register": "Registrarse",
		"ui.map": "Mapa",
		"ui.inventory": "Inventario",
		"ui.stats": "Estadisticas",
		"ui.actions": "Acciones",
		"ui.minimap": "Minimapa",
		"ui.coins": "Monedas: {count}",
		"ui.hp": "HP: {current} / {max}",
		"ui.atk": "ATK: {value}",
		"ui.def": "DEF: {value}",
		"ui.attack_on": "Ataque: ON",
		"ui.attack_off": "Ataque: OFF",
		"ui.potion_on": "Pocion (R): ON x{count}",
		"ui.potion_off": "Pocion (R): OFF x{count}",
		"ui.inventory_empty": "(Sin objetos)",
		"ui.slot_on": "R: ON",
		"ui.slot_off": "R: OFF",
		"ui.use": "Usar",
		"ui.action_3": "Accion 3"
	},
	"ja": {
		"ui.email": "Eメール",
		"ui.pseudo": "ユーザー名",
		"ui.password": "パスワード",
		"ui.login": "ログイン",
		"ui.register": "登録",
		"ui.map": "マップ",
		"ui.inventory": "インベントリ",
		"ui.stats": "ステータス",
		"ui.actions": "アクション",
		"ui.minimap": "ミニマップ",
		"ui.coins": "コイン: {count}",
		"ui.hp": "HP: {current} / {max}",
		"ui.atk": "ATK: {value}",
		"ui.def": "DEF: {value}",
		"ui.attack_on": "攻撃: ON",
		"ui.attack_off": "攻撃: OFF",
		"ui.potion_on": "ポーション(R): ON x{count}",
		"ui.potion_off": "ポーション(R): OFF x{count}",
		"ui.inventory_empty": "(アイテムなし)",
		"ui.slot_on": "R: ON",
		"ui.slot_off": "R: OFF",
		"ui.use": "使う",
		"ui.action_3": "アクション3"
	}
}

func _ready() -> void:
	if OS.has_feature("web"):
		var window = JavaScriptBridge.get_interface("window")
		if window:
			window.godotSetLocale = JavaScriptBridge.create_callback(_on_js_set_locale)
			var stored = JavaScriptBridge.eval("localStorage.getItem('rpg-lang')", true)
			if stored != null and String(stored) != "":
				set_locale(String(stored))
				return

	set_locale(_current_locale)

func _on_js_set_locale(args) -> void:
	if args is Array and args.size() > 0:
		set_locale(String(args[0]))
	elif args is String:
		set_locale(String(args))

func set_locale(locale: String) -> void:
	var normalized := locale.strip_edges()
	if normalized == "":
		normalized = DEFAULT_LOCALE
	if not _translations.has(normalized):
		normalized = "en"

	if _current_locale == normalized:
		return

	_current_locale = normalized
	TranslationServer.set_locale(_current_locale)
	emit_signal("locale_changed", _current_locale)

func get_locale() -> String:
	return _current_locale

func tr_key(key: String, params: Dictionary = {}) -> String:
	var dict: Dictionary = _translations.get(_current_locale, {})
	var fallback: Dictionary = _translations.get("en", {})
	var text: String = String(dict.get(key, fallback.get(key, key)))
	return _format(text, params)

func _format(text: String, params: Dictionary) -> String:
	var result := text
	for k in params.keys():
		result = result.replace("{" + String(k) + "}", str(params[k]))
	return result

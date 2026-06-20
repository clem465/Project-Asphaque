extends Node

signal locale_changed(locale: String)

const DEFAULT_LOCALE := "fr"

var _current_locale: String = DEFAULT_LOCALE

var _translations := {
	"fr": {
		"ui.email": "Email",
		"ui.pseudo": "Pseudo",
		"ui.password": "Mot de passe",
		"ui.login": "Se connecter",
		"ui.register": "S'inscrire",
		"ui.map": "Carte",
		"ui.inventory": "Inventaire",
		"ui.stats": "Stats",
		"ui.actions": "Actions",
		"ui.minimap": "Carte",
		"ui.coins": "Pièce(s): {count}",
		"ui.hp": "PV: {current} / {max}",
		"ui.atk": "ATQ: {value}",
		"ui.def": "DEF: {value}",
		"ui.attack_on": "Attaque: ACTIVÉE",
		"ui.attack_off": "Attaque: DÉSACTIVÉE",
		"ui.potion_on": "Raccourcis Potion (R): ACTIVÉE x{count}",
		"ui.potion_off": "Raccourcis Potion (R): DÉSACTIVÉE x{count}",
		"ui.inventory_empty": "(Aucun d'objet)",
		"ui.slot_on": "R: ACTIVÉE",
		"ui.slot_off": "R: DÉSACTIVÉE",
		"ui.use": "Utilisé",
		"ui.action_3": "Action 3",
		"item.healing_potion": "Potion de soin",
		"item.speed_potion": "Potion de vitesse",
		"ui.weapon": "Arme",
		"ui.equip": "Équiper",
		"ui.equipped": "Équipée",
		"ui.none": "Aucune",
		"item.iron_sword": "Épée en fer",
		"item.steel_sword": "Épée en acier",
		"item.iron_axe": "Hache en fer",
		"item.knight_shield": "Bouclier du chevalier",
		"ui.coins_a": "Pièces",
		"ui.blacksmith": "Forgeron",
		"ui.needed": "requis",
		"ui.Not_enough_coins": "Pas assez de pièces",
		"ui.close_shop": "Fermer la boutique",
		"ui.atk_a": "ATQ",
		"ui.shop": "Magasin",
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
		"item.speed_potion": "Speed Potion",
		"ui.weapon": "Weapon",
		"ui.equip": "Equip",
		"ui.equipped": "Equipped",
		"ui.none": "None",
		"item.iron_sword": "Iron Sword",
		"item.steel_sword": "Steel Sword",
		"item.iron_axe": "Iron Axe",
		"item.knight_shield": "Knight Shield",
		"ui.coins_a": "Coins",
		"ui.blacksmith": "Blacksmith",
		"ui.needed": "needed",
		"ui.Not_enough_coins": "Not enough coins",
		"ui.close_shop": "Close Shop",
		"ui.atk_a": "ATK",
		"ui.shop": "Shop",
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
		"ui.action_3": "Accion 3",
		"ui.weapon": "Arma",
		"ui.equip": "Equipar",
		"ui.equipped": "Equipada",
		"ui.none": "Ninguna",
		"item.iron_sword": "Espada de hierro",
		"item.steel_sword": "Espada de acero",
		"item.iron_axe": "Hacha de hierro",
		"item.knight_shield": "Escudo de caballero",
		"ui.coins_a": "Monedas",
		"ui.blacksmith": "Herrero",
		"ui.needed": "necesario",
		"ui.Not_enough_coins": "No hay suficientes monedas",
		"ui.close_shop": "cerrar",
		"ui.atk_a": "ATK",
		"ui.shop": "Tienda",
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
		"ui.action_3": "アクション3",
		"ui.weapon": "武器",
		"ui.equip": "装備",
		"ui.equipped": "装備中",
		"ui.none": "なし",
		"item.iron_sword": "鉄の剣",
		"item.steel_sword": "鋼の剣",
		"item.iron_axe": "鉄の斧",
		"item.knight_shield": "騎士の盾",
		"ui.coins_a": "コイン",
		"ui.blacksmith": "鍛冶屋",
		"ui.needed": "必要",
		"ui.Not_enough_coins": "コインが足りない",
		"ui.close_shop": "閉店",
		"ui.atk_a": "ATK",
		"ui.shop": "ショップ",
		
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

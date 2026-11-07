class_name Idioma
## Español o inglés. El juego se escribe en español; en inglés se traduce solo lo que se ve.
## La tabla assets/i18n/en.json (trozo en español → inglés) es la misma que usa el juego web.
## Se buscan los trozos más largos primero y sin partir palabras, así las frases montadas con
## números o nombres («Oleada 3 · quedan 12») también se traducen.
## Los Label y Button se traducen solos (una Translation propia); el texto pintado pasa por Fonts.outlined.

const TABLA := "res://assets/i18n/en.json"
const AJUSTES := "user://ajustes.cfg"

static var lang := "es"
static var _tabla: Dictionary = {}
static var _rx: RegEx
static var _tr: Translation
static var _cache: Dictionary = {}
static var _letras: RegEx
static var _dec: RegEx
static var _pct: RegEx
static var _iniciado := false

## Lee el idioma guardado y engancha la traducción de los controles. Llamar una vez al arrancar.
static func iniciar() -> void:
	if _iniciado:
		return
	_iniciado = true
	var cfg := ConfigFile.new()
	if cfg.load(AJUSTES) == OK:
		lang = "en" if str(cfg.get_value("juego", "idioma", "es")) == "en" else "es"
	_tr = Traduccion.new()
	_tr.locale = "en"
	TranslationServer.add_translation(_tr)
	TranslationServer.set_locale(lang)

## quita la traducción propia antes de cerrar: si se queda en TranslationServer, se libera
## después de los scripts y Godot se cae al salir
static func soltar() -> void:
	if _tr != null:
		TranslationServer.remove_translation(_tr)
		_tr = null
	_iniciado = false

static func poner(nuevo: String, guardar := true) -> void:
	nuevo = "en" if nuevo == "en" else "es"
	if nuevo == lang:
		return
	lang = nuevo
	TranslationServer.set_locale(lang)   # los controles se vuelven a traducir solos
	if not guardar:
		return
	var cfg := ConfigFile.new()
	cfg.load(AJUSTES)
	cfg.set_value("juego", "idioma", lang)
	cfg.save(AJUSTES)

static func _cargar() -> void:
	var f := FileAccess.open(TABLA, FileAccess.READ)
	if f == null:
		push_error("Falta la tabla de idioma " + TABLA)
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		_tabla = d
	var claves: Array = _tabla.keys()
	claves.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var partes := PackedStringArray()
	for k: String in claves:
		var p := _escapar(k)
		if _es_letra(k.unicode_at(0)):
			p = "(?<!\\pL)" + p
		if _es_letra(k.unicode_at(k.length() - 1)):
			p += "(?!\\pL)"
		partes.append(p)
	_rx = RegEx.create_from_string("(*UTF)(?:" + "|".join(partes) + ")")
	_letras = RegEx.create_from_string("(*UTF)\\pL\\pL|\\d,\\d|\\d %")
	_dec = RegEx.create_from_string("(\\d),(\\d{1,2})(?!\\d)")
	_pct = RegEx.create_from_string("(\\d) %")

static func _es_letra(c: int) -> bool:
	return String.chr(c).to_upper() != String.chr(c).to_lower()

static func _escapar(s: String) -> String:
	var o := ""
	for i in s.length():
		var c := s[i]
		if ".*+?^${}()|[]\\/".contains(c):
			o += "\\"
		o += c
	return o

## Traduce un texto para mostrarlo. En español lo devuelve tal cual.
static func t(s: String) -> String:
	if lang != "en" or s.is_empty():
		return s
	if _cache.has(s):
		return _cache[s]
	if _rx == null:
		_cargar()
		if _rx == null:
			return s
	if _letras.search(s) == null:
		return s
	var o := ""
	var pos := 0
	for m in _rx.search_all(s):
		o += s.substr(pos, m.get_start() - pos) + str(_tabla[m.get_string()])
		pos = m.get_end()
	o += s.substr(pos)
	o = _pct.sub(_dec.sub(o, "$1.$2", true), "$1%", true).replace("«", "\"").replace("»", "\"")
	if _cache.size() > 6000:
		_cache.clear()
	_cache[s] = o
	return o

## Translation que pasa todos los textos de los controles por Idioma.t
class Traduccion extends Translation:
	func _get_message(src_message: StringName, _context: StringName) -> StringName:
		return StringName(Idioma.t(String(src_message)))

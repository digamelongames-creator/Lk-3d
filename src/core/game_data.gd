class_name GameData
## Tablas sacadas del juego web (assets/web/data/*.json). Se leen una vez y se guardan.

const DIR := "res://assets/web/data/"
static var _cache := {}

static func get_table(name: String) -> Variant:
	if _cache.has(name):
		return _cache[name]
	var path := DIR + name + ".json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Falta la tabla " + path)
		return null
	var v: Variant = JSON.parse_string(f.get_as_text())
	_cache[name] = v
	return v

static func constants() -> Dictionary: return get_table("constants")
static func theme_deco() -> Dictionary: return get_table("theme_deco")
static func tiles_meta() -> Dictionary: return get_table("tiles_meta")
static func tiles_look() -> Dictionary: return get_table("tiles_look")
static func deco_meta() -> Dictionary: return get_table("deco_meta")

## Tema según la profundidad (castillo → cripta → cavernas → forja → infierno).
static func theme_for_depth(d: int) -> String:
	const BANDS := [[3, "castle"], [6, "crypt"], [9, "cave"], [12, "forge"], [13, "hell"], [14, "souls"]]
	for b in BANDS:
		if d <= b[0]:
			return b[1]
	return "hell"

## Metadatos de un tema de casillas (el Osario usa los objetos del Infierno con sus propias texturas).
static func theme_meta(th: String) -> Dictionary:
	var meta := tiles_meta()
	if th == "souls" and not meta.has("souls"):
		var s: Dictionary = meta["hell"].duplicate(true)
		s["name"] = "Osario de Sangre"
		var tex: Dictionary = s["tex"]
		tex["floorA"] = [0, 714, 256, 256]
		tex["floorB"] = [256, 714, 256, 256]
		tex["corr"] = [0, 971, 256, 256]
		tex["cap"] = [417, 971, 64, 64]
		tex["face"] = [256, 971, 160, 64]
		meta["souls"] = s
	return meta.get(th, meta["castle"])

## Objetos del tema: [{i, w, h, k}] filtrados por clase ('s' sólido, 'f' plano, 'w' pared, 'v' vegetación).
static func theme_props(th: String, kind: String = "") -> Array:
	var out := []
	var props: Array = theme_meta(th)["props"]
	for i in props.size():
		var p: Array = props[i]
		if kind == "" or p[4] == kind:
			out.append({"i": i, "w": int(p[2]), "h": int(p[3]), "k": p[4]})
	return out

static func theme_deco_for(th: String) -> Dictionary:
	var td := theme_deco()
	return td.get(th, td["castle"])

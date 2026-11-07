class_name Temas
## Datos del editor de mapas (sin dibujo): temas de texturas por bioma, ajustes de cada textura
## y pisos editados («receta»: semilla + cambios).
##   user://texturas/suelos/*.png|jpg   user://texturas/muros/*.png|jpg   (cada una con su .json de ajustes)
##   user://texturas/temas.json         {"activo": "original", "temas": {nombre: {bioma|"*": {"suelo", "muro"}}}}
##   user://pisos/<nombre>.json         receta de un piso editado
## El tema «original» es el dibujo de siempre: no tiene entrada en el archivo.

const DIR := "user://texturas"
const ARCHIVO := "user://texturas/temas.json"
const DIR_PISOS := "user://pisos"
const ORIGINAL := "original"
const TIPOS := ["suelos", "muros"]
const EXT := ["png", "jpg", "jpeg", "webp"]
const BIOMAS := ["castle", "crypt", "cave", "forge", "hell", "souls"]
const AJUSTES_BASE := {"casillas": 4, "brillo": 0.0, "contraste": 1.0, "tono": 0.0, "aplanar": 0.0, "motas": 0.0}
## ejemplos que trae el juego: se copian a user:// la primera vez
const EJEMPLOS := {
	"suelos": {"Suelo_2.png": "res://assets/texturas/suelos/Suelo_2.jpg", "Suelo1.png": "res://assets/texturas/suelos/Suelo1.jpg"},
	"muros": {"Pared_1.png": "res://assets/texturas/muros/Pared_1.jpg"},
}
const AJUSTES_EJEMPLO := {
	"suelos/Suelo_2.png": {"casillas": 4, "brillo": -0.35, "contraste": 1.1, "aplanar": 0.5},
	"suelos/Suelo1.png": {"casillas": 3, "brillo": -0.3, "contraste": 1.05, "aplanar": 0.4},
	"muros/Pared_1.png": {"casillas": 3, "brillo": 0.15, "contraste": 1.15, "aplanar": 0.4, "motas": 0.6},
}
const TEMA_EJEMPLO := "piedra_64"

static var datos := {"activo": ORIGINAL, "temas": {}}
## el editor está abierto: todos los pisos llevan máscara para poder ponerles textura al momento
static var forzar_mascara := false
static var _cargado := false

static func iniciar() -> void:
	if _cargado:
		return
	_cargado = true
	for t in TIPOS:
		DirAccess.make_dir_recursive_absolute(DIR.path_join(t))
	DirAccess.make_dir_recursive_absolute(DIR_PISOS)
	if FileAccess.file_exists(ARCHIVO):
		var d = JSON.parse_string(FileAccess.get_file_as_string(ARCHIVO))
		if d is Dictionary:
			datos = {"activo": String(d.get("activo", ORIGINAL)), "temas": d.get("temas", {})}
	_instalar_ejemplos()

static func guardar() -> void:
	var f := FileAccess.open(ARCHIVO, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(datos, "\t"))

static func _instalar_ejemplos() -> void:
	var nuevo := false
	for t in EJEMPLOS:
		for n in EJEMPLOS[t]:
			var dst := DIR.path_join(t).path_join(n)
			if FileAccess.file_exists(dst):
				continue
			var tx := load(EJEMPLOS[t][n]) as Texture2D
			if tx == null:
				continue
			var img := tx.get_image()
			img.convert(Image.FORMAT_RGB8)
			img.save_png(dst)
			var aj: Dictionary = AJUSTES_BASE.duplicate()
			aj.merge(AJUSTES_EJEMPLO.get(t + "/" + n, {}), true)
			guardar_ajustes(t, n, aj)
			nuevo = true
	if not datos.temas.has(TEMA_EJEMPLO):
		datos.temas[TEMA_EJEMPLO] = {"*": {"suelo": "Suelo_2.png", "muro": "Pared_1.png"}}
		nuevo = true
	if nuevo:
		guardar()

# ---------------- texturas ----------------
static func lista(tipo: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(DIR.path_join(tipo)):
		if EXT.has(f.get_extension().to_lower()):
			out.append(f)
	out.sort()
	return out

static func ruta(tipo: String, nombre: String) -> String:
	return DIR.path_join(tipo).path_join(nombre)

static func _ruta_json(tipo: String, nombre: String) -> String:
	return ruta(tipo, nombre.get_basename() + ".json")

static func ajustes(tipo: String, nombre: String) -> Dictionary:
	var aj: Dictionary = AJUSTES_BASE.duplicate()
	var p := _ruta_json(tipo, nombre)
	if FileAccess.file_exists(p):
		var d = JSON.parse_string(FileAccess.get_file_as_string(p))
		if d is Dictionary:
			for k in aj:
				if d.has(k):
					aj[k] = d[k]
	aj.casillas = clampi(int(aj.casillas), 1, 12)
	return aj

static func guardar_ajustes(tipo: String, nombre: String, aj: Dictionary) -> void:
	var f := FileAccess.open(_ruta_json(tipo, nombre), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(aj, "\t"))

# ---------------- temas ----------------
static func nombres() -> PackedStringArray:
	var out := PackedStringArray([ORIGINAL])
	var k: Array = datos.temas.keys()
	k.sort()
	for n in k:
		out.append(String(n))
	return out

static func activo() -> String:
	return String(datos.activo) if (datos.activo == ORIGINAL or datos.temas.has(datos.activo)) else ORIGINAL

static func poner_activo(n: String, guardar_ya := true) -> void:
	datos.activo = n
	if guardar_ya:
		guardar()

static func crear(n: String) -> bool:
	n = n.strip_edges().replace("/", "_").replace("\\", "_")
	if n == "" or n == ORIGINAL or datos.temas.has(n):
		return false
	datos.temas[n] = {}
	datos.activo = n
	guardar()
	return true

## {"suelo": nombre|"", "muro": nombre|""} del tema activo en ese bioma ("*" vale para todos)
static func del_bioma(bioma: String, tema: String = "") -> Dictionary:
	if tema == "":
		tema = activo()
	var r := {"suelo": "", "muro": ""}
	if tema == ORIGINAL or not datos.temas.has(tema):
		return r
	var T: Dictionary = datos.temas[tema]
	for k in ["*", bioma]:
		if T.has(k):
			for c in ["suelo", "muro"]:
				if T[k].has(c):
					r[c] = String(T[k][c])
	return r

static func poner(bioma: String, campo: String, nombre: String) -> void:
	var tema := activo()
	if tema == ORIGINAL:
		return
	var T: Dictionary = datos.temas[tema]
	if not T.has(bioma):
		T[bioma] = {}
	T[bioma][campo] = nombre
	guardar()

static func necesita_mascara(L: Dictionary) -> bool:
	if forzar_mascara or not (L.get("tex_cambios", {}) as Dictionary).is_empty():
		return true
	var b := del_bioma(String(L.get("theme", "")))
	return b.suelo != "" or b.muro != ""

# ---------------- pisos editados ----------------
static func receta_nueva(semilla: String, ola: int, bioma: String) -> Dictionary:
	return {"semilla": semilla, "ola": ola, "bioma": bioma, "tam": 0, "grid": {}, "tex": {}}

## genera el piso de una receta: mapa de la semilla con su tamaño de salas, y encima las casillas cambiadas
static func construir_L(r: Dictionary) -> Dictionary:
	DungeonGen.tam_salas = int(r.get("tam", 0))
	var L := DungeonGen.gen_level(String(r.semilla), int(r.ola), String(r.get("bioma", "")))
	DungeonGen.tam_salas = 0
	var G: PackedByteArray = L.grid
	var gc: Dictionary = r.get("grid", {})
	for k in gc:
		var i := int(k)
		if i >= 0 and i < G.size():
			G[i] = int(gc[k])
	var tc := {}
	var rt: Dictionary = r.get("tex", {})
	for k in rt:
		tc[int(k)] = String(rt[k])
	L["tex_cambios"] = tc
	return L

static func lista_pisos() -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(DIR_PISOS):
		if f.get_extension() == "json":
			out.append(f.get_basename())
	out.sort()
	return out

static func guardar_piso(nombre: String, r: Dictionary) -> bool:
	nombre = nombre.strip_edges().replace("/", "_").replace("\\", "_")
	if nombre == "":
		return false
	var f := FileAccess.open(DIR_PISOS.path_join(nombre + ".json"), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(r, "\t"))
	return true

static func cargar_piso(nombre: String) -> Dictionary:
	var p := DIR_PISOS.path_join(nombre + ".json")
	if not FileAccess.file_exists(p):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not (d is Dictionary) or not d.has("semilla"):
		return {}
	var r := receta_nueva(String(d.semilla), int(d.get("ola", 1)), String(d.get("bioma", "")))
	r.tam = int(d.get("tam", 0))
	r.grid = d.get("grid", {})
	r.tex = d.get("tex", {})
	return r

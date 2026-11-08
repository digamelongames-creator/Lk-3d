class_name Props3D
## Piezas de los paquetes de fuera (Poly Haven y Sketchfab), ya convertidas por
## tools/blender/props_glb.py a res://assets/props/<paquete>.glb: una pieza por objeto, con el
## origen abajo en el centro (o atrás, si va colgada) y el frente mirando a +Z.
##
##   Props3D.crear("polyhaven", "cofre") → MeshInstance3D (null si no está)
##
## Los paquetes que vienen sin texturas (low_poly, gotico) se visten aquí con el ladrillo de
## Poly Haven, el suelo del juego o la piedra del kit (ver _material()).
## Autores y licencias: docs/CREDITOS_Y_LICENCIAS.md y assets/creditos.json.

const RUTA := "res://assets/props/%s.glb"
const PAQUETES := ["polyhaven", "dungeon_kit", "armas", "ruinas", "low_poly", "gotico"]

static var _raices := {}      # paquete → Node3D instanciado (fuera del árbol)
static var _mallas := {}      # "paquete/pieza" → Mesh (con los materiales ya cambiados)
static var _mats := {}

## vaciar las cachés al salir (si no, Godot se cuelga al cerrar; ver KitMazmorra.limpiar)
static func limpiar() -> void:
	for r in _raices.values():
		if is_instance_valid(r):
			r.free()
	_raices.clear()
	_mallas.clear()
	_mats.clear()

static func hay(paquete: String) -> bool:
	return ResourceLoader.exists(RUTA % paquete)

static func _raiz(paquete: String) -> Node:
	if _raices.has(paquete):
		return _raices[paquete]
	var r: Node = null
	if hay(paquete):
		var ps := load(RUTA % paquete) as PackedScene
		if ps != null:
			r = ps.instantiate()
	if r == null:
		push_warning("Sin paquete de props: " + RUTA % paquete)
	_raices[paquete] = r
	return r

## la malla de una pieza (compartida entre todas las copias)
static func malla(paquete: String, pieza: String) -> Mesh:
	var k := paquete + "/" + pieza
	if _mallas.has(k):
		return _mallas[k]
	var m: Mesh = null
	var r := _raiz(paquete)
	if r != null:
		var n := r.find_child(pieza, true, false)
		if n == null:
			n = r.find_child(pieza.replace(".", "_"), true, false)
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			m = (n as MeshInstance3D).mesh
			if paquete in ["low_poly", "gotico"]:
				m = m.duplicate() as Mesh
				for s in m.get_surface_count():
					var orig := m.surface_get_material(s)
					m.surface_set_material(s, _material(paquete, pieza, orig.resource_name if orig != null else "", orig))
	if m == null:
		push_warning("Sin pieza %s/%s" % [paquete, pieza])
	_mallas[k] = m
	return m

static func tiene(paquete: String, pieza: String) -> bool:
	return malla(paquete, pieza) != null

## una copia de la pieza, lista para colocar (null si no está)
static func crear(paquete: String, pieza: String) -> MeshInstance3D:
	var m := malla(paquete, pieza)
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = pieza
	mi.mesh = m
	return mi

## alto (en metros) de una pieza, para poner los suelos con la cara de arriba a ras del suelo
static func alto(paquete: String, pieza: String) -> float:
	var m := malla(paquete, pieza)
	return m.get_aabb().size.y if m != null else 0.0

static func caja(paquete: String, pieza: String) -> AABB:
	var m := malla(paquete, pieza)
	return m.get_aabb() if m != null else AABB()

# ---------- materiales para los paquetes sin texturas ----------
static func _material(paquete: String, pieza: String, nombre: String, orig: Material) -> Material:
	var tipo := ""
	if paquete == "low_poly":
		if nombre in ["grey", "dark_grey", "light_grey"]:
			tipo = "suelo" if (pieza.begins_with("floor") or pieza.begins_with("tile")) else "ladrillo"
	elif paquete == "gotico":
		if nombre == "BLACK":
			tipo = "negro"
		elif nombre in ["Material.010", "Material.011"]:
			tipo = "suelo"
		elif nombre in ["material", "material_12", "Material.004", "Material.005"]:
			tipo = "ladrillo"
		else:
			tipo = "piedra"
	if tipo == "":
		return orig
	# el tono original oscurece un poco el ladrillo (los grises del low poly son azulados)
	var tono := Color.WHITE
	if orig is BaseMaterial3D and paquete == "low_poly":
		var c: Color = (orig as BaseMaterial3D).albedo_color
		tono = Color(1, 1, 1).lerp(c * 3.0, .25)
	var k := tipo + "|" + tono.to_html()
	if _mats.has(k):
		return _mats[k]
	var m: Material
	match tipo:
		"ladrillo": m = _ladrillo(tono)
		"suelo": m = _suelo()
		"negro": m = _liso(Color(.03, .03, .03))
		_: m = KitMazmorra.material("")
	_mats[k] = m
	return m

static func _liso(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = .9
	return m

## ladrillo de Poly Haven (patterned_brick_wall, CC0) proyectado en el mundo: 1 repetición cada 2 m
static func _ladrillo(tono: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tono
	m.albedo_texture = _tex("res://assets/texturas/polyhaven/ladrillo_color.jpg")
	m.normal_enabled = true
	m.normal_texture = _tex("res://assets/texturas/polyhaven/ladrillo_normal.jpg")
	m.roughness_texture = _tex("res://assets/texturas/polyhaven/ladrillo_rugosidad.jpg")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(.5, .5, .5)
	return m

static func _suelo() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex("res://assets/texturas/suelos/Suelo1.jpg")
	m.albedo_color = Color(.8, .78, .76)
	m.roughness = .85
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(.5, .5, .5)
	return m

static func _tex(ruta: String) -> Texture2D:
	return load(ruta) as Texture2D if ResourceLoader.exists(ruta) else null

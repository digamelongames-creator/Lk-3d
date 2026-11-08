class_name Armadura3D
extends RefCounted
## Armadura visible del héroe: el Set del Caballero Oscuro (modelo de Diego hecho con Tripo, cortado en
## piezas con tools/blender/armadura_set.py → assets/armaduras/caballero_oscuro/). Cada pieza se cuelga de
## un hueso de Mixamo (Modelo3D.enganche) y sigue la animación. También da la pieza suelta para el suelo,
## y la espada y el escudo del set para las manos.
##
## Colocación: cada pieza tiene un «ancla», un punto del archivo original (coordenadas glTF, en metros)
## que se pone en el hueso, y una escala. Los ejes del original son +Y arriba, +Z delante y −X a la derecha
## del personaje; EJES dice hacia dónde caen arriba, delante y derecha en cada hueso (medido en reposo),
## así que las piezas salen derechas sin girarlas a mano.
##
## Aura según la calidad (Items.RQ_C): básico sin aura; mágico, dorado y legendario con brillo de
## borde (fresnel) que late; dorado y legendario, además, chispas que suben.

const SET := "caballero_oscuro"
const CARPETA := "res://assets/armaduras/caballero_oscuro/"
## clases que llevan este set (las demás, de momento, sin armadura visible)
const CLASES := ["knight"]

## hueco del equipo → piezas (archivo, hueso)
const PIEZAS := {
	"helm":   [{"archivo": "casco", "hueso": "Head"}],
	"chest":  [{"archivo": "peto", "hueso": "Spine2"},
			   {"archivo": "hombrera_der", "hueso": "RightShoulder"},
			   {"archivo": "hombrera_izq", "hueso": "LeftShoulder"}],
	"gloves": [{"archivo": "guante_der", "hueso": "RightHand"},
			   {"archivo": "guante_izq", "hueso": "LeftHand"}],
	"belt":   [{"archivo": "cinturon", "hueso": "Hips"}],
	"boots":  [{"archivo": "bota_der_cana", "hueso": "RightLeg"},
			   {"archivo": "bota_der_pie", "hueso": "RightFoot"},
			   {"archivo": "bota_izq_cana", "hueso": "LeftLeg"},
			   {"archivo": "bota_izq_pie", "hueso": "LeftFoot"}],
}
## armas del set: en la mano, colgadas del hueso con su propio agarre
const ARMAS := {"sword": "espada", "shield": "escudo"}

## ejes del mundo en cada hueso del esqueleto en reposo (idle): arriba, delante y derecha del personaje
const EJES := {
	"Head": [Vector3(0.05, 1.00, 0.00), Vector3(0.04, 0.00, 1.00), Vector3(-1.00, 0.05, 0.04)],
	"Spine2": [Vector3(0.04, 1.00, 0.06), Vector3(0.06, -0.06, 1.00), Vector3(-1.00, 0.04, 0.06)],
	"RightShoulder": [Vector3(0.04, -0.58, -0.81), Vector3(0.99, 0.13, -0.05), Vector3(-0.14, 0.80, -0.58)],
	"LeftShoulder": [Vector3(-0.04, -0.48, -0.88), Vector3(-0.94, 0.31, -0.12), Vector3(-0.33, -0.82, 0.46)],
	"RightHand": [Vector3(-0.01, -0.85, 0.52), Vector3(0.51, 0.44, 0.74), Vector3(0.86, -0.28, -0.43)],
	"LeftHand": [Vector3(0.06, -0.86, 0.50), Vector3(-0.22, 0.48, 0.85), Vector3(0.97, 0.16, 0.16)],
	"RightLeg": [Vector3(0.19, -0.97, -0.15), Vector3(-0.43, -0.22, 0.87), Vector3(0.88, 0.10, 0.46)],
	"LeftLeg": [Vector3(-0.25, -0.97, -0.07), Vector3(0.24, -0.13, 0.96), Vector3(0.94, -0.22, -0.26)],
	"RightFoot": [Vector3(0.11, -0.45, 0.89), Vector3(-0.36, 0.81, 0.46), Vector3(0.92, 0.37, 0.07)],
	"LeftFoot": [Vector3(-0.11, -0.45, 0.89), Vector3(0.14, 0.88, 0.46), Vector3(0.98, -0.17, 0.03)],
	"Hips": [Vector3(-0.05, 1.00, 0.07), Vector3(0.09, -0.06, 0.99), Vector3(-0.99, -0.06, 0.09)],
}

## ancla (punto del original que va en el hueso), escala, desplazamiento (m, ejes del personaje:
## x derecha, y arriba, z delante) y giro extra (grados, ejes del original)
const AJUSTE := {
	# el cráneo del esqueleto es grande y va adelantado; la columna va por detrás del pecho
	"casco": {"ancla": Vector3(-0.1462, 0.095, 0.0016), "esc": 2.35, "desp": Vector3(0, 0, .1)},
	"peto": {"ancla": Vector3(-0.2888, 0.135, 0.0035), "esc": 2.95, "desp": Vector3(0, -.01, .07)},
	"hombrera_der": {"ancla": Vector3(-0.316, 0.179, 0.0), "esc": 2.95, "desp": Vector3(0, 0, .05)},
	"hombrera_izq": {"ancla": Vector3(-0.254, 0.179, 0.0), "esc": 2.95, "desp": Vector3(0, 0, .05)},
	"guante_der": {"ancla": Vector3(-0.0521, 0.14, 0.0134), "esc": 2.2},
	"guante_izq": {"ancla": Vector3(0.0003, 0.14, 0.0134), "esc": 2.2},
	"cinturon": {"ancla": Vector3(0.2561, 0.155, 0.0), "esc": 2.0, "desp": Vector3(0, .03, .04)},
	"bota_der_cana": {"ancla": Vector3(0.08, 0.226, 0.0035), "esc": 2.6},
	"bota_der_pie": {"ancla": Vector3(0.08, 0.069, 0.0035), "esc": 2.6},
	"bota_izq_cana": {"ancla": Vector3(0.1371, 0.226, 0.0033), "esc": 2.6},
	"bota_izq_pie": {"ancla": Vector3(0.1371, 0.069, 0.0033), "esc": 2.6},
	# armas (ejes de la mano en reposo): la espada, cogida por el puño en la palma y con la hoja hacia
	# delante; el escudo, en el antebrazo y mirando hacia fuera
	"espada": {"ancla": Vector3(-0.4453, 0.225, -0.0015), "esc": 3.4, "desp": Vector3(0, -.08, .02), "giro": Vector3(-65, 0, 0)},
	"escudo": {"ancla": Vector3(0.4147, 0.1192, 0.0177), "esc": 2.6, "desp": Vector3(-.05, .08, 0), "giro": Vector3(0, 90, 0)},
}

static var _escenas := {}
static var _centros := {}
static var _aura_shader: Shader

static func limpiar() -> void:
	_escenas.clear()
	_centros.clear()
	_aura_shader = null

static func huecos() -> Array:
	return PIEZAS.keys()

## ¿se ve esta pieza del equipo con el set? (de la clase del set y con su modelo)
static func tiene(it) -> bool:
	if it == null or not it.get("gear", false) or not CLASES.has(String(it.get("cls", ""))):
		return false
	var s: String = it.slot
	return (PIEZAS.has(s) or ARMAS.has(s)) and ResourceLoader.exists(CARPETA + String(_archivos(s)[0]) + ".gltf")

static func _archivos(s: String) -> Array:
	if ARMAS.has(s):
		return [ARMAS[s]]
	return PIEZAS[s].map(func(d): return d.archivo)

## viste el modelo con el equipo; devuelve los nodos creados (para soltarlos al cambiar)
static func vestir(modelo: Modelo3D, eq: Dictionary) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for s in PIEZAS:
		var it = eq.get(s)
		if not tiene(it):
			continue
		for d in PIEZAS[s]:
			var n := pieza(d.archivo, d.hueso, it)
			modelo.enganche(d.hueso).add_child(n)
			out.append(n)
	return out

## arma del set para la mano («RightHand» o «LeftHand»); una espada en la izquierda sale en espejo
static func arma(it, hueso: String) -> Node3D:
	if not tiene(it) or not ARMAS.has(String(it.slot)):
		return null
	var n := pieza(ARMAS[it.slot], hueso, it)
	if it.slot == "sword" and hueso == "LeftHand":
		n.scale.x *= -1
	return n

## una pieza colocada en su hueso (con su escala, su aura y sus chispas)
static func pieza(archivo: String, hueso: String, it) -> Node3D:
	var e: Array = EJES.get(hueso, [Vector3.UP, Vector3.BACK, Vector3.LEFT])
	var aj: Dictionary = AJUSTE.get(archivo, {})
	var esc := float(aj.get("esc", 1.0))
	# columnas: a dónde van los ejes del original (X = izquierda, Y = arriba, Z = delante) en el hueso
	var B := Basis(-(e[2] as Vector3), e[0], e[1]).orthonormalized()
	var R := Basis.from_euler(aj.get("giro", Vector3.ZERO) * PI / 180.0)
	var ancla: Vector3 = aj.get("ancla", centro(archivo))
	var desp: Vector3 = aj.get("desp", Vector3.ZERO)
	var desp_o := Vector3(-desp.x, desp.y, desp.z)   # a ejes del original
	var raiz := Node3D.new()
	raiz.name = "pieza_" + archivo
	var cuerpo := _cargar(archivo, it)
	cuerpo.transform = Transform3D(B * R * Basis.from_scale(Vector3.ONE * esc),
		B * desp_o - B * R * ((ancla - centro(archivo)) * esc))
	raiz.add_child(cuerpo)
	_chispas_si(raiz, it, cuerpo.transform.origin, .09 if archivo in ["peto", "casco", "escudo"] else .05)
	return raiz

## la pieza para el botín del suelo: todas las del hueco, como estaban en el modelo, de pie
## (la espada y el escudo, tumbados)
static func suelta(it) -> Node3D:
	if not tiene(it):
		return null
	var E := 2.2
	var n := Node3D.new()
	var archivos := _archivos(it.slot)
	var c0 := Vector3.ZERO
	for a in archivos:
		c0 += centro(a)
	c0 /= archivos.size()
	var tumbada: bool = it.slot in ["sword", "shield"]
	var giro := Basis.from_euler(Vector3(-PI / 2, 0, 0)) if tumbada else Basis()
	var bajo := INF
	for a in archivos:
		var p := _cargar(a, it)
		p.transform = Transform3D(giro * Basis.from_scale(Vector3.ONE * E), giro * ((centro(a) - c0) * E))
		n.add_child(p)
		for mi in _mallas(p):
			bajo = minf(bajo, (p.transform * (mi as MeshInstance3D).get_aabb()).position.y)
	for p in n.get_children():
		(p as Node3D).position.y -= bajo
	_chispas_si(n, it, Vector3(0, .2, 0), .15)
	return n

## centro de una pieza en el archivo original (centros.json de armadura_set.py)
static func centro(archivo: String) -> Vector3:
	if _centros.is_empty():
		var f := FileAccess.open(CARPETA + "centros.json", FileAccess.READ)
		if f != null:
			_centros = JSON.parse_string(f.get_as_text())
	var c: Array = _centros.get(archivo, [0, 0, 0])
	return Vector3(c[0], c[1], c[2])

# ---------- modelos ----------
static func _cargar(archivo: String, it) -> Node3D:
	var ruta := CARPETA + archivo + ".gltf"
	if not _escenas.has(ruta):
		_escenas[ruta] = load(ruta)
	var esc: Node3D = (_escenas[ruta] as PackedScene).instantiate()
	var q := clampi(int(it.get("q", 0)), 0, 3) if it != null else 0
	var aura := _aura(Color(Items.RQ_C[q]), q) if q > 0 else null
	for mi in _mallas(esc):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.material_overlay = aura
	return esc

static func _mallas(n: Node) -> Array:
	var r: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		r.append(n)
	return r

# ---------- aura ----------
## brillo de borde que late, sumado encima del material de la pieza
static func _aura(col: Color, q: int) -> ShaderMaterial:
	if _aura_shader == null:
		_aura_shader = Shader.new()
		_aura_shader.code = """
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(0.4, 0.6, 1.0, 1.0);
uniform float potencia = 3.5;
uniform float fuerza = 1.5;
uniform float base = 0.08;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), potencia);
	float pulso = 0.7 + 0.3 * sin(TIME * 3.0);
	ALBEDO = color.rgb * (f * fuerza + base) * pulso;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _aura_shader
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("fuerza", [0.0, .45, .6, .75][q])
	m.set_shader_parameter("base", [0.0, .0, .0, .015][q])
	return m

static func _chispas_si(n: Node3D, it, pos: Vector3, radio: float) -> void:
	var q := clampi(int(it.get("q", 0)), 0, 3) if it != null else 0
	if q >= 2:
		var p := _chispas(Color(Items.RQ_C[q]), radio)
		p.position = pos
		n.add_child(p)

## chispas del color de la calidad que suben de la pieza (dorado y legendario)
static func _chispas(col: Color, radio: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radio
	p.direction = Vector3.UP
	p.spread = 20
	p.gravity = Vector3(0, .9, 0)
	p.initial_velocity_min = .05
	p.initial_velocity_max = .2
	p.scale_amount_min = .5
	p.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(.025, .025)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	q.material = mat
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 1))
	g.set_color(1, Color(col.r, col.g, col.b, 0))
	p.color_ramp = g
	return p

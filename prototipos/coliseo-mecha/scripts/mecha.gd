extends CharacterBody3D
## Un mecha por piezas (piernas, torso, cabeza y un arma en cada brazo) hecho con formas básicas,
## con la mochila 4×4 de módulos a la espalda. Lo maneja un control (jugador.gd o ia.gd)
## que rellena las órdenes de abajo al principio de cada paso de física.

signal golpeado(cantidad: float, por_golpe: bool)
signal destruido
signal modulo_roto(nombre: String)

const Proyectil = preload("res://scripts/proyectil.gd")
const Modulos = preload("res://scripts/modulos.gd")
const Piezas = preload("res://scripts/piezas.gd")

const ACEL := 45.0
const GRAVEDAD := 30.0
const IMPULSO_COSTE := 30.0
const IMPULSO_VEL := 34.0
const IMPULSO_T := 0.22
const PROPULSOR_EMPUJE := 55.0
const PROPULSOR_COSTE := 40.0
const PROPULSOR_VMAX := 9.0
const CALOR_ENFRIA := 34.0
const CALOR_ENFRIA_BLOQUEO := 42.0
const ESPERA_ENFRIAR := 0.35
const ESPERA_ESCUDO := 2.5
const LADOS := ["i", "d"]

# --- órdenes del control ---
var mover := Vector3.ZERO
var mirar_yaw := 0.0
var punto_mira := Vector3.ZERO
var gatillo_i := false  # brazo izquierdo (mantener)
var gatillo_d := false  # brazo derecho
var pedir_impulso := false
var propulsor := false

# --- estado ---
var control
var nombre := ""
var rival
var activo := false
var muerto := false
var vida := 1000.0
var vida_max := 1000.0
var prop := 0.0
var escudo := 0.0
var t_escudo := 0.0
var montaje: Dictionary = Piezas.DE_SERIE.duplicate()
var construccion: Array = []
var stats: Dictionary = {}
var brazos := {}  # "i"/"d" → estado del arma
var t_impulso := 0.0
var dir_impulso := Vector3.ZERO
var t_aturdido := 0.0
var vel_h := Vector3.ZERO
var empuje := Vector3.ZERO
var propulsando := false
var fx
var golpes_espalda := 0  # para la prueba
var destello_escudo := 0.0

# --- piezas ---
var color_cuerpo: Color
var color_luz: Color
var mat_cuerpo: StandardMaterial3D
var mat_oscuro: StandardMaterial3D
var mat_luz: StandardMaterial3D
var mat_resalte: ShaderMaterial
var cadera: Node3D
var torso: Node3D
var muslos: Array[Node3D] = []
var rodillas: Array[Node3D] = []
var muslo_base := 0.0
var rodilla_base := 0.0
var mochila: Node3D
var nodos_modulo: Array = []
var llamas: Array[MeshInstance3D] = []
var burbuja: MeshInstance3D
var mat_burbuja: ShaderMaterial
var humo: CPUParticles3D
var t_paso := 0.0
var _hueco := ""  # a qué pieza pertenece lo que se está construyendo (para resaltarla en el taller)

const SHADER_ESCUDO := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform float carga = 1.0;
uniform float destello = 0.0;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float lineas = 0.5 + 0.5 * sin(UV.y * 120.0 + TIME * 3.0);
	ALBEDO = color.rgb * (f * (0.6 + 0.6 * carga) * (0.8 + 0.2 * lineas) + destello * 0.5);
	ALPHA = clamp(f * (0.4 + 0.5 * carga) + destello * 0.4, 0.0, 1.0);
}
"""

const SHADER_RESALTE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	ALBEDO = vec3(1.0, 0.75, 0.2) * (0.25 + 0.2 * sin(TIME * 6.0) + f * 0.8);
}
"""


func preparar(p_nombre: String, cuerpo: Color, luz: Color, p_fx) -> void:
	nombre = p_nombre
	color_cuerpo = cuerpo
	color_luz = luz
	fx = p_fx
	collision_layer = 2
	collision_mask = 1 | 2
	floor_snap_length = 0.6
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 1.8
	capsula.height = 6.4
	forma.shape = capsula
	forma.position.y = 3.2
	add_child(forma)

	mat_cuerpo = _mat(color_cuerpo)
	mat_cuerpo.emission_enabled = true
	mat_cuerpo.emission = Color.BLACK
	mat_oscuro = _mat(Color(0.13, 0.13, 0.15), 0.4, 0.8)
	mat_luz = StandardMaterial3D.new()
	mat_luz.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_luz.albedo_color = color_luz
	mat_luz.emission_enabled = true
	mat_luz.emission = color_luz
	mat_luz.emission_energy_multiplier = 3.0
	mat_resalte = ShaderMaterial.new()
	var shr := Shader.new()
	shr.code = SHADER_RESALTE
	mat_resalte.shader = shr

	burbuja = MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 4.4
	esfera.height = 8.4
	burbuja.mesh = esfera
	mat_burbuja = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_ESCUDO
	mat_burbuja.shader = sh
	burbuja.material_override = mat_burbuja
	burbuja.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burbuja.position.y = 3.4
	add_child(burbuja)
	_humo()
	pintar(p_nombre, cuerpo, luz)
	equipar(montaje, [])


func pintar(p_nombre: String, cuerpo: Color, luz: Color) -> void:
	nombre = p_nombre
	color_cuerpo = cuerpo
	color_luz = luz
	mat_cuerpo.albedo_color = cuerpo
	mat_luz.albedo_color = luz
	mat_luz.emission = luz
	mat_burbuja.set_shader_parameter("color", luz.lerp(Color(0.3, 0.7, 1.0), 0.6))


func centro() -> Vector3:
	return global_position + Vector3(0, 3.6, 0)


func cargando_golpe() -> bool:
	for l in LADOS:
		if brazos.has(l) and brazos[l].t_carga > 0.0:
			return true
	return false


# ---------------------------------------------------------------- formas
func _mat(c: Color, rugoso := 0.55, metal := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugoso
	m.metallic = metal
	return m


func _caja(padre: Node3D, tam: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	mi.set_meta("hueco", _hueco)
	padre.add_child(mi)
	return mi


func _cilindro(padre: Node3D, r_arriba: float, r_abajo: float, alto: float, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_arriba
	cm.bottom_radius = r_abajo
	cm.height = alto
	cm.radial_segments = 16
	mi.mesh = cm
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	mi.set_meta("hueco", _hueco)
	padre.add_child(mi)
	return mi


func _pivote(padre: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	padre.add_child(n)
	return n


func _humo() -> void:
	humo = CPUParticles3D.new()
	humo.emitting = false
	humo.amount = 40
	humo.lifetime = 2.0
	humo.direction = Vector3.UP
	humo.spread = 20
	humo.initial_velocity_min = 2.0
	humo.initial_velocity_max = 4.0
	humo.gravity = Vector3(0, 1.0, 0)
	humo.scale_amount_min = 0.8
	humo.scale_amount_max = 1.8
	var hm := SphereMesh.new()
	hm.radius = 0.6
	hm.height = 1.2
	hm.radial_segments = 8
	hm.rings = 4
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.1, 0.1, 0.1, 0.6)
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.material = hmat
	humo.mesh = hm
	humo.position = Vector3(0, 4.5, 0)
	add_child(humo)


# ---------------------------------------------------------------- montaje
## Monta las piezas y la mochila (copias, con los módulos reparados) y recalcula todo.
func equipar(p_montaje: Dictionary, cons: Array) -> void:
	montaje = p_montaje.duplicate()
	construccion = Modulos.copiar(cons)
	for p in construccion:
		p.vida = Modulos.vida_de(p.id)
	stats = Piezas.calcular(montaje, construccion)
	vida_max = stats.vida
	vida = minf(vida, vida_max) if activo else vida_max
	if cadera:
		cadera.free()
	muslos.clear()
	rodillas.clear()
	llamas.clear()
	nodos_modulo.clear()
	cadera = _pivote(self, Vector3(0, stats.cadera, 0))
	_hueco = "piernas"
	_caja(cadera, Vector3(2.2, 0.8, 1.4), Vector3.ZERO, mat_oscuro)
	_piernas(montaje.piernas)
	_hueco = "torso"
	var arriba := _torso(montaje.torso)
	_hueco = "cabeza"
	_cabeza(montaje.cabeza, arriba.cabeza)
	for l in LADOS:
		_hueco = "brazo_" + l
		_brazo(l, montaje["brazo_" + l], arriba.hombro)
	_hueco = "mochila"
	_mochila(arriba.espalda)
	_hueco = ""


func _piernas(tipo: String) -> void:
	match tipo:
		"tanque":
			muslo_base = 0.0
			rodilla_base = 0.0
			for lado in [-1.0, 1.0]:
				var muslo := _pivote(cadera, Vector3(1.25 * lado, -0.1, 0))
				_caja(muslo, Vector3(1.25, 1.4, 1.35), Vector3(0, -0.7, 0), mat_cuerpo)
				_cilindro(muslo, 0.15, 0.15, 1.4, Vector3(0.75 * lado, -0.7, 0.4), Vector3.ZERO, mat_oscuro)
				var rodilla := _pivote(muslo, Vector3(0, -1.3, 0))
				_caja(rodilla, Vector3(1.0, 0.7, 1.0), Vector3(0, 0, -0.15), mat_oscuro)
				_caja(rodilla, Vector3(1.45, 1.3, 1.5), Vector3(0, -0.7, 0.05), mat_cuerpo)
				_caja(rodilla, Vector3(1.9, 0.5, 2.5), Vector3(0, -1.35, -0.2), mat_oscuro)
				muslos.append(muslo)
				rodillas.append(rodilla)
		"zancudas":
			muslo_base = 0.5
			rodilla_base = -1.0
			for lado in [-1.0, 1.0]:
				var muslo := _pivote(cadera, Vector3(0.85 * lado, -0.1, 0))
				_caja(muslo, Vector3(0.6, 1.9, 0.75), Vector3(0, -0.9, 0), mat_cuerpo)
				var rodilla := _pivote(muslo, Vector3(0, -1.8, 0))
				_cilindro(rodilla, 0.32, 0.32, 0.8, Vector3.ZERO, Vector3(0, 0, PI / 2), mat_oscuro)
				_caja(rodilla, Vector3(0.5, 1.9, 0.55), Vector3(0, -0.9, 0), mat_cuerpo)
				_caja(rodilla, Vector3(0.9, 0.25, 1.6), Vector3(0, -1.85, -0.3), mat_oscuro, Vector3(-rodilla_base - muslo_base, 0, 0))
				muslos.append(muslo)
				rodillas.append(rodilla)
		_:
			muslo_base = 0.0
			rodilla_base = 0.0
			for lado in [-1.0, 1.0]:
				var muslo := _pivote(cadera, Vector3(0.95 * lado, -0.1, 0))
				_caja(muslo, Vector3(0.85, 1.7, 1.0), Vector3(0, -0.8, 0), mat_cuerpo)
				_cilindro(muslo, 0.35, 0.35, 1.1, Vector3.ZERO, Vector3(0, 0, PI / 2), mat_oscuro)
				var rodilla := _pivote(muslo, Vector3(0, -1.55, 0))
				_caja(rodilla, Vector3(0.75, 0.6, 0.75), Vector3(0, 0, -0.1), mat_oscuro)
				_caja(rodilla, Vector3(0.95, 1.4, 1.05), Vector3(0, -0.75, 0.05), mat_cuerpo)
				_caja(rodilla, Vector3(1.15, 0.35, 1.9), Vector3(0, -1.45, -0.25), mat_oscuro)
				muslos.append(muslo)
				rodillas.append(rodilla)
	for m in muslos:
		m.rotation.x = muslo_base
	for r in rodillas:
		r.rotation.x = rodilla_base


## Devuelve dónde van la cabeza, los hombros (x) y la mochila.
func _torso(tipo: String) -> Dictionary:
	torso = _pivote(cadera, Vector3(0, 0.35, 0))
	var w: float = Piezas.TORSOS[tipo].ancho
	match tipo:
		"blindado":
			_caja(torso, Vector3(w, 2.2, 2.3), Vector3(0, 1.2, 0), mat_cuerpo)
			_caja(torso, Vector3(w * 0.8, 0.6, 1.8), Vector3(0, 0.1, 0), mat_oscuro)
			_caja(torso, Vector3(w + 0.2, 0.5, 2.4), Vector3(0, 2.1, 0), mat_oscuro)
			_caja(torso, Vector3(1.6, 1.0, 0.25), Vector3(0, 1.1, -1.2), mat_cuerpo)
			_caja(torso, Vector3(0.5, 0.35, 0.1), Vector3(0, 1.1, -1.33), mat_luz)
			return {"cabeza": Vector3(0, 2.35, -0.2), "hombro": w * 0.5 + 0.45, "espalda": Vector3(0, 1.3, 1.2)}
		"reactor":
			_caja(torso, Vector3(w, 1.7, 1.8), Vector3(0, 1.05, 0), mat_cuerpo)
			_caja(torso, Vector3(w * 0.75, 0.6, 1.4), Vector3(0, 0.1, 0), mat_oscuro)
			_cilindro(torso, 0.55, 0.55, 0.3, Vector3(0, 1.05, -0.95), Vector3(PI / 2, 0, 0), mat_oscuro)
			_cilindro(torso, 0.4, 0.4, 0.32, Vector3(0, 1.05, -0.97), Vector3(PI / 2, 0, 0), mat_luz)
			for k in [-1.0, 1.0]:
				_caja(torso, Vector3(0.12, 1.2, 0.12), Vector3(0.95 * k, 1.05, -0.92), mat_luz)
			return {"cabeza": Vector3(0, 1.9, -0.2), "hombro": w * 0.5 + 0.45, "espalda": Vector3(0, 1.2, 0.95)}
		_:
			_caja(torso, Vector3(w, 1.9, 2.0), Vector3(0, 1.1, 0), mat_cuerpo)
			_caja(torso, Vector3(2.4, 0.6, 1.6), Vector3(0, 0.15, 0), mat_oscuro)
			_caja(torso, Vector3(0.6, 0.5, 0.1), Vector3(0, 1.1, -1.03), mat_luz)
			return {"cabeza": Vector3(0, 2.0, -0.25), "hombro": w * 0.5 + 0.45, "espalda": Vector3(0, 1.3, 1.05)}


func _cabeza(tipo: String, pos: Vector3) -> void:
	var c := _pivote(torso, pos)
	match tipo:
		"mira":
			_caja(c, Vector3(1.2, 0.7, 1.3), Vector3(0, 0.35, 0), mat_cuerpo)
			_caja(c, Vector3(2.2, 0.32, 0.5), Vector3(0, 0.55, -0.45), mat_oscuro)
			for k in [-0.7, 0.0, 0.7]:
				_cilindro(c, 0.12, 0.12, 0.1, Vector3(k, 0.55, -0.72), Vector3(PI / 2, 0, 0), mat_luz)
			_cilindro(c, 0.03, 0.03, 1.4, Vector3(0.45, 1.2, 0.3), Vector3.ZERO, mat_oscuro)
		"blindada":
			_cilindro(c, 0.65, 0.85, 0.9, Vector3(0, 0.45, 0), Vector3.ZERO, mat_cuerpo)
			_caja(c, Vector3(1.0, 0.1, 0.12), Vector3(0, 0.5, -0.8), mat_luz)
			for k in [-1.0, 1.0]:
				_caja(c, Vector3(0.2, 0.9, 1.2), Vector3(0.85 * k, 0.4, 0), mat_oscuro)
		_:
			_caja(c, Vector3(1.5, 0.95, 1.4), Vector3(0, 0.475, 0), mat_cuerpo)
			_caja(c, Vector3(1.1, 0.24, 0.1), Vector3(0, 0.5, -0.72), mat_luz)


func _brazo(lado: String, id: String, hombro_x: float) -> void:
	var s := -1.0 if lado == "i" else 1.0
	var f: Dictionary = Piezas.ARMAS[id]
	var n := _pivote(torso, Vector3(hombro_x * s, 1.6, 0))
	_caja(n, Vector3(1.3, 0.9, 1.6), Vector3(0.15 * s, 0.2, 0), mat_cuerpo)
	_caja(n, Vector3(0.7, 1.2, 0.7), Vector3(0.2 * s, -0.7, 0), mat_oscuro)
	var a := _pivote(n, Vector3(0.2 * s, -1.4, 0))
	var b := {"id": id, "f": f, "nodo": n, "calor": 0.0, "sobre": false, "t_disparo": 0.0, "t_sin": 9.0,
		"giro": 0.0, "t_carga": 0.0, "t_recarga": 0.0, "t_anim": 0.0, "antes": false, "giratorio": null}
	match id:
		"vulcan":
			_caja(a, Vector3(1.1, 1.1, 1.4), Vector3(0, 0, -0.2), mat_cuerpo)
			_cilindro(a, 0.55, 0.55, 0.5, Vector3(0, 0, -1.0), Vector3(PI / 2, 0, 0), mat_oscuro)
			var g := _pivote(a, Vector3(0, 0, -1.9))
			for k in 6:
				var ang := TAU * k / 6.0
				_cilindro(g, 0.1, 0.1, 1.8, Vector3(cos(ang) * 0.3, sin(ang) * 0.3, 0), Vector3(PI / 2, 0, 0), mat_oscuro)
			b.giratorio = g
			b.boca = _pivote(a, Vector3(0, 0, -2.9))
		"escopeta":
			_caja(a, Vector3(1.0, 1.0, 1.5), Vector3(0, 0, -0.3), mat_cuerpo)
			for k in [-0.24, 0.24]:
				_cilindro(a, 0.22, 0.22, 1.6, Vector3(k, 0, -1.6), Vector3(PI / 2, 0, 0), mat_oscuro)
			_caja(a, Vector3(1.0, 0.2, 0.6), Vector3(0, -0.4, -1.0), mat_cuerpo)
			b.boca = _pivote(a, Vector3(0, 0, -2.45))
		"pesado":
			_caja(a, Vector3(1.25, 1.25, 2.0), Vector3(0, 0, -0.4), mat_cuerpo)
			_cilindro(a, 0.45, 0.45, 3.0, Vector3(0, 0, -2.0), Vector3(PI / 2, 0, 0), mat_oscuro)
			_caja(a, Vector3(1.1, 0.6, 0.5), Vector3(0, 0, -3.5), mat_cuerpo)
			_caja(a, Vector3(0.2, 0.2, 1.6), Vector3(0, 0.55, -1.4), mat_luz)
			b.boca = _pivote(a, Vector3(0, 0, -3.8))
		"puno":
			_caja(a, Vector3(0.95, 0.95, 1.7), Vector3(0, 0, -0.5), mat_cuerpo)
			b.punta = _pivote(a, Vector3(0, 0, -1.6))
			_caja(b.punta, Vector3(1.3, 1.3, 1.2), Vector3.ZERO, mat_oscuro)
			_caja(b.punta, Vector3(1.35, 0.25, 0.3), Vector3(0, 0.3, -0.5), mat_luz)
		"martillo":
			_caja(a, Vector3(0.9, 0.9, 1.4), Vector3(0, 0, -0.4), mat_cuerpo)
			_cilindro(a, 0.13, 0.13, 2.4, Vector3(0, 0, -2.0), Vector3(PI / 2, 0, 0), mat_oscuro)
			b.punta = _pivote(a, Vector3(0, 0, -3.1))
			_caja(b.punta, Vector3(1.7, 1.1, 1.1), Vector3.ZERO, mat_oscuro)
			_caja(b.punta, Vector3(1.75, 0.2, 0.2), Vector3(0, 0, -0.5), mat_luz)
		"cuchilla":
			_caja(a, Vector3(0.9, 0.9, 1.5), Vector3(0, 0, -0.4), mat_cuerpo)
			_caja(a, Vector3(0.16, 0.55, 3.2), Vector3(0, 0, -2.6), mat_oscuro)
			_caja(a, Vector3(0.18, 0.12, 3.2), Vector3(0, -0.3, -2.6), mat_luz)
			b.punta = _pivote(a, Vector3(0, 0, -3.8))
		_:  # rotativo
			_caja(a, Vector3(0.95, 0.95, 1.6), Vector3(0, 0, -0.3), mat_cuerpo)
			_cilindro(a, 0.3, 0.3, 2.4, Vector3(0, 0, -1.6), Vector3(PI / 2, 0, 0), mat_oscuro)
			_cilindro(a, 0.36, 0.36, 0.3, Vector3(0, 0, -2.75), Vector3(PI / 2, 0, 0), mat_cuerpo)
			b.boca = _pivote(a, Vector3(0, 0, -3.0))
	if not b.has("punta"):
		b.punta = b.boca
	if not b.has("boca"):
		b.boca = b.punta
	brazos[lado] = b


func _mochila(pos: Vector3) -> void:
	mochila = _pivote(torso, pos)
	_caja(mochila, Vector3(2.45, 2.45, 0.25), Vector3.ZERO, mat_oscuro)
	var c := 0.58
	for p in construccion:
		var d: Dictionary = Modulos.CATALOGO[p.id]
		var t := Modulos.tam(p)
		var cx: float = p.pos.x + (t.x - 1) * 0.5
		var cy: float = p.pos.y + (t.y - 1) * 0.5
		var prof: float = {"escudo": 0.75, "prop": 0.65, "bateria": 0.45, "recarga": 0.45, "disipador": 0.35,
			"propulsor": 0.5, "blindaje": 0.3}[d.tipo]
		var nodo := _pivote(mochila, Vector3((cx - 1.5) * c, (1.5 - cy) * c, 0.125))
		var m := _mat(d.color, 0.45, 0.5)
		_caja(nodo, Vector3(t.x * c - 0.08, t.y * c - 0.08, prof), Vector3(0, 0, prof * 0.5), m)
		if d.tipo in ["prop", "escudo", "bateria", "recarga"]:
			_caja(nodo, Vector3(t.x * c - 0.3, 0.08, 0.06), Vector3(0, 0, prof + 0.02), mat_luz)
		if d.tipo == "disipador":
			for k in 4:
				_caja(nodo, Vector3(0.04, t.y * c - 0.15, 0.25), Vector3((k - 1.5) * 0.25, 0, prof + 0.12), mat_oscuro)
		if d.tipo == "propulsor":
			_cilindro(nodo, 0.15, 0.25, 0.4, Vector3(0, -t.y * c * 0.5, prof * 0.5), Vector3.ZERO, mat_oscuro)
		nodos_modulo.append(nodo)
	for lado in [-0.6, 0.6]:
		_cilindro(mochila, 0.25, 0.38, 0.5, Vector3(lado, -1.4, 0.3), Vector3.ZERO, mat_oscuro)
		var llama := _cilindro(mochila, 0.3, 0.02, 1.6, Vector3(lado, -2.4, 0.3), Vector3.ZERO, mat_luz)
		llama.set_meta("hueco", "")
		llama.visible = false
		llamas.append(llama)


## En el taller: ilumina las mallas de una pieza ("" para ninguna).
func resaltar(hueco: String) -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = mat_resalte if hueco != "" and mi.get_meta("hueco", "") == hueco else null


func _recalcular() -> void:
	stats = Piezas.calcular(montaje, construccion)
	stats.vida = vida_max
	prop = minf(prop, stats.prop_max)
	escudo = minf(escudo, stats.escudo_max)


func _danar_modulo(dano: float) -> void:
	var vivos := []
	var blindajes := []
	for i in construccion.size():
		if Modulos.vivo(construccion[i]):
			vivos.append(i)
			if Modulos.CATALOGO[construccion[i].id].tipo == "blindaje":
				blindajes.append(i)
	if vivos.is_empty():
		return
	var i: int = blindajes.pick_random() if not blindajes.is_empty() and randf() < 0.75 else vivos.pick_random()
	var p: Dictionary = construccion[i]
	p.vida -= dano
	if p.vida <= 0.0:
		p.vida = 0.0
		var nodo: Node3D = nodos_modulo[i]
		fx.chispas(nodo.global_position, global_basis.z, Color(1, 0.7, 0.3), 40, 10.0)
		fx.polvo(nodo.global_position, Vector3.ZERO)
		for h in nodo.get_children():
			h.visible = false
		_caja(nodo, Vector3(0.35, 0.35, 0.15), Vector3(0, 0, 0.08), mat_oscuro)
		_recalcular()
		modulo_roto.emit(Modulos.CATALOGO[p.id].nombre)


# ---------------------------------------------------------------- ronda
func restablecer(pos: Vector3, yaw: float) -> void:
	activo = false
	muerto = false
	equipar(montaje, construccion)
	global_position = pos
	rotation = Vector3(0, yaw, 0)
	mirar_yaw = yaw
	velocity = Vector3.ZERO
	vel_h = Vector3.ZERO
	empuje = Vector3.ZERO
	vida = vida_max
	prop = stats.prop_max
	escudo = stats.escudo_max
	t_escudo = 0.0
	destello_escudo = 0.0
	t_impulso = 0.0
	t_aturdido = 0.0
	mover = Vector3.ZERO
	gatillo_i = false
	gatillo_d = false
	pedir_impulso = false
	propulsor = false
	humo.emitting = false
	mat_cuerpo.emission = Color.BLACK
	reset_physics_interpolation()


# ---------------------------------------------------------------- paso
func _physics_process(d: float) -> void:
	if control and activo and not muerto:
		control.pensar(d)
	if not activo or muerto:
		gatillo_i = false
		gatillo_d = false
		propulsor = false
		pedir_impulso = false
		mover = Vector3.ZERO

	t_aturdido -= d
	if not muerto:
		rotation.y = rotate_toward(rotation.y, mirar_yaw, float(stats.giro) * d)

	# escudo
	t_escudo += d
	if t_escudo > ESPERA_ESCUDO and not muerto:
		escudo = minf(stats.escudo_max, escudo + stats.escudo_regen * d)
	destello_escudo = maxf(0.0, destello_escudo - d * 4.0)
	burbuja.visible = escudo > 1.0 and not muerto
	if burbuja.visible:
		mat_burbuja.set_shader_parameter("carga", escudo / maxf(stats.escudo_max, 1.0))
		mat_burbuja.set_shader_parameter("destello", destello_escudo)

	# impulso
	if pedir_impulso:
		pedir_impulso = false
		if prop >= IMPULSO_COSTE and t_impulso <= 0.0 and t_aturdido <= 0.0:
			prop -= IMPULSO_COSTE
			t_impulso = IMPULSO_T
			for l in LADOS:
				brazos[l].t_carga = 0.0
			dir_impulso = mover.normalized() if mover.length() > 0.2 else global_basis.z
			fx.polvo(global_position, dir_impulso)

	# brazos
	for l in LADOS:
		_brazo_paso(l, d)

	# movimiento horizontal
	var hacia_rival := Vector3.ZERO
	if rival:
		hacia_rival = rival.global_position - global_position
		hacia_rival.y = 0
	var golpe = null
	for l in LADOS:
		if brazos[l].t_carga > 0.0:
			golpe = brazos[l]
	if t_impulso > 0.0:
		t_impulso -= d
		vel_h = dir_impulso * IMPULSO_VEL * stats.impulso
		if t_impulso <= 0.0:
			vel_h = dir_impulso * stats.vel
	elif t_aturdido > 0.0:
		vel_h = vel_h.move_toward(Vector3.ZERO, ACEL * d)
	elif golpe != null:
		if hacia_rival.length() < 12.0 and hacia_rival.length() > 3.5:
			vel_h = hacia_rival.normalized() * float(golpe.f.estocada)
			mirar_yaw = atan2(-hacia_rival.x, -hacia_rival.z)
		else:
			vel_h = vel_h.move_toward(Vector3.ZERO, ACEL * d)
	else:
		var ctrl := 1.0 if is_on_floor() else 0.6
		vel_h = vel_h.move_toward(mover.limit_length(1.0) * float(stats.vel), ACEL * ctrl * d)

	empuje = empuje.move_toward(Vector3.ZERO, 38.0 * d)
	velocity.x = vel_h.x + empuje.x
	velocity.z = vel_h.z + empuje.z

	propulsando = propulsor and prop > 0.0 and t_aturdido <= 0.0
	if propulsando:
		velocity.y = minf(velocity.y + PROPULSOR_EMPUJE * stats.empuje * d, PROPULSOR_VMAX * stats.empuje)
		prop = maxf(0.0, prop - PROPULSOR_COSTE * d)
	else:
		velocity.y -= GRAVEDAD * d
		if t_impulso <= 0.0:
			prop = minf(stats.prop_max, prop + stats.prop_regen * d * (1.0 if is_on_floor() else 0.4))

	var en_aire := not is_on_floor()
	var vy_antes := velocity.y
	move_and_slide()
	if en_aire and is_on_floor() and vy_antes < -14.0:
		fx.polvo(global_position, Vector3.ZERO)

	_animar(d)


func _brazo_paso(l: String, d: float) -> void:
	var b: Dictionary = brazos[l]
	var f: Dictionary = b.f
	var gatillo: bool = gatillo_i if l == "i" else gatillo_d
	b.t_disparo -= d
	b.t_sin += d
	b.t_recarga -= d
	b.t_anim -= d
	if f.tipo == "disparo":
		if b.sobre:
			b.calor -= CALOR_ENFRIA_BLOQUEO * stats.enfria * d
			if b.calor <= 0.0:
				b.calor = 0.0
				b.sobre = false
		elif b.t_sin > ESPERA_ENFRIAR:
			b.calor = maxf(0.0, b.calor - CALOR_ENFRIA * stats.enfria * d)
		var puede: bool = not muerto and not b.sobre and t_aturdido <= 0.0 and not cargando_golpe()
		if f.has("arranque"):
			b.giro = move_toward(b.giro, 1.0 if gatillo and puede else 0.0, d / f.arranque)
			if b.giratorio:
				b.giratorio.rotation.z += b.giro * 30.0 * d
		if gatillo and puede and b.t_disparo <= 0.0 and (not f.has("arranque") or b.giro >= 1.0):
			var a := punto_mira - global_position
			a.y = 0
			if a.length() < 0.5 or (-global_basis.z).angle_to(a.normalized()) < deg_to_rad(75.0):
				_disparar(b)
	else:
		if gatillo and not b.antes and b.t_recarga <= 0.0 and b.t_carga <= 0.0 and t_aturdido <= 0.0 and t_impulso <= 0.0 and not muerto:
			b.t_carga = f.carga
			b.t_recarga = f.recarga
		if b.t_carga > 0.0:
			b.t_carga -= d
			if b.t_carga <= 0.0:
				_soltar_golpe(b)
	b.antes = gatillo


func _disparar(b: Dictionary) -> void:
	var f: Dictionary = b.f
	b.t_disparo = f.cadencia
	b.t_sin = 0.0
	b.calor += f.calor * stats.calor
	if b.calor >= 100.0:
		b.calor = 100.0
		b.sobre = true
		fx.vapor(b.boca.global_position)
	var desde: Vector3 = b.boca.global_position
	var dir := (punto_mira - desde).normalized()
	if dir.length() < 0.5:
		dir = -global_basis.z
	var abre: float = f.dispersion * stats.dispersion
	for k in int(f.balas):
		var dd := (dir + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * abre).normalized()
		var p := Proyectil.new()
		p.preparar(self, desde, dd * float(f.vel), f.dano, color_luz, f.vida, f.tam, f.empujon)
		fx.add_child(p)
	fx.fogonazo(desde, color_luz)
	b.nodo.position.z = 0.35 if f.cadencia > 0.1 else 0.12


func _soltar_golpe(b: Dictionary) -> void:
	var f: Dictionary = b.f
	b.t_anim = 0.25
	if not rival or rival.muerto:
		return
	var a: Vector3 = rival.global_position - global_position
	var dy := absf(a.y)
	a.y = 0
	var frente := -global_basis.z
	if a.length() <= float(f.alcance) and dy < 4.5 and frente.dot(a.normalized()) > 0.35:
		var dir := a.normalized()
		rival.recibir(f.dano, true, dir * float(f.empujon), dir, f.aturdido)
		fx.chispas(rival.centro() - dir * 1.6, -dir, Color(1, 0.8, 0.4), 40 + int(f.dano / 5.0), 14.0)
	else:
		fx.polvo(b.punta.global_position, Vector3.ZERO)


## `dir`: hacia dónde va el golpe. Si no va contra la cara del mecha, es por la espalda o el lado.
func recibir(cantidad: float, por_golpe: bool, empujon: Vector3, dir := Vector3.ZERO, aturdido := 0.5) -> void:
	if muerto or not activo:
		return
	var por_detras := dir.length() > 0.1 and dir.normalized().dot(-global_basis.z) > -0.1
	if por_detras:
		golpes_espalda += 1
	var aguante: float = stats.aturdir
	empuje += empujon * aguante
	if escudo > 0.0:
		t_escudo = 0.0
		destello_escudo = 1.0
		if por_golpe:
			escudo = 0.0
			cantidad *= 0.5
			fx.chispas(centro(), Vector3.UP, Color(0.4, 0.8, 1.0), 70, 16.0)
		else:
			escudo -= cantidad
			cantidad = maxf(0.0, -escudo)
			escudo = maxf(0.0, escudo)
			if escudo <= 0.0:
				fx.chispas(centro(), Vector3.UP, Color(0.4, 0.8, 1.0), 50, 12.0)
		if cantidad <= 0.0:
			golpeado.emit(0.0, false)
			return
	vida = maxf(0.0, vida - cantidad)
	if por_detras:
		_danar_modulo(cantidad * (3.0 if por_golpe else 2.0))
	if por_golpe:
		t_aturdido = aturdido * aguante
		for l in LADOS:
			brazos[l].t_carga = 0.0
		velocity.y = maxf(velocity.y, 4.0 * aguante)
	_destello(1.0 if por_golpe else 0.45)
	golpeado.emit(cantidad, por_golpe)
	if vida <= 0.0:
		_morir()


func _destello(fuerza: float) -> void:
	mat_cuerpo.emission = Color(1.0, 0.75, 0.5) * fuerza
	var tw := create_tween()
	tw.tween_property(mat_cuerpo, "emission", Color.BLACK, 0.18)


func _morir() -> void:
	muerto = true
	activo = false
	fx.explosion(centro(), 2.5)
	humo.emitting = true
	var tw := create_tween().set_parallel()
	tw.tween_property(cadera, "position:y", 1.3, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(cadera, "rotation:x", 0.35, 0.9)
	tw.tween_property(torso, "rotation:x", 0.7, 1.0)
	for l in LADOS:
		tw.tween_property(brazos[l].nodo, "rotation:x", -0.9, 0.8)
	destruido.emit()


# ---------------------------------------------------------------- animación
func _animar(d: float) -> void:
	for ll in llamas:
		var on := (propulsando or t_impulso > 0.0) and not muerto
		ll.visible = on
		if on:
			ll.scale = Vector3(1, randf_range(0.8, 1.3) * (1.6 if t_impulso > 0.0 else 1.0), 1)
	if muerto:
		return
	var vmax := maxf(float(stats.vel), 1.0)
	var local_v := global_basis.inverse() * Vector3(velocity.x, 0, velocity.z)
	var rapidez := clampf(local_v.length() / vmax, 0.0, 1.0)
	var alto: float = stats.cadera
	var rs := -1.0 if rodilla_base < 0.0 else 1.0  # las zancudas doblan al revés
	if muslos.size() == 2:
		if is_on_floor():
			t_paso += d * (2.0 + 6.5 * rapidez)
			var paso := sin(t_paso) * 0.55 * rapidez
			var signo := -1.0 if local_v.z <= 0.0 else 1.0
			muslos[0].rotation.x = muslo_base + paso * signo
			muslos[1].rotation.x = muslo_base - paso * signo
			rodillas[0].rotation.x = rodilla_base + maxf(0.0, -sin(t_paso)) * 0.8 * rapidez * rs
			rodillas[1].rotation.x = rodilla_base + maxf(0.0, sin(t_paso)) * 0.8 * rapidez * rs
			cadera.position.y = alto - absf(sin(t_paso)) * 0.15 * rapidez
			cadera.rotation.z = lerpf(cadera.rotation.z, -local_v.x / vmax * 0.08, 0.2)
		else:
			muslos[0].rotation.x = lerpf(muslos[0].rotation.x, muslo_base - 0.35, 0.15)
			muslos[1].rotation.x = lerpf(muslos[1].rotation.x, muslo_base + 0.15, 0.15)
			rodillas[0].rotation.x = lerpf(rodillas[0].rotation.x, rodilla_base + 0.7 * rs, 0.15)
			rodillas[1].rotation.x = lerpf(rodillas[1].rotation.x, rodilla_base + 0.3 * rs, 0.15)

	var incl := -local_v.z / vmax * 0.08
	if t_aturdido > 0.0:
		incl = 0.35
	torso.rotation.x = lerpf(torso.rotation.x, incl, 0.2)

	for l in LADOS:
		var b: Dictionary = brazos[l]
		var n: Node3D = b.nodo
		if b.f.tipo == "disparo":
			var hacia := global_basis.inverse() * (punto_mira - n.global_position)
			var cabeceo := atan2(hacia.y, Vector2(hacia.x, hacia.z).length())
			n.rotation.x = lerpf(n.rotation.x, clampf(cabeceo, -0.8, 0.9), 0.3)
			n.position.z = lerpf(n.position.z, 0.0, 0.25)
		elif b.id == "martillo":
			# golpe de arriba abajo
			if b.t_carga > 0.0:
				n.rotation.x = lerpf(n.rotation.x, 1.3, 0.25)
			elif b.t_anim > 0.0:
				n.rotation.x = lerpf(n.rotation.x, -0.5, 0.6)
			else:
				n.rotation.x = lerpf(n.rotation.x, 0.0, 0.12)
		elif b.id == "cuchilla":
			# tajo de lado
			var s := -1.0 if l == "i" else 1.0
			if b.t_carga > 0.0:
				n.rotation.y = lerpf(n.rotation.y, 0.9 * s, 0.4)
			elif b.t_anim > 0.0:
				n.rotation.y = lerpf(n.rotation.y, -0.7 * s, 0.6)
			else:
				n.rotation.y = lerpf(n.rotation.y, 0.0, 0.15)
		else:
			if b.t_carga > 0.0:
				n.position.z = lerpf(n.position.z, 0.9, 0.35)
				n.rotation.x = lerpf(n.rotation.x, 0.25, 0.35)
			elif b.t_anim > 0.0:
				n.position.z = lerpf(n.position.z, -2.0, 0.6)
				n.rotation.x = lerpf(n.rotation.x, 0.0, 0.6)
			else:
				n.position.z = lerpf(n.position.z, 0.0, 0.15)
				n.rotation.x = lerpf(n.rotation.x, 0.0, 0.15)

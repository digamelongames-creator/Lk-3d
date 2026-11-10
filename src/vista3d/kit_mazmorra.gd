class_name KitMazmorra
## Las piezas con las que se monta la mazmorra.
##
## Salen de res://assets/kit/kit_mazmorra.glb, que genera tools/blender/kit_mazmorra.py
## (muros de bloques de piedra, losas, arcos, pilares, antorchas, braseros…). Cada objeto del .glb
## es una pieza con su nombre. Si el .glb no está, se fabrica un kit provisional de cajas.
##
## Las piezas de casilla van al MeshLibrary del GridMap (mesh_library()); las sueltas
## (antorcha, brasero, estandarte, barril, caja) se piden con pieza(nombre).
## Los materiales los pone Godot según el nombre del material de Blender (MATERIALES), así se
## pueden retocar aquí sin volver a Blender: color, rugosidad, el muro que se vuelve transparente…

const RUTA_GLB := "res://assets/kit/kit_mazmorra.glb"
const CELDA := 2.0       # metros por casilla (una casilla de la simulación = 32 px)
const ALTO_MURO := 3.0

## piezas de casilla (van al GridMap). Las que tienen variantes se eligen al azar por casilla.
const DE_CASILLA := ["muro", "nucleo", "nucleo_b", "cara", "cara_b", "cara_columna", "cara_nicho", "cara_arco_ciego", "cara_puerta",
	"cara_reja", "cara_rota", "cara_hiedra", "columna_esquina", "suelo", "suelo_b", "suelo_sala", "pilar", "arco",
	"agua", "puente", "tumba", "escombro", "mueble", "escalera_baja", "escalera_sube"]
const VARIANTES := {"nucleo": ["nucleo", "nucleo_b"], "suelo": ["suelo", "suelo_b"]}

static var _lib: MeshLibrary
static var _mallas := {}      # nombre → Mesh con los materiales de Godot
static var _mats := {}

static func mesh_library() -> MeshLibrary:
	if _lib != null:
		return _lib
	_cargar_glb()
	_lib = MeshLibrary.new()
	_provisionales()
	for n in DE_CASILLA:
		if _mallas.has(n):
			var i := _lib.get_last_unused_item_id()
			_lib.create_item(i)
			_lib.set_item_name(i, n)
			_lib.set_item_mesh(i, _mallas[n])
	return _lib

## vaciar las cachés estáticas al salir: si siguen vivas cuando Godot apaga el servidor gráfico, el juego se cuelga al cerrar
static func limpiar() -> void:
	_lib = null
	_mallas.clear()
	_mats.clear()
	_shaders_corte.clear()

static func id(nombre: String) -> int:
	return mesh_library().find_item_by_name(nombre)

## una de las variantes de la pieza, fija para cada casilla
static func variante(nombre: String, cx: int, cy: int) -> int:
	var vs: Array = VARIANTES.get(nombre, [nombre])
	var h := absi(hash(Vector2i(cx, cy))) % 100
	# la primera variante sale más (es la «normal»)
	var k := 0 if h < 55 else 1 + h % (vs.size() - 1) if vs.size() > 1 else 0
	return id(vs[k])

## pieza suelta como MeshInstance3D (antorcha, brasero, estandarte, barril, caja…)
static func pieza(nombre: String) -> MeshInstance3D:
	mesh_library()
	var mi := MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = _mallas.get(nombre)
	return mi

static func tiene(nombre: String) -> bool:
	mesh_library()
	return _mallas.has(nombre)

# ---------- .glb de Blender ----------
static func _cargar_glb() -> void:
	if not ResourceLoader.exists(RUTA_GLB):
		push_warning("Sin kit 3D (%s): se usa el provisional" % RUTA_GLB)
		return
	var raiz: Node = (load(RUTA_GLB) as PackedScene).instantiate()
	for mi in raiz.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh.duplicate()
		var del_muro := _es_del_muro(String(mi.name))
		for s in m.get_surface_count():
			var orig := m.surface_get_material(s)
			var nm := orig.resource_name if orig != null else ""
			m.surface_set_material(s, material_corte(nm) if del_muro else material(nm))
		_mallas[String(mi.name)] = m
	raiz.free()

## piezas que forman el muro o cuelgan de él: todas se recortan juntas al tapar al héroe
## (si no, al irse la piedra quedaban la placa oscura de las juntas, las rejas o la hiedra tapándolo)
const DEL_MURO := ["muro", "nucleo", "cara", "columna_esquina", "pilar", "arco", "antorcha", "estandarte"]
static func _es_del_muro(n: String) -> bool:
	for p in DEL_MURO:
		if n == p or n.begins_with(p + "_"):
			return true
	return false

## el mismo material, pero con el hueco del muro que tapa al héroe (la piedra ya lo lleva)
static func material_corte(nombre: String) -> Material:
	if nombre == "piedra":
		return material(nombre)
	var k := nombre + "|corte"
	if _mats.has(k):
		return _mats[k]
	var base := material(nombre)
	var m: Material = base
	if base is StandardMaterial3D:
		var b: StandardMaterial3D = base
		var sm := ShaderMaterial.new()
		sm.shader = _shader_corte_liso(b.cull_mode == BaseMaterial3D.CULL_DISABLED)
		sm.set_shader_parameter("color", b.albedo_color)
		sm.set_shader_parameter("rugosidad", b.roughness)
		sm.set_shader_parameter("metal", b.metallic)
		sm.set_shader_parameter("usa_color_vertice", b.vertex_color_use_as_albedo)
		if b.emission_enabled:
			sm.set_shader_parameter("emision", b.emission)
			sm.set_shader_parameter("emision_k", b.emission_energy_multiplier)
		if b.albedo_texture != null:
			sm.set_shader_parameter("ruido", b.albedo_texture)
			sm.set_shader_parameter("con_ruido", true)
		m = sm
	_mats[k] = m
	return m

static var _shaders_corte := {}
static func _shader_corte_liso(dos_caras: bool) -> Shader:
	if _shaders_corte.has(dos_caras):
		return _shaders_corte[dos_caras]
	var s := Shader.new()
	s.code = "shader_type spatial;\n" + ("render_mode cull_disabled;\n" if dos_caras else "") + CORTE_GLSL + """
uniform vec4 color : source_color = vec4(1.0);
uniform float rugosidad = .9;
uniform float metal = 0.0;
uniform bool usa_color_vertice = true;
uniform vec3 emision : source_color = vec3(0.0);
uniform float emision_k = 0.0;
uniform bool con_ruido = false;
uniform sampler2D ruido : hint_default_white, filter_linear_mipmap, repeat_enable;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	if (hueco_muro(wp)) discard;
	vec3 c = color.rgb;
	if (usa_color_vertice) { c *= COLOR.rgb; }
	if (con_ruido) { c *= texture(ruido, wp.xz * .3 + wp.y * .2).rgb; }
	ALBEDO = c;
	ROUGHNESS = rugosidad;
	METALLIC = metal;
	EMISSION = emision * emision_k;
}
"""
	_shaders_corte[dos_caras] = s
	return s

## el hueco del muro que tapa al héroe, compartido por todos los materiales del muro.
## Hueco limpio: dentro no queda nada; el borde es algo irregular con un ruido fijo en el mundo
## (no se mueve con la pantalla ni con la cámara, así que no parpadea).
## Zona: la pared que queda entre la cámara y el héroe, unos 4 m a cada lado de él; abajo queda el zócalo.
const CORTE_GLSL := """
global uniform vec3 pos_heroe;
global uniform vec2 dir_camara;
uniform float cortar = 1.0;
varying vec3 wp;
float h3_corte(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}
float ruido_corte(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3_corte(i), h3_corte(i + vec3(1.0, 0.0, 0.0)), f.x), mix(h3_corte(i + vec3(0.0, 1.0, 0.0)), h3_corte(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(h3_corte(i + vec3(0.0, 0.0, 1.0)), h3_corte(i + vec3(1.0, 0.0, 1.0)), f.x), mix(h3_corte(i + vec3(0.0, 1.0, 1.0)), h3_corte(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}
bool hueco_muro(vec3 p) {
	// dir_camara: del héroe hacia la cámara, en el suelo
	vec2 r = vec2(p.x - pos_heroe.x, p.z - pos_heroe.z);
	float hacia = dot(r, dir_camara);
	float de_lado = dot(r, vec2(dir_camara.y, -dir_camara.x));
	float delante = smoothstep(-.6, .4, hacia) * (1.0 - smoothstep(6.0, 8.0, hacia));
	float lado = 1.0 - smoothstep(3.4, 4.6, abs(de_lado));
	float alto = smoothstep(.3, .6, p.y);
	float corte = delante * lado * alto * cortar;
	return corte > .3 + ruido_corte(p * 2.5) * .4;
}
"""

## material de Godot para cada material de Blender
static func material(nombre: String) -> Material:
	if _mats.has(nombre):
		return _mats[nombre]
	var m: Material
	match nombre:
		"piedra": m = material_muro()
		"losa": m = _piedra(Color(.45, .41, .38), .7)
		"junta": m = _liso(Color(.04, .035, .03), 1.0)
		"madera": m = _piedra(Color(.42, .26, .14), .75)
		"hierro": m = _liso(Color(.16, .15, .14), .45, .85)
		"oro": m = _liso(Color(.95, .68, .25), .3, 1.0)
		"tela": m = _tela()
		"brasa":
			var b := _liso(Color(.1, .02, 0), 1.0)
			b.emission_enabled = true
			b.emission = Color(1, .35, .08)
			b.emission_energy_multiplier = 3.0
			m = b
		_: m = _piedra(Color(.45, .4, .36), .85)
	_mats[nombre] = m
	return m

static func _liso(c: Color, rug: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rug
	m.metallic = metal
	m.vertex_color_use_as_albedo = true
	return m

static func _tela() -> StandardMaterial3D:
	var m := _liso(Color(.55, .05, .04), .9)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func _ruido(freq: float, normal: bool = false) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.fractal_octaves = 4
	var tx := NoiseTexture2D.new()
	tx.noise = n
	tx.seamless = true
	tx.width = 256
	tx.height = 256
	if normal:
		tx.as_normal_map = true
		tx.bump_strength = 4.0
	return tx

## piedra con color por bloque (el color de vértice de Blender) y textura de ruido proyectada
static func _piedra(c: Color, rug: float) -> StandardMaterial3D:
	var m := _liso(c, rug)
	m.albedo_texture = _ruido(.06)
	m.normal_enabled = true
	m.normal_texture = _ruido(.09, true)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(.6, .6, .6)
	return m

## muro con un hueco limpio donde tapa al héroe, como en Diablo (ver CORTE_GLSL).
## Usa los parámetros globales pos_heroe y dir_camara (project.godot > shader_globals).
static func material_muro() -> ShaderMaterial:
	var s := Shader.new()
	s.code = """
shader_type spatial;
""" + CORTE_GLSL + """
uniform vec3 color : source_color = vec3(.47, .44, .42);
uniform sampler2D ruido : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D relieve : hint_normal, filter_linear_mipmap, repeat_enable;
varying vec3 wn;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
vec4 triplanar(sampler2D t, vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(t, p.zy) * w.x + texture(t, p.xz) * w.y + texture(t, p.xy) * w.z;
}
void fragment() {
	if (hueco_muro(wp)) discard;
	float n = triplanar(ruido, wp * .35, wn).r;
	float n2 = triplanar(ruido, wp * 1.3 + 7.0, wn).r;
	vec3 c = color * COLOR.rgb * (.7 + n * .45) * (.85 + n2 * .3);
	// las caras de arriba algo más claras y las de abajo de cada bloque más oscuras
	c *= mix(.9, 1.12, clamp(wn.y, 0.0, 1.0));
	ALBEDO = c;
	ROUGHNESS = .88;
	vec3 tn = triplanar(relieve, wp * .9, wn).rgb;
	NORMAL_MAP = tn;
	NORMAL_MAP_DEPTH = .8;
}
"""
	var m := ShaderMaterial.new()
	m.shader = s
	m.set_shader_parameter("ruido", _ruido(.05))
	m.set_shader_parameter("relieve", _ruido(.12, true))
	return m

# ---------- piezas provisionales (lo que el .glb no trae) ----------
static func _provisionales() -> void:
	var piedra := _piedra(Color(.45, .4, .36), .85)
	var poner := func(n: String, m: Mesh) -> void:
		if not _mallas.has(n):
			_mallas[n] = m
	poner.call("suelo", _caja(Vector3(CELDA, .2, CELDA), Vector3(0, -.1, 0), piedra))
	poner.call("muro", _caja(Vector3(CELDA, ALTO_MURO, CELDA), Vector3(0, ALTO_MURO / 2, 0), material_muro()))
	var agua := StandardMaterial3D.new()
	agua.albedo_color = Color(.03, .08, .1)
	agua.roughness = .05
	agua.metallic = .3
	poner.call("agua", _caja(Vector3(CELDA, .1, CELDA), Vector3(0, -.45, 0), agua))
	poner.call("puente", _caja(Vector3(CELDA, .15, CELDA * .8), Vector3(0, -.05, 0), material("madera")))
	poner.call("tumba", _caja(Vector3(1.0, .7, 1.7), Vector3(0, .35, 0), piedra))
	poner.call("escombro", _caja(Vector3(1.2, .3, 1.0), Vector3(0, .15, 0), piedra))
	poner.call("mueble", _caja(Vector3(1.4, .8, .8), Vector3(0, .4, 0), material("madera")))
	poner.call("escalera_baja", _caja(Vector3(CELDA * .9, .05, CELDA * .9), Vector3(0, .01, 0), material("brasa")))
	poner.call("escalera_sube", _caja(Vector3(CELDA * .9, .3, CELDA * .9), Vector3(0, .15, 0), piedra))

## caja ya desplazada dentro de la malla (el GridMap pone la malla en el centro de la casilla, a ras de suelo)
static func _caja(t: Vector3, desplaza: Vector3, mat: Material) -> ArrayMesh:
	var b := BoxMesh.new()
	b.size = t
	var st := SurfaceTool.new()
	st.create_from(b, 0)
	var am := st.commit()
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(am, 0)
	for i in mdt.get_vertex_count():
		mdt.set_vertex(i, mdt.get_vertex(i) + desplaza)
	var am2 := ArrayMesh.new()
	mdt.commit_to_surface(am2)
	am2.surface_set_material(0, mat)
	return am2

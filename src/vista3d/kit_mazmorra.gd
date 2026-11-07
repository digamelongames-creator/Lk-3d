class_name KitMazmorra
## Las piezas con las que se monta la mazmorra en el GridMap (un MeshLibrary).
##
## Si existe res://assets/kit/mazmorra.meshlib se usa ese (tu kit 3D de verdad: Blender, KayKit, Synty…).
## Si no, se fabrica uno provisional con cajas y cilindros para poder jugar ya.
##
## Para meter tu kit: crea una escena con un MeshInstance3D por pieza, ponle a cada uno el NOMBRE de la
## tabla PIEZAS, y en el editor: Escena > Exportar como… > MeshLibrary → res://assets/kit/mazmorra.meshlib.
## Medidas: cada casilla mide CELDA × CELDA metros, con el suelo a la altura 0 y la pieza centrada en la casilla.

const RUTA_KIT := "res://assets/kit/mazmorra.meshlib"
const CELDA := 2.0      # metros por casilla (una casilla de la simulación = 32 px)
const ALTO_MURO := 3.0

## nombre de pieza → para qué sirve
const PIEZAS := {
	"suelo": "losa de suelo de una casilla",
	"suelo_sala": "suelo de las salas (variante)",
	"muro": "bloque de muro que ocupa la casilla entera",
	"agua": "canal de agua (más bajo que el suelo)",
	"puente": "pasarela de madera sobre agua o abismo",
	"pilar": "columna",
	"tumba": "lápida o sarcófago",
	"escombro": "montón de piedras (se puede pisar)",
	"mueble": "mueble sólido del decorador",
	"escalera_baja": "escalera de bajada al piso siguiente",
	"escalera_sube": "escalera por la que se llega",
}

static var _lib: MeshLibrary

static func cargar() -> MeshLibrary:
	if _lib != null:
		return _lib
	if ResourceLoader.exists(RUTA_KIT):
		_lib = load(RUTA_KIT)
	else:
		_lib = _provisional()
	return _lib

static func id(nombre: String) -> int:
	return cargar().find_item_by_name(nombre)

# ---------- kit provisional ----------
static func _provisional() -> MeshLibrary:
	var lib := MeshLibrary.new()
	var piedra := _mat_piedra(Color(.30, .28, .27), .9)
	var piedra_sala := _mat_piedra(Color(.36, .33, .30), .85)
	_add(lib, "suelo", _caja(Vector3(CELDA, .2, CELDA), piedra), Vector3(0, -.1, 0))
	_add(lib, "suelo_sala", _caja(Vector3(CELDA, .2, CELDA), piedra_sala), Vector3(0, -.1, 0))
	_add(lib, "muro", _caja(Vector3(CELDA, ALTO_MURO, CELDA), material_muro()), Vector3(0, ALTO_MURO / 2, 0))
	var agua := StandardMaterial3D.new()
	agua.albedo_color = Color(.05, .12, .16)
	agua.roughness = .05
	agua.metallic = .3
	_add(lib, "agua", _caja(Vector3(CELDA, .1, CELDA), agua), Vector3(0, -.45, 0))
	var madera := _mat_piedra(Color(.32, .20, .11), .8)
	_add(lib, "puente", _caja(Vector3(CELDA, .15, CELDA * .8), madera), Vector3(0, -.05, 0))
	var cil := CylinderMesh.new()
	cil.top_radius = .45
	cil.bottom_radius = .55
	cil.height = ALTO_MURO
	cil.material = _mat_piedra(Color(.42, .39, .35), .8)
	_add(lib, "pilar", cil, Vector3(0, ALTO_MURO / 2, 0))
	_add(lib, "tumba", _caja(Vector3(1.0, .7, 1.7), _mat_piedra(Color(.40, .40, .42), .9)), Vector3(0, .35, 0))
	var esc := PrismMesh.new()
	esc.size = Vector3(1.4, .35, 1.4)
	esc.material = piedra
	_add(lib, "escombro", esc, Vector3(0, .17, 0))
	_add(lib, "mueble", _caja(Vector3(1.4, .8, .8), madera), Vector3(0, .4, 0))
	var brasa := StandardMaterial3D.new()
	brasa.albedo_color = Color(.08, .02, .02)
	brasa.emission_enabled = true
	brasa.emission = Color(1, .35, .1)
	brasa.emission_energy_multiplier = 2.5
	_add(lib, "escalera_baja", _caja(Vector3(CELDA * .9, .05, CELDA * .9), brasa), Vector3(0, .01, 0))
	_add(lib, "escalera_sube", _caja(Vector3(CELDA * .9, .3, CELDA * .9), piedra_sala), Vector3(0, .15, 0))
	return lib

static func _add(lib: MeshLibrary, nombre: String, m: Mesh, desplaza: Vector3) -> void:
	var i := lib.get_last_unused_item_id()
	lib.create_item(i)
	lib.set_item_name(i, nombre)
	lib.set_item_mesh(i, m)
	lib.set_item_mesh_transform(i, Transform3D(Basis.IDENTITY, desplaza))

static func _caja(t: Vector3, mat: Material) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = t
	b.material = mat
	return b

static func _mat_piedra(c: Color, rugosidad: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugosidad
	var n := FastNoiseLite.new()
	n.frequency = .08
	var tx := NoiseTexture2D.new()
	tx.noise = n
	tx.seamless = true
	tx.width = 128
	tx.height = 128
	m.albedo_texture = tx
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(.5, .5, .5)
	var nm := NoiseTexture2D.new()
	nm.noise = n
	nm.seamless = true
	nm.as_normal_map = true
	nm.bump_strength = 6.0
	m.normal_enabled = true
	m.normal_texture = nm
	return m

## muro que se vuelve transparente (tramado) cuando tapa al héroe, como en Diablo 4.
## Usa los parámetros globales pos_heroe y dir_camara (project.godot > shader_globals), que actualiza Main3D cada fotograma.
static func material_muro() -> ShaderMaterial:
	var s := Shader.new()
	s.code = """
shader_type spatial;
global uniform vec3 pos_heroe;
global uniform vec2 dir_camara;
uniform vec3 color : source_color = vec3(.27, .25, .24);
uniform sampler2D ruido : hint_default_white;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	// tapa al héroe si está entre él y la cámara (dir_camara: del héroe hacia la cámara, en el suelo)
	vec2 r = vec2(wp.x - pos_heroe.x, wp.z - pos_heroe.z);
	float hacia = dot(r, dir_camara);
	float de_lado = dot(r, vec2(dir_camara.y, -dir_camara.x));
	float delante = smoothstep(-.5, 1.0, hacia) * (1.0 - smoothstep(5.0, 8.0, hacia));
	float lado = 1.0 - smoothstep(2.0, 4.0, abs(de_lado));
	float alto = smoothstep(.3, 1.0, wp.y);
	float corte = delante * lado * alto * .85;
	float tramado = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
	if (tramado < corte) discard;
	float n = texture(ruido, wp.xz * .25 + wp.yy * .3).r;
	ALBEDO = color * (.75 + n * .5);
	ROUGHNESS = .9;
}
"""
	var m := ShaderMaterial.new()
	m.shader = s
	var n := FastNoiseLite.new()
	n.frequency = .05
	var tx := NoiseTexture2D.new()
	tx.noise = n
	tx.seamless = true
	m.set_shader_parameter("ruido", tx)
	return m

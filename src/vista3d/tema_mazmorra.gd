class_name TemaMazmorra
## TemaMazmorra de la mazmorra: cada piso se viste con sus texturas, su luz y su niebla sin tocar el mapa.
## Las texturas son de Pixmith (ChatGPT desde el PC de Diego) pasadas por tools/texturas.py
## (color, relieve, rugosidad y lo que brilla) en assets/texturas/<tema>/.
##
## Inframundo: pisos 8–9 (pasarelas sobre lava) y el «Piso de prueba 7». Galerías hundidas: solo el «Piso de prueba 3»
## (pasarelas sobre un abismo de niebla azul con cascadas de agua). El piso de prueba lo pone en L.tema3d.
## Qué cambia: el suelo pasa a ser una losa lisa con la textura (la textura ya trae las piedras),
## los muros llevan la roca con vetas que brillan, el agua de los canales es lava, el abismo
## es un mar de lava con cascadas (Abismo3D) y el entorno pasa a rojo y naranja.

const RUTA := "res://assets/texturas/"

const TEMAS := {
	"inframundo": {
		"nombre": "Inframundo",
		"pisos": [8, 9],
		"suelo": "inframundo/suelo", "roca": "inframundo/roca", "lava": "inframundo/lava",
		"suelo_m": 4.0,              # metros que ocupa una vez la textura del suelo
		"roca_m": 3.5,
		"tinte_muro": Color(.95, .88, .85),
		"brillo": Color(1.0, .36, .07),   # color de las grietas y vetas
		"brillo_e": 2.6,                  # fuerza (más de 1,3 hace resplandor)
		"antorcha": Color(1.0, .46, .2),
		"abismo": "lava",                 # qué hay en el vacío: «lava» (mar de lava) o «agua» (niebla y cascadas de agua)
		"lava_y": -5.5,                   # m bajo el suelo donde está el mar de lava
		"entorno": {
			"bg": Color(.03, .008, .004),
			"amb": Color(.75, .36, .26), "amb_e": .42,
			"niebla_vol": .014, "niebla_vol_c": Color(1.0, .52, .32),
			"niebla_alt_c": Color(.32, .07, .02),   # lo que queda bajo el suelo se tiñe de rojo
			"saturacion": 1.05,
		},
	},
	## Galerías hundidas (pisos 3–5): puentes de sillería sobre un abismo de niebla azul con cascadas de agua,
	## piedra mojada con musgo y fuego azul. De momento solo el «Piso de prueba 3» (pisos vacío).
	"galerias": {
		"nombre": "Galerías hundidas",
		"pisos": [],
		"abismo": "agua",
		"suelo": "galerias/suelo", "muro": "galerias/muro", "roca": "galerias/roca", "agua": "galerias/agua",
		"suelo_m": 4.0,
		"muro_m": 3.0,               # sillería de los muros (la roca del abismo es «roca»)
		"roca_m": 4.5,
		"tinte_muro": Color(.92, .96, 1.0),
		"brillo": Color(.3, .85, 1.0),
		"brillo_e": 0.0,                  # sin vetas que brillen
		"antorcha": Color(.35, .78, 1.0), # fuego azul
		"luz_abismo": Color(.35, .8, 1.0), "luz_abismo_e": 1.6,
		"niebla_abismo": Color(.32, .7, .82),
		"entorno": {
			"bg": Color(.008, .02, .03),
			"amb": Color(.4, .58, .72), "amb_e": .4,
			"niebla_vol": .012, "niebla_vol_c": Color(.55, .82, .95),
			"niebla_alt_c": Color(.04, .16, .22),   # lo que queda bajo el suelo se funde en niebla azul
			"saturacion": 1.0,
		},
	},
}

static var _mats := {}
static var _antes := {}

## el tema de un piso: el que lleve puesto (pisos de prueba) o el de su oleada; Inca no tiene
static func de(L: Dictionary) -> String:
	var t := String(L.get("tema3d", ""))
	if TEMAS.has(t):
		return t
	if L.has("ciudad") or L.has("salas_prueba") or L.get("wave") == null:
		return ""
	for k in TEMAS:
		if int(L.wave) in TEMAS[k].get("pisos", []):
			return k
	return ""

static func hay(t: String) -> bool:
	return TEMAS.has(t)

static func dato(t: String, clave: String, si_no = null):
	return TEMAS.get(t, {}).get(clave, si_no)

static func nombre(t: String) -> String:
	return String(dato(t, "nombre", ""))

## qué hay en el vacío de los pisos de pasarelas: "lava", "agua" o "" (la niebla gris de siempre)
static func abismo(t: String) -> String:
	return String(dato(t, "abismo", ""))

## la textura de los muros de las salas: «muro» si el tema la tiene; si no, la roca
static func clave_muro(t: String) -> String:
	return "muro" if dato(t, "muro") != null else "roca"

## una capa de una textura del tema: color, normal, rugosidad o brillo (null si no está)
static func tex(t: String, clave: String, capa: String) -> Texture2D:
	var r := RUTA + String(dato(t, clave, "")) + "_" + capa + ".webp"
	return load(r) if ResourceLoader.exists(r) else null

## vaciar al salir (ver KitMazmorra.limpiar)
static func limpiar() -> void:
	_mats.clear()

# ---------------------------------------------------------------- materiales
static func _pbr(t: String, clave: String, metros: float, cull_no: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(t, clave, "color")
	var n := tex(t, clave, "normal")
	if n != null:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = 1.3
	var r := tex(t, clave, "rugosidad")
	if r != null:
		m.roughness_texture = r
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	var b := tex(t, clave, "brillo")
	if b != null:
		m.emission_enabled = true
		m.emission = dato(t, "brillo", Color.ORANGE)
		m.emission_texture = b
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY   # solo brilla lo que marca la máscara (con ADD brillaba todo)
		m.emission_energy_multiplier = float(dato(t, "brillo_e", 2.0))
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / metros
	if cull_no:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func material_suelo(t: String) -> StandardMaterial3D:
	if not _mats.has("suelo|" + t):
		_mats["suelo|" + t] = _pbr(t, "suelo", float(dato(t, "suelo_m", 4.0)))
	return _mats["suelo|" + t]

## la roca de los muros (sin tramado: para piezas sueltas) y de las paredes del abismo
static func material_roca(t: String) -> StandardMaterial3D:
	if not _mats.has("roca|" + t):
		var m := _pbr(t, "roca", float(dato(t, "roca_m", 3.0)), true)
		m.vertex_color_use_as_albedo = true
		_mats["roca|" + t] = m
	return _mats["roca|" + t]

## lava: la textura corre despacio en dos capas que se cruzan y brilla mucho (no le afecta la niebla)
static func material_lava(t: String, cae: bool = false) -> ShaderMaterial:
	var k := ("cascada|" if cae else "lava|") + t
	if _mats.has(k):
		return _mats[k]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, fog_disabled%s;
uniform sampler2D lava : source_color, repeat_enable, filter_linear_mipmap;
uniform float metros = 6.0;
uniform vec2 corre = vec2(.025, .012);
uniform float fuerza = 2.4;
uniform bool cae = false;
varying vec3 mundo;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv;
	vec2 d = corre;
	if (cae) {
		// cascada: corre hacia abajo, más deprisa, y se estira
		uv = vec2(UV.x * .5, UV.y * 1.6);
		d = vec2(0.0, -.35);
	} else {
		uv = mundo.xz / metros;
	}
	vec3 a = texture(lava, uv + TIME * d).rgb;
	vec3 b = texture(lava, uv * 1.37 + vec2(.31, .77) - TIME * d.yx * .8).rgb;
	vec3 c = max(a, b * .9);
	float l = dot(c, vec3(.3, .55, .15));
	// lo encendido brilla (más de 1,3: resplandor); la costra se queda oscura
	ALBEDO = c * mix(.6, fuerza, smoothstep(.35, .8, l));
	if (cae) {
		float borde = smoothstep(0.0, .18, UV.x) * smoothstep(1.0, .82, UV.x);
		ALPHA = borde * smoothstep(1.0, .9, UV.y);
	}
}
""" % (", cull_disabled, depth_draw_never" if cae else "")
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("lava", tex(t, "lava", "color"))
	m.set_shader_parameter("cae", cae)
	_mats[k] = m
	return m

## agua (Galerías hundidas): la textura corre en dos capas y la espuma brilla un poco; en las cascadas cae
## deprisa y se deshace por los lados. Le afecta la niebla, así que lo hondo se pierde en el azul.
static func material_agua(t: String, cae: bool = false) -> ShaderMaterial:
	var k := ("cascada_agua|" if cae else "agua|") + t
	if _mats.has(k):
		return _mats[k]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded%s;
uniform sampler2D agua : source_color, repeat_enable, filter_linear_mipmap;
uniform float metros = 5.0;
uniform vec2 corre = vec2(.04, .02);
uniform float espuma = 1.5;
uniform bool cae = false;
varying vec3 mundo;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv;
	vec2 d = corre;
	if (cae) {
		uv = vec2(UV.x * .5, UV.y * 1.4);
		d = vec2(0.0, -.6);
	} else {
		uv = mundo.xz / metros;
	}
	vec3 a = texture(agua, uv + TIME * d).rgb;
	vec3 b = texture(agua, uv * 1.31 + vec2(.27, .61) - TIME * d.yx * .7).rgb;
	vec3 c = max(a, b * .9);
	float l = dot(c, vec3(.3, .55, .15));
	// el agua honda queda oscura; la espuma brilla algo (más de 1,3 hace resplandor)
	ALBEDO = c * mix(.45, espuma, smoothstep(.5, .9, l));
	if (cae) {
		float borde = smoothstep(0.0, .2, UV.x) * smoothstep(1.0, .8, UV.x);
		ALPHA = borde * mix(.55, 1.0, l) * smoothstep(1.0, .75, UV.y);
	}
}
""" % (", blend_mix, cull_disabled, depth_draw_never" if cae else "")
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("agua", tex(t, "agua", "color"))
	m.set_shader_parameter("cae", cae)
	_mats[k] = m
	return m

## el líquido de los canales y cascadas del tema (agua o lava)
static func material_liquido(t: String, cae: bool = false) -> ShaderMaterial:
	return material_agua(t, cae) if abismo(t) == "agua" else material_lava(t, cae)

# ---------------------------------------------------------------- entorno
## pone el entorno del tema (o lo deja como estaba si t == "")
static func ambiente(e: Environment, t: String) -> void:
	if t != "" and hay(t):
		if _antes.is_empty():
			_antes = {"bg": e.background_color, "amb": e.ambient_light_color, "amb_e": e.ambient_light_energy,
				"nv": e.volumetric_fog_density, "nvc": e.volumetric_fog_albedo, "nac": e.fog_light_color,
				"sat": e.adjustment_saturation}
		var d: Dictionary = dato(t, "entorno", {})
		e.background_color = d.bg
		e.ambient_light_color = d.amb
		e.ambient_light_energy = d.amb_e
		e.volumetric_fog_density = d.niebla_vol
		e.volumetric_fog_albedo = d.niebla_vol_c
		e.fog_light_color = d.niebla_alt_c
		e.adjustment_saturation = d.saturacion
	elif not _antes.is_empty():
		e.background_color = _antes.bg
		e.ambient_light_color = _antes.amb
		e.ambient_light_energy = _antes.amb_e
		e.volumetric_fog_density = _antes.nv
		e.volumetric_fog_albedo = _antes.nvc
		e.fog_light_color = _antes.nac
		e.adjustment_saturation = _antes.sat
		_antes.clear()

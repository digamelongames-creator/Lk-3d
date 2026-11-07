class_name Armadura3D
extends RefCounted
## Armadura visible del héroe: cada pieza del equipo se cuelga de un hueso de Mixamo (BoneAttachment3D
## de Modelo3D.enganche) y sigue la animación. También da la pieza suelta para el botín del suelo.
##
## Modelos: si existe res://assets/armaduras/<archivo>.glb se usa ese (los que salgan de
## C:\SPRITE_FACTORY\armaduras); si no, una pieza provisional hecha con primitivas.
## Guantes, botas y hombreras: un solo modelo (el derecho); el izquierdo sale en espejo.
##
## Aura según la calidad (Items.RQ_C): básico sin aura; mágico, dorado y legendario con brillo de
## borde (fresnel) que late; dorado y legendario, además, chispas que suben.

## hueco del equipo → piezas: archivo, hueso, lado (1 derecho, -1 izquierdo en espejo)
const PIEZAS := {
	"helm":   [{"archivo": "casco", "hueso": "Head", "lado": 1}],
	"chest":  [{"archivo": "peto", "hueso": "Spine2", "lado": 1},
			   {"archivo": "hombrera", "hueso": "RightShoulder", "lado": 1},
			   {"archivo": "hombrera", "hueso": "LeftShoulder", "lado": -1}],
	"gloves": [{"archivo": "guante", "hueso": "RightHand", "lado": 1},
			   {"archivo": "guante", "hueso": "LeftHand", "lado": -1}],
	"belt":   [{"archivo": "cinturon", "hueso": "Hips", "lado": 1}],
	"boots":  [{"archivo": "bota", "hueso": "RightFoot", "lado": 1},
			   {"archivo": "bota", "hueso": "LeftFoot", "lado": -1}],
}
## ajuste fino de cada modelo sobre su hueso (en metros y grados), para cuando lleguen los .glb
const AJUSTE := {
	"casco": {"pos": Vector3(0, .1, .01), "rot": Vector3.ZERO, "esc": 1.0},
	"peto": {"pos": Vector3(0, .02, .02), "rot": Vector3.ZERO, "esc": 1.0},
	"hombrera": {"pos": Vector3(0, .1, 0), "rot": Vector3.ZERO, "esc": 1.0},
	"guante": {"pos": Vector3(0, .04, 0), "rot": Vector3.ZERO, "esc": 1.0},
	"cinturon": {"pos": Vector3(0, .04, 0), "rot": Vector3.ZERO, "esc": 1.0},
	"bota": {"pos": Vector3(0, .02, 0), "rot": Vector3.ZERO, "esc": 1.0},
}
## color base del metal de las piezas provisionales
const METAL := Color(.42, .43, .47)

static var _escenas := {}
static var _aura_shader: Shader

static func limpiar() -> void:
	_escenas.clear()
	_aura_shader = null

static func huecos() -> Array:
	return PIEZAS.keys()

## viste el modelo con el equipo; devuelve los nodos creados (para soltarlos al cambiar)
static func vestir(modelo: Modelo3D, eq: Dictionary) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for s in PIEZAS:
		var it = eq.get(s)
		if it == null:
			continue
		for d in PIEZAS[s]:
			var n := pieza(d.archivo, it)
			if int(d.lado) < 0:
				n.scale.x *= -1
			modelo.enganche(d.hueso).add_child(n)
			out.append(n)
	return out

## una pieza (con su ajuste, su color y su aura) en metros, relativa al hueso
static func pieza(archivo: String, it) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "pieza_" + archivo
	var aj: Dictionary = AJUSTE.get(archivo, {"pos": Vector3.ZERO, "rot": Vector3.ZERO, "esc": 1.0})
	var cuerpo := _cargar(archivo)
	cuerpo.position = aj.pos
	cuerpo.rotation_degrees = aj.rot
	cuerpo.scale *= float(aj.esc)
	raiz.add_child(cuerpo)
	var q := clampi(int(it.get("q", 0)), 0, 3) if it != null else 0
	if q > 0:
		var col := Color(Items.RQ_C[q])
		var aura := _aura(col, q)
		for mi in _mallas(cuerpo):
			mi.material_overlay = aura
		if q >= 2:
			raiz.add_child(_chispas(col, .12 if archivo in ["peto", "casco"] else .07))
	return raiz

## la pieza para el botín del suelo: tumbada y algo más grande para que se vea desde la cámara
static func suelta(it) -> Node3D:
	var s: String = it.get("slot", "")
	if not PIEZAS.has(s):
		return null
	var n := Node3D.new()
	var p := pieza(PIEZAS[s][0].archivo, it)
	p.rotation_degrees = Vector3(-90 if s in ["chest", "belt"] else 0, 0, 0)
	p.scale = Vector3.ONE * 1.3
	n.add_child(p)
	return n

# ---------- modelos ----------
static func _cargar(archivo: String) -> Node3D:
	var ruta := "res://assets/armaduras/%s.glb" % archivo
	if ResourceLoader.exists(ruta):
		if not _escenas.has(ruta):
			_escenas[ruta] = load(ruta)
		var esc: Node3D = (_escenas[ruta] as PackedScene).instantiate()
		for mi in _mallas(esc):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		return esc
	return _provisional(archivo)

## piezas provisionales con primitivas (ejes del hueso de Mixamo: +Y a lo largo del hueso, +Z delante)
static func _provisional(archivo: String) -> Node3D:
	var n := Node3D.new()
	match archivo:
		"casco":
			var cup := SphereMesh.new()
			cup.radius = .15
			cup.height = .15
			cup.is_hemisphere = true
			n.add_child(_malla(cup, Vector3.ZERO))
			var ala := CylinderMesh.new()
			ala.top_radius = .165
			ala.bottom_radius = .165
			ala.height = .03
			n.add_child(_malla(ala, Vector3(0, -.01, 0)))
			var nasal := BoxMesh.new()
			nasal.size = Vector3(.025, .12, .02)
			n.add_child(_malla(nasal, Vector3(0, -.06, .155)))
		"peto":
			var c := CapsuleMesh.new()
			c.radius = .17
			c.height = .42
			var mi := _malla(c, Vector3.ZERO)
			mi.scale = Vector3(1.05, 1, .72)
			n.add_child(mi)
		"hombrera":
			var h := SphereMesh.new()
			h.radius = .1
			h.height = .1
			h.is_hemisphere = true
			var mi2 := _malla(h, Vector3(.04, 0, 0))
			mi2.rotation_degrees = Vector3(0, 0, -70)
			mi2.scale = Vector3(1, 1, 1.2)
			n.add_child(mi2)
		"guante":
			var g := BoxMesh.new()
			g.size = Vector3(.1, .12, .07)
			n.add_child(_malla(g, Vector3.ZERO))
			var pu := CylinderMesh.new()
			pu.top_radius = .06
			pu.bottom_radius = .075
			pu.height = .08
			n.add_child(_malla(pu, Vector3(0, -.08, 0)))
		"cinturon":
			var t := TorusMesh.new()
			t.inner_radius = .15
			t.outer_radius = .19
			var mi3 := _malla(t, Vector3.ZERO)
			mi3.scale = Vector3(1, 1.6, .8)
			n.add_child(mi3)
			var hebilla := BoxMesh.new()
			hebilla.size = Vector3(.07, .06, .03)
			n.add_child(_malla(hebilla, Vector3(0, 0, .16), Color(.75, .6, .25)))
		"bota":
			var cana := CylinderMesh.new()
			cana.top_radius = .07
			cana.bottom_radius = .065
			cana.height = .2
			n.add_child(_malla(cana, Vector3(0, -.06, 0)))
			var pie := BoxMesh.new()
			pie.size = Vector3(.1, .18, .08)
			n.add_child(_malla(pie, Vector3(0, .07, -.02)))
	return n

static func _malla(m: PrimitiveMesh, pos: Vector3, col: Color = METAL) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = .85
	mat.roughness = .35
	m.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi

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
uniform float potencia = 2.2;
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
	m.set_shader_parameter("fuerza", [0.0, 1.3, 1.8, 2.3][q])
	m.set_shader_parameter("base", [0.0, .05, .1, .15][q])
	return m

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

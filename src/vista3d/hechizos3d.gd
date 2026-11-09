class_name Hechizos3D
extends Node3D
## Efectos de las magias con hojas de fotogramas (assets/vfx/<hoja>.png + .json, hechas con
## tools/vfx_hoja.py a partir de lo que sale de ChatGPT, sobre fondo negro).
##
## Qué es cada efecto lo dice el catálogo (assets/vfx/catalogo.json), una ficha por efecto:
##   hoja, reserva (hoja a usar si aún no está la buena), forma, tam (m; en «suelo», veces el diámetro
##   de la habilidad), brillo, velocidad (× fps de la hoja), alto (m sobre el suelo), bucle, giro (rad/s, suelo),
##   cabeza (proyectil: dónde está la punta), luz (color, "" sin luz), luz_energia, luz_alcance, sonido,
##   al_acabar (efecto que sale donde acaba) y pegado (efecto que sale sobre cada enemigo afectado).
## Formas: proyectil (de cara a la cámara y girado hacia donde vuela), golpe (de cara a la cámara, una vez),
##   suelo (tumbado en el suelo) y aura (de cara a la cámara, siguiendo a alguien).
## Añadir un efecto con una forma que ya existe = una ficha nueva, sin programar. Lo que sí es código es
## el «enganche»: qué mira de la simulación para saber cuándo sale (ver _enganches()).
## El panel de ajuste (PanelEfectos, F4 en el piso de prueba) cambia las fichas en vivo y las guarda.
## La simulación no cambia: esto solo mira y pinta.

var sim: Sim
var camara: Camera3D

const RUTA_CATALOGO := "res://assets/vfx/catalogo.json"
const ALTO_BOLA := 20.0      # px: la bola de fuego sale a la altura del pecho (como en la simulación)

var _vivos: Array = []       # {id, nodo, luz, t, pos, dir, base, seguir (Callable → Vector3 o null), dur, fin}
var _malla: QuadMesh
var _nova = null             # efecto vivo de la nova
var _llamarada_antes := false
var _heroe_antes = null      # posición del héroe en el fotograma anterior (teletransporte)

# ======================================================================
#  catálogo y hojas (caché estática; se suelta con limpiar())
# ======================================================================
static var _cat := {}
static var _hojas := {}
static var _material: ShaderMaterial

static func catalogo() -> Dictionary:
	if _cat.is_empty():
		var f := FileAccess.open(RUTA_CATALOGO, FileAccess.READ)
		if f != null:
			var j = JSON.parse_string(f.get_as_text())
			if j is Dictionary:
				_cat = j
	return _cat

static func ficha(id: String) -> Dictionary:
	return catalogo().get(id, {})

## guarda el catálogo como está ahora (lo que se ha tocado con el panel). Devuelve "" o el error.
static func guardar_catalogo() -> String:
	var f := FileAccess.open(RUTA_CATALOGO, FileAccess.WRITE)
	if f == null:
		return "no se puede escribir %s (%s)" % [RUTA_CATALOGO, error_string(FileAccess.get_open_error())]
	# una línea por ficha, en el orden de siempre, para que los cambios se lean bien en git
	var lineas := []
	for k in _cat:
		lineas.append(" %s: %s" % [JSON.stringify(k), JSON.stringify(_cat[k], "", false)])
	f.store_string("{\n" + ",\n".join(lineas) + "\n}\n")
	return ""

static func hoja(nombre: String) -> Dictionary:
	if _hojas.has(nombre):
		return _hojas[nombre]
	var h := {"tex": null, "cols": 4, "filas": 4, "fotogramas": 16, "fps": 20.0, "bucle": false}
	var ruta := "res://assets/vfx/%s.png" % nombre
	if ResourceLoader.exists(ruta):
		h.tex = load(ruta)
	var f := FileAccess.open("res://assets/vfx/%s.json" % nombre, FileAccess.READ)
	if f != null:
		var j = JSON.parse_string(f.get_as_text())
		if j is Dictionary:
			h.merge(j, true)
	_hojas[nombre] = h
	return h

## la hoja de una ficha: la suya o, si aún no está, la de reserva
static func hoja_de(d: Dictionary) -> Dictionary:
	var h := hoja(String(d.get("hoja", "")))
	if h.tex == null and String(d.get("reserva", "")) != "":
		h = hoja(String(d.reserva))
	return h

static func limpiar() -> void:
	_hojas.clear()
	_cat.clear()
	_material = null

static func _mat() -> ShaderMaterial:
	if _material != null:
		return _material
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform sampler2D hoja : source_color, filter_linear_mipmap;
uniform vec2 rejilla = vec2(4.0, 4.0);
instance uniform float fotograma = 0.0;
instance uniform float intensidad = 1.0;
void fragment() {
	float f = floor(fotograma);
	vec2 celda = vec2(mod(f, rejilla.x), floor(f / rejilla.x));
	vec4 c = texture(hoja, (celda + UV) / rejilla);
	ALBEDO = c.rgb * c.a * intensidad * 1.6;
}"""
	_material = ShaderMaterial.new()
	_material.shader = sh
	return _material

# ======================================================================
#  crear efectos
# ======================================================================
## Saca el efecto «id» del catálogo en pos (m). Opciones: base (tamaño de referencia en m: el diámetro
## de la habilidad en «suelo»; 1 si no), dir (hacia dónde vuela), seguir (Callable que da la posición
## cada fotograma, o null para acabar), dur (s, para los que van en bucle sin seguir a nada), mudo.
## Devuelve el efecto (o {} si la ficha o su hoja no están).
func efecto(id: String, pos: Vector3, op: Dictionary = {}) -> Dictionary:
	var d := ficha(id)
	if d.is_empty():
		return {}
	var h := hoja_de(d)
	if h.tex == null:
		return {}
	var n := MeshInstance3D.new()
	if _malla == null:
		_malla = QuadMesh.new()
	n.mesh = _malla
	if not h.has("mat"):
		var mat: ShaderMaterial = _mat().duplicate()
		mat.set_shader_parameter("hoja", h.tex)
		mat.set_shader_parameter("rejilla", Vector2(h.cols, h.filas))
		h.mat = mat
	n.material_override = h.mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	var l: OmniLight3D = null
	if String(d.get("luz", "")) != "" and float(d.get("luz_energia", 0)) > 0:
		l = OmniLight3D.new()
		l.light_color = Color(String(d.luz))
		l.omni_attenuation = 1.6
		l.shadow_enabled = false
		add_child(l)
	var e := {"id": id, "nodo": n, "luz": l, "t": randf() * 2.0 if d.get("bucle", false) else 0.0, "pos": pos,
		"dir": op.get("dir", Vector3.ZERO), "base": float(op.get("base", 1.0)), "seguir": op.get("seguir", null),
		"dur": float(op.get("dur", INF)), "fin": false, "giro0": randf() * TAU}
	_vivos.append(e)
	if String(d.get("sonido", "")) != "" and not op.get("mudo", false):
		_sonido(StringName(d.sonido), pos)
	_poner(e, 0.0)
	return e

func reset() -> void:
	for e in _vivos:
		_soltar(e)
	_vivos.clear()
	_nova = null
	_llamarada_antes = false
	_heroe_antes = null

func _exit_tree() -> void:
	_malla = null   # los efectos son hijos: se van con el nodo

func _soltar(e: Dictionary) -> void:
	if is_instance_valid(e.nodo):
		e.nodo.free()
	if e.luz != null and is_instance_valid(e.luz):
		e.luz.free()

## cuántos efectos hay vivos (pruebas)
func vivos(id: String = "") -> int:
	return _vivos.filter(func(e): return id == "" or e.id == id).size()

# ======================================================================
#  cada fotograma
# ======================================================================
func actualizar(dt: float) -> void:
	if sim == null or camara == null:
		return
	if sim.cls != null and sim.p != null:
		_enganches()
	for e in _vivos.duplicate():
		_poner(e, dt)
	for e in _vivos.duplicate():
		if e.fin:
			var sig := String(ficha(e.id).get("al_acabar", ""))
			if sig != "":
				efecto(sig, e.pos + e.dir * .3)
			_soltar(e)
	_vivos = _vivos.filter(func(e): return not e.fin)

func _poner(e: Dictionary, dt: float) -> void:
	var d := ficha(e.id)
	var h := hoja_de(d)
	e.t += dt
	if e.seguir != null:
		var p = (e.seguir as Callable).call()
		if p == null:
			e.fin = true
			return
		e.pos = p
	var n := float(h.fotogramas)
	var fr: float = e.t * float(h.fps) * float(d.get("velocidad", 1.0))
	var bucle: bool = d.get("bucle", h.get("bucle", false))
	var avance := 0.0   # 0..1 de los que salen una vez (para apagar la luz)
	if bucle:
		fr = fmod(fr, n)
		if e.seguir == null and e.t >= e.dur:
			e.fin = true
	else:
		avance = fr / n
		if fr >= n:
			e.fin = true
			return
	var nodo: MeshInstance3D = e.nodo
	nodo.set_instance_shader_parameter("fotograma", fr)
	nodo.set_instance_shader_parameter("intensidad", float(d.get("brillo", 1.0)))
	var lado: float = float(d.get("tam", 1.0)) * e.base
	var alto := float(d.get("alto", 0.0))
	match String(d.get("forma", "golpe")):
		"proyectil":
			var adelante := _de_cara(nodo, e.dir, lado)
			# la punta del dibujo (no su centro) va donde está lo que vuela
			nodo.global_position = e.pos + Vector3(0, alto, 0) - adelante * float(d.get("cabeza", .33)) * lado
		"suelo":
			var g: float = e.giro0 + e.t * float(d.get("giro", 0.0))
			nodo.global_transform = Transform3D(Basis(Vector3.UP, g) * Basis(Vector3.RIGHT, -PI / 2) * Basis.from_scale(Vector3.ONE * lado),
				e.pos + Vector3(0, maxf(alto, .03), 0))
		_:   # golpe y aura
			_de_cara(nodo, Vector3.ZERO, lado)
			nodo.global_position = e.pos + Vector3(0, alto, 0)
	if e.luz != null:
		var l: OmniLight3D = e.luz
		l.global_position = e.pos + Vector3(0, maxf(alto, .5), 0)
		l.omni_range = float(d.get("luz_alcance", 5.0))
		var en := float(d.get("luz_energia", 0.0))
		l.light_energy = en * (1.0 + sin(e.t * 23.0) * .18) if bucle else en * pow(1.0 - clampf(avance, 0, 1), 2.2)

## de cara a la cámara; con dirección, el dibujo (que mira a +X) se gira hacia ella en pantalla.
## Devuelve hacia dónde apunta el dibujo, en el mundo.
func _de_cara(n: MeshInstance3D, dir: Vector3, lado: float) -> Vector3:
	var z := camara.global_transform.basis.z.normalized()
	var x := camara.global_transform.basis.x.normalized()
	if dir.length() > .01:
		var dd := dir - z * dir.dot(z)
		if dd.length() > .001:
			x = dd.normalized()
	var y := z.cross(x).normalized()
	n.global_transform.basis = Basis(x * lado, y * lado, z * lado)
	return x

func _sonido(id: StringName, pos: Vector3) -> void:
	if sim != null and sim.fx is Fx3D:
		var px := MazmorraGridMap.a_px(pos)
		(sim.fx as Fx3D).sonido(id, px.x, px.y)

# ======================================================================
#  enganches: cuándo sale cada efecto (mirando la simulación)
# ======================================================================
func _enganches() -> void:
	var C: Clases = sim.cls
	var p := sim.p
	# bola de fuego: vuela mientras exista; al desaparecer, «al_acabar» (la explosión)
	for f in C.fballs:
		if f.has("v3d"):
			continue
		f["v3d"] = true
		var ff: Dictionary = f
		efecto("bola_fuego", MazmorraGridMap.a3d(f.x, f.y + ALTO_BOLA), {"dir": Vector3(f.vx, 0, f.vy).normalized(),
			"seguir": func():
				return null if ff.get("dead", false) or not C.fballs.has(ff) else MazmorraGridMap.a3d(ff.x, ff.y + ALTO_BOLA)})
	# explosión del clic izquierdo: cuando estalla
	for a in C.aoes:
		if a.boom > 0 and not a.has("v3d"):
			a["v3d"] = true
			efecto("mago_estallido", MazmorraGridMap.a3d(a.x, a.y))
	# nova ígnea: un anillo en el suelo mientras dure (sigue a su centro)
	if sim.skill_on_id("nova") and (_nova == null or _nova.fin):
		var NR := sim.skp("nova", "r")
		_nova = efecto("mago_nova", _centro_nova(), {"base": NR * 2 * MazmorraGridMap.PX_M,
			"seguir": func(): return _centro_nova() if sim.skill_on_id("nova") else null})
		if _nova.is_empty():
			_nova = null
	# llamarada: la onda al lanzarla y llamas sobre cada enemigo aturdido
	var llama := sim.skill_on_id("freeze")
	if llama and not _llamarada_antes:
		efecto("mago_llamarada", MazmorraGridMap.a3d(p.x, p.y), {"base": sim.skp("freeze", "r") * 2 * MazmorraGridMap.PX_M})
	_llamarada_antes = llama
	var pegado := String(ficha("mago_llamarada").get("pegado", ""))
	if pegado != "":
		for e: Ent.Enemy in sim.enemies:
			if e.frozen > 0 and not e.dying and not e.get_meta("v3d_llamas", false):
				e.set_meta("v3d_llamas", true)
				var ee := e
				var r := efecto(pegado, MazmorraGridMap.a3d(e.x, e.y), {"mudo": true, "seguir": func():
					if ee.frozen > 0 and not ee.dying:
						return MazmorraGridMap.a3d(ee.x, ee.y)
					ee.set_meta("v3d_llamas", false)
					return null})
				if r.is_empty():
					e.set_meta("v3d_llamas", false)
	# teletransporte: el héroe salta de golpe (más de 40 px en un fotograma)
	var aqui := Vector2(p.x, p.y)
	if _heroe_antes != null and p.cls == "mage" and aqui.distance_to(_heroe_antes) > 40:
		efecto("mago_teletransporte", MazmorraGridMap.a3d(_heroe_antes.x, _heroe_antes.y))
		efecto("mago_teletransporte", MazmorraGridMap.a3d(aqui.x, aqui.y), {"mudo": true})
	_heroe_antes = aqui

func _centro_nova() -> Vector3:
	var c := sim.nova_c()
	return MazmorraGridMap.a3d(c.x, c.y)

# ======================================================================
#  para el panel de ajuste: sacar un efecto cualquiera para verlo
# ======================================================================
## sobre el muñeco (o enemigo) más cercano al héroe, o un poco por delante
func probar(id: String) -> void:
	var d := ficha(id)
	if d.is_empty() or sim == null or sim.p == null:
		return
	var p := sim.p
	var obj := Vector2(p.x + cos(p.face) * 90, p.y + sin(p.face) * 90)
	var mejor: Ent.Enemy = null
	var bd := 400.0
	for e: Ent.Enemy in sim.enemies:
		var dd := Vector2(e.x - p.x, e.y - p.y).length()
		if not e.dying and dd < bd:
			bd = dd
			mejor = e
	if mejor != null:
		obj = Vector2(mejor.x, mejor.y)
	var yo := MazmorraGridMap.a3d(p.x, p.y)
	var alli := MazmorraGridMap.a3d(obj.x, obj.y)
	match String(d.get("forma", "golpe")):
		"proyectil":
			# del héroe al objetivo a 280 px/s, como la bola de fuego
			var ini := MazmorraGridMap.a3d(p.x, p.y + ALTO_BOLA - 20, ALTO_BOLA)
			var fin := MazmorraGridMap.a3d(obj.x, obj.y, ALTO_BOLA)
			var dur := maxf(.2, ini.distance_to(fin) / (280.0 * MazmorraGridMap.PX_M))
			var t0 := Time.get_ticks_msec()
			efecto(id, ini, {"dir": (fin - ini).normalized(), "seguir": func():
				var k := (Time.get_ticks_msec() - t0) / 1000.0 / dur
				return null if k >= 1.0 else ini.lerp(fin, k)})
		"suelo":
			efecto(id, yo, {"base": 6.0, "dur": 3.0})
		_:   # golpe y aura
			efecto(id, alli, {"dur": 3.0})

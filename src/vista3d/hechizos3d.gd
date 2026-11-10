class_name Hechizos3D
extends Node3D
## Efectos de las magias con hojas de fotogramas (assets/vfx/<hoja>.png + .json, hechas con
## tools/vfx_hoja.py a partir de lo que sale de ChatGPT, sobre fondo negro).
##
## Qué es cada efecto lo dice el catálogo (assets/vfx/catalogo.json), una ficha por efecto:
##   hoja, reserva (hoja a usar si aún no está la buena), forma, tam (m; en «suelo», veces el diámetro
##   de la habilidad), brillo, velocidad (× fps de la hoja), alto (m sobre el suelo), bucle, giro (rad/s, suelo),
##   cabeza (proyectil: dónde está la punta), luz (color, "" sin luz), luz_energia, luz_alcance, sonido,
##   al_acabar (efecto que sale donde acaba), pegado (efecto que sale sobre cada enemigo afectado) y
##   apoyado (golpe/aura: la base del dibujo toca el suelo), de_habilidad (suelo: tam va en veces el diámetro de la habilidad), tintes (color por clase: {"mage": "#ff9a40", …}; las imágenes blancas se tiñen con el de la clase del héroe).
## Al lanzar cualquier habilidad sale el «aura de lanzar» sobre el héroe: LANZAR (círculo en el suelo,
##   resplandor alrededor del cuerpo y brillo en la mano), con el tinte de su clase.
## Formas: proyectil (de cara a la cámara y girado hacia donde vuela), golpe (de cara a la cámara, una vez),
##   suelo (tumbado en el suelo) y aura (de cara a la cámara, siguiendo a alguien).
## Añadir un efecto con una forma que ya existe = una ficha nueva, sin programar. Lo que sí es código es
## el «enganche»: qué mira de la simulación para saber cuándo sale (ver _enganches()).
## El panel de ajuste (PanelEfectos, F4 en el piso de prueba) cambia las fichas en vivo y las guarda.
## La simulación no cambia: esto solo mira y pinta.

var sim: Sim
var camara: Camera3D
var actores: Actores3D       # para la mano del héroe

const LANZAR := ["cast_circulo", "cast_resplandor", "cast_mano"]

const RUTA_CATALOGO := "res://assets/vfx/catalogo.json"
const ALTO_BOLA := 20.0      # px: la bola de fuego sale a la altura del pecho (como en la simulación)

var _vivos: Array = []       # {id, nodo, luz, t, pos, dir, base, seguir (Callable → Vector3 o null), dur, fin}
var _malla: QuadMesh
var _activos := {}           # efectos que duran mientras dura algo (nova, drenaje, torbellino…): clave → efecto
var _paso_antes := -1          # paso del combo en el fotograma anterior (tajo del verdugo)
var _cd_antes := []          # enfriamiento de cada habilidad en el fotograma anterior (para saber cuándo se lanza)
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
instance uniform vec4 tinte : source_color = vec4(1.0);
void fragment() {
	float f = floor(fotograma);
	vec2 celda = vec2(mod(f, rejilla.x), floor(f / rejilla.x));
	vec4 c = texture(hoja, (celda + UV) / rejilla);
	ALBEDO = c.rgb * tinte.rgb * c.a * intensidad * 1.6;
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
	var tintes: Dictionary = d.get("tintes", {})
	if not tintes.is_empty() and sim != null and sim.p != null:
		var clase := "dk" if sim.p.dk else ("dl" if sim.p.dl else sim.p.cls)   # p.cls es «knight» en los dos
		var tc := Color(String(tintes.get(clase, tintes.get("otro", "#ffffff"))))
		n.set_instance_shader_parameter("tinte", tc)
		if l != null:
			l.light_color = tc
	var e := {"id": id, "nodo": n, "luz": l, "t": randf() * 2.0 if d.get("bucle", false) else 0.0, "pos": pos,
		"dir": op.get("dir", Vector3.ZERO), "base": float(op.get("base", 1.0)), "seguir": op.get("seguir", null),
		"dur": float(op.get("dur", INF)), "fin": false, "giro0": randf() * TAU, "espejo": bool(op.get("espejo", false))}
	_vivos.append(e)
	if String(d.get("sonido", "")) != "" and not op.get("mudo", false):
		_sonido(StringName(d.sonido), pos)
	_poner(e, 0.0)
	return e

func reset() -> void:
	for e in _vivos:
		_soltar(e)
	_vivos.clear()
	_activos.clear()
	_cd_antes.clear()
	_llamarada_antes = false
	_heroe_antes = null

func _exit_tree() -> void:
	_malla = null   # los efectos son hijos: se van con el nodo

func _soltar(e: Dictionary) -> void:
	if is_instance_valid(e.nodo):
		e.nodo.free()
	if e.luz != null and is_instance_valid(e.luz):
		e.luz.free()

## cuántos efectos hay vivos (pruebas); id acabado en «*» cuenta los que empiezan así
func vivos(id: String = "") -> int:
	return _vivos.filter(func(e): return id == "" or e.id == id or (id.ends_with("*") and e.id.begins_with(id.trim_suffix("*")))).size()

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
		if String(d.get("forma", "")) == "proyectil" and (p - e.pos).length() > .001:
			e.dir = (p - e.pos).normalized()   # el dibujo sigue a la trayectoria (arcos, persecuciones)
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
	if d.get("apoyado", false):   # la base del dibujo en el suelo, sea cual sea su tamaño
		alto += lado * .5
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
			if e.espejo:   # dibujo dado la vuelta (el tajo cuando el héroe mira a la izquierda de la pantalla)
				var b := nodo.global_transform.basis
				nodo.global_transform.basis = Basis(-b.x, b.y, b.z)
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
		_gesto("lanzar_bola", .45)
		var ff: Dictionary = f
		efecto("bola_fuego", MazmorraGridMap.a3d(f.x, f.y + ALTO_BOLA), {"dir": Vector3(f.vx, 0, f.vy).normalized(),
			"seguir": func():
				return null if ff.get("dead", false) or not C.fballs.has(ff) else MazmorraGridMap.a3d(ff.x, ff.y + ALTO_BOLA)})
	# explosión del clic izquierdo: el gesto al lanzarla y el estallido cuando estalla
	for a in C.aoes:
		if not a.has("v3d_gesto"):
			a["v3d_gesto"] = true
			_gesto("lanzar_estallido", .5)
			# una bola de fuego pequeña sale de la mano y vuela en arco hasta donde estalla
			var aa: Dictionary = a
			var ini := _pos_mano()
			var fin := MazmorraGridMap.a3d(a.x, a.y, 6.0)
			var alto_arco := clampf(ini.distance_to(fin) * .35, .8, 3.0)
			efecto("mago_bola_arco", ini, {"dir": (fin - ini).normalized(), "seguir": func():
				if aa.boom > 0 or not C.aoes.has(aa):
					return null
				var k := clampf(1.0 - float(aa.t) / maxf(.01, float(aa.max)), 0.0, 1.0)
				return ini.lerp(fin, k) + Vector3(0, 4.0 * alto_arco * k * (1.0 - k), 0)})
		if a.boom > 0 and not a.has("v3d"):
			a["v3d"] = true
			efecto("mago_estallido", MazmorraGridMap.a3d(a.x, a.y))
	# nova ígnea: un anillo en el suelo mientras dure (sigue a su centro)
	_mientras("nova", sim.skill_on_id("nova"), "mago_nova", _centro_nova, sim.skp("nova", "r") * 2)
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
	# --- Caballero de la Muerte ---
	# levantar muertos: un estallido nigromántico donde se levanta cada aliado
	for a: Ent.Ally in sim.allies:
		if not a.get_meta("v3d", false):
			a.set_meta("v3d", true)
			efecto("dk_levantar", MazmorraGridMap.a3d(a.x, a.y))
	# aura de drenaje: en el suelo mientras dure (sigue a su centro)
	_mientras("drenaje", sim.skill_on_id("drain"), "dk_drenaje", _centro_drenaje, sim.skp("drain", "r") * 2)
	# torbellino oscuro: un anillo de tajos alrededor del héroe mientras gira
	_mientras("torbellino", p.spin_t > 0, "dk_torbellino", _pos_heroe, sim.skp("whirl", "r") * 2)
	# --- Señor Oscuro ---
	# nube de muerte: cada nube en el suelo mientras exista (algunas siguen al héroe)
	for c in C.clouds:
		if c.has("v3d"):
			continue
		c["v3d"] = true
		var cc: Dictionary = c
		efecto("dl_nube", MazmorraGridMap.a3d(c.x, c.y), {"base": c.r * 2 * MazmorraGridMap.PX_M,
			"seguir": func(): return MazmorraGridMap.a3d(cc.x, cc.y) if C.clouds.has(cc) else null})
	# orbe de muerte: flota hacia su presa; al estallar, «al_acabar»
	for o in C.orbes:
		if o.has("v3d"):
			continue
		o["v3d"] = true
		var oo: Dictionary = o
		efecto("dl_orbe", MazmorraGridMap.a3d(o.x, o.y + 18, 18), {"seguir": func():
			return null if oo.get("dead", false) or not C.orbes.has(oo) else MazmorraGridMap.a3d(oo.x, oo.y + 18, 18)})
	# charco de sangre: el héroe hecho charco
	_mientras("charco", p.pool_t > 0, "dl_charco", _pos_heroe, 40.0)
	# pacto de sangre: llamas de sangre alrededor del héroe mientras dura
	_mientras("pacto", sim.skill_on_id("pact"), "dl_pacto", _pos_heroe)
	# --- Arquero ---
	# flechas (normales, múltiples y de fuego): vuelan mientras existan
	for a in C.arrows:
		if a.has("v3d"):
			continue
		a["v3d"] = true
		var aa: Dictionary = a
		var fuego: bool = a.get("boom", false) or float(a.get("burn", 0.0)) > 0
		efecto("arq_flecha_fuego" if fuego else "arq_flecha", _pos_flecha(a), {"dir": Vector3(a.vx, 0, a.vy).normalized(), "mudo": not fuego,
			"seguir": func(): return null if aa.get("dead", false) or not C.arrows.has(aa) else _pos_flecha(aa)})
	# lluvia de flechas: la lluvia y su círculo en el suelo mientras dure
	for r in C.rains:
		if r.has("v3d"):
			continue
		r["v3d"] = true
		var rr: Dictionary = r
		var fin := func(): return MazmorraGridMap.a3d(rr.x, rr.y) if C.rains.has(rr) else null
		var diam: float = r.r * 2 * MazmorraGridMap.PX_M
		efecto("arq_lluvia", MazmorraGridMap.a3d(r.x, r.y), {"base": diam, "seguir": fin})
		efecto("arq_lluvia_suelo", MazmorraGridMap.a3d(r.x, r.y), {"base": diam, "seguir": fin, "mudo": true})
	# flechas que suben al lanzar la lluvia
	for u in C.up_arrows:
		if u.has("v3d"):
			continue
		u["v3d"] = true
		var uu: Dictionary = u
		efecto("arq_flecha", MazmorraGridMap.a3d(u.x, u.y, u.z), {"dir": Vector3.UP, "mudo": true,
			"seguir": func(): return MazmorraGridMap.a3d(uu.x, uu.y, uu.z) if C.up_arrows.has(uu) else null})
	# --- Caballero ---
	# gran valor: aura en el cuerpo mientras dura
	_mientras("valor", sim.skill_on_id("valor"), "cab_valor", _pos_heroe)
	# estandarte: el círculo dorado donde está clavado
	_mientras("estandarte", sim.banner != null and sim.banner.t > 0, "cab_estandarte", _pos_estandarte, sim.skp("banner", "r") * 2)
	# tajo del verdugo: el tercer tajo del combo, con la habilidad activa, deja un tajo rojo enorme
	if p.atk_t > 0 and p.combo_step != _paso_antes and p.combo_step == 2 and not p.dk and not p.dl and sim.skill_on_id("verdugo"):
		var delante := MazmorraGridMap.a3d(p.x + cos(p.face) * 22, p.y + sin(p.face) * 22)
		efecto("cab_verdugo", delante, {"espejo": mira_izquierda()})
	_paso_antes = p.combo_step if p.atk_t > 0 else -1
	_legendarios()
	# --- al lanzar cualquier habilidad: el aura de lanzar sobre el héroe ---
	_cd_antes.resize(p.sk.size())
	for i in p.sk.size():
		var cd: float = p.sk[i].get("cd", 0.0)
		var antes = _cd_antes[i]
		if antes != null and float(antes) <= 0.0 and cd > 0.0:
			lanzar(String(p.skills[i]) if i < p.skills.size() else "")
		_cd_antes[i] = cd

## ¿el héroe mira hacia la izquierda de la pantalla? (para dar la vuelta a los dibujos de tajos, que miran a la derecha)
func mira_izquierda() -> bool:
	if camara == null:
		return false
	var cara := Vector3(cos(sim.p.face), 0, sin(sim.p.face))
	return cara.dot(camara.global_transform.basis.x) < 0

## efectos únicos de los legendarios (Legendarios, 10 nov 2026)
func _legendarios() -> void:
	var LG: Legendarios = sim.leg
	if LG == null:
		return
	for o in LG.ondas:   # onda de fuego de la espada: vuela mientras exista
		if o.has("v3d"):
			continue
		o["v3d"] = true
		var oo: Dictionary = o
		efecto("leg_onda_fuego", MazmorraGridMap.a3d(o.x, o.y), {"dir": Vector3(o.vx, 0, o.vy).normalized(),
			"seguir": func(): return MazmorraGridMap.a3d(oo.x, oo.y) if LG.ondas.has(oo) else null})
	for f in LG.fuegos:   # rastro de fuego de las botas
		if f.has("v3d"):
			continue
		f["v3d"] = true
		var ff: Dictionary = f
		efecto("leg_rastro_fuego", MazmorraGridMap.a3d(f.x, f.y), {"mudo": true,
			"seguir": func(): return MazmorraGridMap.a3d(ff.x, ff.y) if LG.fuegos.has(ff) else null})
	for r in LG.rayos:   # rayo de los guanteletes: de un enemigo al siguiente
		if r.has("v3d"):
			continue
		r["v3d"] = true
		var a := MazmorraGridMap.a3d(r.x0, r.y0)
		var b := MazmorraGridMap.a3d(r.x1, r.y1)
		efecto("leg_rayo", (a + b) * .5, {"dir": b - a, "base": maxf(a.distance_to(b), .5), "dur": .3})
		efecto("leg_rayo_golpe", b, {"mudo": true})
	for ev in LG.eventos:
		match String(ev.id):
			"aturdido":   # estrellas sobre el enemigo aturdido por el escudo
				var en: Ent.Enemy = ev.e
				var fin: float = sim.t + float(ev.t)
				efecto("leg_aturdido", MazmorraGridMap.a3d(en.x, en.y), {"mudo": true, "seguir": func():
					return MazmorraGridMap.a3d(en.x, en.y) if sim.t < fin and not en.dying else null})
			"cura":
				efecto("leg_curacion", _pos_heroe(), {"seguir": _pos_heroe})
			"escudo":   # burbuja de la coraza mientras le quede escudo
				efecto("leg_escudo", _pos_heroe(), {"seguir": func(): return _pos_heroe() if sim.p.shield > 0 else null})
			"furia":
				var fin2: float = sim.t + float(ev.t)
				efecto("leg_furia", _pos_heroe(), {"mudo": true, "seguir": func(): return _pos_heroe() if sim.t < fin2 else null})
	LG.eventos.clear()

## el aura de lanzar sobre el héroe (círculo, resplandor y brillo en la mano), con el tinte de su clase,
## y el gesto del héroe: levantar muertos «lanzar_mayor», los caballeros «lanzar_menor», el mago «lanzar_estallido»
func lanzar(habilidad: String = "") -> void:
	if habilidad == "raise":
		_gesto("lanzar_mayor", 1.0)
	elif sim.p.cls == "knight":
		_gesto("lanzar_menor", .6)
	elif sim.p.cls == "mage" and habilidad != "blink":
		_gesto("lanzar_estallido", .6)
	# el círculo y el resplandor de su clase (cast_circulo_mage…); si no hay, los blancos teñidos
	var clase := "dk" if sim.p.dk else ("dl" if sim.p.dl else sim.p.cls)
	for base in [LANZAR[0], LANZAR[1]]:
		var propio: String = base + "_" + clase
		var hay: bool = not ficha(propio).is_empty() and hoja_de(ficha(propio)).tex != null
		efecto(propio if hay else base, _pos_heroe(), {"seguir": _pos_heroe, "mudo": true})
	efecto(LANZAR[2], _pos_mano(), {"seguir": _pos_mano})

## efecto que dura mientras «si» sea verdad (y lo siga siendo: _sigue); pos: Callable → Vector3;
## diam_px: diámetro de la habilidad en px (para los de suelo; el tam de la ficha va en veces este diámetro)
func _mientras(clave: String, si: bool, id: String, pos: Callable, diam_px: float = 0.0) -> void:
	if not si:
		_activos.erase(clave)
		return
	if _activos.has(clave) and not _activos[clave].fin:
		return
	var op := {"seguir": func(): return pos.call() if _sigue(clave) else null}
	if diam_px > 0:
		op.base = diam_px * MazmorraGridMap.PX_M
	var r := efecto(id, pos.call(), op)
	if not r.is_empty():
		_activos[clave] = r

func _sigue(clave: String) -> bool:
	match clave:
		"nova": return sim.skill_on_id("nova")
		"drenaje": return sim.skill_on_id("drain")
		"torbellino": return sim.p.spin_t > 0
		"charco": return sim.p.pool_t > 0
		"pacto": return sim.skill_on_id("pact")
		"valor": return sim.skill_on_id("valor")
		"estandarte": return sim.banner != null and sim.banner.t > 0
	return false

func _gesto(n: String, dur: float) -> void:
	if actores != null:
		actores.gesto(n, dur)

func _pos_heroe() -> Vector3:
	return MazmorraGridMap.a3d(sim.p.x, sim.p.y)

func _pos_mano() -> Vector3:
	return actores.mano_heroe() - Vector3(0, float(ficha(LANZAR[2]).get("alto", 0.0)), 0) if actores != null else _pos_heroe() + Vector3(0, 1.2, 0)

func _pos_flecha(a: Dictionary) -> Vector3:
	return MazmorraGridMap.a3d(a.x, a.y, float(a.get("h", 16.0)))

func _pos_estandarte() -> Vector3:
	return MazmorraGridMap.a3d(sim.banner.x, sim.banner.y) if sim.banner != null else _pos_heroe()

func _centro_drenaje() -> Vector3:
	var c := sim.drain_c()
	return MazmorraGridMap.a3d(c.x, c.y)

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
	if id in LANZAR:   # los de lanzar, sobre el héroe
		match LANZAR.find(id):
			0, 1: efecto(id, yo, {"seguir": _pos_heroe})
			2: efecto(id, _pos_mano(), {"seguir": _pos_mano})
		return
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
		"suelo":   # los de una habilidad, con un diámetro de 6 m de muestra
			efecto(id, yo, {"base": 6.0 if d.get("de_habilidad", false) else 1.0, "dur": 3.0})
		_:   # golpe y aura
			efecto(id, alli, {"dur": 3.0, "base": 6.0 if d.get("de_habilidad", false) else 1.0})

class_name Modelo3D
extends Node3D
## Un personaje animado (los .glb de assets/monstruos, salidos de SPRITE_FACTORY con tools/blender/monstruos_glb.py).
## Envuelve el AnimationPlayer: reproducir("walk"), reproducir("attack", velocidad)… con mezcla suave.
## Animaciones: idle, walk, run, attack, hurt, death (y jump en el capitán demonio).
## El modelo de Mixamo mira a +z; aquí se gira para que mire a -z, como el resto de nodos.

## monstruo de la simulación (Enemy.mon) → modelo y datos (de config/characters/*.json de la fábrica)
const FICHAS := {
	"esqueleto": {"glb": "esqueleto", "alto": 1.8, "golpe": .36},   # la espada toca a 0,82 s de 2,27 (pico de velocidad de la mano)
	"bufona": {"glb": "jester", "alto": 1.75, "golpe": .8, "luz": Color8(190, 90, 255)},
	"miniDemon": {"glb": "minidemon", "alto": 1.15, "golpe": .8, "luz": Color8(255, 120, 30), "parts": ["brasas"]},
	"middleDemon": {"glb": "middledemon", "alto": 2.3, "golpe": .8, "luz": Color8(255, 110, 30), "parts": ["brasas"]},
	"demonCaptain": {"glb": "leveldemon", "alto": 2.7, "golpe": .8, "luz": Color8(255, 90, 20), "parts": ["brasas", "humo"]},
	"firedemon": {"glb": "firedemon", "alto": 2.1, "golpe": .45, "luz": Color8(255, 90, 20), "parts": ["brasas", "humo"]},
	"prueba2": {"glb": "prueba2", "alto": 2.0, "golpe": .5},
	# el héroe: pon su base.fbx de Mixamo en SPRITE_FACTORY/input/characters/heroe y conviértelo igual
	"heroe": {"glb": "heroe", "alto": 1.8, "golpe": .5},
	# la Maga (Tripo + Mixamo, solo malla y esqueleto: tools/blender/heroe_skin_glb.py), skin del mago.
	# Sale de 1,0 m («alto_original»); sus animaciones, del esqueleto («anims_de»: quieto, dolor, muerte, correr),
	# y sus ataques con los Cast de heroe_anims («attack» = lanzar_bola). Decidido por Diego el 12 nov.
	"maga": {"glb": "maga", "alto": 1.8, "alto_original": 1.0, "golpe": .348, "anims_de": "esqueleto",
		"sin": ["attack", "walk"], "attack": "lanzar_bola"},
}
## el modelo del héroe según la clase (si su .glb existe); las demás clases, el esqueleto
const HEROE_CLASE := {"mage": "maga"}
const BUCLE := ["idle", "walk", "run", "andar", "correr_medio", "correr_rapido", "trotar", "correr_adelante", "correr_herido_atras"]
const ALTO_ORIGINAL := 1.81   # lo que miden los modelos al salir de Mixamo

var anim: AnimationPlayer
var actual := ""
var ficha := {}
var ajuste := 1.0   # para que lo colgado de los huesos (armas, armadura) salga en metros si el modelo se ha escalado aparte

static func de_clase(cls: String, por_defecto: String = "esqueleto") -> String:
	var id: String = HEROE_CLASE.get(cls, por_defecto)
	return id if hay(id) else por_defecto

static func hay(id: String) -> bool:
	return FICHAS.has(id) and ResourceLoader.exists("res://assets/monstruos/%s.glb" % FICHAS[id].glb)

## tinte: multiplica el color de todos los materiales (los esqueletos enemigos van más oscuros y rojizos)
static func crear(id: String, tinte: Color = Color.WHITE) -> Modelo3D:
	if not hay(id):
		return null
	var f: Dictionary = FICHAS[id]
	var m := Modelo3D.new()
	m.ficha = f
	var esc: Node3D = (load("res://assets/monstruos/%s.glb" % f.glb) as PackedScene).instantiate()
	esc.rotation.y = PI
	esc.scale = Vector3.ONE * (float(f.alto) / float(f.get("alto_original", ALTO_ORIGINAL)))
	m.ajuste = float(f.get("alto_original", ALTO_ORIGINAL)) / ALTO_ORIGINAL
	m.add_child(esc)
	# los agarres de repuesto (para el equipo del héroe) no se ven: solo se ve lo que lleva el personaje
	for a in esc.find_children("agarre_*", "MeshInstance3D", true, false):
		a.visible = false
	m.anim = esc.find_children("*", "AnimationPlayer", true, false).front() if esc.find_children("*", "AnimationPlayer", true, false).size() else null
	if f.has("anims_de"):
		m._animaciones_de(esc, f)
	if m.anim != null:
		for n in BUCLE:
			if m.anim.has_animation(n):
				m.anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		m.reproducir("idle")
	for mi in esc.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if tinte != Color.WHITE and mi.mesh != null:
			for k in mi.mesh.get_surface_count():
				var mat: Material = mi.mesh.surface_get_material(k)
				if mat is BaseMaterial3D:
					var m2: BaseMaterial3D = mat.duplicate()
					m2.albedo_color = m2.albedo_color * tinte
					mi.set_surface_override_material(k, m2)
	for k in f.get("parts", []):
		m.add_child(_particulas(k, float(f.alto)))
	if f.has("luz"):
		var l := OmniLight3D.new()
		l.light_color = f.luz
		l.light_energy = 1.2
		l.omni_range = 4.5
		l.position = Vector3(0, float(f.alto) * .6, 0)
		m.add_child(l)
	return m

## punto de enganche en un hueso de Mixamo («RightHand», «LeftHand», «Head»…): lo que se cuelgue de aquí
## sigue la animación. Devuelve un nodo ya escalado a metros (el esqueleto de Mixamo va a escala 0,01).
func enganche(hueso: String) -> Node3D:
	var sk: Skeleton3D = find_children("*", "Skeleton3D", true, false).front()
	var nombre := "mixamorig_" + hueso
	var b: BoneAttachment3D = null
	for c in sk.get_children():
		if c is BoneAttachment3D and c.bone_name == nombre:
			b = c
			if c.has_node("metros"):
				return c.get_node("metros")
	if b == null:
		b = BoneAttachment3D.new()
		b.bone_name = nombre
		sk.add_child(b)
	var m := Node3D.new()
	m.name = "metros"
	b.add_child(m)
	m.scale = Vector3.ONE * 100.0 * ajuste   # deshace el 0,01 de Mixamo (la escala de alto del modelo se mantiene)
	return m

## el agarre de un arma de un modelo de la fábrica (malla y posición respecto al hueso) para dárselo a otro
## con el mismo esqueleto de Mixamo. Por defecto, la espada del esqueleto en la mano derecha.
## mano: «main_hand» o «off_hand»; tipo: «espada» o «escudo». Sale de los agarres colocados con
## colocar_arma.py («agarre_<mano>_<tipo>» en el .glb) y, si no hay, del arma que trae el modelo.
static var _agarres := {}

static func limpiar() -> void:
	_agarres.clear()
	_extra.clear()

# ----------------------------------------------------------------------
#  animaciones sueltas de Mixamo para el héroe (tools/blender/animaciones_glb.py → heroe_anims.glb + .json):
#  lanzar_bola, lanzar_estallido, lanzar_menor, lanzar_mayor, combo_ataque, combo_tajos, ataque_salto, dolor_escudo
# ----------------------------------------------------------------------
static var _extra := {}   # {"anims": {nombre: Animation}, "datos": {nombre: {duracion, golpe}}}

static func extra() -> Dictionary:
	if not _extra.is_empty():
		return _extra
	_extra = {"anims": {}, "datos": {}, "reposo": {}}
	var ruta := "res://assets/monstruos/heroe_anims.glb"
	if not ResourceLoader.exists(ruta):
		return _extra
	var esc: Node = (load(ruta) as PackedScene).instantiate()
	var aps := esc.find_children("*", "AnimationPlayer", true, false)
	if aps.size():
		var ap: AnimationPlayer = aps[0]
		for n in ap.get_animation_list():
			_extra.anims[n] = ap.get_animation(n).duplicate()
	_extra.reposo = _reposo(esc)
	esc.free()
	var f := FileAccess.open("res://assets/monstruos/heroe_anims.json", FileAccess.READ)
	if f != null:
		var j = JSON.parse_string(f.get_as_text())
		if j is Dictionary:
			_extra.datos = j
	return _extra

## copia las animaciones sueltas al AnimationPlayer de este modelo (las pistas son las mismas que las del esqueleto)
func anadir_animaciones() -> void:
	if anim == null:
		return
	var lib := anim.get_animation_library("")
	if lib == null:
		return
	var x := extra()
	var ajenas := ficha.has("anims_de")   # otro esqueleto de Mixamo: hay que pasarlas a sus huesos
	for n in x.anims:
		if not lib.has_animation(n):
			lib.add_animation(n, _pasar(x.anims[n], x.reposo, _reposo(self)) if ajenas else x.anims[n])
	if ficha.has("attack") and lib.has_animation(ficha.attack) and not lib.has_animation("attack"):
		lib.add_animation("attack", lib.get_animation(ficha.attack))
	for n in BUCLE:
		if lib.has_animation(n):
			lib.get_animation(n).loop_mode = Animation.LOOP_LINEAR

## marco del esqueleto de un modelo de Mixamo (giro de la raíz del .glb al Skeleton3D) y altura de la cadera en reposo
static func _reposo(n: Node) -> Dictionary:
	var sks := n.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return {}
	var sk: Skeleton3D = sks[0]
	var i := sk.find_bone("mixamorig_Hips")
	if i < 0:
		return {}
	var marco := Basis.IDENTITY
	var x: Node = sk
	while x != null and x != n:
		if x is Node3D:
			marco = (x as Node3D).transform.basis.orthonormalized() * marco
		x = x.get_parent()
	return {"marco": marco.get_rotation_quaternion(), "alto": sk.get_bone_rest(i).origin.length()}

## una animación de otro esqueleto de Mixamo pasada a este: los huesos llevan el mismo giro (Mixamo usa los
## mismos ejes), menos la cadera, que se gira para quedar igual en el mundo aunque el esqueleto venga girado;
## su posición se escala a la altura de este y se quitan las demás posiciones y escalas (cada hueso conserva su largo)
static func _pasar(a: Animation, de: Dictionary, a_: Dictionary) -> Animation:
	var r := a.duplicate(true) as Animation
	if de.is_empty() or a_.is_empty():
		return r
	var giro: Quaternion = (a_.marco as Quaternion).inverse() * (de.marco as Quaternion)
	var k: float = float(a_.alto) / maxf(.001, float(de.alto))
	for t in range(r.get_track_count() - 1, -1, -1):
		var cadera := str(r.track_get_path(t)).ends_with(":mixamorig_Hips")
		match r.track_get_type(t):
			Animation.TYPE_POSITION_3D:
				if not cadera:
					r.remove_track(t)
				else:
					for c in r.track_get_key_count(t):
						r.track_set_key_value(t, c, giro * (r.track_get_key_value(t, c) as Vector3) * k)
			Animation.TYPE_ROTATION_3D:
				if cadera:
					for c in r.track_get_key_count(t):
						r.track_set_key_value(t, c, giro * (r.track_get_key_value(t, c) as Quaternion))
			Animation.TYPE_SCALE_3D:
				r.remove_track(t)
	return r

## las animaciones del modelo «anims_de» (menos las de «sin») en un AnimationPlayer nuevo para este
func _animaciones_de(esc: Node3D, f: Dictionary) -> void:
	var src := (load("res://assets/monstruos/%s.glb" % FICHAS[f.anims_de].glb) as PackedScene).instantiate()
	var aps := src.find_children("*", "AnimationPlayer", true, false)
	if anim == null:
		anim = AnimationPlayer.new()
		anim.name = "AnimationPlayer"
		esc.add_child(anim)   # root_node «..»: las pistas «esqueleto/Skeleton3D:…» salen de la raíz del .glb
	if not anim.has_animation_library(""):
		anim.add_animation_library("", AnimationLibrary.new())
	var lib := anim.get_animation_library("")
	if aps.size():
		var ap: AnimationPlayer = aps[0]
		var de := _reposo(src)
		var a_ := _reposo(esc)
		for n in ap.get_animation_list():
			if not n in f.get("sin", []) and not lib.has_animation(n):
				lib.add_animation(n, _pasar(ap.get_animation(n), de, a_))
	src.free()

## momento del golpe de una animación (fracción del clip): de la ficha para «attack», del .json para las sueltas
func golpe_de(n: String) -> float:
	if n == "attack" and not ficha.has("attack"):
		return float(ficha.get("golpe", .5))
	if n == "attack":
		n = ficha.attack
	return float(extra().datos.get(n, {}).get("golpe", .5))
static func agarre(id: String = "esqueleto", mano: String = "main_hand", tipo: String = "espada") -> Dictionary:
	var k := "%s/%s/%s" % [id, mano, tipo]
	if _agarres.has(k):
		return _agarres[k]
	var r := {}
	if hay(id):
		var esc: Node = (load("res://assets/monstruos/%s.glb" % FICHAS[id].glb) as PackedScene).instantiate()
		var a := esc.find_child("agarre_%s_%s" % [mano, tipo], true, false) as MeshInstance3D
		if a == null and tipo == "espada":
			a = esc.find_child("arma_" + mano, true, false) as MeshInstance3D
		if a != null:
			# en metros, relativo al hueso (sin la escala 0,01 del esqueleto)
			var t := a.transform
			t.origin *= .01
			t.basis = t.basis.scaled(Vector3.ONE * .01)
			r = {"mesh": a.mesh, "t": t}
		esc.free()
	_agarres[k] = r
	return r

## brasas que suben del cuerpo y humo por encima (las «parts» de la ficha de la fábrica)
static func _particulas(tipo: String, alto: float) -> CPUParticles3D:
	var f := CPUParticles3D.new()
	var q := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = MazmorraGridMap._punto()
	var g := Gradient.new()
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	f.emission_box_extents = Vector3(.3, alto * .3, .3) * (alto / 2.0)
	f.position = Vector3(0, alto * .55, 0)
	f.direction = Vector3.UP
	f.spread = 25
	f.gravity = Vector3.ZERO
	if tipo == "humo":
		f.amount = 14
		f.lifetime = 1.6
		f.position.y = alto * .85
		f.initial_velocity_min = .3
		f.initial_velocity_max = .7
		f.scale_amount_min = .5
		f.scale_amount_max = .9
		q.size = Vector2.ONE * .6
		g.offsets = PackedFloat32Array([0, .3, 1])
		g.colors = PackedColorArray([Color(.15, .12, .11, 0), Color(.2, .17, .15, .45), Color(.25, .22, .2, 0)])
	else:
		f.amount = int(10 + alto * 8)
		f.lifetime = .9
		f.initial_velocity_min = .5
		f.initial_velocity_max = 1.3
		f.scale_amount_min = .04
		f.scale_amount_max = .09
		q.size = Vector2.ONE
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		g.offsets = PackedFloat32Array([0, .4, 1])
		g.colors = PackedColorArray([Color(1, .85, .4, 1), Color(1, .45, .1, .9), Color(.6, .1, .02, 0)])
	q.material = m
	f.mesh = q
	f.color_ramp = g
	return f

func duracion(n: String) -> float:
	return anim.get_animation(n).length if anim != null and anim.has_animation(n) else 1.0

## reproduce n (si ya está sonando y no se fuerza, sigue); velocidad cambia el ritmo
func reproducir(n: String, velocidad: float = 1.0, mezcla: float = .15, forzar: bool = false) -> void:
	if anim == null or not anim.has_animation(n):
		return
	anim.speed_scale = velocidad
	if n == actual and not forzar:
		return
	actual = n
	anim.play(n, mezcla)
	if forzar:
		anim.seek(0, true)

## reproduce n empezando en el segundo desde del clip (para saltarse la preparación de un tajo)
func reproducir_desde(n: String, desde: float, velocidad: float = 1.0, mezcla: float = .06) -> void:
	if anim == null or not anim.has_animation(n):
		return
	anim.speed_scale = velocidad
	actual = n
	anim.play(n, mezcla)
	anim.seek(clampf(desde, 0.0, duracion(n)), true)

func terminada() -> bool:
	return anim == null or not anim.is_playing()

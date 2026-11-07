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
}
const BUCLE := ["idle", "walk", "run"]
const ALTO_ORIGINAL := 1.81   # lo que miden los modelos al salir de Mixamo

var anim: AnimationPlayer
var actual := ""
var ficha := {}

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
	esc.scale = Vector3.ONE * (float(f.alto) / ALTO_ORIGINAL)
	m.add_child(esc)
	# los agarres de repuesto (para el equipo del héroe) no se ven: solo se ve lo que lleva el personaje
	for a in esc.find_children("agarre_*", "MeshInstance3D", true, false):
		a.visible = false
	m.anim = esc.find_children("*", "AnimationPlayer", true, false).front() if esc.find_children("*", "AnimationPlayer", true, false).size() else null
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
	m.scale = Vector3.ONE * 100.0   # deshace el 0,01 de Mixamo (la escala de alto del modelo se mantiene)
	return m

## el agarre de un arma de un modelo de la fábrica (malla y posición respecto al hueso) para dárselo a otro
## con el mismo esqueleto de Mixamo. Por defecto, la espada del esqueleto en la mano derecha.
## mano: «main_hand» o «off_hand»; tipo: «espada» o «escudo». Sale de los agarres colocados con
## colocar_arma.py («agarre_<mano>_<tipo>» en el .glb) y, si no hay, del arma que trae el modelo.
static var _agarres := {}

static func limpiar() -> void:
	_agarres.clear()
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

class_name Modelo3D
extends Node3D
## Un personaje animado (los .glb de assets/monstruos, salidos de SPRITE_FACTORY con tools/blender/monstruos_glb.py).
## Envuelve el AnimationPlayer: reproducir("walk"), reproducir("attack", velocidad)… con mezcla suave.
## Animaciones: idle, walk, run, attack, hurt, death (y jump en el capitán demonio).
## El modelo de Mixamo mira a +z; aquí se gira para que mire a -z, como el resto de nodos.

## monstruo de la simulación (Enemy.mon) → modelo y datos (de config/characters/*.json de la fábrica)
const FICHAS := {
	"esqueleto": {"glb": "esqueleto", "alto": 1.8, "golpe": .5},
	"bufona": {"glb": "jester", "alto": 1.75, "golpe": .8, "luz": Color8(190, 90, 255)},
	# los demonios todavía no existen en la simulación: se ven en la sala de prueba
	"miniDemon": {"glb": "minidemon", "alto": 1.15, "golpe": .8, "luz": Color8(255, 120, 30)},
	"middleDemon": {"glb": "middledemon", "alto": 2.3, "golpe": .8, "luz": Color8(255, 110, 30)},
	"demonCaptain": {"glb": "leveldemon", "alto": 2.7, "golpe": .8, "luz": Color8(255, 90, 20)},
	"firedemon": {"glb": "firedemon", "alto": 2.1, "golpe": .45, "luz": Color8(255, 90, 20)},
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

static func crear(id: String) -> Modelo3D:
	if not hay(id):
		return null
	var f: Dictionary = FICHAS[id]
	var m := Modelo3D.new()
	m.ficha = f
	var esc: Node3D = (load("res://assets/monstruos/%s.glb" % f.glb) as PackedScene).instantiate()
	esc.rotation.y = PI
	esc.scale = Vector3.ONE * (float(f.alto) / ALTO_ORIGINAL)
	m.add_child(esc)
	m.anim = esc.find_children("*", "AnimationPlayer", true, false).front() if esc.find_children("*", "AnimationPlayer", true, false).size() else null
	if m.anim != null:
		for n in BUCLE:
			if m.anim.has_animation(n):
				m.anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		m.reproducir("idle")
	for mi in esc.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
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

## el agarre del arma de un modelo de la fábrica (malla y posición en la mano) para dárselo a otro
## con el mismo esqueleto de Mixamo. Por defecto, la espada del esqueleto.
static var _agarres := {}
static func agarre(id: String = "esqueleto", nodo: String = "arma_main_hand") -> Dictionary:
	var k := id + "/" + nodo
	if _agarres.has(k):
		return _agarres[k]
	var r := {}
	if hay(id):
		var esc: Node = (load("res://assets/monstruos/%s.glb" % FICHAS[id].glb) as PackedScene).instantiate()
		var a := esc.find_child(nodo, true, false) as MeshInstance3D
		if a != null:
			# en metros, relativo al hueso (sin la escala 0,01 del esqueleto)
			var t := a.transform
			t.origin *= .01
			t.basis = t.basis.scaled(Vector3.ONE * .01)
			r = {"mesh": a.mesh, "t": t}
		esc.free()
	_agarres[k] = r
	return r

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

func terminada() -> bool:
	return anim == null or not anim.is_playing()

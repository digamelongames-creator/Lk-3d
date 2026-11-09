class_name Hechizos3D
extends Node3D
## Efectos de los hechizos con hojas de fotogramas (assets/vfx/<nombre>.png + .json, hechas con
## tools/vfx_hoja.py a partir de lo que sale de ChatGPT, sobre fondo negro).
##
## Cada efecto es un cuadrado de cara a la cámara, en modo aditivo (lo negro no suma nada),
## que va pasando los fotogramas. Uno solo material para todos: el fotograma y la intensidad
## van por instancia (instance uniform).
##
## Ahora mismo:
##   · bola de fuego del mago (Clases.fballs): la hoja «bola_fuego» en bucle, girada hacia donde vuela,
##     con una luz naranja que la sigue;
##   · al chocar o acabar el recorrido: la hoja «explosion_fuego» una vez, con un fogonazo de luz y sonido.
## La simulación no cambia: esto solo mira Clases.fballs y pinta.

var sim: Sim
var camara: Camera3D

const BOLA := "bola_fuego"
const EXPLOSION := "explosion_fuego"
const TAM_BOLA := 1.9        # m de lado del cuadrado de la bola
const CABEZA := .33          # dónde está la cabeza dentro del cuadrado (fracción del lado, desde el centro hacia delante)
const TAM_EXPLOSION := 3.4
const ALTO_BOLA := 20.0      # px de altura (como en la simulación: sale a la altura del pecho)

var _bolas := {}             # vid de la bola → {nodo, luz, t, pos, dir}
var _vivos: Array = []       # efectos de una vez: {nodo, luz, t, hoja}
var _n := 0
var _malla: QuadMesh

# ======================================================================
#  hojas (caché estática; se suelta con limpiar())
# ======================================================================
static var _hojas := {}
static var _material: ShaderMaterial

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

static func limpiar() -> void:
	_hojas.clear()
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

## un cuadrado con la hoja; cada hoja lleva su copia del material (la textura cambia)
func _cuadrado(nombre: String, lado: float) -> MeshInstance3D:
	var h := hoja(nombre)
	var m := MeshInstance3D.new()
	if _malla == null:
		_malla = QuadMesh.new()
	m.mesh = _malla
	m.scale = Vector3.ONE * lado
	if not h.has("mat"):
		var mat: ShaderMaterial = _mat().duplicate()
		mat.set_shader_parameter("hoja", h.tex)
		mat.set_shader_parameter("rejilla", Vector2(h.cols, h.filas))
		h.mat = mat
	m.material_override = h.mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m

func _luz(c: Color, energia: float, alcance: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energia
	l.omni_range = alcance
	l.omni_attenuation = 1.6
	l.shadow_enabled = false
	add_child(l)
	return l

# ======================================================================
#  cada fotograma
# ======================================================================
func _exit_tree() -> void:
	_malla = null   # los cuadrados son hijos: se van con el nodo

func reset() -> void:
	for k in _bolas:
		_bolas[k].nodo.free()
		_bolas[k].luz.free()
	_bolas.clear()
	for v in _vivos:
		v.nodo.free()
		v.luz.free()
	_vivos.clear()

func actualizar(dt: float) -> void:
	if sim == null or sim.cls == null or camara == null:
		return
	var vistas := {}
	for f in sim.cls.fballs:
		if not f.has("vid"):
			_n += 1
			f["vid"] = _n
			Fx3DSonido.tocar(sim, &"fuego", f.x, f.y)
		vistas[f.vid] = true
		var b: Dictionary = _bolas.get(f.vid, {})
		if b.is_empty():
			b = {"nodo": _cuadrado(BOLA, TAM_BOLA), "luz": _luz(Color(1, .55, .2), 3.0, 5.0), "t": randf() * 2}
			_bolas[f.vid] = b
		b.t += dt
		b.pos = MazmorraGridMap.a3d(f.x, f.y + ALTO_BOLA, ALTO_BOLA)
		b.dir = Vector3(f.vx, 0, f.vy).normalized()
		_poner_bola(b)
	# las que ya no están: han chocado o se han acabado → explosión donde estaban
	for k in _bolas.keys():
		if vistas.has(k):
			continue
		var b: Dictionary = _bolas[k]
		_explotar(b.pos + b.dir * .3)
		b.nodo.free()
		b.luz.free()
		_bolas.erase(k)
	# efectos de una vez
	for v in _vivos:
		v.t += dt
		var h: Dictionary = v.hoja
		var fr: float = v.t * float(h.fps)
		v.nodo.set_instance_shader_parameter("fotograma", minf(fr, h.fotogramas - 1))
		_de_cara(v.nodo, Vector3.ZERO)
		var p := clampf(fr / float(h.fotogramas), 0, 1)
		v.luz.light_energy = 9.0 * pow(1 - p, 2.2)
		v.fin = fr >= h.fotogramas
		if v.fin:
			v.nodo.free()
			v.luz.free()
	_vivos = _vivos.filter(func(v): return not v.fin)

func _poner_bola(b: Dictionary) -> void:
	var h := hoja(BOLA)
	b.nodo.set_instance_shader_parameter("fotograma", fmod(b.t * float(h.fps), float(h.fotogramas)))
	var adelante := _de_cara(b.nodo, b.dir)
	# la cabeza de la bola (no el centro del dibujo) va donde está la bola de la simulación
	b.nodo.position = b.pos - adelante * CABEZA * TAM_BOLA
	b.luz.position = b.pos
	b.luz.light_energy = 2.6 + sin(b.t * 23.0) * .5

## pone el cuadrado de cara a la cámara; si hay dirección, gira el dibujo (que mira a +X) hacia ella
## en pantalla. Devuelve hacia dónde apunta el dibujo, en el mundo.
func _de_cara(n: MeshInstance3D, dir: Vector3) -> Vector3:
	var z := camara.global_transform.basis.z.normalized()
	var x := camara.global_transform.basis.x.normalized()
	if dir.length() > .01:
		var d := (dir - z * dir.dot(z))
		if d.length() > .001:
			x = d.normalized()
	var y := z.cross(x).normalized()
	var esc := n.scale.x
	n.global_transform.basis = Basis(x * esc, y * esc, z * esc)
	return x

func _explotar(p: Vector3) -> void:
	var h := hoja(EXPLOSION)
	var n := _cuadrado(EXPLOSION, TAM_EXPLOSION * randf_range(.92, 1.08))
	n.position = p + Vector3(0, .35, 0)
	n.set_instance_shader_parameter("fotograma", 0.0)
	n.set_instance_shader_parameter("intensidad", .75)
	var l := _luz(Color(1, .5, .18), 9.0, 7.0)
	l.position = p + Vector3(0, .6, 0)
	_vivos.append({"nodo": n, "luz": l, "t": 0.0, "hoja": h, "fin": false})
	var px := MazmorraGridMap.a_px(p)
	Fx3DSonido.tocar(sim, &"explosion", px.x, px.y)


## el sonido, a través de Fx3D (si la simulación lo tiene)
class Fx3DSonido:
	static func tocar(s: Sim, id: StringName, x: float, y: float) -> void:
		if s != null and s.fx is Fx3D:
			(s.fx as Fx3D).sonido(id, x, y)

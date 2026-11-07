class_name MazmorraGridMap
extends Node3D
## Monta en 3D el piso que genera DungeonGen (la misma rejilla que usa la simulación).
## Tres GridMap con el mismo MeshLibrary (KitMazmorra): suelo, muros y objetos de casilla.
## Lo que no es una casilla (antorchas, velas, adornos del Decorador) va como nodos sueltos,
## porque lleva luces y partículas y el GridMap no puede.
##
## Coordenadas: casilla (cx, cy) de la simulación → celda (cx, 0, cy) del GridMap.
## Un píxel de la simulación = 1/16 m (32 px = 2 m = una casilla). Ver a3d().

const PX_M := KitMazmorra.CELDA / DungeonGen.TS

var suelo: GridMap
var muros: GridMap
var objetos: GridMap
var adornos: Node3D
var luces: Array[OmniLight3D] = []
var _llamas: Array = []   # [OmniLight3D, energía base, fase]
var _t := 0.0

## px de la simulación (x, y) y altura en px → metros
static func a3d(x: float, y: float, z: float = 0.0) -> Vector3:
	return Vector3(x * PX_M, z * PX_M, y * PX_M)

## metros → px de la simulación
static func a_px(v: Vector3) -> Vector2:
	return Vector2(v.x / PX_M, v.z / PX_M)

func _ready() -> void:
	suelo = _gm("Suelo")
	muros = _gm("Muros")
	objetos = _gm("Objetos")
	adornos = Node3D.new()
	adornos.name = "Adornos"
	add_child(adornos)

func _gm(n: String) -> GridMap:
	var g := GridMap.new()
	g.name = n
	g.mesh_library = KitMazmorra.cargar()
	g.cell_size = Vector3(KitMazmorra.CELDA, 1, KitMazmorra.CELDA)
	g.cell_center_y = false
	add_child(g)
	return g

func construir(L: Dictionary) -> void:
	for g in [suelo, muros, objetos]:
		g.clear()
	for c in adornos.get_children():
		c.queue_free()
	luces.clear()
	_llamas.clear()
	var W := DungeonGen.GW
	var H := DungeonGen.GH
	var G: PackedByteArray = L.grid
	var sala: PackedInt32Array = L.get("room_of", PackedInt32Array())
	var i_suelo := KitMazmorra.id("suelo")
	var i_sala := KitMazmorra.id("suelo_sala")
	var i_muro := KitMazmorra.id("muro")
	var pieza := {
		DungeonGen.WATER: KitMazmorra.id("agua"),
		DungeonGen.BRIDGE: KitMazmorra.id("puente"),
		DungeonGen.PILLAR: KitMazmorra.id("pilar"),
		DungeonGen.GRAVE: KitMazmorra.id("tumba"),
		DungeonGen.RUBBLE: KitMazmorra.id("escombro"),
		DungeonGen.DECOR: KitMazmorra.id("mueble"),
		DungeonGen.DOWN: KitMazmorra.id("escalera_baja"),
		DungeonGen.UP: KitMazmorra.id("escalera_sube"),
	}
	for cy in H:
		for cx in W:
			var t := G[cy * W + cx]
			var celda := Vector3i(cx, 0, cy)
			if t == DungeonGen.ROCK:
				if _junto_a_suelo(G, cx, cy):
					muros.set_cell_item(celda, i_muro, _orientacion_muro(G, cx, cy))
				continue
			if t == DungeonGen.ABISMO:
				continue
			# todo lo que no es roca ni vacío lleva suelo debajo (también agua, puertas, tumbas…)
			if t != DungeonGen.WATER:
				var en_sala := sala.size() > 0 and sala[cy * W + cx] >= 0
				suelo.set_cell_item(celda, i_sala if en_sala and i_sala >= 0 else i_suelo)
			if pieza.has(t) and pieza[t] >= 0:
				objetos.set_cell_item(celda, pieza[t])
	_antorchas(L)
	_decorador(L)

## un muro solo hace falta donde la roca toca algo pisable (las 8 vecinas); la roca de dentro se queda vacía
func _junto_a_suelo(G: PackedByteArray, cx: int, cy: int) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var x: int = cx + dx
			var y: int = cy + dy
			if x < 0 or y < 0 or x >= DungeonGen.GW or y >= DungeonGen.GH:
				continue
			var t := G[y * DungeonGen.GW + x]
			if t != DungeonGen.ROCK and t != DungeonGen.ABISMO:
				return true
	return false

## giro de la pieza de muro según hacia dónde da el suelo. Con el bloque provisional da igual;
## con un kit de muros finos (la cara pintada mirando a -z en Blender) la deja mirando al suelo.
func _orientacion_muro(G: PackedByteArray, cx: int, cy: int) -> int:
	var at := func(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= DungeonGen.GW or y >= DungeonGen.GH:
			return false
		return G[y * DungeonGen.GW + x] != DungeonGen.ROCK and G[y * DungeonGen.GW + x] != DungeonGen.ABISMO
	var giro := 0.0
	if at.call(cx, cy + 1): giro = 0.0          # suelo al sur
	elif at.call(cx, cy - 1): giro = PI         # al norte
	elif at.call(cx + 1, cy): giro = PI / 2     # al este
	elif at.call(cx - 1, cy): giro = -PI / 2    # al oeste
	return muros.get_orthogonal_index_from_basis(Basis(Vector3.UP, giro))

# ---------- luces ----------
func _antorchas(L: Dictionary) -> void:
	for tr in L.get("torches", []):
		# la antorcha cuelga de la cara sur del muro de la casilla (cx, cy - 1)
		var p := Vector3((tr.cx + .5) * KitMazmorra.CELDA, 2.1, tr.cy * KitMazmorra.CELDA + .25)
		var soporte := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(.12, .5, .12)
		soporte.mesh = b
		soporte.position = p - Vector3(0, .3, 0)
		adornos.add_child(soporte)
		_fuego(p, .25)
		var luz := _luz(p + Vector3(0, 0, .4), Color(1, .55, .25), 2.6, 9.0)
		_llamas.append([luz, luz.light_energy, randf() * 10])

func _decorador(L: Dictionary) -> void:
	var D: Dictionary = L.get("deco", {})
	for o in D.get("suelo", []):
		if String(o.t) == "alfombra":   # las alfombras son un rectángulo (x0, y0)–(x1, y1)
			var a := a3d(o.x0, o.y0)
			var b := a3d(o.x1, o.y1)
			_bulto((a + b) / 2, Vector3(absf(b.x - a.x), .02, absf(b.z - a.z)), Color(.35, .06, .06), false)
			continue
		var pos := a3d(o.x, o.y)
		match String(o.t):
			"vela":
				for k in int(o.get("n", 1)):
					var v := MeshInstance3D.new()
					var c := CylinderMesh.new()
					c.top_radius = .04
					c.bottom_radius = .05
					c.height = .25 + .1 * k
					v.mesh = c
					v.position = pos + Vector3(k * .12 - .1, c.height / 2, (k % 2) * .1)
					adornos.add_child(v)
				_fuego(pos + Vector3(0, .35, 0), .07)
			"calavera", "caido":
				_bulto(pos, Vector3(.35, .25, .3), Color(.75, .72, .62))
			"losa", "circulo":
				_bulto(pos, Vector3(1.2, .02, 1.2), Color(.2, .19, .2))
			_:
				pass   # hollín, humedad, telarañas: decals más adelante
	var n := 0
	for l in D.get("luces", []):
		if n >= 60:
			break   # luces de vela: con 60 sobra para un piso
		n += 1
		var luz := _luz(a3d(l.x, l.y, 10), Color(1, .7, .4), 1.2, 4.0)
		_llamas.append([luz, luz.light_energy, randf() * 10])

func _luz(p: Vector3, c: Color, e: float, r: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = p
	l.light_color = c
	l.light_energy = e
	l.omni_range = r
	l.omni_attenuation = 1.4
	l.light_volumetric_fog_energy = 1.5
	adornos.add_child(l)
	luces.append(l)
	return l

func _fuego(p: Vector3, tam: float) -> void:
	var f := CPUParticles3D.new()
	f.position = p
	f.amount = 16
	f.lifetime = .5
	f.direction = Vector3.UP
	f.spread = 15
	f.initial_velocity_min = .3
	f.initial_velocity_max = .8
	f.gravity = Vector3(0, 1.0, 0)
	f.scale_amount_min = tam
	f.scale_amount_max = tam * 1.6
	var q := QuadMesh.new()
	q.size = Vector2.ONE * .5
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _punto()
	q.material = m
	f.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1, .8, .3, 1))
	g.set_color(1, Color(.8, .15, .02, 0))
	f.color_ramp = g
	adornos.add_child(f)

static var _tex_punto: Texture2D
static func _punto() -> Texture2D:
	if _tex_punto == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(.5, .5)
		t.fill_to = Vector2(.5, 0)
		_tex_punto = t
	return _tex_punto

func _bulto(p: Vector3, t: Vector3, c: Color, girar: bool = true) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = t
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	b.material = m
	mi.mesh = b
	mi.position = p + Vector3(0, t.y / 2, 0)
	if girar:
		mi.rotation.y = randf() * TAU
	adornos.add_child(mi)

## las llamas parpadean
func _process(dt: float) -> void:
	_t += dt
	for f in _llamas:
		var l: OmniLight3D = f[0]
		l.light_energy = f[1] * (.85 + .15 * sin(_t * 9 + f[2]) + .08 * sin(_t * 23 + f[2] * 3))

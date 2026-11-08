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
var muros: GridMap         # núcleos de muro y arcos
var objetos: GridMap
var caras: Array[GridMap] = []      # sillería de cada lado que da al suelo: 0 sur, 1 este, 2 norte, 3 oeste
var esquinas: Array[GridMap] = []   # columnas de esquina: 0 suroeste, 1 sureste, 2 noreste, 3 noroeste
const DIRS := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
const ESQ := [Vector2i(-1, 1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
const GIROS := [0.0, PI / 2, PI, -PI / 2]
## máscara L.a_mano (ver PisoPrueba): lo que no pone el GridMap porque va montado a mano
const A_MANO_MURO := 1
const A_MANO_SUELO := 2
const A_MANO_OBJETO := 4
var _G: PackedByteArray
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
	for k in 4:
		caras.append(_gm("Caras%d" % k))
		esquinas.append(_gm("Esquinas%d" % k))
	adornos = Node3D.new()
	adornos.name = "Adornos"
	add_child(adornos)

func _gm(n: String) -> GridMap:
	var g := GridMap.new()
	g.name = n
	g.mesh_library = KitMazmorra.mesh_library()
	g.cell_size = Vector3(KitMazmorra.CELDA, 1, KitMazmorra.CELDA)
	g.cell_center_y = false
	add_child(g)
	return g

func construir(L: Dictionary) -> void:
	for g in [suelo, muros, objetos] + caras + esquinas:
		g.clear()
	for c in adornos.get_children():
		c.queue_free()
	luces.clear()
	_llamas.clear()
	var W := DungeonGen.GW
	var H := DungeonGen.GH
	var G: PackedByteArray = L.grid
	_G = G
	var sala: PackedInt32Array = L.get("room_of", PackedInt32Array())
	# casillas montadas a mano (pisos de prueba con kits de fuera): bit 1 sin muro, 2 sin suelo, 4 sin objeto
	var mano: PackedByteArray = L.get("a_mano", PackedByteArray())
	var i_sala := KitMazmorra.id("suelo_sala")
	var i_arco := KitMazmorra.id("arco")
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
			var m := mano[cy * W + cx] if mano.size() > 0 else 0
			if t == DungeonGen.ROCK:
				if m & A_MANO_MURO:
					continue
				if _junto_a_suelo(G, cx, cy):
					_muro(cx, cy)
				continue
			if t == DungeonGen.ABISMO:
				continue
			# todo lo que no es roca ni vacío lleva suelo debajo (también agua, puertas, tumbas…)
			if t != DungeonGen.WATER and not (m & A_MANO_SUELO):
				var en_sala := sala.size() > 0 and sala[cy * W + cx] >= 0
				suelo.set_cell_item(celda, i_sala if en_sala and i_sala >= 0 else KitMazmorra.variante("suelo", cx, cy), _giro_azar(cy, cx))
			if t == DungeonGen.DOOR and i_arco >= 0:
				muros.set_cell_item(celda, i_arco, _orientacion_arco(G, cx, cy))
			elif pieza.has(t) and pieza[t] >= 0 and not (m & A_MANO_OBJETO):
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

# ---------- muros: núcleo + caras + columnas de esquina ----------
func _pisable(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= DungeonGen.GW or y >= DungeonGen.GH:
		return false
	var t := _G[y * DungeonGen.GW + x]
	return t != DungeonGen.ROCK and t != DungeonGen.ABISMO and t != DungeonGen.DOOR

func _ori(g: GridMap, giro: float) -> int:
	return g.get_orthogonal_index_from_basis(Basis(Vector3.UP, giro))

func _muro(cx: int, cy: int) -> void:
	var celda := Vector3i(cx, 0, cy)
	muros.set_cell_item(celda, KitMazmorra.variante("nucleo", cx, cy), _giro_azar(cx, cy))
	for k in 4:
		var d: Vector2i = DIRS[k]
		if _pisable(cx + d.x, cy + d.y):
			caras[k].set_cell_item(celda, KitMazmorra.id(_cara_para(cx, cy, k)), _ori(caras[k], GIROS[k]))
	for k in 4:
		var e: Vector2i = ESQ[k]
		var a := _pisable(cx + e.x, cy)
		var b := _pisable(cx, cy + e.y)
		var diag := _pisable(cx + e.x, cy + e.y)
		# esquina de dentro de una sala (solo la diagonal es suelo) o esquina que sobresale (los dos lados)
		if (diag and not a and not b) or (a and b):
			esquinas[k].set_cell_item(celda, KitMazmorra.id("columna_esquina"), _ori(esquinas[k], GIROS[k]))

## qué cara lleva el lado k del muro (cx, cy): columnas cada 3 casillas y, entre medias, variantes al azar
func _cara_para(cx: int, cy: int, k: int) -> String:
	var t := cx if k % 2 == 0 else cy
	if posmod(t, 3) == 0:
		return "cara_columna"
	var h := absi(hash(Vector3i(cx, cy, k))) % 100
	if h < 14: return "cara_arco_ciego"
	if h < 24: return "cara_nicho"
	if h < 30: return "cara_rota"
	if h < 36: return "cara_hiedra"
	if h < 40: return "cara_reja"
	return "cara" if h % 2 == 0 else "cara_b"

func _giro_azar(a: int, b: int) -> int:
	return muros.get_orthogonal_index_from_basis(Basis(Vector3.UP, (absi(hash(Vector2i(a * 7, b * 13))) % 4) * PI / 2))

## el arco se hace de norte a sur; si la roca está al norte y al sur, el paso va de este a oeste
func _orientacion_arco(G: PackedByteArray, cx: int, cy: int) -> int:
	var roca := func(x: int, y: int) -> bool:
		return x < 0 or y < 0 or x >= DungeonGen.GW or y >= DungeonGen.GH or G[y * DungeonGen.GW + x] == DungeonGen.ROCK
	var este_oeste: bool = roca.call(cx, cy - 1) and roca.call(cx, cy + 1)
	return muros.get_orthogonal_index_from_basis(Basis(Vector3.UP, PI / 2 if este_oeste else 0.0))

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
	# la antorcha cuelga de la cara sur del muro de la casilla (cx, cy - 1)
	for tr in L.get("torches", []):
		poner_antorcha(Vector2i(tr.cx, tr.cy), Vector2i(0, -1))

## centro del suelo de una casilla, en metros
static func centro(c: Vector2i) -> Vector3:
	return Vector3((c.x + .5) * KitMazmorra.CELDA, 0, (c.y + .5) * KitMazmorra.CELDA)

## pieza colgada de la pared: celda es la casilla de suelo y cara la dirección hacia el muro
func poner_en_pared(nombre: String, celda: Vector2i, cara: Vector2i, altura: float, corre: float = 0.0) -> Node3D:
	var n := KitMazmorra.pieza(nombre)
	var dir := Vector3(cara.x, 0, cara.y)
	var lado := Vector3(-cara.y, 0, cara.x)
	n.position = centro(celda) + dir * (KitMazmorra.CELDA / 2 - .1) + lado * corre + Vector3(0, altura, 0)
	_cara_lisa(celda + cara, cara)
	n.rotation.y = atan2(-float(cara.x), -float(cara.y))
	adornos.add_child(n)
	return n

## lo que se cuelga de una pared necesita la cara lisa detrás (sin columna, nicho ni reja)
func _cara_lisa(muro: Vector2i, cara: Vector2i) -> void:
	var k := DIRS.find(-cara)
	if k < 0 or caras.is_empty():
		return
	var c := Vector3i(muro.x, 0, muro.y)
	if caras[k].get_cell_item(c) != GridMap.INVALID_CELL_ITEM:
		caras[k].set_cell_item(c, KitMazmorra.id("cara"), caras[k].get_cell_item_orientation(c))

func poner_antorcha(celda: Vector2i, cara: Vector2i, corre: float = 0.0) -> void:
	var a := poner_en_pared("antorcha", celda, cara, 1.55, corre)
	var llama := a.transform * Vector3(0, .45, .3)   # la copa de la antorcha (ver kit_mazmorra.py)
	_fuego(llama, .13)
	var luz := _luz(llama + Vector3(-cara.x, 0, -cara.y) * .5, Color(1, .62, .36), 2.8, 9.0)
	_llamas.append([luz, luz.light_energy, randf() * 10])

## fuego con luz que parpadea (braseros y antorchas de los kits de fuera)
func fuego_y_luz(p: Vector3, tam: float, energia: float = 2.8, rango: float = 9.0) -> void:
	_fuego(p, tam)
	var luz := _luz(p + Vector3(0, .4, 0), Color(1, .62, .36), energia, rango)
	_llamas.append([luz, luz.light_energy, randf() * 10])

## pieza suelta de pie en el suelo (brasero, barril, caja…) en un punto en metros
func poner_en_suelo(nombre: String, pos: Vector3, giro: float = 0.0) -> Node3D:
	var n := KitMazmorra.pieza(nombre)
	n.position = pos
	n.rotation.y = giro
	adornos.add_child(n)
	if nombre == "brasero":
		var arriba := pos + Vector3(0, 1.15, 0)
		_fuego(arriba, .26)
		var luz := _luz(arriba + Vector3(0, .6, 0), Color(1, .6, .32), 3.2, 10.0)
		_llamas.append([luz, luz.light_energy, randf() * 10])
	return n

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
	l.light_volumetric_fog_energy = .6
	adornos.add_child(l)
	luces.append(l)
	return l

func _fuego(p: Vector3, tam: float) -> void:
	var f := CPUParticles3D.new()
	f.position = p
	f.amount = 24
	f.lifetime = .45
	f.direction = Vector3.UP
	f.spread = 15
	f.initial_velocity_min = .3
	f.initial_velocity_max = .8
	f.gravity = Vector3(0, 1.0, 0)
	f.scale_amount_min = tam
	f.scale_amount_max = tam * 1.6
	var q := QuadMesh.new()
	q.size = Vector2(.32, .5)
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
	g.offsets = PackedFloat32Array([0, .35, 1])
	g.colors = PackedColorArray([Color(1, .75, .35, .9), Color(1, .42, .08, .75), Color(.5, .08, .02, 0)])
	f.color_ramp = g
	adornos.add_child(f)

static var _tex_punto: Texture2D

## ver KitMazmorra.limpiar()
static func limpiar() -> void:
	_tex_punto = null
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

class_name PruebaPuente
## «Prueba puente»: la imagen 8 del Inframundo (C:\Carpeta Juego\Temas\tema_inframundo_pasillo.png) montada a mano
## con las piezas de Tripo (assets/props/puente.glb e inframundo.glb). Sin enemigos y sin nada que hacer:
## solo se anda por el puente y el rellano de la puerta. La cámara es fija, con el ángulo de la imagen.
##
## Mundo (m): el puente va de oeste a este (x de X0 a X1) con el tablero a y = 0 y 8 m de ancho (z de Z0 a Z0 + 8).
## Al norte (z menor) el abismo con los puentes lejanos y las cascadas; al sur (z mayor) el río de lava bajo los arcos;
## al este, el rellano y la puerta demoníaca en la pared de roca. La cámara mira desde el suroeste, en alto.

const N := 9   # número de «piso de prueba» (PisoPrueba.pisos_menu)
const CX0 := 10          # casillas del tablero (el puente): x 10..24, y 20..23
const CX1 := 24
const CY0 := 20
const CY1 := 23
const RX1 := 27          # rellano: x 25..27, y 18..25
const RY0 := 18
const RY1 := 25
const C := 2.0           # m por casilla
const X0 := CX0 * C      # 20 m
const X1 := (CX1 + 1) * C   # 50 m
const Z0 := CY0 * C      # 40 m
const Z1 := (CY1 + 1) * C   # 48 m
const ZC := (Z0 + Z1) / 2.0
const XR := (RX1 + 1) * C   # 56 m: la pared de la puerta
const LAVA_Y := -7.6

## la cámara (desde, hacia, campo de visión): se ajusta comparando con la imagen
const CAM_DESDE := Vector3(24.3, 19.5, 65.5)
const CAM_HACIA := Vector3(42.0, 0.0, 44.0)
const CAM_FOV := 45.0

# tramo del puente: el modelo mide 8,22 × 8,14 × 6,4 m con el tablero a 5,77 y los pretiles desde |z| = 2,2
const TRAMO_TABLERO := 5.77
const TRAMO_ANCHO_UTIL := 4.4
const TRAMO_LARGO := 8.22

# ======================================================================
#  mapa para la simulación: solo el tablero y el rellano se pisan
# ======================================================================
static func generar() -> Dictionary:
	var L := DungeonGen.gen_level("prueba-puente", 1)
	var W := DungeonGen.GW
	var H := DungeonGen.GH
	var G := PackedByteArray()
	G.resize(W * H)
	G.fill(DungeonGen.ROCK)
	var room_of := PackedInt32Array()
	room_of.resize(W * H)
	room_of.fill(-1)
	var mano := PackedByteArray()
	mano.resize(W * H)
	mano.fill(MazmorraGridMap.A_MANO_MURO | MazmorraGridMap.A_MANO_SUELO | MazmorraGridMap.A_MANO_OBJETO)
	for cy in H:
		for cx in W:
			var puente := cx >= CX0 and cx <= CX1 and cy >= CY0 and cy <= CY1
			var rellano := cx > CX1 and cx <= RX1 and cy >= RY0 and cy <= RY1
			if puente or rellano:
				G[cy * W + cx] = DungeonGen.FLOOR
				room_of[cy * W + cx] = 0
	var corr := PackedByteArray()
	corr.resize(W * H)
	var inicio := {"cx": CX0 + 7, "cy": CY0 + 2}   # donde está el héroe en la imagen
	for clave in ["plataformas", "tramos", "escaleras", "esc_mask", "alt", "pozos", "p5_obj", "_esc_idx", "torches_px", "keyrings", "estilo"]:
		L.erase(clave)
	L.merge({"grid": G, "room_of": room_of, "corr": corr, "a_mano": mano,
		"rooms": [{"x": CX0, "y": RY0, "w": RX1 - CX0 + 1, "h": RY1 - RY0 + 1, "cx": (CX0 + RX1) / 2, "cy": (RY0 + RY1) / 2}],
		"room_num": [1], "start_room": 0, "end_room": 0, "grave_room": -1, "start": inicio,
		"stairs_cell": {"cx": 0, "cy": 0}, "stairs_px": {"x": 16.0, "y": 16.0}, "fount": null,
		"torches": [], "decor": [], "litter": [], "wall_deco": [], "wall_veg": [], "flats": [],
		"chests": [], "gold": [], "doors": [], "key_tables": [], "deco": {},
		"dist": PisoPrueba._distancias(G, inicio, W, H), "prueba": N, "tema3d": "inframundo", "puente": true}, true)
	return L

static func nombre() -> String:
	return "Prueba puente · Inframundo"

# ======================================================================
#  montaje
# ======================================================================
static func _pieza(M: MazmorraGridMap, paquete: String, pieza: String, pos: Vector3, giro: float = 0.0, escala = 1.0) -> MeshInstance3D:
	var n := Props3D.crear(paquete, pieza)
	if n == null:
		return null
	n.position = pos
	n.rotation.y = giro
	n.scale = escala if escala is Vector3 else Vector3.ONE * float(escala)
	M.adornos.add_child(n)
	return n

## el suelo del tema con losas más grandes (como en la imagen)
static func _suelo_grande() -> StandardMaterial3D:
	var m := TemaMazmorra.material_suelo("inframundo").duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3.ONE / 6.5
	return m

static func _luz(M: MazmorraGridMap, p: Vector3, c: Color, e: float, r: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = p
	l.light_color = c
	l.light_energy = e
	l.omni_range = r
	l.omni_attenuation = 1.1
	l.light_volumetric_fog_energy = .5
	M.adornos.add_child(l)
	return l

static func montar(M: MazmorraGridMap, e: Environment) -> void:
	# luz principal cálida, de arriba y desde la lava del sur (con sombras), como en la imagen
	var sol := DirectionalLight3D.new()
	sol.name = "LuzLava"
	sol.light_color = Color(1, .58, .36)
	sol.light_energy = 1.4
	sol.shadow_enabled = true
	sol.light_volumetric_fog_energy = 0.0   # si no, toda la niebla se vuelve roja
	sol.rotation = Vector3(deg_to_rad(-52), deg_to_rad(150), 0)
	M.adornos.add_child(sol)
	_puente(M)
	_rellano_y_puerta(M)
	_lava(M)
	_fondo(M)
	_cadenas_y_jaulas(M)
	ambiente(e)

## dos tramos de Tripo estirados a 8 m de tablero útil, con el suelo del tema encima y pináculos en los pretiles
static func _puente(M: MazmorraGridMap) -> void:
	var s := 8.0 / TRAMO_ANCHO_UTIL                 # ancho y largo
	var sy := s * .78                               # algo más bajo: pretil a la cintura, como en la imagen
	var largo := TRAMO_LARGO * s
	var n := ceili((X1 - X0) / largo)
	for i in n:
		var x := X0 + largo * (i + .5) - (largo * n - (X1 - X0)) / 2
		_pieza(M, "puente", "tramo_puente", Vector3(x, -TRAMO_TABLERO * sy, ZC), 0.0, Vector3(s, sy, s))
	# un tramo más hacia el oeste, que sale de la imagen por abajo a la izquierda
	_pieza(M, "puente", "tramo_puente", Vector3(X0 - largo / 2, -TRAMO_TABLERO * sy, ZC), 0.0, Vector3(s, sy, s))
	# el suelo de losas con grietas (el del tema), un poco por encima del tablero del modelo
	var suelo := MeshInstance3D.new()
	suelo.name = "SueloPuente"
	var b := BoxMesh.new()
	b.size = Vector3(X1 - X0 + largo, .2, 8.0)
	suelo.mesh = b
	suelo.material_override = _suelo_grande()
	suelo.position = Vector3((X0 - largo + X1) / 2, -.09, ZC)
	M.adornos.add_child(suelo)
	# pináculos sobre los pretiles, cada 5 m
	var pretil := (TRAMO_ANCHO_UTIL / 2 + .5) * s
	var x := X0 - largo + 2.0
	while x < X1:
		for lado in [-1.0, 1.0]:
			_pieza(M, "inframundo", "remate_punta", Vector3(x, (6.79 - TRAMO_TABLERO) * sy, ZC + lado * pretil), 0.0, 1.8)
		x += 5.0

## rellano de roca, la puerta demoníaca grande en la pared, los braseros y la pared de roca
static func _rellano_y_puerta(M: MazmorraGridMap) -> void:
	var suelo := MeshInstance3D.new()
	suelo.name = "SueloRellano"
	var b := BoxMesh.new()
	b.size = Vector3(XR - X1 + 1.0, .2, (RY1 - RY0 + 1) * C)
	suelo.mesh = b
	suelo.material_override = _suelo_grande()
	suelo.position = Vector3((X1 + XR) / 2 - .5, -.1, (RY0 * C + (RY1 + 1) * C) / 2)
	M.adornos.add_child(suelo)
	# el rellano se apoya en roca que baja hasta la lava
	for z in [RY0 * C + 3, ZC, (RY1 + 1) * C - 3]:
		_pieza(M, "inframundo", "roca_borde", Vector3((X1 + XR) / 2, -6.0, z), randf() * TAU, Vector3(3.2, 4.5, 3.2))
	# la puerta: grande, de cara al puente (oeste)
	var oeste := -PI / 2
	_pieza(M, "inframundo", "puerta_demoniaca", Vector3(XR + .4, 0, ZC), oeste, 2.7)
	# luz sobre la cara de la puerta (las grietas y el relieve) y dentro, pasillo con luz roja
	_luz(M, Vector3(XR - 6, 6, ZC), Color(1, .5, .25), 7.0, 15.0)
	_luz(M, Vector3(XR + 4, 2.5, ZC), Color(1, .35, .1), 10.0, 12.0)
	var fondo := MeshInstance3D.new()
	var bf := BoxMesh.new()
	bf.size = Vector3(14, .2, 5)
	fondo.mesh = bf
	fondo.material_override = TemaMazmorra.material_suelo("inframundo")
	fondo.position = Vector3(XR + 7, -.1, ZC)
	M.adornos.add_child(fondo)
	# muros con relieve a los lados de la puerta y pared de roca alrededor
	for lado in [-1.0, 1.0]:
		_pieza(M, "inframundo", "muro_calavera", Vector3(XR + .2, 0, ZC + lado * 7.2), oeste, 2.4)
		_pieza(M, "inframundo", "pilar_retorcido", Vector3(XR - .6, 0, ZC + lado * 4.6), 0.0, 1.9)
	# la pared de roca de la derecha: de la lava hasta salir de la imagen, con la puerta en medio
	for i in 8:
		var z := ZC - 30 + i * 8.0
		if absf(z - ZC) < 5:
			continue
		_pieza(M, "puente", "acantilado", Vector3(XR + 3.0 + (i % 2), -12.0, z), oeste + (i % 3 - 1) * .12, Vector3(1.0, 1.9, 1.0))
	# encima de la puerta: la pared sigue hasta salir de la imagen
	_pieza(M, "puente", "acantilado", Vector3(XR + 4.0, 10.5, ZC), oeste, Vector3(1.1, 1.2, 1.0))
	# braseros en la entrada del rellano, sobre los pretiles
	for lado in [-1.0, 1.0]:
		var p := Vector3(X1 + 1.2, 0, ZC + lado * 5.2)
		_pieza(M, "inframundo", "brasero_piedra", p, oeste, 1.35)
		M.fuego_sin_luz(p + Vector3(0, 1.62, 0), .38)
		M.fuego_luz(p + Vector3(0, 2.4, 0), 4.5, 12.0)

## el río de lava bajo los arcos (al sur) y el mar de lava del abismo (al norte), con rocas, cascadas y luz
static func _lava(M: MazmorraGridMap) -> void:
	var lava := MeshInstance3D.new()
	lava.name = "MarDeLava"
	var pl := PlaneMesh.new()
	pl.size = Vector2(200, 90)
	lava.mesh = pl
	lava.material_override = TemaMazmorra.material_lava("inframundo")
	lava.position = Vector3(40, LAVA_Y, Z0 + 2 + 45)   # el río: del pie del puente hacia el sur
	M.adornos.add_child(lava)
	# rocas puntiagudas en el río
	var rocas := [Vector3(40, 0, 62), Vector3(30, 0, 70), Vector3(52, 0, 66), Vector3(46, 0, 78), Vector3(22, 0, 60)]
	for i in rocas.size():
		_pieza(M, "inframundo", "estalagmitas", rocas[i] + Vector3(0, LAVA_Y - .4, 0), i * 1.3, 2.0 + (i % 3) * .5)
	# luces del río: la lava alumbra los arcos desde abajo
	# (sin sombras: no deben llegar al tablero del puente, que está 7,6 m más arriba)
	for x in range(10, 70, 10):
		_luz(M, Vector3(x, LAVA_Y + 1.0, Z1 + 8), Color(1, .4, .1), 4.0, 9.0)

## el abismo del norte: dos puentes lejanos con cascadas de lava, acantilados, lava honda entre la niebla y estalactitas
static func _fondo(M: MazmorraGridMap) -> void:
	_pieza(M, "puente", "puente_lejano", Vector3(26, -22, -22), .3, 1.6)
	_pieza(M, "puente", "puente_lejano", Vector3(52, -16, -52), .1, 1.6)
	for i in 9:
		var x := -6 + i * 10.0
		_pieza(M, "puente", "acantilado", Vector3(x * 1.4 - 20, -44.0 + (i % 3) * 4, -60 - (i % 2) * 10), PI * (i % 2), Vector3(1.6, 2.6, 1.0))
	_pieza(M, "puente", "estalactitas", Vector3(18, 17, 40), .4, 1.3)
	# cascadas de lava bajo los arcos de los puentes lejanos y por los acantilados
	var cae := TemaMazmorra.material_lava("inframundo", true)
	var cascadas := [[Vector3(16, -6, -18), 5.0, 30.0], [Vector3(30, -6, -24), 5.5, 30.0], [Vector3(48, 0, -50), 5.0, 34.0],
		[Vector3(8, 4, -36), 6.0, 40.0], [Vector3(66, 6, -46), 6.0, 40.0]]
	for c in cascadas:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(c[1], c[2])
		q.mesh = qm
		q.material_override = cae
		q.position = c[0] - Vector3(0, c[2] / 2, 0)
		q.rotation.y = .5   # de cara a la cámara
		M.adornos.add_child(q)
		_luz(M, c[0] - Vector3(0, 8, -2), Color(1, .4, .1), 5.0, 14.0)

## una cadena colgada entre dos puntos (catenaria hecha de tramos) y jaulas colgando de ella
static func _cadena(M: MazmorraGridMap, a: Vector3, b: Vector3, caida: float) -> Array:
	var tramo := 3.0 * .9   # cada pieza mide 3 m; se solapan un poco
	var puntos := []
	var n := maxi(2, ceili(a.distance_to(b) / tramo))
	for i in n + 1:
		var t := float(i) / n
		puntos.append(a.lerp(b, t) - Vector3(0, caida * 4 * t * (1 - t), 0))
	for i in n:
		var p: Vector3 = puntos[i]
		var q: Vector3 = puntos[i + 1]
		var d := (q - p)
		var c := Props3D.crear("puente", "cadena")
		if c == null:
			break
		var y := d.normalized()
		var x := y.cross(Vector3.UP).normalized() if absf(y.y) < .99 else Vector3.RIGHT
		var z := x.cross(y).normalized()
		c.basis = Basis(x, y, z).scaled(Vector3(1.2, d.length() / 3.0, 1.2))
		c.position = p
		if i % 2 == 1:   # eslabones alternos girados
			c.basis = c.basis * Basis(Vector3.UP, PI / 2)
		M.adornos.add_child(c)
	return puntos

static func _jaula(M: MazmorraGridMap, arriba: Vector3, largo: float, escala: float) -> void:
	_cadena(M, arriba, arriba - Vector3(0, largo, 0), 0.0)
	_pieza(M, "puente", "jaula", arriba - Vector3(0, largo + 2.3 * escala, 0), randf() * TAU, escala)

static func _cadenas_y_jaulas(M: MazmorraGridMap) -> void:
	var p := _cadena(M, Vector3(14, 19, 36), Vector3(62, 23, 28), 6.0)
	_jaula(M, p[6], 5.5, 1.5)
	_cadena(M, Vector3(30, 22, 18), Vector3(64, 24, 20), 4.0)
	_jaula(M, Vector3(44, 17, 22), 7.0, 1.1)
	_jaula(M, Vector3(48.5, 13, 60), 11.0, 1.6)

## entorno de la imagen: más rojo, niebla más espesa y la de altura casi sin oscurecer lo de abajo
static var _antes := {}
const _CAMPOS := ["background_color", "ambient_light_color", "ambient_light_energy", "volumetric_fog_density", "volumetric_fog_albedo",
	"volumetric_fog_emission", "volumetric_fog_emission_energy", "fog_height_density", "fog_light_color", "glow_intensity", "glow_bloom", "fog_density", "volumetric_fog_length", "tonemap_exposure"]

## deja el entorno como estaba antes de la prueba (main3d lo llama al entrar en cualquier piso)
static func quitar(e: Environment) -> void:
	for k in _antes:
		e.set(k, _antes[k])
	_antes.clear()

static func ambiente(e: Environment) -> void:
	if _antes.is_empty():
		for k in _CAMPOS:
			_antes[k] = e.get(k)
	e.background_color = Color(.09, .02, .01)
	e.ambient_light_color = Color(.75, .55, .45)
	e.ambient_light_energy = .5
	e.volumetric_fog_density = .015
	e.volumetric_fog_albedo = Color(.9, .55, .4)
	e.volumetric_fog_emission = Color(.2, .05, .01)
	e.volumetric_fog_emission_energy = .12
	e.fog_height_density = .02
	e.fog_light_color = Color(.45, .16, .07)
	e.fog_density = .004            # lo lejano (puentes, acantilados) se pierde en la calima roja
	e.volumetric_fog_length = 120
	e.tonemap_exposure = 1.35
	e.glow_intensity = .8
	e.glow_bloom = .08

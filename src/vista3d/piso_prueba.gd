class_name PisoPrueba
## Pisos de prueba: mapas hechos a mano para ver en el juego los paquetes de modelos de fuera,
## sin enemigos. El juego arranca en el piso de prueba 1 (main3d.gd, --prueba=N; --partida para jugar normal).
##
## Piso de prueba 1: un pasillo largo de este a oeste con
##   · arriba, una sala por paquete: Poly Haven, Modular Dungeon Kit, Low Poly, Gótico y Ruinas.
##     Las de los kits llevan sus propios muros y suelos (ESTILOS); las demás, los del juego.
##   · abajo, una sala por propósito: almacén, guardia, tesoro (con el cofre que se abre) y cueva.
## Lo que hay en cada sala lo reparte Repartidor según su propósito.
##
## generar() hace el mapa (la misma forma que DungeonGen, para que la simulación lo use tal cual)
## y amueblar() monta lo que el GridMap no pone: muros y suelos de los kits y los adornos.

const NOMBRES := ["Piso de prueba 1"]

## kits con muros y suelos propios. Las piezas de muro miden una casilla (2 m) y dan la cara a +Z.
const ESTILOS := {
	"dungeon_kit": {"muros": ["muro"], "suelos": ["losa_1", "losa_2", "losa_3"], "paso": 1.0, "esquina": "pilar", "alto": 2.2},
	"low_poly": {"muros": ["brick_wall", "brick_wall_001", "brick_wall_002", "brick_wall_003", "brick_wall_004", "brick_wall_005", "smooth_wall_001", "window_001"],
		"suelos": ["floor_001", "floor_002", "floor_003", "floor_004", "floor_005", "floor_006", "floor_007"], "paso": 2.0, "esquina": "pillar", "alto": 2.91},
	"gotico": {"muros": ["wall2", "wall2", "plane_006"], "suelos": ["plane_008"], "paso": 2.0, "esquina": "corn", "alto": 4.0},
}

## salas del piso 1: nombre, estilo (kit de muros; "" = el del juego) y propósito (Repartidor)
const ARRIBA := [["Poly Haven", "", "muestra_polyhaven"], ["Modular Dungeon Kit", "dungeon_kit", "muestra_dungeon_kit"],
	["Low Poly Dungeon", "low_poly", "muestra_low_poly"], ["Gothic Interior", "gotico", "muestra_gotico"], ["Ancient Ruins", "", "muestra_ruinas"]]
const ABAJO := [["Almacén", "", "almacen"], ["Guardia", "", "guardia"], ["Tesoro", "", "tesoro"], ["Cueva", "", "cueva"]]
const LADO := 9          # casillas de cada sala
const PASO_SALAS := 11   # sala + 2 de roca
const Y_ARRIBA := 3
const Y_PASILLO := 14    # 3 de ancho
const Y_ABAJO := 19

static func nombre(n: int) -> String:
	return NOMBRES[clampi(n - 1, 0, NOMBRES.size() - 1)]

# ======================================================================
#  mapa
# ======================================================================
static func generar(n: int) -> Dictionary:
	# se parte de un piso normal para tener todas las claves que espera la simulación, y se cambia el mapa
	var L := DungeonGen.gen_level("piso-prueba-%d" % n, 1)
	var W := DungeonGen.GW
	var H := DungeonGen.GH
	var G := PackedByteArray()
	G.resize(W * H)
	G.fill(DungeonGen.ROCK)
	var room_of := PackedInt32Array()
	room_of.resize(W * H)
	room_of.fill(-1)
	var corr := PackedByteArray()
	corr.resize(W * H)
	var salas := []
	var x_fin := 3 + (ARRIBA.size() - 1) * PASO_SALAS + LADO
	salas.append({"nombre": "Pasillo", "x": 2, "y": Y_PASILLO, "w": x_fin - 1, "h": 3, "estilo": "", "proposito": "pasillo"})
	for i in ARRIBA.size():
		salas.append({"nombre": ARRIBA[i][0], "x": 3 + i * PASO_SALAS, "y": Y_ARRIBA, "w": LADO, "h": LADO, "estilo": ARRIBA[i][1], "proposito": ARRIBA[i][2], "arriba": true})
	for i in ABAJO.size():
		salas.append({"nombre": ABAJO[i][0], "x": 3 + i * PASO_SALAS, "y": Y_ABAJO, "w": LADO, "h": LADO, "estilo": ABAJO[i][1], "proposito": ABAJO[i][2], "arriba": false})
	for k in salas.size():
		var s: Dictionary = salas[k]
		s["celdas"] = []
		s["puertas"] = []
		for y in range(s.y, s.y + s.h):
			for x in range(s.x, s.x + s.w):
				G[y * W + x] = DungeonGen.FLOOR
				room_of[y * W + x] = k
				s.celdas.append(Vector2i(x, y))
				if k == 0:
					corr[y * W + x] = 1
	# entradas de 3 casillas de ancho, de 2 de largo (la roca entre sala y pasillo); son de la sala
	for k in range(1, salas.size()):
		var s: Dictionary = salas[k]
		var ys: Array = [Y_ARRIBA + LADO, Y_ARRIBA + LADO + 1] if s.arriba else [Y_PASILLO + 3, Y_PASILLO + 4]
		for x in range(s.x + 3, s.x + 6):
			for y in ys:
				G[y * W + x] = DungeonGen.FLOOR
				room_of[y * W + x] = k
			s.puertas.append(Vector2i(x, s.y + s.h - 1 if s.arriba else s.y))
			salas[0].puertas.append(Vector2i(x, Y_PASILLO if s.arriba else Y_PASILLO + 2))
	# el cofre del tesoro: en el centro de la sala, de cara a la cámara (sur)
	var chests := []
	for k in salas.size():
		if salas[k].proposito == "tesoro":
			var c := Vector2i(salas[k].x + 4, salas[k].y + 4)
			salas[k].puertas.append(c)
			chests.append({"cx": c.x, "cy": c.y, "kind": "wood", "room": k})
	# adornos según el propósito; lo sólido pasa a ser DECOR (no se puede pisar)
	var pisable := func(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H and G[c.y * W + c.x] != DungeonGen.ROCK
	var props := []
	for k in salas.size():
		var s: Dictionary = salas[k]
		var lista := Repartidor.repartir(s.proposito, s.celdas, pisable, s.puertas, hash(str(n) + s.nombre))
		for o in lista:
			o["estilo"] = s.estilo
			if o.solido:
				G[o.celda.y * W + o.celda.x] = DungeonGen.DECOR
		props += lista
	# lo que va montado a mano: muros y suelos de los kits, y los objetos sólidos (sin mueble del GridMap)
	var mano := PackedByteArray()
	mano.resize(W * H)
	var estilo_roca := {}
	for cy in H:
		for cx in W:
			var i := cy * W + cx
			if G[i] == DungeonGen.ROCK:
				var e := _estilo_roca(G, room_of, salas, cx, cy, W, H)
				if e != "":
					mano[i] |= MazmorraGridMap.A_MANO_MURO
					estilo_roca[i] = e
			else:
				if room_of[i] >= 0 and String(salas[room_of[i]].estilo) != "":
					mano[i] |= MazmorraGridMap.A_MANO_SUELO
				if G[i] == DungeonGen.DECOR:
					mano[i] |= MazmorraGridMap.A_MANO_OBJETO
	var rooms := []
	var room_num := []
	for k in salas.size():
		var s: Dictionary = salas[k]
		rooms.append({"x": s.x, "y": s.y, "w": s.w, "h": s.h, "cx": s.x + (s.w >> 1), "cy": s.y + (s.h >> 1)})
		room_num.append(k + 1)
	var inicio := {"cx": 3, "cy": Y_PASILLO + 1}
	for clave in ["plataformas", "tramos", "escaleras", "esc_mask", "alt", "pozos", "p5_obj", "_esc_idx", "torches_px", "keyrings", "estilo"]:
		L.erase(clave)
	L.merge({"grid": G, "room_of": room_of, "corr": corr, "rooms": rooms, "room_num": room_num,
		"start_room": 0, "end_room": 0, "grave_room": -1, "start": inicio,
		"stairs_cell": {"cx": 0, "cy": 0}, "stairs_px": {"x": 16.0, "y": 16.0}, "fount": null,
		"torches": [], "decor": [], "litter": [], "wall_deco": [], "wall_veg": [], "flats": [],
		"chests": chests, "gold": [], "doors": [], "key_tables": [], "deco": {},
		"dist": _distancias(G, inicio, W, H),
		"a_mano": mano, "estilo_roca": estilo_roca, "salas_prueba": salas, "props_prueba": props, "prueba": n}, true)
	return L

## el estilo de un muro: el de todo el suelo que toca (8 vecinas); si toca suelos de estilos distintos, el del juego
static func _estilo_roca(G: PackedByteArray, room_of: PackedInt32Array, salas: Array, cx: int, cy: int, W: int, H: int) -> String:
	var e := "-"
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var x: int = cx + dx
			var y: int = cy + dy
			if x < 0 or y < 0 or x >= W or y >= H or G[y * W + x] == DungeonGen.ROCK:
				continue
			var k := room_of[y * W + x]
			var s := String(salas[k].estilo) if k >= 0 else ""
			if e == "-":
				e = s
			elif e != s:
				return ""
	return "" if e == "-" else e

static func _distancias(G: PackedByteArray, inicio: Dictionary, W: int, H: int) -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(W * H)
	d.fill(-1)
	var q := [Vector2i(inicio.cx, inicio.cy)]
	d[inicio.cy * W + inicio.cx] = 0
	var h := 0
	while h < q.size():
		var c: Vector2i = q[h]
		h += 1
		for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var o: Vector2i = c + v
			if o.x < 0 or o.y < 0 or o.x >= W or o.y >= H:
				continue
			var i := o.y * W + o.x
			if d[i] < 0 and DungeonGen.walk(G[i]):
				d[i] = d[c.y * W + c.x] + 1
				q.append(o)
	return d

# ======================================================================
#  botín de prueba: armas de verdad en el suelo de la sala de guardia (se pueden coger)
# ======================================================================
static func botin(sim: Sim) -> void:
	var cls: String = sim.p.cls_key()
	var arma: String = Items.set_of(cls).weapon
	for s in sim.L.get("salas_prueba", []):
		if s.proposito != "guardia":
			continue
		for q in 4:
			var c := Vector2i(s.x + 2 + q * 2, s.y + 4)
			var it := Items.make_gear(sim.rng, q, cls, arma if q % 2 == 0 else "shield" if Items.set_of(cls).slots.has("shield") else arma)
			sim.loot.append({"x": (c.x + .5) * DungeonGen.TS, "y": (c.y + .5) * DungeonGen.TS, "item": it, "bob": randf() * 6, "fly": null})

# ======================================================================
#  montaje 3D
# ======================================================================
static func amueblar(L: Dictionary, M: MazmorraGridMap) -> void:
	var W := DungeonGen.GW
	var G: PackedByteArray = L.grid
	var salas: Array = L.salas_prueba
	var room_of: PackedInt32Array = L.room_of
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + int(L.get("prueba", 1))
	var raiz := M.adornos
	var techo := _material_techo()
	# suelos de los kits
	for i in G.size():
		if G[i] == DungeonGen.ROCK or room_of[i] < 0:
			continue
		var e := String(salas[room_of[i]].estilo)
		if e == "":
			continue
		var E: Dictionary = ESTILOS[e]
		var c := Vector2i(i % W, i / W)
		var paso: float = E.paso
		var n := int(round(KitMazmorra.CELDA / paso))
		for a in n:
			for b in n:
				var pieza: String = E.suelos[rng.randi() % E.suelos.size()]
				var s := Props3D.crear(e, pieza)
				if s == null:
					continue
				s.position = Vector3(c.x * KitMazmorra.CELDA + (a + .5) * paso, -Props3D.alto(e, pieza), c.y * KitMazmorra.CELDA + (b + .5) * paso)
				s.rotation.y = (rng.randi() % 4) * PI / 2
				raiz.add_child(s)
	# muros de los kits: una pieza por lado que da al suelo, una columna en cada esquina de dentro y una tapa oscura encima
	var estilo_roca: Dictionary = L.estilo_roca
	var D4 := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	var ESQ := [Vector2i(-1, 1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	var suelo := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < W and y < DungeonGen.GH and G[y * W + x] != DungeonGen.ROCK
	for i in estilo_roca:
		var e: String = estilo_roca[i]
		var E: Dictionary = ESTILOS[e]
		var c := Vector2i(i % W, i / W)
		var centro := MazmorraGridMap.centro(c)
		for d in D4:
			if not suelo.call(c.x + d.x, c.y + d.y):
				continue
			var pieza: String = E.muros[rng.randi() % E.muros.size()]
			var m := Props3D.crear(e, pieza)
			if m == null:
				continue
			var grosor := Props3D.caja(e, pieza).size.z
			var hacia := Vector3(d.x, 0, d.y)
			m.position = centro + hacia * (KitMazmorra.CELDA / 2 - grosor / 2)
			m.rotation.y = atan2(float(d.x), float(d.y))   # la cara (+Z) mirando al suelo
			raiz.add_child(m)
		for k in 4:
			var q: Vector2i = ESQ[k]
			if suelo.call(c.x + q.x, c.y + q.y) and not suelo.call(c.x + q.x, c.y) and not suelo.call(c.x, c.y + q.y):
				var col := Props3D.crear(e, E.esquina)
				if col != null:
					col.position = centro + Vector3(q.x, 0, q.y) * (KitMazmorra.CELDA / 2)
					raiz.add_child(col)
		var tapa := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(KitMazmorra.CELDA, .1, KitMazmorra.CELDA)
		bm.material = techo
		tapa.mesh = bm
		tapa.position = centro + Vector3(0, float(E.alto) + .05, 0)
		raiz.add_child(tapa)
	# adornos
	for o in L.props_prueba:
		var m := Props3D.crear(o.p, o.pieza)
		if m == null:
			continue
		var pos: Vector3 = o.pos
		m.position = pos
		m.rotation.y = o.giro
		m.scale = Vector3.ONE * float(o.escala)
		if o.tumbado:
			m.rotation.x = -PI / 2
			m.position.y = .04
		if float(o.alto) > 0:
			m.position.y = o.alto
		raiz.add_child(m)
		var f: Array = o.fuego
		if not f.is_empty():
			var fuera := Vector3(-o.pared.x, 0, -o.pared.y) * .25 if float(o.alto) > 0 else Vector3.ZERO
			M.fuego_y_luz(m.position + Vector3(0, float(f[1]), 0) + fuera, float(f[0]),
				2.6 if float(o.alto) > 0 else 3.0, 9.0)
	# luz de sala de exposición: una suave en el techo de cada sala, para ver bien los modelos
	for k in range(1, salas.size()):
		var s: Dictionary = salas[k]
		var luz := OmniLight3D.new()
		luz.position = Vector3((s.x + s.w / 2.0) * KitMazmorra.CELDA, 6.0, (s.y + s.h / 2.0) * KitMazmorra.CELDA)
		luz.light_color = Color(1, .9, .78)
		luz.light_energy = 1.6
		luz.omni_range = 16.0
		luz.omni_attenuation = .8
		luz.shadow_enabled = true
		raiz.add_child(luz)
	# rótulo con el nombre de cada sala, encima de la entrada
	for k in range(1, salas.size()):
		var s: Dictionary = salas[k]
		var r := Label3D.new()
		r.text = s.nombre
		r.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		r.font_size = 64
		r.pixel_size = .01
		r.outline_size = 12
		r.modulate = Color(1, .86, .55)
		r.no_depth_test = true
		var yy: float = (s.y + s.h - 1) if s.arriba else s.y
		r.position = Vector3((s.x + 4.5) * KitMazmorra.CELDA, 3.4, (yy + .5) * KitMazmorra.CELDA)
		raiz.add_child(r)

## la parte de arriba de los muros de los kits: piedra oscura, como el remate de los muros del juego
static func _material_techo() -> StandardMaterial3D:
	return KitMazmorra._piedra(Color(.24, .22, .23), .95)

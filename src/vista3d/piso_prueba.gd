class_name PisoPrueba
## Pisos de prueba: mapas hechos a mano para ver en el juego los paquetes de modelos de fuera,
## sin enemigos. Se entra con el botón «Piso de prueba» de la pantalla de inicio (o --prueba=N).
##
## Piso de prueba 1: un pasillo largo de este a oeste con
##   · arriba, una sala por paquete: Poly Haven, Modular Dungeon Kit, Low Poly, Gótico y Ruinas.
##     Las de los kits llevan sus propios muros y suelos (ESTILOS); las demás, los del juego.
##   · abajo, una sala por propósito: almacén, guardia, tesoro (con el cofre que se abre) y cueva,
##     la sala del aprendizaje: un miniboss y 4 esbirros que vuelven a salir al acabar (arena()),
##     y la sala de efectos: el héroe es mago y tiene muñecos para probar los hechizos (efectos(), Hechizos3D).
## Lo que hay en cada sala lo reparte Repartidor según su propósito.
##
## generar() hace el mapa (la misma forma que DungeonGen, para que la simulación lo use tal cual)
## y amueblar() monta lo que el GridMap no pone: muros y suelos de los kits y los adornos.

const NOMBRES := ["Piso de prueba 1"]
## pisos de prueba de temas (TemaMazmorra): un piso generado de verdad, sin enemigos, con el tema puesto
## 7 = el Inframundo (pisos 8–9): pasarelas sobre un mar de lava, como en la imagen 7 de Pixmith
## 3 = Galerías hundidas (pisos 3–5): pasarelas sobre un abismo de niebla azul con cascadas de agua
const DE_TEMA := {3: "galerias", 7: "inframundo"}

## pisos enteros que salen en el menú de pruebas (además de las salas del piso 1)
static func pisos_menu() -> Array:
	return Escena3D.numeros() + DE_TEMA.keys()

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
const ABAJO := [["Almacén", "", "almacen"], ["Guardia", "", "guardia"], ["Tesoro", "", "tesoro"], ["Cueva", "", "cueva"],
	["Aprendizaje", "", "arena"], ["Efectos", "", "efectos"], ["Mímico", "", "mimico"]]
const LADO := 9          # casillas de cada sala
const PASO_SALAS := 11   # sala + 2 de roca
const Y_ARRIBA := 3
const Y_PASILLO := 14    # 3 de ancho
const Y_ABAJO := 19

## las salas del piso 1 en orden (el mismo que salas_prueba: 0 es el pasillo), para el menú de pruebas
static func salas_menu() -> Array:
	var out := [["Pasillo (entrada)", "pasillo"]]
	for a in ARRIBA + ABAJO:
		out.append([a[0], a[2]])
	return out

## con qué clase se entra en cada sala: mago en la de efectos (para la bola de fuego), caballero en el resto
static func clase_de_sala(sala: int) -> String:
	var l := salas_menu()
	return "mage" if sala >= 0 and sala < l.size() and l[sala][1] == "efectos" else "knight"

static func nombre(n: int) -> String:
	if Escena3D.de_numero(n) != "":
		return String(Escena3D.datos(Escena3D.de_numero(n)).get("titulo", Escena3D.de_numero(n)))
	if DE_TEMA.has(n):
		return "Piso de prueba %d · %s" % [n, TemaMazmorra.nombre(DE_TEMA[n])]
	return NOMBRES[clampi(n - 1, 0, NOMBRES.size() - 1)]

# ======================================================================
#  mapa
# ======================================================================
static func generar(n: int) -> Dictionary:
	if Escena3D.de_numero(n) != "":   # escena hecha a mano desde su archivo de datos (assets/escenas)
		return Escena3D.generar(Escena3D.de_numero(n), n)
	if DE_TEMA.has(n):
		return _generar_tema(n, DE_TEMA[n])
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
	var x_fin := 3 + (maxi(ARRIBA.size(), ABAJO.size()) - 1) * PASO_SALAS + LADO
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
		elif salas[k].proposito == "mimico":   # un baúl de verdad y un mímico al lado, iguales por fuera
			for par in [[2, "wood"], [6, "mimic"]]:
				var c := Vector2i(salas[k].x + par[0], salas[k].y + 4)
				salas[k].puertas.append(c)
				chests.append({"cx": c.x, "cy": c.y, "kind": par[1], "room": k})
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

## piso de tema: el mapa sale del generador de siempre (sin tocarlo) como un piso de pasarelas
## sobre el abismo (los pisos 3–5); la vista lo viste con el tema (L.tema3d)
static func _generar_tema(n: int, tema: String) -> Dictionary:
	var L := DungeonGen.gen_level("piso-prueba-%d" % n, Plataformas.PISO)
	if not L.get("plataformas", false):
		Plataformas.aplicar(L)
	L.erase("estilo")
	L["tema3d"] = tema
	L["prueba"] = n
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
	if not L.has("salas_prueba"):
		return   # pisos de tema: lo pone todo la vista
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

# ======================================================================
#  sala del aprendizaje: miniboss y 4 esbirros que aprenden (Aprendizaje)
# ======================================================================
## Al entrar (y cada vez que mueren todos) sale otra ronda con los mismos puestos («prueba-1» a «prueba-5»):
## son los mismos enemigos, que recuerdan lo de las rondas anteriores. Al empezar cada ronda, vida llena.
const ARENA_ESPERA := 2.5

static func sala_arena(sim) -> Dictionary:
	for s in sim.L.get("salas_prueba", []):
		if s.proposito == "arena":
			return s
	return {}

static func arena(sim, dt: float) -> void:
	var s := sala_arena(sim)
	if s.is_empty():
		return
	var A: Dictionary = sim.L.get_or_add("arena_estado", {"ronda": 0, "t": ARENA_ESPERA})
	var vivos := 0
	for e in sim.enemies:
		if e.en_arena and not e.dying and not e.dead:
			vivos += 1
	var cx := int(sim.p.x / DungeonGen.TS)
	var cy := int((sim.p.y - 3) / DungeonGen.TS)
	var dentro: bool = cx >= s.x and cx < s.x + s.w and cy > s.y and cy < s.y + s.h
	if vivos > 0 or sim.p.dead:
		A.t = ARENA_ESPERA
		return
	if not dentro:
		A.t = minf(A.t, ARENA_ESPERA)
		return
	A.t -= dt
	if A.t > 0:
		return
	A.t = ARENA_ESPERA
	A.ronda += 1
	_ronda_arena(sim, s, int(A.ronda))

static func _ronda_arena(sim, s: Dictionary, ronda: int) -> void:
	var TS := DungeonGen.TS
	var bx: float = (s.x + 4.5) * TS
	var by: float = (s.y + s.h - 3.0) * TS
	var jefe: Ent.Enemy = sim.mon_spawn("esqueleto", bx, by)
	sim._hacer_elite(jefe)
	if jefe.poder == "invoca":   # sin invocados: en la prueba solo cuentan los 5 de siempre
		jefe.poder = "escudo"
		jefe.invoca_t = 0
		jefe.escudo_max = jefe.max_hp * .35
		jefe.escudo = jefe.escudo_max
	var grupo: Array = [jefe]
	for k in 4:
		var a := PI + (k - 1.5) * .7
		var e: Ent.Enemy = sim.mon_spawn("esqueleto", bx + cos(a) * 52, by - absf(sin(a)) * 40 - 20)
		sim.unstick(e, 8)
		grupo.append(e)
	for i in grupo.size():
		var e: Ent.Enemy = grupo[i]
		e.en_arena = true
		e.puesto = "prueba-%d" % (i + 1)
		e.apr_lider = null if i == 0 else jefe
		e.apr_clave = Aprendizaje.clave_de(e, 0)
		e.apr_titulo = sim.apr.titulo(e.puesto)
	sim.p.hp = sim.p.st.maxHp
	sim.fx.hud()
	sim.fx.banner("Ronda %d · miniboss y 4 esbirros · F3: lo que han aprendido" % ronda, "Sala del aprendizaje")

# ======================================================================
#  sala del mímico: si ya no queda mímico (ni cofre ni bicho), sale otro a los 3 s (10 nov 2026)
# ======================================================================
static func mimico(sim, dt: float) -> void:
	var s := {}
	for x in sim.L.get("salas_prueba", []):
		if x.proposito == "mimico":
			s = x
	if s.is_empty():
		return
	for c in sim.chests:
		if c.kind == "mimic":
			return
	for e in sim.enemies:
		if e.mimic and not e.dying:
			return
	var A: Dictionary = sim.L.get_or_add("mimico_estado", {"t": 3.0})
	A.t -= dt
	if A.t > 0:
		return
	A.t = 3.0
	var cx: int = s.x + 6
	var cy: int = s.y + 4
	sim.chests.append({"cx": cx, "cy": cy, "kind": "mimic", "room": null, "se": false, "x": (cx + .5) * DungeonGen.TS, "y": (cy + 1) * DungeonGen.TS - 4,
		"open": false, "open_t": 0.0, "best": 0, "guards": [], "msg_t": -9.0})

# ======================================================================
#  sala de efectos: muñecos para probar los hechizos (Hechizos3D)
# ======================================================================
## Tres filas de muñecos (esqueletos quietos): no se mueven, no atacan, no mueren y no aprenden.
## Se ven los números de daño y los efectos; la vida vuelve a llenarse sola.
const MUNECOS := [Vector2(2.5, 2.5), Vector2(4.5, 2.0), Vector2(6.5, 2.5), Vector2(1.8, 5.0), Vector2(7.2, 5.0)]

const CADAVERES := [Vector2(3.0, 6.5), Vector2(4.5, 7.0), Vector2(6.0, 6.5)]

static func sala_efectos(sim) -> Dictionary:
	for s in sim.L.get("salas_prueba", []):
		if s.proposito == "efectos":
			return s
	return {}

static func efectos(sim) -> void:
	var s := sala_efectos(sim)
	if s.is_empty():
		return
	var hay := false
	for e in sim.enemies:
		if e.muneco:
			hay = true
			# quieto en su sitio, dormido y con la vida llena (los números de daño sí salen)
			e.x = e.casa_x
			e.y = e.casa_y
			e.vx = 0
			e.vy = 0
			e.state = "idle"
			e.act = ""
			e.moving = false
			e.face = PI / 2
			e.hp = e.max_hp
			e.ghost = e.max_hp
	sim.p.mana = sim.p.st.get("maxMana", sim.p.mana)   # maná sin fin para probar
	# el caballero de la muerte necesita cadáveres para «Levantar muertos»: siempre hay 3 en el suelo
	if sim.p.dk and sim.allies.is_empty() and sim.corpses.size() < CADAVERES.size():
		var TS := DungeonGen.TS
		for c in CADAVERES:
			var x: float = (s.x + c.x) * TS
			var y: float = (s.y + c.y) * TS
			if sim.corpses.any(func(k): return absf(k.x - x) < 4 and absf(k.y - y) < 4):
				continue
			var k := {"x": x, "y": y, "face": PI / 2, "champ": false, "rare": false, "hero": "", "mon": "esqueleto"}
			sim.corpses.append(k)
			sim.fx.corpse(k)
	if hay:
		return
	var TS := DungeonGen.TS
	for c in MUNECOS:
		var e: Ent.Enemy = sim.mon_spawn("esqueleto", (s.x + c.x) * TS, (s.y + c.y) * TS)
		e.muneco = true
		e.en_arena = true      # main3d deja vivos en el piso de prueba solo a los en_arena
		e.ambush = true        # no despierta al acercarse
		e.dmg = 0
		e.max_hp = 1000000
		e.hp = e.max_hp
		e.ghost = e.max_hp
		e.xp = 0
		e.score = 0
		e.casa_x = e.x
		e.casa_y = e.y

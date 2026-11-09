class_name Ciudad
## Inca: la ciudad donde empieza la partida (inspirada en las ciudades de MU Online, con diseño propio).
## Zona segura: sin enemigos y sin atacar. Plaza con fuente, calles de adoquines, casas, puestos,
## los sitios de las tiendas (herrería, alquimia, runas y almacén; los tenderos llegan en la tanda 2),
## muralla con torres y almenas, la puerta grande (cerrada) al sur y la entrada a la mazmorra al norte.
##
## generar() hace el mapa con la forma de DungeonGen (la simulación lo usa tal cual, como PisoPrueba)
## y amueblar() monta las piezas de assets/kit/kit_ciudad.glb (tools/blender/kit_ciudad.py).
##
## Coordenadas en casillas de 2 m. El recinto va de X0..X1 y Y0..Y1 (la muralla es el borde).

const NOMBRE := "Inca"
const RUTA_GLB := "res://assets/kit/kit_ciudad.glb"
const X0 := 23
const X1 := 59
const Y0 := 14
const Y1 := 44
const CENTRO := Vector2i(41, 29)
const PORTAL := Vector2i(41, Y0)        # la casilla de bajada (DOWN), en la muralla norte
const INICIO := Vector2i(41, 34)        # donde aparece el héroe: al sur de la fuente, mirando al norte

## edificios: pieza, casilla de arriba a la izquierda, tamaño en casillas y hacia dónde mira (S, N, E, O)
const CASAS := [
	["casa_b", Vector2i(32, 18), Vector2i(4, 3), "S", "herreria"],
	["casa_b", Vector2i(47, 18), Vector2i(4, 3), "S", "alquimia"],
	["casa_b", Vector2i(32, 38), Vector2i(4, 3), "N", "runas"],
	["casa_b", Vector2i(47, 38), Vector2i(4, 3), "N", "almacen"],
	["casa_a", Vector2i(26, 16), Vector2i(2, 3), "E", ""],
	["casa_a", Vector2i(26, 22), Vector2i(2, 3), "E", ""],
	["casa_a", Vector2i(26, 33), Vector2i(2, 3), "E", ""],
	["casa_a", Vector2i(26, 39), Vector2i(2, 3), "E", ""],
	["casa_a", Vector2i(55, 16), Vector2i(2, 3), "O", ""],
	["casa_a", Vector2i(55, 22), Vector2i(2, 3), "O", ""],
	["casa_a", Vector2i(55, 33), Vector2i(2, 3), "O", ""],
	["casa_a", Vector2i(55, 39), Vector2i(2, 3), "O", ""],
	["casa_a", Vector2i(30, 15), Vector2i(3, 2), "S", ""],
	["casa_a", Vector2i(50, 15), Vector2i(3, 2), "S", ""],
	["casa_a", Vector2i(30, 42), Vector2i(3, 2), "N", ""],
	["casa_a", Vector2i(50, 42), Vector2i(3, 2), "N", ""],
]

## sitios de las tiendas: pieza de trabajo (casilla sólida), casilla del tendero (tanda 2) y rótulo
const TIENDAS := {
	"herreria": {"nombre": "Herrería", "pieza": "forja", "celda": Vector2i(35, 22), "tendero": Vector2i(34, 22), "mira": "S"},
	"alquimia": {"nombre": "Alquimia", "pieza": "mesa_alquimia", "celda": Vector2i(48, 22), "tendero": Vector2i(49, 22), "mira": "S"},
	"runas": {"nombre": "Runas", "pieza": "altar_runas", "celda": Vector2i(35, 36), "tendero": Vector2i(34, 36), "mira": "N"},
	"almacen": {"nombre": "Almacén", "pieza": "cofre_almacen", "celda": Vector2i(48, 36), "tendero": Vector2i(49, 36), "mira": "N"},
}

## adornos sueltos de una casilla (sólidos): pieza, casilla, mira
const SUELTOS := [
	["puesto_rojo", Vector2i(37, 25), "S"], ["puesto_azul", Vector2i(45, 25), "S"],
	["puesto_azul", Vector2i(37, 33), "N"], ["puesto_rojo", Vector2i(45, 33), "N"],
	["farol", Vector2i(39, 24), "S"], ["farol", Vector2i(43, 24), "S"], ["farol", Vector2i(39, 34), "S"], ["farol", Vector2i(43, 34), "S"],
	["farol", Vector2i(39, 18), "S"], ["farol", Vector2i(43, 18), "S"], ["farol", Vector2i(39, 40), "S"], ["farol", Vector2i(43, 40), "S"],
	["farol", Vector2i(30, 29), "S"], ["farol", Vector2i(52, 29), "S"],
	["arbol", Vector2i(29, 20), "S"], ["arbol", Vector2i(53, 20), "S"], ["arbol", Vector2i(29, 37), "S"], ["arbol", Vector2i(53, 37), "S"],
	["arbol", Vector2i(25, 28), "S"], ["arbol", Vector2i(57, 30), "S"],
	["banco", Vector2i(36, 29), "E"], ["banco", Vector2i(46, 29), "O"],
]
## barriles y cajas del kit de la mazmorra junto a las casas (no estorban: no son sólidos)
const BULTOS := [["barril", Vector2(30.3, 18.4)], ["caja", Vector2(30.6, 19.3)], ["barril", Vector2(36.6, 20.3)],
	["caja", Vector2(52.4, 18.6)], ["barril", Vector2(51.7, 20.4)], ["barril", Vector2(31.3, 37.2)], ["caja", Vector2(52.3, 37.4)],
	["barril", Vector2(28.5, 25.6)], ["caja", Vector2(54.4, 26.3)], ["barril", Vector2(54.6, 35.5)]]

const GIRO := {"S": 0.0, "N": PI, "E": PI / 2, "O": -PI / 2}

static func es_ciudad(L: Dictionary) -> bool:
	return L.has("ciudad")

# ======================================================================
#  mapa
# ======================================================================
static func generar() -> Dictionary:
	var L := DungeonGen.gen_level("ciudad-inca", 1)
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
	for y in range(Y0 + 1, Y1):
		for x in range(X0 + 1, X1):
			G[y * W + x] = DungeonGen.FLOOR
			room_of[y * W + x] = 0
			mano[y * W + x] = MazmorraGridMap.A_MANO_SUELO
	var solido := func(c: Vector2i) -> void:
		G[c.y * W + c.x] = DungeonGen.DECOR
		mano[c.y * W + c.x] |= MazmorraGridMap.A_MANO_OBJETO
	for c in CASAS:
		for dy in c[2].y:
			for dx in c[2].x:
				solido.call(c[1] + Vector2i(dx, dy))
	for k in TIENDAS:
		solido.call(TIENDAS[k].celda)
	for s in SUELTOS:
		solido.call(s[1])
	for dy in 3:
		for dx in 3:
			solido.call(CENTRO + Vector2i(dx - 1, dy - 1))   # la fuente
	for c in [Vector2i(X0 + 1, Y0 + 1), Vector2i(X1 - 1, Y0 + 1), Vector2i(X0 + 1, Y1 - 1), Vector2i(X1 - 1, Y1 - 1)]:
		solido.call(c)   # la parte de las torres que entra en el recinto
	# la entrada a la mazmorra (3 casillas de muralla montadas a mano; la del centro baja)
	for dx in [-1, 0, 1]:
		mano[PORTAL.y * W + PORTAL.x + dx] = MazmorraGridMap.A_MANO_MURO
	for dx in [-1, 0, 1]:   # detrás de la escalera, nada (si no, se ven los muros de fuera por el hueco)
		mano[(PORTAL.y - 1) * W + PORTAL.x + dx] = MazmorraGridMap.A_MANO_MURO
	G[PORTAL.y * W + PORTAL.x] = DungeonGen.DOWN
	room_of[PORTAL.y * W + PORTAL.x] = 0
	mano[PORTAL.y * W + PORTAL.x] = MazmorraGridMap.A_MANO_SUELO | MazmorraGridMap.A_MANO_OBJETO
	# la puerta grande del sur (cerrada)
	for dx in [-1, 0, 1]:
		mano[Y1 * W + CENTRO.x + dx] = MazmorraGridMap.A_MANO_MURO
	var inicio := {"cx": INICIO.x, "cy": INICIO.y}
	var corr := PackedByteArray()
	corr.resize(W * H)
	for clave in ["plataformas", "tramos", "escaleras", "esc_mask", "alt", "pozos", "p5_obj", "_esc_idx", "torches_px", "keyrings", "estilo"]:
		L.erase(clave)
	L.merge({"grid": G, "room_of": room_of, "corr": corr,
		"rooms": [{"x": X0 + 1, "y": Y0 + 1, "w": X1 - X0 - 1, "h": Y1 - Y0 - 1, "cx": CENTRO.x, "cy": CENTRO.y}], "room_num": [1],
		"start_room": 0, "end_room": 0, "grave_room": -1, "start": inicio,
		"stairs_cell": {"cx": PORTAL.x, "cy": PORTAL.y}, "stairs_px": {"x": (PORTAL.x + .5) * DungeonGen.TS, "y": (PORTAL.y + .5) * DungeonGen.TS},
		"fount": null, "torches": [], "decor": [], "litter": [], "wall_deco": [], "wall_veg": [], "flats": [],
		"chests": [], "gold": [], "doors": [], "key_tables": [], "deco": {},
		"dist": PisoPrueba._distancias(G, inicio, W, H), "a_mano": mano, "estilo_roca": {}, "ciudad": NOMBRE}, true)
	return L

## deja la ciudad sin nada de mazmorra (enemigos, cofres, rompibles, trampas, reto): zona segura
static func vaciar(sim: Sim) -> void:
	sim.enemies.clear()
	sim.allies.clear()
	sim.chests.clear()
	sim.loot.clear()
	sim.gold.clear()
	sim.rompibles.clear()
	sim.trampas.clear()
	sim.reto = {}
	sim.cleared = true
	sim.total = 0
	# todo el recinto se ve en el mapa
	for y in range(Y0, Y1 + 1):
		for x in range(X0, X1 + 1):
			sim.explored[y * DungeonGen.GW + x] = 1
	sim.map_dirty = true

static func en_portal(sim: Sim) -> bool:
	return sim.tile_at(sim.cell_of(sim.p.x), sim.cell_of(sim.p.y - 3)) == DungeonGen.DOWN

## aparta al héroe de la entrada (al cancelar la elección de piso)
static func salir_del_portal(sim: Sim) -> void:
	sim.p.x = (PORTAL.x + .5) * DungeonGen.TS
	sim.p.y = (PORTAL.y + 2.2) * DungeonGen.TS
	sim.unstick(sim.p)

# ======================================================================
#  montaje 3D
# ======================================================================
static var _mallas := {}
static var _mats := {}

static func limpiar() -> void:
	_mallas.clear()
	_mats.clear()

static func malla(nombre: String) -> Mesh:
	if _mallas.is_empty():
		_cargar()
	return _mallas.get(nombre)

static func pieza(nombre: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = malla(nombre)
	return mi

static func _cargar() -> void:
	if not ResourceLoader.exists(RUTA_GLB):
		push_warning("Sin kit de la ciudad: " + RUTA_GLB)
		_mallas["-"] = null
		return
	var raiz: Node = (load(RUTA_GLB) as PackedScene).instantiate()
	for mi in raiz.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh.duplicate()
		for s in m.get_surface_count():
			var orig := m.surface_get_material(s)
			m.surface_set_material(s, material(orig.resource_name if orig != null else ""))
		_mallas[String(mi.name)] = m
	raiz.free()

## material de Godot para cada material de Blender (los de piedra, revoque y teja se traman al tapar al héroe)
static func material(nombre: String) -> Material:
	if _mats.has(nombre):
		return _mats[nombre]
	var m: Material
	match nombre:
		"piedra", "madera", "hierro", "oro", "brasa", "tela":
			m = KitMazmorra.material(nombre)
		"revoque": m = _tramado(Color(.86, .8, .68))
		"teja": m = _tramado(Color(.66, .3, .2))
		"adoquin": m = KitMazmorra._piedra(Color(.5, .5, .5), .8)
		"junta": m = KitMazmorra._liso(Color(.06, .055, .05), 1.0)
		"sombra": m = KitMazmorra._liso(Color(.035, .03, .028), 1.0)
		"negro":
			var n := StandardMaterial3D.new()
			n.albedo_color = Color.BLACK
			n.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m = n
		"ventana": m = _brilla(Color(1, .62, .3), Color(1, .55, .2), 2.2)
		"runa": m = _brilla(Color(.3, .05, .02), Color(1, .3, .08), 3.0)
		"runa_azul": m = _brilla(Color(.05, .1, .3), Color(.3, .55, 1), 3.0)
		"vidrio_rojo": m = _brilla(Color(.4, .03, .03), Color(1, .15, .1), 1.6)
		"vidrio_azul": m = _brilla(Color(.05, .1, .4), Color(.2, .4, 1), 1.6)
		"vidrio_verde": m = _brilla(Color(.05, .3, .1), Color(.2, 1, .35), 1.6)
		"agua":
			var a := StandardMaterial3D.new()
			a.albedo_color = Color(.22, .42, .48)
			a.roughness = .12
			a.metallic = 0.0
			a.emission_enabled = true
			a.emission = Color(.04, .1, .12)
			a.normal_enabled = true
			a.normal_texture = KitMazmorra._ruido(.2, true)
			a.uv1_triplanar = true
			a.uv1_scale = Vector3(.8, .8, .8)
			m = a
		"tela_roja", "tela_azul", "tela_clara":
			var c: Color = {"tela_roja": Color(.62, .07, .05), "tela_azul": Color(.1, .2, .55), "tela_clara": Color(.86, .8, .66)}[nombre]
			var t := KitMazmorra._liso(c, .9)
			t.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = t
		"hoja": m = KitMazmorra._piedra(Color(.24, .4, .14), .9)
		"corteza": m = KitMazmorra._piedra(Color(.32, .22, .14), .9)
		"mimbre": m = KitMazmorra._piedra(Color(.6, .45, .24), .9)
		_: m = KitMazmorra.material(nombre)
	_mats[nombre] = m
	return m

static func _tramado(c: Color) -> ShaderMaterial:
	var m := KitMazmorra.material_muro()
	m.set_shader_parameter("color", c)
	return m

static func _brilla(c: Color, e: Color, energia: float) -> StandardMaterial3D:
	var m := KitMazmorra._liso(c, .4)
	m.emission_enabled = true
	m.emission = e
	m.emission_energy_multiplier = energia
	return m

static func _poner(raiz: Node3D, nombre: String, pos: Vector3, giro: float = 0.0) -> MeshInstance3D:
	var n := pieza(nombre)
	n.position = pos
	n.rotation.y = giro
	raiz.add_child(n)
	return n

static func _centro_rect(c: Vector2i, t: Vector2i) -> Vector3:
	return Vector3((c.x + t.x / 2.0) * KitMazmorra.CELDA, 0, (c.y + t.y / 2.0) * KitMazmorra.CELDA)

static func amueblar(L: Dictionary, M: MazmorraGridMap) -> void:
	var raiz := M.adornos
	var W := DungeonGen.GW
	var CEL := KitMazmorra.CELDA
	var G: PackedByteArray = L.grid
	# campo de fuera de la muralla y camino que sale de la puerta
	var campo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(W * CEL + 80, DungeonGen.GH * CEL + 80)
	var hierba := KitMazmorra._piedra(Color(.2, .25, .12), .95)
	hierba.vertex_color_use_as_albedo = false
	pm.material = hierba
	campo.mesh = pm
	campo.position = Vector3(W * CEL / 2, -.06, DungeonGen.GH * CEL / 2)
	raiz.add_child(campo)
	var camino := MeshInstance3D.new()
	var cm := PlaneMesh.new()
	cm.size = Vector2(5, (DungeonGen.GH - Y1) * CEL + 40)
	var tierra := KitMazmorra._piedra(Color(.36, .3, .22), .95)
	tierra.vertex_color_use_as_albedo = false
	cm.material = tierra
	camino.mesh = cm
	camino.position = Vector3((CENTRO.x + .5) * CEL, -.04, (Y1 + 1) * CEL + cm.size.y / 2)
	raiz.add_child(camino)
	# adoquines en todo el recinto (MultiMesh: dos variantes, giradas al azar)
	var celdas: Array[Vector2i] = []
	for y in range(Y0 + 1, Y1):
		for x in range(X0 + 1, X1):
			celdas.append(Vector2i(x, y))
	celdas.append(PORTAL)
	for v in ["adoquines", "adoquines_b"]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = malla(v)
		var mias := celdas.filter(func(c): return (absi(hash(c)) % 2 == 0) == (v == "adoquines"))
		mm.instance_count = mias.size()
		for i in mias.size():
			var c: Vector2i = mias[i]
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, (absi(hash(c * 7)) % 4) * PI / 2), MazmorraGridMap.centro(c)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		raiz.add_child(mmi)
	# casas y tiendas
	for c in CASAS:
		_poner(raiz, c[0], _centro_rect(c[1], c[2]), GIRO[c[3]])
	for k in TIENDAS:
		var T: Dictionary = TIENDAS[k]
		var pos := MazmorraGridMap.centro(T.celda)
		_poner(raiz, T.pieza, pos, GIRO[T.mira])
		if T.pieza == "forja":
			M.fuego_y_luz(pos + Vector3(-.4, 1.0, .2).rotated(Vector3.UP, GIRO[T.mira]), .5, 2.2, 6.0)
		var luz_t := OmniLight3D.new()
		luz_t.light_color = {"herreria": Color(1, .55, .25), "alquimia": Color(.5, 1, .55), "runas": Color(.45, .65, 1), "almacen": Color(1, .85, .55)}[k]
		luz_t.light_energy = 1.2
		luz_t.omni_range = 4.5
		luz_t.position = pos + Vector3(0, 1.6, 0)
		raiz.add_child(luz_t)
		var r := Label3D.new()
		r.text = T.nombre
		r.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		r.font = Fonts.gothic(700)
		r.font_size = 72
		r.pixel_size = .01
		r.outline_size = 14
		r.modulate = Color(1, .86, .55)
		r.position = pos + Vector3(0, 3.0, 0)
		raiz.add_child(r)
	for s in SUELTOS:
		var pos := MazmorraGridMap.centro(s[1])
		_poner(raiz, s[0], pos, GIRO[s[2]] + (randf() * .3 - .15 if s[0] == "arbol" else 0.0))
		if s[0] == "farol":
			var luz := OmniLight3D.new()
			luz.light_color = Color(1, .7, .4)
			luz.light_energy = 1.8
			luz.omni_range = 9.0
			luz.omni_attenuation = 1.3
			luz.position = pos + Vector3(0, 2.8, 0)
			raiz.add_child(luz)
	for b in BULTOS:
		var n := KitMazmorra.pieza(b[0])
		n.position = Vector3(b[1].x * CEL, 0, b[1].y * CEL)
		n.rotation.y = hash(b[1]) % 7
		raiz.add_child(n)
	# fuente
	_poner(raiz, "fuente", Vector3((CENTRO.x + .5) * CEL, 0, (CENTRO.y + .5) * CEL))
	# muralla: almenas encima de cada casilla del borde (mirando hacia fuera) y torres en las esquinas
	for x in range(X0, X1 + 1):
		for y in [Y0, Y1]:
			if absi(x - CENTRO.x) <= 1:
				continue
			_poner(raiz, "almenas", MazmorraGridMap.centro(Vector2i(x, y)) + Vector3(0, 3.35, 0), PI if y == Y0 else 0.0)
	for y in range(Y0 + 1, Y1):
		_poner(raiz, "almenas", MazmorraGridMap.centro(Vector2i(X0, y)) + Vector3(0, 3.35, 0), -PI / 2)
		_poner(raiz, "almenas", MazmorraGridMap.centro(Vector2i(X1, y)) + Vector3(0, 3.35, 0), PI / 2)
	for c in [Vector2i(X0, Y0), Vector2i(X1, Y0), Vector2i(X0, Y1), Vector2i(X1, Y1)]:
		var dentro := Vector3(signf(CENTRO.x - c.x), 0, signf(CENTRO.y - c.y)) * .5
		_poner(raiz, "torre", MazmorraGridMap.centro(c) + dentro)
	# entrada a la mazmorra (norte) y puerta grande (sur)
	var portal := MazmorraGridMap.centro(PORTAL)
	_poner(raiz, "portal_mazmorra", portal)
	for lado in [-1, 1]:
		M.fuego_y_luz(portal + Vector3(lado * 2.25, 5.5, .1), .6, 2.6, 9.0)
	var luz_p := OmniLight3D.new()
	luz_p.light_color = Color(1, .3, .1)
	luz_p.light_energy = 2.0
	luz_p.omni_range = 6.0
	luz_p.position = portal + Vector3(0, 1.2, 1.6)
	raiz.add_child(luz_p)
	var rp := Label3D.new()
	rp.text = "La Mazmorra"
	rp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rp.font = Fonts.gothic(700)
	rp.font_size = 80
	rp.pixel_size = .01
	rp.outline_size = 14
	rp.modulate = Color(1, .55, .35)
	rp.position = portal + Vector3(0, 6.6, 1.0)
	raiz.add_child(rp)
	_poner(raiz, "puerta_ciudad", MazmorraGridMap.centro(Vector2i(CENTRO.x, Y1)))
	# árboles fuera de la muralla
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 60:
		var x := rng.randf_range(X0 - 18, X1 + 18)
		var y := rng.randf_range(Y0 - 12, Y1 + 14)
		if x > X0 - 3 and x < X1 + 3 and y > Y0 - 3 and y < Y1 + 3:
			continue
		if absf(x - CENTRO.x - .5) < 3 and y > Y1:
			continue
		var a := _poner(raiz, "arbol", Vector3(x * CEL, 0, y * CEL), rng.randf() * TAU)
		a.scale = Vector3.ONE * rng.randf_range(.8, 1.35)
	# sol de la tarde (cálido y bajo) para que la ciudad se vea clara
	var sol := DirectionalLight3D.new()
	sol.rotation = Vector3(deg_to_rad(-38), deg_to_rad(-140), 0)
	sol.light_color = Color(1, .8, .58)
	sol.light_energy = 1.1
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 60
	raiz.add_child(sol)

## ambiente de la ciudad (más luz y menos niebla) o el de la mazmorra
static var _antes := {}

static func ambiente(e: Environment, ciudad: bool) -> void:
	if ciudad:
		if _antes.is_empty():
			_antes = {"bg": e.background_color, "amb": e.ambient_light_energy, "ambc": e.ambient_light_color, "niebla": e.volumetric_fog_density}
		e.background_color = Color(.09, .1, .14)
		e.ambient_light_color = Color(.62, .6, .66)
		e.ambient_light_energy = .75
		e.volumetric_fog_density = .004
	elif not _antes.is_empty():
		e.background_color = _antes.bg
		e.ambient_light_energy = _antes.amb
		e.ambient_light_color = _antes.ambc
		e.volumetric_fog_density = _antes.niebla
		_antes.clear()

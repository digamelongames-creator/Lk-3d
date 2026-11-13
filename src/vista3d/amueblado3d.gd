class_name Amueblado3D
## Los muebles del Decorador (L.p5_obj, casillas DECOR que chocan en la simulación) con piezas 3D de verdad
## en lugar de la caja «mueble» del kit: barriles, cajas, baúles, urnas, escombros y columnas rotas,
## de espaldas a la pared que tienen al lado. Cada nombre de la hoja de Diego tiene sus piezas (PIEZAS);
## la elegida y su giro salen de la casilla (siempre igual en el mismo piso).

## nombre del Decorador → [[paquete, pieza, escala], …] (una al azar por casilla)
const PIEZAS := {
	"barril": [["dungeon_kit", "barril", 1.0]],
	"barril_2": [["dungeon_kit", "barril_abierto", 1.0]],
	"barril_3": [["dungeon_kit", "barril_roto", 1.0]],
	"caja": [["low_poly", "wooden_box_006", 1.3], ["low_poly", "wooden_box_007", 1.3], ["low_poly", "wooden_box", 1.5]],
	"cubo": [["low_poly", "wooden_box", 1.2]],
	"cubo_2": [["low_poly", "wooden_box_007", 1.1]],
	"cofre_largo": [["low_poly", "chest_bottom", .9]],
	"escombro": [["low_poly", "debris", .75]],
	"escombro_2": [["low_poly", "rock_002", .7]],
	"escombro_3": [["low_poly", "rock", .75]],
	"escombro_4": [["polyhaven", "roca_musgo_8", .8]],
	"escombro_5": [["low_poly", "bricks", 1.0], ["low_poly", "bricks_001", 1.0]],
	"columna_rota": [["ruinas", "pillar2", 1.0]],
	"columna_rota_2": [["ruinas", "pillar8", 1.0]],
	"columna_rota_3": [["ruinas", "pilar7", 1.0]],
	"columna_rota_4": [["ruinas", "pillar2", 1.0]],
	# los del generador (L.decor, nombres del juego web); las mesas siguen con la caja del kit
	"barrel_large": [["dungeon_kit", "barril", 1.1]],
	"barrel_small_stack": [["dungeon_kit", "barril", .85], ["dungeon_kit", "barril_abierto", .85]],
	"barrel_large_decorated": [["dungeon_kit", "barril_abierto", 1.1]],
	"keg_decorated": [["dungeon_kit", "barril_roto", 1.0]],
	"crates_stacked": [["low_poly", "wooden_box_006", 1.5]],
	"box_stacked": [["low_poly", "wooden_box_007", 1.4]],
	"box_large": [["low_poly", "wooden_box", 1.7]],
	"rubble_large": [["low_poly", "debris", .7], ["low_poly", "rock_002", .7]],
}
## altura a la que se cortan las columnas rotas (m): se aplastan a esta altura
const ALTO_COLUMNA_ROTA := 1.5
const URNAS := ["jarra", "jarra_2", "jarra_3", "jarra_4", "jarra_5", "vasija"]

static var _urna: Mesh

static func limpiar() -> void:
	_urna = null

## casillas cuyo mueble se pone aquí (MazmorraGridMap no les pone la caja)
static func casillas(L: Dictionary) -> Dictionary:
	var out := {}
	for o in L.get("decor", []):
		if o is Dictionary and o.has("cx") and PIEZAS.has(String(o.get("n", ""))):
			out[Vector2i(int(o.cx), int(o.cy))] = o
	for o in L.get("p5_obj", []):
		if o.get("deco", false) and not o.get("plano", false) and (PIEZAS.has(String(o.n)) or URNAS.has(String(o.n))):
			out[Vector2i(int(o.cx), int(o.cy))] = o
	return out

static func poner(m: MazmorraGridMap, L: Dictionary, cuales: Dictionary) -> void:
	var G: PackedByteArray = L.grid
	var GW := DungeonGen.GW
	for c in cuales:
		var o: Dictionary = cuales[c]
		var h := absi(hash(c))
		# de espaldas a la pared más cercana (las piezas miran a +Z)
		var giro := 0.0
		for par in [[Vector2i(0, -1), 0.0], [Vector2i(-1, 0), PI / 2], [Vector2i(1, 0), -PI / 2], [Vector2i(0, 1), PI]]:
			var v: Vector2i = par[0]
			if G[(c.y + v.y) * GW + c.x + v.x] == DungeonGen.ROCK:
				giro = par[1]
				break
		giro += ((h % 7) - 3) * .06
		var base := MazmorraGridMap.centro(c)
		if URNAS.has(String(o.n)):   # urnas de barro: un grupito de 1 a 3
			for i in 1 + h % 3:
				var u := MeshInstance3D.new()
				u.mesh = _malla_urna()
				var e := .8 + ((h >> (i * 3)) % 5) * .12
				u.scale = Vector3(e, e, e)
				u.position = base + Vector3((i - 1) * .42, 0, ((h >> i) % 3 - 1) * .2)
				m.adornos.add_child(u)
			continue
		var lista: Array = PIEZAS[String(o.n)]
		var elegido: Array = lista[h % lista.size()]
		var p := Props3D.crear(elegido[0], elegido[1])
		if p == null:
			continue
		var e: float = elegido[2]
		p.scale = Vector3(e, e, e)
		if String(o.n).begins_with("columna_rota"):
			var alto := Props3D.alto(elegido[0], elegido[1])
			if alto > ALTO_COLUMNA_ROTA:
				p.scale.y = ALTO_COLUMNA_ROTA / alto
		p.rotation.y = giro
		p.position = base
		m.adornos.add_child(p)

## urna de barro torneada (la misma forma que las rompibles de Actores3D)
static func _malla_urna() -> Mesh:
	if _urna != null:
		return _urna
	var perfil := [Vector2(0, 0), Vector2(.17, 0), Vector2(.2, .05), Vector2(.3, .22), Vector2(.34, .38), Vector2(.3, .55),
		Vector2(.18, .68), Vector2(.14, .76), Vector2(.19, .82), Vector2(.17, .85), Vector2(.12, .8)]
	var lados := 18
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in perfil.size() - 1:
		for j in lados:
			var a0 := TAU * j / lados
			var a1 := TAU * (j + 1) / lados
			var p0: Vector2 = perfil[i]
			var p1: Vector2 = perfil[i + 1]
			var v00 := Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var v01 := Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var v10 := Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var v11 := Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			st.add_vertex(v00); st.add_vertex(v10); st.add_vertex(v11)
			st.add_vertex(v00); st.add_vertex(v11); st.add_vertex(v01)
	st.generate_normals()
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.5, .3, .2)
	mat.roughness = .85
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mat)
	_urna = m
	return m

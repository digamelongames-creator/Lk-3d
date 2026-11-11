class_name Inframundo3D
## Las piezas de Tripo del Inframundo (assets/props/inframundo.glb, Props3D) colocadas sobre un piso con el tema:
##   · pilar retorcido en las esquinas de dentro de las salas (en lugar de la columna del kit),
##   · muro con calavera en lugar de algunas caras de muro (las de nicho y arco ciego),
##   · puerta demoníaca en todas las puertas (en lugar del arco del kit), con dos braseros de piedra,
##   · remates en punta encima de los muros y en los bordes de las pasarelas,
##   · rocas bajo los bordes de las pasarelas y estalagmitas que salen de la lava.
## MazmorraGridMap pregunta aquí qué casillas no pone (caras, esquinas y arcos) y al final llama a amueblar().
## Solo lee la rejilla: la simulación no cambia (las piezas no estorban al andar).

const P := "inframundo"
const LEJOS := 60.0   # m: a más distancia de la cámara no se dibujan (rendimiento)
const BRASERO_FUEGO := 1.22   # altura del cuenco del brasero de piedra

static func activo(tema: String) -> bool:
	return tema == "inframundo" and Props3D.hay(P)

## la cara k de este muro lleva el muro con calavera (y la cara del kit no se pone)
static func cara_calavera(cx: int, cy: int, k: int, cara: String) -> bool:
	return cara in ["cara_nicho", "cara_arco_ciego"] or (cara == "cara_rota" and (cx + cy) % 2 == 0)

static func _poner(M: MazmorraGridMap, pieza: String, pos: Vector3, giro: float = 0.0, escala: float = 1.0) -> MeshInstance3D:
	var n := Props3D.crear(P, pieza)
	if n == null:
		return null
	n.position = pos
	n.rotation.y = giro
	if escala != 1.0:
		n.scale = Vector3.ONE * escala
	n.visibility_range_end = LEJOS
	M.adornos.add_child(n)
	return n

## giro para que el frente de la pieza (+Z) mire hacia d
static func giro_hacia(d: Vector2i) -> float:
	return atan2(float(d.x), float(d.y))

static func pilar(M: MazmorraGridMap, esquina: Vector3) -> void:
	_poner(M, "pilar_retorcido", esquina, (absi(hash(esquina)) % 4) * PI / 2)

static func muro_calavera(M: MazmorraGridMap, cx: int, cy: int, d: Vector2i) -> void:
	var c := MazmorraGridMap.centro(Vector2i(cx, cy))
	# la espalda contra la cara del muro (medio metro dentro del núcleo)
	_poner(M, "muro_calavera", c + Vector3(d.x, 0, d.y) * (KitMazmorra.CELDA / 2 - .25), giro_hacia(d))

## puerta demoníaca y sus dos braseros; este_oeste: el paso va de este a oeste
static func puerta(M: MazmorraGridMap, cx: int, cy: int, este_oeste: bool) -> void:
	var c := MazmorraGridMap.centro(Vector2i(cx, cy))
	var frente := Vector2i(1, 0) if este_oeste else Vector2i(0, 1)   # mira hacia la cámara (este o sur)
	_poner(M, "puerta_demoniaca", c, giro_hacia(frente))
	var lado := Vector3(frente.y, 0, frente.x)   # a lo largo del muro
	var delante := Vector3(frente.x, 0, frente.y)
	for s in [-1.0, 1.0]:
		var p: Vector3 = c + lado * float(s) * 1.85 + delante * 1.05
		_poner(M, "brasero_piedra", p, giro_hacia(frente))
		M.fuego_sin_luz(p + Vector3(0, BRASERO_FUEGO, 0), .22)
	# una luz para los dos braseros
	M.fuego_luz(c + delante * 1.3 + Vector3(0, BRASERO_FUEGO + .6, 0), 3.0, 9.0)

## remates, rocas y estalagmitas: bordes de las pasarelas y encima de los muros
static func amueblar(L: Dictionary, M: MazmorraGridMap) -> void:
	var G: PackedByteArray = L.grid
	var W := DungeonGen.GW
	var H := DungeonGen.GH
	var C := KitMazmorra.CELDA
	var lava_y: float = TemaMazmorra.dato("inframundo", "lava_y", -5.5)
	var es := func(x: int, y: int, t: int) -> bool:
		return x >= 0 and y >= 0 and x < W and y < H and G[y * W + x] == t
	for cy in H:
		for cx in W:
			var t := G[cy * W + cx]
			var h := absi(hash(Vector2i(cx * 31, cy * 17)))
			if t == DungeonGen.ROCK:
				# remate encima de algunos muros que se ven (los que tienen cara)
				if h % 5 == 0 and M.tiene_cara(cx, cy):
					_poner(M, "remate_punta", MazmorraGridMap.centro(Vector2i(cx, cy)) + Vector3(0, KitMazmorra.ALTO_MURO, 0), (h % 4) * PI / 2, .8)
				continue
			if t == DungeonGen.ABISMO:
				continue
			# casilla con suelo: sus bordes con el vacío
			for d in MazmorraGridMap.DIRS:
				if not es.call(cx + d.x, cy + d.y, DungeonGen.ABISMO):
					continue
				var borde: Vector3 = MazmorraGridMap.centro(Vector2i(cx, cy)) + Vector3(d.x, 0, d.y) * C / 2
				var k := absi(hash(Vector3i(cx, cy, d.x * 3 + d.y)))
				if k % 3 == 0:   # pináculo en el borde, como el pretil de la imagen
					_poner(M, "remate_punta", borde + Vector3(d.x, 0, d.y) * .25, giro_hacia(d), .9 + (k % 5) * .06)
				if k % 4 == 1:   # roca bajo el borde, para que no sea recto
					_poner(M, "roca_borde", borde + Vector3(d.x, -1.25, d.y) + Vector3(d.x, 0, d.y) * .3, (k % 8) * PI / 4, 1.0 + (k % 3) * .15)
				if k % 6 == 2:   # estalagmita que sale de la lava, más lejos del borde
					var lejos := 2.5 + (k % 5) * .7
					var off := Vector3(-d.y, 0, d.x) * ((k % 7) - 3) * .4
					_poner(M, "estalagmitas", Vector3(borde.x, lava_y - .3, borde.z) + Vector3(d.x, 0, d.y) * lejos + off,
						(k % 6) * PI / 3, 2.2 + (k % 4) * .35)

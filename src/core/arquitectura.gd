class_name Arquitectura
## Etapa del generador (DungeonGen._post), entre el plano y el Decorador: el «creador de mundos» en cascada.
##   1. papel de cada sala (capilla, osario, salón…; Decorador._papeles), que deciden lo demás
##   2. rasgos que cambian la forma de la sala sin cerrar caminos: columnata, esquinas achaflanadas, estanques
##   3. muros: cuáles son bajos (los del lado de la cámara) y qué cara lleva cada tramo de muro alto
## Todo con su propio azar (semilla + «#arq»): cada cliente del online sale igual sin mandar nada.
## Deja L.papeles, L.rasgos y L.arq = {"bajo": PackedByteArray por casilla, "caras": {"cx,cy,k": pieza}}.
## Los rasgos tocan la rejilla (los pilares y el agua chocan en la simulación); se deshacen si cortan un camino.

static var ACTIVO := true
## la cámara mira desde el sureste (CamaraIso.giro 45°): los muros con suelo al norte o al oeste lo tapan
## y se hacen bajos; los altos (suelo al sur o al este) nunca tapan nada que se pise
const LADOS_BAJOS := [Vector2i(0, -1), Vector2i(-1, 0)]
const DIRS := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]   # como MazmorraGridMap.DIRS

static func aplicar(L: Dictionary) -> void:
	if not ACTIVO or L.get("plataformas", false):
		return
	var R := Mulberry32.new(JS.hash_str(String(L.seed) + "#arq" + str(int(L.wave))))
	var papeles := Decorador._papeles(L, R, Decorador.reglas())
	L["papeles"] = papeles
	L["rasgos"] = {}
	var ocup := Decorador._ocupado(L)
	for t in L.get("torches", []):
		ocup[int(t.cy) * DungeonGen.GW + int(t.cx)] = 1
	for k in L.rooms.size():
		_rasgos(L, k, String(papeles[k]), R, ocup)
	L["arq"] = {"bajo": _bajos(L)}
	L.arq["caras"] = _caras(L, papeles)

# ---------------------------------------------------------------- 2. rasgos

static func _rasgos(L: Dictionary, k: int, papel: String, R: Mulberry32, ocup: PackedByteArray) -> void:
	if k == L.start_room or k == int(L.get("grave_room", -1)):
		return
	var r: Dictionary = L.rooms[k]
	var lista: Array = []
	# columnata: dos filas simétricas de pilares a 2 casillas de las paredes (quedan pasos de 2 a los lados)
	if r.w >= 8 and r.h >= 7 and papel in ["salon", "capilla", "cripta", "guarida", "entrada", "santuario"] and R.next() < .65:
		var c := []
		var y := int(r.y) + 2
		while y <= int(r.y) + int(r.h) - 3:
			c.append(Vector2i(int(r.x) + 2, y))
			c.append(Vector2i(int(r.x) + int(r.w) - 3, y))
			y += 2
		lista.append(["columnata", c, DungeonGen.PILLAR])
	# estanques: dos simétricos a los lados del centro (la casilla del centro queda libre)
	if r.w >= 9 and r.h >= 6 and papel in ["salon", "ruina", "osario", "almacen", "cripta"] and R.next() < .35:
		var c := []
		var y0 := int(r.cy) - 1
		for xx in [int(r.x) + 2, int(r.x) + int(r.w) - 4]:
			for dy in 2:
				for dx in 2:
					c.append(Vector2i(xx + dx, y0 + dy))
		lista.append(["estanques", c, DungeonGen.WATER])
	# esquinas achaflanadas: la sala deja de ser un rectángulo
	if r.w >= 7 and r.h >= 6 and R.next() < .5:
		var c := []
		for e in [Vector2i(r.x, r.y), Vector2i(r.x + r.w - 1, r.y), Vector2i(r.x, r.y + r.h - 1), Vector2i(r.x + r.w - 1, r.y + r.h - 1)]:
			c.append(e)
		lista.append(["chaflan", c, DungeonGen.ROCK])
	for rasgo in lista:
		_probar(L, k, rasgo[0], rasgo[1], rasgo[2], ocup)

## pone el rasgo si todas sus casillas están libres, lejos de puertas y pasillos, y no corta ningún camino
static func _probar(L: Dictionary, k: int, nombre: String, celdas: Array, tipo: int, ocup: PackedByteArray) -> void:
	var G: PackedByteArray = L.grid
	var GW := DungeonGen.GW
	for c in celdas:
		var i: int = c.y * GW + c.x
		if G[i] != DungeonGen.FLOOR or ocup[i] or L.room_of[i] != k:
			return
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var j: int = (c.y + dy) * GW + c.x + dx
				if G[j] == DungeonGen.DOOR or L.corr[j] or (L.room_of[j] != k and DungeonGen.walk(G[j])):
					return   # junto a una puerta o un pasillo: no estorbar el paso
	var antes := _alcanzables(L)
	for c in celdas:
		G[c.y * GW + c.x] = tipo
	if _alcanzables(L) != antes - celdas.size():
		for c in celdas:
			G[c.y * GW + c.x] = DungeonGen.FLOOR
		return
	for c in celdas:
		var i: int = c.y * GW + c.x
		ocup[i] = 1
		if tipo == DungeonGen.ROCK:
			L.room_of[i] = -1
	if not L.rasgos.has(k):
		L.rasgos[k] = []
	L.rasgos[k].append(nombre)

## distancias desde (sx, sy) andando; las puertas se cruzan (DungeonGen._bfs las trata como muro)
static func bfs(grid: PackedByteArray, sx: int, sy: int) -> PackedInt32Array:
	var GW := DungeonGen.GW
	var d := PackedInt32Array()
	d.resize(DungeonGen.N)
	d.fill(-1)
	var q := PackedInt32Array([sy * GW + sx])
	d[q[0]] = 0
	var h := 0
	while h < q.size():
		var i := q[h]
		h += 1
		var x := i % GW
		var y := i / GW
		for v in DIRS:
			var nx: int = x + v.x
			var ny: int = y + v.y
			if nx < 0 or ny < 0 or nx >= GW or ny >= DungeonGen.GH:
				continue
			var j := ny * GW + nx
			if d[j] < 0 and (DungeonGen.walk(grid[j]) or grid[j] == DungeonGen.DOOR):
				d[j] = d[i] + 1
				q.append(j)
	return d

static func _alcanzables(L: Dictionary) -> int:
	var n := 0
	for v in bfs(L.grid, int(L.start.cx), int(L.start.cy)):
		if v >= 0:
			n += 1
	return n

# ---------------------------------------------------------------- 3. muros

static func _pisable(G: PackedByteArray, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= DungeonGen.GW or y >= DungeonGen.GH:
		return false
	var t := G[y * DungeonGen.GW + x]
	return t != DungeonGen.ROCK and t != DungeonGen.ABISMO

## 1 = muro bajo: roca con algo pisable (o una puerta) al norte, al oeste o en la diagonal noroeste
static func _bajos(L: Dictionary) -> PackedByteArray:
	var G: PackedByteArray = L.grid
	var b := PackedByteArray(); b.resize(DungeonGen.N)
	for y in DungeonGen.GH:
		for x in DungeonGen.GW:
			if G[y * DungeonGen.GW + x] != DungeonGen.ROCK:
				continue
			for d in LADOS_BAJOS + [Vector2i(-1, -1)]:
				if _pisable(G, x + d.x, y + d.y):
					b[y * DungeonGen.GW + x] = 1
					break
	return b

## la cara de cada tramo de muro alto, con ritmo y simetría según el papel de la sala.
## Tramo = casillas de muro seguidas en una línea con la misma sala (o el mismo pasillo) delante.
static func _caras(L: Dictionary, papeles: Dictionary) -> Dictionary:
	var G: PackedByteArray = L.grid
	var GW := DungeonGen.GW
	var bajo: PackedByteArray = L.arq.bajo if L.has("arq") else _bajos(L)
	var out := {}
	for k in [0, 1]:   # 0: cara al sur (muro norte de la sala), 1: cara al este (muro oeste)
		var d: Vector2i = DIRS[k]
		var paso := Vector2i(1, 0) if k == 0 else Vector2i(0, 1)
		var lineas := DungeonGen.GH if k == 0 else GW
		var largo := GW if k == 0 else DungeonGen.GH
		for a in lineas:
			var tramo: Array = []
			var dueno := -2
			for t in largo + 1:
				var c := Vector2i(t, a) if k == 0 else Vector2i(a, t)
				var ok := t < largo and G[c.y * GW + c.x] == DungeonGen.ROCK and _pisable(G, c.x + d.x, c.y + d.y) \
					and G[(c.y + d.y) * GW + c.x + d.x] != DungeonGen.DOOR
				var sala: int = L.room_of[(c.y + d.y) * GW + c.x + d.x] if ok else -3
				if ok and not tramo.is_empty() and sala == dueno:
					tramo.append(c)
					continue
				if not tramo.is_empty():
					_componer(tramo, k, String(papeles.get(dueno, "pasillo")) if dueno >= 0 else "pasillo", out)
				tramo = [c] if ok else []
				dueno = sala
	# los muros bajos no llevan nada: cara lisa (la del muro bajo)
	for key in out.keys():
		var p: PackedStringArray = key.split(",")
		if bajo[int(p[1]) * GW + int(p[0])]:
			out.erase(key)
	return out

## patrón simétrico: j = distancia al extremo más cercano del tramo
static func _componer(tramo: Array, k: int, papel: String, out: Dictionary) -> void:
	var n := tramo.size()
	var h := absi(hash(tramo[0])) % 100   # mismo azar en todo el tramo
	for i in n:
		var j := mini(i, n - 1 - i)
		var medio := (n % 2 == 1 and i == n / 2) or (n % 2 == 0 and (i == n / 2 or i == n / 2 - 1))
		var c: Vector2i = tramo[i]
		var p := "cara"
		if n >= 3 and j == 0:
			p = "cara_columna"
		elif papel == "pasillo":
			var t := c.x if k == 0 else c.y
			p = "cara_columna" if posmod(t, 4) == 0 else ("cara_b" if (absi(hash(c)) % 100) < 30 else "cara")
			if (absi(hash(c * 7)) % 100) < 8:
				p = "cara_rota" if h % 2 == 0 else "cara_hiedra"
		else:
			match papel:
				"capilla", "santuario":
					p = "cara_arco_ciego" if j % 2 == 1 else "cara_columna"
				"cripta", "osario":
					p = "cara_nicho" if j % 2 == 1 else "cara_columna"
				"salon", "entrada", "guarida":
					p = "cara_arco_ciego" if medio else ("cara_columna" if j % 3 == 0 else "cara")
				"tesoro":
					p = "cara_reja" if medio else ("cara_columna" if j % 2 == 0 else "cara_b")
				"almacen":
					p = "cara_columna" if medio and n >= 5 else "cara_b"
				"ruina":
					var q := absi(hash(Vector2i(j, h))) % 100   # simétrico: depende de j, no de la casilla
					p = "cara_rota" if q < 35 else ("cara_hiedra" if q < 60 else "cara")
				_:
					p = "cara_columna" if j % 3 == 0 else "cara"
		out["%d,%d,%d" % [c.x, c.y, k]] = p

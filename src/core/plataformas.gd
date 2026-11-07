class_name Plataformas
## Piso de pasarelas sobre el abismo: se genera el mapa normal y después la roca se convierte en vacío,
## salvo las paredes del norte (con sus antorchas y adornos) y el marco de las puertas.
## Los pasillos quedan como pasarelas y en algunas salas grandes se abre un pozo en el centro.
## Pisar el vacío (DungeonGen.ABISMO) te hace caer (Sim._vigilar_caida).
## Piso 4: 1–2 salas suben de altura (L.alt: 0 bajo, 1 alto, 2 escalera) y cada pasillo que llega a ellas
## acaba en una escalera. Solo se puede entrar por ahí, así que la simulación no necesita saber de alturas;
## el arte pinta la cara alta bajo la sala y los peldaños (LevelArt._abismo y _escaleras).

const PISO := 3
const PISOS := [3, 4, Descenso.PISO]
const PISO_ALTURAS := 4   # además del abismo, salas en alto con escaleras
const TS := DungeonGen.TS
const PARED := 3          # filas de roca que se conservan encima del suelo (cara alta del muro)

static func aplicar(L: Dictionary) -> void:
	var G: PackedByteArray = L.grid
	var R := Mulberry32.new(JS.hash_str(String(L.seed) + "|plataformas"))
	var roca := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < DungeonGen.GW and y < DungeonGen.GH and G[y * DungeonGen.GW + x] == DungeonGen.ROCK
	# 1) roca que se queda: la pared que hay encima de cada casilla y el marco de las puertas y canales
	var queda := PackedByteArray(); queda.resize(DungeonGen.N)
	for y in DungeonGen.GH:
		for x in DungeonGen.GW:
			var t := G[y * DungeonGen.GW + x]
			if t == DungeonGen.ROCK:
				continue
			for k in range(1, PARED + 1):
				if not roca.call(x, y - k):
					break
				queda[(y - k) * DungeonGen.GW + x] = 1
			if t == DungeonGen.DOOR or t == DungeonGen.WATER or t == DungeonGen.BRIDGE:
				for j in range(-1, 2):
					for i in range(-1, 2):
						if roca.call(x + i, y + j):
							queda[(y + j) * DungeonGen.GW + x + i] = 1
	# salas cerradas (todas sus entradas son puertas): conservan sus muros enteros (ahí puede salir el Soul Eater)
	var cerradas := []
	for k in L.rooms.size():
		var r: Dictionary = L.rooms[k]
		if not _cerrada(G, L, r):
			continue
		cerradas.append(k)
		for y in range(int(r.y) - 1 - PARED, int(r.y) + int(r.h) + 1):
			for x in range(int(r.x) - 1, int(r.x) + int(r.w) + 1):
				if roca.call(x, y):
					queda[y * DungeonGen.GW + x] = 1
	for i in DungeonGen.N:
		if G[i] == DungeonGen.ROCK and not queda[i]:
			G[i] = DungeonGen.ABISMO
	# 2) pozos en el centro de algunas salas grandes, sin tocar nada de lo que hay en el suelo
	var ocup := PackedByteArray(); ocup.resize(DungeonGen.N)
	var marca := func(cx: int, cy: int, r: int) -> void:
		for j in range(-r, r + 1):
			for i in range(-r, r + 1):
				var x := cx + i
				var y := cy + j
				if x >= 0 and y >= 0 and x < DungeonGen.GW and y < DungeonGen.GH:
					ocup[y * DungeonGen.GW + x] = 1
	for lst in ["decor", "chests", "key_tables"]:
		for o in L.get(lst, []):
			marca.call(int(o.cx), int(o.cy), 1)
	for o in L.get("gold", []):
		marca.call(int(floorf(o.x / TS)), int(floorf(o.y / TS)), 0)
	marca.call(int(L.stairs_cell.cx), int(L.stairs_cell.cy), 2)
	marca.call(int(L.start.cx), int(L.start.cy), 2)
	var no_sala := [int(L.grave_room)] + cerradas
	if L.fount != null:
		no_sala.append(int(L.fount.room))
	var vivos := _alcanzables(G, L)
	for k in L.rooms.size():
		var r: Dictionary = L.rooms[k]
		if no_sala.has(k) or r.w < 6 or r.h < 6 or R.next() > .8:
			continue
		# el pozo más grande que quepa con 2 casillas de borde, probando a moverlo si hay algo en medio
		var hecho := false
		for tam in [[mini(int(r.w) - 4, 5), mini(int(r.h) - 4, 3)], [2, 2]]:
			var w: int = tam[0]
			var h: int = tam[1]
			for x0 in range(int(r.x) + 2, int(r.x) + int(r.w) - 1 - w):
				for y0 in range(int(r.y) + 2, int(r.y) + int(r.h) - 1 - h):
					var celdas := _hueco(G, L, ocup, x0, y0, w, h)
					if celdas.is_empty():
						continue
					for i in celdas:
						G[i] = DungeonGen.ABISMO
					# el pozo no puede dejar nada sin camino
					var ahora := _alcanzables(G, L)
					if ahora == vivos - celdas.size():
						vivos = ahora
						L["pozos"] = int(L.get("pozos", 0)) + 1
						# alfombras y objetos sueltos que caían en el pozo, fuera
						var fuera := Rect2(x0 * TS - TS, y0 * TS - TS, (w + 2) * TS, (h + 2) * TS)
						var dentro := Rect2(x0 * TS, y0 * TS, w * TS, h * TS)
						L.flats = L.flats.filter(func(o): return not fuera.has_point(Vector2(o.x, o.y)))
						L.litter = L.litter.filter(func(o): return not dentro.has_point(Vector2(o.x, o.y)))
						hecho = true
						break
					for i in celdas:
						G[i] = DungeonGen.FLOOR
				if hecho: break
			if hecho: break
	L["dist"] = distancias(G, L)
	L["plataformas"] = true
	if int(L.wave) == PISO_ALTURAS:
		_terrazas(L, G, R, cerradas)
	elif int(L.wave) == Descenso.PISO:
		Descenso.aplicar(L, G, R, cerradas)

## salas en alto: sin puertas, canales ni salas pegadas; todas sus entradas son pasillos donde cabe una escalera
static func _terrazas(L: Dictionary, G: PackedByteArray, R: Mulberry32, cerradas: Array) -> void:
	var alt := PackedByteArray(); alt.resize(DungeonGen.N)
	var esc := []
	var room_of: PackedInt32Array = L.room_of
	var D := [[0, -1], [1, 0], [0, 1], [-1, 0]]
	var orden := []
	for k in L.rooms.size():
		if k != int(L.start_room) and k != int(L.grave_room) and not cerradas.has(k) and not (L.fount != null and k == int(L.fount.room)):
			orden.append(k)
	# las más grandes primero, con algo de azar
	orden.sort_custom(func(a, b): return L.rooms[a].w * L.rooms[a].h > L.rooms[b].w * L.rooms[b].h)
	var hechas := 0
	var hechas_k := []
	for n in orden.size() * 2:   # segunda vuelta sin azar si en la primera no ha salido ninguna
		var k: int = orden[n % orden.size()]
		if hechas >= 2 or hechas_k.has(k) or (n >= orden.size() and hechas > 0):
			continue
		if n < orden.size() and R.next() < .3:
			continue
		var r: Dictionary = L.rooms[k]
		var dentro := func(x: int, y: int) -> bool:
			return x >= int(r.x) and y >= int(r.y) and x < int(r.x) + int(r.w) and y < int(r.y) + int(r.h)
		var celdas := PackedInt32Array()
		var entradas := []   # [casilla, dx, dy]
		var vale := true
		for y in range(int(r.y), int(r.y) + int(r.h)):
			for x in range(int(r.x), int(r.x) + int(r.w)):
				var t := G[y * DungeonGen.GW + x]
				if t == DungeonGen.ROCK or t == DungeonGen.ABISMO:
					continue
				if t == DungeonGen.DOOR or t == DungeonGen.WATER or t == DungeonGen.BRIDGE:
					vale = false
				celdas.append(y * DungeonGen.GW + x)
				for d in D:
					var nx: int = x + d[0]
					var ny: int = y + d[1]
					if dentro.call(nx, ny) or nx < 1 or ny < 1 or nx >= DungeonGen.GW - 1 or ny >= DungeonGen.GH - 1:
						continue
					var tn := G[ny * DungeonGen.GW + nx]
					if tn == DungeonGen.ROCK or tn == DungeonGen.ABISMO:
						continue
					if tn != DungeonGen.FLOOR or room_of[ny * DungeonGen.GW + nx] >= 0 or alt[ny * DungeonGen.GW + nx] != 0:
						vale = false
					entradas.append([ny * DungeonGen.GW + nx, d[0], d[1]])
		if not vale or entradas.is_empty():
			continue
		# tramos de entrada (casillas seguidas con la misma dirección): como mucho 3 de ancho, como un pasillo
		var tramos := _tramos(entradas)
		if tramos.any(func(tr): return tr.size() > 3):
			continue
		for i in celdas:
			alt[i] = 1
		for tr in tramos:
			var dx: int = tr[0][1]
			var dy: int = tr[0][2]
			var largo := 2
			for en in tr:
				if not _peldano_libre(G, room_of, alt, int(en[0]) + dy * DungeonGen.GW + dx, dx, dy):
					largo = 1
			for en in tr:
				var c: int = en[0]
				alt[c] = 2
				esc.append({"i": c, "ux": -dx, "uy": -dy, "paso": 1, "largo": largo})
				if largo == 2:
					var c2 := c + dy * DungeonGen.GW + dx
					alt[c2] = 2
					esc.append({"i": c2, "ux": -dx, "uy": -dy, "paso": 2, "largo": largo})
		hechas += 1
		hechas_k.append(k)
	if hechas:
		L["alt"] = alt
		L["escaleras"] = esc
		var mask := PackedByteArray(); mask.resize(DungeonGen.N)
		for e in esc:
			mask[int(e.i)] = 1
		L["esc_mask"] = mask
		L["terrazas"] = hechas

## agrupa las entradas en tramos seguidos de la misma dirección
static func _tramos(entradas: Array) -> Array:
	var out := []
	var usados := {}
	for en in entradas:
		if usados.has(en[0]):
			continue
		var tr := [en]
		usados[en[0]] = true
		var paso: int = 1 if int(en[2]) != 0 else DungeonGen.GW   # a lo ancho del tramo
		var crece := true
		while crece:
			crece = false
			for o in entradas:
				if usados.has(o[0]) or o[1] != en[1] or o[2] != en[2]:
					continue
				for t in tr:
					if absi(int(o[0]) - int(t[0])) == paso:
						tr.append(o)
						usados[o[0]] = true
						crece = true
						break
		out.append(tr)
	return out

## la segunda casilla de una escalera: pasillo bajo, sin otra sala al lado
static func _peldano_libre(G: PackedByteArray, room_of: PackedInt32Array, alt: PackedByteArray, c: int, dx: int, dy: int) -> bool:
	var x := c % DungeonGen.GW
	var y := c / DungeonGen.GW
	if x < 1 or y < 1 or x >= DungeonGen.GW - 1 or y >= DungeonGen.GH - 1:
		return false
	if G[c] != DungeonGen.FLOOR or room_of[c] >= 0 or alt[c] != 0:
		return false
	# la casilla siguiente tiene que ser pasillo bajo (que la escalera no acabe contra el vacío)
	var c3 := c + dy * DungeonGen.GW + dx
	return G[c3] != DungeonGen.ABISMO and G[c3] != DungeonGen.ROCK and alt[c3] == 0

## ¿todas las entradas de la sala son puertas? (lo mismo que mira Sim._se_openings)
static func _cerrada(G: PackedByteArray, L: Dictionary, r: Dictionary) -> bool:
	var room_of: PackedInt32Array = L.room_of
	var hay := false
	var borde := []
	for x in range(int(r.x), int(r.x) + int(r.w)):
		borde.append([x, int(r.y) - 1]); borde.append([x, int(r.y) + int(r.h)])
	for y in range(int(r.y), int(r.y) + int(r.h)):
		borde.append([int(r.x) - 1, y]); borde.append([int(r.x) + int(r.w), y])
	for c in borde:
		var x: int = c[0]
		var y: int = c[1]
		if x < 0 or y < 0 or x >= DungeonGen.GW or y >= DungeonGen.GH:
			continue
		var t := G[y * DungeonGen.GW + x]
		if t == DungeonGen.DOOR:
			hay = true
		elif t != DungeonGen.ROCK and room_of[y * DungeonGen.GW + x] < 0:
			return false
	return hay

## casillas del hueco si todas son suelo libre; vacío si no vale
static func _hueco(G: PackedByteArray, L: Dictionary, ocup: PackedByteArray, x0: int, y0: int, w: int, h: int) -> PackedInt32Array:
	var celdas := PackedInt32Array()
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			var i := y * DungeonGen.GW + x
			if G[i] != DungeonGen.FLOOR or ocup[i] or L.corr[i]:
				return PackedInt32Array()
			celdas.append(i)
	return celdas

## distancias desde la entrada con las puertas abiertas (como el dist original, que se calcula antes de las puertas)
static func distancias(G: PackedByteArray, L: Dictionary) -> PackedInt32Array:
	var G2 := G.duplicate()
	for i in G2.size():
		if G2[i] == DungeonGen.DOOR:
			G2[i] = DungeonGen.FLOOR
	return DungeonGen._bfs(G2, int(L.start.cx), int(L.start.cy))

static func _alcanzables(G: PackedByteArray, L: Dictionary) -> int:
	var d := distancias(G, L)
	var n := 0
	for v in d:
		if v >= 0:
			n += 1
	return n

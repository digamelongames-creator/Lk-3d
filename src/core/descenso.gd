class_name Descenso
## Planta 5, «el gran descenso»: sobre el piso de pasarelas (Plataformas) cada grupo de salas recibe un nivel,
## de NIVELES - 1 (la entrada, lo más alto) a 0 (lo más hondo), bajando según te alejas de la entrada.
## Cada pasillo toma el nivel de la sala por la que se entra primero; donde una sala tiene otro nivel que el pasillo,
## el pasillo empieza con una escalera larga y recta (hasta ESC_MAX casillas). Como entre niveles solo se pasa por
## escaleras, la simulación sigue sin saber de alturas (solo va más despacio en los peldaños: L.esc_mask).
## Datos: L.nivel (nivel por casilla, 255 = escalera), L.escaleras (una entrada por casilla de escalera),
## L.tramos (una por escalera entera, para dibujarla), L.p5_obj (estatuas y objetos de la hoja de Diego).

const PISO := 5
const NIVELES := 4
const ESC_MAX := 7
const ESC_MIN := 2
const ESC_TOPE := 7       # escaleras por planta
const TS := DungeonGen.TS
const D4 := [[0, -1], [1, 0], [0, 1], [-1, 0]]
const ESC := 255

## objetos de la hoja: los sólidos van contra la pared norte de las salas, los planos en el suelo
const OBJ_PARED := ["barril", "barril_2", "barril_3", "caja", "cofre_largo", "vasija", "cubo", "cubo_2", "jarra", "jarra_2", "jarra_3", "jarra_4", "jarra_5"]
const OBJ_RUINA := ["escombro", "escombro_2", "escombro_3", "escombro_4", "escombro_5", "columna_rota", "columna_rota_2", "columna_rota_3", "columna_rota_4"]
const OBJ_PLANO := ["rejilla", "rejilla_2", "losas_rotas"]

static func _pasa(t: int) -> bool:
	return t != DungeonGen.ROCK and t != DungeonGen.ABISMO

## una planta de descenso que merece la pena: alguna escalera de 4 o más y al menos 3 niveles
static func bueno(L: Dictionary) -> bool:
	var larga := false
	var niveles := {}
	for t in L.get("tramos", []):
		if int(t.largo) >= 4:
			larga = true
		niveles[int(t.alto)] = true
		niveles[int(t.bajo)] = true
	return larga and niveles.size() >= 3

static func _anda(t: int) -> bool:
	return DungeonGen.walk(t) or t == DungeonGen.DOOR

static func aplicar(L: Dictionary, G: PackedByteArray, R: Mulberry32, cerradas: Array) -> void:
	var room_of: PackedInt32Array = L.room_of
	var inicio := int(L.start.cy) * DungeonGen.GW + int(L.start.cx)
	# 1) candidatas: tramos rectos norte–sur de pasillo (1 a 3 de ancho), con vacío o muro a los lados
	var cands := []
	for w in range(1, 4):
		for x in range(2, DungeonGen.GW - 1 - w):
			var y := 2
			while y < DungeonGen.GH - 2:
				var y0 := y
				while y < DungeonGen.GH - 2 and _tramo_ok(G, room_of, y * DungeonGen.GW + x, w):
					y += 1
				var n := y - y0
				if n >= ESC_MIN + 1:
					var a := y0 + 1
					var b := y - 2
					var sala_n := room_of[(y0 - 1) * DungeonGen.GW + x] >= 0
					var sala_s := room_of[y * DungeonGen.GW + x] >= 0
					if sala_n: a = y0
					if sala_s: b = y - 1
					if b - a + 1 > ESC_MAX:
						if sala_s and not sala_n: a = b - ESC_MAX + 1
						elif sala_n and not sala_s: b = a + ESC_MAX - 1
						else:
							a += (b - a + 1 - ESC_MAX) / 2
							b = a + ESC_MAX - 1
					if b - a + 1 >= ESC_MIN:
						cands.append([x, a, b, b - a + 1 + R.next(), w])
				y = maxi(y + 1, y0 + 1)
	cands.sort_custom(func(p, q): return p[3] > q[3])   # las más largas primero
	# 2) sin tocarse entre sí
	var es_esc := PackedByteArray(); es_esc.resize(DungeonGen.N)
	var elegidas := []
	for c in cands:
		if elegidas.size() >= ESC_TOPE:
			break
		var x: int = c[0]
		var a: int = c[1]
		var b: int = c[2]
		var w: int = c[4]
		var junto := false
		for y in range(a - 1, b + 2):
			for dx in range(-2, w + 2):
				var k := y * DungeonGen.GW + x + dx
				if k >= 0 and k < DungeonGen.N and es_esc[k]:
					junto = true
		if junto:
			continue
		for y in range(a, b + 1):
			for dx in w:
				es_esc[y * DungeonGen.GW + x + dx] = 1
		elegidas.append(c)
	# 3) zonas (sin las escaleras) y sus niveles: desde la entrada, cada escalera baja un nivel
	var zona := PackedInt32Array(); zona.resize(DungeonGen.N); zona.fill(-1)
	var nz := 0
	for i in DungeonGen.N:
		if zona[i] >= 0 or es_esc[i] or not _anda(G[i]):
			continue
		var q := PackedInt32Array([i])
		zona[i] = nz
		var h := 0
		while h < q.size():
			var cc := q[h]
			h += 1
			for dd in D4:
				var xx: int = cc % DungeonGen.GW + dd[0]
				var yy: int = cc / DungeonGen.GW + dd[1]
				if xx < 0 or yy < 0 or xx >= DungeonGen.GW or yy >= DungeonGen.GH:
					continue
				var k := yy * DungeonGen.GW + xx
				if zona[k] < 0 and not es_esc[k] and _anda(G[k]):
					zona[k] = nz
					q.append(k)
		nz += 1
	var nivel_z := PackedInt32Array(); nivel_z.resize(nz); nivel_z.fill(-1)
	nivel_z[zona[inicio]] = NIVELES - 1
	# desde la entrada: al cruzar una escalera hacia una zona nueva se baja un nivel (casi siempre);
	# si la zona ya tenía nivel y es el mismo, la escalera sobra y se queda como pasillo
	var hechas := []
	var cola := [zona[inicio]]
	while cola.size():
		var z: int = cola.pop_front()
		for c in elegidas:
			if hechas.has(c):
				continue
			var x: int = c[0]
			var zn := zona[(int(c[1]) - 1) * DungeonGen.GW + x]
			var zs := zona[(int(c[2]) + 1) * DungeonGen.GW + x]
			if zn != z and zs != z:
				continue
			var otra := zs if zn == z else zn
			if nivel_z[otra] < 0:
				# las escaleras largas pueden bajar dos niveles de golpe
				var baja := 2 if (int(c[2]) - int(c[1]) + 1 >= 6 and R.next() < .5) else 1
				nivel_z[otra] = maxi(0, nivel_z[z] - baja) if R.next() < .95 else nivel_z[z]
				cola.append(otra)
			hechas.append(c)
	for k in nz:
		if nivel_z[k] < 0:
			nivel_z[k] = NIVELES - 1
	var niv := PackedByteArray(); niv.resize(DungeonGen.N)
	for i in DungeonGen.N:
		if zona[i] >= 0:
			niv[i] = nivel_z[zona[i]]
	# 4) escaleras: las que no bajan (ya en el fondo) se quedan como pasillo normal
	var esc := []
	var tramos := []
	for c in hechas:
		var x: int = c[0]
		var a: int = c[1]
		var b: int = c[2]
		var w: int = c[4]
		var na := (a - 1) * DungeonGen.GW + x
		var sb := (b + 1) * DungeonGen.GW + x
		var arriba := 0 if niv[na] > niv[sb] else 1
		var alto: int = maxi(niv[na], niv[sb])
		var bajo: int = mini(niv[na], niv[sb])
		if alto == bajo:
			for y in range(a, b + 1):
				for dx in w:
					niv[y * DungeonGen.GW + x + dx] = alto
			continue
		var uy := -1 if arriba == 0 else 1
		var largo := b - a + 1
		var cols := []
		for dx in w:
			cols.append(x + dx)
		# ancha: se abren carriles a los lados sobre el vacío o el muro (hasta 3)
		for lado in [-1, 1]:
			if cols.size() >= 3:
				break
			var xl: int = (cols.min() - 1) if lado < 0 else (cols.max() + 1)
			if xl < 2 or xl >= DungeonGen.GW - 2:
				continue
			var ok := true
			for y in range(a, b + 1):
				var k := y * DungeonGen.GW + xl
				if _anda(G[k]) or _anda(G[k + lado]):
					ok = false
			# puntas del carril nuevo: muro o vacío (se hace rellano) o la misma zona
			for pt in [[a - 1, zona[na]], [b + 1, zona[sb]]]:
				var k: int = int(pt[0]) * DungeonGen.GW + xl
				if _anda(G[k]) and zona[k] != int(pt[1]):
					ok = false
				if not _anda(G[k]) and _anda(G[k + lado]) and zona[k + lado] != int(pt[1]):
					ok = false
			if ok:
				cols.append(xl)
		var celdas := PackedInt32Array()
		for xc in cols:
			for y in range(a, b + 1):
				var k: int = y * DungeonGen.GW + xc
				G[k] = DungeonGen.FLOOR
				niv[k] = ESC
				celdas.append(k)
				var paso := (y - a + 1) if uy < 0 else (b - y + 1)
				esc.append({"i": k, "ux": 0, "uy": uy, "paso": paso, "largo": largo, "alto": alto, "bajo": bajo, "t": tramos.size()})
			if xc < x or xc >= x + w:
				# rellanos en las puntas que dan al vacío, para no acabar colgando
				for pt in [[a - 1, niv[na]], [b + 1, niv[sb]]]:
					var k: int = int(pt[0]) * DungeonGen.GW + xc
					if G[k] == DungeonGen.ABISMO:
						G[k] = DungeonGen.FLOOR
						niv[k] = int(pt[1])
		var pie_y := b + 1 if uy < 0 else a - 1
		tramos.append({"celdas": celdas, "ux": 0, "uy": uy, "largo": largo, "alto": alto, "bajo": bajo,
			"x0": cols.min(), "x1": cols.max(), "pie_y": pie_y})
	var mask := PackedByteArray(); mask.resize(DungeonGen.N)
	for e in esc:
		mask[int(e.i)] = 1
	L["nivel"] = niv
	L["escaleras"] = esc
	L["tramos"] = tramos
	L["esc_mask"] = mask
	L["descenso"] = true
	# antorchas, adornos y musgo que colgaban de un muro que ahora es escalera
	var con_muro := func(o) -> bool: return int(o.cy) >= 1 and G[(int(o.cy) - 1) * DungeonGen.GW + int(o.cx)] == DungeonGen.ROCK
	L.torches = L.torches.filter(con_muro)
	L.wall_deco = L.wall_deco.filter(con_muro)
	L.wall_veg = L.wall_veg.filter(con_muro)
	_estatuas(L, G, R)
	_objetos(L, G, R, cerradas)
	L["dist"] = Plataformas.distancias(G, L)

static func _tramo_ok(G: PackedByteArray, room_of: PackedInt32Array, k: int, w: int) -> bool:
	for d in w:
		if G[k + d] != DungeonGen.FLOOR or room_of[k + d] >= 0:
			return false
	return not _anda(G[k - 1]) and not _anda(G[k + w])

## dos cariátides guardan el pie de cada escalera larga cuando llega a una sala
static func _estatuas(L: Dictionary, G: PackedByteArray, R: Mulberry32) -> void:
	var obj: Array = L.get("p5_obj", [])
	var room_of: PackedInt32Array = L.room_of
	var vivos := _vivos(G, L)
	var ocup := _ocupadas(L)
	for t in L.tramos:
		if int(t.largo) < 4:
			continue
		var y: int = t.pie_y
		var a: int = y * DungeonGen.GW + int(t.x0) - 1
		var b: int = y * DungeonGen.GW + int(t.x1) + 1
		var ok := true
		for c in [a, b]:
			if G[c] != DungeonGen.FLOOR or room_of[c] < 0 or ocup.has(c):
				ok = false
		if not ok:
			continue
		G[a] = DungeonGen.DECOR
		G[b] = DungeonGen.DECOR
		var ahora := _vivos(G, L)
		if ahora != vivos - 2:
			G[a] = DungeonGen.FLOOR
			G[b] = DungeonGen.FLOOR
			continue
		vivos = ahora
		ocup[a] = true
		ocup[b] = true
		obj.append({"cx": a % DungeonGen.GW, "cy": a / DungeonGen.GW, "n": "cariatide", "flip": false})
		obj.append({"cx": b % DungeonGen.GW, "cy": b / DungeonGen.GW, "n": "cariatide", "flip": true})
	L["p5_obj"] = obj

## barriles, jarras y cajas contra la pared norte; ruinas en las esquinas; rejillas y losas rotas en el suelo
static func _objetos(L: Dictionary, G: PackedByteArray, R: Mulberry32, cerradas: Array) -> void:
	var obj: Array = L.get("p5_obj", [])
	var room_of: PackedInt32Array = L.room_of
	var ocup := _ocupadas(L)
	var vivos := _vivos(G, L)
	var niv: PackedByteArray = L.nivel
	for k in L.rooms.size():
		if k == int(L.start_room):
			continue
		var r: Dictionary = L.rooms[k]
		var huecos := []
		for x in range(int(r.x), int(r.x) + int(r.w)):
			var c: int = int(r.y) * DungeonGen.GW + x
			if G[c] == DungeonGen.FLOOR and G[c - DungeonGen.GW] == DungeonGen.ROCK and not ocup.has(c) and niv[c] != ESC \
					and _pasa(G[c - 1]) and _pasa(G[c + 1]):
				huecos.append(c)
		var n := mini(huecos.size() / 3, 1 + int(R.next() * 3))
		for m in n:
			var c: int = huecos.pop_at(int(R.next() * huecos.size()))
			if ocup.has(c - 1) or ocup.has(c + 1):
				continue
			G[c] = DungeonGen.DECOR
			var ahora := _vivos(G, L)
			if ahora != vivos - 1:
				G[c] = DungeonGen.FLOOR
				continue
			vivos = ahora
			ocup[c] = true
			var lista: Array = OBJ_RUINA if R.next() < .3 else OBJ_PARED
			obj.append({"cx": c % DungeonGen.GW, "cy": c / DungeonGen.GW, "n": lista[int(R.next() * lista.size())], "flip": R.next() < .5})
		# algo plano en el suelo
		if R.next() < .5:
			var x := int(r.x) + 1 + int(R.next() * maxi(1, int(r.w) - 2))
			var y := int(r.y) + 1 + int(R.next() * maxi(1, int(r.h) - 2))
			var c := y * DungeonGen.GW + x
			if G[c] == DungeonGen.FLOOR and not ocup.has(c):
				obj.append({"cx": x, "cy": y, "n": OBJ_PLANO[int(R.next() * OBJ_PLANO.size())], "plano": true, "flip": false})
				ocup[c] = true
	L["p5_obj"] = obj

static func _ocupadas(L: Dictionary) -> Dictionary:
	var o := {}
	for lst in ["decor", "chests", "key_tables"]:
		for d in L.get(lst, []):
			for j in range(-1, 2):
				for i in range(-1, 2):
					o[(int(d.cy) + j) * DungeonGen.GW + int(d.cx) + i] = true
	for d in L.get("p5_obj", []):
		o[int(d.cy) * DungeonGen.GW + int(d.cx)] = true
	for d in L.get("gold", []) + L.get("flats", []) + L.get("litter", []):
		o[int(floorf(d.y / TS)) * DungeonGen.GW + int(floorf(d.x / TS))] = true
	for c in [L.stairs_cell, L.start]:
		for j in range(-2, 3):
			for i in range(-2, 3):
				o[(int(c.cy) + j) * DungeonGen.GW + int(c.cx) + i] = true
	if L.fount != null:
		var fx := int(floorf(L.fount.x / TS))
		var fy := int(floorf(L.fount.y / TS))
		for j in range(-2, 3):
			for i in range(-2, 3):
				o[(fy + j) * DungeonGen.GW + fx + i] = true
	return o

static func _vivos(G: PackedByteArray, L: Dictionary) -> int:
	var d := Plataformas.distancias(G, L)
	var n := 0
	for v in d:
		if v >= 0:
			n += 1
	return n

## nivel (con decimales en los peldaños) bajo el punto (x, y) del mundo; -1 si el piso no tiene niveles
static func nivel_en(L: Dictionary, x: float, y: float) -> float:
	var niv: PackedByteArray = L.get("nivel", PackedByteArray())
	if niv.is_empty():
		return -1.0
	var cx := int(floorf(x / TS))
	var cy := int(floorf(y / TS))
	if cx < 0 or cy < 0 or cx >= DungeonGen.GW or cy >= DungeonGen.GH:
		return -1.0
	var v := niv[cy * DungeonGen.GW + cx]
	if v != ESC:
		return float(v)
	var e = _esc_de(L, cy * DungeonGen.GW + cx)
	if e == null:
		return 0.0
	return float(e.alto) - (float(e.alto) - float(e.bajo)) * recorrido(e, x, y) / (int(e.largo) * TS)

## píxeles recorridos desde lo alto de la escalera
static func recorrido(e: Dictionary, x: float, y: float) -> float:
	var cx := int(e.i) % DungeonGen.GW
	var cy := int(e.i) / DungeonGen.GW
	var lx := x - cx * TS
	var ly := y - cy * TS
	var o: float
	if int(e.uy) < 0: o = ly
	elif int(e.uy) > 0: o = TS - ly
	elif int(e.ux) < 0: o = lx
	else: o = TS - lx
	return (int(e.paso) - 1) * TS + clampf(o, 0, TS)

static func _esc_de(L: Dictionary, i: int) -> Variant:
	if not L.has("_esc_idx"):
		var d := {}
		for e in L.get("escaleras", []):
			d[int(e.i)] = e
		L["_esc_idx"] = d
	return L._esc_idx.get(i)

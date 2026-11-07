class_name Decorador
## Decorador de los pisos 1–5: última etapa del generador. No cambia el mapa ni la simulación,
## solo deja en L.deco qué adornar y dónde, con su propio azar (semilla + «#deco»), así que
## cada cliente del online decora igual sin mandar nada por la red.
## Cada sala recibe un papel (salón, capilla, cripta…) con su kit de assets/deco/decorador.json:
## un punto focal, detalles de suelo repartidos con más peso junto a las paredes, una viñeta
## narrativa (un caído y su rastro), velas con luz y adornos de pared (telarañas, cadenas, humedad).

static var ACTIVO := true
const PISO_MAX := 5
const RUTA := "res://assets/deco/decorador.json"

static var _reglas: Dictionary = {}

static func reglas() -> Dictionary:
	if _reglas.is_empty():
		var f := FileAccess.open(RUTA, FileAccess.READ)
		_reglas = JSON.parse_string(f.get_as_text())
	return _reglas

static func aplicar(L: Dictionary) -> void:
	if not ACTIVO or int(L.wave) > PISO_MAX or int(L.wave) < 1:
		return
	var C := reglas()
	var P: Dictionary = C.pisos.get(str(int(L.wave)), {})
	var R := Mulberry32.new(JS.hash_str(String(L.seed) + "#deco" + str(int(L.wave))))
	var ocup := _ocupado(L)
	var D := {"suelo": [], "pared": [], "luces": [], "papeles": {}, "focos": []}
	var papeles := _papeles(L, R, C)
	D.papeles = papeles
	var usados := {}   # tipo → [celdas] para separar los iguales
	for k in L.rooms.size():
		_sala(L, k, String(papeles[k]), C, P, R, ocup, usados, D)
	_pasillos(L, C, R, ocup, usados, D)
	_paredes(L, papeles, C, P, R, D)
	if L.get("plataformas", false):
		_abismo(L, P, R, D)
	L["deco"] = D

# ---------------------------------------------------------------- casillas libres

static func _ocupado(L: Dictionary) -> PackedByteArray:
	var GW := DungeonGen.GW
	var o := PackedByteArray(); o.resize(DungeonGen.N)
	var marca := func(cx: int, cy: int, r: int) -> void:
		for y in range(cy - r, cy + r + 1):
			for x in range(cx - r, cx + r + 1):
				if x >= 0 and y >= 0 and x < GW and y < DungeonGen.GH:
					o[y * GW + x] = 1
	for k in ["chests", "decor", "key_tables", "p5_obj"]:
		for e in L.get(k, []):
			if e is Dictionary and e.has("cx"):
				marca.call(int(e.cx), int(e.cy), 0)
	for d in L.get("doors", []):
		for c in d.cells:
			marca.call(int(c) % GW, int(c) / GW, 1)
	for f in L.get("flats", []):
		marca.call(int(f.x / DungeonGen.TS), int(f.y / DungeonGen.TS), 1)
	var st: Dictionary = L.stairs_cell
	marca.call(int(st.cx), int(st.cy), 1)
	marca.call(int(st.cx) + 1, int(st.cy) + 1, 1)
	marca.call(int(L.start.cx), int(L.start.cy), 1)
	if L.fount != null:
		marca.call(int(L.fount.x / DungeonGen.TS), int(L.fount.y / DungeonGen.TS), 1)
	return o

static func _libre(L: Dictionary, ocup: PackedByteArray, x: int, y: int) -> bool:
	if x < 1 or y < 1 or x >= DungeonGen.GW - 1 or y >= DungeonGen.GH - 1:
		return false
	var i := y * DungeonGen.GW + x
	return L.grid[i] == DungeonGen.FLOOR and not ocup[i]

## 0 = muro al lado (borde), 1 = a una casilla, 2 = centro
static func _anillo(L: Dictionary, x: int, y: int) -> int:
	var G: PackedByteArray = L.grid
	for r in [1, 2]:
		for d in [[-r, 0], [r, 0], [0, -r], [0, r]]:
			var xx: int = x + d[0]
			var yy: int = y + d[1]
			if xx < 0 or yy < 0 or xx >= DungeonGen.GW or yy >= DungeonGen.GH or G[yy * DungeonGen.GW + xx] == 0:
				return r - 1
	return 2

# ---------------------------------------------------------------- papeles

static func _papeles(L: Dictionary, R: Mulberry32, C: Dictionary) -> Dictionary:
	var out := {}
	var oro := {}
	for c in L.chests:
		if c.get("room") != null and (c.kind == "gold" or c.kind == "boss"):
			oro[int(c.room)] = true
	var ultimo := ""
	for k in L.rooms.size():
		var r: Dictionary = L.rooms[k]
		var p := ""
		if k == L.start_room:
			p = "entrada"
		elif k == L.end_room:
			p = "guarida"
		elif L.fount != null and k == int(L.fount.room):
			p = "santuario"
		elif oro.has(k):
			p = "tesoro"
		else:
			var a: int = r.w * r.h
			var lista: Array = C.reparto.grande if a >= 48 else (C.reparto.mediana if a >= 30 else C.reparto.pequena)
			# dos salas seguidas no repiten papel
			for intento in 4:
				p = lista[int(R.next() * lista.size())]
				if p != ultimo:
					break
		ultimo = p
		out[k] = p
	return out

# ---------------------------------------------------------------- salas

static func _sala(L: Dictionary, k: int, papel: String, C: Dictionary, P: Dictionary, R: Mulberry32,
		ocup: PackedByteArray, usados: Dictionary, D: Dictionary) -> void:
	var r: Dictionary = L.rooms[k]
	var kit: Dictionary = C.papeles[papel]
	var TS := DungeonGen.TS
	# 0) muebles de verdad: grupos de objetos sólidos contra las paredes (antes que nada, el resto los esquiva)
	_muebles(L, k, kit, R, ocup)
	var celdas: Array = []
	for y in range(r.y, r.y + r.h):
		for x in range(r.x, r.x + r.w):
			if _libre(L, ocup, x, y) and L.room_of[y * DungeonGen.GW + x] == k:
				celdas.append(Vector2i(x, y))
	if celdas.is_empty():
		return
	var luz: Array = kit.get("luz", [255, 170, 90])
	# 1) punto focal en el centro de la sala (o lo más cerca que quede libre)
	var centro := Vector2i(r.cx, r.cy)
	var foco := _mas_cerca(celdas, centro)
	# el foco necesita suelo alrededor (en los pisos de pasarelas puede haber un pozo en el centro)
	var focal := String(kit.focal)
	if focal != "" and focal != "alfombra":
		var holgadas := celdas.filter(func(c: Vector2i) -> bool: return _holgura(L, c, 1 if focal != "circulo" else 2))
		if holgadas.is_empty():
			focal = ""
		else:
			foco = _mas_cerca(holgadas, centro)
	match focal:
		"alfombra":
			_alfombra(L, r, ocup, D)
		"circulo":
			D.suelo.append({"t": "circulo", "x": (foco.x + .5) * TS, "y": (foco.y + .5) * TS, "r": 26 + int(R.next() * 8), "v": int(R.next() * 9999)})
			D.focos.append({"x": (foco.x + .5) * TS, "y": (foco.y + .5) * TS})
			D.luces.append({"x": (foco.x + .5) * TS, "y": (foco.y + .5) * TS, "r": 46, "k": .45, "col": luz})
		"osario":
			_racimo(D, "huesos", foco, 5 + int(R.next() * 4), 18.0, R)
			D.suelo.append({"t": "calavera", "x": (foco.x + .5) * TS, "y": (foco.y + .5) * TS, "v": int(R.next() * 9999)})
		"derrumbe":
			_racimo(D, "escombro", foco, 7 + int(R.next() * 5), 22.0, R)
			D.suelo.append({"t": "losa", "x": (foco.x + .5) * TS, "y": (foco.y + .5) * TS, "v": int(R.next() * 9999), "g": 2})
		"rejilla":
			_plano(L, foco, "rejilla" if R.next() < .5 else "rejilla_2", ocup)
	# 2) velas: en círculo alrededor del foco (capilla) o en parejas pegadas a las paredes
	var nv := int(kit.velas)
	if nv > 0:
		if focal == "circulo":
			for i in nv:
				var ang := TAU * i / nv - PI / 2
				_vela(D, (foco.x + .5) * TS + cos(ang) * 30, (foco.y + .5) * TS + sin(ang) * 20, luz, R)
		else:
			# grupos de 2–3 velas en los rincones (donde se tocan dos paredes) y, si faltan, junto a una pared
			var rincones := celdas.filter(func(c: Vector2i) -> bool: return _rincon(L, c))
			var borde := celdas.filter(func(c: Vector2i) -> bool: return _anillo(L, c.x, c.y) == 0 and not _rincon(L, c))
			var puestas := 0
			while puestas < nv and (rincones.size() or borde.size()):
				var lista: Array = rincones if rincones.size() else borde
				var c: Vector2i = lista.pop_at(int(R.next() * lista.size()))
				var gx := (c.x + .5) * TS
				var gy := (c.y + .5) * TS
				for j in 2 + int(R.next() * 2):
					_vela(D, gx + (R.next() - .5) * 14, gy + (R.next() - .5) * 9, luz, R, j > 0)
				puestas += 2
	# 3) detalles de suelo: cantidad por superficie, con más peso junto a las paredes
	var factor := celdas.size() / 10.0
	for t in kit.suelo:
		var mult := float(P.get(t, 1.0)) if t in ["musgo"] else 1.0
		var n := int(floorf(float(kit.suelo[t]) * factor * mult + R.next()))
		var borde_pesa: bool = t in ["musgo", "escombro", "huesos", "paja", "mancha"]
		for i in n:
			var c := _elegir(L, celdas, R, borde_pesa)
			if not _separado(usados, t, c, int(C.separacion.get(t, 2))):
				continue
			D.suelo.append({"t": t, "x": (c.x + .15 + R.next() * .7) * TS, "y": (c.y + .15 + R.next() * .7) * TS, "v": int(R.next() * 99999), "g": 1 + int(R.next() * 2)})
	# 4) objetos sueltos del atlas (velas, botellas, monedas, cascotes, taburetes), sin colisión
	var sueltos: Array = kit.get("sueltos", [])
	if sueltos.size():
		for i in int(floorf(float(kit.get("n_sueltos", .3)) * factor + R.next())):
			var c := _elegir(L, celdas, R, true)
			if _separado(usados, "suelto", c, 2):
				L.litter.append({"x": (c.x + .2 + R.next() * .6) * TS, "y": (c.y + .5 + R.next() * .4) * TS, "n": sueltos[int(R.next() * sueltos.size())]})
	# 5) viñeta: un caído en una esquina y su rastro hacia la puerta más cercana
	if R.next() < float(kit.vineta):
		var rincones := celdas.filter(func(c: Vector2i) -> bool: return _anillo(L, c.x, c.y) == 0)
		if rincones.size():
			var c: Vector2i = rincones[int(R.next() * rincones.size())]
			D.suelo.append({"t": "caido", "x": (c.x + .5) * TS, "y": (c.y + .55) * TS, "v": int(R.next() * 9999), "flip": R.next() < .5})

## grupos de 1–4 objetos de la hoja de Diego pegados a una pared (norte, este u oeste), con un hueco entre grupos.
## Son sólidos (DECOR): solo se ponen si los vecinos que se pueden pisar siguen unidos entre sí (no corta pasos).
static func _muebles(L: Dictionary, k: int, kit: Dictionary, R: Mulberry32, ocup: PackedByteArray) -> void:
	var lista: Array = kit.get("muebles", [])
	if lista.is_empty():
		return
	var r: Dictionary = L.rooms[k]
	var G: PackedByteArray = L.grid
	var GW := DungeonGen.GW
	var huecos: Array = []
	for y in range(r.y, r.y + r.h):
		for x in range(r.x, r.x + r.w):
			if not _libre(L, ocup, x, y) or L.room_of[y * GW + x] != k:
				continue
			var n := G[(y - 1) * GW + x] == 0
			var w := G[y * GW + x - 1] == 0
			var e := G[y * GW + x + 1] == 0
			if n or w or e:
				huecos.append(Vector2i(x, y))
	var area: int = r.w * r.h
	var grupos := int(floorf(float(kit.get("n_muebles", .3)) * area / 10.0 + R.next()))
	if not L.has("p5_obj"):
		L["p5_obj"] = []
	for g in grupos:
		if huecos.is_empty():
			break
		var c: Vector2i = huecos[int(R.next() * huecos.size())]
		# el grupo sigue la pared: en horizontal si es la del norte, en vertical si es lateral
		var horiz: bool = G[(c.y - 1) * GW + c.x] == 0
		var paso := Vector2i(1 if R.next() < .5 else -1, 0) if horiz else Vector2i(0, 1 if R.next() < .5 else -1)
		var tam := 1 + int(R.next() * 4)
		var p := c
		for i in tam:
			if not huecos.has(p) or not _no_corta(L, p):
				break
			G[p.y * GW + p.x] = DungeonGen.DECOR
			L.p5_obj.append({"cx": p.x, "cy": p.y, "n": lista[int(R.next() * lista.size())], "flip": R.next() < .5, "deco": true})
			ocup[p.y * GW + p.x] = 1
			p += paso
		# hueco de una casilla alrededor del grupo para que respire
		huecos = huecos.filter(func(h: Vector2i) -> bool: return not ocup[h.y * GW + h.x] and _lejos_de_grupo(ocup, L, h))

static func _lejos_de_grupo(ocup: PackedByteArray, L: Dictionary, h: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = h + d
		if L.grid[q.y * DungeonGen.GW + q.x] == DungeonGen.DECOR:
			return false
	return true

## poner algo sólido en p no separa a sus vecinos pisables (anillo de 8 casillas con un solo tramo)
static func _no_corta(L: Dictionary, p: Vector2i) -> bool:
	const ANILLO := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)]
	var pisa := []
	for d in ANILLO:
		var q: Vector2i = p + d
		pisa.append(DungeonGen.walk(L.grid[q.y * DungeonGen.GW + q.x]))
	# los 8 vecinos en orden forman un anillo donde cada uno toca al siguiente por un lado:
	# los pisables tienen que formar un solo tramo
	var tramos := 0
	for i in 8:
		if pisa[i] and not pisa[(i + 7) % 8]:
			tramos += 1
	return tramos <= 1

## objeto plano de la hoja en el suelo (rejillas, losas rotas)
static func _plano(L: Dictionary, c: Vector2i, n: String, ocup: PackedByteArray) -> void:
	if not L.has("p5_obj"):
		L["p5_obj"] = []
	L.p5_obj.append({"cx": c.x, "cy": c.y, "n": n, "plano": true, "flip": false, "deco": true})
	ocup[c.y * DungeonGen.GW + c.x] = 1

static func _alfombra(L: Dictionary, r: Dictionary, ocup: PackedByteArray, D: Dictionary) -> void:
	# camino de alfombra por el eje largo, dejando una casilla a cada lado
	var TS := DungeonGen.TS
	var horiz: bool = r.w >= r.h
	var a: int = (r.x + 1) if horiz else (r.y + 1)
	var b: int = (r.x + r.w - 2) if horiz else (r.y + r.h - 2)
	var fijo: int = r.cy if horiz else r.cx
	# recorta donde haya algo encima
	var tramo: Array = []
	for t in range(a, b + 1):
		var x: int = t if horiz else fijo
		var y: int = fijo if horiz else t
		if _libre(L, ocup, x, y):
			tramo.append(t)
		elif tramo.size() < 3:
			tramo.clear()
		else:
			break
	if tramo.size() < 3:
		return
	var t0: int = tramo[0]
	var t1: int = tramo[-1]
	# ancha (casi 2 casillas) si la sala da para ello
	var ancho: int = r.h if horiz else r.w
	var m := -10 if ancho >= 6 else 6
	if horiz:
		D.suelo.append({"t": "alfombra", "x0": t0 * TS + 4, "y0": fijo * TS + m, "x1": (t1 + 1) * TS - 4, "y1": (fijo + 1) * TS - m, "v": JS.hash_str(String(L.seed) + str(r.x))})
	else:
		D.suelo.append({"t": "alfombra", "x0": fijo * TS + m, "y0": t0 * TS + 4, "x1": (fijo + 1) * TS - m, "y1": (t1 + 1) * TS - 4, "v": JS.hash_str(String(L.seed) + str(r.y))})

static func _vela(D: Dictionary, x: float, y: float, luz: Array, R: Mulberry32, sin_luz: bool = false) -> void:
	D.suelo.append({"t": "vela", "x": x, "y": y, "n": 1 + int(R.next() * 3), "v": int(R.next() * 9999)})
	if not sin_luz:
		D.luces.append({"x": x, "y": y - 6, "r": 34, "k": .55, "col": luz, "vela": true})

## todas las casillas a r de c son suelo
static func _holgura(L: Dictionary, c: Vector2i, r: int) -> bool:
	for y in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			if x < 0 or y < 0 or x >= DungeonGen.GW or y >= DungeonGen.GH or not DungeonGen.walk(L.grid[y * DungeonGen.GW + x]):
				return false
	return true

## casilla con pared a dos lados que se tocan
static func _rincon(L: Dictionary, c: Vector2i) -> bool:
	var G: PackedByteArray = L.grid
	var GW := DungeonGen.GW
	var n := G[(c.y - 1) * GW + c.x] == 0
	var s := G[(c.y + 1) * GW + c.x] == 0
	var w := G[c.y * GW + c.x - 1] == 0
	var e := G[c.y * GW + c.x + 1] == 0
	return (n or s) and (w or e)

static func _racimo(D: Dictionary, t: String, c: Vector2i, n: int, rad: float, R: Mulberry32) -> void:
	var TS := DungeonGen.TS
	for i in n:
		var ang := R.next() * TAU
		var d := sqrt(R.next()) * rad
		D.suelo.append({"t": t, "x": (c.x + .5) * TS + cos(ang) * d, "y": (c.y + .5) * TS + sin(ang) * d * .7, "v": int(R.next() * 99999), "g": 1 + int(R.next() * 2)})

static func _mas_cerca(celdas: Array, p: Vector2i) -> Vector2i:
	var mejor: Vector2i = celdas[0]
	var dm := 1 << 30
	for c in celdas:
		var d: int = (c.x - p.x) * (c.x - p.x) + (c.y - p.y) * (c.y - p.y)
		if d < dm:
			dm = d
			mejor = c
	return mejor

static func _elegir(L: Dictionary, celdas: Array, R: Mulberry32, borde: bool) -> Vector2i:
	# tres candidatas y gana la más pegada a la pared (o la primera si no importa)
	var c: Vector2i = celdas[int(R.next() * celdas.size())]
	if not borde:
		return c
	for i in 2:
		var o: Vector2i = celdas[int(R.next() * celdas.size())]
		if _anillo(L, o.x, o.y) < _anillo(L, c.x, c.y):
			c = o
	return c

static func _separado(usados: Dictionary, t: String, c: Vector2i, sep: int) -> bool:
	var lista: Array = usados.get(t, [])
	for o in lista:
		if absi(o.x - c.x) < sep and absi(o.y - c.y) < sep:
			return false
	lista.append(c)
	usados[t] = lista
	return true

static func _puerta_cerca(L: Dictionary, k: int, c: Vector2i) -> Vector2i:
	# la casilla de pasillo pegada a la sala más cercana al caído
	var r: Dictionary = L.rooms[k]
	var mejor := Vector2i(-1, -1)
	var dm := 1 << 30
	for y in range(r.y - 1, r.y + r.h + 1):
		for x in range(r.x - 1, r.x + r.w + 1):
			if x < 0 or y < 0 or x >= DungeonGen.GW or y >= DungeonGen.GH:
				continue
			var i := y * DungeonGen.GW + x
			if L.room_of[i] == -1 and DungeonGen.walk(L.grid[i]):
				var d := (x - c.x) * (x - c.x) + (y - c.y) * (y - c.y)
				if d < dm:
					dm = d
					mejor = Vector2i(x, y)
	return mejor

# ---------------------------------------------------------------- pasillos

static func _pasillos(L: Dictionary, C: Dictionary, R: Mulberry32, ocup: PackedByteArray, usados: Dictionary, D: Dictionary) -> void:
	var TS := DungeonGen.TS
	var kit: Dictionary = C.pasillos
	for y in range(1, DungeonGen.GH - 1):
		for x in range(1, DungeonGen.GW - 1):
			var i := y * DungeonGen.GW + x
			if not L.corr[i] or L.room_of[i] >= 0 or not _libre(L, ocup, x, y):
				continue
			for t in kit:
				if R.next() < float(kit[t]) * .25 and _separado(usados, t, Vector2i(x, y), int(C.separacion.get(t, 2))):
					D.suelo.append({"t": t, "x": (x + .2 + R.next() * .6) * TS, "y": (y + .2 + R.next() * .6) * TS, "v": int(R.next() * 99999), "g": 1})

# ---------------------------------------------------------------- paredes

## caras del muro norte de cada sala: telarañas en los rincones, cadenas y manchas de humedad.
## La celda es la del suelo bajo la cara (como antorchas y adornos de pared).
static func _paredes(L: Dictionary, papeles: Dictionary, C: Dictionary, P: Dictionary, R: Mulberry32, D: Dictionary) -> void:
	var G: PackedByteArray = L.grid
	var GW := DungeonGen.GW
	var ocup := {}
	for e in L.torches:
		ocup[Vector2i(int(e.cx), int(e.cy))] = true
	for e in L.wall_deco:
		ocup[Vector2i(int(e.cx), int(e.cy))] = true
	var cara := func(x: int, y: int) -> bool:
		return x > 0 and y > 1 and x < GW - 1 and y < DungeonGen.GH and G[(y - 1) * GW + x] == 0 and DungeonGen.walk(G[y * GW + x]) and G[y * GW + x] != DungeonGen.ABISMO
	var hum := float(P.get("humedad", 1.0))
	for k in L.rooms.size():
		var r: Dictionary = L.rooms[k]
		var kit: Dictionary = C.papeles[String(papeles[k])]
		var y: int = r.y
		# rincones de arriba: telaraña si la cara del muro llega a la pared lateral
		for lado in [-1, 1]:
			var x: int = r.x if lado < 0 else r.x + r.w - 1
			if cara.call(x, y) and G[y * GW + x + lado] == 0 and R.next() < float(kit.telas):
				D.pared.append({"t": "telarana", "cx": x, "cy": y, "lado": lado, "v": int(R.next() * 9999)})
		for x in range(r.x, r.x + r.w):
			if not cara.call(x, y) or ocup.has(Vector2i(x, y)):
				continue
			if R.next() < float(kit.cadenas) * .18:
				D.pared.append({"t": "cadenas", "cx": x, "cy": y, "n": 1 + int(R.next() * 2), "v": int(R.next() * 9999)})
				ocup[Vector2i(x, y)] = true
			elif R.next() < float(kit.humedad) * hum * .14:
				D.pared.append({"t": "humedad", "cx": x, "cy": y, "v": int(R.next() * 9999)})
	# hollín sobre todas las antorchas
	for e in L.torches:
		D.pared.append({"t": "hollin", "cx": int(e.cx), "cy": int(e.cy), "v": int(R.next() * 9999)})

# ---------------------------------------------------------------- abismo

## pisos 3–5: cadenas que cuelgan de los bordes hacia el vacío
static func _abismo(L: Dictionary, P: Dictionary, R: Mulberry32, D: Dictionary) -> void:
	var G: PackedByteArray = L.grid
	var GW := DungeonGen.GW
	var p := float(P.get("cadenas_abismo", 0.0))
	if p <= 0:
		return
	for y in range(1, DungeonGen.GH - 2):
		for x in range(1, GW - 1):
			if G[y * GW + x] == DungeonGen.FLOOR and G[(y + 1) * GW + x] == DungeonGen.ABISMO and R.next() < p:
				D.pared.append({"t": "cadena_abismo", "cx": x, "cy": y, "l": 40 + int(R.next() * 50), "ox": 6 + int(R.next() * 20), "v": int(R.next() * 9999)})

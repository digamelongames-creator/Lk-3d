class_name DungeonGen
## Generador de mazmorras traducido línea a línea de genLevel/tryGen/placeChests del juego web.
## Regla: no «mejorarlo». La misma semilla debe dar el mismo mapa casilla a casilla
## (lo comprueba tests/test_mapas.gd contra mapas sacados del navegador).

## tamaño del mapa: ×3 de superficie (83 × 59) con el triple de salas; fijar_grande(false) vuelve al de la web (48 × 34)
## reparto de anchos de pasillo (1, 2 o 3 casillas; el resto hasta 1 es de 3) y cuántos van en zigzag
const ANCHO_1 := .2
const ANCHO_2 := .6
const ZIGZAG := .35
const GW_WEB := 48
const GH_WEB := 34
const GW_GRANDE := 83
const GH_GRANDE := 59
const ESCALA_SALAS := 3
static var grande := true
static var GW := GW_GRANDE
static var GH := GH_GRANDE
const TS := 32
static var N := GW * GH
const D4 := [[0, -1], [1, 0], [0, 1], [-1, 0]]

# códigos de casilla
const ROCK := 0
const FLOOR := 1
const WATER := 2
const DOOR := 3
const GRAVE := 4
const PILLAR := 5
const RUBBLE := 6
const UP := 7
const DOWN := 8
const BRIDGE := 9
const DECOR := 10
const ABISMO := 11   # vacío del piso de pasarelas: si lo pisas, te caes

## editor de mapas: casillas que se suman al ancho y alto de las salas (0 = como siempre, mismo mapa que la web)
static var tam_salas := 0
## piso de pasarelas sobre el abismo (Plataformas.PISO); test_mapas lo apaga para comparar con la web
static var plataformas := true

## cambia el tamaño del mapa (test_mapas lo apaga para comparar con la web)
static func fijar_grande(si: bool) -> void:
	grande = si
	GW = GW_GRANDE if si else GW_WEB
	GH = GH_GRANDE if si else GH_WEB
	N = GW * GH

## multiplicador de salas, patrullas y emboscadas
static func escala() -> int:
	return ESCALA_SALAS if grande else 1

static func is_solid(t: int) -> bool:
	return t == 0 or t == 2 or t == 3 or t == 4 or t == 5 or t == 10 or t == 11

static func is_opaque(t: int) -> bool:
	return t == 0 or t == 3 or t == 5

static func walk(t: int) -> bool:
	return not is_solid(t)

## genLevel(seed, wave): prueba semillas seed#0 … seed#29 y, si ninguna sirve, seed#final forzada.
static func gen_level(seed: String, wave: int, force_theme: String = "") -> Dictionary:
	var theme := force_theme if force_theme != "" else GameData.theme_for_depth(wave)
	if plataformas and wave == Descenso.PISO:
		return _gen_descenso(seed, wave, theme)
	for a in 30:
		var L := try_gen(seed + "#" + str(a), wave, a < 15, false, theme)
		if not L.is_empty():
			L["theme"] = theme
			L["wave"] = wave
			_post(L)
			return L
	var L2 := try_gen(seed + "#final", wave, false, true, theme)
	L2["theme"] = theme
	L2["wave"] = wave
	_post(L2)
	return L2

## planta 5: de las semillas válidas, la primera que da una escalera larga y varios niveles (si no, la primera válida)
static func _gen_descenso(seed: String, wave: int, theme: String) -> Dictionary:
	var primero := {}
	for a in 30:
		var L := try_gen(seed + "#" + str(a), wave, a < 15, false, theme)
		if L.is_empty():
			continue
		L["theme"] = theme
		L["wave"] = wave
		_post(L)
		if Descenso.bueno(L):
			return L
		if primero.is_empty():
			primero = L
	if not primero.is_empty():
		return primero
	var L2 := try_gen(seed + "#final", wave, false, true, theme)
	L2["theme"] = theme
	L2["wave"] = wave
	_post(L2)
	return L2

## pisos con las losetas pintadas del nivel A (Losetas); test_mapas lo apaga
static var losetas := true
const PISOS_LOSETAS := [1, 2, 3]

static func _post(L: Dictionary) -> void:
	if plataformas and Plataformas.PISOS.has(int(L.wave)):
		Plataformas.aplicar(L)
	# última etapa: el decorador (muebles y adornos)
	Decorador.aplicar(L)
	MapaPruebas.marcar(L)
	if losetas and not L.has("estilo") and PISOS_LOSETAS.has(int(L.wave)) and not MapaPruebas.es(L):
		L["estilo"] = "a"

static func _bfs(grid: PackedByteArray, sx: int, sy: int) -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(N)
	d.fill(-1)
	var q := PackedInt32Array()
	q.append(sy * GW + sx)
	d[q[0]] = 0
	var h := 0
	while h < q.size():
		var i := q[h]
		h += 1
		var x := i % GW
		var y := i / GW
		for dd in D4:
			var nx: int = x + dd[0]
			var ny: int = y + dd[1]
			if nx < 0 or ny < 0 or nx >= GW or ny >= GH:
				continue
			var j := ny * GW + nx
			if d[j] < 0 and walk(grid[j]):
				d[j] = d[i] + 1
				q.append(j)
	return d

static func try_gen(seed: String, wave: int, canals: bool, force: bool, theme: String) -> Dictionary:
	var TD := GameData.theme_deco_for(theme)
	var R := Mulberry32.new(JS.hash_str(seed))
	var grid := PackedByteArray(); grid.resize(N)
	var corr := PackedByteArray(); corr.resize(N)
	var room_of := PackedInt32Array(); room_of.resize(N); room_of.fill(-1)
	var vv := PackedFloat32Array(); vv.resize(N)
	var at := func(x: int, y: int) -> int:
		return grid[y * GW + x] if (x >= 0 and y >= 0 and x < GW and y < GH) else 0

	# ---- salas ----
	var rooms: Array = []
	var NR := (11 + mini(3, wave >> 1)) * escala()
	var RMAX := 9
	var ots := tam_salas
	if ots != 0:
		NR = maxi(6, NR - maxi(0, ots) * 2)
	var tries := 0
	while rooms.size() < NR:
		tries += 1
		if tries - 1 >= NR * 150:
			break
		var w := R.ri(5, RMAX) if ots == 0 else R.ri(maxi(3, 5 + ots), maxi(3, RMAX + ots))
		var h := R.ri(5, 8) if ots == 0 else R.ri(maxi(3, 5 + ots), maxi(3, 8 + ots))
		var x := R.ri(2, GW - w - 3)
		var y := R.ri(2, GH - h - 3)
		var clash := false
		for r in rooms:
			if x < r.x + r.w + 3 and x + w + 3 > r.x and y < r.y + r.h + 3 and y + h + 3 > r.y:
				clash = true
				break
		if clash:
			continue
		rooms.append({"x": x, "y": y, "w": w, "h": h, "cx": x + (w >> 1), "cy": y + (h >> 1)})
	if rooms.size() < (8 * escala() if ots <= 0 else mini(8 * escala(), NR - 1)) and not force:
		return {}
	for k in rooms.size():
		var r: Dictionary = rooms[k]
		for y in range(r.y, r.y + r.h):
			for x in range(r.x, r.x + r.w):
				grid[y * GW + x] = 1
				room_of[y * GW + x] = k
	var nodes: Array = []
	for r in rooms:
		nodes.append({"x": r.cx, "y": r.cy})

	# ---- mordiscos de cueva (autómata celular) ----
	var bites := 3 if theme == "cave" else (1 if R.next() < .7 else 0)
	for bi in bites:
		var rad := R.ri(4, 6)
		var cx := R.ri(rad + 1, GW - rad - 2)
		var cy := R.ri(rad + 1, GH - rad - 2)
		var D := rad * 2 + 1
		var m := PackedByteArray(); m.resize(D * D)
		for j in D:
			for i in D:
				var d := JS.hypot(i - rad, j - rad) / rad
				m[j * D + i] = 1 if (d < 1 and R.next() < .64 - d * .22) else 0
		for it in 4:
			var n := PackedByteArray(); n.resize(D * D)
			for j in D:
				for i in D:
					if JS.hypot(i - rad, j - rad) >= rad:
						continue
					var c := 0
					for b in range(-1, 2):
						for a in range(-1, 2):
							if a == 0 and b == 0:
								continue
							var ii := i + a
							var jj := j + b
							if ii >= 0 and jj >= 0 and ii < D and jj < D:
								c += m[jj * D + ii]
					n[j * D + i] = 1 if c >= 5 else (0 if c <= 2 else m[j * D + i])
			m = n
		for b in range(-1, 2):
			for a in range(-1, 2):
				m[(rad + b) * D + rad + a] = 1
		for j in D:
			for i in D:
				if not m[j * D + i]:
					continue
				var gx := cx - rad + i
				var gy := cy - rad + j
				if gx >= 1 and gy >= 1 and gx < GW - 1 and gy < GH - 1 and grid[gy * GW + gx] == 0:
					grid[gy * GW + gx] = 1
		nodes.append({"x": cx, "y": cy})

	# ---- árbol de expansión mínima + algún bucle ----
	var n_nodes := nodes.size()
	var in_t := []
	in_t.resize(n_nodes); in_t.fill(false)
	var edges: Array = []
	var has := {}
	var dist := func(a: int, b: int) -> int:
		return absi(nodes[a].x - nodes[b].x) + absi(nodes[a].y - nodes[b].y)
	var key := func(a: int, b: int) -> String:
		return (str(a) + "-" + str(b)) if a < b else (str(b) + "-" + str(a))
	in_t[0] = true
	for k in range(1, n_nodes):
		var best = null
		var bd := 1000000000
		for i in n_nodes:
			if in_t[i]:
				for j in n_nodes:
					if not in_t[j]:
						var dd: int = dist.call(i, j)
						if dd < bd:
							bd = dd
							best = [i, j]
		edges.append(best)
		has[key.call(best[0], best[1])] = true
		in_t[best[1]] = true
	for i in n_nodes:
		if R.next() >= .18:
			continue
		var order := []
		for j in n_nodes:
			if j != i and not has.has(key.call(i, j)):
				order.append(j)
		order = JS.stable_sort(order, func(a, b): return dist.call(i, a) - dist.call(i, b))
		if order.size():
			var j: int = order[0]
			edges.append([i, j])
			has[key.call(i, j)] = true

	# ---- pasillos (9 nov, decidido por Diego): unos pocos estrechos de 1 casilla, la mayoría de 2 y algunas
	# galerías de 3; en L como siempre o en zigzag (escalones de 3–5 casillas) para que no sean todos iguales ----
	var cw := [2]
	var dig := func(x: int, y: int) -> void:
		for j in cw[0]:
			for i in cw[0]:
				var X: int = x + i
				var Y: int = y + j
				if X < 1 or Y < 1 or X >= GW - 1 or Y >= GH - 1:
					continue
				var kk: int = Y * GW + X
				if grid[kk] == 0:
					grid[kk] = 1
					corr[kk] = 1
	# tramo recto de (x0, y0) a (x1, y1), con los dos extremos (solo en horizontal o en vertical)
	var tramo := func(x0: int, y0: int, x1: int, y1: int) -> void:
		var sx := int(JS.sign(x1 - x0))
		var sy := int(JS.sign(y1 - y0))
		var x := x0
		var y := y0
		while true:
			dig.call(x, y)
			if x == x1 and y == y1:
				break
			x += sx
			y += sy
	for e in edges:
		var A: Dictionary = nodes[e[0]]
		var B: Dictionary = nodes[e[1]]
		var hf := R.next() < .5
		var r := R.next()
		cw[0] = 1 if r < ANCHO_1 else (2 if r < ANCHO_1 + ANCHO_2 else 3)
		var zig := R.next() < ZIGZAG and absi(B.x - A.x) >= 6 and absi(B.y - A.y) >= 6
		if zig:
			var x: int = A.x
			var y: int = A.y
			var hor := hf
			while x != B.x or y != B.y:
				var paso := 3 + int(R.next() * 3)
				if hor and x != B.x:
					var nx: int = x + int(JS.sign(B.x - x)) * mini(paso, absi(B.x - x))
					tramo.call(x, y, nx, y)
					x = nx
				elif not hor and y != B.y:
					var ny: int = y + int(JS.sign(B.y - y)) * mini(paso, absi(B.y - y))
					tramo.call(x, y, x, ny)
					y = ny
				hor = not hor
		elif hf:
			tramo.call(A.x, A.y, B.x, A.y)
			tramo.call(B.x, A.y, B.x, B.y)
		else:
			tramo.call(A.x, A.y, A.x, B.y)
			tramo.call(A.x, B.y, B.x, B.y)

	# ---- canal con puentes ----
	if canals and (wave >= 2 or theme != "castle") and R.next() < (.8 if (theme == "hell" or theme == "souls" or theme == "forge") else .55):
		var horiz := R.next() < .5
		var Ln := GW if horiz else GH
		var M := GH if horiz else GW
		var p := floorf(M * (.3 + R.next() * .4))
		var drift := 0.0
		var pos := []
		for t in Ln:
			drift = maxf(-.7, minf(.7, drift + (R.next() - .5) * .5))
			p = maxf(4, minf(M - 6, p + drift))
			pos.append(JS.roundi(p))
		var idx := func(t: int, m2: int) -> int:
			return m2 * GW + t if horiz else t * GW + m2
		var cross := []
		for t in Ln:
			cross.append(grid[idx.call(t, pos[t] - 1)] != 0 and grid[idx.call(t, pos[t] + 2)] != 0)
		for t in Ln:
			for k in 2:
				var i: int = idx.call(t, pos[t] + k)
				if grid[i] != 0:
					grid[i] = 2
					corr[i] = 0
		var t := 0
		while t < Ln:
			if not cross[t]:
				t += 1
				continue
			var s := t
			while t < Ln and cross[t]:
				t += 1
			var mid := (s + t - 1) >> 1
			if mid < t:
				for k in 2:
					grid[idx.call(mid, pos[mid] + k)] = 9

	# ---- la entrada en un extremo del mapa ----
	var left_to_right := R.next() < .5
	var start_room := 0
	for k in rooms.size():
		var r: Dictionary = rooms[k]
		if (r.cx < rooms[start_room].cx) if left_to_right else (r.cx > rooms[start_room].cx):
			start_room = k
	var sR: Dictionary = rooms[start_room]
	var d0 := _bfs(grid, sR.cx, sR.cy)
	# ---- la escalera de bajada en la casilla más lejana (bloque de 2×2) ----
	var far := -1
	var fd := -1
	for y in GH - 1:
		for x in GW - 1:
			var i := y * GW + x
			var k := room_of[i]
			if k < 0 or k == start_room or d0[i] < 0:
				continue
			if room_of[i + 1] != k or room_of[i + GW] != k or room_of[i + GW + 1] != k:
				continue
			if grid[i] != 1 or grid[i + 1] != 1 or grid[i + GW] != 1 or grid[i + GW + 1] != 1:
				continue
			var rk: Dictionary = rooms[k]
			if x <= rk.x or y <= rk.y or x + 1 >= rk.x + rk.w - 1 or y + 1 >= rk.y + rk.h - 1:
				continue
			if d0[i] > fd:
				fd = d0[i]
				far = i
	if far < 0 or (fd < 34 and not force):
		return {}
	if far < 0:
		return {}
	var end_room := room_of[far]
	for i in [far, far + 1, far + GW, far + GW + 1]:
		grid[i] = DOWN
	grid[sR.cy * GW + sR.cx] = UP

	# ---- fuente a mitad de camino ----
	var fount = null
	var fc := []
	for k in rooms.size():
		var r: Dictionary = rooms[k]
		var o := {"r": r, "k": k, "d": d0[r.cy * GW + r.cx]}
		if o.k != start_room and o.k != end_room and r.w >= 6 and r.h >= 6 and o.d > 0:
			fc.append(o)
	fc = JS.stable_sort(fc, func(a, b): return absf(a.d - fd * .5) - absf(b.d - fd * .5))
	if fc.size():
		var r: Dictionary = fc[0].r
		fount = {"x": (r.x + r.w / 2.0) * TS, "y": (r.y + r.h / 2.0) * TS + 8, "room": fc[0].k}

	# ---- cementerio ----
	var grave_room := -1
	var bestA := 0
	for k in rooms.size():
		var r: Dictionary = rooms[k]
		if k == start_room or k == end_room or (fount != null and k == fount.room):
			continue
		if r.w >= 6 and r.h >= 6 and r.w * r.h > bestA:
			bestA = r.w * r.h
			grave_room = k
	if grave_room >= 0 and R.next() < .6:
		var r: Dictionary = rooms[grave_room]
		var y: int = r.y + 1
		while y < r.y + r.h - 1:
			var x: int = r.x + 1
			while x < r.x + r.w - 1:
				if not (x == r.cx or x == r.cx - 1 or y == r.cy or y == r.cy - 1):
					var i := y * GW + x
					if grid[i] == 1 and R.next() < .8:
						grid[i] = GRAVE
				x += 2
			y += 2
	else:
		grave_room = -1

	# ---- columnatas ----
	for k in rooms.size():
		var r: Dictionary = rooms[k]
		if k == grave_room or k == start_room or (fount != null and k == fount.room) or r.w < 7 or r.h < 7 or R.next() >= .5:
			continue
		var y: int = r.y + 2
		while y <= r.y + r.h - 3:
			for x in [r.x + 1, r.x + r.w - 2]:
				var i: int = y * GW + x
				var near_c := false
				for b in range(-1, 2):
					for a in range(-1, 2):
						if corr[(y + b) * GW + x + a]:
							near_c = true
				for b in range(-1, 2):
					if grid[(y + b) * GW + x - 1] == 1 and room_of[(y + b) * GW + x - 1] < 0:
						near_c = true
				for b in range(-1, 2):
					if grid[(y + b) * GW + x + 1] == 1 and room_of[(y + b) * GW + x + 1] < 0:
						near_c = true
				if not near_c and grid[i] == 1:
					grid[i] = PILLAR
			y += 3

	# ---- escombros ----
	for y in range(1, GH - 1):
		for x in range(1, GW - 1):
			var i := y * GW + x
			if grid[i] != 1 or corr[i]:
				continue
			if fount != null and room_of[i] == fount.room:
				continue
			var adj := false
			for dd in D4:
				if at.call(x + dd[0], y + dd[1]) == 0:
					adj = true
					break
			if R.next() < (.07 if adj else .012):
				grid[i] = RUBBLE

	# ---- muebles y objetos del suelo ----
	var decor := []
	var litter := []
	var flats := []
	var gold := []
	var key_tables := []
	var solidS := GameData.theme_props(theme, "s")
	var flatS := GameData.theme_props(theme, "f")
	var kay: Array = TD.kay
	var blocked_near := func(x: int, y: int) -> bool:
		for b in range(-1, 2):
			for a in range(-1, 2):
				var j := (y + b) * GW + x + a
				var t: int = at.call(x + a, y + b)
				if t == DECOR or t == DOWN or t == UP or t == PILLAR or t == GRAVE or (t != 0 and room_of[j] < 0):
					return true
		return false
	var wall_ok := func(x: int, y: int) -> bool:
		return at.call(x, y) == 1 and at.call(x, y - 1) == 0 and not blocked_near.call(x, y)
	var pick_solid := func() -> Dictionary:
		if kay.size() and R.next() < float(TD.kayK):
			return {"n": kay[int(R.next() * kay.size())]}
		return {"tp": solidS[int(R.next() * solidS.size())].i}
	var put_s := func(x: int, y: int, sp: Dictionary) -> void:
		grid[y * GW + x] = DECOR
		var o := {"cx": x, "cy": y}
		o.merge(sp)
		decor.append(o)
		if sp.get("n", "") == "table_small_decorated_A" or sp.get("n", "") == "table_medium_tablecloth_decorated_B":
			key_tables.append(o)
	var pair := func(xa: int, xb: int, y: int, sp: Dictionary) -> bool:
		if xa > xb:
			return false
		if xa == xb:
			if wall_ok.call(xa, y):
				put_s.call(xa, y, sp)
				return true
			return false
		if wall_ok.call(xa, y) and wall_ok.call(xb, y):
			put_s.call(xa, y, sp)
			put_s.call(xb, y, sp)
			return true
		return false
	var big_flat := func():
		var fs := JS.stable_sort(flatS, func(a, b): return b.w * b.h - a.w * a.h)
		return fs[int(floorf(R.next() * mini(3, fs.size())))] if fs.size() else null
	var floor_px := func(x: float, y: float) -> bool:
		return at.call(int(floorf(x / TS)), int(floorf(y / TS))) == 1
	var layouts: Array = TD.layouts
	var tlitter: Array = TD.litter
	for k in rooms.size():
		var r: Dictionary = rooms[k]
		if k == start_room or (fount != null and k == fount.room) or k == grave_room:
			continue
		var y: int = r.y
		var x0: int = r.x
		var x1: int = r.x + r.w - 1
		var lc := int(floorf((x0 + x1) / 2.0))
		var rc := int(ceilf((x0 + x1) / 2.0))
		var mx: float = (r.x + r.w / 2.0) * TS
		var my: float = (r.y + r.h / 2.0) * TS + 6
		var lay: String = layouts[int(floorf(R.next() * layouts.size()))]
		if lay == "store":
			var n := 1 + (1 if R.next() < .6 else 0)
			var o := 0
			while o < int(floorf(r.w / 2.0)) and n > 0:
				if pair.call(x0 + o, x1 - o, y, pick_solid.call()):
					n -= 1
					o += 1
				o += 1
		elif lay == "gallery":
			var sp: Dictionary = pick_solid.call()
			var o := 1
			while o < int(floorf(r.w / 2.0)):
				pair.call(x0 + o, x1 - o, y, sp)
				o += 2
			var f = big_flat.call()
			if f != null:
				flats.append({"x": mx, "y": my, "i": f.i, "flip": false})
		elif lay == "ritual":
			var f = big_flat.call()
			if f != null:
				flats.append({"x": mx, "y": my, "i": f.i, "flip": false})
			var dx := maxf(24, (f.w / 2.0 if f != null else 14.0) + 8)
			var dy := maxf(18, (f.h / 2.0 if f != null else 12.0) + 6)
			for sxy in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
				if floor_px.call(mx + sxy[0] * dx, my + sxy[1] * dy):
					litter.append({"x": mx + sxy[0] * dx, "y": my + sxy[1] * dy + 8, "n": "candle_triple"})
			pair.call(lc - 1, rc + 1, y, pick_solid.call())
		elif lay == "dining":
			var cx := int(floorf(mx / TS))
			var cy := int(floorf((my - 6) / TS))
			if at.call(cx, cy) == 1 and not blocked_near.call(cx, cy):
				put_s.call(cx, cy, {"n": "table_small_decorated_A" if R.next() < .6 else "table_medium_tablecloth_decorated_B"})
				for sx in [-1, 1]:
					if at.call(cx + sx, cy) == 1:
						litter.append({"x": (cx + .5 + sx * .95) * TS, "y": (cy + .95) * TS, "n": "stool"})
			pair.call(x0, x1, y, {"n": "barrel_large" if R.next() < .5 else "barrel_small_stack"})
		else:
			var left := R.next() < .5
			var n := 2 + (1 if R.next() < .5 else 0)
			var o := 0
			while o < r.w and n > 0:
				var x := x0 + o if left else x1 - o
				if wall_ok.call(x, y):
					put_s.call(x, y, pick_solid.call())
					n -= 1
				o += 1
			var q := 0
			while q < 2 and flatS.size():
				var f: Dictionary = flatS[int(R.next() * flatS.size())]
				var fx: float = ((x0 + .8 + q * 1.3) if left else (x1 + .2 - q * 1.3)) * TS
				var fy: float = (y + 1.7 + q * .7) * TS
				if floor_px.call(fx, fy):
					flats.append({"x": fx, "y": fy, "i": f.i, "flip": R.next() < .5})
				q += 1
		# escombros y velas sueltas pegados a las paredes
		if tlitter.size() and R.next() < .5:
			var side := x0 if R.next() < .5 else x1
			var yy := y + 1 + int(floorf(R.next() * (r.h - 2)))
			if at.call(side, yy) == 1:
				litter.append({"x": (side + .5 + (-.15 if side == x0 else .15)) * TS, "y": (yy + .8) * TS, "n": tlitter[int(R.next() * tlitter.size())]})
		if R.next() < .4:
			var x: int = r.x + int(R.next() * r.w)
			var yy: int = r.y + int(R.next() * r.h)
			if grid[yy * GW + x] == 1:
				gold.append({"x": (x + .5) * TS, "y": (yy + .6) * TS, "amt": JS.roundi((4 + R.next() * 8) * (1 + wave * .12))})
	for i in N:
		vv[i] = R.next()

	# ---- nada aislado: un puente o un vado hasta el suelo sin paso ----
	for it in 40:
		var dd := _bfs(grid, sR.cx, sR.cy)
		var lost := -1
		for i in N:
			if dd[i] < 0 and walk(grid[i]) and grid[i] != DOOR:
				lost = i
				break
		if lost < 0:
			break
		var pr := PackedInt32Array(); pr.resize(N); pr.fill(-2)
		var q := PackedInt32Array()
		for i in N:
			if dd[i] >= 0:
				pr[i] = -1
				q.append(i)
		var hit := -1
		var h := 0
		while h < q.size() and hit < 0:
			var i := q[h]
			h += 1
			var x := i % GW
			var y := i / GW
			for d4 in D4:
				var nx: int = x + d4[0]
				var ny: int = y + d4[1]
				if nx < 1 or ny < 1 or nx >= GW - 1 or ny >= GH - 1:
					continue
				var j := ny * GW + nx
				if pr[j] != -2 or grid[j] == 0:
					continue
				pr[j] = i
				if walk(grid[j]):
					hit = j
					break
				q.append(j)
		if hit < 0:
			# bolsa encerrada en roca: se rellena
			var st := [lost]
			var seen := {lost: true}
			while st.size():
				var i: int = st.pop_back()
				grid[i] = 0
				corr[i] = 0
				for d4 in D4:
					var j: int = i + d4[1] * GW + d4[0]
					if not seen.has(j) and walk(grid[j]):
						seen[j] = true
						st.append(j)
			continue
		var path := []
		var j := pr[hit]
		while j >= 0 and dd[j] < 0:
			path.append(j)
			j = pr[j]
		var wet := 0
		for jj in path:
			if grid[jj] == 2:
				wet += 1
		for jj in path:
			if grid[jj] == 2:
				grid[jj] = 9 if wet <= 3 else 1
			else:
				grid[jj] = 1

	# ---- la escalera sigue accesible ----
	var d := _bfs(grid, sR.cx, sR.cy)
	if d[far] < 0 and not force:
		return {}
	if not force:
		for r in rooms:
			if d[r.cy * GW + r.cx] < 0 and grid[r.cy * GW + r.cx] == 1:
				return {}
	var chests := _place_chests(grid, corr, room_of, rooms, d, far, start_room, end_room, fount, R, wave, sR)

	# ---- paredes: antorchas y adornos simétricos en la pared norte; vegetación por todas partes ----
	var is_c := func(x: int, y: int) -> bool:
		return x >= 1 and y >= 2 and x < GW - 1 and y < GH - 1 and not corr[y * GW + x] and grid[y * GW + x] != 0 and grid[y * GW + x] != 2 and grid[y * GW + x] != 9 and grid[(y - 1) * GW + x] == 0
	var mk_t := func(x: int, y: int) -> Dictionary:
		return {"cx": x, "cy": y, "x": (x + .5) * TS, "y": (y - 1) * TS + 11}
	var torches := []
	var wall_deco := []
	var wall_veg := []
	var used := {}
	var K := func(x: int, y: int) -> int: return y * GW + x
	var wfree := func(x: int, y: int) -> bool:
		return is_c.call(x, y) and not used.has(K.call(x, y)) and not used.has(K.call(x - 1, y)) and not used.has(K.call(x + 1, y))
	var wallW := GameData.theme_props(theme, "w")
	var vegW := GameData.theme_props(theme, "v")
	var twall: Array = TD.wall
	var twall_nokey := []
	for nm in twall:
		if nm != "keyring_hanging":
			twall_nokey.append(nm)
	var pick_wall := func() -> Dictionary:
		if twall.size() and R.next() < .35:
			return {"n": twall_nokey[int(floorf(R.next() * twall_nokey.size()))]}
		return {"tp": wallW[int(floorf(R.next() * wallW.size()))].i}
	# huecos en la pared norte (donde entra un pasillo): una antorcha a cada lado
	var gaps := []
	for y in range(2, GH - 1):
		var x := 1
		while x < GW - 1:
			var i := y * GW + x
			if room_of[i] >= 0 and grid[i - GW] != 0 and is_c.call(x - 1, y):
				var x1 := x
				while x1 + 1 < GW - 1 and room_of[y * GW + x1 + 1] >= 0 and grid[(y - 1) * GW + x1 + 1] != 0:
					x1 += 1
				if x1 - x <= 3 and is_c.call(x1 + 1, y):
					gaps.append({"y": y, "a": x - 1, "b": x1 + 1})
				x = x1 + 1
			else:
				x += 1
	for gp in gaps:
		if R.next() < .8:
			torches.append(mk_t.call(gp.a, gp.y))
			torches.append(mk_t.call(gp.b, gp.y))
			used[K.call(gp.a, gp.y)] = true
			used[K.call(gp.b, gp.y)] = true
	var wallK: float = TD.wallK
	for k in rooms.size():
		var r: Dictionary = rooms[k]
		var y: int = r.y
		var x0: int = r.x
		var x1: int = r.x + r.w - 1
		var has_t := false
		for t in torches:
			if t.cy == y and t.cx >= x0 - 1 and t.cx <= x1 + 1:
				has_t = true
				break
		if not has_t:
			var o: int = maxi(1, JS.roundi((r.w - 1) / 4.0))
			if x0 + o < x1 - o and wfree.call(x0 + o, y) and wfree.call(x1 - o, y):
				torches.append(mk_t.call(x0 + o, y))
				torches.append(mk_t.call(x1 - o, y))
				used[K.call(x0 + o, y)] = true
				used[K.call(x1 - o, y)] = true
		var items := [pick_wall.call(), pick_wall.call()]
		for o in int(ceilf(r.w / 2.0)):
			var xa := x0 + o
			var xb := x1 - o
			if xa > xb:
				break
			if R.next() >= wallK:
				continue
			var itm: Dictionary = items[o % 2]
			if xa == xb:
				if wfree.call(xa, y):
					var w := {"cx": xa, "cy": y}; w.merge(itm)
					wall_deco.append(w)
					used[K.call(xa, y)] = true
			elif wfree.call(xa, y) and wfree.call(xb, y):
				var wa := {"cx": xa, "cy": y}; wa.merge(itm)
				var wb := {"cx": xb, "cy": y}; wb.merge(itm)
				wall_deco.append(wa)
				wall_deco.append(wb)
				used[K.call(xa, y)] = true
				used[K.call(xb, y)] = true
	# llaves colgadas: una o dos por piso
	var free := []
	for y in range(2, GH - 1):
		for x in range(1, GW - 1):
			if wfree.call(x, y) and room_of[y * GW + x] >= 0 and room_of[y * GW + x] != start_room:
				free.append([x, y])
	var nk := 1 + (1 if R.next() < .35 else 0)
	while nk > 0 and free.size():
		var pick: Array = free.pop_at(int(floorf(R.next() * free.size())))
		var x: int = pick[0]
		var y: int = pick[1]
		if not wfree.call(x, y):
			continue
		wall_deco.append({"cx": x, "cy": y, "n": "keyring_hanging"})
		used[K.call(x, y)] = true
		nk -= 1
	# vegetación y grietas que trepan por cualquier pared
	var veg: float = TD.veg
	if vegW.size():
		for y in range(2, GH - 1):
			for x in range(1, GW - 1):
				var t := grid[y * GW + x]
				if t == 0 or t == 2 or t == 9 or grid[(y - 1) * GW + x] != 0:
					continue
				if R.next() < veg:
					var vi: int = vegW[int(floorf(R.next() * vegW.size()))].i
					var ox := R.next()
					var flip := R.next() < .5
					wall_veg.append({"cx": x, "cy": y, "i": vi, "ox": ox, "flip": flip})

	# ---- puertas: solo si todas las entradas de la sala están en la pared norte o sur ----
	var doors := []
	var entrances := []
	for k in rooms.size():
		var r: Dictionary = rooms[k]
		var list := []
		var eds := []
		for pr2 in [[r.y - 1, r.y - 2], [r.y + r.h, r.y + r.h + 1]]:
			var cs := []
			for x in range(r.x, r.x + r.w):
				cs.append([x, pr2[0], x, pr2[1]])
			eds.append({"cs": cs, "h": true})
		for pr2 in [[r.x - 1, r.x - 2], [r.x + r.w, r.x + r.w + 1]]:
			var cs := []
			for y in range(r.y, r.y + r.h):
				cs.append([pr2[0], y, pr2[1], y])
			eds.append({"cs": cs, "h": false})
		for ed in eds:
			var run := []
			var flush := func() -> void:
				if run.size():
					var f: Array = run[0]
					var l: Array = run[run.size() - 1]
					var before: int = at.call(f[0] - 1, f[1]) if ed.h else at.call(f[0], f[1] - 1)
					var after: int = at.call(l[0] + 1, l[1]) if ed.h else at.call(l[0], l[1] + 1)
					var ok: bool = ed.h and run.size() <= 3 and before == 0 and after == 0
					if ok:
						for c in run:
							var t: int = at.call(c[2], c[3])
							if not (t == 1 and corr[c[3] * GW + c[2]] and room_of[c[3] * GW + c[2]] < 0):
								ok = false
								break
					for c in run:
						for b in range(-1, 2):
							for a in range(-1, 2):
								var t: int = at.call(c[0] + a, c[1] + b)
								if t == DECOR or t == DOWN or t == UP or t == DOOR:
									ok = false
					list.append({"ok": ok, "run": run.duplicate(), "h": ed.h})
				run.clear()
			for c in ed.cs:
				var i: int = c[1] * GW + c[0]
				var t: int = at.call(c[0], c[1])
				if t != 0 and room_of[i] < 0:
					run.append(c)
				else:
					flush.call()
			flush.call()
		entrances.append(list)
	var eligible := func(k: int) -> bool:
		if k == start_room or entrances[k].size() == 0:
			return false
		for e in entrances[k]:
			if not e.ok:
				return false
		return true
	var want := {}
	for c in chests:
		if c.kind == "gold" and c.get("room") != null and eligible.call(c.room):
			want[c.room] = true
	if eligible.call(end_room):
		want[end_room] = true
	var others := []
	for k in rooms.size():
		if not want.has(k) and eligible.call(k):
			others.append(k)
	var i2 := others.size() - 1
	while i2 > 0:
		var j := int(floorf(R.next() * (i2 + 1)))
		var tmp = others[i2]; others[i2] = others[j]; others[j] = tmp
		i2 -= 1
	var take := 1 + (1 if R.next() < .5 else 0)
	for k in others.slice(0, take):
		want[k] = true
	for k in want:
		for e in entrances[k]:
			var f: Array = e.run[0]
			var l: Array = e.run[e.run.size() - 1]
			var already := false
			for c in e.run:
				if grid[c[1] * GW + c[0]] == DOOR:
					already = true
					break
			if already:
				continue
			var cells := []
			for c in e.run:
				cells.append(c[1] * GW + c[0])
			for ci in cells:
				grid[ci] = DOOR
			doors.append({"cells": cells, "h": true, "room": k, "x0": f[0], "y0": f[1], "x1": l[0], "y1": l[1]})

	# ---- numeración de salas por distancia a la entrada ----
	var room_num := []
	room_num.resize(rooms.size()); room_num.fill(0)
	var ro := []
	for k in rooms.size():
		var r: Dictionary = rooms[k]
		ro.append({"k": k, "d": 1e9 if d[r.cy * GW + r.cx] < 0 else float(d[r.cy * GW + r.cx])})
	ro = JS.stable_sort(ro, func(a, b): return a.d - b.d)
	for idx in ro.size():
		room_num[ro[idx].k] = idx + 1
	var fx := far % GW
	var fy := far / GW
	return {"seed": seed, "grid": grid, "corr": corr, "room_of": room_of, "rooms": rooms, "room_num": room_num, "vv": vv,
		"start_room": start_room, "end_room": end_room, "grave_room": grave_room, "start": {"cx": sR.cx, "cy": sR.cy},
		"stairs_cell": {"cx": fx, "cy": fy}, "stairs_px": {"x": (fx + 1) * TS, "y": (fy + 1) * TS}, "fount": fount,
		"torches": torches, "dist": d, "decor": decor, "litter": litter, "wall_deco": wall_deco, "wall_veg": wall_veg,
		"flats": flats, "chests": chests, "gold": gold, "doors": doors, "key_tables": key_tables}

## Cofres: baúles en salas, el de hierro donde más se aleja del camino principal, el dorado en la sala más apartada.
static func _place_chests(grid: PackedByteArray, corr: PackedByteArray, room_of: PackedInt32Array, rooms: Array, d: PackedInt32Array,
		far: int, start_room: int, end_room: int, fount, R: Mulberry32, wave: int, sR: Dictionary) -> Array:
	var out := []
	var in_b := func(x: int, y: int) -> bool: return x >= 0 and y >= 0 and x < GW and y < GH
	var at := func(x: int, y: int) -> int:
		return grid[y * GW + x] if (x >= 0 and y >= 0 and x < GW and y < GH) else 0
	# camino principal y distancia de cada casilla a él
	var on_path := PackedByteArray(); on_path.resize(N)
	var cur := far
	var gd := 0
	while cur >= 0:
		gd += 1
		if gd - 1 >= 5000:
			break
		on_path[cur] = 1
		if d[cur] <= 0:
			break
		var x := cur % GW
		var y := cur / GW
		var nx := -1
		for dd in D4:
			if not in_b.call(x + dd[0], y + dd[1]):
				continue
			var j: int = (y + dd[1]) * GW + x + dd[0]
			if d[j] >= 0 and d[j] == d[cur] - 1:
				nx = j
				break
		cur = nx
	var off := PackedInt32Array(); off.resize(N); off.fill(-1)
	var q := PackedInt32Array()
	for i in N:
		if on_path[i]:
			off[i] = 0
			q.append(i)
	var h := 0
	while h < q.size():
		var i := q[h]
		h += 1
		var x := i % GW
		var y := i / GW
		for dd in D4:
			if not in_b.call(x + dd[0], y + dd[1]):
				continue
			var j: int = (y + dd[1]) * GW + x + dd[0]
			if off[j] < 0 and not is_solid(grid[j]):
				off[j] = off[i] + 1
				q.append(j)
	var fount_room: int = fount.room if fount != null else -1
	var ok := func(x: int, y: int, wall: bool) -> bool:
		var i := y * GW + x
		if at.call(x, y) != 1 or d[i] < 10 or room_of[i] < 0:
			return false
		for b in range(-1, 2):
			for a in range(-1, 2):
				var j := (y + b) * GW + x + a
				var t: int = at.call(x + a, y + b)
				if t != 0 and t != 2 and room_of[j] < 0:
					return false
		if room_of[i] == start_room or room_of[i] == fount_room:
			return false
		if fount != null and JS.hypot((x + .5) * TS - fount.x, (y + .5) * TS - fount.y) < TS * 3.5:
			return false
		if wall and at.call(x, y - 1) != 0:
			return false
		for b in range(-1, 2):
			for a in range(-1, 2):
				var t: int = at.call(x + a, y + b)
				if t == DECOR or t == PILLAR or t == GRAVE or t == DOWN or t == UP or t == DOOR or t == 2 or t == 9:
					return false
		for c in out:
			if absi(c.cx - x) + absi(c.cy - y) < 4:
				return false
		return true
	var reach := func(dd: PackedInt32Array) -> int:
		var n := 0
		for k in N:
			if dd[k] >= 0:
				n += 1
		return n
	var put := func(x: int, y: int, kind: String) -> bool:
		var i := y * GW + x
		var before: int = reach.call(_bfs(grid, sR.cx, sR.cy))
		grid[i] = DECOR
		var dd := _bfs(grid, sR.cx, sR.cy)
		var any_side := false
		for d4 in D4:
			if in_b.call(x + d4[0], y + d4[1]) and dd[(y + d4[1]) * GW + x + d4[0]] >= 0:
				any_side = true
				break
		var good: bool = reach.call(dd) >= before - 1 and dd[far] >= 0 and any_side
		for r in rooms:
			if grid[r.cy * GW + r.cx] == 1 and dd[r.cy * GW + r.cx] < 0:
				good = false
		for c in out:
			var reach_c := false
			for d4 in D4:
				if in_b.call(c.cx + d4[0], c.cy + d4[1]) and dd[(c.cy + d4[1]) * GW + c.cx + d4[0]] >= 0:
					reach_c = true
					break
			if not reach_c:
				good = false
		if not good:
			grid[i] = 1
			return false
		out.append({"cx": x, "cy": y, "kind": kind})
		return true
	var cells_of := func(r: Dictionary) -> Array:
		var a := []
		for y in range(r.y, r.y + r.h):
			for x in range(r.x, r.x + r.w):
				a.append([x, y])
		return a
	# dorado: salas guardadas por un enemigo dorado (desde el piso 2)
	var ng := 0
	if wave >= 2:
		ng = (1 if R.next() < (.25 if wave <= 5 else minf(.9, .35 + wave * .05)) else 0)
		ng += 1 if (wave >= 8 and R.next() < .4) else 0
	if ng:
		var cand := []
		for k in rooms.size():
			var r: Dictionary = rooms[k]
			var c := {"r": r, "k": k, "o": off[r.cy * GW + r.cx]}
			if c.k != start_room and c.k != end_room and c.k != fount_room and r.w >= 5 and r.h >= 5 and c.o >= 0:
				cand.append(c)
		cand = JS.stable_sort(cand, func(a, b): return b.o - a.o)
		for c in cand:
			if ng <= 0:
				break
			var r: Dictionary = c.r
			for dxy in [[0, -1], [0, 0], [1, -1], [-1, -1], [1, 0], [-1, 0]]:
				if ok.call(r.cx + dxy[0], r.cy + dxy[1], false) and put.call(r.cx + dxy[0], r.cy + dxy[1], "gold"):
					out[out.size() - 1]["room"] = c.k
					ng -= 1
					break
	# hierro: junto a una pared, lo más lejos posible del camino principal
	var best = null
	var bo := -1
	for y in range(1, GH - 1):
		for x in range(1, GW - 1):
			var i := y * GW + x
			if off[i] > bo and ok.call(x, y, true):
				bo = off[i]
				best = [x, y]
	if best != null:
		put.call(best[0], best[1], "iron")
	# baúles en salas al azar
	var rk := []
	for k in rooms.size():
		if k != start_room and k != fount_room:
			rk.append(k)
	var i3 := rk.size() - 1
	while i3 > 0:
		var j := int(floorf(R.next() * (i3 + 1)))
		var tmp = rk[i3]; rk[i3] = rk[j]; rk[j] = tmp
		i3 -= 1
	var nw := 2 + (1 if R.next() < .5 else 0)
	var extra := []
	if wave >= 2 and R.next() < .3:
		extra.append("cursed")
	for k in rk:
		if nw <= 0 and not extra.size():
			break
		var cs := []
		for c in cells_of.call(rooms[k]):
			if ok.call(c[0], c[1], true):
				cs.append(c)
		if not cs.size():
			continue
		var c: Array = cs[int(floorf(R.next() * cs.size()))]
		var kind: String = "wood" if nw > 0 else extra.pop_front()
		if put.call(c[0], c[1], kind):
			if kind == "wood":
				nw -= 1
	# mímico: uno de los baúles
	if wave >= 3 and R.next() < .25:
		var w := []
		for c in out:
			if c.kind == "wood":
				w.append(c)
		if w.size():
			w[int(floorf(R.next() * w.size()))]["kind"] = "mimic"
	return out

class_name SalaSecreta
## Salas secretas: detrás de algunas puertas negras de las paredes hay una sala apartada, tallada en una zona
## de roca del mismo mapa, sin pasillo que la una con el resto. Al pulsar Espacio junto a la puerta, la vista
## pregunta «¿Entrar?», funde a negro y el héroe aparece dentro (Sim.cruzar_secreta). Se sale por la misma puerta.
## Dentro: una élite más fuerte de lo normal, dos escoltas y dos cofres dorados que guarda la élite.
##
## L.secretas = [{fuera: Vector2i (suelo del piso junto a la puerta), puerta: Vector2i (muro con la puerta),
##   dentro: Vector2i (suelo de la sala junto a su puerta), puerta_dentro: Vector2i, sala: {x, y, w, h}}]

const ANCHO := [7, 9]
const ALTO := [6, 7]
const MENORES := [[6, 5], [5, 5]]   # si no cabe, se prueba más pequeña
const DIST_MIN := 12        # la puerta, lejos de la entrada del piso
const PUERTA_R := 34.0      # px: a esta distancia de la puerta se puede usar

## talla las salas en L (antes de que se pinte el piso). Pisos normales: una; desde el 4, a veces dos.
static func tallar(L: Dictionary, wave: int) -> void:
	if L.has("secretas"):
		return
	L["secretas"] = []
	if L.has("ciudad") or L.has("prueba"):
		return   # (en los pisos de pasarelas no suele haber roca libre y no sale)
	var R := Mulberry32.new(absi(hash(str(L.get("seed", "")) + "-secreta")))
	var n := 1 + (1 if wave >= 4 and R.next() < .5 else 0)
	for i in n:
		_una(L, R)

static func _una(L: Dictionary, R: Mulberry32) -> void:
	var W := DungeonGen.GW
	var H := DungeonGen.GH
	var g: PackedByteArray = L.grid
	# sitios de roca libres: la sala y su muro, todo roca y dentro del mapa
	var sitios := []
	var w := 0
	var h := 0
	for tam in [[R.ri(ANCHO[0], ANCHO[1]), R.ri(ALTO[0], ALTO[1])], [ANCHO[0], ALTO[0]]] + MENORES:
		w = tam[0]
		h = tam[1]
		for y in range(2, H - h - 2):
			for x in range(2, W - w - 2):
				if _roca(g, W, x - 1, y - 1, w + 2, h + 2):
					sitios.append(Vector2i(x, y))
		if sitios.size():
			break
	var puertas := _puertas(L)
	if sitios.is_empty() or puertas.is_empty():
		return
	var s: Vector2i = sitios[int(R.next() * sitios.size())]
	var pu: Array = puertas[int(R.next() * puertas.size())]
	for y in range(s.y, s.y + h):
		for x in range(s.x, s.x + w):
			g[y * W + x] = DungeonGen.FLOOR
	L.grid = g
	var cx := s.x + (w >> 1)
	var dentro := Vector2i(cx, s.y)
	# antorchas en la pared norte, a los lados de la puerta de dentro
	for tx in [s.x + 1, s.x + w - 2]:
		var tr := {"cx": tx, "cy": s.y, "x": (tx + .5) * DungeonGen.TS, "y": (s.y - 1) * DungeonGen.TS + 11}
		L.torches.append(tr)
		if L.has("torches_px"):
			L.torches_px.append(tr.duplicate())
	L.secretas.append({"fuera": pu[1], "puerta": pu[0], "dentro": dentro, "puerta_dentro": dentro + Vector2i(0, -1),
		"sala": {"x": s.x, "y": s.y, "w": w, "h": h}})

static func _roca(g: PackedByteArray, W: int, x0: int, y0: int, w: int, h: int) -> bool:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			if g[y * W + x] != DungeonGen.ROCK:
				return false
	return true

## muros donde puede ir la puerta: roca con una sola casilla de suelo de sala al sur o al este (las caras que
## se ven con la cámara), lejos de la entrada y sin antorcha ni adorno colgado en esa cara
static func _puertas(L: Dictionary) -> Array:
	var W := DungeonGen.GW
	var H := DungeonGen.GH
	var g: PackedByteArray = L.grid
	var sala: PackedInt32Array = L.get("room_of", PackedInt32Array())
	var dist: PackedInt32Array = L.get("dist", PackedInt32Array())
	var ocupado := {}
	for tr in L.get("torches", []):
		ocupado[Vector2i(tr.cx, tr.cy - 1)] = true
	for w in L.get("wall_deco", []):
		ocupado[Vector2i(w.cx, w.cy - 1)] = true
	for s in L.get("secretas", []):
		ocupado[s.puerta] = true
		ocupado[s.fuera] = true
	var out := []
	for y in range(2, H - 2):
		for x in range(2, W - 2):
			if g[y * W + x] != DungeonGen.ROCK:
				continue
			var d := Vector2i(x, y)
			if ocupado.has(d):
				continue
			var pis := 0
			for d4 in DungeonGen.D4:
				var t := g[(y + d4[1]) * W + x + d4[0]]
				if t != DungeonGen.ROCK and t != DungeonGen.ABISMO:
					pis += 1
			if pis != 1:
				continue
			for dir in [Vector2i(0, 1), Vector2i(1, 0)]:
				var f: Vector2i = d + dir
				var i := f.y * W + f.x
				if g[i] != DungeonGen.FLOOR or (sala.size() and sala[i] < 0) or (sala.size() and sala[i] == L.get("start_room", -1)):
					continue
				if dist.size() and dist[i] < DIST_MIN:
					continue
				if ocupado.has(f):
					continue
				# las vecinas de la puerta a lo largo del muro también son muro (que no sea una esquina)
				var lado := Vector2i(dir.y, dir.x)
				if g[(d + lado).y * W + (d + lado).x] != DungeonGen.ROCK or g[(d - lado).y * W + (d - lado).x] != DungeonGen.ROCK:
					continue
				out.append([d, f])
	return out

## punto de la puerta en px (el borde entre el muro y el suelo)
static func punto(muro: Vector2i, suelo: Vector2i) -> Vector2:
	var TS := DungeonGen.TS
	return Vector2((muro.x + suelo.x + 1) * TS / 2.0, (muro.y + suelo.y + 1) * TS / 2.0)

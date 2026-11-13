class_name Suciedad3D
## Calcomanías (Decal) que ensucian la mazmorra: hollín encima de cada antorcha, humedad y verdín en la base
## de los muros altos y manchas y grietas en el suelo de las salas. Las texturas salen de ruido (no son
## dibujos provisionales: son el propio material de la suciedad). Todo fijo por casilla (hash), sin azar.
## MazmorraGridMap.construir llama a poner() al final.

const MAX_HUMEDAD := 160
const MAX_SUELO := 90
static var _tex := {}

static func limpiar() -> void:
	_tex.clear()

## textura de una mancha: ruido recortado por un degradado (radial o desde abajo), en escala de grises con alfa
static func _textura(clase: String) -> Texture2D:
	if _tex.has(clase):
		return _tex[clase]
	const T := 128
	var n := FastNoiseLite.new()
	n.seed = hash(clase)
	n.frequency = .045 if clase != "grieta" else .02
	n.fractal_octaves = 5
	if clase == "grieta":
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	for y in T:
		for x in T:
			var u := (x + .5) / T * 2.0 - 1.0
			var v := (y + .5) / T * 2.0 - 1.0
			var r := n.get_noise_2d(x, y) * .5 + .5
			var forma := 0.0
			match clase:
				"hollin":     # columna de humo que sube y se abre: más oscura abajo (la textura va de arriba, v=-1, a abajo)
					var ancho := lerpf(.25, .9, (1.0 - v) * .5)
					forma = clampf(1.0 - absf(u) / ancho, 0, 1) * clampf((v + 1.0) * .5 + .15, 0, 1) * clampf((1.0 - v) * 2.0, 0, 1)
				"humedad":    # desde la base del muro hacia arriba, con borde irregular
					forma = clampf((v + 1.0) * .5 * 1.6 - .35 + (r - .5) * .9, 0, 1) * clampf(1.0 - absf(u) * absf(u), 0, 1)
				"mancha":
					forma = clampf(1.0 - sqrt(u * u + v * v), 0, 1)
				"grieta":
					forma = clampf(1.0 - sqrt(u * u + v * v), 0, 1)
			var a := 0.0
			if clase == "grieta":
				a = (1.0 - smoothstep(.0, .06, r)) * forma * 1.4   # solo las líneas finas del ruido celular
			else:
				a = clampf(forma * (.55 + r * .8) - .15, 0, 1)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0, 1)))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[clase] = t
	return t

## base de una calcomanía de pared: proyecta hacia dentro del muro (cara con normal n), la textura de arriba abajo
static func _en_pared(n: Vector3) -> Basis:
	var z := Vector3.DOWN
	return Basis(n.cross(z), n, z)

static func _decal(padre: Node3D, clase: String, pos: Vector3, tam: Vector3, color: Color, base: Basis) -> Decal:
	var d := Decal.new()
	d.texture_albedo = _textura(clase)
	d.modulate = color
	d.size = tam
	d.transform = Transform3D(base, pos)
	d.upper_fade = .3
	d.lower_fade = .3
	d.distance_fade_enabled = true
	d.distance_fade_begin = 38.0
	d.distance_fade_length = 6.0
	d.cull_mask = 1   # escenario (los actores van en otras capas o, si no, apenas les toca)
	padre.add_child(d)
	return d

static func poner(m: MazmorraGridMap, L: Dictionary) -> void:
	var padre := Node3D.new()
	padre.name = "Suciedad"
	m.adornos.add_child(padre)
	var C := KitMazmorra.CELDA
	# hollín sobre las antorchas (cuelgan del muro norte de su casilla: cara al sur)
	for tr in L.get("torches", []):
		var c := Vector2i(int(tr.cx), int(tr.cy))
		if m.es_bajo(c.x, c.y - 1):
			continue
		var p := MazmorraGridMap.centro(c) + Vector3(0, 2.25, -C / 2)
		_decal(padre, "hollin", p, Vector3(1.1, .8, 1.9), Color(.02, .015, .01, .85), _en_pared(Vector3.BACK))
	# humedad en la base de los muros altos: una de cada pocas caras, fija por casilla
	var G: PackedByteArray = L.grid
	var GW := DungeonGen.GW
	var n := 0
	for y in range(1, DungeonGen.GH - 1):
		for x in range(1, GW - 1):
			if n >= MAX_HUMEDAD or G[y * GW + x] != DungeonGen.ROCK or m.es_bajo(x, y):
				continue
			for k in [0, 1]:
				var d: Vector2i = MazmorraGridMap.DIRS[k]
				var t := G[(y + d.y) * GW + x + d.x]
				if t == DungeonGen.ROCK or t == DungeonGen.ABISMO:
					continue
				var h := absi(hash(Vector3i(x, y, k * 31)))
				if h % 100 >= 30:
					continue
				var p := MazmorraGridMap.centro(Vector2i(x, y)) + Vector3(d.x, 0, d.y) * C / 2 + Vector3(0, .55, 0)
				var verdin := h % 3 == 0
				var col := Color(.08, .12, .05, .7) if verdin else Color(.03, .03, .035, .6)
				var ancho := C * (.8 + (h % 7) * .1)
				_decal(padre, "humedad", p, Vector3(ancho, .7, 1.2), col, _en_pared(Vector3(d.x, 0, d.y)))
				n += 1
	# manchas y grietas en el suelo de las salas (y alguna en los pasillos)
	n = 0
	var sala: PackedInt32Array = L.get("room_of", PackedInt32Array())
	for y in range(1, DungeonGen.GH - 1):
		for x in range(1, GW - 1):
			if n >= MAX_SUELO or G[y * GW + x] != DungeonGen.FLOOR:
				continue
			var h := absi(hash(Vector2i(x * 3, y * 5)))
			var en_sala := sala.size() > 0 and sala[y * GW + x] >= 0
			if h % 100 >= (9 if en_sala else 4):
				continue
			var grieta := h % 2 == 0
			var p := MazmorraGridMap.centro(Vector2i(x, y)) + Vector3((h % 5 - 2) * .2, 0, (h % 7 - 3) * .15)
			var tam := C * (.9 + (h % 5) * .25)
			_decal(padre, "grieta" if grieta else "mancha", p, Vector3(tam, .4, tam),
				Color(.02, .02, .02, .9) if grieta else Color(.05, .04, .03, .55), Basis(Vector3.UP, (h % 4) * PI / 2))
			n += 1

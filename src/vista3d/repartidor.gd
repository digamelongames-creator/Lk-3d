class_name Repartidor
## Reparte los adornos de una sala según para qué sirve (almacén, guardia, tesoro, cueva, pasillo…).
## No pinta nada: devuelve qué poner y dónde, y quien lo llama (PisoPrueba) lo coloca.
##
## Cada propósito es una lista de reglas:
##   p        paquete de Props3D ("polyhaven", "dungeon_kit"…)
##   piezas   una de estas, al azar
##   n        [mínimo, máximo] de copias
##   donde    "pared"   de pie junto a una pared, de espaldas a ella
##            "esquina" en una casilla con dos paredes
##            "centro"  lejos de las paredes, con una casilla libre alrededor
##            "colgado" colgado de la pared a la altura "alto" (antorchas, estandartes, cabezas)
##            "libre"   en cualquier punto del suelo, sin ocupar la casilla (plantas, piedras, monedas)
##   solido   ocupa la casilla: no se puede pasar (la simulación la ve como DECOR)
##   fuego    [tamaño, altura] lleva fuego y luz (braseros y antorchas)
##   tumbado  se pone tumbado en el suelo (armas)
##   escala   [mínima, máxima]
## Las casillas delante de las puertas no se usan nunca, para no tapar el paso.

const PROPOSITOS := {
	"almacen": [
		{"p": "polyhaven", "piezas": ["caja"], "n": [4, 6], "donde": "pared", "solido": true, "escala": [.9, 1.2]},
		{"p": "dungeon_kit", "piezas": ["barril", "barril_abierto", "barril_roto"], "n": [3, 5], "donde": "esquina", "solido": true},
		{"p": "dungeon_kit", "piezas": ["barril"], "n": [2, 3], "donde": "pared", "solido": true},
		{"p": "low_poly", "piezas": ["wooden_box", "wooden_box_006", "wooden_box_007"], "n": [2, 4], "donde": "pared", "solido": true},
		{"p": "dungeon_kit", "piezas": ["antorcha"], "n": [2, 2], "donde": "colgado", "alto": 1.6, "fuego": [.1, .3]},
	],
	"guardia": [
		{"p": "polyhaven", "piezas": ["silla"], "n": [2, 3], "donde": "pared", "solido": true},
		{"p": "dungeon_kit", "piezas": ["brasero"], "n": [2, 2], "donde": "centro", "solido": true, "fuego": [.24, 1.0]},
		{"p": "armas", "piezas": ["espada", "hacha", "garrote", "daga", "martillo", "guadana", "lanza", "escudo"], "n": [8, 8], "donde": "libre", "tumbado": true, "todas": true},
		{"p": "dungeon_kit", "piezas": ["estandarte_1", "estandarte_2", "estandarte_3"], "n": [2, 3], "donde": "colgado", "alto": 2.0},
		{"p": "dungeon_kit", "piezas": ["antorcha"], "n": [2, 2], "donde": "colgado", "alto": 1.6, "fuego": [.1, .3]},
	],
	"tesoro": [
		{"p": "polyhaven", "piezas": ["cabeza_leon"], "n": [3, 3], "donde": "colgado", "alto": 1.9},
		{"p": "low_poly", "piezas": ["chests_gold"], "n": [1, 2], "donde": "esquina", "solido": true},
		{"p": "low_poly", "piezas": ["coin_001"], "n": [8, 12], "donde": "libre", "tumbado": true},
		{"p": "dungeon_kit", "piezas": ["pilar"], "n": [2, 2], "donde": "esquina", "solido": true},
		{"p": "dungeon_kit", "piezas": ["brasero"], "n": [2, 2], "donde": "pared", "solido": true, "fuego": [.24, 1.0]},
	],
	"arena": [
		{"p": "dungeon_kit", "piezas": ["brasero"], "n": [4, 4], "donde": "esquina", "solido": true, "fuego": [.24, 1.0]},
		{"p": "dungeon_kit", "piezas": ["estandarte_1", "estandarte_2", "estandarte_3"], "n": [2, 3], "donde": "colgado", "alto": 2.0},
	],
	"mimico": [   # sala del mímico: braseros para que se vean bien los dos baúles
		{"p": "dungeon_kit", "piezas": ["brasero"], "n": [4, 4], "donde": "esquina", "solido": true, "fuego": [.24, 1.0]},
	],
	"animaciones": [   # sala de las animaciones (panel F5): braseros en las esquinas y el centro despejado
		{"p": "dungeon_kit", "piezas": ["brasero"], "n": [4, 4], "donde": "esquina", "solido": true, "fuego": [.24, 1.0]},
	],
	"efectos": [   # oscura y despejada, para que se vean bien los hechizos
		{"p": "dungeon_kit", "piezas": ["estandarte_1", "estandarte_2", "estandarte_3"], "n": [3, 3], "donde": "colgado", "alto": 2.0},
	],
	"cueva": [
		{"p": "polyhaven", "piezas": ["roca_grande"], "n": [1, 1], "donde": "esquina", "solido": true, "escala": [.45, .55]},
		{"p": "polyhaven", "piezas": ["roca_musgo_7", "roca_musgo_8", "roca_musgo_9", "roca_musgo_10", "roca_musgo_11", "roca_musgo_12", "roca_musgo_13"], "n": [4, 6], "donde": "pared", "solido": true, "escala": [.8, 1.1]},
		{"p": "polyhaven", "piezas": ["roca_musgo_10", "roca_musgo_11"], "n": [1, 2], "donde": "centro", "solido": true},
		{"p": "dungeon_kit", "piezas": ["roca", "piedra"], "n": [4, 6], "donde": "libre"},
		{"p": "polyhaven", "piezas": ["piedras_a", "piedras_b", "piedras_c", "piedras_d", "piedras_e"], "n": [10, 14], "donde": "libre"},
		{"p": "polyhaven", "piezas": ["diente_leon_a", "diente_leon_b", "diente_leon_c", "diente_leon_d", "diente_leon_e"], "n": [12, 18], "donde": "libre", "escala": [1.5, 2.2]},
	],
	"pasillo": [
		{"p": "dungeon_kit", "piezas": ["antorcha"], "n": [6, 8], "donde": "colgado", "alto": 1.6, "fuego": [.1, .3]},
		{"p": "dungeon_kit", "piezas": ["estandarte_1", "estandarte_2", "estandarte_3"], "n": [3, 4], "donde": "colgado", "alto": 2.0},
	],
	# ---- muestras de cada paquete (salas de arriba del piso de prueba 1) ----
	"muestra_polyhaven": [
		{"p": "polyhaven", "piezas": ["cabeza_leon"], "n": [2, 2], "donde": "colgado", "alto": 1.9},
		{"p": "polyhaven", "piezas": ["silla"], "n": [2, 2], "donde": "pared", "solido": true},
		{"p": "polyhaven", "piezas": ["caja"], "n": [3, 3], "donde": "pared", "solido": true},
		{"p": "polyhaven", "piezas": ["roca_musgo_8", "roca_musgo_9", "roca_musgo_12"], "n": [2, 2], "donde": "esquina", "solido": true, "escala": [.7, .8]},
		{"p": "polyhaven", "piezas": ["piedras_a", "piedras_b", "piedras_c", "piedras_d", "piedras_e"], "n": [6, 8], "donde": "libre"},
		{"p": "polyhaven", "piezas": ["diente_leon_a", "diente_leon_b", "diente_leon_c"], "n": [6, 8], "donde": "libre", "escala": [1.5, 2.2]},
		{"p": "dungeon_kit", "piezas": ["antorcha"], "n": [2, 2], "donde": "colgado", "alto": 1.6, "fuego": [.1, .3]},
	],
	"muestra_dungeon_kit": [
		{"p": "dungeon_kit", "piezas": ["barril", "barril_abierto", "barril_roto"], "n": [3, 4], "donde": "esquina", "solido": true},
		{"p": "dungeon_kit", "piezas": ["pilar"], "n": [2, 2], "donde": "centro", "solido": true},
		{"p": "dungeon_kit", "piezas": ["brasero"], "n": [2, 2], "donde": "pared", "solido": true, "fuego": [.24, 1.0]},
		{"p": "dungeon_kit", "piezas": ["estandarte_1", "estandarte_2", "estandarte_3"], "n": [3, 3], "donde": "colgado", "alto": 1.5},
		{"p": "dungeon_kit", "piezas": ["antorcha"], "n": [3, 3], "donde": "colgado", "alto": 1.4, "fuego": [.1, .3]},
		{"p": "dungeon_kit", "piezas": ["roca", "piedra"], "n": [4, 6], "donde": "libre"},
	],
	"muestra_low_poly": [
		{"p": "low_poly", "piezas": ["barrel", "barrel_024"], "n": [2, 3], "donde": "esquina", "solido": true},
		{"p": "low_poly", "piezas": ["wooden_box", "wooden_box_006", "wooden_box_007"], "n": [3, 4], "donde": "pared", "solido": true},
		{"p": "low_poly", "piezas": ["chest_bottom"], "n": [1, 1], "donde": "pared", "solido": true},
		{"p": "low_poly", "piezas": ["skull", "bone", "candle", "candle_002", "candle_003", "debris", "bricks"], "n": [8, 10], "donde": "libre"},
		{"p": "low_poly", "piezas": ["torch_001"], "n": [3, 3], "donde": "colgado", "alto": 1.3, "fuego": [.1, .7]},
	],
	"muestra_gotico": [
		{"p": "gotico", "piezas": ["statue1", "statue2"], "n": [2, 2], "donde": "pared", "solido": true},
		{"p": "gotico", "piezas": ["circle_007"], "n": [2, 2], "donde": "centro", "solido": true},
		{"p": "gotico", "piezas": ["cube_009"], "n": [1, 1], "donde": "centro", "solido": true},
		{"p": "dungeon_kit", "piezas": ["brasero"], "n": [2, 2], "donde": "pared", "solido": true, "fuego": [.24, 1.0]},
	],
	"muestra_ruinas": [
		{"p": "ruinas", "piezas": ["pilar7", "pillar2", "pillar8"], "n": [3, 4], "donde": "centro", "solido": true},
		{"p": "ruinas", "piezas": ["walls11", "wall9"], "n": [2, 3], "donde": "pared", "solido": true},
		{"p": "ruinas", "piezas": ["bricks9", "bricks11"], "n": [2, 3], "donde": "esquina", "solido": true, "escala": [.6, .7]},
		{"p": "dungeon_kit", "piezas": ["roca", "piedra"], "n": [4, 6], "donde": "libre"},
		{"p": "dungeon_kit", "piezas": ["antorcha"], "n": [2, 2], "donde": "colgado", "alto": 1.6, "fuego": [.1, .3]},
	],
}

const D4 := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
## las paredes que ve la cámara isométrica (giro de 45°): norte y oeste. Lo que va pegado a la pared se pone
## antes en estas; las del sur y el este las tapa el propio muro.
const PAREDES_VISIBLES := [Vector2i(0, -1), Vector2i(-1, 0)]

## Lo que hay que poner en la sala. celdas: las casillas de suelo de la sala; pisable(c) dice si una casilla
## es suelo (de esta sala o de fuera); puertas: casillas de la sala que dan a otra zona (no se tapan).
## Devuelve una lista de {p, pieza, celda, pos (m), giro, solido, pared (Vector2i hacia el muro o cero),
##   alto, fuego, tumbado, escala}.
static func repartir(proposito: String, celdas: Array, pisable: Callable, puertas: Array, semilla: int) -> Array:
	var reglas: Array = PROPOSITOS.get(proposito, [])
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var en_sala := {}
	for c in celdas:
		en_sala[c] = true
	# casillas que no se tocan: las puertas y sus vecinas
	var paso := {}
	for c in puertas:
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				paso[c + Vector2i(dx, dy)] = true
	var ocupada := {}
	var pared_usada := {}   # casilla|lado → ya hay algo colgado
	var out := []
	for r in reglas:
		var n := rng.randi_range(int(r.n[0]), int(r.n[1]))
		var piezas: Array = r.piezas
		for i in n:
			var pieza: String = piezas[i % piezas.size()] if r.get("todas", false) else piezas[rng.randi() % piezas.size()]
			var sitio := _sitio(String(r.donde), celdas, en_sala, pisable, paso, ocupada, pared_usada, rng, bool(r.get("solido", false)))
			if sitio.is_empty():
				break
			var esc: Array = r.get("escala", [1.0, 1.0])
			sitio.merge({"p": r.p, "pieza": pieza, "solido": r.get("solido", false), "alto": float(r.get("alto", 0.0)),
				"fuego": r.get("fuego", []), "tumbado": r.get("tumbado", false), "escala": rng.randf_range(float(esc[0]), float(esc[1]))})
			out.append(sitio)
	return out

## paredes de una casilla: direcciones (de las 4) en las que no hay suelo
static func _paredes(c: Vector2i, pisable: Callable) -> Array:
	var out := []
	for d in D4:
		if not pisable.call(c + d):
			out.append(d)
	return out

static func _sitio(donde: String, celdas: Array, en_sala: Dictionary, pisable: Callable, paso: Dictionary,
		ocupada: Dictionary, pared_usada: Dictionary, rng: RandomNumberGenerator, solido: bool) -> Dictionary:
	var cand := []
	for c in celdas:
		if paso.has(c):
			continue
		var pw := _paredes(c, pisable)
		match donde:
			"pared":
				if pw.size() == 1 and not ocupada.has(c):
					cand.append([c, pw[0]])
			"esquina":
				if pw.size() == 2 and not ocupada.has(c):
					cand.append([c, pw[1] if PAREDES_VISIBLES.has(pw[1]) else pw[0]])
			"centro":
				if pw.is_empty() and not ocupada.has(c):
					# las 8 vecinas son de la sala y no tienen nada sólido: se puede rodear
					var libre := true
					for dy in [-1, 0, 1]:
						for dx in [-1, 0, 1]:
							var v: Vector2i = c + Vector2i(dx, dy)
							if not en_sala.has(v) or ocupada.get(v, false):
								libre = false
					if libre:
						cand.append([c, Vector2i.ZERO])
			"colgado":
				for d in pw:
					if not pared_usada.has(str(c) + str(d)):
						cand.append([c, d])
			"libre":
				if not ocupada.has(c) or not ocupada[c]:
					cand.append([c, Vector2i.ZERO])
	if cand.is_empty():
		return {}
	if donde in ["pared", "esquina", "colgado"]:
		var vistas := cand.filter(func(x): return PAREDES_VISIBLES.has(x[1]))
		if not vistas.is_empty():
			cand = vistas
	var e: Array = cand[rng.randi() % cand.size()]
	var cel: Vector2i = e[0]
	var d: Vector2i = e[1]
	var pos := MazmorraGridMap.centro(cel)
	var giro := rng.randf() * TAU
	match donde:
		"pared", "esquina":
			pos += Vector3(d.x, 0, d.y) * (KitMazmorra.CELDA / 2 - .55)
			giro = atan2(-float(d.x), -float(d.y))   # de espaldas a la pared (el frente es +Z)
			ocupada[cel] = solido
		"centro":
			ocupada[cel] = solido
		"colgado":
			pos += Vector3(d.x, 0, d.y) * (KitMazmorra.CELDA / 2 - .12)
			pos += Vector3(-d.y, 0, d.x) * rng.randf_range(-.4, .4)
			giro = atan2(-float(d.x), -float(d.y))
			pared_usada[str(cel) + str(d)] = true
		"libre":
			pos += Vector3(rng.randf_range(-.8, .8), 0, rng.randf_range(-.8, .8))
			if not ocupada.has(cel):
				ocupada[cel] = false
	return {"celda": cel, "pos": pos, "giro": giro, "pared": d}

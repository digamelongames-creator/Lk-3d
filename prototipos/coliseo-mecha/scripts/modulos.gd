extends RefCounted
## Módulos de la mochila (cuadrícula 4×4 en la espalda del mecha) y la escalera de gladiadores.
## Una construcción es un Array de piezas: {"id", "pos": Vector2i (columna, fila), "girado": bool, "vida"}.
## Columnas de izquierda a derecha y filas de arriba abajo, vistas desde detrás del mecha.
## Las baterías (+40 % de capacidad) y los recargadores (+50 % de recarga) refuerzan a los
## generadores (escudo o propulsión) que tocan por un lado.

const LADO := 4
const PESO_MAX := 18
const REACTOR := 12
const VIDA_MODULO := 80.0

const CATALOGO := {
	"prop_peq": {"nombre": "Generador de propulsión pequeño", "tam": Vector2i(1, 1), "peso": 2, "consumo": 2, "precio": 60,
		"tipo": "prop", "cap": 45.0, "regen": 16.0, "color": Color(0.95, 0.55, 0.15),
		"texto": "Energía para el impulso y el vuelo. Sin generador de propulsión no hay ni lo uno ni lo otro."},
	"prop": {"nombre": "Generador de propulsión", "tam": Vector2i(1, 2), "peso": 3, "consumo": 3, "precio": 150,
		"tipo": "prop", "cap": 75.0, "regen": 26.0, "color": Color(1.0, 0.45, 0.1),
		"texto": "Más energía de propulsión y recarga más rápida."},
	"escudo_peq": {"nombre": "Generador de escudo pequeño", "tam": Vector2i(1, 2), "peso": 2, "consumo": 3, "precio": 100,
		"tipo": "escudo", "cap": 140.0, "regen": 22.0, "color": Color(0.3, 0.7, 1.0),
		"texto": "Burbuja que para las balas. Se recarga si no te dan. El puñetazo la rompe."},
	"escudo": {"nombre": "Generador de escudo", "tam": Vector2i(2, 2), "peso": 4, "consumo": 5, "precio": 240,
		"tipo": "escudo", "cap": 300.0, "regen": 38.0, "color": Color(0.2, 0.5, 1.0),
		"texto": "Escudo fuerte. Ocupa mucho y gasta mucho reactor."},
	"bateria": {"nombre": "Batería", "tam": Vector2i(1, 1), "peso": 1, "consumo": 0, "precio": 60,
		"tipo": "bateria", "color": Color(0.3, 0.9, 0.4),
		"texto": "+40 % de energía a cada generador que toque (escudo o propulsión)."},
	"recargador": {"nombre": "Recargador", "tam": Vector2i(1, 1), "peso": 1, "consumo": 1, "precio": 70,
		"tipo": "recarga", "color": Color(0.9, 0.9, 0.3),
		"texto": "+50 % de recarga a cada generador que toque (escudo o propulsión)."},
	"disipador": {"nombre": "Disipador", "tam": Vector2i(2, 1), "peso": 2, "consumo": 1, "precio": 90,
		"tipo": "disipador", "color": Color(0.75, 0.8, 0.85),
		"texto": "El cañón se calienta un 15 % menos y se enfría un 35 % más rápido."},
	"propulsor": {"nombre": "Propulsor extra", "tam": Vector2i(1, 2), "peso": 2, "consumo": 2, "precio": 110,
		"tipo": "propulsor", "color": Color(0.9, 0.3, 0.2),
		"texto": "+20 % de empuje al volar y +12 % de velocidad de impulso."},
	"blindaje": {"nombre": "Placa de blindaje", "tam": Vector2i(2, 1), "peso": 3, "consumo": 0, "precio": 80,
		"tipo": "blindaje", "color": Color(0.45, 0.45, 0.5),
		"texto": "+150 de vida. Por la espalda recibe casi todos los tiros y protege a los demás."},
}

## La escalera de gladiadores: construcción, puntería (más alto, falla más), reflejos y premio.
const RIVALES := [
	{"nombre": "GLADIADOR DE CHATARRA", "color": Color(0.5, 0.35, 0.25), "luz": Color(1.0, 0.6, 0.2),
		"punteria": 1.6, "reflejos": 0.12, "premio": 120, "texto": "Un montón de hierro oxidado. Para calentar.",
		"construccion": [["prop_peq", 0, 3, false], ["escudo_peq", 3, 2, false]]},
	{"nombre": "RETIARIUS-7", "color": Color(0.25, 0.45, 0.35), "luz": Color(0.4, 1.0, 0.6),
		"punteria": 1.3, "reflejos": 0.25, "premio": 160, "texto": "Rápido y saltarín. Le gusta rodearte.",
		"construccion": [["prop", 1, 2, false], ["bateria", 0, 3, false], ["escudo_peq", 2, 2, false], ["recargador", 3, 3, false]]},
	{"nombre": "MURMILLO DE HIERRO", "color": Color(0.4, 0.4, 0.45), "luz": Color(1.0, 0.85, 0.3),
		"punteria": 1.1, "reflejos": 0.15, "premio": 200, "texto": "Lento, blindado y con un escudo enorme. Rómpeselo a puñetazos.",
		"construccion": [["escudo", 1, 1, false], ["bateria", 0, 1, false], ["bateria", 3, 2, false], ["prop_peq", 1, 3, false],
			["blindaje", 0, 0, false], ["blindaje", 2, 0, false]]},
	{"nombre": "SECUTOR VELOZ", "color": Color(0.6, 0.15, 0.4), "luz": Color(1.0, 0.3, 0.8),
		"punteria": 1.0, "reflejos": 0.5, "premio": 250, "texto": "Esquiva casi todo. Hay que pillarlo sin energía.",
		"construccion": [["prop", 1, 1, false], ["propulsor", 0, 0, false], ["propulsor", 3, 0, false], ["bateria", 0, 2, false],
			["recargador", 2, 1, false], ["escudo_peq", 2, 2, false]]},
	{"nombre": "CAMPEÓN DEL CÉSAR", "color": Color(0.6, 0.5, 0.15), "luz": Color(1.0, 0.9, 0.4),
		"punteria": 0.8, "reflejos": 0.45, "premio": 400, "texto": "El favorito del público. Lo tiene todo.",
		"construccion": [["escudo", 1, 1, false], ["bateria", 0, 1, false], ["bateria", 3, 2, false], ["prop", 0, 2, false],
			["recargador", 1, 3, false], ["disipador", 2, 3, false], ["blindaje", 1, 0, false]]},
]

const DE_SERIE := [["prop_peq", 1, 3, false], ["escudo_peq", 2, 2, false]]


static func pieza(id: String, pos: Vector2i, girado := false) -> Dictionary:
	return {"id": id, "pos": pos, "girado": girado, "vida": vida_de(id)}


static func vida_de(id: String) -> float:
	return VIDA_MODULO * (2.5 if CATALOGO[id].tipo == "blindaje" else 1.0)


static func desde_lista(lista: Array) -> Array:
	var c := []
	for l in lista:
		c.append(pieza(l[0], Vector2i(l[1], l[2]), l[3]))
	return c


static func tam(p: Dictionary) -> Vector2i:
	var t: Vector2i = CATALOGO[p.id].tam
	return Vector2i(t.y, t.x) if p.girado else t


static func celdas(p: Dictionary) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	var t := tam(p)
	for x in t.x:
		for y in t.y:
			r.append(p.pos + Vector2i(x, y))
	return r


## ¿Cabe la pieza en la cuadrícula sin pisar a las demás? (ignora la que esté en `ignorar`)
static func cabe(cons: Array, p: Dictionary, ignorar: Dictionary = {}) -> bool:
	var ocupadas := {}
	for o in cons:
		if is_same(o, ignorar) or is_same(o, p):
			continue
		for c in celdas(o):
			ocupadas[c] = true
	for c in celdas(p):
		if c.x < 0 or c.y < 0 or c.x >= LADO or c.y >= LADO or ocupadas.has(c):
			return false
	return true


static func pieza_en(cons: Array, celda: Vector2i):
	for p in cons:
		if celda in celdas(p):
			return p
	return null


static func vivo(p: Dictionary) -> bool:
	return p.vida > 0.0


## Piezas vivas que tocan a `p` por un lado.
static func vecinos(cons: Array, p: Dictionary) -> Array:
	var mias := celdas(p)
	var r := []
	for o in cons:
		if is_same(o, p) or not vivo(o):
			continue
		var toca := false
		for c in celdas(o):
			for m in mias:
				if absi(c.x - m.x) + absi(c.y - m.y) == 1:
					toca = true
		if toca:
			r.append(o)
	return r


## Lo que da la construcción. Solo cuentan las piezas vivas.
static func calcular(cons: Array) -> Dictionary:
	var s := {"prop_max": 0.0, "prop_regen": 0.0, "escudo_max": 0.0, "escudo_regen": 0.0,
		"enfria": 1.0, "calor": 1.0, "empuje": 1.0, "impulso": 1.0, "vida_extra": 0.0,
		"peso": 0, "consumo": 0}
	for p in cons:
		if not vivo(p):
			continue
		var d: Dictionary = CATALOGO[p.id]
		s.peso += d.peso
		s.consumo += d.consumo
		match d.tipo:
			"prop", "escudo":
				var nb := 0
				var nr := 0
				for v in vecinos(cons, p):
					var t: String = CATALOGO[v.id].tipo
					if t == "bateria":
						nb += 1
					elif t == "recarga":
						nr += 1
				var cap: float = d.cap * (1.0 + 0.4 * nb)
				var regen: float = d.regen * (1.0 + 0.5 * nr)
				if d.tipo == "prop":
					s.prop_max += cap
					s.prop_regen += regen
				else:
					s.escudo_max += cap
					s.escudo_regen += regen
			"disipador":
				s.enfria *= 1.35
				s.calor *= 0.85
			"propulsor":
				s.empuje *= 1.2
				s.impulso *= 1.12
			"blindaje":
				s.vida_extra += 150.0
	return s


static func problemas(cons: Array) -> Array[String]:
	var s := calcular(cons)
	var r: Array[String] = []
	if s.peso > PESO_MAX:
		r.append("Demasiado peso (%d / %d)" % [s.peso, PESO_MAX])
	if s.consumo > REACTOR:
		r.append("El reactor no da para tanto (%d / %d)" % [s.consumo, REACTOR])
	return r


static func copiar(cons: Array) -> Array:
	var c := []
	for p in cons:
		c.append(p.duplicate())
	return c

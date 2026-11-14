extends RefCounted
## Piezas cambiables del mecha: piernas, torso, cabeza y un arma en cada brazo (cualquiera en cualquiera).
## Un montaje es {"piernas", "torso", "cabeza", "brazo_i", "brazo_d"} con los id de abajo.
## Todo está desbloqueado por ahora (Diego, 14 nov: estamos probando que sea divertido).

const Modulos = preload("res://scripts/modulos.gd")

const VIDA_BASE := 1000.0
const GIRO_BASE := 2.3

const PIERNAS := {
	"bipedas": {"nombre": "Piernas bípedas", "texto": "Equilibradas en todo.",
		"carga": 30, "vel": 11.5, "vida": 0.0, "empuje": 1.0, "impulso": 1.0, "aturdir": 1.0, "cadera": 3.2},
	"tanque": {"nombre": "Piernas de tanque", "texto": "Aguantan mucho peso y casi no se las aturde, pero son lentas.",
		"carga": 42, "vel": 8.5, "vida": 250.0, "empuje": 0.85, "impulso": 0.85, "aturdir": 0.5, "cadera": 2.9},
	"zancudas": {"nombre": "Piernas zancudas", "texto": "Rápidas y saltarinas. Poca carga y menos vida.",
		"carga": 24, "vel": 14.0, "vida": -150.0, "empuje": 1.25, "impulso": 1.12, "aturdir": 1.2, "cadera": 3.6},
}

const TORSOS := {
	"estandar": {"nombre": "Torso estándar", "texto": "Reactor normal.", "peso": 6, "reactor": 12, "vida": 0.0, "ancho": 3.0},
	"blindado": {"nombre": "Torso blindado", "texto": "Mucha más vida, menos reactor para la mochila.", "peso": 9, "reactor": 10, "vida": 350.0, "ancho": 3.6},
	"reactor": {"nombre": "Torso reactor", "texto": "Reactor grande para llenar la mochila. Más frágil.", "peso": 7, "reactor": 16, "vida": -150.0, "ancho": 2.7},
}

const CABEZAS := {
	"estandar": {"nombre": "Cabeza estándar", "texto": "Sin más.", "peso": 1, "consumo": 0, "vida": 0.0, "ayuda": 5.0, "dispersion": 1.0, "giro": 1.0},
	"mira": {"nombre": "Cabeza de mira", "texto": "Más ayuda al apuntar y las balas se abren la mitad.", "peso": 1, "consumo": 1, "vida": -50.0, "ayuda": 9.0, "dispersion": 0.5, "giro": 1.0},
	"blindada": {"nombre": "Cabeza blindada", "texto": "Más vida, pero el mecha gira más despacio.", "peso": 3, "consumo": 0, "vida": 150.0, "ayuda": 5.0, "dispersion": 1.0, "giro": 0.85},
}

## tipo "disparo": cadencia (s), balas por disparo, daño por bala, velocidad, calor por disparo, dispersión, vida de la bala (s).
## tipo "golpe": carga (s antes de golpear), recarga, alcance, estocada, empujón, aturdido.
const ARMAS := {
	"rotativo": {"nombre": "Cañón rotativo", "texto": "El de siempre: ráfagas medias.", "tipo": "disparo", "peso": 3, "consumo": 1,
		"cadencia": 0.14, "balas": 1, "dano": 26.0, "vel": 80.0, "calor": 8.5, "dispersion": 0.012, "vida": 2.0, "tam": 1.0, "empujon": 1.5},
	"vulcan": {"nombre": "Ametralladora Vulcan", "texto": "Seis cañones: muchísimos disparos de poco daño. Tarda en girar.", "tipo": "disparo", "peso": 4, "consumo": 2,
		"cadencia": 0.045, "balas": 1, "dano": 8.0, "vel": 90.0, "calor": 2.4, "dispersion": 0.03, "vida": 1.6, "tam": 0.6, "empujon": 0.4, "arranque": 0.45},
	"escopeta": {"nombre": "Escopeta", "texto": "Ocho perdigones. Demoledora de cerca, inútil de lejos.", "tipo": "disparo", "peso": 3, "consumo": 1,
		"cadencia": 0.8, "balas": 8, "dano": 15.0, "vel": 70.0, "calor": 22.0, "dispersion": 0.075, "vida": 0.42, "tam": 0.7, "empujon": 1.2},
	"pesado": {"nombre": "Cañón pesado", "texto": "Un pepinazo lento que hace mucho daño y calienta muchísimo.", "tipo": "disparo", "peso": 5, "consumo": 2,
		"cadencia": 1.1, "balas": 1, "dano": 140.0, "vel": 110.0, "calor": 34.0, "dispersion": 0.003, "vida": 2.0, "tam": 2.2, "empujon": 7.0},
	"puno": {"nombre": "Puño", "texto": "Golpe con estocada que aturde y rompe escudos.", "tipo": "golpe", "peso": 2, "consumo": 0,
		"dano": 150.0, "carga": 0.28, "recarga": 1.1, "alcance": 6.2, "estocada": 20.0, "empujon": 18.0, "aturdido": 0.5},
	"martillo": {"nombre": "Martillo", "texto": "Lento de narices, pero lanza al rival por los aires.", "tipo": "golpe", "peso": 4, "consumo": 0,
		"dano": 270.0, "carga": 0.55, "recarga": 1.9, "alcance": 6.8, "estocada": 16.0, "empujon": 34.0, "aturdido": 0.9},
	"cuchilla": {"nombre": "Cuchilla", "texto": "Rápida: poco daño por tajo, pero no para.", "tipo": "golpe", "peso": 2, "consumo": 0,
		"dano": 80.0, "carga": 0.12, "recarga": 0.5, "alcance": 6.0, "estocada": 24.0, "empujon": 7.0, "aturdido": 0.25},
}

const HUECOS := ["piernas", "torso", "cabeza", "brazo_i", "brazo_d", "mochila"]
const NOMBRE_HUECO := {"piernas": "PIERNAS", "torso": "TORSO", "cabeza": "CABEZA",
	"brazo_i": "BRAZO IZQUIERDO", "brazo_d": "BRAZO DERECHO", "mochila": "MOCHILA"}

const DE_SERIE := {"piernas": "bipedas", "torso": "estandar", "cabeza": "estandar", "brazo_i": "puno", "brazo_d": "rotativo"}


static func catalogo(hueco: String) -> Dictionary:
	match hueco:
		"piernas":
			return PIERNAS
		"torso":
			return TORSOS
		"cabeza":
			return CABEZAS
		"brazo_i", "brazo_d":
			return ARMAS
	return {}


static func ficha(montaje: Dictionary, hueco: String) -> Dictionary:
	return catalogo(hueco)[montaje[hueco]]


## Todo lo que da el mecha entero: piezas + mochila (solo los módulos vivos).
static func calcular(montaje: Dictionary, cons: Array) -> Dictionary:
	var s := Modulos.calcular(cons)
	var pi: Dictionary = PIERNAS[montaje.piernas]
	var to: Dictionary = TORSOS[montaje.torso]
	var ca: Dictionary = CABEZAS[montaje.cabeza]
	var ai: Dictionary = ARMAS[montaje.brazo_i]
	var ad: Dictionary = ARMAS[montaje.brazo_d]
	s.peso += to.peso + ca.peso + ai.peso + ad.peso
	s.consumo += ca.consumo + ai.consumo + ad.consumo
	s.carga = pi.carga
	s.reactor = to.reactor
	s.vida = VIDA_BASE + s.vida_extra + pi.vida + to.vida + ca.vida
	var f: float = clampf(float(s.peso) / float(pi.carga), 0.0, 1.5)
	s.vel = pi.vel * (1.0 - 0.35 * f)
	s.giro = GIRO_BASE * (1.0 - 0.4 * f) * ca.giro
	s.empuje *= pi.empuje
	s.impulso *= pi.impulso
	s.aturdir = pi.aturdir
	s.ayuda = ca.ayuda
	s.dispersion = ca.dispersion
	s.cadera = pi.cadera
	return s


static func problemas(montaje: Dictionary, cons: Array) -> Array[String]:
	var s := calcular(montaje, cons)
	var r: Array[String] = []
	if s.peso > s.carga:
		r.append("Demasiado peso para estas piernas (%d / %d)" % [s.peso, s.carga])
	if s.consumo > s.reactor:
		r.append("El reactor del torso no da para tanto (%d / %d)" % [s.consumo, s.reactor])
	return r

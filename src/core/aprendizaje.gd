class_name Aprendizaje
extends RefCounted
## Enemigos que aprenden (decidido por Diego, 9 nov 2026).
##
## Cada enemigo tiene un puesto fijo por piso («2-37»: piso 2, enemigo 37 en el orden de reparto).
## La mazmorra cambia, pero el 37 de hoy es el 37 de mañana y recuerda lo que aprendió.
## No aprende movimientos nuevos: elige entre las TACTICAS que le damos la que mejor le funciona.
##
## Dos memorias:
##   · tipos:   compartida por tipo y papel («esqueleto/esbirro»), para que aprendan rápido.
##   · puestos: la de cada puesto, que le da su carácter (el 37 prefiere la espalda, el 12 el contraataque).
## Cada combate (de que despierta a que muere, te mata o se acaba el piso) da una nota:
## el daño que te hizo por segundo (en partes de tu vida) y un premio si te mató.
##
## El archivo solo guarda sumas y cuentas, así que se puede juntar el de muchos jugadores
## sumando (fusionar): es el formato que usará el servidor más adelante.
## Títulos: «Asesino» si te ha matado ASESINO_N veces; «Experto» tras EXPERTO_N combates.
## Por ahora mantienen su puesto (no ascienden).

const VERSION := 1
const TACTICAS := ["directo", "rodear", "espalda", "contra", "rematar", "escolta"]
const NOMBRE := {"directo": "Directo", "rodear": "Rodear", "espalda": "Por la espalda",
	"contra": "Contraataque", "rematar": "Rematar", "escolta": "Escolta"}
const EXPLORA := .15          # parte de los combates en que prueba una táctica al azar
const PREVIO_N := 2.0         # combates «imaginarios» con nota PREVIO_V para que no se fíe de uno solo
const PREVIO_V := .3
const PESO_PUESTO := 8.0      # con este número de combates propios, la mitad de la decisión es suya
const PREMIO_MUERTE := 2.0
const ESCALA := 20.0          # nota = daño por segundo / vida del héroe × ESCALA (≈ 0–1,5)
const ASESINO_N := 3
const EXPERTO_N := 12
const ESPERA_MAX := 4.0       # segundos sin golpear: deja la táctica y va a por ti
const REMATAR_VIDA := .45     # «rematar» entra cuando te queda menos de esta parte de la vida

var ruta := ""                # "" = solo en memoria (pruebas)
var tipos := {}               # clave → {tactica: [n, suma]}
var puestos := {}             # puesto → {"t": {tactica: [n, suma]}, "combates": n, "muertes": n}
var rng := RandomNumberGenerator.new()
var sucio := false
var _fin_ataque_t := -9.0     # cuándo acabó el último tajo del héroe (ventana del contraataque)
var _rodo_t := -9.0
var _atacaba := false

func _init(ruta_: String = "") -> void:
	ruta = ruta_
	rng.randomize()
	cargar()

# ======================================================================
#  archivo
# ======================================================================
func cargar() -> void:
	if ruta == "" or not FileAccess.file_exists(ruta):
		return
	var txt := FileAccess.get_file_as_string(ruta)
	var d = JSON.parse_string(txt)
	if d is Dictionary:
		tipos = d.get("tipos", {})
		puestos = d.get("puestos", {})

func guardar() -> void:
	if ruta == "" or not sucio:
		return
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(datos()))
	sucio = false

func datos() -> Dictionary:
	return {"version": VERSION, "tipos": tipos, "puestos": puestos}

## suma lo aprendido en otra partida (u otro jugador) a esta: así juntará el servidor lo de todos
func fusionar(d: Dictionary) -> void:
	for k in d.get("tipos", {}):
		var dst: Dictionary = tipos.get_or_add(k, {})
		_sumar(dst, d.tipos[k])
	for k in d.get("puestos", {}):
		var o: Dictionary = d.puestos[k]
		var dst: Dictionary = _puesto(k)
		_sumar(dst.t, o.get("t", {}))
		dst.combates = int(dst.combates) + int(o.get("combates", 0))
		dst.muertes = int(dst.muertes) + int(o.get("muertes", 0))
	sucio = true

static func _sumar(dst: Dictionary, src: Dictionary) -> void:
	for t in src:
		var a: Array = dst.get_or_add(t, [0.0, 0.0])
		a[0] = float(a[0]) + float(src[t][0])
		a[1] = float(a[1]) + float(src[t][1])

func _puesto(k: String) -> Dictionary:
	if not puestos.has(k):
		puestos[k] = {"t": {}, "combates": 0, "muertes": 0}
	return puestos[k]

# ======================================================================
#  elegir y apuntar
# ======================================================================
## nota esperada de cada táctica para este puesto: mezcla de lo del tipo y lo suyo
func valores(clave: String, puesto: String) -> Dictionary:
	var T: Dictionary = tipos.get(clave, {})
	var P: Dictionary = puestos.get(puesto, {}).get("t", {}) if puesto != "" else {}
	var n_propio := 0.0
	for t in P:
		n_propio += float(P[t][0])
	var w := n_propio / (n_propio + PESO_PUESTO)
	var out := {}
	for t in TACTICAS:
		var a: Array = T.get(t, [0.0, 0.0])
		var q_tipo := (float(a[1]) + PREVIO_V * PREVIO_N) / (float(a[0]) + PREVIO_N)
		var b: Array = P.get(t, [0.0, 0.0])
		var q_puesto := (float(b[1]) + q_tipo * PREVIO_N) / (float(b[0]) + PREVIO_N)
		out[t] = q_tipo * (1 - w) + q_puesto * w
	return out

func elegir(clave: String, puesto: String, con_lider: bool) -> String:
	var opciones: Array = TACTICAS if con_lider else TACTICAS.filter(func(t): return t != "escolta")
	if rng.randf() < EXPLORA:
		return opciones[rng.randi() % opciones.size()]
	var v := valores(clave, puesto)
	var mejor := ""
	var mv := -INF
	for t in opciones:
		var q: float = v[t] + rng.randf() * .01   # desempate al azar
		if q > mv:
			mv = q
			mejor = t
	return mejor

## apunta un combate: nota de la táctica en su tipo y en su puesto
func apuntar(clave: String, puesto: String, tactica: String, nota: float, mato: bool) -> void:
	var a: Array = tipos.get_or_add(clave, {}).get_or_add(tactica, [0.0, 0.0])
	a[0] = float(a[0]) + 1
	a[1] = float(a[1]) + nota
	if puesto != "":
		var P := _puesto(puesto)
		var b: Array = P.t.get_or_add(tactica, [0.0, 0.0])
		b[0] = float(b[0]) + 1
		b[1] = float(b[1]) + nota
		P.combates = int(P.combates) + 1
		if mato:
			P.muertes = int(P.muertes) + 1
	sucio = true

func titulo(puesto: String) -> String:
	if puesto == "" or not puestos.has(puesto):
		return ""
	var P: Dictionary = puestos[puesto]
	if int(P.muertes) >= ASESINO_N:
		return "Asesino"
	if int(P.combates) >= EXPERTO_N:
		return "Experto"
	return ""

## combates de este puesto (para el panel de pruebas)
func combates(puesto: String) -> int:
	return int(puestos.get(puesto, {}).get("combates", 0))

# ======================================================================
#  en la simulación
# ======================================================================
## papel de cada enemigo en su piso y su puesto (lo llama Sim.enter_level tras repartirlos)
func repartir(sim, prefijo: String) -> void:
	var lider_de := {}
	for e in sim.enemies:
		if e.jefe or e.rare:
			lider_de[sim.room_at_px(e.x, e.y)] = e
	var n := 0
	for e in sim.enemies:
		n += 1
		if prefijo != "":
			e.puesto = "%s-%d" % [prefijo, n]
		var sala: int = sim.room_at_px(e.x, e.y)
		var l = lider_de.get(sala) if sala >= 0 else null
		e.apr_lider = l if l != e else null
		e.apr_clave = clave_de(e, sala)
		e.apr_titulo = titulo(e.puesto)

static func clave_de(e: Ent.Enemy, sala: int) -> String:
	var tipo: String = e.mon if e.mon != "" else e.type
	var papel := "grupo"
	if e.jefe:
		papel = "jefe"
	elif e.rare:
		papel = "elite"
	elif e.apr_lider != null:
		papel = "esbirro"
	elif sala < 0:
		papel = "pasillo"
	return tipo + "/" + papel

## despierta: elige la táctica de este combate
func empezar(sim, e: Ent.Enemy) -> void:
	if e.apr_activo or e.muneco:
		return
	if e.apr_clave == "":
		e.apr_clave = clave_de(e, sim.room_at_px(e.x, e.y))
	var lider: bool = e.apr_lider != null and not e.apr_lider.dying and not e.apr_lider.dead
	e.tactica = elegir(e.apr_clave, e.puesto, lider)
	e.apr_activo = true
	e.apr_t0 = sim.t
	e.apr_ult = sim.t
	e.apr_dealt0 = e.dealt
	e.apr_ang = atan2(e.y - sim.p.y, e.x - sim.p.x)

## fin del combate (muere, te mata o se acaba el piso)
func terminar(sim, e: Ent.Enemy, mato: bool) -> void:
	if not e.apr_activo:
		return
	e.apr_activo = false
	var dur := maxf(4.0, sim.t - e.apr_t0)
	var vida: float = maxf(1.0, float(sim.p.st.get("maxHp", 100.0)))
	var nota := (e.dealt - e.apr_dealt0) / vida / dur * ESCALA + (PREMIO_MUERTE if mato else 0.0)
	apuntar(e.apr_clave, e.puesto, e.tactica, nota, mato)
	if e.puesto != "":
		e.apr_titulo = titulo(e.puesto)

## te han matado: gana el que dio el golpe y se cierran los combates de todos los despiertos
func heroe_muere(sim, asesino) -> void:
	for e in sim.enemies:
		if e.apr_activo:
			terminar(sim, e, e == asesino)

func cerrar_todos(sim) -> void:
	for e in sim.enemies:
		if e.apr_activo and not e.dying:
			terminar(sim, e, false)

## cada paso: vigila los tajos y las volteretas del héroe (ventana del contraataque)
func tick(sim) -> void:
	var p = sim.p
	if p.seq != null:
		_atacaba = true
	elif _atacaba:
		_atacaba = false
		_fin_ataque_t = sim.t
	if p.roll_t > 0:
		_rodo_t = sim.t

func _ventana(sim) -> bool:
	var p = sim.p
	return (p.seq != null and p.hit_done) or sim.t - maxf(_fin_ataque_t, _rodo_t) < .7

## a dónde va el enemigo según su táctica (px), o null si toca ir a por ti y golpear
func objetivo(sim, e: Ent.Enemy, d: float) -> Variant:
	if e.tactica == "" or e.tactica == "directo" or e.thrower:
		return null
	if sim.t - e.apr_ult > ESPERA_MAX:
		return null
	var p = sim.p
	var hacia := Vector2(e.x - p.x, e.y - p.y) / maxf(d, 1)
	match e.tactica:
		"rodear":
			# cada uno busca su hueco alrededor del héroe, separándose de los demás
			for o in sim.enemies:
				if o == e or not o.apr_activo or o.dying:
					continue
				var oa := atan2(o.y - p.y, o.x - p.x)
				var df := angle_difference(oa, e.apr_ang)
				if absf(df) < 1.1 and JS.hypot(o.x - p.x, o.y - p.y) < 140:
					e.apr_ang -= signf(df if df != 0 else 1.0) * .04
			var hueco := Vector2(p.x, p.y) + Vector2.from_angle(e.apr_ang) * (e.reach + 8)
			if hueco.distance_to(Vector2(e.x, e.y)) < 14:
				return null
			return hueco
		"espalda":
			var cara := Vector2.from_angle(p.face)
			if hacia.dot(cara) < -.25:
				return null   # ya está detrás
			# rodea por el lado más corto hasta quedar a su espalda
			var lado := signf(cara.cross(hacia))
			if lado == 0: lado = 1
			var dir := hacia.rotated(lado * .9)
			return Vector2(p.x, p.y) + dir * maxf(e.reach + 14, minf(d, 70))
		"contra":
			if _ventana(sim):
				e.burst_t = maxf(e.burst_t, .35)
				return null
			return Vector2(p.x, p.y) + hacia * (e.reach + 30)
		"rematar":
			if p.hp <= p.st.maxHp * REMATAR_VIDA:
				e.burst_t = maxf(e.burst_t, .4)
				return null
			if d < e.reach - 2:
				return null   # te le has echado encima
			return Vector2(p.x, p.y) + hacia.rotated(.35) * (e.reach + 44)
		"escolta":
			var l = e.apr_lider
			if l == null or l.dying or l.dead:
				return null
			if JS.hypot(l.x - p.x, l.y - p.y) < 90:
				return null   # estás junto al jefe: a por ti
			var a := Vector2(l.x, l.y)
			var v := Vector2(p.x, p.y) - a
			return a + v.normalized() * minf(40.0, v.length() * .5)
	return null

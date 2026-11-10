class_name Legendarios
extends RefCounted
## Efectos únicos de los legendarios del caballero (decidido por Diego, 10 nov 2026). Cada pieza
## legendaria lleva su efecto en «efecto»; la simulación llama a los ganchos de aquí. La vista
## (Hechizos3D) lee ondas, fuegos, rayos y eventos para dibujarlos.

const EFECTO := {"sword": "onda", "shield": "aturde", "helm": "cura_elite", "chest": "escudo",
	"gloves": "rayo", "belt": "pocion", "boots": "rastro"}
const TEXTO := {
	"onda": "Cada tercer tajo lanza una onda de fuego hacia delante",
	"aturde": "Al bloquear, aturde 1 s al que te ha golpeado",
	"cura_elite": "Al matar a una élite recuperas el 20 % de la vida",
	"escudo": "Al bajar del 30 % de vida, un escudo absorbe un cuarto de tu vida máxima (una vez por minuto)",
	"rayo": "Los críticos saltan como un rayo a 2 enemigos cercanos (50 % del daño)",
	"pocion": "Las pociones curan el doble y dan +20 % de daño durante 3 s",
	"rastro": "La voltereta deja un rastro de fuego durante 2 s",
}
const CLASES := ["knight"]   # de momento, solo el caballero (producto mínimo)

const ONDA_VEL := 260.0      # px/s
const ONDA_VIDA := .6        # s (unos 10 m)
const ONDA_R := 26.0         # px
const ONDA_DANO := 1.0       # × daño del héroe
const ATURDE := 1.0          # s
const CURA_ELITE := .2       # de la vida máxima
const ESCUDO_UMBRAL := .3
const ESCUDO_PARTE := .25
const ESCUDO_CD := 60.0
const RAYO_N := 2
const RAYO_R := 110.0        # px (unos 7 m)
const RAYO_PARTE := .5
const POCION_X := 2.0
const FURIA := .2
const FURIA_T := 3.0
const RASTRO_PASO := 14.0    # px entre llamas
const RASTRO_VIDA := 2.0
const RASTRO_R := 18.0
const RASTRO_TICK := .5
const RASTRO_DANO := .3      # × daño del héroe por tick

var sim
var ondas := []     # {x, y, vx, vy, t, tocados}
var fuegos := []    # {x, y, t, tick}
var rayos := []     # {x0, y0, x1, y1, t} (la vista los dibuja una vez)
var eventos := []   # {id: aturdido|cura|escudo|furia, ...} (la vista los consume)
var escudo_cd := 0.0
var _ultimo := Vector2(INF, INF)

func _init(s) -> void:
	sim = s

## efecto de una pieza (o "")
static func de(it) -> String:
	return String(it.get("efecto", "")) if it is Dictionary else ""

static func texto(it) -> String:
	return TEXTO.get(de(it), "")

## ¿lleva puesto un legendario con este efecto?
func tiene(id: String) -> bool:
	var p = sim.p
	if p == null:
		return false
	for s in p.eq:
		if de(p.eq[s]) == id:
			return true
	return false

func reset() -> void:
	ondas.clear()
	fuegos.clear()
	rayos.clear()
	eventos.clear()
	escudo_cd = 0.0
	_ultimo = Vector2(INF, INF)

# ----------------------------------------------------------------- ganchos

## tercer tajo del combo
func tajo3() -> void:
	if not tiene("onda"):
		return
	var p = sim.p
	ondas.append({"x": p.x + cos(p.face) * 14, "y": p.y + sin(p.face) * 14 - 6, "vx": cos(p.face) * ONDA_VEL,
		"vy": sin(p.face) * ONDA_VEL, "t": 0.0, "tocados": {}})
	sim.fx.sonido(&"fuego", p.x, p.y)

## golpe crítico de un tajo sobre «e»
func critico(e, dmg: float) -> void:
	if not tiene("rayo"):
		return
	var cerca := []
	for o in sim.enemies:
		if o == e or o.dying:
			continue
		var d: float = JS.hypot(o.x - e.x, o.y - e.y)
		if d < RAYO_R:
			cerca.append([d, o])
	cerca.sort_custom(func(a, b): return a[0] < b[0])
	var de_x: float = e.x
	var de_y: float = e.y
	for i in mini(RAYO_N, cerca.size()):
		var o = cerca[i][1]
		rayos.append({"x0": de_x, "y0": de_y, "x1": o.x, "y1": o.y, "t": 0.0})
		sim.dk_damage(o, maxf(1, dmg * RAYO_PARTE), atan2(o.y - de_y, o.x - de_x), false, "#9fd8ff")
		de_x = o.x
		de_y = o.y

## muere un enemigo
func muere(e) -> void:
	if not tiene("cura_elite"):
		return
	if e.rare or e.jefe or e.type == "champ":
		var n: int = sim.heal(sim.p, sim.p.st.maxHp * CURA_ELITE, "#7aff9a", 12)
		if n > 0:
			eventos.append({"id": "cura"})

## el héroe ha bloqueado un golpe de «src»
func bloqueo(src) -> void:
	if not tiene("aturde") or src == null or not (src is Ent.Enemy) or src.dying:
		return
	src.hurt_t = maxf(src.hurt_t, ATURDE)
	src.act = ""
	src.cool = maxf(src.cool, ATURDE)
	src.vx = 0
	src.vy = 0
	sim.fx.text(src.x, src.y - 56, "aturdido", "#ffd25a", 10, false, 1.2, true, false)
	eventos.append({"id": "aturdido", "e": src, "t": ATURDE})

## el héroe ha perdido vida
func herido() -> void:
	var p = sim.p
	if escudo_cd > 0 or p.dead or not tiene("escudo") or p.hp >= p.st.maxHp * ESCUDO_UMBRAL:
		return
	escudo_cd = ESCUDO_CD
	p.shield = maxf(p.shield, p.st.maxHp * ESCUDO_PARTE)
	sim.fx.text(p.x, p.y - 60, "Coraza de Roldán", "#8fd0ea", 11, false, 1.4, true, false)
	eventos.append({"id": "escudo"})

## veces que cura una poción
func pocion_x() -> float:
	return POCION_X if tiene("pocion") else 1.0

## después de beber
func bebe() -> void:
	if not tiene("pocion"):
		return
	sim.add_effect(sim.p, "furia_leg", [{"stat": "dmg", "pct": FURIA}], FURIA_T)
	eventos.append({"id": "furia", "t": FURIA_T})

# ----------------------------------------------------------------- cada paso

func paso(dt: float) -> void:
	escudo_cd = maxf(0, escudo_cd - dt)
	var p = sim.p
	# rastro de fuego de la voltereta
	if p.roll_t > 0 and not p.dead and tiene("rastro"):
		var aqui := Vector2(p.x, p.y)
		if _ultimo.x == INF or aqui.distance_to(_ultimo) >= RASTRO_PASO:
			_ultimo = aqui
			fuegos.append({"x": p.x, "y": p.y, "t": 0.0, "tick": 0.0})
	elif p.roll_t <= 0:
		_ultimo = Vector2(INF, INF)
	# ondas
	for o in ondas:
		o.t += dt
		o.x += o.vx * dt
		o.y += o.vy * dt
		if sim.solid_px(o.x, o.y):
			o.t = ONDA_VIDA
			continue
		for e in sim.enemies.duplicate():
			if e.dying or o.tocados.has(e.get_instance_id()):
				continue
			if JS.hypot(e.x - o.x, (e.y - 14) - o.y) < ONDA_R + e.cuerpo:
				o.tocados[e.get_instance_id()] = true
				sim.dk_damage(e, maxf(1, p.st.dmg * ONDA_DANO), atan2(o.vy, o.vx), false, "#ff9a3a")
	ondas = ondas.filter(func(o): return o.t < ONDA_VIDA)
	# fuegos del suelo
	for f in fuegos:
		f.t += dt
		f.tick -= dt
		if f.tick <= 0:
			f.tick = RASTRO_TICK
			for e in sim.enemies.duplicate():
				if not e.dying and JS.hypot(e.x - f.x, e.y - f.y) < RASTRO_R + e.cuerpo:
					sim.dk_damage(e, maxf(1, p.st.dmg * RASTRO_DANO), 0.0, true, "#ff9a3a")
	fuegos = fuegos.filter(func(f): return f.t < RASTRO_VIDA)
	for r in rayos:
		r.t += dt
	rayos = rayos.filter(func(r): return r.t < .5)

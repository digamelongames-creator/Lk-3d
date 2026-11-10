class_name Sim
extends RefCounted
## Núcleo de la partida: todo lo que decide (posiciones, daño, IA, botín) y nada de dibujo.
## Traducción de update() y sus funciones del juego web: un piso por semilla, las cinco clases del héroe
## (lo propio de cada una está en clases.gd y el árbol de habilidades en arbol.gd) y todos los enemigos.
## Lo que se ve u oye sale por `fx` (SimFx); la vista lo pinta.

const TS := 32
static var WW: int:
	get: return DungeonGen.GW * DungeonGen.TS
static var WH: int:
	get: return DungeonGen.GH * DungeonGen.TS
const FRAD := 42
## versión 3D: los golpes del héroe no cortan el ataque del enemigo ni lo dejan parado (sí la parada perfecta),
## el empujón es pequeño y el héroe no avanza al atacar
const INTERRUMPIR := false
const EMPUJE := .3
const LUNGE := false
const BASE_SPD := 138 * .8 * .5 * 1.2
const ATK_CD := .2
const COMBO_SPACING := 1.95
const COMBO_PAUSE := 0.0
const ENEMY_TURN := 6.5
const ROLL_T := .2 * Ritmo.DASH_TIEMPO
const ROLL_SPD := 155.0
const AFT := .042
const ENEMY_SPD := 76.0
const BLOCK_PASS := {"move": .5, "fwd": .75}
const RARE := {"dmg": 3, "hp": 5, "spd": 2, "score": 5}
const CHAMP_MULT := 1.5
const CH_CONE := {"r": 56.0, "sp": 1.7}
const M_FOOT := 4.0
const ELITE_XP := {"base": 200, "bloody": 400, "edge": 500}
const MAXLVL := 25
const XPT := [100, 270, 500, 809, 1228, 1792, 2555, 3584, 4973, 6848, 9380, 12798, 17413, 23642, 32052, 42630, 56700, 75400, 100300, 133400, 177400, 236000, 313800, 417400, 555100]
const LEVEL_STAT_PTS := 3
const LEVEL_SKILL_PTS := 1
const DOOR_R := 40.0
const GOLD_R := 24.0
const KEY_R := 30.0
const BLOOD := ["#8e1a14", "#a8231a", "#6a120e", "#7d160f"]
const KNIGHTS := ["El Cid", "Ricardo Corazón de León", "Guillermo el Mariscal", "Bertrand du Guesclin", "Godofredo de Bouillon", "Suero de Quiñones", "Jacques de Molay", "Roger de Flor", "Chevalier Bayard", "Balduino IV", "Jan Žižka", "Tancredo de Galilea", "Bohemundo de Tarento", "Alonso Pérez de Guzmán", "Jaime el Conquistador", "Simón de Montfort"]
const BANNER_R := 58.0
const NOVA_R := 36.0
const FREEZE_R := 60.0
const BLINK_MAX := 170.0
const AOE_R := 28.0
## recorte de la web: radio y daño de algunas áreas a la mitad (se aplica al final de skp)
const SKP_NERF := {"rain.r": .5, "rain.mult": .5, "cloud.r": .5, "cloud.mult": .5, "whirl.r": .5, "whirl.mult": .5, "nova.mult": .5, "drain.r": .5, "drain.tick": 1 / 3.0}
const CLASS_ORDER := ["knight", "mage", "archer", "dk", "dl"]
## habilidades: los datos de la web (SKD) con sus parámetros p.* al primer nivel, sin el recorte
static var SK: Dictionary = _build_sk()

static func _build_sk() -> Dictionary:
	var out := {}
	var src: Dictionary = GameData.get_table("skills")
	for id in src:
		var d: Dictionary = src[id].duplicate(true)
		for k in d.get("p", {}):
			d[k] = d.p[k]
		out[id] = d
	out.banner["r"] = BANNER_R
	out.nova["r"] = NOVA_R
	out.freeze["r"] = FREEZE_R
	out.blink["range"] = BLINK_MAX
	return out

var fx: SimFx = SimFx.new()
var rng := RandomNumberGenerator.new()

var L: Dictionary
var G: PackedByteArray
var run_seed := ""
var wave := 1
var t := 0.0
var score := 0
var kills := 0
var hitstop := 0.0
## velocidad de andar del héroe y de los enemigos (Opciones «Velocidad al andar», 0,3–1; banco de pruebas):
## solo el andar; ataques, voltereta, cargas y proyectiles no cambian
var vel_mov := 1.0
var phase := "fight"
var fade := 0.0
var over := false
var cleared := false
var total := 0
var CX := -9999.0
var CY := -9999.0

var p: Ent.Hero
var enemies: Array = []
var allies: Array = []
var corpses: Array = []
var pickups: Array = []
var gold: Array = []
var doors: Array = []
var chests: Array = []
var keyrings: Array = []
var floor_keys: Array = []
var key_tables: Array = []     # mesitas con llave (o mantel con oro): {o (el mueble del mapa), x, y, oro, taken}
var loot: Array = []          # objetos y runas en el suelo: {x, y, item, bob, fly: {x0, y0, tx, ty, ft} | null}
var runes: Runes
var arbol: Arbol
var cls: Clases
var cur_inp: Inp = null       # entrada de este paso (para apuntar las habilidades)
var banner = null             # Estandarte clavado: {x, y, t, max}
var last_stand := false       # «Último en pie» ya usado en este piso
var blood_mask := PackedByteArray()   # sangre en el suelo por celdas de 4×4 px (la absorbe el Charco de sangre)
static var BMW: int:
	get: return WW / 4
var revives := 0
var full_msg_t := -9.0
var projs: Array = []         # espadas lanzadas: {x, y, tx, ty, owner, phase, t, hit, dmg, stall_t, pend, svx, svy}
var marks: Array = []         # avisos en el suelo (cuña, línea, anillo…): {own, kind, t, T, x, y, …}
var explored := PackedByteArray()
var map_dirty := true
var flow := PackedInt32Array()
var pcell := -1
var stat_defs: Dictionary
var class_base: Dictionary
var level_up_pending := false
var start_gear: Array = []    # lo fijo del equipo inicial (las piezas básicas)
## datos de la partida (tecla P): ataques, golpes, tiempo total y por oleada, distancia, muertes y bajas por tipo
var stats := new_stats()
## enemigos que aprenden (Aprendizaje): sin archivo hasta que main3d le da uno (las pruebas no tocan el disco)
var apr := Aprendizaje.new()
var start_wave := 1
var _last_pos := Vector2(INF, INF)

static func new_stats() -> Dictionary:
	return {"swings": 0, "hits": 0, "t": 0.0, "deaths": 0, "dist": 0.0, "waves": {}, "kills": {}}

## qué casilla de bajas cuenta un enemigo
static func kill_kind(e: Ent.Enemy) -> String:
	if e.mon != "":
		return "mon"
	if e.hero != "":
		return "hero"
	if e.rare:
		return "rare"
	return e.type

## lo que pide el jugador en este paso
class Inp extends RefCounted:
	var move := Vector2.ZERO
	var aim := Vector2.ZERO        # punto del mundo al que apunta el ratón
	var aim_mouse := false         # true: se apunta con el ratón; false: al enemigo más cercano
	var attack := false            # pulsado en este paso
	var attack_held := false
	var block := false
	var dash := false
	var skill := -1
	var interact := false
	var potion := false

func rnd() -> float:
	return rng.randf()

func _init() -> void:
	rng.randomize()
	stat_defs = GameData.get_table("stat_defs")
	class_base = GameData.get_table("classes")["dk"]["base"]
	start_gear = GameData.get_table("start_gear")["dk"]
	runes = Runes.new(self)
	arbol = Arbol.new(self)
	cls = Clases.new(self)
	blood_mask.resize(BMW * (WH / 4))

# ======================================================================
#  partida y pisos
# ======================================================================
## clase: knight, mage, archer, dk o dl
func new_game(start_wave: int = 1, seed: String = "", ck: String = "dk") -> void:
	run_seed = seed if seed != "" else "d" + str(rng.randi() % 1000000000)
	wave = start_wave
	score = 0
	kills = 0
	revives = 0
	stats = new_stats()
	self.start_wave = start_wave
	if not CLASS_ORDER.has(ck):
		ck = "dk"
	var C: Dictionary = GameData.get_table("classes")[ck]
	class_base = C.base
	start_gear = GameData.get_table("start_gear")[ck]
	p = Ent.Hero.new()
	p.dk = ck == "dk"
	p.dl = ck == "dl"
	p.cls = "knight" if (p.dk or p.dl) else ck
	p.skills = C.skills.duplicate()
	p.sk = [{"t": 0.0, "cd": 0.0}, {"t": 0.0, "cd": 0.0}, {"t": 0.0, "cd": 0.0}]
	Items.init_gear(p, rng)
	runes.agg(p)
	p.hp = p.st.maxHp
	p.mana = p.st.maxMana

func level_seed(w: int) -> String:
	return run_seed + "-" + str(w)

## entra en un piso ya generado (L); el ornato, las antorchas a su altura y los llaveros salen de Muros
## (si el arte ya se dibujó, ya están). No necesita el arte: vale para el servidor y las pruebas.
func enter_level(level: Dictionary) -> void:
	apr.cerrar_todos(self)   # los combates del piso anterior acaban aquí
	L = level
	Muros.preparar(L)
	SalaSecreta.tallar(L, wave)   # salas secretas tras algunas puertas negras (antes de pintar el piso)
	G = L.grid
	CX = L.fount.x if L.fount != null else -9999.0
	CY = L.fount.y if L.fount != null else -9999.0
	enemies = []
	allies = []
	corpses = []
	pickups = []
	floor_keys = []
	loot = []
	projs = []
	marks = []
	hh_shots = []
	hh_clouds = []
	hh_fx = []
	mon_haz = []
	mon_orbs = []
	boss_fx = []
	bombas = []
	cls.reset()
	banner = null
	blood_mask.fill(0)
	p.x = (L.start.cx + .5) * TS
	p.y = (L.start.cy + .5) * TS + 10
	unstick(p)
	p.caida_t = 0
	p.seg_x = p.x
	p.seg_y = p.y
	p.seq = null; p.roll_t = 0; p.inv = 0; p.blocking = false; p.hurt_t = 0
	explored = PackedByteArray(); explored.resize(DungeonGen.GW * DungeonGen.GH)
	map_dirty = true
	pcell = -1
	cleared = false
	_escalera_pedida = false
	_elegir_reto()
	_populate()
	_chests_init()
	_mazmorra_init()
	_cofre_entrada()
	_cofres_sala()
	_secretas_init()
	total = enemies.size()
	# cada enemigo, su puesto fijo («piso-n» por orden de reparto), su papel y su título
	apr.repartir(self, "" if L.has("prueba") else str(wave))
	phase = "fight"
	fade = 1.0
	reveal(L.start.cx, L.start.cy)
	compute_flow(L.start.cx, L.start.cy)
	# fin de la maldición del piso anterior
	p.effects = p.effects.filter(func(ef): return ef.id != "maldicion")
	runes.on_floor()
	arbol.on_floor()
	recalc(p)

## «¡En pie!»: el héroe se levanta con media vida y aparta a los enemigos cercanos (revive de la web)
## golpe del héroe a un enemigo: con INTERRUMPIR (juego 2D) le corta el ataque y lo deja parado t segundos
func _interrumpe(e: Ent.Enemy, t: float) -> void:
	if INTERRUMPIR:
		e.hurt_t = t
		e.act = ""

func revive() -> void:
	if not p.dead:
		return
	p.dead = false
	p.death_t = 0
	over = false
	p.hp = ceilf(p.st.maxHp / 2)
	p.inv = 1
	p.hurt_t = 0
	p.seq = null
	p.roll_t = 0
	p.blocking = false
	revives += 1
	runes.revives += 1
	# versión 3D: al levantarse no se aparta a los enemigos
	if phase == "descend":
		phase = "fight"
		fade = 0
	for pr in projs:
		pr.phase = "drop"
	fx.burst(p.x, p.y, 20, ["#fff3c0", "#ffd25a", "#ff8a5a"], 40, 160)
	fx.shake(8)
	fx.text(p.x, p.y - 60, "¡En pie!", "#ffd25a", 15, true)
	fx.hud()
	for e in enemies:   # los que siguen despiertos empiezan otro combate
		if e.state != "idle" and not e.dying and not e.dead:
			apr.empezar(self, e)

func begin_descend() -> void:
	phase = "descend"
	fade = 0.0
	p.inv = 99
	fx.burst(p.x, p.y, 10, ["#ffd25a", "#ff8a3a"], 20, 60)

# ======================================================================
#  hoja de estadísticas (recalc)
# ======================================================================
func recalc(h: Ent.Hero) -> void:
	## valor = (base + Σflat) × (1 + Σpct) × Πmult, recortado a [min, max] (como el juego web)
	var flat := {}
	var pct := {}
	var mul := {}
	# equipo puesto, runas y efectos temporales (maldición, Furia de la poción…)
	var mods: Array = []
	# puntos de nivel (1 punto = lo mismo que un punto de afijo; la agilidad da movimiento y velocidad de ataque)
	if h.alloc.get("hp", 0): mods.append({"stat": "maxHp", "flat": 8.0 * h.alloc.hp})
	if h.alloc.get("agi", 0):
		mods.append({"stat": "spd", "pct": .005 * h.alloc.agi})
		mods.append({"stat": "atkSpd", "pct": .005 * h.alloc.agi})
	mods.append_array(runes.mods(h))
	# habilidades activas con modificadores (Gran Valor, Aura de drenaje) y el Estandarte
	for i in h.skills.size():
		if i < h.sk.size() and h.sk[i].t > 0:
			mods.append_array(SK[h.skills[i]].get("mods", []))
	if h == p and in_banner():
		mods.append_array(SK.banner.aura)
	mods.append_array(arbol.mods(h))
	for ef in h.effects:
		mods.append_array(ef.mods)
	if runes.rv("fallenKing"): mods.append({"stat": "atkSpd", "mult": 1.2})
	if runes.rv("novaArmor") and skill_on_id("nova"): mods.append({"stat": "armor", "flat": runes.rv("novaArmor")})
	if runes.rv("innerSun"): mods.append({"stat": "maxMana", "mult": .5})
	mods.append({"stat": "spd", "mult": Ritmo.VEL_HEROE})
	mods.append({"stat": "rollCdMax", "mult": Ritmo.DASH_RECARGA})
	for m in mods:
		if not stat_defs.has(m.stat):
			continue
		if m.has("flat"): flat[m.stat] = flat.get(m.stat, 0.0) + m.flat
		if m.has("pct"): pct[m.stat] = pct.get(m.stat, 0.0) + m.pct
		if m.has("mult"): mul[m.stat] = mul.get(m.stat, 1.0) * m.mult
	var st := h.st
	var old_max = st.get("maxHp")
	for k in stat_defs:
		var d: Dictionary = stat_defs[k]
		var base: float = class_base[k] if class_base.has(k) else d.base
		var v: float = (base + flat.get(k, 0.0)) * (1 + pct.get(k, 0.0)) * mul.get(k, 1.0)
		if d.get("min") != null: v = maxf(d.min, v)
		if d.get("max") != null: v = minf(d.max, v)
		if d.get("round"): v = JS.round(v)
		st[k] = v
	st.dmg += h.alloc.get("dmg", 0)   # los puntos de daño se suman al final: 1 punto = +1 de daño
	st["atkCd"] = ATK_CD / st.atkSpd
	if old_max != null and st.maxHp > old_max:
		h.hp += st.maxHp - old_max
	elif old_max != null and st.maxHp < old_max and not h.dead:
		h.hp = maxf(1, h.hp - (old_max - st.maxHp))
	if h.hp > st.maxHp:
		h.hp = st.maxHp
	if h.mana > st.maxMana:
		h.mana = st.maxMana

## efecto temporal genérico: add_effect(p, "veneno", [{stat: "spd", pct: -.3}], 4)
func add_effect(h: Ent.Hero, id: String, m: Array, dur: float) -> void:
	h.effects = h.effects.filter(func(ef): return ef.id != id)
	h.effects.append({"id": id, "mods": m, "t": dur})
	recalc(h)

## efectos que caducan y regeneración (statTick de la web)
func _stat_tick(dt: float) -> void:
	if p.effects.size():
		for ef in p.effects:
			ef.t -= dt
		p.effects = p.effects.filter(func(ef): return ef.t > 0)
	if p.st.regen > 0 and not p.dead:
		p.regen_acc += p.st.regen * dt
		if p.regen_acc >= 1:
			var n := int(floorf(p.regen_acc))
			p.regen_acc -= n
			heal(p, n)

func heal(h: Ent.Hero, n: float, col: String = "", size: float = 10) -> int:
	var want := int(floorf(n))
	var m := mini(want, int(floorf(h.st.maxHp - h.hp)))
	if not (m > 0) or h.dead:
		return 0
	h.hp += m
	h.healed += m
	if col != "":
		fx.text(h.x, h.y - 44, "+" + str(m), col, size)
	fx.hud()
	return m

func leech(dmg: float) -> void:
	if p.dead or not (p.st.lifesteal > 0):
		return
	p.leech_acc += dmg * p.st.lifesteal
	if p.leech_acc >= 1:
		var n := int(floorf(p.leech_acc))
		p.leech_acc -= n
		heal(p, n, "#d07aff", 9)

func skill_on(i: int) -> bool:
	return i < p.sk.size() and p.sk[i].t > 0

func skill_on_id(id: String) -> bool:
	var i := p.skills.find(id) if p != null else -1
	return i >= 0 and p.sk[i].t > 0

func skp(id: String, par: String) -> float:
	return arbol.skp(id, par)

func has(id: String) -> bool:
	return arbol.has(id)

func in_banner() -> bool:
	return banner != null and banner.t > 0 and p != null and JS.hypot(p.x - banner.x, p.y - banner.y) < skp("banner", "r")

## centro de la Nova (anclada con «Nova anclada») y del Aura (dirigida con «Aura dirigida»)
func nova_c() -> Vector2:
	return Vector2(p.nova_x, p.nova_y) if (has("m_nova_b") and p.nova_x != null) else Vector2(p.x, p.y)

func drain_c() -> Vector2:
	return Vector2(p.drain_x, p.drain_y) if (has("d_drain_b") and p.drain_x != null and skill_on_id("drain")) else Vector2(p.x, p.y)

## la vista marca la sangre del suelo; el Charco de sangre la absorbe
func bm_mark(x: int, y: int) -> void:
	if x < 0 or y < 0 or x >= WW or y >= WH:
		return
	blood_mask[(y >> 2) * BMW + (x >> 2)] = 3

func blood_under(x: float, y: float, erase: bool) -> int:
	const R := 9
	var x0 := JS.roundi(x - R)
	var y0 := JS.roundi(y - R * .6)
	var w := R * 2
	var hh := JS.roundi(R * 1.2)
	if x0 < 0 or y0 < 0 or x0 + w > WW or y0 + hh > WH:
		return 0
	var n := 0
	for yy in range(y0 >> 2, ((y0 + hh - 1) >> 2) + 1):
		for xx in range((x0 >> 2), ((x0 + w - 1) >> 2) + 1):
			var i := yy * BMW + xx
			if blood_mask[i]:
				n += 4
				if erase:
					blood_mask[i] -= 1
	if erase and n:
		fx.blood_suck(x, y, R)
	return n

func xp_need(l: int) -> int:
	return XPT[l - 1]

func gain_xp(n: int) -> void:
	if p.lvl >= MAXLVL:
		return
	p.xp += JS.roundi(n * p.st.xpMul)
	while p.lvl < MAXLVL and p.xp >= xp_need(p.lvl):
		p.xp -= xp_need(p.lvl)
		p.lvl += 1
		p.pts += LEVEL_STAT_PTS
		p.skp += LEVEL_SKILL_PTS
		var h := JS.roundi(p.st.maxHp * .25)
		p.hp = minf(p.st.maxHp, p.hp + h)
		fx.burst(p.x, p.y, 20, ["#ffd25a", "#fff3c0", "#b89bff"], 26, 110)
		fx.text(p.x, p.y - 60, "¡NIVEL " + str(p.lvl) + "!", "#ffd25a", 15, true)
		fx.banner("+%d puntos · +%d de habilidad · pulsa Tab" % [LEVEL_STAT_PTS, LEVEL_SKILL_PTS], "Nivel " + str(p.lvl))
	if p.lvl >= MAXLVL:
		p.xp = 0

# ======================================================================
#  mundo: casillas, colisiones, visión y rastro
# ======================================================================
func cell_of(v: float) -> int:
	return int(floorf(v / TS))

func tile_at(cx: int, cy: int) -> int:
	return 0 if (cx < 0 or cy < 0 or cx >= DungeonGen.GW or cy >= DungeonGen.GH) else G[cy * DungeonGen.GW + cx]

func solid_px(x: float, y: float) -> bool:
	var tt := tile_at(int(floorf(x / TS)), int(floorf(y / TS)))
	if tt == DungeonGen.ABISMO:
		return not vacio_pasa
	return DungeonGen.is_solid(tt)

## muro de verdad (el vacío no frena proyectiles ni orbes)
func muro_px(x: float, y: float) -> bool:
	var tt := tile_at(int(floorf(x / TS)), int(floorf(y / TS)))
	return tt != DungeonGen.ABISMO and DungeonGen.is_solid(tt)

# ---------------- abismo (piso de pasarelas) ----------------
const CAIDA_T := 1.0          # dura la caída hasta perderse en la niebla (la vista la anima)
const CAIDA_DANO := .2           # parte de la vida máxima que quita caer
const CAIDA_EMPUJE := 45.0       # velocidad de empujón con la que un enemigo puede pasar el borde
## mientras es true, el vacío no frena el movimiento (lo activa mv para el héroe y los enemigos empujados)
var vacio_pasa := false

## peldaños (pisos 4 y 5): el héroe va algo más despacio
const ESC_LENTO := .8
func en_escalera(x: float, y: float) -> bool:
	var m: PackedByteArray = L.get("esc_mask", PackedByteArray())
	if m.is_empty():
		return false
	var cx := cell_of(x)
	var cy := cell_of(y - 3)
	return cx >= 0 and cy >= 0 and cx < DungeonGen.GW and cy < DungeonGen.GH and m[cy * DungeonGen.GW + cx] == 1

## el héroe pisa el vacío (y se cae); un enemigo solo si va empujado o muriendo
func _pasa_vacio(o) -> bool:
	return o is Ent.Hero or (o is Ent.Enemy and (o.dying or JS.hypot(o.vx, o.vy) > CAIDA_EMPUJE))

func _empujado(e: Ent.Enemy) -> bool:
	return L.get("plataformas", false) and JS.hypot(e.vx, e.vy) > CAIDA_EMPUJE

func sobre_vacio(x: float, y: float) -> bool:
	return tile_at(cell_of(x), cell_of(y - 3)) == DungeonGen.ABISMO

## ¿el vacío donde cae está detrás de una plataforma? (entonces no se le ve bajar)
func _cae_atras(x: float, y: float) -> bool:
	var cy := cell_of(y - 3)
	return tile_at(cell_of(x), cy + 1) != DungeonGen.ABISMO and tile_at(cell_of(x), cy + 1) != DungeonGen.ROCK

func _vigilar_caida_heroe() -> void:
	if p.dead or p.caida_t > 0 or not L.get("plataformas", false):
		return
	if sobre_vacio(p.x, p.y):
		p.caida_t = CAIDA_T
		p.caida_atras = _cae_atras(p.x, p.y)
		p.seq = null
		p.blocking = false
		p.roll_t = 0
		p.lunge = 0
		fx.sonido(&"caida", p.x, p.y)
	elif fits(p.x, p.y):
		p.seg_x = p.x
		p.seg_y = p.y

## cae: sin control; al terminar, daño y de vuelta al último sitio con suelo
func _caida_heroe(dt: float) -> void:
	p.caida_t -= dt
	p.moving = false
	if p.caida_t > 0:
		return
	p.caida_t = 0
	p.x = p.seg_x
	p.y = p.seg_y
	unstick(p)
	var dmg := maxf(1, JS.round(p.st.maxHp * CAIDA_DANO))
	p.hp = maxf(0, p.hp - dmg)
	p.inv = 1.0
	p.hurt_t = .18
	p.chain = 0
	fx.shake(6 * Ritmo.VIBRA_DANO)
	fx.text(p.x, p.y - 40, "-" + str(int(dmg)), COL_RECIBIDO, 14)
	fx.text(p.x, p.y - 54, "¡Al abismo!", "#c9c5bb", 9)
	fx.hud()
	arbol.last_stand(p)
	runes.lethal()
	if p.hp <= 0:
		p.dead = true
		p.death_t = 0

## true si el enemigo está cayendo (el resto de su lógica se salta)
func _caida_enemigo(e: Ent.Enemy, dt: float) -> bool:
	if e.caida_t > 0:
		e.caida_t -= dt
		if e.caida_t <= 0:
			e.dead = true
		return true
	if not L.get("plataformas", false) or e.dead:
		return false
	if not sobre_vacio(e.x, e.y):
		if not e.dying and fits(e.x, e.y):
			e.seg_x = e.x
			e.seg_y = e.y
		return false
	# cuenta como baja: el botín cae en el borde de donde se ha caído
	if not e.dying:
		var ox := e.x
		var oy := e.y
		e.x = e.seg_x if e.seg_x else ox
		e.y = e.seg_y if e.seg_y else oy
		kill_enemy(e, atan2(oy - e.y, ox - e.x))
		e.x = ox
		e.y = oy
		fx.text(e.x, e.y - 40, "¡Al abismo!", "#ffd25a", 9)
	e.no_corpse = true
	e.hp = 0
	e.caida_t = CAIDA_T
	fx.sonido(&"caida", e.x, e.y)
	e.caida_atras = _cae_atras(e.x, e.y)
	e.vx = 0
	e.vy = 0
	return true

func fits(x: float, y: float, r: float = 6) -> bool:
	var a := x - r
	var b := x + r
	var c := y - 6
	var d := y + 1
	return not solid_px(a, c) and not solid_px(b, c) and not solid_px(a, d) and not solid_px(b, d)

func unstick(o, r: float = 6) -> void:
	vacio_pasa = _pasa_vacio(o)
	var ok := fits(o.x, o.y, r)
	vacio_pasa = false
	if ok:
		return
	var d := 3
	while d < 120:
		for a in 16:
			var x: float = o.x + cos(a * PI / 8) * d
			var y: float = o.y + sin(a * PI / 8) * d
			if fits(x, y, r):
				o.x = x
				o.y = y
				return
		d += 3

func mv(o, dx: float, dy: float, r: float = 6) -> bool:
	if not dx and not dy:
		return false
	vacio_pasa = _pasa_vacio(o)
	var hit := _mv(o, dx, dy, r)
	vacio_pasa = false
	return hit

func _mv(o, dx: float, dy: float, r: float) -> bool:
	if not fits(o.x, o.y, r):
		unstick(o, r)
		return true
	var hit := false
	var n := maxi(1, int(ceilf(maxf(absf(dx), absf(dy)) / 6)))
	var sx := dx / n
	var sy := dy / n
	for i in n:
		if sx:
			if fits(o.x + sx, o.y, r): o.x += sx
			else: hit = true
		if sy:
			if fits(o.x, o.y + sy, r): o.y += sy
			else: hit = true
	return hit

func line_test(x0: float, y0: float, x1: float, y1: float, opaque_only: bool) -> bool:
	var d := JS.hypot(x1 - x0, y1 - y0)
	var n := int(ceilf(d / 8))
	for i in range(1, n):
		var x := x0 + (x1 - x0) * i / n
		var y := y0 + (y1 - y0) * i / n
		var tt := tile_at(int(floorf(x / TS)), int(floorf(y / TS)))
		if DungeonGen.is_opaque(tt) if opaque_only else DungeonGen.is_solid(tt):
			return false
	return true

## camino sin paredes ni muebles de (x0, y0) a (x1, y1), sin contar la casilla de salida (un cofre)
func _reach(x0: float, y0: float, x1: float, y1: float) -> bool:
	var c0 := Vector2i(cell_of(x0), cell_of(y0))
	var n := int(ceilf(JS.hypot(x1 - x0, y1 - y0) / 4))
	for i in range(1, n + 1):
		var x := x0 + (x1 - x0) * i / n
		var y := y0 + (y1 - y0) * i / n
		var c := Vector2i(cell_of(x), cell_of(y))
		if c != c0 and DungeonGen.is_solid(tile_at(c.x, c.y)):
			return false
	return true

## ¿hay un muro de verdad entre dos puntos? Los golpes cuerpo a cuerpo (los tuyos y los de los
## enemigos) no atraviesan las esquinas. Muebles, barriles y el vacío no cuentan.
func muro_entre(x0: float, y0: float, x1: float, y1: float) -> bool:
	var n := maxi(1, int(ceilf(JS.hypot(x1 - x0, y1 - y0) / 3)))
	for i in range(1, n):
		var tt := tile_at(cell_of(x0 + (x1 - x0) * i / n), cell_of(y0 + (y1 - y0) * i / n))
		if tt != DungeonGen.ABISMO and DungeonGen.is_opaque(tt):
			return true
	return false

func has_los(x0: float, y0: float, x1: float, y1: float) -> bool:
	return line_test(x0, y0, x1, y1, true)

func clear_path(x0: float, y0: float, x1: float, y1: float) -> bool:
	var dx := x1 - x0
	var dy := y1 - y0
	var l := JS.hypot(dx, dy)
	if l == 0: l = 1
	var ox := -dy / l * 6
	var oy := dx / l * 6
	return line_test(x0, y0 - 3, x1, y1 - 3, false) and line_test(x0 + ox, y0 - 3 + oy, x1 + ox, y1 - 3 + oy, false) and line_test(x0 - ox, y0 - 3 - oy, x1 - ox, y1 - 3 - oy, false)

func reveal(cx: int, cy: int) -> void:
	const R := 6
	for dy in range(-R, R + 1):
		for dx in range(-R, R + 1):
			if dx * dx + dy * dy > R * R + 2:
				continue
			var x := cx + dx
			var y := cy + dy
			if x < 0 or y < 0 or x >= DungeonGen.GW or y >= DungeonGen.GH:
				continue
			var i := y * DungeonGen.GW + x
			if not explored[i]:
				explored[i] = 1
				map_dirty = true

## campo de rutas para que los enemigos sorteen las paredes
func compute_flow(sx: int, sy: int) -> void:
	if flow.size() != DungeonGen.N:
		flow.resize(DungeonGen.N)
	flow.fill(-1)
	if sx < 0 or sy < 0 or sx >= DungeonGen.GW or sy >= DungeonGen.GH:
		return
	var s := sy * DungeonGen.GW + sx
	flow[s] = 0
	var q := PackedInt32Array([s])
	var h := 0
	while h < q.size():
		var i := q[h]
		h += 1
		var x := i % DungeonGen.GW
		var y := i / DungeonGen.GW
		var dd := flow[i]
		if dd > 400:
			continue
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if not dx and not dy:
					continue
				var nx := x + dx
				var ny := y + dy
				if nx < 0 or ny < 0 or nx >= DungeonGen.GW or ny >= DungeonGen.GH:
					continue
				var j := ny * DungeonGen.GW + nx
				if flow[j] >= 0 or DungeonGen.is_solid(G[j]):
					continue
				if dx and dy and (DungeonGen.is_solid(G[y * DungeonGen.GW + nx]) or DungeonGen.is_solid(G[ny * DungeonGen.GW + x])):
					continue
				flow[j] = dd + 1
				q.append(j)

func nav_dir(e) -> Variant:
	if flow.is_empty():
		return null
	var x := cell_of(e.x)
	var y := cell_of(e.y - 3)
	if x < 0 or y < 0 or x >= DungeonGen.GW or y >= DungeonGen.GH:
		return null
	var cur := flow[y * DungeonGen.GW + x]
	if cur < 0:
		return null
	if cur == 0:
		var dx: float = p.x - e.x
		var dy: float = p.y - e.y
		var l := JS.hypot(dx, dy)
		if l == 0: l = 1
		return Vector2(dx / l, dy / l)
	var best := -1
	var bv := cur
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if not dx and not dy:
				continue
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or ny < 0 or nx >= DungeonGen.GW or ny >= DungeonGen.GH:
				continue
			var j := ny * DungeonGen.GW + nx
			var v := flow[j]
			if v < 0 or v >= bv:
				continue
			if dx and dy and (DungeonGen.is_solid(G[y * DungeonGen.GW + nx]) or DungeonGen.is_solid(G[ny * DungeonGen.GW + x])):
				continue
			bv = v
			best = j
	if best < 0:
		return null
	var tx := (best % DungeonGen.GW + .5) * TS
	var ty := (best / DungeonGen.GW + .5) * TS + 3
	var ddx: float = tx - e.x
	var ddy: float = ty - e.y
	var l2 := JS.hypot(ddx, ddy)
	if l2 == 0: l2 = 1
	return Vector2(ddx / l2, ddy / l2)

# ======================================================================
#  enemigos: aparición
# ======================================================================
func enemy_type_for(w: int) -> String:
	var h := _hh_pick(w)
	if h != "":
		return h
	var r := rnd()
	if w >= 3 and r < minf(.3, .12 + w * .02):
		return "sargwen"
	if w >= 2 and r < .5:
		return "slayer"
	return "knight"

func spawn_enemy(type: String, x: float, y: float) -> Ent.Enemy:
	var d: Dictionary = GameData.get_table("enemy_types")[type]
	var w := wave
	var hp := JS.roundi(d.hp * (1.5 if type == "knight" else 3.0) * (1 + (w - 1) * .08))
	var e := Ent.Enemy.new()
	e.type = type
	e.b = int(d.b)
	e.x = x
	e.y = y
	e.hp = hp; e.max_hp = hp; e.ghost = hp
	e.spd = (ENEMY_SPD * 1.2 if type == "champ" else ENEMY_SPD) * (1 + (w - 1) * .02)
	e.dmg = JS.roundi(d.dmg * 1.25 * (1 + (w - 1) * .05))
	e.xp = JS.roundi(d.xp * (1 + (w - 1) * .12))
	e.reach = d.reach
	e.wind_t = d.wind
	e.score = int(d.score)
	e.thrower = bool(d.get("thrower", false))
	e.armor = bool(d.get("armor", false))
	e.name = d.name
	e.flip = rnd() < .5
	e.walk_t = rnd()
	e.throw_cd = .8 + rnd()
	e.seed = rnd() * 10
	e.tang = 1.0 if rnd() < .5 else -1.0
	e.face = rnd() * 6.283
	e.guard_cd = .5 + rnd()
	e.los_t = rnd() * .2
	e.idle_t = rnd() * 3
	if type == "knight":
		e.reach = 26
		e.wind_t /= 1.25
		e.am *= 1.25
		e.combo = 0
	enemies.append(e)
	if d.has("hero"):
		e.hero = d.hero
		_hh_init(e)
	if type == "champ":
		e.hp = JS.roundi(e.hp * CHAMP_MULT); e.max_hp = e.hp; e.ghost = e.hp
		e.dmg = JS.roundi(e.dmg * CHAMP_MULT)
		var names: Array = GameData.get_table("champions").CHAMPIONS
		e.title = names[int(rnd() * names.size())]
	return e

func make_rare(e: Ent.Enemy) -> void:
	e.rare = true
	e.am = RARE.spd
	e.hp = JS.roundi(e.hp * RARE.hp / 2.0); e.max_hp = e.hp; e.ghost = e.hp
	e.dmg *= RARE.dmg
	e.wind_t /= RARE.spd
	e.score *= RARE.score
	e.throw_cd /= RARE.spd
	var used := {}
	for o in enemies:
		if o.rare and o != e:
			used[o.title] = true
	var free := []
	for n in KNIGHTS:
		if not used.has(n):
			free.append(n)
	var pool: Array = free if free.size() else KNIGHTS
	e.title = pool[int(rnd() * pool.size())]
	_dar_poder(e)

func _rand_cell_in(r: Dictionary, tries: int = 40) -> Variant:
	for i in tries:
		var cx: int = r.x + 1 + int(floorf(rnd() * (r.w - 2)))
		var cy: int = r.y + 1 + int(floorf(rnd() * (r.h - 2)))
		var tt := G[cy * DungeonGen.GW + cx]
		if tt != DungeonGen.FLOOR and tt != DungeonGen.RUBBLE:
			continue
		var x := (cx + .5) * TS
		var y := (cy + .5) * TS + 8
		if not fits(x, y, 8):
			continue
		if L.fount != null and JS.hypot(x - CX, y - CY) < FRAD + 24:
			continue
		var near := false
		for e in enemies:
			if JS.hypot(e.x - x, e.y - y) < 24:
				near = true
				break
		if near:
			continue
		return {"x": x, "y": y, "cx": cx, "cy": cy}
	return null

func _populate() -> void:
	if L.has("ciudad"):   # Inca es zona segura: sin enemigos
		return
	var w := wave
	var dist: PackedInt32Array = L.dist
	var corr: PackedByteArray = L.corr
	for k in L.rooms.size():
		var r: Dictionary = L.rooms[k]
		if k == L.start_room or k == int(reto.get("room", -1)):
			continue
		# grupos de 5–10 por sala (más cuanto más hondo), de humanos, de esqueletos o mezclados
		var n := mini(GRUPO_MAX, GRUPO_MIN + int(rnd() * 3) + mini(3, (w - 1) >> 1))
		if L.fount != null and k == L.fount.room:
			n = maxi(0, n - 3)
		if k == L.end_room:
			n = mini(GRUPO_MAX, n + 2)
		var mezcla := rnd()   # < .45 humanos, < .8 esqueletos, si no, mitad y mitad
		var grupo: Array[Ent.Enemy] = []
		for i in n:
			var c = _rand_cell_in(r)
			if c == null or dist[c.cy * DungeonGen.GW + c.cx] <= 8:
				continue
			var hueso := mezcla >= .45 and (mezcla < .8 or i % 2 == 0)
			grupo.append(mon_spawn("esqueleto", c.x, c.y) if hueso else spawn_enemy(enemy_type_for(w), c.x, c.y))
		# a veces el grupo lo lleva una élite
		if grupo.size() and rnd() < minf(.5, .2 + .04 * w):
			_hacer_elite(grupo[int(rnd() * grupo.size())])
	# patrullas en los pasillos
	var cor := []
	for i in DungeonGen.GW * DungeonGen.GH:
		if corr[i] and G[i] == DungeonGen.FLOOR and dist[i] > 12:
			cor.append(i)
	var m := (3 + mini(3, w >> 1)) * DungeonGen.escala()
	while m > 0 and cor.size():
		m -= 1
		var i: int = cor.pop_at(int(rnd() * cor.size()))
		var x := (i % DungeonGen.GW + .5) * TS
		var y := (i / DungeonGen.GW + .5) * TS + 8
		var crowd := false
		for e in enemies:
			if JS.hypot(e.x - x, e.y - y) < 40:
				crowd = true
				break
		if not fits(x, y, 8) or crowd:
			continue
		spawn_enemy(enemy_type_for(w), x, y)
		if rnd() < .45:
			var o := {"x": x + (-18.0 if rnd() < .5 else 18.0), "y": y + (rnd() - .5) * 10}
			unstick(o, 8)
			spawn_enemy(enemy_type_for(w), o.x, o.y)
	# emboscadas en las esquinas de los pasillos
	var op := func(x: int, y: int) -> bool:
		var tt := G[y * DungeonGen.GW + x]
		return tt != 0 and tt != 2
	var cand := []
	for y in range(2, DungeonGen.GH - 2):
		for x in range(2, DungeonGen.GW - 2):
			var i := y * DungeonGen.GW + x
			if not corr[i] or G[i] != DungeonGen.FLOOR or dist[i] < 10:
				continue
			var nn: bool = op.call(x, y - 1)
			var s2: bool = op.call(x, y + 1)
			var w2: bool = op.call(x - 1, y)
			var e2: bool = op.call(x + 1, y)
			if (nn != s2) and (w2 != e2) and (nn or s2) and (w2 or e2):
				cand.append(i)
	if cand.size() < 6:
		for y in range(2, DungeonGen.GH - 2):
			for x in range(2, DungeonGen.GW - 2):
				var i := y * DungeonGen.GW + x
				if not corr[i] or G[i] != DungeonGen.FLOOR or dist[i] < 10 or cand.has(i):
					continue
				for d4 in DungeonGen.D4:
					var ro: int = L.room_of[(y + d4[1]) * DungeonGen.GW + x + d4[0]]
					if ro >= 0 and ro != L.start_room:
						cand.append(i)
						break
	var na := (2 + mini(3, w >> 1)) * DungeonGen.escala()
	while na > 0 and cand.size():
		na -= 1
		var i: int = cand.pop_at(int(rnd() * cand.size()))
		var x := (i % DungeonGen.GW + .5) * TS
		var y := (i / DungeonGen.GW + .5) * TS + 8
		var crowd := false
		for e in enemies:
			if JS.hypot(e.x - x, e.y - y) < 36:
				crowd = true
				break
		if not fits(x, y, 8) or crowd:
			na += 1
			continue
		var e := spawn_enemy("slayer" if rnd() < .5 else "knight", x, y)
		e.ambush = true
		e.ambush_hit = true
	_hh_elites(w)
	_mon_populate(w)
	# cada 5 pisos, un campeón guarda la escalera (y es el jefe del piso); los demás pisos, un monstruo
	if w % 5 != 0:
		_jefe_piso(w)
	else:
		var r: Dictionary = L.rooms[L.end_room]
		var st: Dictionary = L.stairs_px
		var rcx: float = (r.x + r.w / 2.0) * TS
		var rcy: float = (r.y + r.h / 2.0) * TS
		var ddx: float = rcx - st.x
		var ddy: float = rcy - st.y
		var dd := JS.hypot(ddx, ddy)
		if dd == 0: dd = 1
		var o := {"x": st.x + ddx / dd * 56, "y": st.y + ddy / dd * 56 + 10}
		if tile_at(cell_of(o.x), cell_of(o.y)) == DungeonGen.DOWN:
			o.y += 48
		unstick(o, 8)
		_hacer_jefe(spawn_enemy("champ", o.x, o.y), "")

## cofres y su guardián dorado (los del Soul Eater los guarda él), puertas, oro y llaves
func _chests_init() -> void:
	chests = []
	for o in L.chests:
		chests.append({"cx": o.cx, "cy": o.cy, "kind": o.kind, "room": o.get("room"), "se": o.get("se", false), "x": (o.cx + .5) * TS, "y": (o.cy + 1) * TS - 4, "open": false, "open_t": 0.0, "best": 0, "guards": [], "msg_t": -9.0})
	for c in chests:
		if c.kind == "gold" and not c.se:
			var o := {"x": c.x, "y": c.y + 40}
			unstick(o, 8)
			var r := rnd()
			var e := spawn_enemy("sargwen" if wave >= 10 and r < .25 else ("slayer" if r < .6 else "knight"), o.x, o.y)
			if not e.rare:
				make_rare(e)
			e.guard_chest = true
			c.guards = [e]
		elif c.se:
			c.guards = enemies.filter(func(e): return e.se_room == c.room)
	doors = []
	for d in L.doors:
		var h: bool = d.h
		var x: float = (d.x0 + d.x1 + 1) / 2.0 * TS if h else (d.x0 + .5) * TS
		var y: float = (d.y0 + 1) * TS if h else (d.y1 + 1) * TS
		doors.append({"cells": d.cells, "h": h, "room": d.room, "x0": d.x0, "y0": d.y0, "x1": d.x1, "y1": d.y1,
			"x": x, "y": y, "cx": x if h else (d.x0 + .5) * TS, "cy": (d.y0 + .5) * TS if h else (d.y0 + d.y1 + 1) / 2.0 * TS, "open": false, "open_t": 0.0, "msg_t": -9.0})
	gold = []
	for g in L.gold:
		gold.append({"x": g.x, "y": g.y, "amt": g.amt, "bob": rnd() * 6, "manual": false})
	key_tables = []
	for o in L.get("key_tables", []):
		o["taken"] = false
		key_tables.append({"o": o, "x": (o.cx + .5) * TS, "y": (o.cy + 1) * TS + 4, "oro": o.get("n") == "table_medium_tablecloth_decorated_B", "taken": false})
	keyrings = []
	for k in L.keyrings:
		var k2: Dictionary = k.duplicate()
		k2["taken"] = false
		keyrings.append(k2)

# ======================================================================
#  cofres y botín (tryOpenChest, rollDrops, rnFan… del juego web)
# ======================================================================
const CHEST_R := 30.0
const CHEST_LOOT := {
	"wood": {"n": [1, 2], "min": 0, "potion": .5, "leg": 0.0, "gold": [10, 30]},
	"iron": {"n": [2, 2], "min": 1, "potion": .35, "leg": 0.0, "gold": [20, 50]},
	"gold": {"n": [3, 3], "min": 2, "potion": 1.0, "leg": .15, "gold": [60, 120]},
	"cursed": {"n": [2, 3], "min": 2, "potion": .3, "leg": .1, "gold": [40, 80]},
	"sala": {"n": [1, 2], "min": 0, "potion": .6, "leg": .02, "gold": [15, 40]},
}
const CHEST_N := {"wood": "Baúl de madera", "iron": "Cofre de hierro", "gold": "Cofre dorado", "cursed": "Cofre maldito", "mimic": "Baúl de madera"}

func nearest_chest() -> Variant:
	var best = null
	var bd := CHEST_R
	for c in chests:
		if c.open:
			continue
		var d := JS.hypot(c.x - p.x, (c.y - 6) - p.y)
		if d < bd:
			bd = d
			best = c
	return best

## ¿el cofre aún tiene guardianes vivos?
func chest_locked(c: Dictionary) -> bool:
	if c.has("sala"):   # cofre de sala: cerrado hasta que mueran los que estaban en ella
		return guardias_vivos(c) > 0
	if c.kind != "gold":
		return false
	for e in c.guards:
		if not e.dying and enemies.has(e):
			return true
	return false

func _chest_qual(mn: int, leg: float) -> int:
	var r := rnd() * (1 / maxf(.5, p.st.findMul))
	var q := 2 if r < .06 else (1 if r < .4 else 0)
	q = maxi(q, mn)
	if leg > 0 and rnd() < leg * p.st.findMul:
		q = 3
	return q

func _spawn_around(x: float, y: float, n: int, rmin: float, rmax: float) -> void:
	var made := 0
	var tries := 0
	while made < n and tries < 60:
		tries += 1
		var a := rnd() * TAU
		var r := rmin + rnd() * (rmax - rmin)
		var ex := x + cos(a) * r
		var ey := y + sin(a) * r * .8
		if not fits(ex, ey, 8) or not has_los(x, y - 6, ex, ey - 6):
			continue
		var e := spawn_enemy(enemy_type_for(wave), ex, ey)
		e.rare = false
		wake(e)
		e.wake_t = 0
		made += 1
		fx.burst(ex, ey, 10, ["#3a1a3a", "#8a2a6a", "#1a0a1a"], 14, 60)
	total += made

func try_open_chest(c: Dictionary) -> void:
	if p.dead:
		return
	if chest_locked(c):
		if not (c.msg_t > t - .8):
			c.msg_t = t
			var n := guardias_vivos(c)
			var aviso := ("Limpia la sala · queda %d" % n if n == 1 else "Limpia la sala · quedan %d" % n) if c.has("sala") else "Derrota al guardián"
			fx.text(c.x, c.y - 36, aviso, "#ffd25a", 10, false, 1.1, false, false)
		return
	if c.get("inicio", false):
		_abrir_cofre_entrada(c)
		return
	if c.kind == "iron":
		if not (p.keys > 0) and not runes.lockpick():
			if not (c.msg_t > t - .8):
				c.msg_t = t
				fx.text(c.x, c.y - 36, "Necesitas una llave", "#e8d8a0", 10, false, 1.1, false, false)
			return
		if runes.picked:
			runes.picked = false
		else:
			p.keys -= 1
			fx.text(p.x, p.y - 62, "−1 llave", "#e8d8a0", 10, false, 1, false, false)
	if c.kind == "mimic":   # ¡muerde!
		_morder(c)
		return
	var CL: Dictionary = CHEST_LOOT["sala" if c.has("sala") else c.kind]
	var n: int = CL.n[0] + int(rnd() * (CL.n[1] - CL.n[0] + 1))
	var quals := []
	for i in n:
		quals.append(_chest_qual(CL.min if i == 0 else 0, CL.leg if i == 0 else 0.0))
	quals.sort()
	quals.reverse()
	if c.get("boss", false):
		quals[0] = 3 if rnd() < .5 else 2
		quals.append(2)
	if c.get("reto", false):   # premio del reto de oleadas: un legendario seguro
		quals[0] = 3
		quals.append(2)
	c.open = true
	c.open_t = 0
	c.best = quals[0]
	var items := []
	for q in quals:
		items.append(_gear_drop(q))
	for id in _chest_runes(c):
		items.append(Items.rune_item(id))
	if c.get("boss", false):
		items.append(Items.rune_item(rune_roll(4, true)))
		items.append(Items.rune_item(rune_roll(4, true)))
	_fan(c.x, c.y, items, 1 if rnd() < CL.potion else 0, true)
	drop_gold(c.x, c.y + 4, (CL.gold[0] + rnd() * (CL.gold[1] - CL.gold[0])) * (1 + wave * .1), false)
	if c.get("reto", false):   # y mucho oro
		for i in 5:
			drop_gold(c.x + (rnd() - .5) * 60, c.y + 8 + rnd() * 24, (60 + rnd() * 40) * (1 + wave * .15), false)
	fx.burst(c.x, c.y, 12, ["#fff3c0", Items.RQ_C[c.best]], 10, 70)
	fx.text(c.x, c.y - 34, String(c.get("nombre", CHEST_N[c.kind])), Items.RQ_C[c.best], 10, false, 1.2, false, false)
	if c.kind == "cursed":
		if rnd() < .5:
			_spawn_around(c.x, c.y, 3, 40, 80)
			fx.banner("¡El cofre estaba maldito!", "Salen sus guardianes")
		else:
			add_effect(p, "maldicion", [{"stat": "dmg", "pct": -.2}, {"stat": "spd", "pct": -.15}], 1e6)
			fx.banner("Maldición hasta el próximo piso", "−20 % daño · −15 % velocidad")
	map_dirty = true

## cada paso: tapa abierta y objetos en vuelo
func _chest_tick(dt: float) -> void:
	for c in chests.duplicate():
		if c.open:
			c.open_t += dt
		elif c.kind == "mimic" and not p.dead and JS.hypot(c.x - p.x, c.y - p.y) < MIMICO_R:
			_morder(c)   # al acercarte, no hace falta abrirlo
	for l in loot:
		var f = l.get("fly")
		if f == null:
			continue
		f.ft += dt / float(f.get("dur", .55))
		if f.ft < 0:
			continue
		var k := minf(1, f.ft)
		# en el plano va en línea recta; la altura (alto, en px) la usa la vista 3D para el arco
		l.x = f.x0 + (f.tx - f.x0) * k
		l.y = f.y0 + (f.ty - f.y0) * k
		l.alto = sin(PI * k) * float(f.get("h", 26.0))
		if k >= 1:
			l.x = f.tx
			l.y = f.ty
			l.alto = 0.0
			l.fly = null
			l.land_t = t
			var q := int(l.item.get("q", 0))
			fx.burst(l.x, l.y, 4, ["#e8e2d0", Items.RQ_C[clampi(q, 0, 3)]], 4 + q * 4, 30 + q * 15)
			if l.item.get("gear", false) and q == 3:
				fx.sonido(&"legendario", l.x, l.y)
			elif l.item.get("gear", false) and q == 2:
				fx.sonido(&"dorado", l.x, l.y)

# ---------- qué cae ----------
## rango de runa: entre los permitidos en este piso, por pesos
func _rune_tier(min_t: int, leg_ok: bool) -> int:
	var opts := []
	for tt in range(1, 6):
		if tt < min_t or (tt == 5 and not leg_ok) or (Items.RN_FLOOR[tt] > wave and tt != min_t):
			continue
		opts.append([tt, Items.RN_W[tt]])
	if opts.is_empty():
		return mini(min_t, 5 if leg_ok else 4)
	var sum := 0.0
	for o in opts:
		sum += o[1]
	var r := rnd() * sum
	for o in opts:
		r -= o[1]
		if r <= 0:
			return o[0]
	return opts[-1][0]

## runa de un rango: las de clase caen de la tuya las 3 primeras veces de cada rango
func _rune_pick(tt: int) -> String:
	var pool := Items.runes().filter(func(r): return int(r.t) == tt)
	var r: Dictionary = pool[int(rnd() * pool.size())]
	if r.k != "Todas":
		var own := pool.filter(func(o): return o.k == Items.CLS_N[p.cls_key()])
		if p.rn_cls.get(tt, 0) < 3 and own.size():
			r = own[int(rnd() * own.size())]
			p.rn_cls[tt] = p.rn_cls.get(tt, 0) + 1
	return r.id

func rune_roll(min_t: int, leg_ok: bool) -> String:
	return _rune_pick(_rune_tier(min_t, leg_ok))

## de qué clase cae una pieza: la mitad de las veces la tuya, el resto de las otras cuatro
func _gear_drop(q: int) -> Dictionary:
	var own := p.cls_key()
	var k := own
	if rnd() >= .5:
		var others := Items.CLASSES.filter(func(c): return c != own)
		k = others[int(rnd() * others.size())]
	return Items.make_gear(rng, q, k)

## madera 1 runa, hierro 2 (una de rango II o más), dorado 3 (una de III o más), maldito 2
func _chest_runes(c: Dictionary) -> Array:
	const N := {"wood": 1, "iron": 2, "gold": 3, "cursed": 2}
	var n: int = (1 if c.has("sala") else N.get(c.kind, 1)) + int(runes.rv("looter"))
	var out := []
	for i in n:
		out.append(rune_roll(N.get(c.kind, 1) if i == 0 else 1, c.kind == "gold"))
	return out

func roll_drops(e: Ent.Enemy) -> void:
	if e.hero == "minion":
		return
	var ids := []
	var gear := []
	var fm: float = p.st.findMul
	if e.mimic:
		ids.append_array([rune_roll(2, false), rune_roll(1, false)])
		gear.append(2)
	elif e.jefe:   # jefe del piso: tres piezas buenas (una legendaria a veces) y dos runas, además de su cofre
		ids.append_array([rune_roll(3, true), rune_roll(2, true)])
		gear.append(3 if rnd() < .35 else 2)
		gear.append(2)
		gear.append(2 if rnd() < .5 else 1)
	elif e.type == "champ" or e.boss != "":
		ids.append_array([rune_roll(3, true), rune_roll(2, true)])
		for i in 2:
			var r := rnd()
			gear.append(3 if r < .15 else (2 if r < .65 else 1))
	elif e.rare:
		var n := 1 + (1 if runes.has_vs3("rare") else 0)
		if runes.rv("midas"):
			n *= 3
		for i in n:
			ids.append(rune_roll(2 if i == 0 else 1, true))
		var r := rnd()
		gear.append(3 if r < .08 else (2 if r < .45 else 1))
		gear.append(1 if rnd() < .5 else 0)   # más botín (10 nov): una pieza más
	else:
		if rnd() < BOTIN.runa * fm:
			ids.append(rune_roll(1, false))
		if rnd() < (BOTIN.pieza_lanza if e.thrower else BOTIN.pieza) * fm:
			var r := rnd()
			gear.append(3 if r < .01 else (2 if r < .06 else (1 if r < .31 else 0)))
	if ids.is_empty() and gear.is_empty():
		return
	var items := []
	for q in gear:
		items.append(_gear_drop(q))
	for id in ids:
		items.append(Items.rune_item(id))
	_fan(e.x, e.y, items, 0, e.rare or e.jefe or e.mimic or e.type == "champ" or e.boss != "")

## un sitio donde se pueda recoger: fuera de la fuente y sin muebles ni paredes;
## con origen, además, sin paredes entre el origen y el sitio (que no salte a otra sala)
func safe_spot(x: float, y: float, from: Variant = null) -> Vector2:
	var ve := func(a: float, b: float) -> bool: return from == null or _reach(from.x, from.y - 3, a, b - 3)
	var out := func(a: float, b: float) -> bool: return L.fount != null and JS.hypot(a - CX, b - CY) < FRAD + 10
	if out.call(x, y):
		var fx_ := x - CX
		var fy := y - CY
		var fd := maxf(1, JS.hypot(fx_, fy))
		x = CX + fx_ / fd * (FRAD + 12)
		y = CY + fy / fd * (FRAD + 12)
	if fits(x, y, 7) and not out.call(x, y) and ve.call(x, y):
		return Vector2(x, y)
	var d := 4
	while d < 140:
		for a in 16:
			var tx := x + cos(a * PI / 8) * d
			var ty := y + sin(a * PI / 8) * d
			if fits(tx, ty, 7) and not out.call(tx, ty) and ve.call(tx, ty):
				return Vector2(tx, ty)
		d += 4
	if from != null:
		return Vector2(from.x, from.y)
	return Vector2(p.x, p.y)

## todo sale en abanico desde (x, y): objetos, runas y pociones
## explota: élites, jefes y cofres; el botín sale disparado en todas direcciones, más lejos y más alto
func _fan(x: float, y: float, items: Array, potions: int, explota := false) -> void:
	var n := items.size() + potions
	var k := 0
	var giro := rnd() * TAU
	if explota and items.size():
		fx.burst(x, y, 20, ["#fff3c0", "#ffd25a", "#ffffff"], 26, 160)
		fx.sonido(&"botin", x, y)
	for item in items:
		var a := PI * (.18 + .64 * (float(k) / (n - 1) if n > 1 else .5)) + (rnd() - .5) * .2
		var r := 24 + rnd() * 12
		if explota:
			a = giro + TAU * float(k) / maxf(1, items.size()) + (rnd() - .5) * .5
			r = 40 + rnd() * 34
		k += 1
		var tx := x + cos(a) * r
		var ty := y + 8 + sin(a) * r * .7
		var s := 0
		while s < 6 and not fits(tx, ty, 7):
			tx += (x - tx) * .35
			ty += 4
			s += 1
		var v := safe_spot(tx, ty, Vector2(x, y))
		var f := {"x0": x, "y0": y - 8, "tx": v.x, "ty": v.y, "ft": -k * (.06 if explota else .12), "h": 70.0 if explota else 26.0, "dur": .8 if explota else .55}
		loot.append({"x": x, "y": y - 8, "item": item, "bob": rnd() * 6, "fly": f, "alto": 0.0})
		if item.has("rune"):
			var rr := Items.rune(item.rune)
			if int(rr.t) >= 4:
				fx.banner("¡Runa legendaria!" if int(rr.t) == 5 else "¡Runa épica!", rr.n)
		elif item.get("gear", false) and item.q == 3:
			fx.banner("¡Objeto legendario!", item.name)
	for i in potions:
		var a := PI * (.25 + .5 * rnd())
		var tx := x + cos(a) * 30
		var ty := y + 10 + sin(a) * 18
		var s := 0
		while s < 6 and not fits(tx, ty, 7):
			tx += (x - tx) * .35
			ty += 4
			s += 1
		var v := safe_spot(tx, ty, Vector2(x, y))
		pickups.append({"x": v.x, "y": v.y, "t": 1e9, "bob": rnd() * 6, "no_pick": 0.0})

func nearest_loot() -> Variant:
	var best = null
	var bd: float = p.st.pickupR
	for l in loot:
		if l.get("fly") != null:
			continue
		var d := JS.hypot(l.x - p.x, l.y - p.y)
		if d < bd:
			bd = d
			best = l
	return best

func _bag_full_msg() -> void:
	if not (full_msg_t > t - .6):
		full_msg_t = t
		fx.text(p.x, p.y - 50, "La mochila está llena", "#ff3b30", 13, true, 1.2, false, false)

## tecla de usar: objetos y runas
func try_pickup(l: Dictionary) -> void:
	var it: Dictionary = l.item
	if it.has("rune"):
		var n: int = it.get("n", 1)
		var left := Items.add_rune(p, it.rune, n)
		var r := Items.rune(it.rune)
		if left < n:
			p.rn_new += 1
			fx.text(p.x, p.y - 50, "Runa " + String(r.n), Items.RN_TC[int(r.t)], 10, false, 1.4, false, false)
			fx.burst(l.x, l.y, 6, ["#fff3c0", Items.RN_TC[int(r.t)]], 8, 50)
		if left > 0:
			it.n = left
			_bag_full_msg()
		else:
			loot.erase(l)
		fx.hud()
		return
	# autoequipado: si su hueco está vacío y la clase puede llevarla, se la pone; si no, a la mochila
	if it.get("gear", false) and p.eq.get(it.slot) == null and Items.why_equip(p, it) == "":
		p.eq[it.slot] = it
		loot.erase(l)
		runes.agg(p)
		var cq: String = Items.RQ_C[it.q]
		fx.text(p.x, p.y - 50, it.name + " · puesto", cq, 10, false, 1.4, false, false)
		fx.burst(l.x, l.y, 10, ["#fff3c0", cq], 10, 60)
		fx.hud()
		return
	if not Items.bag_add(p, it):
		_bag_full_msg()
		return
	loot.erase(l)
	var c: String = Items.RQ_C[it.q]
	fx.text(p.x, p.y - 50, it.name, c, 10, false, 1.2, false, false)
	fx.burst(l.x, l.y, 6, ["#fff3c0", c], 8, 50)
	p.rn_new += 1
	fx.hud()

## soltar en el suelo lo que se tira desde el inventario
func drop_item(it: Dictionary) -> void:
	var v := safe_spot(p.x + (-22 if p.flip else 22), p.y + 6, Vector2(p.x, p.y))
	if it.slot == "potion":
		for i in int(it.get("n", 1)):
			pickups.append({"x": v.x + (i - (it.get("n", 1) - 1) / 2.0) * 7, "y": v.y, "t": 1e9, "bob": rnd() * 6, "no_pick": .8})
		return
	loot.append({"x": v.x, "y": v.y, "item": it, "bob": rnd() * 6, "fly": null})

# ======================================================================
#  el paso de simulación
# ======================================================================
func step(dt: float, inp: Inp) -> String:
	## devuelve "descend" cuando hay que pasar al piso siguiente, "over" al morir, "" si nada
	cur_inp = inp
	_count_stats(dt)
	if hitstop > 0:
		hitstop -= dt
		return ""
	t += dt
	apr.tick(self)
	if phase == "fight":
		if not p.dead and tile_at(cell_of(p.x), cell_of(p.y - 3)) == DungeonGen.DOWN:
			if jefe_vivo() == null:
				if preguntar_escalera:
					# la vista pregunta qué hacer (Inca: elegir piso; tras el jefe: bajar o subir a Inca), una vez por pisada
					if not _escalera_pedida:
						_escalera_pedida = true
						return "escalera"
				else:
					begin_descend()
			elif t - _aviso_escalera_t > 2.0:
				_aviso_escalera_t = t
				var j := jefe_vivo()
				fx.text(p.x, p.y - 60, j.title + " guarda la escalera", "#ff5a3a", 12, false, 1.6, true, false)
				fx.sonido(&"escalera_cerrada", p.x, p.y)
		else:
			_escalera_pedida = false
	elif phase == "descend":
		fade += dt / .7
		if fade >= 1:
			fade = 1
			return "descend"
	if phase != "descend" and fade > 0:
		fade = maxf(0, fade - dt / .6)
	var pcx := cell_of(p.x)
	var pcy := cell_of(p.y - 3)
	var pc := pcy * DungeonGen.GW + pcx
	if pc != pcell:
		pcell = pc
		reveal(pcx, pcy)
		compute_flow(pcx, pcy)
	_update_hero(dt, inp)
	_vigilar_caida_heroe()
	runes.tick(dt)
	_chest_tick(dt)
	_update_pickups(dt)
	if allies.size():
		_update_allies(dt)
	cls.tick(dt)
	if not p.dead:
		_blood_trail(p, p.hp / p.st.maxHp, dt)
	if p.dead and p.death_t < 2.4:
		fx.blood_pool(p, 5 + minf(1, p.death_t / 2.2) * 23)
	_update_enemies(dt)
	_hh_update(dt)
	_mon_update(dt)
	_mon_empuje(dt)
	_poderes_tick(dt)
	_trampas_tick(dt)
	_reto_tick(dt)
	_update_projs(dt)
	_update_marks(dt)
	var alive := []
	for e in enemies:
		if not e.dead:
			alive.append(e)
	enemies = alive
	if not cleared and total > 0 and phase == "fight" and not enemies.size():
		cleared = true
		var b := wave * 40
		score += b
		gain_xp(wave * 20)
		fx.banner("+%d puntos · +%d EXP" % [b, wave * 20], "Mazmorra despejada")
		fx.hud()
	if p.dead and p.death_t > 1.6 and not over:
		over = true
		stats.deaths = int(stats.get("deaths", 0)) + 1
		return "over"
	if secreta_pedida != null:
		return "secreta"   # la vista pregunta «¿Entrar?» y hace el fundido (cruzar_secreta)
	return ""

func _update_hero(dt: float, inp: Inp) -> void:
	if p.dead:
		p.death_t += dt
		return
	if p.aturdido > 0:   # aturdido (salto del capitán demonio): ni se mueve ni ataca
		p.aturdido -= dt
		inp = Inp.new()
	if p.caida_t > 0:
		_caida_heroe(dt)
		return
	var mx := inp.move.x
	var my := inp.move.y
	var m := JS.hypot(mx, my)
	if m > 1:
		mx /= m
		my /= m
	p.mx = mx
	p.my = my
	p.moving = m > .1 and p.hurt_t <= 0
	if inp.dash and p.roll_cd <= 0 and p.roll_t <= 0 and not (p.pool_t > 0):
		var dx := mx
		var dy := my
		if m < .1:
			dx = cos(p.face)
			dy = sin(p.face)
		var l := JS.hypot(dx, dy)
		if l == 0: l = 1
		p.roll_dx = dx / l
		p.roll_dy = dy / l
		p.roll_t = ROLL_T
		p.roll_cd = p.st.rollCdMax
		p.seq = null
		p.atk_t = 0
		p.ar_t = 0
		p.ar_cb = null
		if absf(p.roll_dx) > .1:
			p.flip = p.roll_dx < 0
		runes.on_roll(inp.aim, inp.aim_mouse)
	cls.update(dt, inp)
	if p.dk:
		_update_dk(dt)
	_stat_tick(dt)
	arbol.tick(p, dt)
	recalc(p)
	var want_block := p.cls == "knight" and not Items.dos_espadas(p) and inp.block and p.roll_t <= 0 and p.hurt_t <= 0 and not (p.spin_t > 0) and not (p.cast_anim > 0) and not (p.ar_t > 0) and not (p.pool_t > 0)
	if want_block and not p.blocking:
		p.blocking = true
		p.block_t = 0
		p.seq = null
	elif not want_block:
		p.blocking = false
	if p.blocking:
		p.block_t += dt
		p.block_hit_t -= dt
		var ba := p.face
		if inp.aim_mouse:
			ba = atan2(inp.aim.y - (p.y - 14), inp.aim.x - p.x)
		elif m > .1:
			ba = atan2(my, mx)
		p.face = ba
		p.block_q = ((JS.roundi(ba / (PI / 2)) % 4) + 4) % 4
		if p.block_q == 0: p.flip = false
		elif p.block_q == 2: p.flip = true
	if p.roll_t > 0:
		p.roll_t -= dt
		mv(p, p.roll_dx * ROLL_SPD * dt, p.roll_dy * ROLL_SPD * dt)
	elif p.hurt_t <= 0:
		var slow := 1.0
		if p.pool_t > 0: slow = skp("pool", "spd") if p.pool_fast else 1.0
		elif p.spin_t > 0: slow = 1.0 if has("d_whirl_a") else .55
		elif p.blocking: slow = .4
		elif p.seq != null: slow = 0.0   # quieto mientras dura el tajo (decidido por Diego, 8 nov)
		elif p.ar_t > 0: slow = 0.0
		elif p.cast_t > 0: slow = .85
		if en_escalera(p.x, p.y): slow *= ESC_LENTO
		mv(p, mx * p.st.spd * slow * vel_mov * dt, my * p.st.spd * slow * vel_mov * dt)
		if p.moving and p.seq == null and not p.blocking and not (p.cast_t > 0) and not (p.shot_t > 0) and not (p.ar_t > 0):
			if absf(mx) > .1:
				p.flip = mx < 0
			p.face = atan2(my, mx)
	if p.lunge > 0:
		p.lunge -= dt
		if LUNGE:
			mv(p, cos(p.face) * 130 * dt, sin(p.face) * 130 * dt)
	p.hurt_t -= dt; p.roll_cd -= dt; p.atk_t -= dt; p.inv -= dt; p.combo_t -= dt; p.parry_t -= dt
	for s in p.sk:
		s.t = maxf(0, s.t - dt)
		s.cd = maxf(0, s.cd - dt)
	if banner != null:
		banner.t -= dt
		if banner.t <= 0:
			banner = null
	if not runes.chain_hold():
		p.chain_t -= dt
	if p.chain_t <= 0:
		p.chain = 0
	if p.moving: p.walk_t += dt
	else: p.idle_t += dt
	if inp.skill >= 0:
		use_skill(inp.skill)
	if inp.potion:
		drink_potion()
	if inp.interact:
		interact()
	if inp.attack:
		player_attack(inp)
	if inp.attack_held and p.atk_t <= 0:
		player_attack(inp)
	if p.seq != null:
		p.anim += dt
		if not p.hit_done and p.anim >= p.seq.hit * AFT:
			p.hit_done = true
			_do_hit()
		if p.seq != null and p.anim >= p.seq.f.size() * AFT:
			p.seq = null
	# la fuente cura despacio (al Señor Oscuro le quema)
	if p.dl and JS.hypot(p.x - CX, p.y - CY) < FRAD + 16:
		p.heal_t += dt
		if rnd() < dt * 7:
			fx.part({"x": p.x + (rnd() - .5) * 12, "y": p.y, "z": 6, "vx": 0, "vy": 0, "vz": 22, "float": true, "life": .7, "col": "#c0304a" if rnd() < .5 else "#5a0810"})
		if p.heal_t >= .8:
			p.heal_t = 0
			if not (p.pool_t > 0):
				var n := minf(4, p.hp - 1)
				if n > 0:
					p.hp -= n
					fx.text(p.x, p.y - 40, "-" + str(int(n)), "#ff4a5a", 11)
					fx.hud()
	elif JS.hypot(p.x - CX, p.y - CY) < FRAD + 16 and p.hp < p.st.maxHp:
		p.heal_t += dt * p.st.healMul
		if rnd() < dt * 7:
			fx.part({"x": p.x + (rnd() - .5) * 12, "y": p.y, "z": 6, "vx": 0, "vy": 0, "vz": 22, "float": true, "life": .7, "col": "#8fd0ea"})
		if p.heal_t >= .8:
			p.heal_t = 0
			heal(p, 4, "#8fd0ea")
	else:
		p.heal_t = 0
	# no se puede atravesar la fuente: se rodea
	var fdx := p.x - CX
	var fdy := p.y - CY
	var fd := JS.hypot(fdx, fdy)
	var R := FRAD + 4
	if fd < R:
		var nx := fdx / (fd if fd else 1.0)
		var ny := fdy / (fd if fd else 1.0)
		p.x = CX + nx * R
		p.y = CY + ny * R
		if p.moving and not p.dead:
			var ix := -p.mx
			var iy := -p.my
			if ix * nx + iy * ny > .92:
				var s = ((-1.0 if p.flip else 1.0) if absf(ny) > absf(nx) else (1.0 if ny >= 0 else -1.0)) * p.st.spd * dt * .7
				p.x += -ny * s
				p.y += nx * s
	unstick(p)

# ---------------- ataque del héroe ----------------
func aim_at(inp: Inp) -> void:
	if inp.aim_mouse:
		p.face = atan2(inp.aim.y - (p.y - 14), inp.aim.x - p.x)
		return
	var best = null
	var bd: float = p.st.range + 40
	for e in enemies:
		if e.dying:
			continue
		var d := JS.hypot(e.x - p.x, e.y - p.y)
		if d < bd:
			bd = d
			best = e
	if best != null:
		p.face = atan2(best.y - p.y, best.x - p.x)

func player_attack(inp: Inp) -> void:
	if cls.attack():
		return
	if p.atk_t > 0 or p.roll_t > 0 or p.dead or p.hurt_t > 0 or p.blocking or p.spin_t > 0 or p.cast_anim > 0 or p.ar_t > 0 or p.pool_t > 0:
		return
	p.riposte = p.parry_t > 0
	p.rip_target = p.parry_src if p.riposte else null
	p.parry_t = 0
	for pr in projs:
		if pr.phase == "stall" and JS.hypot(pr.x - p.x, pr.y - p.y) < p.st.range + 34:
			pr.pend = true
	var n4 := 4 if has("k_verd_key") else 3   # «Maestro de armas»: combo de 4 tajos
	p.combo_step = (p.combo_step + 1) % n4 if p.combo_t > 0 else 0
	aim_at(inp)
	p.flip = cos(p.face) < 0
	var atk: Array = GameData.get_table("attacks")
	p.seq = atk[p.combo_step]
	p.anim = 0
	p.hit_done = false
	stats.swings += 1
	p.atk_t = p.st.atkCd * (1.35 if p.combo_step >= 2 else 1.0) * COMBO_SPACING
	if p.combo_step == n4 - 1:
		p.atk_t += COMBO_PAUSE
	p.combo_t = p.atk_t + .35
	p.lunge = .05
	fx.sonido([&"tajo1", &"tajo2", &"tajo3", &"tajo1"][p.combo_step], p.x, p.y)

func back_mul(e: Ent.Enemy, ang: float) -> float:
	if cos(e.face - ang) <= .5:
		return 1.0
	if not (e.back_t > t - .35):
		e.back_t = t
		fx.text(e.x, e.y - 54, "espalda", "#ffd25a", 9, false, .7, false, false)
	return 1 + p.st.backstab

func enemy_block(e: Ent.Enemy, fx_: float, fy: float) -> bool:
	if e.act != "guard" or e.rn_no_block > 0:
		return false
	var fa := atan2(fy - e.y, fx_ - e.x) - e.face
	fa = atan2(sin(fa), cos(fa))
	if absf(fa) > 1.5:
		return false
	e.act = "wind"
	e.act_t = e.wind_t * .4
	e.cool = 0
	e.face = atan2(fy - e.y, fx_ - e.x)
	fx.burst(e.x + cos(e.face) * 8, e.y, 18, ["#fffbe8", "#ffd25a", "#c9c5bb"], 8, 90)
	fx.text(e.x, e.y - 52, "bloqueo", "#d8d2c4", 10, false, 1.5, true, false)
	fx.shake(2)
	fx.sonido(&"bloqueo", e.x, e.y)
	return true

## los caballeros legendarios, tras encajar tres golpes seguidos, se cubren con el escudo
func note_hit(e: Ent.Enemy) -> void:
	e.golpe_t = t
	if not e.rare or e.dying:
		return
	if t - e.last_hit > 1.2:
		e.hit_count = 0
	e.last_hit = t
	e.hit_count += 1
	if e.hit_count >= 3:
		e.hit_count = 0
		e.wall = true; e.wall_far = 0; e.wall_t = 0
		e.act = "guard"; e.act_t = .9 + rnd() * .7; e.hurt_t = 0
		e.vx *= .2; e.vy *= .2
		e.face = atan2(p.y - e.y, p.x - e.x)
		fx.text(e.x, e.y - 56, "se cubre", "#d8d2c4", 10, false, 1.5, true, false)

func _do_hit() -> void:
	var A: Dictionary = p.seq
	var hits := 0
	var rip := p.riposte
	p.riposte = false
	_reflect_pending()
	var cx := p.x
	var cy := p.y - 14
	var a3 := p.combo_step == 2   # el tercer tajo (el vertical)
	var carne := 0   # golpes que no paró un escudo
	var verd: bool = a3 and not p.dk and not p.dl and skill_on_id("verdugo")
	var hubo_crit := false
	for e in enemies.duplicate():
		if e.dying:
			continue
		var dx: float = e.x - cx
		var dy: float = (e.y - 14) - cy
		var d := JS.hypot(dx, dy)
		if d > p.st.range + 10 + e.cuerpo:
			continue
		var da := atan2(dy, dx) - p.face
		da = atan2(sin(da), cos(da))
		var abre := atan2(e.cuerpo, maxf(d, 1.0))   # un cuerpo ancho se alcanza con más ángulo
		if absf(da) > (1.6 if a3 and has("k_verd_a") else 1.3) + abre and d > 12 + e.cuerpo:
			continue
		if muro_entre(p.x, p.y - 3, e.x, e.y - 3):   # el tajo no atraviesa muros ni esquinas
			continue
		hits += 1
		e.golpe_t = t
		var rp: bool = rip and e == p.rip_target
		var crit = rp or rnd() < p.st.crit
		var blk := false if rp else enemy_block(e, p.x, p.y)
		var bk := back_mul(e, atan2(e.y - p.y, e.x - p.x))
		if rp:
			fx.text(e.x, e.y - 62, "CRÍTICO", "#ff2a1a", 14, true, 1.5, true, false)
		var dmg := JS.roundi(bk * p.st.dmg * A.mult * (skp("verdugo", "a3Mult") if verd else 1.0) * (.85 + rnd() * .3) * (p.st.critMult if crit else 1.0) * (.15 if blk else 1.0))
		if e.boss != "" and (e.boss_air or e.boss_shield):
			continue
		if a3 and has("k_verd_b") and (e.hp - dmg) / e.max_hp < .15:   # «Ejecución»
			dmg = dmg * 3 if e.type == "champ" else maxi(dmg, ceili(e.hp))
		dmg = int(dmg_mod(e, dmg))
		dmg = runes.hit(e, dmg, "melee", crit)
		if blk:
			dmg = maxi(1, dmg)
		if verd and runes.rv("verdBleed"):
			runes.bleed(e, maxf(1, JS.round(p.st.dmg * .3)), 4)
		e.hp -= dmg
		p.dmg_dealt += dmg
		e.flash = .07
		leech(dmg)
		if dmg > 0:
			fx.text(e.x, e.y - 40, (str(dmg) + "!") if crit else str(dmg), COL_CRIT if crit else COL_GOLPE, 18 if crit else 11, crit)
		if crit:
			hubo_crit = true
		if not e.armor and not blk:
			_interrumpe(e, .16)
		if rp and p.st.parryStun > 0:
			e.hurt_t = maxf(e.hurt_t, p.st.parryStun)
			e.act = ""
			e.cool = maxf(e.cool, p.st.parryStun)
		if not blk:
			note_hit(e)
			carne += 1
		var kb: float = (25.0 if e.armor else 100.0) * A.kb * p.st.kb / (3.0 if e.rare else 1.0) * (.15 if blk else 1.0) * EMPUJE
		e.vx += cos(p.face) * kb
		e.vy += sin(p.face) * kb
		_herida(e, p.face, 46 if crit else 26, 150)
		_herida(e, p.face + PI, 12 if crit else 6, 50, 1.4, 14)
		if herir_de(e) == "sangre":
			for i in (18 if crit else 9):
				fx.stain(e.x + (rnd() - .5) * 18, e.y + (rnd() - .5) * 5, BLOOD[i % 4], 2 if rnd() < .5 else 1)
		if e.hp <= 0:
			kill_enemy(e, p.face)
	_romper_golpe(cx, cy)
	if hits:
		stats.hits += hits
		p.chain += hits
		p.chain_t = 1.3 + p.st.chainT
		p.best_chain = maxi(p.best_chain, p.chain)
		hitstop = maxf(hitstop, .04)
		fx.shake(3)
		fx.hud()
		if hubo_crit:
			fx.sonido(&"critico", p.x + cos(p.face) * 20, p.y + sin(p.face) * 20)
		elif carne > 0:
			fx.sonido(&"impacto", p.x + cos(p.face) * 20, p.y + sin(p.face) * 20)

## daño de las habilidades del Caballero de la Muerte y de sus muertos alzados
func dk_damage(e: Ent.Enemy, dmg: float, ang: float, small: bool, col: String = "#b07aff") -> void:
	if e.dying:
		return
	dmg = dmg_mod(e, JS.round(dmg))
	if dmg <= 0:
		return
	dmg = runes.hit(e, dmg, "dot" if small else "hit", false)
	e.hp -= dmg
	p.dmg_dealt += int(dmg)
	e.flash = .06
	fx.text(e.x, e.y - 40, str(int(dmg)), col, 9 if small else 11)
	if not e.armor and not small:
		_interrumpe(e, .14)
	var k: float = (10.0 if small else 45.0) * p.st.kb / (3.0 if e.rare else 1.0) * EMPUJE
	e.vx += cos(ang) * k
	e.vy += sin(ang) * k
	_herida(e, ang, 8 if small else 20, 110)
	if e.state == "idle":
		wake(e)
	if e.hp <= 0:
		kill_enemy(e, ang)

func kill_enemy(e: Ent.Enemy, ang: float) -> void:
	if e.dying:
		return
	if e.pool_t > 0:   # en su charco de sangre no se le puede matar
		e.hp = maxf(1, e.pool_hp)
		return
	if e.hero == "dk":
		for o in enemies:
			if o.master == e and not o.dying and o != e:
				fx.burst(o.x, o.y, 10, ["#9a4dff", "#5a2a90", "#d0b0ff"], 14, 70)
				kill_enemy(o, atan2(o.y - e.y, o.x - e.x))
	arbol.on_kill(e)
	runes.on_kill(e)
	var champ := e.type == "champ"
	if champ and wave % 5 == 0:
		p.skp += 1
		fx.text(p.x, p.y - 70, "+1 punto de habilidad", "#b89bff", 12, true, 2, true, false)
	e.dying = mon_def(e).dieT if e.mon != "" else .25
	apr.terminar(self, e, false)
	fx.sonido(&"muerte_enemigo", e.x, e.y)
	e.die_a = ang
	e.flash = .06
	e.hp = 0
	# cae justo donde muere: sin empujón (decidido por Diego)
	e.vx = 0
	e.vy = 0
	var mult := 1 + mini(4, int(floorf(p.chain / 5.0)))
	kills += 1
	var kk: Dictionary = stats.get("kills", {})
	kk[kill_kind(e)] = int(kk.get(kill_kind(e), 0)) + 1
	stats["kills"] = kk
	score += e.score * mult
	_herida(e, ang, 70 + (40 if champ else 0), 200, .6)
	_herida(e, ang + PI, 22, 70, 1.4)
	_herida(e, -PI / 2, 20, 90, 1.6, 22)
	_muere_poder(e)
	hitstop = maxf(hitstop, .15 if champ else .06)
	fx.shake((10 if champ else 5) * Ritmo.VIBRA_MATAR)
	fx.text(e.x, e.y - 52, "+%d pts" % (e.score * mult), "#ffd25a" if mult > 1 else "#e8a33a", 9)
	var tag := ""
	if e.rare or champ:
		if p.hp < p.st.maxHp * .1:
			e.xp = ELITE_XP.edge
			tag = "¡Al borde de la muerte!"
		elif e.dealt >= p.st.maxHp * .5:
			e.xp = ELITE_XP.bloody
			tag = "¡Duelo sangriento!"
		else:
			e.xp = ELITE_XP.base
		e.xp = JS.roundi(e.xp * (1 + (wave - 1) * .1))
	if p.lvl < MAXLVL:
		var big := e.xp >= 200
		fx.text(e.x, e.y - 64, "+%d EXP" % e.xp, "#b89bff", 15 if big else 11, big, 1.8 if big else 1.1, false, false)
		if e.rare or champ:
			fx.text(e.x, e.y - 96, e.title + " ha caído", "#ffd25a" if e.rare else "#ff9a3a", 10, false, 1.8, false, false)
		if tag != "":
			fx.text(e.x, e.y - 80, tag, "#ffd25a", 10, false, 1.8, false, false)
	gain_xp(e.xp)
	for pr in projs:
		if pr.owner == e:
			pr.phase = "drop"
	# objetos y runas, oro, llaves y pociones
	if e.hero == "minion":
		fx.hud()
		return
	roll_drops(e)
	var w := wave
	if e.rare or champ:
		drop_gold(e.x, e.y, (20 + rnd() * 25) * (1 + w * .12) * (2 if champ else 1), true)
	elif rnd() < BOTIN.oro:
		drop_gold(e.x, e.y, (3 + rnd() * 7) * (1 + w * .12), true)
	if (e.type == "slayer" or e.type == "sargwen" or e.rare) and rnd() < (.5 if e.rare else .1) * p.st.keyMul:
		floor_keys.append({"x": e.x + (rnd() - .5) * 16, "y": e.y + 8, "bob": rnd() * 6})
	var chance := 1.0 if champ else (BOTIN.pocion_elite if e.rare else (BOTIN.pocion_lanza if e.thrower else BOTIN.pocion))
	if rnd() < chance:
		pickups.append({"x": e.x, "y": e.y, "t": BOTIN.pocion_dura, "bob": rnd() * 6, "no_pick": 0.0})
	fx.hud()

func drop_gold(x: float, y: float, amt: float, manual: bool) -> void:
	if amt <= 0:
		return
	var gx := x + (rnd() - .5) * 20
	var gy := y + 10 + rnd() * 10
	if not fits(gx, gy, 7):
		gx = x
		gy = y + 12
		if not fits(gx, gy, 7):
			gx = p.x
			gy = p.y + 2
	gold.append({"x": gx, "y": gy, "amt": JS.roundi(amt), "bob": rnd() * 6, "manual": manual})

# ---------------- daño al héroe ----------------
## enemigo básico: ni élite, ni jefe, ni campeón, ni demonio u otro monstruo con ficha (los esqueletos sí son básicos)
func _basico(src) -> bool:
	if not (src is Ent.Enemy):
		return false
	var e: Ent.Enemy = src
	return not e.rare and not e.elite and not e.jefe and e.boss == "" and e.type != "champ" and (e.mon == "" or e.mon == "esqueleto")

func hurt_player(dmg: float, from_x: float, from_y: float, src, kind: String = "") -> String:
	if p.inv > 0 or p.roll_t > 0 or p.dead or p.pool_t > 0:
		return ""
	# un golpe cuerpo a cuerpo no pasa a través de un muro (ni de una esquina)
	if kind == "" and src is Ent.Enemy and muro_entre(from_x, from_y - 3, p.x, p.y - 3):
		return ""
	# esquiva, resistencias, armadura, bloqueo sin escudo y efectos de las runas
	dmg = runes.hurt(dmg, src, kind, from_x, from_y)
	if not (dmg > 0):
		fx.hud()
		return ""
	dmg = maxf(1, JS.round(dmg * (1 - p.st.armor)))
	if p.shield > 0:
		var ab := minf(p.shield, dmg)
		p.shield -= ab
		dmg -= ab
		if dmg <= 0:
			fx.text(p.x, p.y - 40, "absorbido", "#d07aff", 9)
			fx.hud()
			return ""
	var to_a := atan2(from_y - p.y, from_x - p.x)
	var from_q := ((JS.roundi(to_a / (PI / 2)) % 4) + 4) % 4
	if p.blocking and from_q == p.block_q:
		var red := 0.0 if runes.rv("wall") else maxf(1, JS.round(dmg * block_pass()))
		if has("k_valor_b") and skill_on_id("valor"):
			heal(p, p.st.maxHp * .03, "#ff8a7a")
		if src != null:
			src.dealt += minf(red, p.hp)
		p.hp = maxf(0, p.hp - red)
		p.block_hit_t = .18
		fx.shake(2 * Ritmo.VIBRA_DANO)
		var a := atan2(p.y - from_y, p.x - from_x)
		mv(p, cos(a) * 4, sin(a) * 4)
		fx.burst(p.x - cos(a) * 6, p.y, 18, ["#fffbe8", "#ffd25a", "#f08a24"], 8, 90)
		fx.text(p.x, p.y - 40, "-" + str(int(red)), "#c9c5bb", 11)
		fx.text(p.x, p.y - 52, "bloqueado", "#8fd0ea", 8)
		fx.sonido(&"bloqueo", p.x, p.y)
		fx.hud()
		arbol.last_stand(p)
		runes.lethal()
		if p.hp <= 0:
			p.dead = true
			p.death_t = 0
			p.blocking = false
			p.flip = cos(a) < 0
			apr.heroe_muere(self, src)
		p.parry_t = p.st.parryWin
		p.parry_src = src
		runes.on_block(src, dmg)
		return "block"
	if src != null:
		src.dealt += minf(dmg, p.hp)
	p.hp = maxf(0, p.hp - dmg)
	p.hurt_t = .18
	# el golpe recibido no corta el tajo ni congela el juego (decidido por Diego, 8 nov)
	p.chain = 0
	fx.shake(6 * Ritmo.VIBRA_DANO)
	var a := atan2(p.y - from_y, p.x - from_x)
	# los enemigos básicos no te mueven; élites, jefes y demonios siguen empujando un poco
	if not _basico(src):
		mv(p, cos(a) * 8, sin(a) * 8)
	fx.bleed(p.x, p.y, 16, a, 24, 120)
	fx.text(p.x, p.y - 40, "-" + str(int(dmg)), COL_RECIBIDO, 14)
	fx.sonido(&"herido", p.x, p.y)
	fx.hud()
	arbol.last_stand(p)
	runes.lethal()
	if p.hp <= 0:
		p.dead = true
		p.death_t = 0
		p.flip = cos(a) < 0
		apr.heroe_muere(self, src)
	return "hit"

func _count_stats(dt: float) -> void:
	for k in ["t", "dist", "deaths"]:
		if not stats.has(k):
			stats[k] = 0.0 if k != "deaths" else 0
	if not stats.has("waves"): stats["waves"] = {}
	if not stats.has("kills"): stats["kills"] = {}
	stats.t += dt
	var wk := str(wave)
	stats.waves[wk] = float(stats.waves.get(wk, 0.0)) + dt
	var pos := Vector2(p.x, p.y)
	if _last_pos.x != INF:
		var dd := pos.distance_to(_last_pos)
		if dd < 40:
			stats.dist += dd
	_last_pos = pos

## parte del daño que pasa al bloquear: quieto 10 %, moviéndote 50 %, avanzando 75 %
func block_pass() -> float:
	if not p.moving:
		return p.st.blockRed
	var df := atan2(p.my, p.mx) - p.face
	df = atan2(sin(df), cos(df))
	return maxf(p.st.blockRed, BLOCK_PASS.fwd if absf(df) < .8 else BLOCK_PASS.move)

## ¿el héroe tiene el escudo levantado hacia este enemigo?
func shield_up(e: Ent.Enemy) -> bool:
	if not p.blocking:
		return false
	var a := atan2(e.y - p.y, e.x - p.x)
	var q := ((JS.roundi(a / (PI / 2)) % 4) + 4) % 4
	return q == p.block_q

# ---------------- habilidades (las de cada clase, en clases.gd) ----------------
func use_skill(i: int) -> void:
	if i < 0 or i >= p.skills.size() or p.pool_t > 0:   # en forma de charco solo se mueve
		return
	var s: Dictionary = p.sk[i]
	var id: String = p.skills[i]
	if not p.dead and id == "raise" and allies.size():
		_command_allies()
		return
	if p.dead or s.cd > 0:
		return
	var def: Dictionary = SK[id]
	if id == "blink":
		cls.use_skill(id, s)
		runes.on_skill(s)
		fx.hud()
		return
	if id == "raise" and not _raise_dead():
		return
	cls.use_skill(id, s)
	s.t = skp(id, "dur") * p.st.skillDur
	s.cd = skp(id, "cd") * (1 - p.st.cdr)
	if id == "drain":
		p.drain_tick = 0
		if has("d_drain_b"):
			var inp := cur_inp
			p.drain_x = inp.aim.x if inp != null and inp.aim_mouse else p.x + cos(p.face) * 60
			p.drain_y = inp.aim.y if inp != null and inp.aim_mouse else p.y + sin(p.face) * 60
		fx.burst(p.x, p.y, 16, ["#8a1030", "#c0304a", "#9a4dff"], 26, 110)
		fx.shake(2)
	if id == "whirl":
		p.spin_t = SK.whirl.dur
		p.spin_hits = 0
		p.seq = null
		p.blocking = false
		stats.swings += 1
	runes.on_skill(s)
	var col := "#ff5a46" if id == "valor" else ("#ffd25a" if id == "banner" else ("#ffb060" if p.cls == "mage" else ("#9ad87a" if p.cls == "archer" else ("#c070ff" if p.dl else ("#c48cff" if p.dk else "#bfe6ff")))))
	fx.text(p.x, p.y - 54, def.n + "!", col, 12, true)
	fx.hud()

func _raise_dead() -> bool:
	var cs := []
	for c in corpses:
		if JS.hypot(c.x - p.x, c.y - p.y) < skp("raise", "r"):
			cs.append(c)
	cs = JS.stable_sort(cs, func(a, b): return JS.hypot(a.x - p.x, a.y - p.y) - JS.hypot(b.x - p.x, b.y - p.y))
	cs = cs.slice(0, JS.roundi(skp("raise", "count")))
	if not cs.size():
		fx.text(p.x, p.y - 54, "No hay cadáveres cerca", "#b78cff", 10)
		return false
	p.cast_anim = .6
	p.seq = null
	for c in cs:
		corpses.erase(c)
		fx.corpse_raised(c)
		fx.pool(c.x, c.y - 3, 9)
		var a := Ent.Ally.new()
		a.x = c.x; a.y = c.y; a.face = c.face
		a.t = skp("raise", "dur") * p.st.skillDur; a.max_t = a.t
		a.seed = rnd() * 9
		allies.append(a)
		fx.burst(c.x, c.y - 10, 10, ["#e6d0ff", "#9a4dff", "#3a1660"], 26, 110)
		for k in 14:
			fx.part({"x": c.x + (rnd() - .5) * 26, "y": c.y + (rnd() - .5) * 8, "z": 2, "vx": 0, "vy": 0, "vz": 30 + rnd() * 30, "float": true, "life": .8, "col": "#9a4dff" if rnd() < .5 else "#2a1040"})
	fx.shake(3)
	return true

var ally_goal = null
func _command_allies() -> void:
	var tx: float
	var ty: float
	# hacia el enemigo más cercano o, si no hay, hacia delante (la vista pone el cursor con set_ally_target)
	if ally_target != null:
		tx = ally_target.x
		ty = ally_target.y
	else:
		var best = null
		var bd := 260.0
		for e in enemies:
			if e.dying:
				continue
			var d := JS.hypot(e.x - p.x, e.y - p.y)
			if d < bd:
				bd = d
				best = e
		if best != null:
			tx = best.x; ty = best.y
		else:
			tx = p.x + cos(p.face) * 120; ty = p.y + sin(p.face) * 120
	ally_goal = {"x": tx, "y": ty, "t": 1.2}
	var n := allies.size()
	for k in n:
		var an := k / float(n) * 6.283
		allies[k].goal = {"x": tx + cos(an) * (14.0 if n > 1 else 0.0), "y": ty + sin(an) * 8 * (1.0 if n > 1 else 0.0)}
		allies[k].arrived = false
	fx.text(p.x, p.y - 54, "¡Id!", "#c48cff", 11, true)
	fx.burst(tx, ty, 4, ["#9a4dff", "#e6d0ff"], 14, 70)

var ally_target = null   # punto del ratón para mandar a los muertos (lo pone la entrada)

func _update_dk(dt: float) -> void:
	p.cast_anim -= dt
	var pw := 1.0 if skill_on_id("drain") else (.5 if has("d_drain_key") else 0.0)   # «Sed eterna»: siempre activa a la mitad
	if pw > 0 and not p.dead:
		var R: float = skp("drain", "r")
		var c := drain_c()
		p.drain_tick -= dt
		if p.drain_tick <= 0:
			p.drain_tick = .5
			for e in enemies.duplicate():
				if e.dying or e.state == "idle":
					continue
				var d := JS.hypot(e.x - c.x, e.y - c.y)
				if d > R:
					continue
				var dmg := maxf(1, JS.round(p.st.dmg * skp("drain", "tick") * pw))
				dk_damage(e, dmg, atan2(e.y - c.y, e.x - c.x), true, "#c0304a")
				leech(dmg)
				for k in 5:
					fx.part({"x": e.x, "y": e.y, "z": 14, "vx": (p.x - e.x) * 2.2, "vy": (p.y - e.y) * 2.2, "vz": 6, "float": true, "life": .45, "col": "#c0304a" if k % 2 else "#9a4dff"})
		if rnd() < dt * 24 * pw:
			var a := rnd() * 6.283
			var r := R * (.5 + rnd() * .5)
			fx.part({"x": c.x + cos(a) * r, "y": c.y + sin(a) * r * .6, "z": 3, "vx": -cos(a) * r * 1.4, "vy": -sin(a) * r * .8, "vz": 10, "float": true, "life": .5, "col": "#8a1030" if rnd() < .5 else "#9a4dff"})
	if p.spin_t > 0:
		p.spin_t -= dt
		p.seq = null
		p.blocking = false
		var el: float = SK.whirl.dur - p.spin_t
		var due := [.18, .42, .66, .9] if has("d_whirl_t4") else [.22, .55, .88]
		var SR: float = skp("whirl", "r")
		while p.spin_hits < due.size() and el >= due[p.spin_hits]:
			p.spin_hits += 1
			fx.shake(3)
			for e in enemies.duplicate():
				if e.dying:
					continue
				var d := JS.hypot(e.x - p.x, e.y - p.y)
				if d > SR + e.cuerpo:
					continue
				var ang := atan2(e.y - p.y, e.x - p.x)
				var crit = rnd() < p.st.crit
				var dmg := maxi(1, JS.roundi(dmg_mod(e, back_mul(e, ang) * p.st.dmg * skp("whirl", "mult") * (.85 + rnd() * .3) * (p.st.critMult if crit else 1.0))))
				dmg = runes.hit(e, dmg, "melee", crit)
				stats.hits += 1
				e.hp -= dmg
				p.dmg_dealt += dmg
				e.flash = .07
				fx.text(e.x, e.y - 40, (str(dmg) + "!") if crit else str(dmg), COL_CRIT if crit else COL_GOLPE, 18 if crit else 11, crit)
				if not e.armor:
					_interrumpe(e, .16)
				var k: float = (-110.0 if has("d_whirl_b") else 75 * p.st.kb / (3.0 if e.rare else 1.0)) * EMPUJE
				e.vx += cos(ang) * k
				e.vy += sin(ang) * k
				if has("d_whirl_key"):   # «Danza macabra»
					var ri := p.skills.find("raise")
					if ri >= 0:
						p.sk[ri].cd = maxf(0, p.sk[ri].cd - 1)
				fx.bleed(e.x, e.y, 16, ang, 40 if crit else 22, 140)
				leech(dmg)
				if e.state == "idle":
					wake(e)
				if e.hp <= 0:
					kill_enemy(e, ang)
			for k in 18:
				var a := k / 18.0 * 6.283
				fx.part({"x": p.x + cos(a) * SR * .7, "y": p.y + sin(a) * SR * .45, "z": 10, "vx": -sin(a) * 140, "vy": cos(a) * 80, "vz": 10, "float": true, "life": .3, "col": "#b07aff" if k % 2 else "#e6d0ff"})

func _update_allies(dt: float) -> void:
	for a in allies:
		a.t -= dt
		if a.rise > 0:
			a.rise -= dt
			continue
		if a.t <= 0 or p.dead:
			a.dead = true
			if a.t <= 0:
				arbol.ally_expire(a)
			fx.burst(a.x, a.y - 14, 14, ["#b78cff", "#5a2a8a", "#2a1040"], 20, 80)
			continue
		a.cool -= dt
		if a.goal != null and not a.arrived and JS.hypot(a.goal.x - a.x, a.goal.y - a.y) < 14:
			a.arrived = true
		var tg = null
		var bd := 60.0 if (a.goal != null and not a.arrived) else 230.0
		for e in enemies:
			if e.dying:
				continue
			var d := JS.hypot(e.x - a.x, e.y - a.y)
			if d < bd:
				bd = d
				tg = e
		if tg != null and bd > 40:
			a.los_t -= dt
			if a.los_t <= 0:
				a.los_t = .25
				a.los = has_los(a.x, a.y - 10, tg.x, tg.y - 10)
			if not a.los:
				tg = null
		a.moving = false
		if a.act != "":
			a.act_t -= dt
			if not a.hit_done and a.act_t < .2:
				a.hit_done = true
				if tg != null and bd < 34:
					var ang := atan2(tg.y - a.y, tg.x - a.x)
					dk_damage(tg, maxf(1, JS.round(p.st.dmg * skp("raise", "allyDmg") * (.85 + rnd() * .3))), ang, false, "#c9a6ff")
					arbol.ally_hit(a, tg)
			if a.act_t <= 0:
				a.act = ""
			continue
		if tg != null and bd < 26 and a.cool <= 0:
			a.act = "a1"
			a.act_t = .45
			a.hit_done = false
			a.cool = .85 + rnd() * .3
			a.face = atan2(tg.y - a.y, tg.x - a.x)
			continue
		var tx: float
		var ty: float
		var stop := 22.0
		if tg != null:
			tx = tg.x; ty = tg.y
		elif a.goal != null:
			tx = a.goal.x; ty = a.goal.y
			stop = 14.0 if a.arrived else 6.0
		else:
			tx = p.x; ty = p.y
			stop = 46.0
		var dx = tx - a.x
		var dy = ty - a.y
		var d := JS.hypot(dx, dy)
		if d == 0: d = 1
		if tg == null and a.goal == null and d > 420:
			a.x = p.x + (rnd() - .5) * 30
			a.y = p.y + 14
			unstick(a)
			continue
		if d > stop:
			var vx = dx / d
			var vy = dy / d
			for o in allies:
				if o == a:
					continue
				var sx: float = a.x - o.x
				var sy: float = a.y - o.y
				var sd := JS.hypot(sx, sy)
				if sd > 0 and sd < 16:
					vx += sx / sd * .8
					vy += sy / sd * .8
			var l := JS.hypot(vx, vy)
			if l == 0: l = 1
			mv(a, vx / l * 92 * dt, vy / l * 92 * dt)
			a.moving = true
			a.walk_t += dt
			a.face = atan2(vy, vx)
		else:
			a.idle_t += dt
			if tg != null:
				a.face = atan2(dy, dx)
			var sx := 0.0
			var sy := 0.0
			for o in allies:
				if o == a:
					continue
				var ox: float = a.x - o.x
				var oy: float = a.y - o.y
				var od := JS.hypot(ox, oy)
				if od < 18:
					sx += ox / od if od > 0 else rnd() - .5
					sy += oy / od if od > 0 else rnd() - .5
			if sx or sy:
				mv(a, sx * 40 * dt, sy * 40 * dt)
	var keep := []
	for a in allies:
		if not a.dead:
			keep.append(a)
	allies = keep

# ---------------- enemigos ----------------
func wake(e: Ent.Enemy) -> void:
	if e.state != "idle":
		return
	e.state = "chase"
	e.cool = .25 + rnd() * .3
	e.wake_t = 0
	e.burst_t = .5
	if e.jefe:
		fx.banner("El jefe del piso despierta", e.title)
		fx.sonido(&"jefe", e.x, e.y)
	elif e.type == "champ":
		fx.banner("Un campeón te cierra el paso", e.title)
	elif e.rare and e.poder != "":
		fx.banner("¡Élite! · " + PODER_N[e.poder], e.title)
		fx.sonido(&"elite", e.x, e.y)
	elif e.rare:
		fx.banner(("¡Cuidado! Un %s legendario" % HH_TITLE[e.hero]) if e.hero != "" else "¡Cuidado! Un caballero legendario", e.title)
	for o in enemies:
		if o != e and o.state == "idle" and not o.ambush and not o.dying and not (o.wake_t > 0) and JS.hypot(o.x - e.x, o.y - e.y) < 140:
			o.wake_t = .15 + rnd() * .35
	apr.empezar(self, e)

func _update_enemies(dt: float) -> void:
	for e in enemies:
		e.flash -= dt
		e.ghost = maxf(e.hp, e.ghost - e.max_hp * 1.1 * dt)
		if _caida_enemigo(e, dt):
			continue
		if e.dying:
			e.dying -= dt   # se queda donde cae: sin desplazarse mientras muere
			e.vx = 0
			e.vy = 0
			if rnd() < .7:
				fx.bleed(e.x, e.y, 10, e.die_a + PI, 1, 25, 1.5)
			if e.dying <= 0:
				if not e.no_corpse:
					_stamp_corpse(e)
				e.dead = true
			continue
		if e.frozen > 0:
			e.frozen -= dt
			if e.frozen <= 0 and e.contagion:
				arbol.contagion(e)
			mv(e, e.vx * dt, e.vy * dt)
			e.vx *= pow(.002, dt)
			e.vy *= pow(.002, dt)
			if rnd() < dt * 4:
				fx.part({"x": e.x + (rnd() - .5) * 14, "y": e.y, "z": 4 + rnd() * 24, "vx": 0, "vy": 0, "vz": 10, "float": true, "life": .5, "col": "#ffc070" if rnd() < .5 else "#ff6a10"})
			continue
		_blood_trail(e, e.hp / e.max_hp, dt)
		var dx = p.x - e.x
		var dy = p.y - e.y
		var d := JS.hypot(dx, dy)
		if d == 0: d = 1
		e.los_t -= dt
		if e.los_t <= 0:
			e.los_t = .12 + rnd() * .1
			e.los = d < 380 and has_los(e.x, e.y - 10, p.x, p.y - 10)
			e.clear = e.los and clear_path(e.x, e.y, p.x, p.y)
		if e.state == "idle":
			if e.vx or e.vy:
				mv(e, e.vx * dt, e.vy * dt)
				e.vx *= pow(.002, dt)
				e.vy *= pow(.002, dt)
				if absf(e.vx) + absf(e.vy) < 1:
					e.vx = 0
					e.vy = 0
			if e.wake_t > 0:
				e.wake_t -= dt
				if e.wake_t <= 0:
					wake(e)
			elif not p.dead and phase == "fight" and ((d < 64 or e.hp < e.max_hp) if e.ambush else ((d < VISTA_PX * runes.see() and e.los) or d < OIDO_PX * runes.see() or e.hp < e.max_hp)):
				wake(e)
			if e.state == "idle":
				e.moving = false
				e.idle_t -= dt
				if e.idle_t <= 0:
					e.idle_t = 2 + rnd() * 3
					e.face = rnd() * 6.283
				continue
		if e.wall:
			e.wall_t += dt
			if d > e.reach + 45:
				e.wall_far += dt
			else:
				e.wall_far = 0
			if e.wall_far > .5 or e.wall_t > 7:
				e.wall = false
				if e.act == "guard" or e.act == "repo":
					e.act = ""
		if e.flee_t > 0:   # «Grito de guerra»
			e.flee_t -= dt
			e.act = ""
			mv(e, -dx / d * e.spd * vel_mov * dt, -dy / d * e.spd * vel_mov * dt)
			e.moving = true
			e.walk_t += dt
			e.face = atan2(-dy, -dx)
			continue
		if e.hero != "" and _hh_ai(e, dt, dx, dy, d):
			continue
		if e.boss != "" and _boss_ai(e, dt, dx, dy, d):
			continue
		if e.mon != "" and _mon_skill_ai(e, dt, d):
			continue
		if e.type == "champ" and _champ_ai(e, dt, dx, dy, d):
			continue
		var vx := 0.0
		var vy := 0.0
		e.moving = false
		e.throw_cd -= dt
		e.catch_t -= dt
		if e.burst_t > 0:
			e.burst_t -= dt
		e.guard_cd -= dt
		if e.flank_cd > 0:
			e.flank_cd -= dt
		if e.hurt_t > 0:
			e.hurt_t -= dt
		elif e.act == "guard":
			e.act_t -= dt
			e.face = atan2(dy, dx)
			if e.act_t <= 0:
				if e.wall:
					e.act = "repo"
					e.act_t = .55 + rnd() * .4
					e.repo_dir = 1.0 if rnd() < .5 else -1.0
				else:
					e.act = ""
					e.cool = minf(e.cool, .2)
		elif e.act == "repo":
			# acorralado: rodea al héroe y vuelve a cubrirse
			e.act_t -= dt
			var R = e.reach + 14
			var rk := maxf(-1, minf(1, (d - R) / 30))
			var mx2 = -dy / d * e.repo_dir + dx / d * rk
			var my2 = dx / d * e.repo_dir + dy / d * rk
			var ml := JS.hypot(mx2, my2)
			if ml == 0: ml = 1
			mv(e, mx2 / ml * e.spd * runes.e_slow(e) * 1.15 * dt, my2 / ml * e.spd * runes.e_slow(e) * 1.15 * dt)
			e.moving = true
			e.walk_t += dt
			e.face = atan2(dy, dx)
			if e.act_t <= 0:
				e.act = "guard"
				e.act_t = .9 + rnd() * .7
		elif e.act == "dodge":
			e.act_t -= dt
			if e.act_t <= 0:
				e.act = ""
				e.cool = 0
		elif e.act == "wind":
			e.act_t -= dt
			if e.act_t <= 0:
				e.act = "strike"
				e.act_t = .24 / e.am
				e.hit_done = false
				e.flip = dx < 0
				e.face = atan2(dy, dx)
				if e.type != "knight":
					var lg := 160 + maxf(0, d - e.reach) * 7
					e.vx += dx / d * lg
					e.vy += dy / d * lg
		elif e.act == "strike":
			e.act_t -= dt
			if not e.hit_done and e.act_t < .15 / e.am:
				e.hit_done = true
				var amb = e.ambush_hit
				e.ambush_hit = false
				if JS.hypot(p.x - e.x, p.y - e.y) < e.reach + 9:
					hurt_player(e.dmg * (2 if amb else 1), e.x, e.y, e)
					if amb:
						fx.text(p.x, p.y - 60, "CRÍTICO", "#ff2a1a", 14, true, 1.5, true, false)
			if e.act_t <= 0:
				e.act = ""
				e.cool = (.45 + rnd() * .5) / e.am
				if e.type == "knight":
					e.combo = (e.combo + 1) % 3
				if e.wall:
					e.act = "guard"
					e.act_t = .9 + rnd() * .7
		elif e.act == "throw":
			e.act_t -= dt
			if e.act_t <= 0:
				e.act = ""
				e.has_sword = false
				e.cool = .3 / e.am
				projs.append({"x": e.x, "y": e.y, "tx": p.x, "ty": p.y, "owner": e, "phase": "out", "t": 0.0, "hit": false, "dmg": e.dmg,
					"stall_t": 0.0, "pend": false, "svx": 0.0, "svy": 0.0})
		elif not p.dead:
			e.cool -= dt
			# leer el ataque del héroe: bloquear con el escudo o apartarse rodando
			var threat: bool = (p.seq != null and not p.hit_done and d < p.st.range + 30) or cls.threat(e)
			var reacted := false
			if threat and e.guard_cd <= 0 and e.los:
				e.guard_cd = 1 + rnd() * .9
				var ch := .6 if e.type == "champ" else (.55 if e.rare else (.45 if e.type == "knight" else (.4 if e.type == "slayer" else .3)))
				if rnd() < ch:
					reacted = true
					if e.type == "slayer" or e.type == "sargwen" or (e.mon_dodge > 0 and rnd() < e.mon_dodge):
						var s := 1.0 if rnd() < .5 else -1.0
						var ax = -dy / d * s
						var ay = dx / d * s
						e.act = "dodge"
						e.act_t = .28
						e.dodge_a = atan2(ay, ax)
						e.vx += ax * 230 - dx / d * 60
						e.vy += ay * 230 - dy / d * 60
					else:
						e.act = "guard"
						e.act_t = .6
						e.face = atan2(dy, dx)
			# el degollador no ataca contra el escudo: rueda hacia un costado y entra por otro lado
			if not reacted and e.type == "slayer" and shield_up(e) and d < e.reach + 50 and not (e.flank_cd > 0):
				reacted = true
				e.flank_cd = 1.4
				var s := 1.0 if rnd() < .5 else -1.0
				var ax = -dy / d * s
				var ay = dx / d * s
				e.act = "dodge"
				e.act_t = .3
				e.dodge_a = atan2(ay + dy / d * .4, ax + dx / d * .4)
				e.vx += ax * 260 + dx / d * 90
				e.vy += ay * 260 + dy / d * 90
			# táctica aprendida: a dónde ir (o null: a por ti y a golpear)
			var tg = apr.objetivo(self, e, d) if e.apr_activo and e.clear else null
			if reacted:
				pass
			elif e.thrower and e.has_sword and e.los and d > 60 and d < 190 and e.throw_cd <= 0:
				e.act = "throw"
				e.act_t = .22 / e.am
				e.flip = dx < 0
				e.face = atan2(dy, dx)
				e.throw_cd = (2.4 + rnd() * 1.2) / e.am
			elif tg == null and d < (e.reach if e.type == "knight" else e.reach + 24) and e.cool <= 0 and e.has_sword and e.type != "champ":
				e.act = "wind"
				e.act_t = e.wind_t
				e.face = atan2(dy, dx)
				e.apr_ult = t
			else:
				var want := 1.0
				if e.thrower:
					if not e.has_sword:
						want = -1.0 if d < 100 else 0.0
					else:
						want = 1.0 if d > 120 else (0.0 if d < e.reach + 4 else (-.6 if d < 70 else .4))
				elif d < e.reach - 4:
					want = 0
				var nx = dx / d
				var ny = dy / d
				if not e.clear and d > e.reach:
					var nd = nav_dir(e)
					if nd != null:
						nx = nd.x
						ny = nd.y
						if want <= 0:
							want = 1
					else:
						want = 0
				if tg != null:
					var g: Vector2 = tg - Vector2(e.x, e.y)
					if g.length() < 6:
						want = 0
					else:
						nx = g.x / g.length()
						ny = g.y / g.length()
						want = 1
				if want != 0:
					vx = nx * want
					vy = ny * want
				if e.thrower and d > e.reach and e.clear:
					vx = -dy / d * .5 * e.tang
					vy = dx / d * .5 * e.tang
				var ffx = e.x - CX
				var ffy = e.y - CY
				var ffd := JS.hypot(ffx, ffy)
				if ffd == 0: ffd = 1
				if ffd < FRAD + 26 and (vx or vy):
					var push := (FRAD + 26 - ffd) / 26
					vx += ffx / ffd * push * .8 - ffy / ffd * e.tang * push * 1.4
					vy += ffy / ffd * push * .8 + ffx / ffd * e.tang * push * 1.4
				var l := JS.hypot(vx, vy)
				if l > 0:
					vx /= l
					vy /= l
					e.moving = true
					e.walk_t += dt
		for o in enemies:
			if o == e or o.dying:
				continue
			var sx: float = e.x - o.x
			var sy: float = e.y - o.y
			if absf(sx) > 18 or absf(sy) > 18:
				continue
			var sd := JS.hypot(sx, sy)
			if sd > 0 and sd < 18:
				var f := (18 - sd) / 18
				vx += sx / sd * f * 1.6
				vy += sy / sd * f * 1.6
		var sp = 0.0 if e.act != "" else e.spd * runes.e_slow(e) * (1.25 if e.burst_t > 0 else 1.0)
		if _empujado(e):
			sp = 0.0   # en las pasarelas, mientras le empujan no anda (si no, el empujón casi nunca le tira)
		mv(e, (vx * sp + e.vx) * dt, (vy * sp + e.vy) * dt)
		e.vx *= pow(.002, dt)
		e.vy *= pow(.002, dt)
		var fx2 = e.x - CX
		var fy2 = e.y - CY
		var fd2 := JS.hypot(fx2, fy2)
		var Rf := FRAD + 6
		if fd2 < Rf:
			e.x = CX + fx2 / (fd2 if fd2 else 1.0) * Rf
			e.y = CY + fy2 / (fd2 if fd2 else 1.0) * Rf
		if e.act == "" and e.hurt_t <= 0:
			var ax2 = vx if e.moving else dx
			var ay2 = vy if e.moving else dy
			if ax2 or ay2:
				var tg := atan2(ay2, ax2)
				var df = tg - e.face
				df = atan2(sin(df), cos(df))
				var mxr := ENEMY_TURN * dt
				e.face = e.face + maxf(-mxr, minf(mxr, df))

# ======================================================================
#  espadas lanzadas (lanzador)
# ======================================================================
func _update_projs(dt: float) -> void:
	for pr in projs:
		pr.t += dt
		var o: Ent.Enemy = pr.owner
		if pr.phase == "drop":
			pr.dead = true
			fx.burst(pr.x, pr.y, 14, ["#e6edf2", "#9aa0a6"], 6, 60)
			continue
		if pr.phase == "stall":
			pr.stall_t -= dt
			pr.x += pr.svx * dt
			pr.y += pr.svy * dt
			pr.svx *= pow(.02, dt)
			pr.svy *= pow(.02, dt)
			if rnd() < dt * 20:
				fx.part({"x": pr.x + (rnd() - .5) * 8, "y": pr.y, "z": 12 + rnd() * 6, "vx": 0, "vy": 0, "vz": 8, "float": true, "life": .3, "col": "#ffd25a"})
			if (pr.stall_t <= 0 and not pr.pend) or pr.stall_t < -.45:
				pr.phase = "back"
				pr.hit = true
				pr.pend = false
			continue
		if pr.phase == "reflect":
			if o.dead or o.dying:
				pr.phase = "drop"
				continue
			var rdx: float = o.x - pr.x
			var rdy: float = o.y - pr.y
			var rd := JS.hypot(rdx, rdy)
			if rd == 0: rd = 1
			var stp := 380 * dt
			if rnd() < dt * 40:
				fx.part({"x": pr.x, "y": pr.y, "z": 14, "vx": 0, "vy": 0, "vz": 4, "float": true, "life": .25, "col": "#ffd25a" if rnd() < .5 else "#ff7a18"})
			if rd <= stp + 8:
				pr.dead = true
				o.has_sword = true
				o.catch_t = .22
				_reflect_hit(o, pr)
			else:
				pr.x += rdx / rd * stp
				pr.y += rdy / rd * stp
			continue
		var tx: float = pr.tx if pr.phase == "out" else o.x
		var ty: float = pr.ty if pr.phase == "out" else o.y
		var spd := 200.0 if pr.phase == "out" else 220.0
		var dx: float = tx - pr.x
		var dy: float = ty - pr.y
		var d := JS.hypot(dx, dy)
		if d == 0: d = 1
		var stp := spd * dt
		if d <= stp:
			pr.x = tx
			pr.y = ty
			if pr.phase == "out":
				pr.phase = "back"
				pr.hit = false
			else:
				pr.dead = true
				o.has_sword = true
				o.catch_t = .22
		else:
			pr.x += dx / d * stp
			pr.y += dy / d * stp
		if pr.phase == "out" and DungeonGen.is_opaque(tile_at(cell_of(pr.x), cell_of(pr.y - 10))):
			pr.dead = true
			o.has_sword = true
			o.catch_t = .22
			fx.burst(pr.x, pr.y, 14, ["#e6edf2", "#9aa0a6", "#ffd25a"], 8, 60)
			continue
		if pr.phase == "out" and pr.t > 1.4:
			pr.phase = "back"
			pr.hit = false
		if not pr.hit and not p.dead and JS.hypot(pr.x - p.x, pr.y - p.y) < 13:
			pr.hit = true
			if hurt_player(pr.dmg, pr.x, pr.y, o, "proj") == "block" and not p.dead:
				var a := atan2(pr.y - p.y, pr.x - p.x)
				pr.phase = "stall"
				pr.stall_t = .5
				pr.pend = false
				pr.svx = cos(a) * 70
				pr.svy = sin(a) * 70
	var keep := []
	for pr in projs:
		if not pr.get("dead", false):
			keep.append(pr)
	projs = keep

## espadas paradas con el escudo que el héroe golpea: vuelven contra su dueño
func _reflect_pending() -> void:
	for pr in projs:
		if pr.pend and pr.phase == "stall":
			pr.pend = false
			pr.phase = "reflect"
			pr.t = 0
			fx.burst(pr.x, pr.y - 10, 22, ["#fffbe8", "#ffd25a", "#ff7a18"], 10, 120)
			fx.shake(4)
			hitstop = .06
			fx.text(pr.x, pr.y - 40, "¡DEVUELTA!", "#ffd25a", 11, true, 1, true, false)

func _reflect_hit(e: Ent.Enemy, pr: Dictionary) -> void:
	if e.dying or e.dead:
		return
	var ang := atan2(e.y - pr.y, e.x - pr.x)
	var dmg := int(dmg_mod(e, maxi(1, JS.roundi(maxf(pr.dmg, p.st.dmg) * 2 * (.9 + rnd() * .2)))))
	e.hp -= dmg
	p.dmg_dealt += dmg
	e.flash = .09
	stats.hits += 1
	fx.text(e.x, e.y - 40, str(dmg) + "!", "#ff3a2a", 15, true)
	fx.text(e.x, e.y - 62, "CRÍTICO", "#ff2a1a", 14, true, 1.5, true, false)
	if not e.armor:
		_interrumpe(e, .25)
	e.vx += cos(ang) * 80 * p.st.kb / (3.0 if e.rare else 1.0) * EMPUJE
	e.vy += sin(ang) * 80 * p.st.kb / (3.0 if e.rare else 1.0) * EMPUJE
	fx.bleed(e.x, e.y, 16, ang, 46, 150)
	for i in 18:
		fx.stain(e.x + (rnd() - .5) * 18, e.y + (rnd() - .5) * 5, BLOOD[i % 4], 2 if rnd() < .5 else 1)
	fx.shake(5)
	fx.hud()
	if e.hp <= 0:
		kill_enemy(e, ang)

# ======================================================================
#  avisos en el suelo (cuñas, líneas, anillos) y su geometría
# ======================================================================
func add_mark(e, o: Dictionary) -> Dictionary:
	o["own"] = e
	o["t"] = 0.0
	marks.append(o)
	return o

func _update_marks(dt: float) -> void:
	var keep := []
	for m in marks:
		m.t += dt
		var own: Ent.Enemy = m.own
		if own.dead or own.dying:
			continue
		if (m.kind == "cone" and not m.get("fixed", false)) or m.kind == "heal":
			m.x = own.x
			m.y = own.y
		if m.t >= m.T:
			_mark_end(m)
			continue
		keep.append(m)
	marks = keep

func m_seg(px_: float, py: float, ax: float, ay: float, bx: float, by: float) -> float:
	var vx := bx - ax
	var vy := by - ay
	var l := vx * vx + vy * vy
	if l == 0: l = 1
	var k := clampf(((px_ - ax) * vx + (py - ay) * vy) / l, 0, 1)
	return JS.hypot(px_ - ax - vx * k, py - ay - vy * k)

func m_in_ell(px_: float, py: float, cx: float, cy: float, r: float) -> bool:
	return JS.hypot(px_ - cx, (py - cy) / .62) <= r + M_FOOT

func m_in_cone(m: Dictionary, px_: float, py: float) -> bool:
	var dx: float = px_ - m.x
	var dy: float = (py - m.y) / .62
	var d := JS.hypot(dx, dy)
	if d > m.r + M_FOOT:
		return false
	if d < 10:
		return true
	var a: float = atan2(dy, dx) - m.a
	a = atan2(sin(a), cos(a))
	return absf(a) <= m.sp / 2 + asin(minf(1, M_FOOT / d))

func m_in_line(m: Dictionary, px_: float, py: float) -> bool:
	return m_seg(px_, py, m.x, m.y, m.x2, m.y2) <= m.w / 2 + M_FOOT

## recorta una línea de aviso en la primera pared
func m_clip_len(x: float, y: float, a: float, ln: float, r: float = 8) -> float:
	var k := 0.0
	while k < ln:
		if not fits(x + cos(a) * (k + 4), y + sin(a) * (k + 4), r):
			break
		k += 4
	return maxf(20, minf(ln, k))

# ======================================================================
#  campeón: tajo con cuña fija, embestida en línea y furia bajo la mitad de vida
# ======================================================================
func _champ_cancel(e: Ent.Enemy) -> void:
	if e.c_mk != null: e.c_mk.t = e.c_mk.T
	if e.ch_mk != null: e.ch_mk.t = e.ch_mk.T
	e.c_mk = null
	e.ch_mk = null
	e.cs = ""
	if e.act == "wind" or e.act == "strike":
		e.act = ""

func _champ_slash(e: Ent.Enemy, first: bool) -> void:
	var rage := e.hp < e.max_hp * .5
	var W := (.55 if first else .4) * (.85 if rage else 1.0)
	e.cs = "slash"
	e.cs_t = 0
	e.cs_w = W
	e.atk_a = atan2(p.y - e.y, p.x - e.x)
	e.face = e.atk_a
	e.flip = cos(e.atk_a) < 0
	e.act = "wind"
	e.wind_t = W
	e.act_t = W
	e.hit_done = false
	e.moving = false
	e.c_mk = add_mark(e, {"kind": "cone", "fixed": true, "x": e.x, "y": e.y, "a": e.atk_a, "r": CH_CONE.r, "sp": CH_CONE.sp, "T": W + .3})

func _champ_ai(e: Ent.Enemy, dt: float, dx: float, dy: float, d: float) -> bool:
	e.ch_cd = (2 + rnd() * 2 if e.ch_cd < 0 else e.ch_cd) - dt
	if e.cs != "" and (e.cs_seen < 0 or t - e.cs_seen > .15 or e.frozen > 0):
		_champ_cancel(e)
	e.cs_seen = t
	if not e.rage and e.hp < e.max_hp * .5 and not e.dying:
		e.rage = true
		fx.banner(e.title + " se enfurece", "Encadena tajos y embiste más a menudo")
		fx.burst(e.x, e.y - 20, 30, ["#ffd060", "#ff7a18", "#ff3a10"], 30, 120)
		fx.shake(5)
	if e.rage and rnd() < dt * 14:
		fx.part({"x": e.x + (rnd() - .5) * 20, "y": e.y, "z": 6 + rnd() * 30, "vx": 0, "vy": 0, "vz": 30, "float": true, "life": .5, "col": "#ff7a18" if rnd() < .5 else "#ff3a10"})
	if e.cs == "":
		if e.state != "chase" or e.act != "" or e.hurt_t > 0 or p.dead:
			return false
		if d < e.reach + 24 and e.cool <= 0 and e.has_sword:
			e.cs_left = 2 if e.hp < e.max_hp * .25 else (1 if e.hp < e.max_hp * .5 else 0)
			_champ_slash(e, true)
			return true
		if e.ch_cd <= 0 and d > 85 and d < 230 and e.clear and e.los:
			e.cs = "aim"
			e.cs_t = 0
			e.atk_a = atan2(dy, dx)
			e.face = e.atk_a
			e.flip = dx < 0
			e.act = "wind"
			e.wind_t = .6
			e.act_t = .6
			e.moving = false
			var ln := m_clip_len(e.x, e.y, e.atk_a, minf(240, d + 40), 8)
			e.ch_mk = add_mark(e, {"kind": "line", "x": e.x, "y": e.y, "x2": e.x + cos(e.atk_a) * ln, "y2": e.y + sin(e.atk_a) * ln, "w": 30.0, "T": .6, "col": Color8(255, 130, 30)})
			fx.text(e.x, e.y - 70, "¡Embestida!", "#ff9a3a", 10, false, .9, false, false)
			return true
		return false
	e.cs_t += dt
	e.vx *= pow(.002, dt)
	e.vy *= pow(.002, dt)
	if e.cs == "slash":
		if e.act == "wind":
			e.act_t = maxf(0, e.cs_w - e.cs_t)
			e.face = e.atk_a
			if e.cs_t >= e.cs_w:
				e.act = "strike"
				e.act_t = .24 / e.am
				e.hit_done = false
				mv(e, cos(e.atk_a) * 4, sin(e.atk_a) * 4)
		else:
			e.act_t -= dt
			if not e.hit_done and e.act_t < .15 / e.am:
				e.hit_done = true
				var m = e.c_mk
				if m != null and m_in_cone(m, p.x, p.y) and not p.dead:
					hurt_player(e.dmg, m.x, m.y, e)
				if m != null:
					m.t = m.T
					for k in 10:
						var a: float = m.a + (rnd() - .5) * m.sp
						var r: float = m.r * (.5 + rnd() * .5)
						fx.part({"x": m.x + cos(a) * r, "y": m.y + sin(a) * r * .62, "z": 3, "vx": cos(a) * 40, "vy": sin(a) * 25, "vz": 30, "life": .3, "col": "#ffd060" if k % 2 else "#ff7a18"})
				e.c_mk = null
			if e.act_t <= 0:
				if e.cs_left > 0 and not p.dead:
					e.cs_left -= 1
					_champ_slash(e, false)
				else:
					e.cs = ""
					e.act = ""
					e.cool = (.6 + rnd() * .4) / e.am
		return true
	if e.cs == "aim":
		e.act_t = maxf(0, .6 - e.cs_t)
		e.face = e.atk_a
		if e.cs_t >= .6:
			var m = e.ch_mk
			e.cs = "charge"
			e.cs_t = 0
			e.act = ""
			e.ch0 = Vector2(e.x, e.y)
			e.ch1 = Vector2(m.x2, m.y2) if m != null else Vector2(e.x, e.y)
			e.ch_hit = false
			fx.burst(e.x, e.y, 16, ["#ffd060", "#ff7a18", "#3a1a14"], 10, 90)
			fx.shake(3)
		return true
	if e.cs == "charge":
		var k := minf(1, e.cs_t / .32)
		e.moving = true
		e.walk_t += dt * 2.2
		e.face = e.atk_a
		var o := e.ch0.lerp(e.ch1, k)
		var bonk := false
		if fits(o.x, o.y, 8):
			e.x = o.x
			e.y = o.y
		else:
			bonk = true
		if rnd() < .9:
			fx.part({"x": e.x + (rnd() - .5) * 14, "y": e.y, "z": 2 + rnd() * 10, "vx": -cos(e.atk_a) * 40, "vy": -sin(e.atk_a) * 25, "vz": 10, "life": .35, "col": "#ff9a3a" if rnd() < .5 else "#5a3a24"})
		if not e.ch_hit and not p.dead and not (p.roll_t > 0) and m_seg(p.x, p.y, e.ch0.x, e.ch0.y, e.x, e.y) <= 15 + M_FOOT:
			e.ch_hit = true
			hurt_player(JS.roundi(e.dmg * 1.3), e.x, e.y, e)
			if not p.dead and not p.blocking:
				mv(p, cos(e.atk_a) * 14, sin(e.atk_a) * 14)
		if k >= 1 or bonk:
			if e.ch_mk != null: e.ch_mk.t = e.ch_mk.T
			e.ch_mk = null
			e.cs = "tired"
			e.cs_t = 0
			e.moving = false
			e.ch_cd = (4.5 if e.rage else 7.0) + rnd() * 1.5
			e.tired_t = 1.7 if bonk else 1.1
			if bonk:
				fx.shake(7)
				fx.burst(e.x, e.y - 10, 24, ["#e6edf2", "#9aa0a6", "#ffd25a"], 14, 110)
				fx.text(e.x, e.y - 74, "¡Se estrella!", "#ffd25a", 11, true, 1.2, false, false)
			else:
				fx.text(e.x, e.y - 74, "¡Expuesto!", "#ffd25a", 10, false, 1, false, false)
		return true
	if e.cs == "tired":
		e.act = ""
		e.moving = false
		if rnd() < dt * 8:
			var a := t * 6 + rnd()
			fx.part({"x": e.x + cos(a) * 10, "y": e.y + sin(a) * 4, "z": 52, "vx": 0, "vy": 0, "vz": 4, "float": true, "life": .4, "col": "#fff3c0" if rnd() < .5 else "#ffd25a"})
		if e.cs_t >= e.tired_t:
			e.cs = ""
			e.cool = .3
		return true
	e.cs = ""
	return false

# ======================================================================
#  héroes renegados: Mago, Arquero, Caballero de la Muerte y Señor Oscuro como enemigos
#  normales: se mezclan con los caballeros desde el piso 2; élites dorados con nombre: 0–2 por piso
# ======================================================================
const HH_TYPES := ["hmage", "harcher", "hdk", "hdl"]
const HH_TITLE := {"mage": "mago", "archer": "arquero", "dk": "caballero de la muerte", "dl": "señor oscuro"}
var hh_shots: Array = []      # flechas y bolas de fuego: {x, y, vx, vy, ang, k, dmg, life, owner}
var hh_clouds: Array = []     # nubes de muerte del Señor Oscuro: {x, y, r, t, form, tick, owner, seed}
var hh_fx: Array = []         # destellos del parpadeo del mago: {x, y, t}

func _hh_init(e: Ent.Enemy) -> void:
	e.cd_a = 1 + rnd() * 1.5
	e.cd_b = 3 + rnd() * 3
	e.combo = 0
	if e.hero == "mage" or e.hero == "archer":
		e.has_sword = false

func _hh_pick(w: int) -> String:
	if w < 2:
		return ""
	if rnd() < minf(.2, .06 + .02 * w):
		return HH_TYPES[int(rnd() * 4)]
	return ""

func _hh_elites(w: int) -> void:
	# desde el piso 1 (decidido por Diego): uno en los pisos 1–2, uno o dos hasta el 5 y después dos o tres
	var n := 1 if w <= 2 else (1 + (1 if rnd() < .5 else 0) if w <= 5 else 2 + (1 if rnd() < minf(.6, .15 + .05 * w) else 0))
	var rooms := []
	for k in L.rooms.size():
		var r: Dictionary = L.rooms[k]
		if k != L.start_room and not (L.fount != null and k == L.fount.room) and k != int(reto.get("room", -1)) and L.dist[r.cy * DungeonGen.GW + r.cx] > 14:
			rooms.append(r)
	var used := {}
	for o in enemies:
		if o.title != "":
			used[o.title] = true
	var types := HH_TYPES.duplicate()
	for j in range(types.size() - 1, 0, -1):
		var q := int(rnd() * (j + 1))
		var tmp = types[j]; types[j] = types[q]; types[q] = tmp
	var i := 0
	while i < n and rooms.size():
		var r: Dictionary = rooms.pop_at(int(rnd() * rooms.size()))
		var c = _rand_cell_in(r)
		if c != null:
			_hh_elite(spawn_enemy(types[i % 4], c.x, c.y), used)
		i += 1

func _hh_elite(e: Ent.Enemy, used: Dictionary) -> void:
	e.rare = true
	e.elite = true
	e.am = 1.3
	e.hp = JS.roundi(e.hp * 2.5); e.max_hp = e.hp; e.ghost = e.hp
	e.dmg = JS.roundi(e.dmg * 1.7)
	e.wind_t /= 1.3
	e.score *= 5
	var all: Array = GameData.get_table("renegade_heroes").HH_NAMES[e.hero]
	var names := all.filter(func(nm): return not used.has(nm))
	var pool: Array = names if names.size() else all
	e.title = pool[int(rnd() * (names.size() if names.size() else 4))]
	used[e.title] = true
	_dar_poder(e)

## movimiento compartido (separación, fuente, inercia)
func _hh_move(e: Ent.Enemy, vx: float, vy: float, dt: float, mult: float) -> void:
	for o in enemies:
		if o == e or o.dying:
			continue
		var sx: float = e.x - o.x
		var sy: float = e.y - o.y
		if absf(sx) > 18 or absf(sy) > 18:
			continue
		var sd := JS.hypot(sx, sy)
		if sd > 0 and sd < 18:
			var f := (18 - sd) / 18
			vx += sx / sd * f * 1.6
			vy += sy / sd * f * 1.6
	var sp := e.spd * mult * runes.e_slow(e)
	mv(e, (vx * sp + e.vx) * dt, (vy * sp + e.vy) * dt)
	e.vx *= pow(.002, dt)
	e.vy *= pow(.002, dt)
	var fx_ := e.x - CX
	var fy := e.y - CY
	var fd := JS.hypot(fx_, fy)
	var R := FRAD + 6
	if fd < R:
		e.x = CX + fx_ / (fd if fd else 1.0) * R
		e.y = CY + fy / (fd if fd else 1.0) * R
	if vx or vy:
		e.moving = true
		e.walk_t += dt

## daño en el tiempo al héroe (nube, drenaje): sin empujón ni temblor
func hh_dot(dmg: float, col: String, src) -> int:
	if p.inv > 0 or p.roll_t > 0 or p.dead:
		return 0
	dmg = runes.hurt(dmg, src, "dot", p.x, p.y)
	if not (dmg > 0):
		return 0
	var n := maxi(1, JS.roundi(dmg * (1 - p.st.armor)))
	if p.shield > 0:
		var ab := mini(int(p.shield), n)
		p.shield -= ab
		n -= ab
		if n <= 0:
			return 0
	if src != null:
		src.dealt += minf(n, p.hp)
	p.hp = maxf(0, p.hp - n)
	fx.text(p.x, p.y - 40, "-" + str(n), col, 10)
	fx.hud()
	runes.lethal()
	if p.hp <= 0:
		p.dead = true
		p.death_t = 0
	return n

## devuelve true si ya ha gestionado este fotograma
func _hh_ai(e: Ent.Enemy, dt: float, dx: float, dy: float, d: float) -> bool:
	e.cd_a -= dt
	e.cd_b -= dt
	if e.rise > 0:
		e.rise -= dt
		e.moving = false
		return true
	if e.hero == "minion":
		return false
	# drenaje del Caballero de la Muerte: corre aunque esté haciendo otra cosa
	if e.drain_t > 0:
		e.drain_t -= dt
		e.drain_tick -= dt
		if e.drain_tick <= 0:
			e.drain_tick = .5
			if d < 72:
				var got := hh_dot(e.dmg * .35, "#c0304a", e)
				if got:
					e.hp = minf(e.max_hp, e.hp + got)
					fx.text(e.x, e.y - 46, "+" + str(got), "#9a4dff", 9)
	# charco de sangre del Señor Oscuro: no se le puede matar, huye y se cura
	if e.pool_t > 0:
		e.pool_t -= dt
		e.hp = maxf(e.hp, e.pool_hp)
		e.hp = minf(e.max_hp, e.hp + e.max_hp * .05 * dt)
		e.pool_hp = e.hp
		e.act = ""
		e.hurt_t = 0
		var vx := -dx / d
		var vy := -dy / d
		if d > 150:
			vx = -dy / d * e.tang
			vy = dx / d * e.tang
		_hh_move(e, vx, vy, dt, 1.35)
		return true
	if e.hurt_t > 0:
		return false
	# acciones propias en curso (disparar, invocar)
	if e.act.begins_with("h"):
		e.act_t -= dt
		e.moving = false
		e.face = atan2(dy, dx)
		if e.act == "hshoot" and e.hero == "archer":
			e.aim_a = atan2(p.y - e.y, p.x - e.x)
		if e.act_t <= 0:
			var a := e.act
			e.act = ""
			_hh_release(e, a)
		_hh_move(e, 0, 0, dt, 0)
		return true
	if p.dead:
		return false
	var H := e.hero
	if H == "mage" or H == "archer":
		# a distancia: guarda las distancias, se mueve de lado y dispara con aviso
		if H == "mage" and d < 70 and e.cd_b <= 0 and _hh_blink(e):
			e.cd_b = 6 / e.am
			return true
		if H == "archer" and e.los and d < 230 and e.cd_b <= 0 and e.cd_a <= .8:
			e.act = "hmulti"
			e.act_t = .75 / e.am; e.act_max = e.act_t
			e.aim_a = atan2(dy, dx)
			e.cd_b = 7.5 / e.am
			e.cd_a = 1.3 / e.am
			return true
		if e.los and d < 260 and e.cd_a <= 0:
			e.act = "hshoot"
			e.act_t = (.5 if H == "mage" else .45) / e.am; e.act_max = e.act_t
			e.aim_a = atan2(dy, dx)
			e.cd_a = (1.9 if H == "mage" else 1.5) * (.85 + rnd() * .35) / e.am
			return true
		var lo := 85.0 if H == "mage" else 95.0
		var hi := 140.0 if H == "mage" else 155.0
		var vx := 0.0
		var vy := 0.0
		if not e.clear or d > hi:
			var nd = nav_dir(e) if not e.clear else Vector2(dx / d, dy / d)
			if nd != null:
				vx = nd.x
				vy = nd.y
		elif d < lo:
			vx = -dx / d
			vy = -dy / d
			if not fits(e.x + vx * 12, e.y + vy * 12, 6):
				vx = -dy / d * e.tang
				vy = dx / d * e.tang
		else:
			if rnd() < dt * .6:
				e.tang *= -1
			vx = -dy / d * .6 * e.tang
			vy = dx / d * .6 * e.tang
		_hh_move(e, vx, vy, dt, 1)
		var tg := atan2(vy if (vx or vy) else dy, vx if (vx or vy) else dx)
		var df := tg - e.face
		df = atan2(sin(df), cos(df))
		e.face += clampf(df, -ENEMY_TURN * dt, ENEMY_TURN * dt)
		if not vx and not vy:
			e.moving = false
		return true
	# cuerpo a cuerpo: combate normal de caballero, más sus dos habilidades
	if e.act != "":
		return false
	if H == "dk":
		var mins := 0
		for o in enemies:
			if o.master == e and not o.dying:
				mins += 1
		if e.los and d < 220 and e.cd_a <= 0 and mins < 2:
			e.act = "hcast"
			e.act_t = .8 / e.am; e.act_max = e.act_t
			e.cd_a = 20 / e.am
			return true
		if d < 85 and e.cd_b <= 0:
			e.drain_t = 6
			e.drain_tick = .3
			e.cd_b = 15 / e.am
			fx.text(e.x, e.y - 58, "Aura de drenaje", "#c0304a", 9)
	if H == "dl":
		if e.hp < e.max_hp * .45 and e.cd_b <= 0 and not e.pooled:
			e.pooled = true
			e.pool_t = 3
			e.pool_hp = e.hp
			e.cd_b = 20
			fx.text(e.x, e.y - 58, "Charco de sangre", "#c0203a", 9)
			fx.burst(e.x, e.y, 4, ["#8a1020", "#c0203a"], 14, 80)
			return true
		if e.los and d < 210 and d > 40 and e.cd_a <= 0:
			e.act = "hcast"
			e.act_t = .6 / e.am; e.act_max = e.act_t
			e.cloud_at = Vector2(p.x, p.y)
			e.cd_a = 13 / e.am
			return true
	return false

## el mago se teletransporta lejos del héroe
func _hh_blink(e: Ent.Enemy) -> bool:
	var away := atan2(e.y - p.y, e.x - p.x)
	for k in 14:
		var a := away + (1 if k % 2 else -1) * ceilf(k / 2.0) * .38
		var r := 120 + rnd() * 40
		var x := e.x + cos(a) * r
		var y := e.y + sin(a) * r
		if not fits(x, y, 8) or not has_los(e.x, e.y - 10, x, y - 10):
			continue
		if JS.hypot(x - CX, y - CY) < FRAD + 20:
			continue
		fx.burst(e.x, e.y, 14, ["#ffb03a", "#ff5a10", "#fff0b0"], 18, 110)
		hh_fx.append({"x": e.x, "y": e.y, "t": .35})
		e.x = x
		e.y = y
		e.vx = 0
		e.vy = 0
		e.blink_t = .3
		fx.burst(x, y, 14, ["#ffb03a", "#ff5a10", "#fff0b0"], 18, 110)
		hh_fx.append({"x": x, "y": y, "t": .35})
		return true
	return false

func _hh_release(e: Ent.Enemy, a: String) -> void:
	if a == "hshoot":
		var ang := e.aim_a if e.hero == "archer" else atan2(p.y - e.y, p.x - e.x)
		var sp := 165.0 if e.hero == "mage" else 250.0
		hh_shots.append({"x": e.x + cos(ang) * 10, "y": e.y + sin(ang) * 6, "vx": cos(ang) * sp, "vy": sin(ang) * sp, "ang": ang,
			"k": "fire" if e.hero == "mage" else "arrow", "dmg": JS.roundi(e.dmg * (1.15 if e.hero == "mage" else 1.0)), "life": 2.4, "owner": e})
	elif a == "hmulti":
		for i in 5:
			var ang := e.aim_a + (i - 2) * .16
			hh_shots.append({"x": e.x + cos(ang) * 10, "y": e.y + sin(ang) * 6, "vx": cos(ang) * 250, "vy": sin(ang) * 250, "ang": ang,
				"k": "arrow", "dmg": JS.roundi(e.dmg * .8), "life": 2.2, "owner": e})
	elif a == "hcast" and e.hero == "dk":
		# levanta dos esbirros junto a él
		for i in 2:
			var o := {"x": e.x + (22.0 if i else -22.0), "y": e.y + 8}
			unstick(o, 8)
			var m := spawn_enemy("knight", o.x, o.y)
			m.hero = "minion"
			m.master = e
			m.rise = .7
			m.hp = JS.roundi(m.hp * .55); m.max_hp = m.hp; m.ghost = m.hp
			m.xp = 1
			m.score = 0
			m.state = "chase"
			m.cool = .5
			fx.burst(o.x, o.y, 4, ["#9a4dff", "#5a2a90", "#d0b0ff"], 12, 70)
		total += 2
	elif a == "hcast" and e.hero == "dl":
		hh_clouds.append({"x": e.cloud_at.x, "y": e.cloud_at.y, "r": 50.0, "t": 5.6, "form": .6, "tick": .2, "owner": e, "seed": rnd() * 10})

## proyectiles, nubes y destellos
func _hh_update(dt: float) -> void:
	var keep := []
	for s in hh_shots:
		s.life -= dt
		s.x += s.vx * dt
		s.y += s.vy * dt
		var fire: bool = s.k == "fire"
		if s.life <= 0 or muro_px(s.x, s.y):
			fx.burst(s.x, s.y, 14, ["#ff9a2a", "#ff5a10", "#fff0b0"] if fire else ["#9a8a70", "#d8d0c0"], 12 if fire else 4, 90 if fire else 40)
			continue
		if not p.dead and JS.hypot(p.x - s.x, p.y - s.y) < 12:
			var o = s.owner if s.owner != null and not s.owner.dying else null
			hurt_player(s.dmg, s.x - s.vx * .05, s.y - s.vy * .05, o, "shot")
			if fire:
				fx.burst(s.x, s.y, 14, ["#ff9a2a", "#ff5a10", "#fff0b0"], 14, 100)
			continue
		if fire and rnd() < dt * 30:
			fx.part({"x": s.x, "y": s.y, "z": 16, "vx": 0, "vy": 0, "vz": 10, "float": true, "life": .25, "col": "#ffb03a" if rnd() < .5 else "#ff5a10"})
		keep.append(s)
	hh_shots = keep
	keep = []
	for c in hh_clouds:
		c.t -= dt
		if c.form > 0:
			c.form -= dt
		else:
			c.tick -= dt
			if c.tick <= 0:
				c.tick = .5
				if not p.dead and JS.hypot(p.x - c.x, (p.y - c.y) / .7) < c.r:
					hh_dot((c.owner.dmg if c.owner != null else 10) * .5, "#b070ff", c.owner)
		if c.t > 0:
			keep.append(c)
	hh_clouds = keep
	keep = []
	for f in hh_fx:
		f.t -= dt
		if f.t > 0:
			keep.append(f)
	hh_fx = keep
	for e in enemies:
		if e.blink_t > 0:
			e.blink_t -= dt

# ======================================================================
#  monstruos con hoja propia: Penitente de Brasas, Soul Eater, Demon Overseer y el jefe Angel of Mercy
#  la IA base es la del caballero (wind → strike → guard) ajustada con su ficha; cada uno añade sus habilidades
# ======================================================================
const MON_LV := {
	"vida": {"baja": .7, "media": 1.0, "alta": 2.2, "muy alta": 3.2, "jefe": 5.0},
	"dano": {"bajo": .8, "medio": 1.15, "alto": 1.5, "muy alto": 1.9, "muy alta": 1.9},
	"vel": {"lenta": .72, "normal": 1.0, "rapida": 1.3},
	"alcance": {"corto": 30.0, "corto-medio": 37.0, "medio": 44.0, "largo": 44.0},
}
const BOSS_F := [1.0, 1.0, 2.0, 4.0]
## radio del cuerpo dibujado de cada monstruo: los golpes cuentan desde su borde y el héroe no se mete dentro
const MON_CUERPO := {"penitente": 10.0, "soulEater": 13.0, "overseer": 15.0, "angel": 13.0, "bufona": 7.0,
	"middleDemon": 9.0, "demonCaptain": 11.0, "firedemon": 9.0}   # velocidad y dificultad del jefe por etapa
const BOSS_DMG_STUN := 1.6
const SE_BLOOD := ["#1c0303", "#2a0606", "#240505", "#330908", "#160202"]
var mon_haz: Array = []       # lava y ondas: {kind, x, y, r, t, life, own, dmg, tick | x2, y2, w, hit}
var mon_orbs: Array = []      # orbes de alma que persiguen: {x, y, vx, vy, t, life, own, dmg}
var boss_fx: Array = []       # haces de luz (plumas, meteoros): {x, y, t, col}

func mon_def(e) -> Dictionary:
	return GameData.get_table("monsters")[e.mon]

func mon_spawn(id: String, x: float, y: float) -> Ent.Enemy:
	var M: Dictionary = GameData.get_table("monsters")[id]
	var e := spawn_enemy("knight", x, y)
	var hk: float = MON_LV.vida.get(M.vida, 1.0)
	e.mon = id
	e.cuerpo = MON_CUERPO.get(id, 0.0)
	e.name = M.name
	e.title = M.name
	e.combo = 0
	e.hp = JS.roundi(e.hp * hk); e.max_hp = e.hp; e.ghost = e.hp
	e.dmg = JS.roundi(e.dmg * MON_LV.dano.get(M.dano, 1.0))
	e.spd *= MON_LV.vel.get(M.vel, 1.0)
	e.reach = MON_LV.alcance.get(M.alcance, 30.0)
	e.wind_t = M.get("wind", .45)
	e.am = M.get("am", .85)
	match M.get("cubre", ""):
		"no": e.guard_cd = INF
		"esquiva": e.mon_dodge = 1
		"ambos": e.mon_dodge = .5
	if M.get("dash", false):
		e.dash_cd = 1.5 + rnd() * 2
	if M.get("tipo", "") == "distancia":
		e.thrower = true
	if M.get("muerte", "") != "cadaver":
		e.no_corpse = true
	e.score = JS.roundi(e.score * hk * 2)
	e.xp = JS.roundi(e.xp * hk * 2.2)
	if M.has("hpMul"):
		e.hp = JS.roundi(e.max_hp * M.hpMul); e.max_hp = e.hp; e.ghost = e.hp
	if M.has("dmgMul"):
		e.dmg = JS.roundi(e.dmg * M.dmgMul)
	if M.has("boss"):
		_boss_init(e, M.boss)
	return e

func _rooms_free() -> Array:
	var ks := []
	for k in L.rooms.size():
		if k != L.start_room and not (L.fount != null and k == L.fount.room) and k != int(reto.get("room", -1)):
			ks.append(k)
	return ks

## reparto por piso: cada monstruo sale desde su piso, solo, en grupo o guardando la escalera
func _mon_populate(w: int) -> void:
	var dist: PackedInt32Array = L.dist
	# piso 2: dos Penitentes de Brasas, cada uno en una sala distinta
	if w == 2:
		var ks := _rooms_free()
		for i in range(ks.size() - 1, 0, -1):
			var j := int(rnd() * (i + 1))
			var tmp = ks[i]; ks[i] = ks[j]; ks[j] = tmp
		var put := 0
		for k in ks:
			if put >= 2:
				break
			for tt in 30:
				var c = _rand_cell_in(L.rooms[k])
				if c != null and dist[c.cy * DungeonGen.GW + c.cx] > 8 and fits(c.x, c.y, 8):
					mon_spawn("penitente", c.x, c.y)
					put += 1
					break
	var MS: Dictionary = GameData.get_table("monsters")
	var usadas := {}   # salas que ya tienen monstruo
	for id in MS:
		var M: Dictionary = MS[id]
		if M.group == "horda":
			_horda_populate(id, M, w)
			continue
		# piso 3: Soul Eater asegurado en su sala sellada
		if id == "soulEater" and w == 3:
			if not _se_place():
				var ks := []
				for k in L.rooms.size():
					if k != L.start_room:
						ks.append(k)
				var r: Dictionary = L.rooms[ks[int(rnd() * ks.size())]]
				var o := {"x": (r.x + r.w / 2.0) * TS, "y": (r.y + r.h / 2.0) * TS}
				unstick(o, 10)
				mon_spawn(id, o.x, o.y)
			continue
		if w < M.from or (M.has("to") and w > M.to) or rnd() > M.chance:
			continue
		if id == "soulEater" and _se_place():
			continue
		if M.group == "jefe":
			var o := {"x": L.stairs_px.x, "y": L.stairs_px.y + 56}
			unstick(o, 8)
			mon_spawn(id, o.x, o.y)
			continue
		var rooms := _rooms_free()
		# cada monstruo en una sala distinta (mientras queden salas sin usar)
		var libres := rooms.filter(func(k): return not usadas.has(k))
		if not libres.is_empty():
			rooms = libres
		if rooms.is_empty():
			continue
		var rk: int = rooms[int(rnd() * rooms.size())]
		usadas[rk] = true
		var r: Dictionary = L.rooms[rk]
		var n := 2 + (1 if rnd() < .4 else 0) if M.group == "grupo" else 1
		if M.has("groupN"):
			n = int(M.groupN)
		for i in n:
			var c = _rand_cell_in(r)
			if c != null and dist[c.cy * DungeonGen.GW + c.cx] > 10:
				mon_spawn(id, c.x, c.y)

## hordas (esqueletos): varios grupos repartidos por salas distintas, más grupos cuanto más hondo
func _horda_populate(id: String, M: Dictionary, w: int) -> void:
	if w < M.from:
		return
	var H: Dictionary = M.horda
	var dist: PackedInt32Array = L.dist
	var ks := _rooms_free()
	for i in range(ks.size() - 1, 0, -1):
		var j := int(rnd() * (i + 1))
		var tmp = ks[i]; ks[i] = ks[j]; ks[j] = tmp
	var grupos := mini(ks.size(), int(H.grupos) + mini(int(H.grupos_max) - int(H.grupos), (w - int(M.from)) >> 1))
	var pg: Array = H.por_grupo
	for g in grupos:
		var r: Dictionary = L.rooms[ks[g]]
		var n: int = int(pg[0]) + int(rnd() * (int(pg[1]) - int(pg[0]) + 1))
		for i in n:
			var c = _rand_cell_in(r)
			if c != null and dist[c.cy * DungeonGen.GW + c.cx] > 10:
				mon_spawn(id, c.x, c.y)

## lo que hacen cada fotograma fuera de la IA: reacciones al golpe, embestidas, partículas, estallidos
func _mon_update(dt: float) -> void:
	_mon_haz_tick(dt)
	for e in enemies:
		if e.mon == "":
			continue
		var M: Dictionary = mon_def(e)
		if e.se_room >= 0 and not e.dying:
			_se_room_tick(e)
		if e.flash > 0 and not e.ms.get("fl", false):
			e.ms.fl = true
			if not e.dying and e.act != "strike":
				e.mon_hurt = .3
			if M.herir == "plateado":
				fx.burst(e.x, e.y, 18, ["#ffffff", "#dfe8ff", "#a9b8d2", "#6f7a90"], 12, 80)
			elif M.herir == "hueso":
				fx.burst(e.x, e.y, 12, ["#ece6d4", "#c8c0a8", "#8a8270", "#5a5446"], 14, 70)
		if e.flash <= 0:
			e.ms.fl = false
		if e.mon_hurt > 0:
			e.mon_hurt -= dt
		if e.dying:
			if not e.ms.get("boom", false):
				e.ms.boom = true
				if e.boss != "":
					_boss_death(e)
				if e.se_room >= 0:
					_se_open(e)
				if M.has("boom"):
					fx.burst(e.x, e.y, 20, M.boom, 40, 110)
			continue
		if absf(e.x - p.x) > 420 or absf(e.y - p.y) > 420:
			continue
		var h: float = M.barH
		var ember: Array = M.get("emberCol", ["#ffb030", "#ff5a10"])
		for k in M.get("parts", []):
			if k == "brasas" and rnd() < dt * 9:
				fx.part({"x": e.x + (rnd() - .5) * 14, "y": e.y, "z": h * .55 + rnd() * h * .4, "vx": (rnd() - .5) * 10, "vy": 0, "vz": 26 + rnd() * 20, "float": true, "life": .5 + rnd() * .4, "col": ember[0 if rnd() < .5 else 1]})
			elif k == "humo" and rnd() < dt * 4:
				fx.part({"x": e.x + (rnd() - .5) * 10, "y": e.y, "z": h * .8 + rnd() * 8, "vx": (rnd() - .5) * 6, "vy": 0, "vz": 16 + rnd() * 10, "float": true, "life": .8 + rnd() * .5, "col": "#3a302c" if rnd() < .5 else "#4e4440"})
		if M.has("aura") and rnd() < dt * 14:
			var fa: float = e.face + PI
			var ap: Array = M.get("auraP", ["#ffffff", "#c8d4ec"])
			fx.part({"x": e.x + cos(fa) * 6 + (rnd() - .5) * 16, "y": e.y - 2, "z": h * .35 + rnd() * h * .5, "vx": cos(fa) * 8 + (rnd() - .5) * 6, "vy": 0, "vz": 18 + rnd() * 16, "float": true, "life": .7 + rnd() * .5, "col": ap[0 if rnd() < .5 else 1]})
		if M.has("trail") and e.moving and rnd() < dt * 10:
			fx.stain(e.x + (rnd() - .5) * 6, e.y + 1, M.trail[int(rnd() * M.trail.size())], 1)
		# golpe fuerte: estallido en el punto de impacto cuando se hace el daño
		if M.get("bigFx", false) and e.act == "strike" and e.hit_done and not e.ms.get("mhit", false):
			e.ms.mhit = true
			var ix: float = e.x + cos(e.face) * e.reach * .8
			var iy: float = e.y + sin(e.face) * e.reach * .5
			for k in 46:
				var aa := rnd() * 6.283
				var v := 40 + rnd() * 130
				fx.part({"x": ix, "y": iy, "z": 14 + rnd() * 18, "vx": cos(aa) * v, "vy": sin(aa) * v * .6, "vz": 40 + rnd() * 90, "life": .35 + rnd() * .45, "col": M.strikeFx[k % M.strikeFx.size()]})
			fx.shake(4)
		if e.act != "strike":
			e.ms.mhit = false
		if e.act == "strike" and not e.ms.get("mstk", false) and M.has("strikeFx"):
			e.ms.mstk = true
			for k in (60 if M.get("bigFx", false) else 22):
				var aa: float = e.face + (rnd() - .5) * 2.2
				var r: float = 14 + rnd() * e.reach
				fx.part({"x": e.x + cos(aa) * r, "y": e.y + sin(aa) * r * .6, "z": 10 + rnd() * 16, "vx": cos(aa) * 40, "vy": sin(aa) * 24, "vz": 30 + rnd() * 40, "life": .35 + rnd() * .3, "col": M.strikeFx[k % M.strikeFx.size()]})
			fx.shake(2)
		if e.act != "strike":
			e.ms.mstk = false

## el héroe y los monstruos grandes no se solapan: se aparta el monstruo y, si choca con la pared, el héroe
func _mon_empuje(dt: float) -> void:
	if p == null or p.dead:
		return
	for e: Ent.Enemy in enemies:
		if e.cuerpo <= 0 or e.dying or e.boss_air or e.bz > 1:
			continue
		var min_d: float = e.cuerpo + 5
		var dx := e.x - p.x
		var dy := e.y - p.y
		var d := JS.hypot(dx, dy)
		if d >= min_d:
			continue
		if d < .01:
			dx = cos(p.face); dy = sin(p.face); d = 1.0
		var falta := minf(min_d - d, 150 * dt)   # poco a poco: sin saltos al aterrizar encima
		var ux := dx / d
		var uy := dy / d
		var x0 := e.x
		var y0 := e.y
		mv(e, ux * falta, uy * falta)
		var hecho := (e.x - x0) * ux + (e.y - y0) * uy
		if hecho < falta - .1:
			mv(p, -ux * (falta - hecho), -uy * (falta - hecho))

func m_hurt(e: Ent.Enemy, k: float, x = null, y = null) -> void:
	hurt_player(maxi(1, JS.roundi(e.dmg * k)), e.x if x == null else x, e.y if y == null else y, e)

func m_sparks(x: float, y: float, n: int, cols: Array, v: float = 90, z: float = 10) -> void:
	for k in n:
		var a := rnd() * 6.283
		var s := v * (.4 + rnd())
		fx.part({"x": x, "y": y, "z": z + rnd() * 10, "vx": cos(a) * s, "vy": sin(a) * s * .6, "vz": 30 + rnd() * 70, "life": .3 + rnd() * .4, "col": cols[k % cols.size()]})

# ---------------- habilidades (MON_SK) ----------------
func _mon_skill_ai(e: Ent.Enemy, dt: float, d: float) -> bool:
	var sk_def: Dictionary = GameData.get_table("monster_skills")
	if not sk_def.has(e.mon):
		return false
	if not e.ms.has("cds"):
		e.ms.cds = {}
	var cds: Dictionary = e.ms.cds
	for k in cds:
		if cds[k] > 0:
			cds[k] -= dt
	_mon_passive(e, dt, d)
	if e.ms.get("sk", "") != "":
		e.ms.skT += dt
		if e.hurt_t > 0:
			e.hurt_t = 0
		if _mon_skill(e, e.ms.sk, dt):
			e.ms.sk = ""
			e.act = ""
			e.cool = maxf(e.cool, .35)
		return true
	if e.state != "chase" or e.act != "" or e.frozen > 0 or p.dead or e.hurt_t > 0:
		return false
	e.ms.gap = e.ms.get("gap", 1.2) - dt
	if e.ms.gap > 0:
		return false
	var k := _mon_pick(e, d)
	if k == "":
		return false
	e.ms.sk = k
	e.ms.skT = 0.0
	e.ms.gap = 1.4 + rnd() * .8
	e.moving = false
	e.act = ""
	return true

func _cd(e: Ent.Enemy, k: String) -> float:
	return e.ms.cds.get(k, 0.0)

func _mon_pick(e: Ent.Enemy, d: float) -> String:
	match e.mon:
		"demonCaptain":
			if d > 45 and d < 240 and e.clear and not (_cd(e, "salto") > 0): return "salto"
		"penitente":
			if d < 70 and not (_cd(e, "spin") > 0): return "spin"
			if d > 90 and d < 190 and e.clear and not (_cd(e, "pull") > 0): return "pull"
		"soulEater":
			if not _se_alcanza(e): return ""
			if d > 60 and d < 230 and e.clear and not (_cd(e, "dash3") > 0): return "dash3"
			if d > 70 and not (_cd(e, "orbs") > 0): return "orbs"
		"overseer":
			if d < 110 and not (_cd(e, "slam") > 0): return "slam"
			var imps := 0
			for o in enemies:
				if o.imp and not o.dying:
					imps += 1
			if not (_cd(e, "summon") > 0) and imps < 3: return "summon"
			if not (_cd(e, "meteor") > 0): return "meteor"
	return ""

## el Soul Eater solo usa sus magias si te ve y, si tiene sala, si estás dentro de ella
func _se_alcanza(e: Ent.Enemy) -> bool:
	return e.los and (e.se_room < 0 or room_at_px(p.x, p.y) == e.se_room)

func _mon_passive(e: Ent.Enemy, dt: float, d: float) -> void:
	var s: Dictionary = e.ms
	match e.mon:
		"penitente":
			# charcos de lava al andar y el tirón de cadena arrastra al héroe
			s.lavaT = s.get("lavaT", 2.0) - dt
			if e.moving and s.lavaT <= 0 and e.state == "chase":
				s.lavaT = 2.2
				mon_haz.append({"kind": "lava", "x": e.x, "y": e.y + 2, "r": 15.0, "t": 0.0, "life": 5.0, "own": e, "dmg": .25, "tick": 0.0})
			if s.get("pullT", 0.0) > 0:
				s.pullT -= dt
				var k := minf(1, dt * 14)
				p.x += (s.pullX - p.x) * k
				p.y += (s.pullY - p.y) * k
				unstick(p, 6)
		"soulEater":
			# aura que absorbe vida
			if e.state != "chase":
				return
			s.drT = s.get("drT", 0.0) - dt
			if d < 74 and s.drT <= 0 and not p.dead and _se_alcanza(e):
				s.drT = .5
				var h := maxi(1, JS.roundi(p.st.maxHp * .01))
				if not (p.inv > 0) and not (p.roll_t > 0):
					p.hp = maxf(1, p.hp - h)
					e.hp = minf(e.max_hp, e.hp + h * 3)
					fx.text(p.x, p.y - 44, "-" + str(h), "#9ad0ff", 9, false, .7, false, false)
					fx.hud()
				for k in 6:
					fx.part({"x": p.x + (rnd() - .5) * 10, "y": p.y, "z": 20 + rnd() * 10, "vx": (e.x - p.x) * 1.6, "vy": (e.y - p.y) * 1.6, "vz": 0, "life": .5, "col": "#9ad0ff" if k % 2 else "#3a7aff"})
		"overseer":
			if e.state == "chase" and rnd() < dt * 6:
				fx.part({"x": e.x + (rnd() - .5) * 30, "y": e.y, "z": 2, "vx": 0, "vy": 0, "vz": 14, "float": true, "life": .8, "col": "#3a1a14" if rnd() < .5 else "#5a2418"})

## una habilidad en curso: devuelve true cuando termina
func _mon_skill(e: Ent.Enemy, sk: String, dt: float) -> bool:
	var s: Dictionary = e.ms
	var first: bool = s.skT <= dt * 1.5
	match sk:
		"spin":   # barrido de cadena en círculo
			if first:
				s.spinM = add_mark(e, {"kind": "ring", "x": e.x, "y": e.y, "r": 66.0, "T": .6, "col": Color8(255, 90, 30)})
			e.act = ""
			e.moving = false
			if s.skT >= .6 and not s.get("spun", false):
				s.spun = true
				s.spinA = 0.0
			if s.get("spun", false):
				s.spinA += dt * 18
				if not s.get("spinHit", false) and s.spinA > 2:
					s.spinHit = true
					var m: Dictionary = s.spinM
					if m_in_ell(p.x, p.y, m.x, m.y, 66):
						m_hurt(e, 1.1)
					fx.shake(4)
				for k in 4:
					var a: float = s.spinA - k * .3
					fx.part({"x": e.x + cos(a) * 60, "y": e.y + sin(a) * 36, "z": 12, "vx": cos(a + 1.57) * 40, "vy": sin(a + 1.57) * 24, "vz": 20, "life": .3, "col": "#ffd060" if k % 2 else "#ff5a10"})
				if s.spinA >= 6.6:
					s.spun = false
					s.spinHit = false
					s.cds.spin = 7.0
					return true
			return false
		"pull":   # tirón de cadena en línea
			if first:
				e.face = atan2(p.y - e.y, p.x - e.x)
				s.pullL = add_mark(e, {"kind": "line", "x": e.x, "y": e.y, "x2": e.x + cos(e.face) * 200, "y2": e.y + sin(e.face) * 200, "w": 24.0, "T": .45, "col": Color8(255, 120, 30)})
			e.act = ""
			e.moving = false
			var m = s.get("pullL")
			if m == null:
				return true
			if s.skT >= .45 and not s.get("pullDone", false):
				s.pullDone = true
				var hit := m_in_line(m, p.x, p.y) and not (p.roll_t > 0)
				if hit:
					m_hurt(e, .6, p.x, p.y)
					s.pullT = .25
					s.pullX = e.x + cos(e.face) * 34
					s.pullY = e.y + sin(e.face) * 34
					m_sparks(p.x, p.y, 24, ["#ffd060", "#ff6a10", "#ffffff"], 120, 14)
					fx.shake(5)
				s.chainOut = {"x": p.x if hit else m.x2, "y": p.y if hit else m.y2, "t": .35}
			if s.skT >= .85:
				s.pullDone = false
				s.pullL = null
				s.cds.pull = 8.0
				return true
			return false
		"dash3":   # triple embestida
			if first:
				s.dn = 0
				s.dph = "aim"
				s.dt0 = 0.0
			s.dt0 += dt
			if s.dph == "aim":
				e.act = ""
				e.moving = false
				if s.dt0 < dt * 1.5:
					e.face = atan2(p.y - e.y, p.x - e.x)
					var ln := m_clip_len(e.x, e.y, e.face, minf(200, JS.hypot(p.x - e.x, p.y - e.y) + 50), 8)
					s.dl = add_mark(e, {"kind": "line", "x": e.x, "y": e.y, "x2": e.x + cos(e.face) * ln, "y2": e.y + sin(e.face) * ln, "w": 30.0, "T": .42, "col": Color8(120, 170, 255)})
				if s.dt0 >= .42:
					s.dph = "go"
					s.dt0 = 0.0
					s.d0 = Vector2(e.x, e.y)
					s.d1 = Vector2(s.dl.x2, s.dl.y2)
					s.dHit = false
					e.act = "dodge"
					e.dodge_a = e.face
					e.dodge_t = .22
					m_sparks(e.x, e.y, 16, ["#d0e8ff", "#6aa8ff", "#2a5aff"], 90)
			else:
				var k := minf(1, s.dt0 / .22)
				e.act_t = .22 - s.dt0
				var o: Vector2 = s.d0.lerp(s.d1, k)
				if fits(o.x, o.y, 8):
					e.x = o.x
					e.y = o.y
				if not s.dHit and m_seg(p.x, p.y, s.d0.x, s.d0.y, e.x, e.y) <= 15 + M_FOOT and not (p.roll_t > 0):
					s.dHit = true
					m_hurt(e, .8)
				if rnd() < .9:
					fx.part({"x": e.x + (rnd() - .5) * 16, "y": e.y, "z": 8 + rnd() * 30, "vx": 0, "vy": 0, "vz": 10, "float": true, "life": .45, "col": "#9ad0ff" if rnd() < .5 else "#2a3a8a"})
				if k >= 1:
					s.dn += 1
					e.act = ""
					if s.dn >= 3:
						s.cds.dash3 = 7.0
						return true
					s.dph = "aim"
					s.dt0 = 0.0
			return false
		"orbs":   # orbes de alma que persiguen
			e.act = "wind"
			e.wind_t = .7
			e.act_t = maxf(0, .7 - s.skT)
			e.moving = false
			if first:
				add_mark(e, {"kind": "ring", "x": e.x, "y": e.y, "r": 30.0, "T": .7, "col": Color8(120, 170, 255)})
			if s.skT >= .7:
				for k in 3:
					var a: float = e.face + (k - 1) * 1.2
					mon_orbs.append({"x": e.x + cos(a) * 20, "y": e.y + sin(a) * 12, "vx": cos(a) * 60, "vy": sin(a) * 40, "t": 0.0, "life": 6.0, "own": e, "dmg": .55})
				m_sparks(e.x, e.y, 20, ["#d0e8ff", "#6aa8ff"], 80, 30)
				e.act = ""
				s.cds.orbs = 9.0
				return true
			return false
		"salto":   # el capitán salta sobre el héroe: al caer daña y aturde 2 s, y luego da dos puñetazos
			e.moving = false
			const SUBE := .9
			const R_CAIDA := 48.0
			if first:
				s.sx = e.x; s.sy = e.y
				s.tx = p.x; s.ty = p.y
				e.face = atan2(p.y - e.y, p.x - e.x)
				s.salM = add_mark(e, {"kind": "zone", "x": p.x, "y": p.y, "r": R_CAIDA, "T": SUBE, "col": Color8(255, 90, 20)})
				s.cayo = false
				s.punos = 0
			if s.skT < SUBE:
				var k: float = s.skT / SUBE
				e.act = "jump"
				e.x = lerpf(s.sx, s.tx, k)
				e.y = lerpf(s.sy, s.ty, k)
				e.bz = sin(PI * k) * 70.0
				return false
			if not s.cayo:
				s.cayo = true
				e.bz = 0.0
				unstick(e, 8)
				fx.shake(9)
				m_sparks(e.x, e.y, 40, mon_def(e).get("boom", ["#ffb030", "#ff5a10"]), 150, 4)
				if JS.hypot(p.x - e.x, p.y - e.y) < R_CAIDA and not p.dead and not (p.roll_t > 0):
					m_hurt(e, 1.3, e.x, e.y)
					p.aturdido = 2.0
					fx.text(p.x, p.y - 40, "Aturdido", "#ffb030", 11, false, 1.2)
			# dos puñetazos mientras dura el aturdimiento
			var tg: float = s.skT - SUBE
			for k in 2:
				var t0 := .25 + k * .5
				if s.punos == k and tg >= t0:
					s.punos = k + 1
					e.face = atan2(p.y - e.y, p.x - e.x)
					e.act = "strike"
					e.act_t = .3
					if JS.hypot(p.x - e.x, p.y - e.y) < e.reach + 14 and not p.dead:
						m_hurt(e, .8, p.x, p.y)
			if tg >= 1.4:
				e.act = ""
				s.cds.salto = 7.0
				return true
			return false
		"slam":   # golpe al suelo con tres ondas
			e.act = "wind"
			e.wind_t = .65
			e.act_t = maxf(0, .65 - s.skT)
			e.moving = false
			if first:
				e.face = atan2(p.y - e.y, p.x - e.x)
				s.sl = []
				for k in [-1, 0, 1]:
					var a: float = e.face + k * .45
					s.sl.append(add_mark(e, {"kind": "line", "x": e.x, "y": e.y, "x2": e.x + cos(a) * 170, "y2": e.y + sin(a) * 170, "w": 22.0, "T": .65, "col": Color8(255, 60, 20)}))
			if s.skT >= .65 and not s.get("slDone", false):
				s.slDone = true
				fx.shake(8)
				m_sparks(e.x, e.y, 30, ["#ffd060", "#ff5a10", "#3a1a14"], 140, 4)
				for m in s.sl:
					mon_haz.append({"kind": "wave", "x": m.x, "y": m.y, "x2": m.x2, "y2": m.y2, "w": m.w, "t": 0.0, "life": .45, "own": e, "dmg": 1.1, "hit": false})
			if s.skT >= 1.05:
				s.slDone = false
				e.act = ""
				s.cds.slam = 6.0
				return true
			return false
		"meteor":   # meteoros sobre el héroe y alrededor
			e.act = "wind"
			e.wind_t = .6
			e.act_t = maxf(0, .6 - s.skT)
			e.moving = false
			if first:
				for k in 5:
					var x := p.x
					var y := p.y
					if k:
						var a := rnd() * 6.283
						var r := 24 + rnd() * 70
						x += cos(a) * r
						y += sin(a) * r * .8
						if not fits(x, y, 6):
							continue
					add_mark(e, {"kind": "zone", "x": x, "y": y, "r": 24.0, "T": .9 + k * .12, "col": Color8(255, 70, 20), "on_end": "meteor"})
			if s.skT >= .8:
				e.act = ""
				s.cds.meteor = 10.0
				return true
			return false
		"summon":   # llama diablillos
			e.act = "wind"
			e.wind_t = .8
			e.act_t = maxf(0, .8 - s.skT)
			e.moving = false
			if first:
				add_mark(e, {"kind": "ring", "x": e.x, "y": e.y, "r": 46.0, "T": .8, "col": Color8(255, 60, 20)})
			if s.skT >= .8:
				for k in 2:
					var a := rnd() * 6.283
					var o := {"x": e.x + cos(a) * 40, "y": e.y + sin(a) * 26}
					unstick(o, 8)
					var m := spawn_enemy("slayer", o.x, o.y)
					m.rare = false
					m.imp = true
					m.title = "Diablillo"
					m.hp = JS.roundi(m.hp * .6); m.max_hp = m.hp; m.ghost = m.hp
					wake(m)
					m_sparks(o.x, o.y, 20, ["#ff5a10", "#3a1a14", "#ffd060"], 90, 4)
				total += 2
				e.act = ""
				s.cds.summon = 16.0
				return true
			return false
	return true

## lava, ondas y orbes
func _mon_haz_tick(dt: float) -> void:
	var keep := []
	for h in mon_haz:
		h.t += dt
		var own: Ent.Enemy = h.own
		if h.t >= h.life or own.dead:
			continue
		if h.kind == "lava":
			h.tick -= dt
			if h.tick <= 0 and JS.hypot(p.x - h.x, p.y - h.y) < h.r and not p.dead:
				h.tick = .5
				m_hurt(own, h.dmg, h.x, h.y)
		elif h.kind == "wave" and not h.hit:
			var k: float = h.t / h.life
			var wx: float = h.x + (h.x2 - h.x) * k
			var wy: float = h.y + (h.y2 - h.y) * k
			if rnd() < .9:
				m_sparks(wx, wy, 2, ["#ff5a10", "#ffd060"], 40, 2)
			if JS.hypot(p.x - wx, p.y - wy) < 20 and m_in_line(h, p.x, p.y) and not (p.roll_t > 0):
				h.hit = true
				m_hurt(own, h.dmg, wx, wy)
		keep.append(h)
	mon_haz = keep
	keep = []
	for o in mon_orbs:
		o.t += dt
		var dx: float = p.x - o.x
		var dy: float = p.y - 10 - o.y
		var d := JS.hypot(dx, dy)
		if d == 0: d = 1
		o.vx += (dx / d * 58 - o.vx) * minf(1, dt * 1.4)
		o.vy += (dy / d * 58 - o.vy) * minf(1, dt * 1.4)
		o.x += o.vx * dt
		o.y += o.vy * dt
		if rnd() < .7:
			fx.part({"x": o.x, "y": o.y + 10, "z": 10, "vx": 0, "vy": 0, "vz": 6, "float": true, "life": .4, "col": "#9ad0ff" if rnd() < .5 else "#3a5aff"})
		if d < 12 and not p.dead and not (p.roll_t > 0):
			m_hurt(o.own, o.dmg, o.x, o.y)
			m_sparks(o.x, o.y + 10, 22, ["#ffffff", "#9ad0ff", "#3a7aff"], 120, 10)
			continue
		# los orbes chocan con muros y puertas cerradas
		if o.t >= o.life or o.own.dead or o.own.dying or muro_px(o.x, o.y + 10):
			m_sparks(o.x, o.y + 10, 10, ["#9ad0ff", "#3a7aff"], 60, 10)
			continue
		keep.append(o)
	mon_orbs = keep
	keep = []
	for f in boss_fx:
		f.t += dt
		if f.t <= .35:
			keep.append(f)
	boss_fx = keep

## al acabar un aviso: plumas y meteoros caen donde marcaban
func _mark_end(m: Dictionary) -> void:
	var own: Ent.Enemy = m.own
	if m.kind == "feather":
		if m_in_ell(p.x, p.y, m.x, m.y, m.r):
			hurt_player(JS.roundi(own.dmg * .8), m.x, m.y, own)
		boss_fx.append({"x": m.x, "y": m.y, "t": 0.0, "col": Color.WHITE})
		for k in 14:
			var a := rnd() * 6.283
			fx.part({"x": m.x, "y": m.y, "z": 4, "vx": cos(a) * 90, "vy": sin(a) * 50, "vz": 40 + rnd() * 60, "life": .4, "col": "#ffffff" if k % 2 else "#c8d4ec"})
	elif m.get("on_end", "") == "meteor":
		if m_in_ell(p.x, p.y, m.x, m.y, m.r):
			m_hurt(own, .9, m.x, m.y)
		boss_fx.append({"x": m.x, "y": m.y, "t": 0.0, "col": Color8(255, 140, 40)})
		m_sparks(m.x, m.y, 18, ["#ffd060", "#ff5a10", "#5a2418"], 110, 4)
		fx.shake(3)

# ---------------- la sala sellada del Soul Eater ----------------
func _se_openings(k: int) -> Variant:
	var r: Dictionary = L.rooms[k]
	var room_of: PackedInt32Array = L.room_of
	var at := func(x: int, y: int) -> int: return 0 if (x < 0 or y < 0 or x >= DungeonGen.GW or y >= DungeonGen.GH) else G[y * DungeonGen.GW + x]
	var out := func(x: int, y: int) -> bool: return (at.call(x, y) != 0 and room_of[y * DungeonGen.GW + x] < 0) or at.call(x, y) == DungeonGen.DOOR
	var runs := []
	for y in [r.y - 1, r.y + r.h]:
		var run := []
		for x in range(r.x, r.x + r.w):
			if out.call(x, y):
				run.append([x, y])
			elif run.size():
				runs.append({"h": true, "run": run}); run = []
		if run.size():
			runs.append({"h": true, "run": run})
	for x in [r.x - 1, r.x + r.w]:
		var run := []
		for y in range(r.y, r.y + r.h):
			if out.call(x, y):
				run.append([x, y])
			elif run.size():
				runs.append({"h": false, "run": run}); run = []
		if run.size():
			runs.append({"h": false, "run": run})
	if runs.is_empty():
		return null
	for u in runs:
		if u.run.size() > 3:
			return null
	return runs

func _se_place() -> bool:
	var ks := []
	for k in L.rooms.size():
		# nunca en la sala del reto: las rejas y las puertas selladas se pisaban y no se podía salir
		if k == L.start_room or k == L.end_room or (L.fount != null and k == L.fount.room) or k == int(reto.get("room", -1)):
			continue
		var gold_room := false
		for c in L.chests:
			if c.get("room") == k and c.kind == "gold":
				gold_room = true
		if not gold_room:
			ks.append(k)
	if ks.is_empty():
		return false
	for i in range(ks.size() - 1, 0, -1):
		var j := int(rnd() * (i + 1))
		var tmp = ks[i]; ks[i] = ks[j]; ks[j] = tmp
	# solo salas cuyas entradas son todas puertas normales del piso (no se crean puertas ni rejas propias)
	var k := -1
	for kk in ks:
		var o = _se_openings(kk)
		if o != null and o.all(func(u): return u.run.all(func(c): return G[c[1] * DungeonGen.GW + c[0]] == DungeonGen.DOOR)):
			k = kk
			break
	if k < 0:
		return false
	var r: Dictionary = L.rooms[k]
	# él solo: fuera los demás enemigos de la sala
	enemies = enemies.filter(func(o): return room_at_px(o.x, o.y) != k)
	var o := {"x": (r.x + r.w / 2.0) * TS, "y": (r.y + r.h / 2.0) * TS + 8}
	unstick(o, 10)
	var e := mon_spawn("soulEater", o.x, o.y)
	e.se_room = k
	# dos cofres dorados al fondo de la sala
	var free := []
	for y in range(r.y + 1, r.y + r.h - 1):
		for x in range(r.x + 1, r.x + r.w - 1):
			if G[y * DungeonGen.GW + x] != DungeonGen.FLOOR:
				continue
			var taken := false
			for c in L.chests:
				if c.cx == x and c.cy == y:
					taken = true
			if not taken:
				free.append([x, y])
	free = JS.stable_sort(free, func(a, b): return a[1] - b[1])
	var pick := []
	if free.size():
		pick.append(free[0])
		var second = null
		for c in free:
			if absi(c[0] - free[0][0]) >= 3 and c[1] <= free[0][1] + 1:
				second = c
				break
		if second == null and free.size() > 2:
			second = free[2]
		if second != null:
			pick.append(second)
	for c in pick:
		L.chests.append({"cx": c[0], "cy": c[1], "kind": "gold", "room": k, "se": true})
	return true

func _se_room_tick(e: Ent.Enemy) -> void:
	var k := e.se_room
	if not e.ms.get("blood", false):
		e.ms.blood = true
		_se_blood(k)
	var R: Dictionary = L.rooms[k]
	var ds := doors.filter(func(d): return d.room == k)
	if e.sealed and not e.dying and ds.is_empty():
		p.x = clampf(p.x, R.x * TS + 8, (R.x + R.w) * TS - 8)
		p.y = clampf(p.y, R.y * TS + 14, (R.y + R.h) * TS - 4)
	if not e.sealed and room_at_px(p.x, p.y) == k and not e.dying:
		var deep: bool = p.x > R.x * TS + 20 and p.x < (R.x + R.w) * TS - 20 and p.y > R.y * TS + 26 and p.y < (R.y + R.h) * TS - 16
		var far := true
		for d in ds:
			if JS.hypot(d.cx - p.x, d.cy - p.y) <= 46:
				far = false
		if deep and far:
			e.sealed = true
			for d in ds:
				d.open = false
				for i in d.cells:
					G[i] = DungeonGen.DOOR
			pcell = -1
			map_dirty = true
			wake(e)
			fx.banner(e.name, "Las puertas se cierran a tu espalda")
			fx.shake(6)

func _se_open(e: Ent.Enemy) -> void:
	if e.ms.get("se_open", false):
		return
	e.ms.se_open = true
	for d in doors:
		if d.room == e.se_room and not d.open:
			d.open = true
			d.open_t = 0
			for i in d.cells:
				G[i] = DungeonGen.FLOOR
			fx.burst(d.cx, d.cy, 12, ["#6a4424", "#3a2414", "#a0703a"], 14, 60)
	pcell = -1
	map_dirty = true
	fx.banner("Las puertas se abren", "Los cofres son tuyos")

## charco de sangre vieja delante de cada reja
func _se_blood(k: int) -> void:
	var room_of: PackedInt32Array = L.room_of
	var dk := func(x: float, y: float, r: float) -> void:
		for i in int(r * r * 2.4):
			var a := rnd() * 6.283
			var d := sqrt(rnd()) * r
			fx.stain(x + cos(a) * d, y + sin(a) * d * .55, SE_BLOOD[i % SE_BLOOD.size()], 2 if rnd() < .45 else 1)
	for d in doors:
		if d.room != k:
			continue
		if d.h:
			var midx: float = (d.x0 + d.x1 + 1) / 2.0 * TS
			var in_n: bool = room_of[(d.y0 - 1) * DungeonGen.GW + d.x0] == k
			var oy: float = (d.y0 + 1.6 if in_n else d.y0 - .4) * TS
			dk.call(midx, oy, 16.0)
			dk.call(midx + (rnd() - .5) * 20, oy + (14 if in_n else -14), 9.0)
		else:
			var midy: float = (d.y0 + d.y1 + 1) / 2.0 * TS
			var in_w: bool = room_of[d.y0 * DungeonGen.GW + d.x0 - 1] == k
			var ox: float = (d.x0 + 1.6 if in_w else d.x0 - .6) * TS
			dk.call(ox, midy, 16.0)
			dk.call(ox + (14 if in_w else -14), midy + (rnd() - .5) * 16, 9.0)

# ---------------- jefe: Angel of Mercy ----------------
#  3 etapas (100–66 %, 66–33 %, 33–0 %); en cada una ataca ×2 de rápido y es ×2 de difícil.
#  Combo de estocadas · picado desde el aire · lluvia de plumas (etapa 2+) · curación que se corta (una vez)
func _bf(e: Ent.Enemy) -> float:
	return BOSS_F[e.b_phase] if e.b_phase < BOSS_F.size() else 1.0

func _bt(e: Ent.Enemy, tt: float, mn: float = .35) -> float:
	return maxf(mn, tt / _bf(e))

func _boss_init(e: Ent.Enemy, id: String) -> void:
	e.boss = id
	e.bs = "idle"
	e.ms.bt = 0.0
	e.b_phase = 1
	e.ms.bcd = 1.4
	e.ms.healed = false
	e.guard_cd = INF
	e.dash_cd = 2.5
	e.hp = JS.roundi(e.max_hp * 6); e.max_hp = e.hp; e.ghost = e.hp
	e.dmg = JS.roundi(e.dmg * 2)
	e.ms.am0 = e.am
	e.ms.spd0 = e.spd
	e.arena = {"x": e.x, "y": e.y, "r": 200.0}
	e.arena_on = false
	e.no_corpse = true

func _boss_txt(e: Ent.Enemy, txt: String, col: String) -> void:
	fx.text(e.x, e.y - 90, txt, col, 13, true, 1.6, true, false)

func _boss_face(e: Ent.Enemy) -> void:
	e.face = atan2(p.y - e.y, p.x - e.x)

func _boss_walk(e: Ent.Enemy, dt: float, k: float = 1) -> void:
	var dx := p.x - e.x
	var dy := p.y - e.y
	var d := JS.hypot(dx, dy)
	if d == 0: d = 1
	mv(e, dx / d * e.spd * k * dt, dy / d * e.spd * k * dt)
	e.moving = true
	e.walk_t += dt
	_boss_face(e)

func _boss_ai(e: Ent.Enemy, dt: float, dx: float, dy: float, d: float) -> bool:
	if e.boss != "angel":
		return false
	var M := mon_def(e)
	var s: Dictionary = e.ms
	var F := _bf(e)
	e.moving = false
	if e.bs != "dash" and e.bs != "strike":
		e.vx *= pow(.001, dt)
		e.vy *= pow(.001, dt)
	mv(e, e.vx * dt, e.vy * dt)
	# sala sellada
	if not e.arena_on:
		e.arena_on = true
		var A: Dictionary = e.arena
		if JS.hypot(p.x - A.x, p.y - A.y) > A.r - 20:
			A.r = JS.hypot(p.x - A.x, p.y - A.y) + 30
		fx.banner(M.name, "La sala queda sellada")
		e.bs = "intro"
		s.bt = .9
		fx.shake(5)
		fx.burst(e.x, e.y, 30, M.boom, 40, 120)
	var A: Dictionary = e.arena
	var ax: float = p.x - A.x
	var ay: float = p.y - A.y
	var dd := JS.hypot(ax, ay)
	if dd > A.r:
		p.x = A.x + ax / dd * A.r
		p.y = A.y + ay / dd * A.r
	if p.dead:
		e.act = ""
		return true
	# aturdido: ventana de castigo
	if e.bstun > 0:
		e.bstun -= dt
		e.act = ""
		e.boss_air = false
		e.bz = 0
		if rnd() < dt * 10:
			fx.part({"x": e.x + (rnd() - .5) * 20, "y": e.y, "z": M.barH * .9 + rnd() * 8, "vx": (rnd() - .5) * 20, "vy": 0, "vz": 6, "float": true, "life": .4, "col": "#ffe9a0"})
		if e.bstun <= 0:
			e.bs = "chase"
			s.bcd = .6
		return true
	# cambio de etapa
	var want := 3 if e.hp < e.max_hp / 3.0 else (2 if e.hp < e.max_hp * 2 / 3.0 else 1)
	if want > e.b_phase and not e.boss_air and e.bs != "dive":
		e.b_phase = want
		e.bs = "roar"
		s.bt = 1.2
		e.act = ""
		e.boss_shield = true
		e.am = s.am0 * _bf(e)
		e.spd = s.spd0 * (1 + .2 * (want - 1))
		fx.banner("¡El Ángel despliega sus alas!" if want == 2 else "¡El Ángel arde en luz!", "Segunda etapa · ×2" if want == 2 else "Tercera etapa · ×4")
		fx.shake(8)
		fx.burst(e.x, e.y - 30, 46, M.boom, 60, 160)
		marks = marks.filter(func(m): return m.own != e)
		return true
	s.bcd -= dt
	e.dash_cd -= dt
	match e.bs:
		"intro", "roar":
			s.bt -= dt
			_boss_face(e)
			if rnd() < dt * 30:
				fx.part({"x": e.x + (rnd() - .5) * 50, "y": e.y, "z": rnd() * 60, "vx": 0, "vy": 0, "vz": 30, "float": true, "life": .6, "col": "#ffffff"})
			if s.bt <= 0:
				e.bs = "chase"
				e.boss_shield = false
				s.bcd = .5
		"recover":
			s.bt -= dt
			e.act = ""
			_boss_face(e)
			if s.bt <= 0:
				e.bs = "chase"
		"dash":
			s.bt -= dt
			e.act_t = s.bt
			if s.bt <= 0:
				e.bs = "chase"
				e.act = ""
				e.vx *= .2
				e.vy *= .2
			if rnd() < dt * 40:
				fx.part({"x": e.x + (rnd() - .5) * 14, "y": e.y, "z": 6 + rnd() * 30, "vx": 0, "vy": 0, "vz": 12, "float": true, "life": .35, "col": "#ffffff" if rnd() < .5 else "#a9b8d2"})
		"chase":
			e.act = ""
			if s.bcd <= 0:   # elegir ataque
				var opts := []
				if d < 95: opts.append(["combo", 4.0])
				opts.append(["dive", 3.0 if d >= 95 else 1.0])
				if e.b_phase >= 2: opts.append(["feathers", 2.0])
				if e.b_phase >= 2 and not s.healed and e.hp < e.max_hp * .4: opts.append(["heal", 5.0])
				var sum := 0.0
				for o in opts: sum += o[1]
				var r := rnd() * sum
				var pick: String = opts[0][0]
				for o in opts:
					r -= o[1]
					if r <= 0:
						pick = o[0]
						break
				_boss_start(e, pick)
				return true
			if d > 150 and e.dash_cd <= 0 and e.clear:
				e.dash_cd = 3.2 / F
				e.bs = "dash"
				s.bt = .3
				e.act = "dodge"
				e.act_t = .3
				e.dodge_t = .3
				e.dodge_a = atan2(dy, dx)
				e.face = e.dodge_a
				var v := minf(700, (d - 60) * 5.5)
				e.vx = dx / d * v
				e.vy = dy / d * v
				fx.burst(e.x, e.y, 14, M.dashFx, 10, 70)
				return true
			if d > e.reach - 6:
				_boss_walk(e, dt)
			else:
				_boss_face(e)
		"combo": _boss_combo(e, dt)
		"dive": _boss_dive(e, dt)
		"feathers": _boss_feathers(e, dt)
		"heal": _boss_heal(e, dt)
	return true

func _boss_start(e: Ent.Enemy, k: String) -> void:
	var s: Dictionary = e.ms
	e.bs = k
	s.bt = 0.0
	s.ct = 0.0
	e.act = ""
	if k == "combo":
		s.ci = 0
		s.cn = 4 if e.b_phase >= 3 else 3
		s.cph = "wind"
	elif k == "dive":
		s.cph = "up"
		e.act = "dodge"
		e.dodge_t = .45
		e.act_t = .45
		_boss_face(e)
		e.dodge_a = e.face
	elif k == "feathers":
		s.cph = "cast"
		_boss_txt(e, "Lluvia de plumas", "#e8eeff")
	elif k == "heal":
		e.chan_dmg = 0
		s.healed = true
		_boss_txt(e, "¡Se está curando! ¡Interrúmpelo!", "#9affc0")
		add_mark(e, {"kind": "heal", "x": e.x, "y": e.y, "r": 42.0, "T": 2.4})

## combo de 3 estocadas: cada una avisa con un cono en el suelo
func _boss_combo(e: Ent.Enemy, dt: float) -> void:
	var s: Dictionary = e.ms
	s.ct += dt
	if s.cph == "wind":
		var W := _bt(e, .55 if s.ci == 0 else .36, .35 if s.ci == 0 else .22)
		if s.ct < dt * 1.5:
			_boss_face(e)
			e.c_mk = add_mark(e, {"kind": "cone", "fixed": true, "x": e.x, "y": e.y, "a": e.face, "r": 72.0, "sp": 1.25, "T": W + .3 / e.am})
		e.act = "wind"
		e.wind_t = W
		e.act_t = maxf(0, W - s.ct)
		if s.ct >= W:
			s.cph = "strike"
			s.ct = 0.0
			e.act = "strike"
			e.act_t = .24 / e.am
			e.hit_done = false
			e.vx = cos(e.face) * 60
			e.vy = sin(e.face) * 60
		return
	e.act_t -= dt
	if not e.hit_done and e.act_t < .15 / e.am:
		e.hit_done = true
		var m = e.c_mk
		var inside: bool
		if m != null:
			inside = m_in_cone(m, p.x, p.y)
		else:
			var a := atan2(p.y - e.y, p.x - e.x) - e.face
			a = atan2(sin(a), cos(a))
			var dd := JS.hypot(p.x - e.x, p.y - e.y)
			inside = dd <= 82 and (absf(a) < 1.25 / 2 + .25 or dd < 18)
		if inside:
			hurt_player(e.dmg, e.x, e.y, e)
		if m != null:
			m.t = m.T
		e.c_mk = null
	if e.act_t <= 0:
		s.ci += 1
		e.act = ""
		e.vx *= .2
		e.vy *= .2
		if s.ci >= s.cn:
			e.bs = "recover"
			s.bt = .7 / _bf(e)
			s.bcd = 1.1 / _bf(e)
		else:
			s.cph = "wind"
			s.ct = 0.0

## picado: sube, una sombra te persigue y cae donde estás; al caer queda aturdido
func _boss_dive(e: Ent.Enemy, dt: float) -> void:
	var s: Dictionary = e.ms
	var M := mon_def(e)
	s.ct += dt
	if s.cph == "up":
		var k := minf(1, s.ct / .45)
		e.bz = 150 * k * k
		e.act_t = maxf(0, .45 - s.ct)
		if k > .4:
			e.boss_air = true
		if k >= 1:
			s.cph = "air"
			s.ct = 0.0
			s.tx = p.x
			s.ty = p.y
			s.dive = add_mark(e, {"kind": "dive", "x": p.x, "y": p.y, "r": 44.0, "T": _bt(e, 1.05, .55)})
		return
	if s.cph == "air":
		var T := _bt(e, 1.05, .55)
		var mk = s.get("dive")
		if mk != null and not marks.has(mk):
			mk = null
		if s.ct < T * .6 and mk != null:
			mk.x += (p.x - mk.x) * minf(1, dt * 6)
			mk.y += (p.y - mk.y) * minf(1, dt * 6)
		if mk != null:
			e.x += (mk.x - e.x) * minf(1, dt * 4)
			e.y += (mk.y - e.y) * minf(1, dt * 4)
			s.tx = mk.x
			s.ty = mk.y
		e.bz = 150
		e.act = "dodge"
		e.act_t = .2
		if s.ct >= T:
			s.cph = "fall"
			s.ct = 0.0
		return
	if s.cph == "fall":
		var k := minf(1, s.ct / .16)
		e.x = s.tx
		e.y = s.ty
		e.bz = 150 * (1 - k)
		if k >= 1:
			unstick(e, 8)
			e.bz = 0
			e.boss_air = false
			if JS.hypot(p.x - e.x, p.y - e.y) < 50:
				hurt_player(JS.roundi(e.dmg * 1.3), e.x, e.y, e)
			fx.shake(9)
			for i in 36:
				var a := i / 36.0 * 6.283
				fx.part({"x": e.x + cos(a) * 8, "y": e.y + sin(a) * 5, "z": 4, "vx": cos(a) * 180, "vy": sin(a) * 110, "vz": 10, "life": .35, "col": "#ffffff" if i % 2 else "#c8d4ec"})
			fx.burst(e.x, e.y, 30, M.boom, 30, 140)
			e.bstun = maxf(.6, BOSS_DMG_STUN / sqrt(_bf(e)))
			_boss_txt(e, "¡Aturdido!", "#ffe9a0")
			e.bs = "stun"

## lluvia de plumas (etapa 2+): círculos en el suelo y, al cabo de un momento, caen haces de luz
func _boss_feathers(e: Ent.Enemy, dt: float) -> void:
	var s: Dictionary = e.ms
	s.ct += dt
	e.act = "wind"
	e.wind_t = 1
	e.act_t = .6
	_boss_face(e)
	if s.ct < dt * 1.5:
		var nf := mini(22, JS.roundi(3 + 2 * _bf(e) * 2))
		for i in nf:
			var x := p.x
			var y := p.y
			if i:
				var a := rnd() * 6.283
				var r := 30 + rnd() * 80
				x += cos(a) * r
				y += sin(a) * r * .8
				if not fits(x, y, 6):
					continue
			add_mark(e, {"kind": "feather", "x": x, "y": y, "r": 26.0, "T": maxf(.5, .95 / sqrt(_bf(e))) + i * .04})
	if s.ct > 1.7:
		e.bs = "recover"
		s.bt = .5 / _bf(e)
		s.bcd = 1.1 / _bf(e)
		e.act = ""

func _boss_heal(e: Ent.Enemy, dt: float) -> void:
	var s: Dictionary = e.ms
	s.ct += dt
	e.act = ""
	e.moving = false
	_boss_face(e)
	if rnd() < dt * 30:
		var a := rnd() * 6.283
		fx.part({"x": e.x + cos(a) * 40, "y": e.y + sin(a) * 16, "z": 4, "vx": -cos(a) * 40, "vy": -sin(a) * 16, "vz": 40, "float": true, "life": .6, "col": "#bfffd8"})
	if e.chan_dmg >= e.max_hp * .08:
		for m in marks:
			if m.own == e and m.kind == "heal":
				m.t = m.T + 1
		_boss_txt(e, "¡Interrumpido!", "#ffe9a0")
		e.bstun = 1.3
		e.bs = "stun"
		return
	if s.ct >= 2.4:
		var h := JS.roundi(e.max_hp * .25)
		e.hp = minf(e.max_hp, e.hp + h)
		fx.text(e.x, e.y - 70, "+" + str(h), "#7fffb0", 14, true, 1.4, false, false)
		fx.burst(e.x, e.y - 30, 30, ["#ffffff", "#bfffd8", "#7fe0a0"], 30, 90)
		e.bs = "recover"
		s.bt = .4 / _bf(e)
		s.bcd = .8 / _bf(e)

## muerte del jefe: cofre de jefe y fin de la sala sellada
func _boss_death(e: Ent.Enemy) -> void:
	e.arena_on = false
	marks = marks.filter(func(m): return m.own != e)
	fx.banner(mon_def(e).name + " derrotado", "Ha dejado un cofre")
	var o := {"x": e.x, "y": e.y}
	unstick(o, 10)
	chests.append({"cx": cell_of(o.x), "cy": cell_of(o.y), "kind": "gold", "boss": true, "room": null, "se": false, "x": o.x, "y": o.y, "open": false, "open_t": 0.0, "best": 0, "guards": [], "msg_t": -9.0})
	fx.burst(o.x, o.y - 10, 24, ["#ffffff", "#ffd25a", "#c8d4ec"], 20, 90)

## lo que cambia el daño que recibe un enemigo (rnHit de la web, sin runas): Expuesto, jefe en el aire, aturdido, curándose
func dmg_mod(e: Ent.Enemy, dmg: float) -> float:
	e.escudo_t = 0.0
	if e.escudo > 0 and dmg > 0:
		var ab := minf(e.escudo, dmg)
		e.escudo -= ab
		dmg -= ab
		if e.escudo <= 0:
			fx.burst(e.x, e.y, 30, ["#bfe4ff", "#6ab4ff", "#ffffff"], 18, 110)
			fx.sonido(&"escudo_roto", e.x, e.y)
		if dmg <= 0:
			fx.text(e.x, e.y - 52, "escudo", "#7cc4ff", 9)
			return 0.0
	if e.cs == "tired":
		dmg = JS.round(dmg * 1.5)
	if e.boss != "":
		if e.boss_air or e.boss_shield:
			return 0
		if e.bstun > 0:
			dmg = JS.round(dmg * 1.6)
		if e.bs == "heal":
			e.chan_dmg += dmg
	return dmg

func _stamp_corpse(e: Ent.Enemy) -> void:
	var x := JS.round(e.x)
	var y := JS.round(e.y)
	if e.mon != "":
		if mon_def(e).herir == "sangre":
			fx.pool(x, y - 3, 18)
	else:
		fx.pool(x, y - 3, 22 if e.type == "champ" else 15)
	if JS.hypot(x - CX, y - CY) < FRAD + 8:
		return
	var c := {"x": x, "y": y, "face": e.face, "champ": e.type == "champ", "rare": e.rare and e.hero == "", "hero": e.hero, "mon": e.mon}
	if e.hero != "minion":
		corpses.append(c)
	fx.corpse(c)

## rastro de sangre según la vida que queda
func _blood_trail(o, f: float, dt: float) -> void:
	var rate := 0.0
	var sz := 1
	var spread := 8.0
	if f < .1:
		rate = 80; sz = 2; spread = 16
	elif f < .3:
		rate = 32; sz = 1; spread = 12
	elif f < .5 and o != p:
		rate = 5
	var n := rate * dt
	var k := int(floorf(n)) + (1 if rnd() < fmod(n, 1.0) else 0)
	while k > 0:
		k -= 1
		fx.stain(o.x + (rnd() - .5) * spread, o.y + (rnd() - .5) * spread * .4, BLOOD[int(rnd() * 4)], sz + 1 if rnd() < .4 else sz)
	if f < .3 and rnd() < dt * (7 if f < .1 else 2.5):
		var bx: float = o.x + (rnd() - .5) * spread * .6
		var by: float = o.y + (rnd() - .5) * 4
		var m := 9 if f < .1 else 5
		for i in m:
			fx.stain(bx + (rnd() - .5) * (7 if f < .1 else 5), by + (rnd() - .5) * 3, BLOOD[i % 4], 2)
	if f < .1 and rnd() < dt * 9:
		fx.bleed(o.x, o.y, 14 + rnd() * 10, rnd() * 6.283, 2, 30, 1.6)
	elif f < .3 and rnd() < dt * 2:
		fx.bleed(o.x, o.y, 12, rnd() * 6.283, 1, 25, 1.4)

# ---------------- recoger, abrir, beber ----------------
func _update_pickups(dt: float) -> void:
	for k in pickups:
		k.t -= dt
		if k.no_pick > 0:
			k.no_pick -= dt
			continue
		if not p.dead and JS.hypot(k.x - p.x, k.y - p.y) < 12:
			if Items.add_potion(p):
				k.t = 0
				fx.text(p.x, p.y - 50, "+1 poción", "#ff8a7a", 10, false, 1, false, false)
				fx.burst(k.x, k.y, 8, ["#ff4a3a", "#ffd0c0"], 8, 50)
				fx.hud()
			else:
				_bag_full_msg()
	var keep := []
	for k in pickups:
		if k.t > 0:
			keep.append(k)
	pickups = keep
	# el oro del suelo se recoge al pasar; el que sueltan los enemigos, con la tecla de usar
	if not p.dead:
		for i in range(gold.size() - 1, -1, -1):
			var g: Dictionary = gold[i]
			if not g.manual and JS.hypot(g.x - p.x, g.y - p.y) < 16:
				take_gold(g)
	for d in doors:
		if d.open:
			d.open_t += dt

func drink_potion(which = null) -> void:
	if p.dead:
		return
	if Items.potion_count(p) <= 0:
		if not (p.no_pot_t > t - .8):
			p.no_pot_t = t
			fx.text(p.x, p.y - 50, "Sin pociones", "#ff8a7a", 10)
		return
	if p.hp >= p.st.maxHp:
		if not (p.no_pot_t > t - .8):
			p.no_pot_t = t
			fx.text(p.x, p.y - 50, "Vida llena", "#ff8a7a", 10)
		return
	if pot_wait() > 0:
		if not (p.no_pot_t > t - .8):
			p.no_pot_t = t
			fx.text(p.x, p.y - 50, "Espera %.1f s" % pot_wait(), "#ff8a7a", 10)
		return
	# se bebe la de más abajo de la mochila, o la que se ha pulsado
	var pot = which
	if pot == null:
		for it in p.bag:
			if it.slot == "potion" and (pot == null or it.gy > pot.gy or (it.gy == pot.gy and it.gx > pot.gx)):
				pot = it
	pot.n = int(pot.get("n", 1)) - 1
	if pot.n <= 0:
		Items.bag_del(p, pot)
	p.pot_t = t
	if not runes.rv("dragonBlood"):
		heal(p, p.st.potionHeal, "#ff8a7a", 12)
	runes.on_potion()
	fx.burst(p.x, p.y, 18, ["#ff4a3a", "#ff8a7a", "#ffd0c0"], 14, 70)
	for i in 10:
		fx.part({"x": p.x + (rnd() - .5) * 14, "y": p.y, "z": 4 + rnd() * 20, "vx": 0, "vy": 0, "vz": 30, "float": true, "life": .6, "col": "#ff4a3a" if rnd() < .5 else "#ffb0a0"})
	fx.hud()

## segundos que faltan para poder beber otra poción
const POT_CD := 3.0

func pot_wait() -> float:
	return maxf(0, p.pot_t + POT_CD - t)

func take_gold(g: Dictionary) -> void:
	var amt := JS.roundi(g.amt * p.st.goldMul)
	p.gold += amt
	gold.erase(g)
	fx.sonido(&"oro", p.x, p.y)
	fx.text(p.x, p.y - 50, "+%d oro" % amt, "#ffd25a", 11, false, 1.1, false, false)
	if runes.rv("goldHand"):
		heal(p, 3 * runes.rv("goldHand"), "#ffd25a", 9)
	fx.burst(g.x, g.y, 8, ["#ffd25a", "#fff3c0", "#c9962a"], 6, 50)
	fx.hud()

func room_at_px(x: float, y: float) -> int:
	var cx := cell_of(x)
	var cy := cell_of(y - 3)
	return -1 if (cx < 0 or cy < 0 or cx >= DungeonGen.GW or cy >= DungeonGen.GH) else L.room_of[cy * DungeonGen.GW + cx]

## enemigos que impiden abrir: los de tu sala, o los cercanos si estás en un pasillo
func blockers() -> int:
	if runes.rv("brokenDoor"):
		return 0
	var k := room_at_px(p.x, p.y)
	var n := 0
	for e in enemies:
		if e.dying:
			continue
		var ek := room_at_px(e.x, e.y)
		if (ek == k) if k >= 0 else (ek < 0 and JS.hypot(e.x - p.x, e.y - p.y) < 220):
			n += 1
	return n

func open_door(d: Dictionary) -> void:
	var n := blockers()
	if n > 0:
		if not (d.msg_t > t - .8):
			d.msg_t = t
			fx.text(d.cx, d.cy - 40, "Queda 1 enemigo" if n == 1 else "Quedan %d enemigos" % n, "#ff9a6a", 10, false, 1.1, false, false)
		return
	d.open = true
	d.open_t = 0
	for i in d.cells:
		G[i] = DungeonGen.FLOOR
	pcell = -1
	map_dirty = true
	fx.burst(d.cx, d.cy, 12, ["#6a4424", "#3a2414", "#a0703a"], 14, 60)

## «Usar» (espacio): lo más cercano de puerta, llave, oro o cofre
func interact() -> void:
	if p.dead:
		return
	var opts := []
	var c = nearest_chest()
	if c != null:
		opts.append({"d": JS.hypot(c.x - p.x, (c.y - 6) - p.y) * .8, "f": func(): try_open_chest(c)})
	var l = nearest_loot()
	if l != null:
		opts.append({"d": JS.hypot(l.x - p.x, l.y - p.y) * .7, "f": func(): try_pickup(l)})
	var rb = rompible_cerca()
	if rb != null:
		opts.append({"d": JS.hypot(rb.x - p.x, rb.y - p.y), "f": func(): _romper(rb)})
	for dr in doors:
		if dr.open:
			continue
		var dd := JS.hypot(dr.cx - p.x, dr.cy - (p.y - 6))
		if dd < DOOR_R:
			opts.append({"d": dd, "f": func(): open_door(dr)})
	var ps = secreta_cerca()
	if ps != null:
		opts.append({"d": ps.d * .9, "f": func(): _pedir_secreta(ps)})
	for k in keyrings:
		if k.taken:
			continue
		var dd := JS.hypot(k.x - p.x, (k.cy * TS + 10) - p.y)
		if dd < KEY_R:
			opts.append({"d": dd * .8, "f": func(): _take_key(k)})
	for k in floor_keys:
		var dd := JS.hypot(k.x - p.x, k.y - p.y)
		if dd < KEY_R:
			opts.append({"d": dd * .7, "f": func(): _take_floor_key(k)})
	var kt = nearest_key_table()
	if kt != null:
		opts.append({"d": JS.hypot(kt.x - p.x, kt.y - p.y) * .8, "f": func(): _take_key_table(kt)})
	for g in gold:
		if not g.manual:
			continue
		var dd := JS.hypot(g.x - p.x, g.y - p.y)
		if dd < GOLD_R:
			opts.append({"d": dd * .75, "f": func(): take_gold(g)})
	if not opts.size():
		return
	opts = JS.stable_sort(opts, func(a, b): return a.d - b.d)
	opts[0].f.call()

func _take_key(k: Dictionary) -> void:
	k.taken = true
	p.keys += 1
	fx.text(p.x, p.y - 50, "+1 llave", "#e8d8a0", 11, false, 1.1, false, false)
	fx.burst(k.x, k.top + 10, 8, ["#e8d8a0", "#9a9aa6"], 6, 40)
	fx.hud()

const KEY_TABLE_R := 34.0

func nearest_key_table() -> Variant:
	var best = null
	var bd := KEY_TABLE_R
	for k in key_tables:
		if k.taken:
			continue
		var d := JS.hypot(k.x - p.x, k.y - p.y)
		if d < bd:
			bd = d
			best = k
	return best

## la mesita de las llaves da una llave; la mesa con mantel, un puñado de oro
func _take_key_table(k: Dictionary) -> void:
	k.taken = true
	k.o["taken"] = true
	map_dirty = true
	if k.oro:
		var amt := JS.roundi((10 + rnd() * 15) * (1 + wave * .1))
		p.gold += amt
		fx.sonido(&"oro", p.x, p.y)
		fx.text(p.x, p.y - 50, "+%d oro" % amt, "#ffd25a", 11, false, 1.1, false, false)
		fx.burst(k.x, k.o.cy * TS + 8, 8, ["#ffd25a", "#fff3c0"], 6, 40)
	else:
		p.keys += 1
		fx.text(p.x, p.y - 50, "+1 llave", "#e8d8a0", 11, false, 1.1, false, false)
		fx.burst(k.x, k.o.cy * TS + 8, 8, ["#e8d8a0", "#9a9aa6"], 6, 40)
	fx.hud()

func _take_floor_key(k: Dictionary) -> void:
	floor_keys.erase(k)
	p.keys += 1
	fx.text(p.x, p.y - 50, "+1 llave", "#e8d8a0", 11, false, 1.1, false, false)
	fx.hud()

## ¿hay algo que usar cerca? (para el aviso de la tecla)
func can_interact() -> bool:
	if p.dead:
		return false
	if nearest_chest() != null or nearest_loot() != null or rompible_cerca() != null:
		return true
	for dr in doors:
		if not dr.open and JS.hypot(dr.cx - p.x, dr.cy - (p.y - 6)) < DOOR_R:
			return true
	for k in keyrings:
		if not k.taken and JS.hypot(k.x - p.x, (k.cy * TS + 10) - p.y) < KEY_R:
			return true
	for k in floor_keys:
		if JS.hypot(k.x - p.x, k.y - p.y) < KEY_R:
			return true
	if nearest_key_table() != null or secreta_cerca() != null:
		return true
	for g in gold:
		if g.manual and JS.hypot(g.x - p.x, g.y - p.y) < GOLD_R:
			return true
	return false


# ======================================================================
#  élites con poder, jefe del piso y escalera cerrada (vista 3D, 8 nov 2026)
# ======================================================================
const GRUPO_MIN := 5
const GRUPO_MAX := 10
const COL_GOLPE := "#f4ead8"     # daño normal
## distancia a la que un enemigo dormido te ve (con línea de visión) o te nota sin verte;
## a la mitad que en la web (antes 200 y 70), decidido por Diego el 10 nov
const VISTA_PX := 100.0
const OIDO_PX := 35.0
const COL_CRIT := "#ffc83a"      # crítico: grande y amarillo
const COL_RECIBIDO := "#ff2a1a"  # lo que recibe el héroe
const PODERES := ["rapido", "escudo", "explota", "invoca"]
const PODER_N := {"rapido": "Veloz", "escudo": "Escudo de daño", "explota": "Explota al morir", "invoca": "Invocador"}
## monstruo que hace de jefe en cada piso (los que tienen modelo 3D), por orden; el piso 5, 10… es el campeón
const JEFES := [
	{"id": "demonCaptain", "n": "Gorvath, Señor del Abismo", "siervo": "miniDemon"},
	{"id": "esqueleto", "n": "El Rey Osario", "siervo": "esqueleto"},
	{"id": "middleDemon", "n": "Mórgal el Devorador", "siervo": "miniDemon"},
	{"id": "firedemon", "n": "Ignaroth, la Llama Viva", "siervo": "miniDemon"},
	{"id": "bufona", "n": "La Bufona Loca", "siervo": "esqueleto"},
]
const JEFE_VIDA := 7.0
const JEFE_DANO := 1.4
const ONDA_R := 95.0       # px
const ONDA_AVISO := .9     # s
const EXPLOTA_R := 70.0
const EXPLOTA_AVISO := 1.0
var bombas: Array = []     # golpes en área con aviso: {x, y, r, t, dmg, own, col, snd}
var _aviso_escalera_t := -9.0
## si es true, pisar la escalera sin jefe devuelve "escalera" en step() en lugar de bajar (la vista pregunta)
var preguntar_escalera := false
var _escalera_pedida := false
## oro que llevaba el héroe al salir de Inca: al morir en la mazmorra vuelve a tener solo eso
var oro_salida := 0

## el jefe del piso que sigue vivo (o null)
func jefe_vivo() -> Ent.Enemy:
	for e in enemies:
		if e.jefe and not e.dying and not e.dead:
			return e
	return null

## qué sale al golpear: "sangre", "hueso" o "brasas" (según la ficha del monstruo)
func herir_de(e: Ent.Enemy) -> String:
	if e.mon == "":
		return "sangre"
	var M := mon_def(e)
	if M.get("herir", "") == "hueso":
		return "hueso"
	if (M.get("parts", []) as Array).has("brasas"):
		return "brasas"
	return "sangre"

func _herida(e: Ent.Enemy, ang: float, n: int, spd: float, spread: float = .9, z: float = 16) -> void:
	var h := herir_de(e)
	if h == "sangre":
		fx.bleed(e.x, e.y, z, ang, n, spd, spread)
	else:
		fx.esquirlas(e.x, e.y, z, ang, n, spd, h)

## élite de un grupo: más grande, más vida y daño, nombre y un poder al azar
func _hacer_elite(e: Ent.Enemy) -> void:
	e.rare = true
	e.elite = true
	e.hp = JS.roundi(e.hp * 2.5); e.max_hp = e.hp; e.ghost = e.hp
	e.dmg = JS.roundi(e.dmg * 1.5)
	e.score *= 5
	e.xp = JS.roundi(e.xp * 3)
	if e.mon != "":
		e.title = e.name
	else:
		var used := {}
		for o in enemies:
			if o.rare and o != e:
				used[o.title] = true
		var free := KNIGHTS.filter(func(nm): return not used.has(nm))
		var pool: Array = free if free.size() else KNIGHTS
		e.title = pool[int(rnd() * pool.size())]
	_dar_poder(e)

func _dar_poder(e: Ent.Enemy) -> void:
	e.poder = PODERES[int(rnd() * PODERES.size())]
	match e.poder:
		"rapido":
			e.spd *= 1.45
			e.wind_t /= 1.25
			e.am *= 1.25
		"escudo":
			e.escudo_max = e.max_hp * .35
			e.escudo = e.escudo_max
		"invoca":
			e.invoca_t = 2.5

func _hacer_jefe(e: Ent.Enemy, nombre: String) -> void:
	e.jefe = true
	e.rare = true
	if nombre != "":
		e.title = nombre
	e.hp = JS.roundi(e.hp * JEFE_VIDA); e.max_hp = e.hp; e.ghost = e.hp
	e.dmg = JS.roundi(e.dmg * JEFE_DANO)
	e.score *= 8
	e.xp = JS.roundi(e.xp * 6)
	e.onda_t = 3.0
	e.guard_cd = INF   # no se cubre: se le pega

## jefe del piso: el monstruo de JEFES que toca, delante de la escalera
func _jefe_piso(w: int) -> void:
	var J: Dictionary = JEFES[(w - 1) % JEFES.size()]
	var st: Dictionary = L.stairs_px
	var r: Dictionary = L.rooms[L.end_room]
	var rcx: float = (r.x + r.w / 2.0) * TS
	var rcy: float = (r.y + r.h / 2.0) * TS
	var dd := maxf(1.0, JS.hypot(rcx - st.x, rcy - st.y))
	var o := {"x": st.x + (rcx - st.x) / dd * 60, "y": st.y + (rcy - st.y) / dd * 60 + 10}
	if tile_at(cell_of(o.x), cell_of(o.y)) == DungeonGen.DOWN:
		o.y += 48
	unstick(o, 12)
	var e := mon_spawn(J.id, o.x, o.y)
	_hacer_jefe(e, J.n)

func _siervo_de(e: Ent.Enemy) -> String:
	for J in JEFES:
		if J.id == e.mon:
			return J.siervo
	return "esqueleto"

func _invocar(e: Ent.Enemy, id: String, n: int) -> void:
	for i in n:
		var a := rnd() * TAU
		var o := {"x": e.x + cos(a) * 34, "y": e.y + sin(a) * 26}
		unstick(o, 8)
		if not fits(o.x, o.y, 8):
			continue
		var s := mon_spawn(id, o.x, o.y)
		s.invocador = e
		s.xp = JS.roundi(s.xp * .3)
		s.score = JS.roundi(s.score * .3)
		s.state = "chase"
		s.cool = .4 + rnd() * .3
		fx.burst(o.x, o.y, 6, ["#c890ff", "#7a3aff", "#2a1040"], 14, 60)
	fx.sonido(&"invocar", e.x, e.y)

func _siervos_vivos(e: Ent.Enemy) -> int:
	var n := 0
	for o in enemies:
		if o.invocador == e and not o.dying:
			n += 1
	return n

## lo que hacen cada fotograma las élites con poder y el jefe, y los golpes en área con aviso
func _poderes_tick(dt: float) -> void:
	for e in enemies:
		if e.dying or e.dead:
			continue
		if e.escudo_max > 0:
			e.escudo_t += dt
			if e.escudo_t > 5.0 and e.escudo < e.escudo_max:
				if e.escudo <= 0:
					fx.text(e.x, e.y - 60, "escudo", "#7cc4ff", 10)
				e.escudo = e.escudo_max
		if e.state == "idle":
			continue
		if e.poder == "invoca":
			e.invoca_t -= dt
			if e.invoca_t <= 0:
				e.invoca_t = 7.0
				if _siervos_vivos(e) < 6:
					_invocar(e, "esqueleto", 2)
		if e.jefe:
			if not e.jefe_mitad and e.hp < e.max_hp * .5:
				e.jefe_mitad = true
				fx.banner(e.title + " llama a sus siervos", "")
				_invocar(e, _siervo_de(e), 4)
			e.onda_t -= dt
			if e.onda_t <= 0 and JS.hypot(e.x - p.x, e.y - p.y) < 220:
				e.onda_t = 6.5
				e.cool = maxf(e.cool, ONDA_AVISO + .3)   # tarda en volver a atacar mientras carga la onda
				fx.aviso(e.x, e.y, ONDA_R, ONDA_AVISO, "#ff3a1a")
				fx.sonido(&"carga", e.x, e.y)
				bombas.append({"x": e.x, "y": e.y, "r": ONDA_R, "t": ONDA_AVISO, "dmg": e.dmg * 1.6, "own": e, "col": ["#fff0c0", "#ff7a2a", "#ff2a10"], "snd": &"onda"})
	for i in range(bombas.size() - 1, -1, -1):
		var b: Dictionary = bombas[i]
		b.t -= dt
		if b.t > 0:
			continue
		bombas.remove_at(i)
		fx.burst(b.x, b.y, 10, b.col, 40, 220)
		fx.shake(10)
		fx.sonido(b.snd, b.x, b.y)
		if not p.dead and JS.hypot(p.x - b.x, p.y - b.y) < b.r:
			var src = b.own if is_instance_valid(b.own) and not b.own.dead else null
			hurt_player(b.dmg, b.x, b.y, src, "area")
		_romper_en(b.x, b.y, b.r)
		# la explosión también hace daño a los enemigos de alrededor
		if b.own == null:
			for o in enemies.duplicate():
				if not o.dying and JS.hypot(o.x - b.x, o.y - b.y) < b.r:
					o.hp -= b.dmg * .5
					if o.hp <= 0:
						kill_enemy(o, atan2(o.y - b.y, o.x - b.x))

## al morir: la élite inestable deja una explosión con aviso; el jefe, el cofre grande y la escalera libre
func _muere_poder(e: Ent.Enemy) -> void:
	if e.poder == "explota":
		fx.aviso(e.x, e.y, EXPLOTA_R, EXPLOTA_AVISO, "#ff8a1a")
		fx.sonido(&"carga", e.x, e.y)
		bombas.append({"x": e.x, "y": e.y, "r": EXPLOTA_R, "t": EXPLOTA_AVISO, "dmg": e.dmg * 2.0, "own": null, "col": ["#fff0a0", "#ffa020", "#ff4a10", "#3a2414"], "snd": &"explosion"})
	if e.jefe:
		fx.banner(e.title + " ha caído", "La escalera está libre")
		fx.sonido(&"jefe_muere", e.x, e.y)
		hitstop = maxf(hitstop, .25)
		fx.shake(14)
		var o := {"x": e.x, "y": e.y + 20}
		unstick(o, 12)
		chests.append({"cx": cell_of(o.x), "cy": cell_of(o.y), "kind": "gold", "boss": true, "grande": true, "room": null, "se": false, "x": o.x, "y": o.y, "open": false, "open_t": 0.0, "best": 0, "guards": [], "msg_t": -9.0})
		fx.burst(o.x, o.y - 10, 24, ["#ffffff", "#ffd25a", "#c8d4ec"], 30, 110)
		# los siervos que queden se deshacen
		for s in enemies.duplicate():
			if s.invocador == e and not s.dying:
				kill_enemy(s, 0.0)


# ======================================================================
#  mazmorra (tanda 3, 8 nov 2026): rompibles, mímico, reto de oleadas y trampas
# ======================================================================
const MIMICO_R := 38.0
## al acercarse (o al intentar abrirlo), el mímico muerde y se convierte en enemigo
func _morder(c: Dictionary) -> void:
	c.open = true
	chests.erase(c)
	G[c.cy * DungeonGen.GW + c.cx] = DungeonGen.FLOOR
	map_dirty = true
	pcell = -1
	var e := spawn_enemy("slayer", c.x, c.y - 2)
	e.rare = false
	e.mimic = true
	e.title = "Mímico"
	e.hp *= 2; e.max_hp *= 2; e.ghost *= 2
	e.dmg = JS.round(e.dmg * 1.3)
	wake(e)
	total += 1
	hurt_player(JS.round(p.st.maxHp * .15), c.x, c.y - 2, e)
	fx.shake(8)
	fx.burst(c.x, c.y - 8, 12, ["#7a1a1a", "#d0d0da", "#5a3216"], 16, 80)
	fx.banner("¡Era un mímico!", "Te ha mordido")
	fx.sonido(&"mimico", c.x, c.y)

# ---------- rompibles: barriles, cajas y urnas ----------
var rompibles: Array = []   # {x, y, kind: barril|caja|urna, roto, giro}
const ROMPIBLE_R := 20.0
const ROMPIBLES := ["barril", "caja", "urna"]

func rompible_cerca() -> Variant:
	var best = null
	var bd := ROMPIBLE_R + 8
	for r in rompibles:
		if r.roto:
			continue
		var d := JS.hypot(r.x - p.x, r.y - p.y)
		if d < bd:
			bd = d
			best = r
	return best

func _romper_golpe(cx: float, cy: float) -> void:
	for r in rompibles:
		if r.roto:
			continue
		var dx: float = r.x - cx
		var dy: float = (r.y - 14) - cy
		var d := JS.hypot(dx, dy)
		if d > p.st.range + 14:
			continue
		var da := atan2(dy, dx) - p.face
		da = atan2(sin(da), cos(da))
		if absf(da) < 1.5 or d < 16:
			_romper(r)

func _romper_en(x: float, y: float, rad: float) -> void:
	for r in rompibles:
		if not r.roto and JS.hypot(r.x - x, r.y - y) < rad:
			_romper(r)

## se rompe: siempre algo de oro, a veces una poción y, rara vez, un esqueleto que salta de dentro
func _romper(r: Dictionary) -> void:
	if r.roto:
		return
	r.roto = true
	fx.esquirlas(r.x, r.y, 10, -PI / 2, 18, 110, "barro" if r.kind == "urna" else "madera")
	fx.sonido(&"romper_urna" if r.kind == "urna" else &"romper_madera", r.x, r.y)
	drop_gold(r.x, r.y + 4, (2 + rnd() * 6) * (1 + wave * .12), true)
	var tirada := rnd()
	if tirada < .06:
		var e := mon_spawn("esqueleto", r.x, r.y + 2)
		e.state = "chase"
		e.cool = .5
		total += 1
		fx.text(r.x, r.y - 50, "¡Estaba dentro!", "#ff9a3a", 11, false, 1.2, false, false)
	elif tirada < .18:
		var v := safe_spot(r.x + (rnd() - .5) * 20, r.y + 10, Vector2(r.x, r.y))
		pickups.append({"x": v.x, "y": v.y, "t": 1e9, "bob": rnd() * 6, "no_pick": 0.0})

func _rompibles_init(_w: int) -> void:
	rompibles = []
	var dist: PackedInt32Array = L.dist
	for k in L.rooms.size():
		if k == L.start_room:
			continue
		var r: Dictionary = L.rooms[k]
		var n := 3 + int(rnd() * 4)
		var pared := []   # casillas del borde de la sala que tocan muro
		for cy in range(r.y, r.y + r.h):
			for cx in range(r.x, r.x + r.w):
				var i: int = cy * DungeonGen.GW + cx
				if G[i] != DungeonGen.FLOOR or dist[i] <= 4:
					continue
				var junto := false
				var puerta := false
				for d4 in DungeonGen.D4:
					var t2 := tile_at(cx + d4[0], cy + d4[1])
					if t2 == DungeonGen.DOOR:
						puerta = true
					if DungeonGen.is_solid(t2) and t2 != DungeonGen.DOOR:
						junto = true
				if junto and not puerta:
					pared.append(Vector2i(cx, cy))
		for j in range(pared.size() - 1, 0, -1):
			var q := int(rnd() * (j + 1))
			var tmp = pared[j]; pared[j] = pared[q]; pared[q] = tmp
		var puestos := 0
		for c in pared:
			if puestos >= n:
				break
			var x: float = (c.x + .5) * TS + (rnd() - .5) * 8
			var y: float = (c.y + .5) * TS + 8 + (rnd() - .5) * 6
			if not fits(x, y, 9):
				continue
			var cerca := false
			for o in rompibles:
				if JS.hypot(o.x - x, o.y - y) < 18:
					cerca = true
					break
			for ch in chests:
				if JS.hypot(ch.x - x, ch.y - y) < 30:
					cerca = true
			if cerca or JS.hypot(x - L.stairs_px.x, y - L.stairs_px.y) < 50:
				continue
			# a veces van de dos o tres juntos
			var kind: String = ROMPIBLES[int(rnd() * 3)]
			rompibles.append({"x": x, "y": y, "kind": kind, "roto": false, "giro": rnd() * TAU})
			puestos += 1

# ---------- reto de oleadas: una sala por piso ----------
var reto := {}   # {room, estado: espera|activo|hecho, ola, t, salidas: [i], viejas: [t]}
const RETO_OLAS := [6, 9, 12]

func _elegir_reto() -> void:
	reto = {}
	if L.has("prueba") or L.has("ciudad"):
		return
	var mejor := -1
	var ks := []
	for k in L.rooms.size():
		var r: Dictionary = L.rooms[k]
		if k == L.start_room or k == L.end_room or (L.fount != null and k == L.fount.room):
			continue
		if r.w >= 7 and r.h >= 6:
			ks.append(k)
	if ks.is_empty():
		return
	mejor = ks[int(rnd() * ks.size())]
	reto = {"room": mejor, "estado": "espera", "ola": 0, "t": 0.0, "salidas": [], "viejas": []}

func _reto_tick(dt: float) -> void:
	if reto.is_empty() or reto.estado == "hecho" or p.dead:
		return
	var r: Dictionary = L.rooms[reto.room]
	if reto.estado == "espera":
		var cx := cell_of(p.x)
		var cy := cell_of(p.y - 3)
		if cx > r.x and cx < r.x + r.w - 1 and cy > r.y and cy < r.y + r.h - 1:
			_reto_empezar(r)
		return
	# activo: cuando caen todos los de la oleada, la siguiente (o el premio)
	reto.t += dt
	var vivos := 0
	for e in enemies:
		if e.reto and not e.dying and not e.dead:
			vivos += 1
	if vivos == 0 and reto.t > 1.5:
		if reto.ola < RETO_OLAS.size():
			_reto_ola(r)
		else:
			_reto_fin(r)

func _reto_empezar(r: Dictionary) -> void:
	reto.estado = "activo"
	reto.t = 0.0
	# se cierran las rejas: cada casilla de paso que sale de la sala queda bloqueada
	var sal := []
	var viejas := []
	for cy in range(r.y - 1, r.y + r.h + 1):
		for cx in range(r.x - 1, r.x + r.w + 1):
			var borde: bool = cx == r.x - 1 or cy == r.y - 1 or cx == r.x + r.w or cy == r.y + r.h
			if not borde:
				continue
			var t2 := tile_at(cx, cy)
			if t2 == 0 or (DungeonGen.is_solid(t2) and t2 != DungeonGen.DOOR):
				continue
			var i: int = cy * DungeonGen.GW + cx
			sal.append(i)
			viejas.append(G[i])
			G[i] = DungeonGen.PILLAR
	reto.salidas = sal
	reto.viejas = viejas
	pcell = -1
	map_dirty = true
	fx.banner("¡Emboscada! Aguanta 3 olas", "Se cierran las rejas")
	fx.sonido(&"rejas", p.x, p.y)
	fx.shake(6)

func _reto_ola(r: Dictionary) -> void:
	var n: int = RETO_OLAS[reto.ola]
	reto.ola += 1
	reto.t = 0.0
	fx.banner("Ola %d de %d" % [reto.ola, RETO_OLAS.size()], "")
	fx.sonido(&"invocar", p.x, p.y)
	var hechos: Array[Ent.Enemy] = []
	for i in n:
		for intento in 20:
			var c = _rand_cell_in(r)
			if c == null or JS.hypot(c.x - p.x, c.y - p.y) < 70:
				continue
			var e := mon_spawn("esqueleto", c.x, c.y) if rnd() < .45 else spawn_enemy(enemy_type_for(wave), c.x, c.y)
			e.reto = true
			e.state = "chase"
			e.cool = .6 + rnd() * .6
			fx.burst(c.x, c.y, 8, ["#5a2a90", "#2a1040", "#c890ff"], 12, 60)
			hechos.append(e)
			total += 1
			break
	if reto.ola == RETO_OLAS.size() and hechos.size():
		_hacer_elite(hechos[0])
		fx.banner("Ola %d de %d" % [reto.ola, RETO_OLAS.size()], "Con " + hechos[0].title)

func _reto_fin(r: Dictionary) -> void:
	reto.estado = "hecho"
	var sal: Array = reto.salidas
	for k in sal.size():
		G[sal[k]] = reto.viejas[k]
	pcell = -1
	map_dirty = true
	fx.banner("¡Reto superado!", "Ha aparecido un cofre dorado")
	fx.sonido(&"reto", p.x, p.y)
	var o := {"x": (r.x + r.w / 2.0) * TS, "y": (r.y + r.h / 2.0) * TS + 10}
	unstick(o, 12)
	chests.append({"cx": cell_of(o.x), "cy": cell_of(o.y), "kind": "gold", "reto": true, "grande": true, "room": null, "se": false, "x": o.x, "y": o.y, "open": false, "open_t": 0.0, "best": 0, "guards": [], "msg_t": -9.0})
	fx.burst(o.x, o.y - 10, 24, ["#ffffff", "#ffd25a", "#c8d4ec"], 30, 110)

## ¿la casilla i es una reja cerrada del reto? (para la vista)
func rejas_cerradas() -> Array:
	return reto.get("salidas", []) if not reto.is_empty() and reto.estado == "activo" else []

# ---------- trampas de pinchos y de fuego en los pasillos ----------
var trampas: Array = []   # {x, y, kind: pinchos|fuego, estado: listo|aviso|activa|recarga, t, tick}
const TRAMPA_R := 15.0
const TRAMPA_AVISO := .5
var _trampa_scan := 0.0

func _trampas_init(w: int) -> void:
	trampas = []
	var dist: PackedInt32Array = L.dist
	var corr: PackedByteArray = L.corr
	var cand := []
	for i in DungeonGen.GW * DungeonGen.GH:
		if corr[i] and G[i] == DungeonGen.FLOOR and dist[i] > 10:
			cand.append(i)
	var n := mini(12, (3 + mini(5, w)) * DungeonGen.escala())
	while n > 0 and cand.size():
		var i: int = cand.pop_at(int(rnd() * cand.size()))
		var x := (i % DungeonGen.GW + .5) * TS
		var y := (i / DungeonGen.GW + .5) * TS + 6
		var cerca := false
		for o in trampas:
			if JS.hypot(o.x - x, o.y - y) < TS * 4:
				cerca = true
				break
		if cerca:
			continue
		trampas.append({"x": x, "y": y, "cx": i % DungeonGen.GW, "cy": i / DungeonGen.GW, "kind": "fuego" if rnd() < .4 else "pinchos", "estado": "listo", "t": 0.0, "tick": 0.0})
		n -= 1

func _pisa(tr: Dictionary, x: float, y: float) -> bool:
	return JS.hypot(x - tr.x, y - tr.y) < TRAMPA_R

func _trampas_tick(dt: float) -> void:
	if trampas.is_empty():
		return
	# casillas con algún enemigo encima: una pasada por los enemigos cada 0,05 s (no una por trampa y fotograma)
	_trampa_scan -= dt
	var ocupadas := {}
	if _trampa_scan <= 0:
		_trampa_scan = .05
		for e in enemies:
			if not e.dying and e.state != "idle":   # los que esperan quietos no las disparan
				ocupadas[int(e.y / TS) * DungeonGen.GW + int(e.x / TS)] = true
	for tr in trampas:
		tr.t -= dt
		match tr.estado:
			"listo":
				var pisada := not p.dead and _pisa(tr, p.x, p.y)
				if not pisada and ocupadas.has(tr.cy * DungeonGen.GW + tr.cx):
					for e in enemies:
						if not e.dying and e.state != "idle" and _pisa(tr, e.x, e.y):
							pisada = true
							break
				if pisada:
					tr.estado = "aviso"
					tr.t = TRAMPA_AVISO
					fx.sonido(&"trampa_click", tr.x, tr.y)
			"aviso":
				if tr.t <= 0:
					tr.estado = "activa"
					tr.t = .4 if tr.kind == "pinchos" else 1.2
					tr.tick = 0.0
					fx.sonido(&"pinchos" if tr.kind == "pinchos" else &"fuego", tr.x, tr.y)
					if tr.kind == "pinchos":
						_trampa_dano(tr, 12 + wave * 4)
			"activa":
				if tr.kind == "fuego":
					tr.tick -= dt
					if tr.tick <= 0:
						tr.tick = .3
						_trampa_dano(tr, 5 + wave * 2)
						fx.burst(tr.x, tr.y, 14, ["#fff0a0", "#ffa020", "#ff4a10"], 6, 50)
				if tr.t <= 0:
					tr.estado = "recarga"
					tr.t = 2.0
			"recarga":
				if tr.t <= 0:
					tr.estado = "listo"

## daña al héroe (la voltereta lo salva: hurt_player no hace nada con roll_t) y a los enemigos encima
func _trampa_dano(tr: Dictionary, dmg: float) -> void:
	if not p.dead and _pisa(tr, p.x, p.y):
		hurt_player(dmg, tr.x, tr.y + 4, null, "trampa")
	for e in enemies.duplicate():
		if e.dying or absf(e.x - tr.x) > TRAMPA_R or absf(e.y - tr.y) > TRAMPA_R or not _pisa(tr, e.x, e.y):
			continue
		e.hp -= dmg
		e.flash = .07
		fx.text(e.x, e.y - 40, str(int(dmg)), COL_GOLPE, 11)
		if e.hp <= 0:
			kill_enemy(e, -PI / 2)

func _mazmorra_init() -> void:
	rompibles = []
	trampas = []
	if L.has("prueba") or L.has("ciudad"):
		return
	_rompibles_init(wave)
	_trampas_init(wave)

# ======================================================================
#  10 nov: más botín, cofre de entrada, cofre por sala, nombres y salas secretas
# ======================================================================
## lo que sueltan los enemigos normales (antes: runa .10, pieza .12/.18, oro .45, poción .18/.3/.6 durante 9 s)
const BOTIN := {"runa": .14, "pieza": .24, "pieza_lanza": .32, "oro": .6,
	"pocion": .28, "pocion_lanza": .4, "pocion_elite": .9, "pocion_dura": 25.0}

## cofre junto a la entrada de cada piso: una pieza de tu clase, mágica o mejor, para el hueco que peor llevas
func _cofre_entrada() -> void:
	if L.has("prueba") or L.has("ciudad"):
		return
	var sx: float = (L.start.cx + .5) * TS
	var sy: float = (L.start.cy + .5) * TS + 10
	for o in [[0, -2], [1, -2], [-1, -2], [2, 0], [-2, 0], [0, 2], [2, -1], [-2, -1]]:
		var cx: int = L.start.cx + o[0]
		var cy: int = L.start.cy + o[1]
		var x := (cx + .5) * TS
		var y := (cy + 1) * TS - 4
		if tile_at(cx, cy) != DungeonGen.FLOOR or not fits(x, y, 8) or not has_los(sx, sy - 6, x, y - 6):
			continue
		if _cofre_cerca(cx, cy, 2):
			continue
		chests.append({"cx": cx, "cy": cy, "kind": "gold", "inicio": true, "nombre": "Cofre del descenso", "room": L.start_room, "se": false,
			"x": x, "y": y, "open": false, "open_t": 0.0, "best": 0, "guards": [], "msg_t": -9.0})
		return

func _cofre_cerca(cx: int, cy: int, r: int) -> bool:
	for c in chests:
		if absi(c.cx - cx) + absi(c.cy - cy) <= r:
			return true
	return false

## el hueco con la pieza más floja (o vacío) de las de tu clase
func hueco_mas_flojo() -> String:
	var peor := ""
	var pq := 99
	for s in Items.set_of(p.cls_key()).slots:
		var it = p.eq.get(s)
		var q: int = -1 if it == null else int(it.q) * 100 + Items.puntos(it)
		if q < pq:
			pq = q
			peor = s
	return peor

func _abrir_cofre_entrada(c: Dictionary) -> void:
	c.open = true
	c.open_t = 0
	var r := rnd() * (1 / maxf(.5, p.st.findMul))
	var q := 3 if r < .05 else (2 if r < .4 else 1)
	c.best = q
	var it := Items.make_gear(rng, q, p.cls_key(), hueco_mas_flojo())
	_fan(c.x, c.y, [it], 1, true)
	drop_gold(c.x, c.y + 4, (15 + rnd() * 20) * (1 + wave * .1), false)
	fx.burst(c.x, c.y, 12, ["#fff3c0", Items.RQ_C[q]], 10, 70)
	fx.text(c.x, c.y - 34, String(c.nombre), Items.RQ_C[q], 10, false, 1.2, false, false)
	map_dirty = true

## un cofre por sala con enemigos: se queda cerrado hasta que mueran los que estaban en ella al empezar
func _cofres_sala() -> void:
	if L.has("prueba") or L.has("ciudad"):
		return
	var por_sala := {}
	var ro: PackedInt32Array = L.room_of
	for e in enemies:
		var cx := cell_of(e.x)
		var cy := cell_of(e.y - 3)
		if cx < 0 or cy < 0 or cx >= DungeonGen.GW or cy >= DungeonGen.GH:
			continue
		var k := ro[cy * DungeonGen.GW + cx]
		if k < 0 or k == L.start_room or k == int(reto.get("room", -1)):
			continue
		if not por_sala.has(k):
			por_sala[k] = []
		por_sala[k].append(e)
	for k in por_sala:
		var r: Dictionary = L.rooms[k]
		var sitio = _sitio_cofre_sala(r)
		if sitio == null:
			continue
		chests.append({"cx": sitio.x, "cy": sitio.y, "kind": "wood", "sala": k, "nombre": "Cofre de la sala", "room": k, "se": false,
			"x": (sitio.x + .5) * TS, "y": (sitio.y + 1) * TS - 4, "open": false, "open_t": 0.0, "best": 0, "guards": por_sala[k], "msg_t": -9.0})

## junto a la pared norte de la sala si se puede (se ve mejor); si no, cualquier casilla libre
func _sitio_cofre_sala(r: Dictionary) -> Variant:
	var cands := []
	for x in range(r.x + 1, r.x + r.w - 1):
		cands.append(Vector2i(x, r.y))
	for i in range(cands.size() - 1, 0, -1):
		var j := int(rnd() * (i + 1))
		var tmp = cands[i]; cands[i] = cands[j]; cands[j] = tmp
	for y in range(r.y + 1, r.y + r.h - 1):
		for x in range(r.x + 1, r.x + r.w - 1):
			cands.append(Vector2i(x, y))
	for c in cands:
		var tt := tile_at(c.x, c.y)
		if tt != DungeonGen.FLOOR:
			continue
		var x: float = (c.x + .5) * TS
		var y: float = (c.y + 1) * TS - 4
		if not fits(x, y, 8) or _cofre_cerca(c.x, c.y, 3):
			continue
		if L.fount != null and JS.hypot(x - CX, y - CY) < FRAD + 20:
			continue
		var malo := false
		for b in range(-1, 2):
			for a in range(-1, 2):
				var t2 := tile_at(c.x + a, c.y + b)
				if t2 == DungeonGen.DOWN or t2 == DungeonGen.UP or t2 == DungeonGen.DOOR:
					malo = true
		if not malo:
			return c
	return null

## guardianes del cofre que siguen vivos
func guardias_vivos(c: Dictionary) -> int:
	var n := 0
	for e in c.guards:
		if not e.dying and enemies.has(e):
			n += 1
	return n

# ---------- nombres de los enemigos ----------
const NOM_PILA := ["Osric", "Bermudo", "Fruela", "Gonzalo", "Tello", "Nuño", "Sancho", "Ordoño", "Rodrigo", "Ramiro", "Mendo", "Pelayo",
	"Íñigo", "Vela", "Fortún", "Garci", "Munio", "Lope", "Alvar", "Odón", "Gaspar", "Teobaldo", "Brunilda", "Urraca", "Elvira", "Toda", "Jimena", "Oria"]
const NOM_HUMANO := ["el Roto", "el Tuerto", "el Manco", "el Cruel", "el Bravo", "el Rojo", "el Viejo", "el Mozo", "el Sordo", "el Negro",
	"Sin Tierra", "el Saqueador", "el Desertor", "el Ahorcado", "Mano de Hierro", "el Cuervo", "el Malo", "Diente Partido"]
const NOM_HUESO := ["el Descarnado", "el Olvidado", "Sin Tumba", "el Hueco", "el Polvoriento", "el Sepultado", "el Sin Nombre", "el Roído",
	"de la Fosa", "el Mondo", "Calavera Rota", "el Desenterrado"]
const NOM_DEMONIO := ["Azrok", "Belzar", "Ghorm", "Xaroth", "Mulgrim", "Vexa", "Ossk", "Zhul", "Karnak", "Ubrax", "Thessa", "Morgul"]
const NOM_DEMONIO2 := ["el Ardiente", "de las Brasas", "el Hambriento", "del Pozo", "el Sin Alma", "el Retorcido", "Lengua de Fuego", "el Cenizo"]

## nombre propio de un enemigo: el título de élites, jefes y campeones; los demás, uno inventado y fijo
## (sale de su semilla, sin gastar números del azar de la simulación)
func nombre_de(e: Ent.Enemy) -> String:
	if e.rare or e.jefe or e.type == "champ" or e.boss != "":
		return e.title
	if e.nombre == "":
		var h := absi(hash(e.seed))
		if e.mon != "" and e.mon != "esqueleto":
			e.nombre = "%s %s" % [NOM_DEMONIO[h % NOM_DEMONIO.size()], NOM_DEMONIO2[(h >> 8) % NOM_DEMONIO2.size()]]
		elif e.mon == "esqueleto":
			e.nombre = "%s %s" % [NOM_PILA[h % NOM_PILA.size()], NOM_HUESO[(h >> 8) % NOM_HUESO.size()]]
		else:
			e.nombre = "%s %s" % [NOM_PILA[h % NOM_PILA.size()], NOM_HUMANO[(h >> 8) % NOM_HUMANO.size()]]
	return e.nombre

# ---------- salas secretas (SalaSecreta) ----------
var secreta_pedida = null    # {s, sale} mientras la vista pregunta «¿Entrar?»
var _secreta_aviso_t := -9.0

## en cada sala secreta: una élite más dura de lo normal, dos escoltas y dos cofres dorados que guarda ella
func _secretas_init() -> void:
	secreta_pedida = null
	for s in L.get("secretas", []):
		var r: Dictionary = s.sala
		var cx: float = (r.x + r.w / 2.0) * TS
		var cy: float = (r.y + r.h / 2.0 + .5) * TS
		var rr := rnd()
		var e := spawn_enemy("sargwen" if wave >= 10 and rr < .3 else ("slayer" if rr < .6 else "knight"), cx, cy)
		_hacer_elite(e)
		e.hp = JS.roundi(e.hp * 1.6); e.max_hp = e.hp; e.ghost = e.hp
		e.dmg = JS.roundi(e.dmg * 1.2)
		e.xp = JS.roundi(e.xp * 1.5)
		e.secreta = true
		for i in 2:
			var o := {"x": cx + (-40.0 if i == 0 else 40.0), "y": cy + 10}
			unstick(o, 8)
			var es := spawn_enemy(enemy_type_for(wave), o.x, o.y)
			es.secreta = true
		for cxy in [Vector2i(r.x + 1, r.y), Vector2i(r.x + r.w - 2, r.y)]:
			chests.append({"cx": cxy.x, "cy": cxy.y, "kind": "gold", "secreta": true, "nombre": "Cofre del tesoro oculto", "room": null, "se": false,
				"x": (cxy.x + .5) * TS, "y": (cxy.y + 1) * TS - 4, "open": false, "open_t": 0.0, "best": 0, "guards": [e], "msg_t": -9.0})

## la puerta secreta (de fuera o de dentro) que tiene el héroe al lado: {s, sale, d}
func secreta_cerca() -> Variant:
	if p == null or p.dead or L.is_empty():
		return null
	var mejor = null
	var bd := SalaSecreta.PUERTA_R
	for s in L.get("secretas", []):
		for sale in [false, true]:
			var pt := SalaSecreta.punto(s.puerta_dentro, s.dentro) if sale else SalaSecreta.punto(s.puerta, s.fuera)
			var d := JS.hypot(pt.x - p.x, pt.y - (p.y - 6))
			if d < bd:
				bd = d
				mejor = {"s": s, "sale": sale, "d": d}
	return mejor

func _pedir_secreta(ps: Dictionary) -> void:
	secreta_pedida = ps

## la vista ya ha fundido a negro: el héroe (y sus aliados) pasan al otro lado de la puerta
func cruzar_secreta() -> void:
	var ps = secreta_pedida
	secreta_pedida = null
	if ps == null:
		return
	var s: Dictionary = ps.s
	var a: Vector2i = s.fuera if ps.sale else s.dentro
	var m: Vector2i = s.puerta if ps.sale else s.puerta_dentro
	var dir := a - m
	p.x = (a.x + .5) * TS + dir.x * 6
	p.y = (a.y + .5) * TS + 10 + dir.y * 6
	unstick(p)
	p.seg_x = p.x
	p.seg_y = p.y
	p.seq = null; p.roll_t = 0; p.blocking = false; p.hurt_t = 0
	p.face = atan2(dir.y, dir.x)
	for al in allies:
		al.x = p.x + (rnd() - .5) * 30
		al.y = p.y + 14 + rnd() * 10
		unstick(al)
	pcell = -1
	map_dirty = true
	if not ps.sale:
		fx.banner("Una sala oculta", "Algo la guarda")

func cancelar_secreta() -> void:
	secreta_pedida = null

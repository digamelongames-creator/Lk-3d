class_name Items
## Objetos, runas y mochila (sistema de runas del juego web: RN_SETS, rnMakeGear, rnFit, mochila en rejilla).
## Los objetos son diccionarios, como en la web:
##   pieza   {id, gear: true, cls, slot, q, name, bonus: {dmg, spd, hp, as}, socks: [id de runa o null]}
##   runa    {id, slot: "rune", rune, n, q: 0, bonus: {}, name}
##   poción  {id, slot: "potion", n (1–3, se apilan), q: 0, bonus: {}, name}
## En la mochila llevan además gx, gy (casilla de arriba a la izquierda).

# ---------- equipo de cada clase: piezas, engarces máximos, nombres, colocación en el muñeco (10×7) ----------
const SETS := {
	"knight": {"slots": ["sword", "helm", "shield", "chest", "gloves", "belt", "boots"], "n": {"sword": 3, "chest": 6, "shield": 4, "helm": 4, "gloves": 2, "belt": 2, "boots": 2}, "weapon": "sword", "name": {},
		"lay": {"sword": [1, 1, 2, 4], "helm": [5, 1, 2, 2], "shield": [9, 1, 2, 4], "chest": [5, 3, 2, 3], "gloves": [1, 6, 2, 2], "belt": [5, 6, 2, 2], "boots": [9, 6, 2, 2]}},
	"dk": {"slots": ["sword", "helm", "shield", "chest", "gloves", "belt", "boots"], "n": {"sword": 3, "chest": 6, "shield": 4, "helm": 4, "gloves": 2, "belt": 2, "boots": 2}, "weapon": "sword", "name": {},
		"lay": {"sword": [1, 1, 2, 4], "helm": [5, 1, 2, 2], "shield": [9, 1, 2, 4], "chest": [5, 3, 2, 3], "gloves": [1, 6, 2, 2], "belt": [5, 6, 2, 2], "boots": [9, 6, 2, 2]}},
	"archer": {"slots": ["sword", "helm", "shield", "chest", "gloves", "boots"], "n": {"sword": 4, "shield": 4, "chest": 6, "helm": 4, "gloves": 3, "boots": 2}, "weapon": "sword", "name": {"sword": "Arco", "shield": "Carcaj"},
		"lay": {"sword": [1, 1, 2, 5], "helm": [5, 1, 2, 2], "shield": [9, 1, 2, 5], "chest": [5, 3, 2, 3], "gloves": [1, 6, 2, 2], "boots": [9, 6, 2, 2]}},
	"dl": {"slots": ["helm", "chest", "gloves", "belt", "boots"], "n": {"chest": 6, "helm": 5, "gloves": 5, "belt": 3, "boots": 4}, "weapon": "gloves", "name": {"helm": "Corona"},
		"lay": {"helm": [5, 1, 2, 2], "chest": [5, 3, 2, 3], "gloves": [1, 2, 2, 3], "belt": [5, 6, 2, 2], "boots": [9, 2, 2, 3]}},
	"mage": {"slots": ["chest", "belt", "legs", "gloves", "boots"], "n": {"chest": 6, "gloves": 6, "legs": 4, "belt": 3, "boots": 4}, "weapon": "gloves", "name": {"chest": "Abrigo", "boots": "Zapatos", "legs": "Pantalones"},
		"lay": {"chest": [5, 1, 2, 3], "belt": [5, 4, 2, 2], "legs": [5, 6, 2, 2], "gloves": [1, 2, 2, 3], "boots": [9, 2, 2, 3]}},
}
const CLASSES := ["knight", "mage", "dk", "archer", "dl"]
const SLOT_N0 := {"sword": "Espada", "helm": "Casco", "shield": "Escudo", "chest": "Pecho", "gloves": "Guantes", "belt": "Cinturón", "boots": "Botas", "legs": "Pantalones"}
const CLS_N := {"knight": "Caballero", "mage": "Mago de fuego", "dk": "Caballero de la Muerte", "archer": "Arquero", "dl": "Señor Oscuro"}

# ---------- calidades ----------
const RQ_N := ["Básico", "Mágico", "Dorado", "Legendario"]
const RQ_NP := ["básicos", "mágicos", "dorados", "legendarios"]
const RQ_C := ["#e8e2d0", "#6fa8ff", "#ffd25a", "#3fe0b0"]
const RQ_SOCK := [.25, .5, .75, 1.0]
const RI_BASE := {
	"knight": {"sword": "Espada", "helm": "Yelmo", "shield": "Escudo", "chest": "Coraza", "gloves": "Guanteletes", "belt": "Cinturón", "boots": "Botas"},
	"dk": {"sword": "Espadón", "helm": "Yelmo", "shield": "Escudo", "chest": "Coraza", "gloves": "Guanteletes", "belt": "Cinturón", "boots": "Grebas"},
	"archer": {"sword": "Arco", "helm": "Capucha", "shield": "Carcaj", "chest": "Jubón", "gloves": "Brazales", "boots": "Botas"},
	"dl": {"helm": "Corona", "chest": "Túnica", "gloves": "Guanteletes", "belt": "Fajín", "boots": "Botas"},
	"mage": {"chest": "Abrigo", "belt": "Cinturón", "legs": "Pantalones", "gloves": "Guantes", "boots": "Zapatos"}}
## clases con set de armadura visible: sus piezas básicas, mágicas y doradas se llaman como el set
const RI_SET := {"knight": "del Caballero Oscuro"}
const RI_MAG := ["del alba", "de la marea", "del cuervo", "de escarcha", "del lobo", "de brasas", "del peregrino", "de la niebla", "del zorro", "de la tormenta"]
const RI_DOR := ["del rey caído", "del juramento", "de la llama eterna", "del último asedio", "de la corona", "del verdugo", "de los siete sellos", "del gran maestre"]
const RI_LEG := {
	"knight": {"sword": "Tizona", "helm": "Yelmo de Mambrino", "shield": "Égida del Último Caballero", "chest": "Coraza de Roldán", "gloves": "Guanteletes del Cid", "belt": "Ceñidor de Babieca", "boots": "Botas de Siete Leguas"},
	"dk": {"sword": "Colada Maldita", "helm": "Yelmo del Rey sin Rostro", "shield": "Pavés de las Ánimas", "chest": "Peto del Osario", "gloves": "Garras del Sepulcro", "belt": "Cadena del Penitente", "boots": "Grebas de la Santa Compaña"},
	"archer": {"sword": "Arco de Guillermo", "helm": "Capucha del Bosque Viejo", "shield": "Carcaj sin Fondo", "chest": "Jubón del Montero", "gloves": "Brazales del Halcón", "boots": "Botas del Rastreador"},
	"dl": {"helm": "Corona del Abismo", "chest": "Túnica del Eclipse", "gloves": "Puños del Señor Oscuro", "belt": "Fajín de las Mil Almas", "boots": "Botas del Trono Negro"},
	"mage": {"chest": "Abrigo de Ascuas Eternas", "belt": "Cinturón del Alquimista", "legs": "Pantalones del Brasero", "gloves": "Guantes de Prometeo", "boots": "Zapatos de Ceniza"}}
const STAT_NM := {"dmg": "Daño", "spd": "Velocidad de movimiento", "hp": "Vida", "as": "Velocidad de ataque", "arm": "Armadura"}
## material de las piezas básicas según lo bien que salgan sus números (de peor a mejor)
const RI_MATERIAL := {
	"metal": ["de hierro oxidado", "de hierro", "de bronce", "de acero", "de acero templado"],
	"cuero": ["de cuero roído", "de cuero", "de cuero curtido", "de cuero tachonado", "de piel de lobo"],
	"tela": ["de arpillera", "de lana", "de lino", "de paño fino", "de seda"],
	"madera": ["de rama verde", "de olmo", "de fresno", "de tejo", "de tejo viejo"]}
const RI_MAT_DE := {"Espada": "metal", "Espadón": "metal", "Yelmo": "metal", "Escudo": "metal", "Coraza": "metal", "Guanteletes": "metal",
	"Grebas": "metal", "Corona": "metal", "Cinturón": "cuero", "Botas": "cuero", "Brazales": "cuero", "Carcaj": "cuero", "Fajín": "cuero",
	"Capucha": "cuero", "Jubón": "cuero", "Túnica": "tela", "Abrigo": "tela", "Pantalones": "tela", "Guantes": "tela", "Zapatos": "tela", "Arco": "madera"}
## piezas que protegen: llevan siempre armadura entre sus números
const SLOT_ARMADURA := ["chest", "helm", "shield", "belt", "boots", "legs"]

# ---------- runas ----------
const RN_ROM := ["", "I", "II", "III", "IV", "V"]
const RN_TN := ["", "Común", "Grabada", "Rúnica", "Épica", "Legendaria"]
const RN_TC := ["", "#c9c2b4", "#7f9bff", "#f0cf5a", "#c07aff", "#ff8a3a"]
const RN_FLOOR := [0, 1, 4, 8, 12, 16]     # piso desde el que puede caer cada rango
const RN_W := [0, 50, 30, 14, 5, 1]        # peso de cada rango al caer

# ---------- mochila ----------
const RB_W := 12
const RB_H := 6
const RB_STACK := 20
const RB_SZ := {"sword": [2, 4], "chest": [2, 3], "shield": [2, 3], "helm": [2, 2], "gloves": [2, 2], "belt": [2, 1], "boots": [2, 2], "legs": [2, 2]}

static var item_id := 1
static var _by := {}
static var _list: Array = []

static func runes() -> Array:
	if _list.is_empty():
		_list = GameData.get_table("runes")
		for r in _list:
			_by[r.id] = r
	return _list

static func rune(id) -> Dictionary:
	if _list.is_empty():
		runes()
	return _by.get(id, {})

static func affixes() -> Dictionary:
	return GameData.get_table("affixes")["AFFIXES"]

# ---------- piezas ----------
static func set_of(cls: String) -> Dictionary:
	return SETS.get(cls, SETS.knight)

static func slot_name(cls: String, s: String) -> String:
	var C: Dictionary = set_of(cls)
	return C.name.get(s, SLOT_N0.get(s, s))

## en qué piezas entra una runa según la clase (regla fija)
static func fit(cls: String, r: Dictionary) -> Array:
	var C: Dictionary = set_of(cls)
	var sl: Array = C.slots
	match String(r.s):
		"Arma": return [C.weapon]
		"Armadura": return sl.filter(func(s): return s != C.weapon)
		"Escudo": return ["shield"] if sl.has("shield") else ["chest"]
		"Cinturón": return ["belt"] if sl.has("belt") else ["shield"]
		"Casco": return ["helm"] if sl.has("helm") else ["chest"]
		"Botas": return ["boots"]
		"Guantes": return ["gloves"]
	return sl.duplicate()

static func fit_txt(cls: String, r: Dictionary) -> String:
	var l: Array = fit(cls, r).map(func(s): return slot_name(cls, s).to_lower())
	if l.size() > 1:
		return ", ".join(PackedStringArray(l.slice(0, -1))) + " o " + l[-1]
	return l[0]

## lo que da cada pieza por sí misma (base fija pequeña, igual en todas las calidades)
static func base_mods(cls: String, s: String) -> Array:
	var C: Dictionary = set_of(cls)
	if s == C.weapon:
		return [{"stat": "dmg", "flat": 2}, {"stat": "atkSpd", "pct": .03}] if s == "gloves" else [{"stat": "dmg", "flat": 2}]
	match s:
		"chest": return [{"stat": "armorPts", "flat": 6}]
		"shield": return [{"stat": "atkSpd", "pct": .03}] if cls == "archer" else [{"stat": "armorPts", "flat": 4}, {"stat": "blockCh", "flat": .05}]
		"helm": return [{"stat": "armorPts", "flat": 2}]
		"gloves": return [{"stat": "atkSpd", "pct": .03}]
		"boots": return [{"stat": "spd", "pct": .03}]
		"belt": return [{"stat": "maxHp", "flat": 10}]
		"legs": return [{"stat": "armorPts", "flat": 3}, {"stat": "maxHp", "flat": 5}]
	return []

static func base_txt(cls: String, s: String) -> String:
	var out := PackedStringArray()
	for m in base_mods(cls, s):
		match String(m.stat):
			"dmg": out.append("+%d de daño" % m.flat)
			"armorPts": out.append("+%d de armadura" % m.flat)
			"blockCh": out.append("+%d %% de bloqueo" % JS.roundi(m.flat * 100))
			"atkSpd": out.append("+%d %% de velocidad de ataque" % JS.roundi(m.pct * 100))
			"spd": out.append("+%d %% de velocidad de movimiento" % JS.roundi(m.pct * 100))
			_: out.append("+%d de vida máxima" % m.flat)
	return " y ".join(out)

static func stat_txt(a: String, v: int) -> String:
	match a:
		"as": return "+%d Velocidad de ataque (+%d%%)" % [v, v * 4]
		"dmg": return "+%d Daño" % v
		"spd": return "+%d Velocidad de movimiento (+%d%%)" % [v, v * 3]
		"arm": return "+%d Armadura (+%d)" % [v, v * 2]
	return "+%d Vida (+%d)" % [v, v * 8]

static func sock_n(cls: String, s: String, q: int) -> int:
	return maxi(1, ceili(set_of(cls).n[s] * RQ_SOCK[q]))

static func _pick(rng: RandomNumberGenerator, a: Array):
	return a[int(rng.randf() * a.size())]

## simple: como antes del 10 nov (un número de 1 a 3, sin armadura ni extra): el equipo inicial
## ol: oleada donde cae la pieza: cada afijo gana un 10 % por oleada (10 nov 2026)
static func make_gear(rng: RandomNumberGenerator, q: int, cls: String, s: String = "", no_sock: bool = false, simple: bool = false, ol: int = 1) -> Dictionary:
	var C: Dictionary = set_of(cls)
	if s == "":
		s = _pick(rng, C.slots)
	var base: String = RI_BASE[cls][s]
	var protege: bool = SLOT_ARMADURA.has(s) and s != C.weapon and not (cls == "archer" and s == "shield") and not simple
	var bonus := {}
	if q == 3:
		bonus = {"dmg": 3, "spd": 3, "hp": 3, "as": 3}
		if protege:
			bonus["arm"] = 4
	else:
		# más variedad (10 nov): números de 1 a 4 (dorado de 2 a 5), armadura en las piezas que protegen
		# y, a veces, una estadística de más
		var main := "dmg" if s == C.weapon else String({"chest": "hp", "belt": "hp", "boots": "spd", "gloves": "as"}.get(s, ""))
		var st := []
		if main != "":
			st.append(main)
		if protege:
			st.append("arm")
		var n := q + 1 + (1 if rng.randf() < (.3 if q == 0 else .2) and not simple else 0)
		while st.size() < n:
			var a: String = _pick(rng, ["dmg", "spd", "hp", "as"])
			if not st.has(a):
				st.append(a)
		for a in st:
			bonus[a] = (1 + int(rng.randf() * 3)) if simple else ((2 + int(rng.randf() * 4)) if q == 2 else (1 + int(rng.randf() * 4)))
	if ol > 1 and not simple:
		for a in bonus:
			bonus[a] = escalar(int(bonus[a]), ol)
	var name := base
	if q == 0:
		name += " " + material(base, bonus)
	if RI_SET.has(cls) and q < 3: name += " " + RI_SET[cls]   # el set que se ve puesto (Armadura3D)
	elif q == 1: name += " " + _pick(rng, RI_MAG)
	elif q == 2: name += " " + _pick(rng, RI_DOR)
	elif q == 3: name = RI_LEG[cls][s]
	var socks := []
	if not no_sock:
		socks.resize(sock_n(cls, s, q))
	item_id += 1
	var it := {"id": item_id, "gear": true, "cls": cls, "slot": s, "q": q, "name": name, "bonus": bonus, "socks": socks, "ol": ol}
	if q == 3 and Legendarios.CLASES.has(cls) and Legendarios.EFECTO.has(s):
		it["efecto"] = Legendarios.EFECTO[s]
	return it

const MEJORA_OLEADA := .1
## número de un afijo en la oleada «ol»: +10 % por oleada, redondeado
static func escalar(v: int, ol: int) -> int:
	return maxi(v, roundi(v * (1.0 + MEJORA_OLEADA * (ol - 1))))

## material de una pieza básica: cuanto mejores sus números, mejor el material («Espada de acero templado»)
static func material(base: String, bonus: Dictionary) -> String:
	var l: Array = RI_MATERIAL[RI_MAT_DE.get(base, "metal")]
	var n := maxi(1, bonus.size())
	var k := clampf((puntos({"bonus": bonus}) / float(n) - 1.0) / 3.0, 0, 1)   # media de 1 a 4 → 0 a 1
	return l[clampi(roundi(k * (l.size() - 1)), 0, l.size() - 1)]

## suma de los números de una pieza
static func puntos(it: Dictionary) -> int:
	var t := 0
	for a in it.get("bonus", {}):
		t += int(it.bonus[a])
	return t

static func rune_item(id: String, n: int = 1) -> Dictionary:
	item_id += 1
	return {"id": item_id, "slot": "rune", "rune": id, "n": n, "q": 0, "bonus": {}, "name": "Runa " + String(rune(id).n)}

const POT_STACK := 3

static func potion_item(n: int = 1) -> Dictionary:
	item_id += 1
	return {"id": item_id, "slot": "potion", "n": n, "q": 0, "bonus": {}, "name": "Poción de vida"}

## mete una poción: primero en un montón con hueco (hasta 3), si no en una casilla libre
static func add_potion(h) -> bool:
	for it in h.bag:
		if it.slot == "potion" and int(it.get("n", 1)) < POT_STACK:
			it.n = int(it.get("n", 1)) + 1
			return true
	return bag_add(h, potion_item())

## calidad mínima del objeto para cada runa: I Básico, II Mágico, III Dorado, IV y V Legendario
static func rune_q(r: Dictionary) -> int:
	return mini(3, int(r.t) - 1)

static func can_use(cls: String, r: Dictionary) -> bool:
	return r.k == "Todas" or r.k == CLS_N.get(cls, "")

# ---------- mochila en rejilla ----------
static func size_of(it: Dictionary) -> Array:
	return RB_SZ.get(it.slot, [2, 2]) if it.get("gear", false) else [1, 1]

static func bag_over(h, gx: int, gy: int, w: int, hh: int, skip = null) -> Array:
	var out := []
	for it in h.bag:
		if it == skip:
			continue
		var sz := size_of(it)
		if gx < it.gx + sz[0] and gx + w > it.gx and gy < it.gy + sz[1] and gy + hh > it.gy:
			out.append(it)
	return out

static func bag_fits(h, it: Dictionary, gx: int, gy: int, skip = null) -> bool:
	var sz := size_of(it)
	return gx >= 0 and gy >= 0 and gx + sz[0] <= RB_W and gy + sz[1] <= RB_H and bag_over(h, gx, gy, sz[0], sz[1], skip).is_empty()

static func bag_spot(h, it: Dictionary) -> Variant:
	var sz := size_of(it)
	for x in RB_W - sz[0] + 1:
		for y in RB_H - sz[1] + 1:
			if bag_fits(h, it, x, y):
				return [x, y]
	return null

static func bag_add(h, it: Dictionary) -> bool:
	var sp = bag_spot(h, it)
	if sp == null:
		return false
	it.gx = sp[0]
	it.gy = sp[1]
	h.bag.append(it)
	return true

static func bag_del(h, it: Dictionary) -> void:
	h.bag.erase(it)

static func bag_used(h) -> int:
	var n := 0
	for it in h.bag:
		var sz := size_of(it)
		n += sz[0] * sz[1]
	return n

## mete runas: primero en los montones iguales, luego en casillas libres. Devuelve las que no caben.
static func add_rune(h, id: String, n: int = 1) -> int:
	for it in h.bag:
		if it.get("rune", "") == id and it.n < RB_STACK:
			var k := mini(n, RB_STACK - it.n)
			it.n += k
			n -= k
			if n == 0:
				return 0
	while n > 0:
		var it := rune_item(id, mini(n, RB_STACK))
		if not bag_add(h, it):
			return n
		n -= it.n
	return 0

static func potion_count(h) -> int:
	var n := 0
	for it in h.bag:
		if it.slot == "potion":
			n += int(it.get("n", 1))
	return n

# ---------- equipo ----------
static func socketed(h) -> Array:
	var out := []
	for s in set_of(h.cls_key()).slots:
		var it = h.eq.get(s)
		if it != null:
			for id in it.socks:
				if id != null and not rune(id).is_empty():
					out.append(rune(id))
	return out

static func leg_count(h, skip: String = "") -> int:
	var n := 0
	for s in set_of(h.cls_key()).slots:
		if s == skip:
			continue
		var it = h.eq.get(s)
		if it != null:
			for id in it.socks:
				if id != null and int(rune(id).get("t", 0)) == 5:
					n += 1
	return n

static func why_not(h, r: Dictionary, slot: String) -> String:
	var k: String = h.cls_key()
	if not can_use(k, r):
		return "Es una runa de %s." % r.k
	if not fit(k, r).has(slot):
		return "Esta runa va en: %s." % fit_txt(k, r)
	var it = h.eq.get(slot)
	if it != null and it.q < rune_q(r):
		return "Esta runa solo entra en objetos %s%s." % [RQ_NP[rune_q(r)], " o mejores" if (int(r.t) < 5 and rune_q(r) < 3) else ""]
	if int(r.t) == 5 and leg_count(h) >= 2:
		return "Ya llevas 2 runas legendarias."
	return ""

## caballero y caballero oscuro pueden llevar una segunda espada en el hueco del escudo:
## sin bloqueo, a cambio de más daño (DOS_ESPADAS_DMG)
const DOS_ESPADAS := ["knight", "dk"]
const DOS_ESPADAS_DMG := .15

## si la pieza va en ese hueco
static func cabe(cls: String, it, slot: String) -> bool:
	return it.slot == slot or (slot == "shield" and it.slot == "sword" and DOS_ESPADAS.has(cls))

static func dos_espadas(h) -> bool:
	var izq = h.eq.get("shield")
	return izq != null and izq.slot == "sword"

static func why_equip(h, it, slot: String = "") -> String:
	if it == null or not it.get("gear", false):
		return "Eso no se equipa."
	var k: String = h.cls_key()
	if it.cls != k:
		return "Es de %s: tu clase no puede usarlo." % CLS_N[it.cls]
	if slot != "" and not cabe(k, it, slot):
		return "Va en el hueco de %s." % slot_name(k, it.slot).to_lower()
	var leg := 0
	for id in it.socks:
		if id != null and int(rune(id).get("t", 0)) == 5:
			leg += 1
	if leg and leg_count(h, slot if slot != "" else it.slot) + leg > 2:
		return "Llevarías más de 2 runas legendarias engarzadas."
	return ""

## equipo básico de la clase (partida nueva): piezas básicas sin engarces
static func init_gear(h, rng: RandomNumberGenerator) -> void:
	var k: String = h.cls_key()
	h.eq = {}
	for s in set_of(k).slots:
		h.eq[s] = make_gear(rng, 0, k, s, true, true)
	h.bag = []

class_name Arbol
extends RefCounted
## Árbol de habilidades (TREE, rank, has, SKP, treeMods, nodeState, learnNode… del juego web).
## 3 ramas por clase (una por habilidad) y 5 escalones. Los nodos aportan:
##   mods → modificadores de la hoja (por rango)
##   sp   → cambios a los parámetros de una habilidad (duración, recarga, radio…) por rango
##   cond → modificadores que solo cuentan en cierta situación (vida baja, dentro del Estandarte)
## y el resto de efectos se consultan con has("id") donde toca.

const TIER_REQ := [0, 0, 3, 6, 9, 11]   # puntos gastados en la rama para abrir cada escalón
const TIER_NAME := ["", "Mejora", "Pasiva", "Elección A / B", "Pasiva fuerte", "Clave"]
const WHY := {"locked": "Escalón cerrado: gasta más puntos en esta rama.", "excluded": "Ya elegiste la otra opción de este escalón.",
	"keytaken": "Ya tienes una clave en otra rama: solo se permite una.", "nopts": "No te quedan puntos de habilidad.", "max": "Rango máximo."}

static var TREE: Array = []
static var BY_ID: Dictionary = {}

var sim: Sim

func _init(s: Sim) -> void:
	sim = s
	if TREE.is_empty():
		TREE = GameData.get_table("skill_tree")
		for n in TREE:
			BY_ID[n.id] = n

# ---------- consultas ----------
func rank(id: String) -> int:
	var p := sim.p
	return int(p.tree.get(id, 0)) if p != null else 0

## el nodo está aprendido o lo concede una runa engarzada
func has(id: String) -> bool:
	return rank(id) > 0 or sim.runes.G.has(id)

## parámetro de habilidad con el árbol y las runas: (base + Σplano) × (1 + Σ%) × Πmult, y el recorte de la web
func skp(id: String, par: String) -> float:
	var d: Dictionary = Sim.SK[id]
	var b: float = float(d.get(par, 0.0))
	var fl := 0.0
	var pc := 0.0
	var mu := 1.0
	var p := sim.p
	if p != null:
		for nid in p.tree:
			var r: int = int(p.tree[nid])
			var n: Dictionary = BY_ID.get(nid, {})
			if r <= 0 or not n.has("sp"):
				continue
			for m in n.sp:
				if m.sk != id or m.par != par:
					continue
				if m.has("flat"): fl += m.flat * r
				if m.has("pct"): pc += m.pct * r
				if m.has("mult"): mu *= pow(m.mult, r)
	for m in sim.runes.SKM:
		if m.sk != id or m.par != par:
			continue
		fl += m.get("flat", 0.0)
		pc += m.get("pct", 0.0)
	if id == "pact" and sim.runes.rv("forbiddenPact"):
		if par == "cost": mu = 0
		if par == "dmgM": fl += .5
	return maxf(0, (b + fl) * (1 + pc) * mu) * float(Sim.SKP_NERF.get(id + "." + par, 1.0))

static func scale_mod(m: Dictionary, k: float) -> Dictionary:
	var o := {"stat": m.stat}
	if m.has("flat"): o.flat = m.flat * k
	if m.has("pct"): o.pct = m.pct * k
	if m.has("mult"): o.mult = pow(m.mult, k)
	return o

## modificadores de la hoja que aportan los nodos (fijos y condicionales)
func mods(h: Ent.Hero) -> Array:
	var out := []
	var in_b := sim.in_banner()
	for nid in h.tree:
		var r: int = int(h.tree[nid])
		var n: Dictionary = BY_ID.get(nid, {})
		if r <= 0 or n.is_empty():
			continue
		for m in n.get("mods", []):
			out.append(scale_mod(m, r))
		var cond: String = n.get("cond", "")
		if cond == "lowhp" and h.st.get("maxHp", 0) and h.hp / h.st.maxHp < .3:
			for m in n.condMods: out.append(scale_mod(m, r))
		if cond == "banner" and in_b:
			for m in n.condMods: out.append(scale_mod(m, r))
	if in_b and has("k_ban_t4"): out.append({"stat": "regen", "flat": h.st.get("maxHp", 100) * .01})
	if in_b and has("k_ban_key"): out.append({"stat": "atkSpd", "mult": 1.75 / 1.5})
	if h.dk and has("d_drain_key") and not sim.skill_on_id("drain"): out.append({"stat": "lifesteal", "flat": .135})
	if h.dl and sim.skill_on_id("pact"):
		out.append_array([{"stat": "dmg", "mult": skp("pact", "dmgM")}, {"stat": "atkSpd", "mult": 1.2}])
		if has("l_pact_t4"): out.append({"stat": "lifesteal", "flat": .08})
	return out

# ---------- reglas para aprender ----------
func branch_pts(h: Ent.Hero, c: String, b: int) -> int:
	var s := 0
	for n in TREE:
		if n.c == c and int(n.b) == b:
			s += int(h.tree.get(n.id, 0))
	return s

## ok, max, excluded, locked, keytaken, nopts u other (de otra clase)
func node_state(h: Ent.Hero, n: Dictionary) -> String:
	var r := int(h.tree.get(n.id, 0))
	var c := h.cls_key()
	if n.c != c: return "other"
	if r >= int(n.max): return "max"
	if n.has("excl") and int(h.tree.get(n.excl, 0)) > 0: return "excluded"
	if branch_pts(h, n.c, int(n.b)) < TIER_REQ[int(n.t)]: return "locked"
	if n.get("key", false):
		for o in TREE:
			if o.get("key", false) and o.c == c and o.id != n.id and int(h.tree.get(o.id, 0)) > 0:
				return "keytaken"
	return "ok" if h.skp > 0 else "nopts"

func learn(id: String) -> bool:
	var h := sim.p
	var n: Dictionary = BY_ID.get(id, {})
	if n.is_empty() or node_state(h, n) != "ok":
		return false
	h.tree[id] = int(h.tree.get(id, 0)) + 1
	h.skp -= 1
	sim.recalc(h)
	sim.fx.burst(h.x, h.y, 14, ["#b89bff", "#ffd25a"], 20, 80)
	sim.fx.hud()
	return true

## nodos de la clase del héroe, por rama y escalón
func nodes(c: String, b: int, t: int = 0) -> Array:
	var out := []
	for n in TREE:
		if n.c == c and int(n.b) == b and (t == 0 or int(n.t) == t):
			out.append(n)
	return out

# ---------- efectos especiales ----------
## «Grito de guerra»: al activar Gran Valor los enemigos cercanos huyen
func valor(h: Ent.Hero) -> void:
	if not has("k_valor_a"):
		return
	for e: Ent.Enemy in sim.enemies:
		if e.dying:
			continue
		if JS.hypot(e.x - h.x, e.y - h.y) < 80:
			e.flee_t = 2
			e.act = ""
	sim.fx.text(h.x, h.y - 70, "¡GRITO DE GUERRA!", "#ff5a46", 12, true, 1.2, true, false)

## «Último en pie»: una vez por piso, un golpe mortal te deja a 1 de vida y activa Gran Valor
func last_stand(h: Ent.Hero) -> void:
	if h.hp > 0 or not has("k_valor_key") or sim.last_stand:
		return
	sim.last_stand = true
	h.hp = 1
	h.inv = maxf(h.inv, 1)
	var i := h.skills.find("valor")
	if i >= 0:
		h.sk[i].t = skp("valor", "dur") * h.st.skillDur
		h.valor_heal_t = 0
	sim.fx.text(h.x, h.y - 70, "¡ÚLTIMO EN PIE!", "#ffd25a", 14, true, 1.6, true, false)
	sim.fx.burst(h.x, h.y, 20, ["#ff3b30", "#ffd25a", "#fff3c0"], 30, 140)
	sim.fx.shake(6)

func on_floor() -> void:
	var h := sim.p
	sim.last_stand = false
	h.nova_x = null
	h.drain_x = null
	if has("k_ban_key"):
		var i := h.skills.find("banner")
		if i >= 0:
			var d: float = skp("banner", "dur") * h.st.skillDur
			h.sk[i].t = d
			sim.banner = {"x": h.x, "y": h.y + 1, "t": d, "max": d}

## ralentización de los enemigos por el Estandarte y el Aura
func e_slow(e: Ent.Enemy) -> float:
	var k := 1.0
	var h := sim.p
	var b = sim.banner
	if has("k_ban_b") and b != null and b.t > 0 and JS.hypot(e.x - b.x, e.y - b.y) < skp("banner", "r"):
		k *= .6
	if h.dk and has("d_drain_a") and (sim.skill_on_id("drain") or has("d_drain_key")):
		var c := sim.drain_c()
		if JS.hypot(e.x - c.x, e.y - c.y) < skp("drain", "r"):
			k *= .7
	return k

## daño extra que reciben los enemigos de los ataques mágicos
func taken_mul(e: Ent.Enemy, small: bool) -> float:
	var k := 1.0
	if has("m_frz_b") and e.frozen > 0:
		k *= 1.3
	if not small and has("m_nova_t4") and sim.skill_on_id("nova"):
		var c := sim.nova_c()
		if JS.hypot(e.x - c.x, e.y - c.y) < skp("nova", "r"):
			k *= 1.15
	return k

func freeze(h: Ent.Hero) -> void:
	if has("m_frz_t4"):
		sim.add_effect(h, "flameShield", [{"stat": "armor", "flat": .3}], 3)
	if has("m_frz_key"):
		sim.runes.fires.append({"x": h.x, "y": h.y, "r": skp("freeze", "r") * .7, "t": 5.0, "tick": 0.0})

func contagion(e: Ent.Enemy) -> void:
	e.contagion = false
	for o: Ent.Enemy in sim.enemies:
		if o == e or o.dying or o.frozen > 0:
			continue
		if JS.hypot(o.x - e.x, o.y - e.y) < 60:
			o.frozen = e.frz_dur if e.frz_dur > 0 else 2.0
			o.act = ""
			o.vx = 0
			o.vy = 0
			sim.fx.burst(o.x, o.y, 14, ["#fff0b0", "#ffb03a", "#ff6a10"], 8, 50)

## al teletransportarse: estela, invulnerabilidad, maná y doble salto; devuelve la recarga
func blink(h: Ent.Hero, x0: float, y0: float) -> float:
	if has("m_blink_a"):
		sim.cls.aoes.append({"x": x0, "y": y0, "t": .35, "max": .35, "r": Sim.AOE_R, "boom": 0.0})
	if has("m_blink_t4"):
		h.inv = maxf(h.inv, 1)
	if has("m_blink_key"):
		h.mana = minf(h.st.maxMana, h.mana + 25)
		h.next_fb_crit = true
	var cd: float = skp("blink", "cd") * (1 - h.st.cdr)
	if has("m_blink_b") and not h.blink_second:
		h.blink_second = true
		return .35
	h.blink_second = false
	return cd

func fb_crit(h: Ent.Hero) -> bool:
	var c := h.next_fb_crit
	h.next_fb_crit = false
	return c

func on_kill(e: Ent.Enemy) -> void:
	var h := sim.p
	sim.cls.on_kill(e)
	if h.cls == "mage" and has("m_nova_a") and sim.skill_on_id("nova"):
		var c := sim.nova_c()
		if JS.hypot(e.x - c.x, e.y - c.y) < skp("nova", "r"):
			h.mana = minf(h.st.maxMana, h.mana + 10)
			sim.fx.text(h.x, h.y - 52, "+10 maná", "#6fa8ff", 9)

## cada golpe de un muerto alzado
func ally_hit(a: Ent.Ally, tg: Ent.Enemy) -> void:
	var h := sim.p
	if has("d_raise_t4"):
		sim.heal(h, 1)
	if has("d_raise_key") and tg.hp <= 0 and sim.allies.size() < 5:
		tg.no_corpse = true
		var d: float = skp("raise", "dur") * h.st.skillDur
		var n := Ent.Ally.new()
		n.x = tg.x; n.y = tg.y; n.face = tg.face
		n.t = d; n.max_t = d
		n.seed = sim.rnd() * 9
		if a.goal != null and a.arrived:
			n.goal = {"x": a.goal.x, "y": a.goal.y}
		sim.allies.append(n)
		sim.fx.burst(tg.x, tg.y - 10, 10, ["#e6d0ff", "#9a4dff", "#3a1660"], 20, 90)

## «Campeones caídos»: al desaparecer, el muerto explota
func ally_expire(a: Ent.Ally) -> void:
	if not has("d_raise_b"):
		return
	var h := sim.p
	sim.fx.burst(a.x, a.y - 10, 10, ["#e6d0ff", "#9a4dff", "#ff6a10"], 30, 150)
	sim.fx.shake(4)
	for e: Ent.Enemy in sim.enemies.duplicate():
		if e.dying:
			continue
		if JS.hypot(e.x - a.x, e.y - a.y) < 50:
			sim.dk_damage(e, maxf(1, JS.round(h.st.dmg * 2)), atan2(e.y - a.y, e.x - a.x), false, "#c9a6ff")

## cada paso: estandarte errante
func tick(h: Ent.Hero, _dt: float) -> void:
	var b = sim.banner
	if has("k_ban_a") and b != null and b.t > 0:
		b.x = h.x
		b.y = h.y + 1

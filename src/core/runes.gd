class_name Runes
extends RefCounted
## Efectos de las runas engarzadas (rnAgg, runeMods, rnHit, rnHurt, rnOnKill, rnTick… del juego web).
## Solo cuentan las runas de las piezas puestas. Las de una clase solo hacen algo con esa clase, igual que en la web.

var sim: Sim
var A := {}          # RNA: suma de efectos (número, [min, max] o listas L_<fx>)
var G := {}          # RNG: nodos del árbol que conceden las runas
var SKM: Array = []  # RNSK: cambios a parámetros de habilidad {sk, par, flat|pct}

# estado del piso (rnOnFloor lo reinicia)
var immortal_used := false
var breath_used := false
var fount_used := false
var picked := false
var lock_used := false
var kills := 0
var revives := 0
var fonts: Array = []      # fuentes portátiles {x, y, t, tk}
var queue: Array = []      # golpes que se resuelven al paso siguiente {k, e, dmg}
var bolts: Array = []      # rayos para dibujar {x0, y0, x1, y1, t, col}
var slashes: Array = []    # tajos de energía {x, y, a, t}
var fires: Array = []      # rastro de fuego {x, y, r, t, tick}
var storm_t := 0.0
var dot_t := 0.0
var ally_n := 0

func _init(s: Sim) -> void:
	sim = s

func rv(k: String) -> float:
	var v = A.get(k)
	return float(v) if (v is float or v is int) else 0.0

func lst(k: String) -> Array:
	return A.get("L_" + k, [])

func has_vs3(g: String) -> bool:
	for v in lst("vs3"):
		if v[0] == g:
			return true
	return false

## nodo del árbol aprendido o concedido por una runa
func granted(id: String) -> bool:
	return sim.has(id)

## suma de todo lo engarzado; recalcula la hoja
func agg(h: Ent.Hero) -> void:
	A = {}
	G = {}
	SKM = []
	for r in Items.socketed(h):
		var f: String = r.fx
		var v = r.v
		if f == "sk":
			SKM.append(v)
		elif f == "grant":
			G[v] = true
		elif v is Array and v.size() and (v[0] is float or v[0] is int):
			var a: Array = A.get(f, [0.0, 0.0])
			A[f] = [a[0] + v[0], a[1] + v[1]]
		elif v is Array:
			if not A.has("L_" + f):
				A["L_" + f] = []
			A["L_" + f].append(v)
		else:
			A[f] = A.get(f, 0.0) + (float(v) if (v is float or v is int) else 1.0)
	if rv("bannerMaster"): G["k_ban_a"] = true
	if rv("fallenKing"): G["k_verd_key"] = true
	sim.recalc(h)

## parámetro de habilidad con el árbol y las runas (SKP de la web)
func skp(id: String, par: String) -> float:
	return sim.skp(id, par)

## modificadores de la hoja: base de cada pieza puesta, bonificaciones y runas
func mods(h: Ent.Hero) -> Array:
	var out := []
	var k := h.cls_key()
	var AF := Items.affixes()
	for s in Items.set_of(k).slots:
		var it = h.eq.get(s)
		if it == null:
			continue
		out.append_array(Items.base_mods(k, it.slot))   # una espada en el hueco del escudo da lo de espada
		for a in it.bonus:
			var d: Dictionary = AF.get(a, {})
			if d.is_empty():
				continue
			var m := {"stat": d.stat}
			if d.has("flat"): m.flat = d.flat * it.bonus[a]
			if d.has("pct"): m.pct = d.pct * it.bonus[a]
			out.append(m)
	if Items.dos_espadas(h):
		out.append({"stat": "dmg", "pct": Items.DOS_ESPADAS_DMG})
	const FX := {"dmgF": ["dmg", "flat", 1], "dmgP": ["dmg", "pct", .01], "asP": ["atkSpd", "pct", .01], "crit": ["crit", "flat", .01], "critD": ["critMult", "flat", .01], "rangeP": ["range", "pct", .01],
		"armorPts": ["armorPts", "flat", 1], "dmgRed": ["armor", "flat", .01], "blockCh": ["blockCh", "flat", .01], "thorns": ["thorns", "flat", 1], "dodge": ["dodge", "flat", .01],
		"resFire": ["resFire", "flat", .01], "resCold": ["resCold", "flat", .01], "resDark": ["resDark", "flat", .01], "resPois": ["resPois", "flat", .01],
		"hpF": ["maxHp", "flat", 1], "hpP": ["maxHp", "pct", .01], "regen": ["regen", "flat", 1], "leech": ["lifesteal", "flat", .01], "killHeal": ["killHeal", "flat", 1],
		"manaF": ["maxMana", "flat", 1], "manaRegP": ["manaRegen", "pct", .01], "potP": ["potionHeal", "pct", .01], "fountP": ["healMul", "pct", .01], "spdP": ["spd", "pct", .01],
		"rollP": ["rollCdMax", "pct", -.01], "cdr": ["cdr", "flat", .01], "durP": ["skillDur", "pct", .01], "chainT": ["chainT", "flat", 1], "lightP": ["light", "pct", .01],
		"goldP": ["goldMul", "pct", .01], "findP": ["findMul", "pct", .01], "keyP": ["keyMul", "pct", .01], "xpP": ["xpMul", "pct", .01]}
	for f in FX:
		var n := rv(f)
		if n == 0:
			continue
		var d: Array = FX[f]
		out.append({"stat": d[0], d[1]: n * d[2]})
	var th := _theme()
	for v in lst("biome"):
		if v[0] == th:
			for st in ["resFire", "resCold", "resDark", "resPois"]:
				out.append({"stat": st, "flat": v[1] / 100.0})
	if rv("streak") and h.chain >= 10: out.append({"stat": "atkSpd", "pct": rv("streak") / 100.0})
	if rv("drainSteal") and sim.skill_on_id("drain"): out.append({"stat": "lifesteal", "flat": rv("drainSteal")})
	if rv("ancient"): out.append_array([{"stat": "skillDur", "pct": .2 * rv("ancient")}, {"stat": "cdr", "flat": .1 * rv("ancient")}])
	if rv("dragonBlood"): out.append({"stat": "regen", "flat": h.st.get("maxHp", 100) * .02})
	if rv("vampire"): out.append_array([{"stat": "lifesteal", "flat": .1}, {"stat": "healMul", "mult": 0.0}])
	if rv("lordDark"): out.append({"stat": "light", "mult": 3.0})
	if rv("greed"): out.append({"stat": "findMul", "pct": 1.0})
	if rv("usurer"): out.append({"stat": "goldMul", "pct": .5})
	if rv("gloryOrDeath"): out.append_array([{"stat": "dmg", "mult": 2.0}, {"stat": "maxHp", "mult": .5}])
	if rv("ironOath"): out.append({"stat": "dmg", "flat": floorf(h.st.get("armorPts", 0) / 20.0)})
	if rv("fearless"):
		var n := 0
		for e: Ent.Enemy in sim.enemies:
			if not e.dying and e.state != "idle" and JS.hypot(e.x - h.x, e.y - h.y) < 90:
				n += 1
		if n:
			out.append({"stat": "armorPts", "flat": mini(40, 5 * n)})
	return out

func _theme() -> String:
	if sim.L.is_empty():
		return ""
	var th: String = sim.L.get("theme", "")
	return "hell" if th == "souls" else th

# ---------- utilidades de combate ----------
func groups(e: Ent.Enemy) -> Array:
	var g := []
	if e.hero == "minion": g.append("undead")
	elif e.hero != "": g.append("hero")
	else:
		if e.type == "knight": g.append("knight")
		if e.type == "slayer": g.append("slayer")
		if e.type == "sargwen" or e.thrower: g.append("thrower")
		if e.type == "champ": g.append("champ")
	if e.rare: g.append("rare")
	if e.mimic: g.append("mimic")
	return g

func dtype(src) -> String:
	if src == null or not (src is Ent.Enemy) or src.hero == "":
		return "phys"
	match src.hero:
		"mage": return "fire"
		"dk", "dl": return "dark"
		"archer": return "poison"
		"minion": return "cold"
	return "phys"

func armored(e: Ent.Enemy) -> bool:
	return e.rare or e.type == "champ" or (e.hero != "" and e.hero != "minion") or e.act == "guard"

func awake_near(r: float) -> int:
	var p := sim.p
	var n := 0
	for e: Ent.Enemy in sim.enemies:
		if not e.dying and e.state != "idle" and JS.hypot(e.x - p.x, e.y - p.y) < r:
			n += 1
	return n

func room_doors_closed() -> int:
	var k := sim.room_at_px(sim.p.x, sim.p.y)
	if k < 0:
		return 0
	var n := 0
	for d in sim.doors:
		if d.room == k and not d.open:
			n += 1
	return n

func near_light() -> bool:
	var p := sim.p
	for tr in sim.L.get("torches_px", []):
		if JS.hypot(tr.x - p.x, tr.y - p.y) < 110:
			return true
	for w in sim.L.get("windows", []):
		if JS.hypot((w.cx + .5) * Sim.TS - p.x, (w.cy + 1.5) * Sim.TS - p.y) < 110:
			return true
	return false

func on_bridge() -> bool:
	return not sim.L.is_empty() and sim.tile_at(sim.cell_of(sim.p.x), sim.cell_of(sim.p.y - 2)) == DungeonGen.BRIDGE

## daño propio de las runas (venenos, rayos, ondas…): sin más efectos encadenados
func rdmg(e: Ent.Enemy, dmg: float, col: String = "#d8a0ff", size: float = 9) -> int:
	if e == null or e.dying:
		return 0
	var n := maxi(1, JS.roundi(dmg * (1.3 if rv("blackPlague") and e.rn_pois_t > 0 else 1.0)))
	e.hp -= n
	sim.p.dmg_dealt += n
	e.flash = maxf(e.flash, .04)
	sim.fx.text(e.x, e.y - 36, str(n), col, size)
	if e.state == "idle":
		sim.wake(e)
	if e.hp <= 0:
		sim.kill_enemy(e, atan2(e.y - sim.p.y, e.x - sim.p.x))
	return n

func stun(e: Ent.Enemy, t: float) -> void:
	if e.dying:
		return
	e.frozen = maxf(e.frozen, t)
	e.act = ""
	e.vx *= .3
	e.vy *= .3

func bleed(e: Ent.Enemy, dps: float, dur: float) -> void:
	if e.dying:
		return
	var mx := 3 if rv("hemo") else 1
	if e.rn_bleed.size() >= mx:
		e.rn_bleed.sort_custom(func(a, b): return a.t < b.t)
		e.rn_bleed[0] = {"t": dur, "d": dps}
	else:
		e.rn_bleed.append({"t": dur, "d": dps})
	e.rn_bleed_t = 0.0
	for b in e.rn_bleed:
		e.rn_bleed_t = maxf(e.rn_bleed_t, b.t)

func poison(e: Ent.Enemy, dps: float, dur: float) -> void:
	if e.dying:
		return
	e.rn_pois_d = maxf(e.rn_pois_d, dps)
	e.rn_pois_t = maxf(e.rn_pois_t, dur)

func slow(e: Ent.Enemy, dur: float) -> void:
	if e.dying:
		return
	e.rn_slow_t = maxf(e.rn_slow_t, dur)
	e.rn_slow_n += 1
	if rv("deepFrost") and e.rn_slow_n >= 3:
		e.rn_slow_n = 0
		stun(e, 1.5)
		sim.fx.text(e.x, e.y - 56, "congelado", "#a8e0ff", 9)

func burn(e: Ent.Enemy, dmg: float, dur: float) -> void:
	if e.dying:
		return
	e.burn_d = maxf(e.burn_d, dmg)
	e.burn_t = maxf(e.burn_t, dur)
	if not (e.burn_tick > 0):
		e.burn_tick = .5

func bolt(x0: float, y0: float, x1: float, y1: float, col: String = "#cfe6ff") -> void:
	bolts.append({"x0": x0, "y0": y0, "x1": x1, "y1": y1, "t": .18, "col": col})

## golpe del héroe, justo antes de restar la vida. kind: melee (tajo o giro), hit (habilidad), dot (tic de daño)
func hit(e: Ent.Enemy, dmg: float, kind: String, crit: bool) -> int:
	var p := sim.p
	var g := groups(e)
	var d := JS.hypot(e.x - p.x, e.y - p.y)
	var hpk := e.hp / e.max_hp
	var add := 0.0
	if kind != "dot":
		for k in ["fireAdd", "coldAdd", "lightAdd"]:
			var a = A.get(k)
			if a is Array:
				add += a[0] + sim.rnd() * (a[1] - a[0])
	var pct := 0.0
	var mul := 1.0
	for v in lst("vs"):
		if g.has(v[0]): pct += v[1] / 100.0
	for v in lst("guard"):
		if g.has(v[0]): pct += v[1] / 100.0
	for v in lst("vs3"):
		if g.has(v[0]): pct += v[1] / 100.0
	var th := _theme()
	for v in lst("biome"):
		if v[0] == th: pct += v[1] / 100.0
	if rv("near") and d < 64: pct += rv("near") / 100.0
	if rv("far") and d >= 96: pct += rv("far") / 100.0
	if rv("low") and hpk < .35: pct += rv("low") / 100.0
	var stunned := e.frozen > 0
	var chilled := e.frozen > 0 or e.rn_slow_t > 0
	if rv("stunned") and stunned: pct += rv("stunned") / 100.0
	if rv("chilled") and chilled: pct += rv("chilled") / 100.0
	if rv("bleeding") and e.rn_bleed_t > 0: pct += rv("bleeding") / 100.0
	if rv("burning") and e.burn_t > 0: pct += rv("burning") / 100.0
	if rv("ambush") and e.state == "idle": pct += rv("ambush") / 100.0
	if rv("afterRoll") and p.rn_after_roll > 0 and kind != "dot":
		pct += rv("afterRoll") / 100.0
		p.rn_after_roll = 0
	if rv("counter") and p.rn_counter > 0 and kind != "dot":
		pct += rv("counter") / 100.0
		p.rn_counter = 0
	if rv("full") and p.hp >= p.st.maxHp: pct += rv("full") / 100.0
	if rv("desperate") and p.hp < p.st.maxHp * .3: pct += rv("desperate") / 100.0
	if rv("doors") and room_doors_closed(): pct += rv("doors") / 100.0
	if rv("siege"): pct += .05 * rv("siege") * room_doors_closed()
	if rv("pen") and armored(e): pct += rv("pen") / 100.0
	if rv("bloodWave") and p.rn_wave > 0: pct += .05 * mini(5, p.rn_wave_n)
	if rv("rampage") and kind != "dot":
		if p.rn_ramp_e == e:
			p.rn_ramp_n = mini(10, p.rn_ramp_n + 1)
		else:
			p.rn_ramp_e = e
			p.rn_ramp_n = 0
		pct += .04 * p.rn_ramp_n
	if rv("goldSlayer") and (e.rare or e.type == "champ"): pct += .4 * rv("goldSlayer")
	if rv("loneWolf") and sim.allies.is_empty(): pct += .2 * rv("loneWolf")
	if rv("vengeance") and p.rn_veng_t > 0: pct += .3
	if rv("thousand"): pct += minf(.5, kills * .01)
	if rv("fallenRevenge"): pct += .25 * revives
	if rv("hereticHammer") and (g.has("undead") or g.has("hero")): pct += 1
	if rv("blackPlague") and e.rn_pois_t > 0: mul *= 1.3
	if rv("volcano") and kind != "dot": burn(e, maxf(1, p.st.dmg * .25), 3)
	dmg = (dmg + add) * (1 + pct) * mul
	# críticos forzados
	var fcrit := false
	if not crit and kind != "dot":
		if rv("hundred") and p.rn_hundred:
			p.rn_hundred = false
			fcrit = true
		elif rv("lastKnight") and awake_near(220) >= 5:
			fcrit = true
		elif rv("coldGaze") and chilled and sim.rnd() < p.st.crit * .2 * rv("coldGaze"):
			fcrit = true
		if fcrit:
			dmg *= p.st.critMult
	var is_crit := crit or fcrit
	# ejecuciones
	if kind != "dot":
		if rv("execLow") and hpk < .15 and not e.rare and e.type != "champ": dmg = maxf(dmg, e.hp)
		if has_vs3("undead") and g.has("undead") and hpk < .3: dmg = maxf(dmg, e.hp)
		if rv("critExec") and is_crit and hpk < .2: dmg = maxf(dmg, e.hp)
	var n := maxi(1, JS.roundi(dmg))
	if kind != "dot":
		_procs(e, n, is_crit, g)
	return n

## efectos que se disparan al golpear (no en los tics)
func _procs(e: Ent.Enemy, dmg: int, crit: bool, g: Array) -> void:
	var p := sim.p
	if rv("stunCh") and sim.rnd() < rv("stunCh") / 100.0: stun(e, .5)
	if rv("bleedCh") and sim.rnd() < rv("bleedCh") / 100.0: bleed(e, maxf(1, JS.round(p.st.dmg * .2)), 3)
	if rv("burnCh") and sim.rnd() < rv("burnCh") / 100.0: burn(e, maxf(1, p.st.dmg * .25), 3)
	if rv("slowCh") and sim.rnd() < rv("slowCh") / 100.0: slow(e, 2)
	if rv("poison"): poison(e, rv("poison"), 3)
	if rv("bloodHeal") and e.rn_bleed_t > 0: sim.heal(p, 1)
	if g.has("hero") and has_vs3("hero"): sim.leech(dmg)
	if g.has("knight") and has_vs3("knight"): e.rn_no_block = 2
	if crit and g.has("champ") and has_vs3("champ"): stun(e, 1)
	if rv("disarm") and sim.rnd() < .1:
		e.rn_disarm = 3
		sim.fx.text(e.x, e.y - 58, "desarmado", "#ffd25a", 9)
	if rv("charge") and p.rn_charged:
		p.rn_charged = false
		p.rn_run = 0
		stun(e, 1)
		sim.fx.text(e.x, e.y - 58, "¡derribado!", "#ffd25a", 9)
	if rv("winter") and e.hp / e.max_hp < .5 and not (e.rn_winter_cd > 0):
		e.rn_winter_cd = 4
		stun(e, 1)
		sim.fx.burst(e.x, e.y, 20, ["#e8f6ff", "#a8d8ff", "#5a9ad8"], 12, 60)
	if p.chain > 0 and (p.chain + 1) % 10 == 0:
		p.rn_hundred = true
	if rv("doubleHit") and sim.rnd() < .1: queue.append({"k": "double", "e": e, "dmg": dmg})
	if rv("shockwave") and crit: queue.append({"k": "shock", "e": e, "dmg": dmg})
	if rv("chainLight") and sim.rnd() < .15: queue.append({"k": "chain", "e": e, "dmg": dmg})
	if rv("ghostBlade"):
		p.rn_ghost_n += 1
		if p.rn_ghost_n >= 4:
			p.rn_ghost_n = 0
			queue.append({"k": "ghost", "e": e, "dmg": dmg})
	if rv("spinCut"):
		p.rn_spin_n += 1
		if p.rn_spin_n >= 3:
			p.rn_spin_n = 0
			queue.append({"k": "spin", "e": e, "dmg": dmg})

## lo que queda en cola se resuelve en el paso siguiente (así no se mata a nadie a mitad de un bucle)
func _run_queue() -> void:
	if queue.is_empty():
		return
	var q := queue
	queue = []
	var p := sim.p
	for it in q:
		var e: Ent.Enemy = it.e
		match String(it.k):
			"double":
				if not e.dying:
					sim.fx.text(e.x, e.y - 58, "¡doble!", "#ffd25a", 9)
					rdmg(e, it.dmg, "#ffb070", 11)
			"shock":
				sim.fx.burst(e.x, e.y, 10, ["#fff3c0", "#ffd25a"], 18, 140)
				for o: Ent.Enemy in sim.enemies.duplicate():
					if o == e or o.dying:
						continue
					if JS.hypot(o.x - e.x, o.y - e.y) < 52:
						rdmg(o, it.dmg * .5, "#ffd25a", 10)
						var a := atan2(o.y - e.y, o.x - e.x)
						o.vx += cos(a) * 120
						o.vy += sin(a) * 120
			"chain":
				var from := e
				var done := [e]
				for n in 3:
					var best: Ent.Enemy = null
					var bd := 95.0
					for o: Ent.Enemy in sim.enemies:
						if o.dying or done.has(o):
							continue
						var d := JS.hypot(o.x - from.x, o.y - from.y)
						if d < bd:
							bd = d
							best = o
					if best == null:
						break
					bolt(from.x, from.y - 16, best.x, best.y - 16)
					rdmg(best, it.dmg * .5, "#cfe6ff", 10)
					done.append(best)
					from = best
			"ghost":
				var a := p.face
				var ux := cos(a)
				var uy := sin(a)
				slashes.append({"x": p.x, "y": p.y - 14, "a": a, "t": .3})
				for o: Ent.Enemy in sim.enemies.duplicate():
					if o.dying:
						continue
					var dx := o.x - p.x
					var dy := o.y - p.y
					var along := dx * ux + dy * uy
					var side := absf(-dx * uy + dy * ux)
					if along > 0 and along < 150 and side < 18:
						rdmg(o, it.dmg * .6, "#bfe6ff", 10)
			"spin":
				for k in 16:
					var a := k / 16.0 * TAU
					sim.fx.part({"x": p.x + cos(a) * 30, "y": p.y + sin(a) * 18, "z": 10, "vx": -sin(a) * 120, "vy": cos(a) * 70, "vz": 6, "float": true, "life": .25, "col": "#e6edf2"})
				for o: Ent.Enemy in sim.enemies.duplicate():
					if not o.dying and JS.hypot(o.x - p.x, o.y - p.y) < 56:
						rdmg(o, it.dmg * .5, "#e6edf2", 10)

# ---------- al matar ----------
func on_kill(e: Ent.Enemy) -> void:
	var p := sim.p
	kills += 1
	if p.st.killHeal > 0: sim.heal(p, p.st.killHeal, "#ff8a7a", 9)
	if rv("bloodWave") and JS.hypot(e.x - p.x, e.y - p.y) < 160:
		p.rn_wave = 5
		p.rn_wave_n = mini(5, p.rn_wave_n + 1)
	if rv("embers") and e.burn_t > 0:
		for o: Ent.Enemy in sim.enemies:
			if o != e and not o.dying and JS.hypot(o.x - e.x, o.y - e.y) < 50:
				burn(o, maxf(1, p.st.dmg * .25), 3)
	if rv("fireBoom") and e.burn_t > 0:
		sim.fx.burst(e.x, e.y, 12, ["#ff7a18", "#ffd25a", "#5a1404"], 26, 150)
		sim.fx.shake(3)
		for o: Ent.Enemy in sim.enemies:
			if o != e and not o.dying and JS.hypot(o.x - e.x, o.y - e.y) < 56:
				queue.append({"k": "double", "e": o, "dmg": 30 * rv("fireBoom")})
	if rv("plague") and e.rn_pois_t > 0:
		for o: Ent.Enemy in sim.enemies:
			if o != e and not o.dying and JS.hypot(o.x - e.x, o.y - e.y) < 70:
				poison(o, e.rn_pois_d, 3)
	if rv("feast") and (e.rare or e.type == "champ"):
		sim.heal(p, p.st.maxHp, "#ff8a7a", 13)
		sim.fx.text(p.x, p.y - 64, "¡Festín!", "#ffd25a", 12, true)
	if rv("brokenClock"):
		for s in p.sk:
			s.cd = maxf(0, s.cd - 1)
	if rv("deadKing") and e.hero != "minion" and not e.mimic and sim.allies.size() < 6:
		e.no_corpse = true
		var a := Ent.Ally.new()
		a.x = e.x; a.y = e.y; a.face = e.face
		a.t = skp("raise", "dur") * p.st.skillDur; a.max_t = a.t
		a.seed = sim.rnd() * 9
		sim.allies.append(a)
		sim.fx.burst(e.x, e.y - 10, 10, ["#e6d0ff", "#9a4dff", "#3a1660"], 20, 90)
	if rv("midas") and not e.rare and e.type != "champ" and e.hero != "minion":
		sim.drop_gold(e.x, e.y, (3 + sim.rnd() * 7) * (1 + sim.wave * .12), true)
	if rv("cleanRoom"):
		var k := sim.room_at_px(e.x, e.y)
		if k >= 0:
			var left := false
			for o: Ent.Enemy in sim.enemies:
				if o != e and not o.dying and sim.room_at_px(o.x, o.y) == k:
					left = true
					break
			if not left:
				sim.heal(p, p.st.maxHp * .15, "#ff8a7a", 11)
				sim.fx.text(p.x, p.y - 64, "Sala limpia", "#9ad87a", 10)

# ---------- daño recibido: devuelve el que queda (0 = no te ha tocado) ----------
func hurt(dmg: float, src, kind: String, fx_: float, fy: float) -> float:
	var p := sim.p
	if src is Ent.Enemy and src.rn_disarm > 0 and kind != "shot":
		return 0
	if p.st.dodge > 0 and sim.rnd() < p.st.dodge:
		sim.fx.text(p.x, p.y - 46, "esquivado", "#bfe6ff", 10)
		return 0
	if rv("aegis") and not (p.rn_aegis_t > 0):
		p.rn_aegis_t = 10
		sim.fx.text(p.x, p.y - 46, "anulado", "#ffd25a", 10)
		sim.fx.burst(p.x, p.y, 18, ["#fff3c0", "#ffd25a"], 16, 90)
		return 0
	var ty := dtype(src)
	var res := 0.0
	match ty:
		"fire": res = p.st.resFire
		"cold": res = p.st.resCold
		"dark": res = p.st.resDark
		"poison": res = p.st.resPois
	dmg *= 1 - minf(.75, res)
	if p.st.armorPts > 0:
		dmg *= 100.0 / (100.0 + p.st.armorPts)
	var red := 0.0
	if rv("cornered") and awake_near(90) >= 3: red += rv("cornered") / 100.0
	if rv("gloom") and not near_light(): red += rv("gloom") / 100.0
	if rv("stoneSkin") and p.rn_still > 1: red += .25
	if rv("bridgeGuard") and on_bridge(): red += .1 * rv("bridgeGuard")
	if src is Ent.Enemy:
		var g := groups(src)
		for v in lst("guard"):
			if g.has(v[0]): red += v[2] / 100.0
	dmg *= maxf(.1, 1 - red)
	if rv("greed"): dmg *= 1.2
	if rv("usurer"): dmg *= 1.1
	# bloqueo sin levantar el escudo
	if not p.blocking and p.st.blockCh > 0 and sim.rnd() < p.st.blockCh:
		dmg *= maxf(p.st.blockRed, .25)
		sim.fx.text(p.x, p.y - 52, "bloqueado", "#8fd0ea", 8)
		on_block(src, dmg)
	# a quien te golpea
	if src is Ent.Enemy and not src.dying and kind != "shot" and kind != "proj" and kind != "dot":
		if p.st.thorns > 0:
			queue.append({"k": "double", "e": src, "dmg": p.st.thorns})
			if rv("bloodThorns"):
				bleed(src, maxf(1, JS.round(p.st.thorns * .5)), 3)
		if rv("holyLight") and src.hero == "minion":
			burn(src, maxf(1, p.st.dmg * .4), 2)
	if rv("soulMirror") and src is Ent.Enemy and not src.dying and ty != "phys":
		queue.append({"k": "double", "e": src, "dmg": dmg * .5})
	return maxf(1, JS.round(dmg))

func on_block(src, dmg: float) -> void:
	var p := sim.p
	if rv("liveShield"): sim.heal(p, p.st.maxHp * .03 * rv("liveShield"), "#8fd0ea", 9)
	if rv("counter"): p.rn_counter = 1
	if not (src is Ent.Enemy) or src.dying:
		return
	if rv("reflect"): queue.append({"k": "double", "e": src, "dmg": maxf(1, src.dmg if src.dmg else dmg)})
	if rv("autoRiposte"): queue.append({"k": "double", "e": src, "dmg": p.st.dmg})
	if rv("perfectParry") and p.blocking and p.block_t < .3:
		stun(src, 2)
		sim.fx.text(src.x, src.y - 58, "¡parada perfecta!", "#ffd25a", 9)

## golpe mortal: «Inmortal» y «Último aliento» (una vez por piso cada una)
func lethal() -> void:
	var p := sim.p
	if p.hp > 0:
		return
	if rv("immortal") and not immortal_used:
		immortal_used = true
		p.hp = p.st.maxHp
		p.inv = maxf(p.inv, 1.5)
		sim.fx.banner("Inmortal", "Vuelves con toda la vida")
		sim.fx.burst(p.x, p.y, 20, ["#fff3c0", "#ffd25a", "#ff8a3a"], 40, 160)
		return
	if rv("lastBreath") and not breath_used:
		breath_used = true
		p.hp = 1
		p.inv = maxf(p.inv, 1)
		sim.fx.text(p.x, p.y - 64, "¡Último aliento!", "#ffd25a", 13, true)

# ---------- voltereta, habilidades, pociones, piso ----------
func on_roll(aim: Vector2, aim_mouse: bool) -> void:
	var p := sim.p
	p.rn_after_roll = 2
	p.rn_roll_hit = []
	p.rn_trail_t = 0
	if rv("specterStep"):
		p.roll_cd = 0
		if p.hp > 4:
			p.hp -= 3
			sim.fx.text(p.x, p.y - 40, "-3", "#c0a0ff", 9)
	if rv("ashWings"):
		var tx := aim.x if aim_mouse else p.x + p.roll_dx * 128
		var ty := aim.y if aim_mouse else p.y + p.roll_dy * 128
		var dx := tx - p.x
		var dy := ty - p.y
		var d := JS.hypot(dx, dy)
		if d > 128:
			tx = p.x + dx / d * 128
			ty = p.y + dy / d * 128
		sim.fx.burst(p.x, p.y, 16, ["#ff7a18", "#2a1a14", "#ffd25a"], 20, 90)
		var L0 := maxf(1, JS.hypot(tx - p.x, ty - p.y))
		var ux := (tx - p.x) / L0
		var uy := (ty - p.y) / L0
		var k := 0
		while not sim.fits(tx, ty) and k < 60:
			tx -= ux * 4
			ty -= uy * 4
			k += 1
		if sim.fits(tx, ty) and sim.clear_path(p.x, p.y, tx, ty):
			p.x = tx
			p.y = ty
			sim.unstick(p)
		p.roll_t = minf(p.roll_t, .05)
		sim.fx.burst(p.x, p.y, 16, ["#ff7a18", "#2a1a14", "#ffd25a"], 20, 90)
	if rv("ghostRoll"):
		for e: Ent.Enemy in sim.enemies:
			if e.dying or e.state == "idle" or e.type == "champ" or e.boss != "":
				continue
			if JS.hypot(e.x - p.x, e.y - p.y) < 170:
				e.state = "idle"
				e.wake_t = 1.4
				e.act = ""
				e.idle_t = 1
	if rv("miniFount") and not fount_used:
		fount_used = true
		fonts.append({"x": p.x, "y": p.y, "t": 5.0, "tk": 0.0})
		sim.fx.text(p.x, p.y - 60, "Fuente portátil", "#7ad0ff", 10)

func on_skill(s: Dictionary) -> void:
	var p := sim.p
	if rv("mastery"):
		for o in p.sk:
			if o != s:
				o.cd = maxf(0, o.cd - 2 * rv("mastery"))
	if rv("resonance"): sim.heal(p, p.st.maxHp * .05 * rv("resonance"), "#ff8a7a", 10)
	if rv("warEcho") and sim.rnd() < .5:
		s.cd = 0
		sim.fx.text(p.x, p.y - 66, "¡Eco!", "#ffd25a", 10)

func on_potion() -> void:
	if rv("potionRush"):
		sim.add_effect(sim.p, "rnPotRush", [{"stat": "atkSpd", "pct": .2}], 5)

func on_floor() -> void:
	immortal_used = false; breath_used = false; fount_used = false; picked = false; lock_used = false
	kills = 0; revives = 0
	fonts = []; queue = []; bolts = []; slashes = []; fires = []
	if rv("cartographer"):
		sim.explored.fill(1)
		sim.map_dirty = true
	elif rv("dowser") and sim.L.has("stairs_cell"):
		var c: Dictionary = sim.L.stairs_cell
		sim.reveal(c.cx, c.cy)

## con «Señor de la Oscuridad» los enemigos te notan a la mitad de distancia
func see() -> float:
	return .5 if rv("lordDark") else 1.0

func chain_hold() -> bool:
	return rv("endlessRage") and sim.p.chain > 0 and awake_near(260) > 0

func lockpick() -> bool:
	if rv("lockpick") and not lock_used:
		lock_used = true
		picked = true
		sim.fx.text(sim.p.x, sim.p.y - 62, "Cerradura forzada", "#e8d8a0", 10, false, 1, false, false)
		return true
	return false

## ralentización de los enemigos: árbol (Estandarte, Aura helada), runas, Lluvia helada y Asfixia
func e_slow(e: Ent.Enemy) -> float:
	var k := sim.arbol.e_slow(e)
	if e.rn_slow_t > 0:
		k *= .7
	return k * sim.cls.slow(e) * sim.vel_mov   # vel_mov: Opciones «Velocidad al andar»

# ---------- cada paso ----------
func tick(dt: float) -> void:
	var p := sim.p
	var fx := sim.fx
	# guardián del puente: aviso al pisar el puente y brillo acerado a los pies
	var onb := rv("bridgeGuard") > 0 and not p.dead and on_bridge()
	if onb and not p.rn_bridge:
		fx.text(p.x, p.y - 60, "Guardián del puente", "#bfe0ff", 9)
	p.rn_bridge = onb
	if onb and sim.rnd() < dt * 10:
		var a := sim.rnd() * TAU
		fx.part({"x": p.x + cos(a) * 10, "y": p.y + sin(a) * 4, "z": 2, "vx": 0, "vy": 0, "vz": 16, "float": true, "life": .5, "col": "#bfe0ff" if sim.rnd() < .5 else "#7fa8d8"})
	_run_queue()
	p.rn_aegis_t -= dt
	p.rn_after_roll -= dt
	if p.rn_wave > 0:
		p.rn_wave -= dt
		if p.rn_wave <= 0:
			p.rn_wave_n = 0
	p.rn_veng_t -= dt
	p.rn_still = 0.0 if (p.moving or p.roll_t > 0) else p.rn_still + dt
	if rv("charge"):
		if p.moving and not p.blocking and p.roll_t <= 0:
			p.rn_run += dt
			if p.rn_run >= 2 and not p.rn_charged:
				p.rn_charged = true
				fx.text(p.x, p.y - 60, "¡Carga lista!", "#ffd25a", 9)
		elif not p.rn_charged:
			p.rn_run = 0
	# segunda piel
	p.rn_skin_cd -= dt
	if rv("secondSkin") and not p.dead and p.hp < p.st.maxHp * .3 and not (p.rn_skin_cd > 0):
		p.rn_skin_cd = 30
		p.shield = maxf(p.shield, JS.round(p.st.maxHp * .2))
		fx.text(p.x, p.y - 60, "Segunda piel", "#8fd0ea", 11, true)
		fx.hud()
	# voltereta: danza de acero y rastro de fuego
	if p.roll_t > 0:
		if rv("steelDance"):
			for e: Ent.Enemy in sim.enemies:
				if e.dying or p.rn_roll_hit.has(e):
					continue
				if JS.hypot(e.x - p.x, e.y - p.y) < 18:
					p.rn_roll_hit.append(e)
					queue.append({"k": "double", "e": e, "dmg": 10 * rv("steelDance")})
		if rv("fireTrail"):
			p.rn_trail_t -= dt
			if p.rn_trail_t <= 0:
				p.rn_trail_t = .06
				fires.append({"x": p.x, "y": p.y, "r": 16.0, "t": 2.0, "tick": 0.0})
	# rastro de fuego
	for f in fires:
		f.t -= dt
		f.tick -= dt
		if f.tick <= 0:
			f.tick = .5
			for e: Ent.Enemy in sim.enemies.duplicate():
				if not e.dying and JS.hypot(e.x - f.x, e.y - f.y) < f.r:
					sim.dk_damage(e, p.st.dmg * .4, atan2(e.y - f.y, e.x - f.x), true, "#ffb03a")
		if sim.rnd() < dt * 30:
			var a := sim.rnd() * TAU
			var r: float = sqrt(sim.rnd()) * f.r
			fx.part({"x": f.x + cos(a) * r, "y": f.y + sin(a) * r * .6, "z": 2, "vx": 0, "vy": 0, "vz": 24 + sim.rnd() * 20, "float": true, "life": .45, "col": "#ff7a18" if sim.rnd() < .5 else "#ffb03a"})
	fires = fires.filter(func(f): return f.t > 0)
	# fuentes portátiles
	for f in fonts:
		f.t -= dt
		f.tk -= dt
		if f.tk <= 0:
			f.tk = .5
			if JS.hypot(p.x - f.x, p.y - f.y) < 34:
				sim.heal(p, p.st.maxHp * .03, "#7ad0ff", 9)
		if sim.rnd() < dt * 20:
			var a := sim.rnd() * TAU
			var r := sim.rnd() * 30
			fx.part({"x": f.x + cos(a) * r, "y": f.y + sin(a) * r * .5, "z": 2, "vx": 0, "vy": 0, "vz": 30, "float": true, "life": .5, "col": "#7ad0ff" if sim.rnd() < .5 else "#e0f6ff"})
	fonts = fonts.filter(func(f): return f.t > 0)
	# ojo de la tormenta
	if rv("storm"):
		storm_t -= dt
		if storm_t <= 0:
			storm_t = 3
			var best: Ent.Enemy = null
			var bd := 180.0
			for e: Ent.Enemy in sim.enemies:
				if e.dying or e.state == "idle":
					continue
				var d := JS.hypot(e.x - p.x, e.y - p.y)
				if d < bd:
					bd = d
					best = e
			if best != null:
				bolt(best.x, best.y - 120, best.x, best.y - 10, "#e6f2ff")
				fx.burst(best.x, best.y, 20, ["#e6f2ff", "#9ad0ff"], 14, 90)
				rdmg(best, p.st.dmg * 2 * rv("storm"), "#cfe6ff", 12)
				fx.shake(3)
	# esbirros perdidos → venganza
	var na := sim.allies.size()
	if rv("vengeance") and na < ally_n:
		p.rn_veng_t = 5
	ally_n = na
	# estados de los enemigos
	dot_t -= dt
	var dot := dot_t <= 0
	if dot:
		dot_t = .5
	for e: Ent.Enemy in sim.enemies.duplicate():
		if e.dying:
			continue
		e.rn_slow_t -= dt
		e.rn_no_block -= dt
		e.rn_winter_cd -= dt
		if e.rn_disarm > 0:
			e.rn_disarm -= dt
			if e.act == "wind" or e.act == "strike" or e.act == "throw":
				e.act = ""
			e.cool = maxf(e.cool, .2)
		if e.burn_t > 0:
			e.burn_t -= dt
			e.burn_tick -= dt
			if e.burn_tick <= 0:
				e.burn_tick = .5
				sim.dk_damage(e, e.burn_d, e.face + PI, true, "#ffb03a")
			if sim.rnd() < dt * 10:
				fx.part({"x": e.x + (sim.rnd() - .5) * 12, "y": e.y, "z": 6 + sim.rnd() * 22, "vx": 0, "vy": 0, "vz": 30, "float": true, "life": .4, "col": "#ffb03a" if sim.rnd() < .5 else "#ff5a10"})
			if e.burn_t <= 0:
				e.burn_d = 0
		if e.dying:
			continue
		if e.rn_pois_t > 0:
			e.rn_pois_t -= dt
			if dot:
				rdmg(e, e.rn_pois_d * .5, "#7ad86a", 8)
			if sim.rnd() < dt * 6:
				fx.part({"x": e.x + (sim.rnd() - .5) * 12, "y": e.y, "z": 6 + sim.rnd() * 20, "vx": 0, "vy": 0, "vz": 14, "float": true, "life": .5, "col": "#6ac85a"})
		if not e.dying and e.rn_bleed.size():
			for b in e.rn_bleed:
				b.t -= dt
			if dot:
				var s := 0.0
				for b in e.rn_bleed:
					s += b.d
				rdmg(e, s * .5, "#d8282e", 8)
				if not e.dying:
					fx.bleed(e.x, e.y, 14, sim.rnd() * TAU, 3, 40)
			e.rn_bleed = e.rn_bleed.filter(func(b): return b.t > 0)
			e.rn_bleed_t = 0.0
			for b in e.rn_bleed:
				e.rn_bleed_t = maxf(e.rn_bleed_t, b.t)
		if has_vs3("slayer") and e.type == "slayer" and e.act == "dodge":
			e.act = ""
			e.vx *= .15
			e.vy *= .15
		if rv("championTerror") and (e.rare or e.type == "champ") and not e.rn_terror:
			e.rn_terror = true
			e.hp = minf(e.hp, ceilf(e.max_hp * .5))
			e.ghost = e.hp
	if has_vs3("thrower"):
		for pr in sim.projs:
			if pr.phase == "back" and not pr.get("rn_drop", false):
				pr.rn_drop = true
				pr.phase = "drop"
	for b in bolts:
		b.t -= dt
	bolts = bolts.filter(func(b): return b.t > 0)
	for s in slashes:
		s.t -= dt
	slashes = slashes.filter(func(s): return s.t > 0)

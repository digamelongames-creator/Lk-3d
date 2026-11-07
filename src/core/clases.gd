class_name Clases
extends RefCounted
## Lo propio de cada clase del héroe: Caballero, Mago de fuego, Arquero, Caballero de la Muerte y Señor Oscuro
## (updateMage, mageCast, archerShoot, fxSkill, fxTick, updateDL… del juego web).
## El Caballero de la Muerte sigue en sim.gd (Levantar muertos, Aura, Torbellino); aquí está todo lo demás y
## lo que vuela por el aire: explosiones y bolas de fuego del mago, flechas, lluvias, nubes de muerte.

const MAGE_ATK := {"blast": {"mult": 1.65, "cost": 12.0}, "fireball": {"mult": 3.3, "cost": 18.0}}
const ARC := {"mult": 1.6, "spd": 330.0, "life": .75, "power": {"mult": 3.2, "cd": 1.4, "pierce": 2}}
## boca del arco en cada dirección (a1 tiro normal, a2 tiro cargado), en píxeles del atlas
const BOW_MZ := {"a1": [[25, -37], [16.5, -18.5], [-6, -33], [-20.5, -33], [-23, -46], [-12.7, -56], [6, -60], [21.5, -53.5]],
	"a2": [[25.7, -38.5], [23, -25], [8.7, -16], [-11, -17], [-24, -27], [-21.5, -41], [-7.5, -51], [12.7, -48.5]]}

var sim: Sim
var aoes: Array = []        # explosiones del mago: {x, y, t, max, r, boom}
var fballs: Array = []      # bolas de fuego: {x, y, vx, vy, life, ang, dmg, t, crit}
var arrows: Array = []      # flechas del arquero
var rains: Array = []       # lluvias de flechas: {x, y, r, t, max, tick, delay, mult, slow, burn, drops, mini}
var up_arrows: Array = []   # flechas que suben al lanzar la lluvia
var clouds: Array = []      # nubes de muerte del Señor Oscuro
var fxs: Array = []         # efectos de sprite (explosión de la flecha de fuego)
var in_skill := false       # true mientras se lanza una habilidad (no un ataque básico)

func _init(s: Sim) -> void:
	sim = s

func reset() -> void:
	aoes = []; fballs = []; arrows = []; rains = []; up_arrows = []; clouds = []; fxs = []

func _p() -> Ent.Hero:
	return sim.p

# ======================================================================
#  apuntar
# ======================================================================
## ángulo hacia el cursor o hacia el enemigo más cercano
func hero_aim(h: Ent.Hero, rng_: float = 300) -> float:
	var inp := sim.cur_inp
	if inp != null and inp.aim_mouse:
		return atan2(inp.aim.y - (h.y - 14), inp.aim.x - h.x)
	var best = _nearest(h, rng_)
	return atan2(best.y - h.y, best.x - h.x) if best != null else h.face

## punto en el suelo: cursor, enemigo más cercano o al frente; recortado a maxD
func hero_target(h: Ent.Hero, max_d: float) -> Vector2:
	var inp := sim.cur_inp
	var tx: float
	var ty: float
	if inp != null and inp.aim_mouse:
		tx = inp.aim.x; ty = inp.aim.y
	else:
		var best = _nearest(h, 1e9)
		if best != null:
			tx = best.x; ty = best.y
		else:
			tx = h.x + cos(h.face) * 90; ty = h.y + sin(h.face) * 90
	var dx := tx - h.x
	var dy := ty - h.y
	var d := JS.hypot(dx, dy)
	if d == 0: d = 1
	if d > max_d:
		tx = h.x + dx / d * max_d
		ty = h.y + dy / d * max_d
	return Vector2(tx, ty)

## punto en pantalla: cursor, pecho del enemigo más cercano o al frente
func hero_aim_pt(h: Ent.Hero, rng_: float) -> Vector2:
	var inp := sim.cur_inp
	if inp != null and inp.aim_mouse:
		return inp.aim
	var best = _nearest(h, rng_)
	if best != null:
		return Vector2(best.x, best.y - 14)
	return Vector2(h.x + cos(h.face) * 120, h.y - 20 + sin(h.face) * 120)

func _nearest(h: Ent.Hero, max_d: float):
	var best = null
	var bd := max_d
	for e: Ent.Enemy in sim.enemies:
		if e.dying:
			continue
		var d := JS.hypot(e.x - h.x, e.y - h.y)
		if d < bd:
			bd = d
			best = e
	return best

# ======================================================================
#  acción con animación propia (heroAct): anima «anim» durante «dur» y dispara cb a los «at» s
# ======================================================================
func hero_act(h: Ent.Hero, anim: String, dur: float, at: float, cb: Callable) -> void:
	h.ar_a = anim
	h.ar_t = dur
	h.ar_max = dur
	h.ar_fire = at
	h.ar_cb = cb
	h.seq = null
	h.ar_sk = in_skill

func hero_act_tick(h: Ent.Hero, dt: float) -> void:
	if not (h.ar_t > 0):
		return
	if h.hurt_t > 0 or h.roll_t > 0 or h.dead:
		var cb = h.ar_cb
		h.ar_t = 0
		h.ar_cb = null
		if cb != null and h.ar_sk and not h.dead:
			cb.call()
		return
	h.ar_t -= dt
	if h.ar_cb != null and h.ar_max - h.ar_t >= h.ar_fire:
		var cb: Callable = h.ar_cb
		h.ar_cb = null
		cb.call()
	if h.ar_t <= 0:
		h.ar_t = 0
		h.ar_cb = null

# ======================================================================
#  daño mágico y a distancia (magicHit)
# ======================================================================
func magic_hit(e: Ent.Enemy, base: float, ang: float, kb: float, small: bool, fc: bool = false) -> bool:
	if e.dying:
		return false
	if e.boss != "" and (e.boss_air or e.boss_shield):
		return false
	var h := _p()
	var crit: bool = fc or sim.rnd() < h.st.crit
	base *= sim.arbol.taken_mul(e, small) * sim.back_mul(e, ang) * taken(e)
	var blk := sim.enemy_block(e, h.x, h.y)
	var dmg := maxf(1, JS.round(base * (.85 + sim.rnd() * .3) * (h.st.critMult if crit else 1.0) * (.15 if blk else 1.0)))
	dmg = sim.dmg_mod(e, dmg)
	if dmg <= 0:
		return false
	var di := sim.runes.hit(e, dmg, "dot" if small else "hit", crit)
	e.hp -= di
	h.dmg_dealt += di
	e.flash = .06
	sim.stats.hits += 1
	sim.leech(di)
	sim.fx.text(e.x, e.y - 40, (str(di) + "!") if crit else str(di), "#ff3a2a" if crit else ("#b8303c" if small else "#d8282e"), 14 if crit else (9 if small else 11), crit)
	if kb and not e.armor and not blk:
		var k: float = kb * .5 * h.st.kb / (3.0 if e.rare else 1.0)
		e.vx += cos(ang) * k
		e.vy += sin(ang) * k
	if not small and not e.armor and not (e.frozen > 0) and not blk:
		e.hurt_t = .12
		e.act = ""
	if not blk and not small:
		sim.note_hit(e)
	sim.fx.bleed(e.x, e.y, 16, ang, 5 if small else 16, 110)
	h.chain += 1
	h.chain_t = 1.3 + h.st.chainT
	h.best_chain = maxi(h.best_chain, h.chain)
	if e.hp <= 0:
		sim.kill_enemy(e, ang)
	return true

## daño en el tiempo: nunca cuenta como golpe por la espalda
func dot_hit(e: Ent.Enemy, dmg: float) -> void:
	if e.dying:
		return
	magic_hit(e, dmg, e.face + PI, 0, true)

## daño extra que reciben los enemigos que arden («Pólvora»)
func taken(e: Ent.Enemy) -> float:
	return 1.15 if (e.burn_t > 0 and sim.arbol.has("a_fire_t4")) else 1.0

## ralentización por la Lluvia helada y la Asfixia
func slow(e: Ent.Enemy) -> float:
	var k := 1.0
	for r in rains:
		if r.slow and JS.hypot(e.x - r.x, e.y - r.y) < r.r:
			k *= .6
			break
	for c in clouds:
		if c.slow and JS.hypot(e.x - c.x, e.y - c.y) < c.r:
			k *= .6
			break
	return k

## ¿viene una flecha o un ataque mágico hacia este enemigo? (para que se cubra o ruede)
func threat(e: Ent.Enemy) -> bool:
	for f in arrows:
		if JS.hypot(f.x - e.x, f.y - e.y) < 70 and ((e.x - f.x) * f.vx + (e.y - f.y) * f.vy) > 0:
			return true
	for a in aoes:
		if a.boom <= 0 and JS.hypot(a.x - e.x, a.y - e.y) < a.r + 12:
			return true
	for f in fballs:
		if JS.hypot(f.x - e.x, f.y + 16 - e.y) < 70 and ((e.x - f.x) * f.vx + (e.y - 16 - f.y) * f.vy) > 0:
			return true
	return false

func on_kill(e: Ent.Enemy) -> void:
	var h := _p()
	for c in clouds:
		if JS.hypot(e.x - c.x, e.y - c.y) > c.r:
			continue
		if sim.arbol.has("l_cloud_t4"):
			sim.heal(h, JS.round(h.st.maxHp * .05), "#d07aff", 10)
		if sim.arbol.has("l_cloud_key") and not c.mini:
			clouds.append(new_cloud(e.x, e.y, c.r * .6, 3, true))
		break

func burn_e(e: Ent.Enemy, dmg: float, dur: float) -> void:
	if e.dying:
		return
	e.burn_d = maxf(e.burn_d, dmg)
	e.burn_t = maxf(e.burn_t, dur)
	if not (e.burn_tick > 0):
		e.burn_tick = .5

func spend_mana(h: Ent.Hero, cost: float) -> bool:
	if sim.arbol.has("m_nova_key") and sim.skill_on_id("nova"):   # «Avatar de fuego»
		return true
	if h.mana >= cost:
		h.mana -= cost
		return true
	if not (h.no_mana_t > sim.t - .8):
		h.no_mana_t = sim.t
		sim.fx.text(h.x, h.y - 52, "Sin maná", "#6fa8ff", 10)
	return false

# ======================================================================
#  ataque básico (clic): el mago y el arquero tienen el suyo
# ======================================================================
## devuelve true si la clase tiene un ataque propio (el resto usa el combo de tajos)
func attack() -> bool:
	var h := _p()
	if h.cls == "mage":
		_mage_cast()
		return true
	if h.cls == "archer":
		_archer_shoot()
		return true
	return false

func _mage_cast() -> void:
	var h := _p()
	if h.atk_t > 0 or h.roll_t > 0 or h.dead or h.hurt_t > 0:
		return
	if not spend_mana(h, MAGE_ATK.blast.cost):
		return
	var tg := hero_target(h, Sim.BLINK_MAX)
	h.face = atan2(tg.y - h.y, tg.x - h.x)
	h.flip = tg.x < h.x
	h.atk_t = h.st.atkCd * 3.5
	h.cast_t = .3
	h.shot_t = 0
	aoes.append({"x": tg.x, "y": tg.y, "t": .35, "max": .35, "r": Sim.AOE_R, "boom": 0.0})
	sim.stats.swings += 1

func _archer_shoot() -> void:
	var h := _p()
	if h.atk_t > 0 or h.roll_t > 0 or h.dead or h.hurt_t > 0 or h.ar_t > 0:
		return
	archer_aim(h, 300)
	var dur := minf(.42, .36 / h.st.atkSpd)
	h.atk_t = h.st.atkCd * 2
	hero_act(h, "a1", dur, dur * .75, func():
		var fk := sim.arbol.has("a_fire_key")
		spawn_arrow(h, muzzle_ang(h, "a1"), {"dmg": h.st.dmg * ARC.mult, "burn": h.st.dmg * .2 if fk else 0.0, "burn_dur": 2.0 if fk else 0.0}))

# ======================================================================
#  cada paso, según la clase (antes de moverse)
# ======================================================================
func update(dt: float, inp: Sim.Inp) -> void:
	var h := _p()
	match h.cls_key():
		"mage": _update_mage(dt, inp)
		"archer": _update_archer(dt, inp)
		"dl": _update_dl(dt)
		"knight": _update_knight(dt)
	# precio justo: al acabar el pacto vuelve la vida pagada
	if sim.runes.rv("pactRefund") and h.dl:
		if sim.skill_on_id("pact"):
			h.rn_pact_seen = true
		elif h.rn_pact_seen:
			h.rn_pact_seen = false
			if h.rn_pact_paid > 0:
				sim.heal(h, h.rn_pact_paid, "#ff8a7a", 11)
				h.rn_pact_paid = 0
	# sol interior: la nova no se apaga
	if sim.runes.rv("innerSun") and h.cls == "mage":
		var i := h.skills.find("nova")
		if i >= 0 and h.sk[i].t < .3:
			if not (h.sk[i].t > 0):
				h.nova_tick = 0
				h.nova_x = h.x
				h.nova_y = h.y
			h.sk[i].t = .5
	if h.st.maxMana > 0 and not h.dead:
		h.mana = minf(h.st.maxMana, h.mana + h.st.manaRegen * dt)

func _update_knight(dt: float) -> void:
	var h := _p()
	if not sim.skill_on_id("valor"):
		return
	h.valor_heal_t += dt
	if sim.rnd() < dt * 14:
		sim.fx.part({"x": h.x + (sim.rnd() - .5) * 20, "y": h.y, "z": 4 + sim.rnd() * 26, "vx": 0, "vy": 0, "vz": 26, "float": true, "life": .6, "col": "#ff3b30" if sim.rnd() < .5 else "#ff9a6a"})
	if h.valor_heal_t >= 1:
		h.valor_heal_t -= 1
		sim.heal(h, JS.round(h.st.maxHp * sim.skp("valor", "heal")), "#ff8a7a")

func _update_mage(dt: float, inp: Sim.Inp) -> void:
	var h := _p()
	h.cast_t -= dt
	h.nova_anim -= dt
	h.spell_anim -= dt
	# bola de fuego (clic derecho): un disparo cada segundo, el doble de daño que la explosión
	h.shot_cd -= dt
	h.shot_t -= dt
	var want := inp.block and h.roll_t <= 0 and h.cast_t <= 0
	if want and h.shot_cd <= 0 and spend_mana(h, MAGE_ATK.fireball.cost):
		if inp.aim_mouse:
			h.face = atan2(inp.aim.y - (h.y - 20), inp.aim.x - h.x)
		else:
			var best = _nearest(h, 260)
			if best != null:
				h.face = atan2(best.y - 14 - (h.y - 20), best.x - h.x)
			elif inp.move.length() > .1:
				h.face = atan2(inp.move.y, inp.move.x)
		h.flip = cos(h.face) < 0
		h.shot_ang = h.face
		h.shot_cd = 1 / h.st.atkSpd
		h.shot_t = .4
		h.fire_at = .16
	if h.shot_t > 0:
		h.face = h.shot_ang
	if h.fire_at > 0:
		h.fire_at -= dt
		if h.fire_at <= 0:
			h.face = h.shot_ang
			var ux := cos(h.face)
			var uy := sin(h.face)
			sim.stats.swings += 1
			fballs.append({"crit": sim.arbol.fb_crit(h), "x": h.x + ux * 12, "y": h.y - 20 + uy * 12, "vx": ux * 280, "vy": uy * 280, "life": .85, "ang": h.shot_ang, "dmg": h.st.dmg * MAGE_ATK.fireball.mult, "t": 0.0, "dead": false})
			sim.fx.burst(h.x + ux * 12, h.y, 20, ["#fff0b0", "#ffb03a", "#ff6a10"], 8, 70)
	# nova
	if sim.skill_on_id("nova"):
		var NR := sim.skp("nova", "r")
		var nc := sim.nova_c()
		h.nova_tick -= dt
		if h.nova_tick <= 0:
			h.nova_tick = sim.skp("nova", "tick")
			for e: Ent.Enemy in sim.enemies.duplicate():
				if e.dying:
					continue
				if JS.hypot(e.x - nc.x, e.y - nc.y) < NR:
					magic_hit(e, h.st.dmg * sim.skp("nova", "mult") * (2.0 if sim.arbol.has("m_nova_b") else 1.0), atan2(e.y - nc.y, e.x - nc.x), 40, true)
		if sim.rnd() < dt * 30:
			var a := sim.rnd() * 6.283
			var r := sim.rnd() * NR
			sim.fx.part({"x": nc.x + cos(a) * r, "y": nc.y + sin(a) * r * .75, "z": 2, "vx": -sin(a) * 40, "vy": cos(a) * 30, "vz": 20, "float": true, "life": .5, "col": "#ff7a18" if sim.rnd() < .5 else "#5a1404"})

# ---------------- arquero ----------------
func bow_muzzle(h: Ent.Hero, anim: String) -> Vector2:
	var m: Array = BOW_MZ.get(anim, BOW_MZ.a1)[JS.dir8(h.face)]
	return Vector2(h.x + m[0] * .6, h.y + m[1] * .6)

## apunta: orienta al héroe y guarda el punto; al soltar, la flecha sale del arco hacia ese punto
func archer_aim(h: Ent.Hero, rng_: float) -> Vector2:
	var tg := hero_aim_pt(h, rng_)
	h.face = atan2(tg.y - (h.y - 14), tg.x - h.x)
	h.aim_pt = tg
	return tg

func muzzle_ang(h: Ent.Hero, anim: String) -> float:
	var M := bow_muzzle(h, anim)
	var tg: Vector2 = h.aim_pt if h.aim_pt != null else Vector2(h.x + cos(h.face) * 100, h.y + sin(h.face) * 100)
	return atan2(tg.y - M.y, tg.x - M.x)

func spawn_arrow(h: Ent.Hero, ang: float, o: Dictionary = {}) -> void:
	var ux := cos(ang)
	var uy := sin(ang)
	var spd: float = o.get("spd", ARC.spd)
	var M := bow_muzzle(h, o.get("anim", "a1"))
	var gy := h.y + uy * 3
	var hh := maxf(6, gy - M.y)
	arrows.append({"x": M.x, "y": gy + o.get("dy", 0.0), "h": hh, "vx": ux * spd, "vy": uy * spd, "ang": ang, "life": o.get("life", ARC.life), "dmg": o.dmg,
		"kind": o.get("kind", "n"), "pierce": 99 if sim.runes.rv("eagleEye") else int(o.get("pierce", 0)), "bounce": int(o.get("bounce", 0)), "wb": int(sim.runes.rv("wallBounce")),
		"hit": [], "burn": o.get("burn", 0.0), "burn_dur": o.get("burn_dur", 0.0), "kb": o.get("kb", 50.0), "boom": o.get("boom", false), "crit": o.get("crit", false), "t": 0.0, "dead": false})
	sim.stats.swings += 1

func _archer_power(h: Ent.Hero) -> void:
	archer_aim(h, 320)
	h.pow_cd = ARC.power.cd / h.st.atkSpd
	h.atk_t = maxf(h.atk_t, .2)
	hero_act(h, "a2", .55, .55 * .78, func():
		spawn_arrow(h, muzzle_ang(h, "a2"), {"anim": "a2", "dmg": h.st.dmg * ARC.power.mult, "pierce": ARC.power.pierce, "kb": 140.0, "spd": 400.0, "life": .8, "kind": "p"})
		sim.fx.shake(2))

func _update_archer(dt: float, inp: Sim.Inp) -> void:
	var h := _p()
	h.pow_cd -= dt
	var want := inp.block and h.roll_t <= 0 and h.hurt_t <= 0 and not (h.ar_t > 0)
	if want and h.pow_cd <= 0:
		_archer_power(h)
	hero_act_tick(h, dt)
	if h.multi_q > 0:
		h.multi_qt -= dt
		if h.multi_qt <= 0:
			h.multi_qt = .18
			h.multi_q -= 1
			multi_volley(h)

func multi_volley(h: Ent.Hero) -> void:
	var n := JS.roundi(sim.skp("multi", "count"))
	var narrow := sim.arbol.has("a_multi_a")
	var spr := sim.skp("multi", "spread") * (.5 if narrow else 1.0)
	var mult := sim.skp("multi", "mult") * (1.3 if narrow else 1.0)
	var base := muzzle_ang(h, "a1")
	for k in n:
		var a := base + ((k / float(n - 1) - .5) * spr * 2 if n > 1 else 0.0)
		spawn_arrow(h, a, {"dmg": h.st.dmg * mult, "pierce": 1 if sim.arbol.has("a_multi_t4") else 0, "bounce": 1 if sim.arbol.has("a_multi_b") else 0, "kind": "m"})
	var M := bow_muzzle(h, "a1")
	sim.fx.burst(M.x, M.y + 14, 14, ["#d8e8c8", "#7ad86a"], 8, 60)

func rain_at(x: float, y: float, r: float, dur: float, mini: bool, delay: float = 0) -> void:
	rains.append({"x": x, "y": y, "r": r, "t": dur, "max": dur, "tick": 0.0, "delay": delay, "mult": sim.skp("rain", "mult") * (.6 if mini else 1.0),
		"slow": sim.arbol.has("a_rain_a"), "burn": sim.arbol.has("a_rain_b"), "drops": [], "mini": mini})

func _arrow_hit(e: Ent.Enemy, a: Dictionary) -> void:
	var h := _p()
	if not magic_hit(e, a.dmg, a.ang, a.kb, false, a.crit):
		return
	if a.burn > 0:
		burn_e(e, a.burn, a.burn_dur)
	if a.kind == "n" and sim.arbol.has("a_rain_key"):
		h.rain_cnt += 1
		if h.rain_cnt >= 8:
			h.rain_cnt = 0
			rain_at(e.x, e.y, 34, 1.2, true)

## la flecha vuelve al punto anterior y se refleja en el eje de la pared que tocó («Rebote»)
func _arrow_bounce(a: Dictionary, dt: float) -> bool:
	var wall := func(x: float, y: float) -> bool: return DungeonGen.is_opaque(sim.tile_at(int(floorf(x / Sim.TS)), int(floorf((y - 4) / Sim.TS))))
	var px0: float = a.x - a.vx * dt
	var py0: float = a.y - a.vy * dt
	if wall.call(px0, py0):
		return false
	var hx: bool = wall.call(a.x, py0)
	var hy: bool = wall.call(px0, a.y)
	if hx or not hy: a.vx = -a.vx
	if hy or not hx: a.vy = -a.vy
	a.x = px0
	a.y = py0
	a.ang = atan2(a.vy, a.vx)
	a.wb -= 1
	a.hit = []
	a.life = maxf(a.life, .45)
	a.t = 0
	sim.fx.burst(a.x, a.y - 4, 8, ["#fff3c0", "#c8b48a", "#ffd25a"], a.h, 60)
	return true

# ---------------- Señor Oscuro ----------------
func new_cloud(x: float, y: float, r: float, dur: float, mini: bool) -> Dictionary:
	return {"x": x, "y": y, "r": r, "t": dur, "max": dur, "tick": .2, "mult": sim.skp("cloud", "mult") * (.6 if mini else 1.0),
		"slow": sim.arbol.has("l_cloud_b"), "follow": not mini and sim.arbol.has("l_cloud_a"), "mini": mini, "seed": sim.rnd() * 9}

func _update_dl(dt: float) -> void:
	var h := _p()
	hero_act_tick(h, dt)
	if h.pool_t > 0:
		_update_pool(dt)
	if sim.skill_on_id("pact") and not h.dead and sim.rnd() < dt * 16:
		sim.fx.part({"x": h.x + (sim.rnd() - .5) * 18, "y": h.y, "z": 4 + sim.rnd() * 26, "vx": 0, "vy": 0, "vz": 24, "float": true, "life": .6, "col": "#c0203a" if sim.rnd() < .5 else "#8a3ae0"})

func _update_pool(dt: float) -> void:
	var h := _p()
	h.pool_tick -= dt
	if h.pool_tick <= 0:
		h.pool_tick = .1
		var n := sim.blood_under(h.x, h.y, true)
		h.pool_fast = n > 5 or sim.arbol.has("l_pool_b")
		if n > 0:
			h.pool_acc += minf(h.st.maxHp * sim.skp("pool", "heal") * .1, n * .04)
			if h.pool_acc >= 1:
				var k := floorf(h.pool_acc)
				h.pool_acc -= k
				sim.heal(h, k, "#ff6a7a", 9)
			if sim.arbol.has("l_pool_key") and n > 5 and h.pool_x < 3:
				h.pool_t += .1
				h.pool_x += .1
	if sim.arbol.has("l_pool_a"):
		h.pool_hit -= dt
		if h.pool_hit <= 0:
			h.pool_hit = .5
			for e: Ent.Enemy in sim.enemies.duplicate():
				if e.dying:
					continue
				if JS.hypot(e.x - h.x, e.y - h.y) < 16:
					dot_hit(e, h.st.dmg * .3)
					sim.heal(h, 2, "#ff6a7a", 9)
	if h.moving and sim.rnd() < dt * 20:
		sim.fx.part({"x": h.x + (sim.rnd() - .5) * 16, "y": h.y + (sim.rnd() - .5) * 5, "z": 2, "vx": (sim.rnd() - .5) * 20, "vy": 0, "vz": 30 + sim.rnd() * 30, "life": .35, "col": "#a01828" if sim.rnd() < .5 else "#5a0810"})
	h.pool_t -= dt
	if h.pool_t <= 0:
		h.pool_t = 0
		sim.fx.bleed(h.x, h.y, 10, -PI / 2, 30, 100, 3)
		sim.fx.burst(h.x, h.y, 16, ["#a01828", "#ff4a5a", "#5a0810"], 22, 110)
		if sim.arbol.has("l_pool_t4"):
			for e: Ent.Enemy in sim.enemies:
				if e.dying:
					continue
				if JS.hypot(e.x - h.x, e.y - h.y) < 60:
					e.hurt_t = maxf(e.hurt_t, 1)
					e.act = ""

# ======================================================================
#  habilidades (useSkill / fxSkill): devuelve false si no se ha podido lanzar
# ======================================================================
func use_skill(id: String, s: Dictionary) -> bool:
	var h := _p()
	in_skill = true
	match id:
		"blink":
			_blink(h, s)
			in_skill = false
			return true
		"rain":
			var tg := hero_target(h, 190)
			h.face = atan2(tg.y - h.y, tg.x - h.x)
			hero_act(h, "rain", .62, .62 * .78, func():
				rain_at(tg.x, tg.y, sim.skp("rain", "r"), sim.skp("rain", "dur") * h.st.skillDur, false, .35)
				for i in 3:
					up_arrows.append({"x": h.x + (i - 1) * 3, "y": h.y, "z": 34.0, "vz": 620.0 + i * 40, "t": .45}))
		"farrow":
			archer_aim(h, 320)
			hero_act(h, "a2", .6, .6 * .78, func():
				var o := {"anim": "a2", "dmg": h.st.dmg * sim.skp("farrow", "mult"), "pierce": 99, "kind": "f", "burn": h.st.dmg * sim.skp("farrow", "burn"),
					"burn_dur": sim.skp("farrow", "burnDur"), "kb": 90.0, "spd": 360.0, "life": .85, "boom": sim.arbol.has("a_fire_a")}
				var ang := muzzle_ang(h, "a2")
				if sim.arbol.has("a_fire_b"):
					var nx := -sin(ang) * 7
					var ny := cos(ang) * 7
					for sg in [-1, 1]:
						h.x += nx * sg; h.y += ny * sg
						spawn_arrow(h, ang, o)
						h.x -= nx * sg; h.y -= ny * sg
				else:
					spawn_arrow(h, ang, o)
				var M := bow_muzzle(h, "a2")
				sim.fx.burst(M.x, M.y + 14, 14, ["#fff0b0", "#ffb03a", "#ff6a10"], 12, 80)
				sim.fx.shake(2))
		"multi":
			archer_aim(h, 300)
			hero_act(h, "a1", .5, .5 * .75, func():
				multi_volley(h)
				if sim.arbol.has("a_multi_key"):
					h.multi_q = 2
					h.multi_qt = .18)
		"pool":
			h.pool_t = sim.skp("pool", "dur") * h.st.skillDur
			h.pool_max = h.pool_t
			h.pool_x = 0; h.pool_tick = 0; h.pool_hit = 0; h.pool_acc = 0
			h.seq = null; h.blocking = false; h.ar_t = 0; h.ar_cb = null
			sim.fx.bleed(h.x, h.y, 24, -PI / 2, 40, 90, 3)
			sim.fx.burst(h.x, h.y, 10, ["#a01828", "#5a0810", "#ff4a5a"], 24, 90)
			sim.fx.shake(3)
		"cloud":
			var tg := hero_target(h, 170)
			h.face = atan2(tg.y - h.y, tg.x - h.x)
			hero_act(h, "cast", .6, .32, func():
				clouds.append(new_cloud(tg.x, tg.y, sim.skp("cloud", "r"), sim.skp("cloud", "dur") * h.st.skillDur, false))
				sim.fx.shake(2))
		"pact":
			hero_act(h, "pact", .6, .3, func():
				var c := sim.skp("pact", "cost")
				if c > 0:
					var n := maxf(0, minf(h.hp - 1, JS.round(h.hp * c)))
					if n > 0:
						h.hp -= n
						h.rn_pact_paid = n
						sim.fx.text(h.x, h.y - 40, "-" + str(int(n)), "#c0203a", 12)
						sim.fx.bleed(h.x, h.y, 18, -PI / 2, 26, 80, 1.6)
						sim.fx.hud()
				sim.fx.burst(h.x, h.y, 20, ["#c0203a", "#8a3ae0", "#ff4a5a"], 26, 110)
				sim.fx.shake(3)
				sim.recalc(h))
		"nova":
			h.nova_anim = .55
			h.nova_tick = 0
			h.nova_x = h.x
			h.nova_y = h.y
			sim.fx.burst(h.x, h.y, 10, ["#ff7a18", "#ffb03a", "#5a1404"], 30, 140)
			sim.fx.shake(3)
		"freeze":
			h.spell_anim = .5
			sim.arbol.freeze(h)
			var R := sim.skp("freeze", "r")
			for e: Ent.Enemy in sim.enemies:
				if e.dying:
					continue
				if JS.hypot(e.x - h.x, e.y - h.y) < R:
					e.frozen = sim.skp("freeze", "dur")
					e.frz_dur = e.frozen
					e.contagion = sim.arbol.has("m_frz_a")
					e.act = ""
					e.vx = 0
					e.vy = 0
					sim.fx.burst(e.x, e.y, 20, ["#fff0b0", "#ffb03a", "#ff6a10"], 10, 60)
			for i in 40:
				var a := i / 40.0 * 6.283
				sim.fx.part({"x": h.x + cos(a) * R * .5, "y": h.y + sin(a) * R * .35, "z": 4, "vx": cos(a) * 120, "vy": sin(a) * 80, "vz": 20, "life": .5, "col": "#ffc070" if i % 2 else "#ff6a10"})
		"valor":
			h.valor_heal_t = 0
			sim.arbol.valor(h)
			sim.fx.burst(h.x, h.y, 20, ["#ff3b30", "#ff8a6a", "#ffd25a"], 22, 100)
			sim.fx.shake(3)
		"verdugo":
			sim.fx.burst(h.x, h.y, 24, ["#e6f2ff", "#8fd0ea"], 14, 80)
		"banner":
			var d: float = sim.skp("banner", "dur") * h.st.skillDur
			sim.banner = {"x": h.x, "y": h.y + 1, "t": d, "max": d}
			sim.fx.burst(h.x, h.y, 4, ["#ffd25a", "#c22b1e"], 16, 90)
			if sim.runes.rv("bannerStun"):
				for e: Ent.Enemy in sim.enemies:
					if not e.dying and JS.hypot(e.x - h.x, e.y - h.y) < sim.skp("banner", "r"):
						sim.runes.stun(e, 1)
	in_skill = false
	return true

func _blink(h: Ent.Hero, s: Dictionary) -> void:
	var inp := sim.cur_inp
	var tx: float
	var ty: float
	if inp != null and inp.aim_mouse:
		tx = inp.aim.x; ty = inp.aim.y
	else:
		tx = h.x + cos(h.face) * 90; ty = h.y + sin(h.face) * 90
	var dx := tx - h.x
	var dy := ty - h.y
	var d := JS.hypot(dx, dy)
	var BR := sim.skp("blink", "range")
	if d > BR:
		tx = h.x + dx / d * BR
		ty = h.y + dy / d * BR
	var bx0 := h.x
	var by0 := h.y
	sim.fx.burst(h.x, h.y, 18, ["#ff7a18", "#fff0b0", "#7a1a08"], 24, 90)
	var bx := tx
	var by := ty
	var L0 := JS.hypot(bx - h.x, by - h.y)
	if L0 == 0: L0 = 1
	var ux := (bx - h.x) / L0
	var uy := (by - h.y) / L0
	var k := 0
	while not sim.fits(bx, by) and k < 60:
		k += 1
		bx -= ux * 4
		by -= uy * 4
	if sim.fits(bx, by):
		h.x = bx
		h.y = by
	var fx_ := h.x - sim.CX
	var fy := h.y - sim.CY
	var fd := JS.hypot(fx_, fy)
	var R := Sim.FRAD + 4
	if fd < R:
		h.x = sim.CX + fx_ / (fd if fd else 1.0) * R
		h.y = sim.CY + fy / (fd if fd else 1.0) * R
	sim.unstick(h)
	h.inv = maxf(h.inv, .3)
	h.seq = null
	sim.fx.burst(h.x, h.y, 18, ["#ff7a18", "#fff0b0", "#ffb03a"], 24, 90)
	s.cd = sim.arbol.blink(h, bx0, by0)

# ======================================================================
#  lo que vuela: explosiones, bolas de fuego, flechas, lluvias, nubes (fxTick)
# ======================================================================
func tick(dt: float) -> void:
	var h := _p()
	var fx := sim.fx
	# explosiones del mago
	for a in aoes:
		if a.boom > 0:
			a.boom -= dt
			continue
		a.t -= dt
		if a.t <= 0:
			a.boom = .5
			fx.shake(3)
			for i in 34:
				var an := sim.rnd() * 6.283
				var v := 40 + sim.rnd() * 120
				fx.part({"x": a.x, "y": a.y, "z": 4 + sim.rnd() * 10, "vx": cos(an) * v, "vy": sin(an) * v * .6, "vz": 60 + sim.rnd() * 80, "life": .45, "col": ["#ff7a18", "#ffb03a", "#fff0b0", "#7a1a08"][i % 4]})
			for e: Ent.Enemy in sim.enemies.duplicate():
				if e.dying:
					continue
				if JS.hypot(e.x - a.x, (e.y - 6) - a.y) < a.r + 6 + e.cuerpo:
					magic_hit(e, h.st.dmg * MAGE_ATK.blast.mult, atan2(e.y - a.y, e.x - a.x), 170, false)
			for i in 10:
				fx.stain(a.x + (sim.rnd() - .5) * a.r * 1.4, a.y + (sim.rnd() - .5) * a.r * .8, "#1a100a" if i % 2 else "#2a1608", 2 if sim.rnd() < .5 else 1)
	aoes = aoes.filter(func(a): return a.t > 0 or a.boom > 0)
	# bolas de fuego
	for f in fballs:
		f.t += dt
		f.life -= dt
		f.x += f.vx * dt
		f.y += f.vy * dt
		if sim.rnd() < .8:
			fx.part({"x": f.x, "y": f.y + 20, "z": 20, "vx": -f.vx * .1 + (sim.rnd() - .5) * 30, "vy": -f.vy * .1 + (sim.rnd() - .5) * 20, "vz": 10, "life": .25, "col": "#ffb03a" if sim.rnd() < .5 else "#ff5a10"})
		var boom: bool = f.life <= 0 or DungeonGen.is_opaque(sim.tile_at(int(floorf(f.x / Sim.TS)), int(floorf((f.y + 16) / Sim.TS))))
		if not boom:
			for e: Ent.Enemy in sim.enemies.duplicate():
				if e.dying:
					continue
				if JS.hypot(e.x - f.x, (e.y - 16) - f.y) < 14 + e.cuerpo:
					magic_hit(e, f.dmg, f.ang, 160, false, f.crit)
					boom = true
					break
		if boom:
			f.dead = true
			fx.shake(3)
			for i in 26:
				var an := sim.rnd() * 6.283
				var v := 40 + sim.rnd() * 110
				fx.part({"x": f.x, "y": f.y + 18, "z": 6 + sim.rnd() * 10, "vx": cos(an) * v, "vy": sin(an) * v * .6, "vz": 50 + sim.rnd() * 70, "life": .4, "col": ["#fff0b0", "#ffb03a", "#ff6a10", "#7a1a08"][i % 4]})
			for i in 6:
				fx.stain(f.x + (sim.rnd() - .5) * 14, f.y + 18 + (sim.rnd() - .5) * 8, "#1a100a" if i % 2 else "#2a1608", 2)
	fballs = fballs.filter(func(f): return not f.dead)
	# flechas
	for a in arrows:
		a.t += dt
		a.life -= dt
		a.x += a.vx * dt
		a.y += a.vy * dt
		if a.kind == "f" and sim.rnd() < .9:
			fx.part({"x": a.x, "y": a.y, "z": a.h, "vx": -a.vx * .08 + (sim.rnd() - .5) * 20, "vy": -a.vy * .08, "vz": 12, "life": .25, "col": "#ffb03a" if sim.rnd() < .5 else "#ff5a10"})
		var end: bool = a.life <= 0 or DungeonGen.is_opaque(sim.tile_at(int(floorf(a.x / Sim.TS)), int(floorf((a.y - 4) / Sim.TS))))
		if end and a.life > 0 and a.wb > 0 and _arrow_bounce(a, dt):
			end = false
		if not end:
			for e: Ent.Enemy in sim.enemies.duplicate():
				if e.dying or a.hit.has(e):
					continue
				if JS.hypot(e.x - a.x, e.y - a.y) < 12 + e.cuerpo:
					a.hit.append(e)
					_arrow_hit(e, a)
					if a.bounce > 0:
						a.bounce -= 1
						var nb = null
						var bd := 120.0
						for o: Ent.Enemy in sim.enemies:
							if o.dying or a.hit.has(o):
								continue
							var d := JS.hypot(o.x - a.x, o.y - a.y)
							if d < bd:
								bd = d
								nb = o
						if nb != null:
							a.ang = atan2(nb.y - a.y, nb.x - a.x)
							var sp := JS.hypot(a.vx, a.vy)
							a.vx = cos(a.ang) * sp
							a.vy = sin(a.ang) * sp
							a.life = maxf(a.life, .5)
							break
					if a.pierce > 0:
						a.pierce -= 1
						continue
					end = true
					break
		if end:
			a.dead = true
			if a.boom:
				fxs.append({"k": "burst", "x": a.x, "y": a.y, "t": .45, "max": .45, "sc": .45})
				fx.shake(3)
				for e: Ent.Enemy in sim.enemies.duplicate():
					if e.dying:
						continue
					if JS.hypot(e.x - a.x, e.y - a.y) < 44:
						magic_hit(e, a.dmg * .6, atan2(e.y - a.y, e.x - a.x), 120, false)
						burn_e(e, a.burn, a.burn_dur)
			else:
				fx.burst(a.x, a.y, 12, ["#ffb03a", "#ff6a10"] if a.kind == "f" else ["#c8b48a", "#8a7a5a"], 5, 40)
	arrows = arrows.filter(func(a): return not a.dead)
	# lluvias
	for r in rains:
		if r.delay > 0:
			r.delay -= dt
			continue
		r.t -= dt
		r.tick -= dt
		if r.t > .25 and sim.rnd() < dt * (26 if r.mini else 60):
			var an := sim.rnd() * 6.283
			var d: float = sqrt(sim.rnd()) * r.r
			r.drops.append({"x": r.x + cos(an) * d, "y": r.y + sin(an) * d * .6, "z": 150 + sim.rnd() * 40, "stuck": 0.0})
		for dr in r.drops:
			if dr.z > 0:
				dr.z -= 520 * dt
				if dr.z <= 0:
					dr.z = 0
					dr.stuck = .5
					if sim.rnd() < .4:
						fx.part({"x": dr.x, "y": dr.y, "z": 1, "vx": (sim.rnd() - .5) * 30, "vy": (sim.rnd() - .5) * 16, "vz": 30, "life": .25, "col": "#6a5a44"})
			else:
				dr.stuck -= dt
		r.drops = r.drops.filter(func(dr): return dr.z > 0 or dr.stuck > 0)
		if r.tick <= 0 and r.t > 0:
			r.tick = Sim.SK.rain.tick
			for e: Ent.Enemy in sim.enemies.duplicate():
				if e.dying:
					continue
				if JS.hypot(e.x - r.x, (e.y - r.y) / .6) < r.r + 6 + e.cuerpo:
					magic_hit(e, h.st.dmg * r.mult, PI / 2, 10, true)
					if r.burn:
						burn_e(e, h.st.dmg * .2, 2)
	rains = rains.filter(func(r): return r.t > 0 or r.drops.size())
	for u in up_arrows:
		u.t -= dt
		u.z += u.vz * dt
	up_arrows = up_arrows.filter(func(u): return u.t > 0)
	# nubes
	for c in clouds:
		c.t -= dt
		c.tick -= dt
		if c.follow and not h.dead:
			c.x += (h.x - c.x) * minf(1, dt * 4)
			c.y += (h.y - c.y) * minf(1, dt * 4)
		if c.tick <= 0:
			c.tick = Sim.SK.cloud.tick
			for e: Ent.Enemy in sim.enemies.duplicate():
				if e.dying:
					continue
				if JS.hypot(e.x - c.x, (e.y - c.y) / .6) < c.r + 4 + e.cuerpo:
					dot_hit(e, h.st.dmg * c.mult)
		if sim.rnd() < dt * (14 if c.mini else 30):
			var an := sim.rnd() * 6.283
			var d: float = sqrt(sim.rnd()) * c.r
			fx.part({"x": c.x + cos(an) * d, "y": c.y + sin(an) * d * .6, "z": 2, "vx": 0, "vy": 0, "vz": 14 + sim.rnd() * 16, "float": true, "life": .8, "col": "#5a1a90" if sim.rnd() < .5 else "#b07aff"})
	clouds = clouds.filter(func(c): return c.t > 0)
	for f in fxs:
		f.t -= dt
	fxs = fxs.filter(func(f): return f.t > 0)

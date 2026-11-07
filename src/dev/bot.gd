class_name Bot
extends RefCounted
## Jugador automático para pruebas (tests/test_partida.gd, tests/banco.gd y el modo --bot).
## Juega como un jugador prudente: sale de los avisos del suelo, bloquea o rueda cuando un enemigo
## carga el golpe, mantiene la distancia con las clases a distancia, usa habilidades y pociones,
## se retira con poca vida y no se mete en grupos grandes. Va hacia la escalera cuando no hay peligro.
## Es determinista: todo el azar sale de `rng`; siembra con `sembrar()` al empezar cada partida.

var rng := RandomNumberGenerator.new()
var _sk_turno := 0          # habilidad que toca probar (rota entre las tres)
var _retirada_t := 0.0      # segundos que le quedan retirándose para recuperarse
var _aguante_t := 0.0       # tras retirarse, segundos en que pelea aunque haya grupo (si no, huiría siempre)

func sembrar(semilla: String) -> void:
	rng.seed = hash("bot:" + semilla)
	_sk_turno = 0
	_retirada_t = 0.0
	_aguante_t = 0.0
	_flow_cache = {}

func play(sim: Sim, push: Vector2 = Vector2.ZERO) -> Sim.Inp:
	var inp := Sim.Inp.new()
	var p := sim.p
	if p.dead:
		return inp
	var yo := Vector2(p.x, p.y)
	var a_distancia := p.cls == "mage" or p.cls == "archer"
	var bloquea := p.cls == "knight"   # Caballero, Caballero de la Muerte y Señor Oscuro
	var vida := p.hp / maxf(1.0, p.st.maxHp)
	var dt := 1.0 / 60.0

	# --- enemigos despiertos: el más cercano, cuántos hay cerca y quién está cargando un golpe
	var objetivo = null
	var d_obj := 1e9
	var d_obj_p := 1e9
	var cerca := 0
	var amenaza = null
	var d_amenaza := 1e9
	var centro := Vector2.ZERO
	for e in sim.enemies:
		if e.dying or e.dead or e.state == "idle":
			continue
		var d := yo.distance_to(Vector2(e.x, e.y))
		# el jefe, el último: primero se limpian los que le acompañan
		var dp := d + (250.0 if e.boss != "" else 0.0)
		if dp < d_obj_p:
			d_obj_p = dp
			d_obj = d
			objetivo = e
		if d < 130:
			cerca += 1
			centro += Vector2(e.x, e.y)
		# solo cuenta el golpe a punto de salir: así el resto del tiempo puede atacar
		var cargando: bool = (e.act == "wind" and e.act_t < .3) or (e.act == "strike" and not e.hit_done) or e.act == "throw"
		if cargando and d < e.reach + 30 and d < d_amenaza:
			d_amenaza = d
			amenaza = e
	if cerca > 0:
		centro /= cerca
	# espadas lanzadas que vienen hacia él (ida o vuelta)
	var espada = null
	for pr in sim.projs:
		if pr.get("dead", false) or not (pr.phase == "out" or pr.phase == "back"):
			continue
		var dp := yo.distance_to(Vector2(pr.x, pr.y))
		if dp < 80 and dp < d_amenaza:
			d_amenaza = dp
			espada = pr

	# --- pociones: antes de que sea tarde
	if vida < .45 and Items.potion_count(p) > 0:
		inp.potion = true

	# --- 1) avisos en el suelo (conos, líneas, círculos): salir de ahí
	var huida := _salida_de_avisos(sim, yo)
	if huida != Vector2.ZERO:
		inp.move = huida
		if p.roll_cd <= 0 and rng.randf() < .25:
			inp.dash = true
		return _empuje(inp, push)

	# --- 2) retirada: poca vida y sin pociones, o rodeado (3 o más cerca): no meterse en grupos
	_aguante_t -= dt
	if _retirada_t > 0:
		_retirada_t -= dt
		if _retirada_t <= 0:
			_aguante_t = 3.0
	elif objetivo != null and ((vida < .3 and Items.potion_count(p) == 0) or (cerca >= 3 and _aguante_t <= 0)):
		_retirada_t = 1.2
	if _retirada_t > 0 and objetivo != null:
		var lejos := centro if cerca > 0 else Vector2(objetivo.x, objetivo.y)
		inp.move = _mejor_huida(sim, yo, lejos)
		if vida < .3 and p.roll_cd <= 0 and d_obj < 60:
			inp.dash = true
		if a_distancia and d_obj < 170:
			_apuntar(inp, objetivo)
			inp.attack_held = true
		return _empuje(inp, push)

	# --- 3) un enemigo carga el golpe: bloquear hacia él o rodar fuera; en cuanto suelta el golpe, contraataque
	if amenaza != null or espada != null:
		var hacia := Vector2(espada.x, espada.y) if espada != null else Vector2(amenaza.x, amenaza.y)
		# el escudo solo para un frente: con uno o dos enemigos; si hay más, mejor rodar fuera
		if bloquea and not a_distancia and (cerca <= 2 or espada != null):
			inp.block = true
			inp.aim = hacia + Vector2(0, -14)
			inp.aim_mouse = true
			return _empuje(inp, push)
		if p.roll_cd <= 0:
			inp.move = (yo - hacia).normalized().rotated(.6 if rng.randf() < .5 else -.6)
			inp.dash = true
			return _empuje(inp, push)
		inp.move = (yo - hacia).normalized()

	# --- 4) combate
	if objetivo != null and d_obj < 170:
		var dir := Vector2(objetivo.x, objetivo.y) - yo
		_apuntar(inp, objetivo)
		if a_distancia:
			# distancia cómoda: ni encima ni fuera de alcance
			if d_obj > 125:
				inp.move = dir.normalized()
			elif d_obj < 80:
				inp.move = _mejor_huida(sim, yo, Vector2(objetivo.x, objetivo.y))
			else:
				inp.move = dir.normalized().rotated(PI / 2) * .5   # se mueve de lado mientras dispara
			inp.attack_held = d_obj < 160
		elif objetivo.boss != "" and objetivo.act != "" and objetivo.act != "dodge":
			# el jefe está atacando: fuera de su alcance hasta que acabe, y luego a por él
			inp.move = _mejor_huida(sim, yo, Vector2(objetivo.x, objetivo.y)) if d_obj < 90 else Vector2.ZERO
		else:
			if d_obj > 22:
				inp.move = dir.normalized()
			inp.attack_held = d_obj < 40
		_habilidades(sim, inp, d_obj, a_distancia)
	else:
		# --- 5) sin peligro: hacia la escalera, abriendo puertas y cofres que encuentre
		inp.move = _path_dir(sim)
		if sim.can_interact():
			inp.interact = true
	return _empuje(inp, push)

func _empuje(inp: Sim.Inp, push: Vector2) -> Sim.Inp:
	if push != Vector2.ZERO:
		inp.move = push
	return inp

func _apuntar(inp: Sim.Inp, e) -> void:
	inp.aim = Vector2(e.x, e.y)
	inp.aim_mouse = true

## prueba una habilidad por turno; el DK sigue su orden propio
func _habilidades(sim: Sim, inp: Sim.Inp, d: float, a_distancia: bool) -> void:
	var p := sim.p
	if p.dk:
		if d < 30 and p.sk[2].cd <= 0:
			inp.skill = 2
		elif d < 60 and p.sk[1].cd <= 0:
			inp.skill = 1
		elif p.sk[0].cd <= 0 and sim.corpses.size() and rng.randf() < .05:
			inp.skill = 0
		return
	if d > (150.0 if a_distancia else 70.0):
		return
	for i in 3:
		var k := (_sk_turno + i) % 3
		if k < p.sk.size() and p.sk[k].cd <= 0:
			if rng.randf() < .15:
				inp.skill = k
				_sk_turno = (k + 1) % 3
			return

## dirección para alejarse de un punto evitando meterse contra una pared o en el vacío
func _mejor_huida(sim: Sim, yo: Vector2, de: Vector2) -> Vector2:
	var base := (yo - de).normalized()
	if base == Vector2.ZERO:
		base = Vector2.RIGHT.rotated(rng.randf() * TAU)
	for giro in [0.0, .7, -.7, 1.4, -1.4, 2.1, -2.1]:
		var v := base.rotated(giro)
		var q := yo + v * 24
		if not sim.solid_px(q.x, q.y) and not sim.sobre_vacio(q.x, q.y):
			return v
	return base

## si el héroe pisa algún aviso de ataque, hacia dónde salir (Vector2.ZERO si está a salvo)
func _salida_de_avisos(sim: Sim, yo: Vector2) -> Vector2:
	for m in sim.marks:
		var dentro := false
		var kind: String = m.get("kind", "")
		if kind == "cone":
			dentro = sim.m_in_cone(m, yo.x, yo.y)
		elif kind == "line" and m.has("x2"):
			dentro = sim.m_in_line(m, yo.x, yo.y)
		elif kind == "heal" or kind == "gold":
			dentro = false
		elif m.has("r"):
			dentro = sim.m_in_ell(yo.x, yo.y, m.x, m.y, m.r)
		if not dentro:
			continue
		if kind == "line" and m.has("x2"):
			# salir de lado, perpendicular a la línea
			var eje := Vector2(m.x2 - m.x, m.y2 - m.y).normalized()
			var lado := eje.rotated(PI / 2)
			var rel := yo - Vector2(m.x, m.y)
			return lado if rel.dot(lado) >= 0 else -lado
		return _mejor_huida(sim, yo, Vector2(m.x, m.y))
	return Vector2.ZERO

var _flow_cache := {}
func _path_dir(sim: Sim) -> Vector2:
	# distancias desde la escalera (las puertas cuentan como paso: el bot las abre)
	var key := str(sim.wave) + ":" + str(hash(sim.G))
	if not _flow_cache.has(key):
		var GW := DungeonGen.GW
		var GH := DungeonGen.GH
		var d := PackedInt32Array(); d.resize(GW * GH); d.fill(-1)
		var st: Dictionary = sim.L.stairs_cell
		var q := [st.cy * GW + st.cx]
		d[q[0]] = 0
		var h := 0
		while h < q.size():
			var i: int = q[h]; h += 1
			var x := i % GW
			var y := i / GW
			for dd in DungeonGen.D4:
				var nx: int = x + dd[0]
				var ny: int = y + dd[1]
				if nx < 0 or ny < 0 or nx >= GW or ny >= GH:
					continue
				var j := ny * GW + nx
				var t := sim.G[j]
				if d[j] < 0 and (not DungeonGen.is_solid(t) or t == DungeonGen.DOOR):
					d[j] = d[i] + 1
					q.append(j)
		_flow_cache = {key: d}
	var dist: PackedInt32Array = _flow_cache[key]
	var cx := sim.cell_of(sim.p.x)
	var cy := sim.cell_of(sim.p.y - 3)
	var bestv := 1 << 30
	var target := Vector2(sim.p.x, sim.p.y)
	for dd in [[0, -1], [1, 0], [0, 1], [-1, 0], [0, 0]]:
		var nx: int = cx + dd[0]
		var ny: int = cy + dd[1]
		if nx < 0 or ny < 0 or nx >= DungeonGen.GW or ny >= DungeonGen.GH:
			continue
		var v := dist[ny * DungeonGen.GW + nx]
		if v >= 0 and v < bestv:
			bestv = v
			target = Vector2((nx + .5) * 32, (ny + .5) * 32 + 6)
	var dir := target - Vector2(sim.p.x, sim.p.y)
	return dir.normalized() if dir.length() > 2 else Vector2.ZERO

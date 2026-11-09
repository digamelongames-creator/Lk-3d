extends SceneTree
## 10 nov: cofre al entrar, cofre por sala (cerrado hasta limpiarla), más botín y variedad con nombres,
## nombres de los enemigos y salas secretas tras las puertas negras.
## godot --headless --path . -s tests/test_cofres_secretas.gd

var fallos := 0

func ok(c: bool, que: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", que)

func _piso(w: int, semilla: String, ck := "knight") -> Sim:
	var sim := Sim.new()
	sim.new_game(w, semilla, ck)
	sim.enter_level(DungeonGen.gen_level(sim.level_seed(w), w))
	return sim

func _pasos(sim: Sim, n: int) -> void:
	for i in n:
		sim.step(1.0 / 60, Sim.Inp.new())

func _init() -> void:
	# ---- cofre al entrar ----
	var con_secreta := 0
	for k in 8:
		var sim := _piso(1 + k, "cofres%d" % k, ["knight", "mage", "archer", "dk", "dl"][k % 5])
		var ini := sim.chests.filter(func(c): return c.get("inicio", false))
		ok(ini.size() == 1, "piso %d: un cofre al entrar" % (1 + k))
		if ini.size():
			var c: Dictionary = ini[0]
			ok(JS.hypot(c.x - sim.p.x, c.y - sim.p.y) < 110, "el cofre de entrada está cerca del héroe")
			var hueco := sim.hueco_mas_flojo()
			var antes: int = sim.loot.size()
			sim.try_open_chest(c)
			ok(c.open, "se abre sin llave")
			var nuevos := sim.loot.slice(antes)
			ok(nuevos.size() == 1 and nuevos[0].item.gear, "da una pieza")
			if nuevos.size():
				var it: Dictionary = nuevos[0].item
				ok(it.cls == sim.p.cls_key() and it.slot == hueco and int(it.q) >= 1, "de tu clase, para tu hueco más flojo y mágica o mejor (%s %s q%d)" % [it.cls, it.slot, it.q])
		# ---- un cofre por sala con enemigos, cerrado hasta limpiarla ----
		var salas := sim.chests.filter(func(c): return c.has("sala"))
		var con_enemigos := {}
		for e in sim.enemies:
			if e.secreta:
				continue
			var i: int = sim.cell_of(e.y - 3) * DungeonGen.GW + sim.cell_of(e.x)
			var ro: int = sim.L.room_of[i]
			if ro >= 0 and ro != sim.L.start_room and ro != int(sim.reto.get("room", -1)):
				con_enemigos[ro] = true
		ok(salas.size() >= con_enemigos.size() * .85 and salas.size() > 3, "piso %d: cofre en las salas con enemigos (%d de %d)" % [1 + k, salas.size(), con_enemigos.size()])
		if salas.size():
			var c: Dictionary = salas[0]
			ok(sim.chest_locked(c), "cerrado mientras queden enemigos de la sala")
			for e in c.guards:
				sim.kill_enemy(e, 0)
			_pasos(sim, 60)
			ok(not sim.chest_locked(c), "se abre al limpiar la sala")
			var antes: int = sim.loot.size()
			sim.try_open_chest(c)
			ok(c.open and sim.loot.size() > antes, "y suelta botín")
		if sim.L.secretas.size() or sim.L.get("plataformas", false):   # en los de pasarelas no hay roca libre
			con_secreta += 1
	ok(con_secreta == 8, "los pisos sin pasarelas tienen sala secreta (%d de 8)" % con_secreta)

	# ---- sala secreta: entrar, élite y cofres, y salir por la misma puerta ----
	var sim := _piso(6, "secreta")
	ok(sim.L.secretas.size() >= 1, "hay sala secreta en el piso 6")
	if sim.L.secretas.size():
		var s: Dictionary = sim.L.secretas[0]
		var g: PackedByteArray = sim.L.grid
		ok(g[s.puerta.y * DungeonGen.GW + s.puerta.x] == DungeonGen.ROCK, "la puerta es muro (no se pasa andando)")
		ok(g[s.fuera.y * DungeonGen.GW + s.fuera.x] == DungeonGen.FLOOR and g[s.dentro.y * DungeonGen.GW + s.dentro.x] == DungeonGen.FLOOR, "suelo a los dos lados")
		# no se llega andando: el camino desde la entrada no alcanza la sala
		var d := DungeonGen._bfs(g, sim.L.start.cx, sim.L.start.cy)
		ok(d[s.dentro.y * DungeonGen.GW + s.dentro.x] < 0, "la sala no está unida al resto del piso")
		var dentro := sim.enemies.filter(func(e): return e.secreta)
		var ns: int = sim.L.secretas.size()
		ok(dentro.size() == 3 * ns and dentro.filter(func(e): return e.elite).size() == ns, "una élite y dos escoltas en cada sala")
		var cofres := sim.chests.filter(func(c): return c.get("secreta", false))
		ok(cofres.size() == 2 * ns and sim.chest_locked(cofres[0]), "dos cofres dorados por sala que guarda la élite")
		# junto a la puerta: Espacio pide entrar
		var pt: Vector2 = SalaSecreta.punto(s.puerta, s.fuera)
		sim.p.x = pt.x + (s.fuera.x - s.puerta.x) * 12
		sim.p.y = pt.y + (s.fuera.y - s.puerta.y) * 12 + 6
		ok(sim.can_interact(), "aviso de usar junto a la puerta")
		# (el azar de la simulación no tiene semilla: se apartan los enemigos de fuera para que no molesten)
		sim.enemies = sim.enemies.filter(func(e): return e.secreta)
		sim.hitstop = 0
		var inp := Sim.Inp.new()
		inp.interact = true
		var r := ""
		for i in 5:
			r = sim.step(1.0 / 60, inp)
			if r == "secreta":
				break
		ok(r == "secreta" and sim.secreta_pedida != null and not sim.secreta_pedida.sale, "Espacio pregunta «¿Entrar?» (%s)" % r)
		sim.cruzar_secreta()
		var r_: Dictionary = s.sala
		var cx := sim.cell_of(sim.p.x)
		var cy := sim.cell_of(sim.p.y - 3)
		ok(cx >= r_.x and cx < r_.x + r_.w and cy >= r_.y and cy < r_.y + r_.h, "el héroe aparece dentro de la sala")
		_pasos(sim, 30)
		var ps = sim.secreta_cerca()
		ok(ps != null and ps.sale, "dentro, la misma puerta sirve para salir")
		if ps != null:
			sim.secreta_pedida = ps
			sim.cruzar_secreta()
			ok(sim.cell_of(sim.p.x) == s.fuera.x and sim.cell_of(sim.p.y - 3) == s.fuera.y, "sale junto a la puerta de fuera")
		# la élite muere y los cofres se abren
		for e in dentro:
			if e.elite:
				sim.kill_enemy(e, 0)
		_pasos(sim, 60)
		ok(not sim.chest_locked(cofres[0]), "muerta la élite, los cofres se abren")
		var antes: int = sim.loot.size()
		sim.try_open_chest(cofres[0])
		ok(sim.loot.size() - antes >= 3, "cofre dorado con 3 piezas o más")
	ok(_piso(1, "ciudad-no").L.secretas.size() >= 0, "piso 1 sin errores")

	# ---- más botín y variedad ----
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var nombres := {}
	var con_arm := 0
	var corazas := 0
	var valores := {}
	for i in 400:
		var it := Items.make_gear(rng, 0, "dk", "chest" if i % 2 == 0 else "sword")
		nombres[it.name] = true
		if it.slot == "chest":
			corazas += 1
			if it.bonus.has("arm"):
				con_arm += 1
		for a in it.bonus:
			valores[int(it.bonus[a])] = true
	ok(nombres.size() >= 8, "las piezas básicas tienen nombres distintos (%d): %s" % [nombres.size(), str(nombres.keys().slice(0, 4))])
	ok(con_arm == corazas, "las corazas llevan armadura")
	ok(valores.has(1) and valores.has(4), "los números varían de 1 a 4")
	ok(Items.stat_txt("arm", 2).begins_with("+2 Armadura"), "texto de la armadura")
	var rk := Items.make_gear(rng, 0, "knight", "helm")
	ok(rk.name.ends_with("del Caballero Oscuro"), "el caballero mantiene el nombre del set: " + rk.name)
	# la armadura cuenta en la hoja
	var sa := _piso(1, "arm", "dk")
	var a0: float = sa.p.st.armorPts
	var pecho: Dictionary = sa.p.eq.chest
	var antes_arm: int = int(pecho.bonus.get("arm", 0))
	pecho.bonus["arm"] = antes_arm + 5
	sa.recalc(sa.p)
	ok(is_equal_approx(sa.p.st.armorPts, a0 + 10), "+5 de armadura en la pieza son +10 de armadura (%s → %s)" % [a0, sa.p.st.armorPts])
	# los enemigos normales sueltan más: 300 muertes
	var sb := _piso(2, "botin")
	sb.rng.seed = 11   # el azar de la simulación, fijo para esta cuenta
	var antes_l: int = sb.loot.size()
	var antes_p: int = sb.pickups.size()
	var n := 0
	for e in sb.enemies.duplicate():
		if e.rare or e.jefe or e.mon != "" or e.type == "champ" or n >= 150:
			continue
		n += 1
		sb.kill_enemy(e, 0)
	var piezas: int = sb.loot.slice(antes_l).filter(func(l): return l.item.get("gear", false)).size()
	ok(piezas > n * .15, "más piezas de los enemigos normales (%d de %d)" % [piezas, n])
	ok(sb.pickups.size() - antes_p > n * .2, "más pociones (%d de %d)" % [sb.pickups.size() - antes_p, n])

	# ---- nombres de los enemigos ----
	var sn := _piso(3, "nombres")
	var vistos := {}
	for e in sn.enemies:
		var nm := sn.nombre_de(e)
		ok(nm != "", "todos tienen nombre")
		vistos[nm] = true
		ok(sn.nombre_de(e) == nm, "el nombre no cambia")
	ok(vistos.size() > sn.enemies.size() * .3, "nombres variados (%d para %d)" % [vistos.size(), sn.enemies.size()])
	var golpeado: Ent.Enemy = sn.enemies[0]
	sn.note_hit(golpeado)
	ok(golpeado.golpe_t == sn.t, "se apunta cuándo lo golpeas")

	print("todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit()

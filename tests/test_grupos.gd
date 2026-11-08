extends SceneTree
## Grupos de 5–10 por sala, élites con poder desde el piso 1, un jefe por piso que cierra la escalera
## y deja un cofre grande, demonios en los pisos 1–5, escudo y explosión de las élites.
## godot --headless --path . -s tests/test_grupos.gd

var fallos := 0

func ok(c: bool, que: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", que)

func _piso(w: int, semilla: String) -> Sim:
	var sim := Sim.new()
	sim.new_game(w, semilla, "knight")
	sim.enter_level(DungeonGen.gen_level(sim.level_seed(w), w))
	return sim

func _init() -> void:
	var demonios := {}
	for w in range(1, 8):
		for semilla in ["a", "b", "c"]:
			var sim := _piso(w, "grupos-%s" % semilla)
			var por_sala := {}
			var elites := 0
			var jefes := 0
			for e in sim.enemies:
				var k: int = sim.room_at_px(e.x, e.y)
				if k >= 0 and k != sim.L.start_room:
					por_sala[k] = por_sala.get(k, 0) + 1
				if e.rare and e.poder != "":
					elites += 1
				if e.jefe:
					jefes += 1
				if e.mon in ["miniDemon", "middleDemon", "demonCaptain", "firedemon"] and not e.jefe:
					demonios[w] = true
			var grandes := por_sala.values().filter(func(n): return n >= 5).size()
			ok(grandes >= por_sala.size() * .6, "piso %d %s: salas con 5 o más (%d de %d)" % [w, semilla, grandes, por_sala.size()])
			ok(elites >= 1, "piso %d %s: al menos una élite con poder" % [w, semilla])
			ok(jefes == 1, "piso %d %s: un jefe (%d)" % [w, semilla, jefes])
			if w == 1 and semilla == "a":
				print("piso 1: %d enemigos, %d salas, %d élites" % [sim.enemies.size(), por_sala.size(), elites])
	for w in range(1, 6):
		ok(demonios.has(w) or w > 3, "demonios en el piso %d" % w)
	ok(not demonios.has(6) and not demonios.has(7), "sin demonios después del piso 5")
	# la escalera no deja bajar con el jefe vivo; muerto, deja un cofre grande
	var sim := _piso(1, "escalera")
	var j := sim.jefe_vivo()
	ok(j != null, "hay jefe")
	sim.p.x = sim.L.stairs_px.x
	sim.p.y = sim.L.stairs_px.y + 3
	for e in sim.enemies:
		e.state = "idle"
	sim.step(1.0 / 60, Sim.Inp.new())
	ok(sim.phase == "fight", "con el jefe vivo no se baja")
	var cofres: int = sim.chests.size()
	j.hp = 1
	sim.kill_enemy(j, 0.0)
	ok(sim.chests.size() == cofres + 1 and sim.chests[-1].get("grande", false), "el jefe deja un cofre grande")
	for i in 90:
		sim.step(1.0 / 60, Sim.Inp.new())
	sim.p.x = sim.L.stairs_px.x
	sim.p.y = sim.L.stairs_px.y + 3
	sim.step(1.0 / 60, Sim.Inp.new())
	ok(sim.phase == "descend", "muerto el jefe, se baja (%s)" % sim.phase)
	# escudo: absorbe el daño y se recarga
	sim = _piso(1, "escudo")
	var e: Ent.Enemy = sim.enemies[0]
	e.poder = "escudo"; e.escudo_max = 50; e.escudo = 50
	var d := sim.dmg_mod(e, 30)
	ok(d == 0 and e.escudo == 20, "el escudo para el golpe (%s, %s)" % [d, e.escudo])
	d = sim.dmg_mod(e, 30)
	ok(d == 10 and e.escudo == 0, "lo que sobra pasa (%s)" % d)
	# explota: aviso y daño al héroe si está cerca
	sim = _piso(1, "explota")
	sim.enemies.clear()
	var x: Ent.Enemy = sim.spawn_enemy("knight", sim.p.x + 30, sim.p.y)
	x.poder = "explota"
	var hp0: float = sim.p.hp
	sim.kill_enemy(x, 0.0)
	ok(sim.bombas.size() == 1, "deja una explosión con aviso")
	sim.p.inv = 0
	for i in 80:
		sim.step(1.0 / 60, Sim.Inp.new())
	ok(sim.p.hp < hp0, "la explosión hace daño (%d → %d)" % [hp0, sim.p.hp])
	print("test_grupos: ", "todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit(1 if fallos else 0)

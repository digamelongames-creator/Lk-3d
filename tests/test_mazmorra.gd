extends SceneTree
## Tanda 3: rompibles (oro y a veces poción o esqueleto), mímico al acercarte, reto de 3 oleadas con rejas
## y cofre con legendario, y trampas de pinchos y fuego (la voltereta salva; dañan también a los enemigos).
## godot --headless --path . -s tests/test_mazmorra.gd

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

func _pasos(sim: Sim, n: int) -> void:
	for i in n:
		sim.step(1.0 / 60, Sim.Inp.new())

func _init() -> void:
	# ---- rompibles ----
	var sim := _piso(1, "rompe")
	var salas: int = sim.L.rooms.size() - 1
	ok(sim.rompibles.size() >= salas * 2, "hay rompibles en las salas (%d en %d salas)" % [sim.rompibles.size(), salas])
	var kinds := {}
	for r in sim.rompibles:
		kinds[r.kind] = true
	ok(kinds.size() == 3, "barriles, cajas y urnas " + str(kinds.keys()))
	var r0: Dictionary = sim.rompibles[0]
	var oro0: int = sim.gold.size()
	sim._romper(r0)
	ok(r0.roto and sim.gold.size() > oro0, "al romperse suelta oro")
	# el tajo del héroe rompe lo que tiene delante
	var r1: Dictionary = sim.rompibles[1]
	sim.p.x = r1.x - 20
	sim.p.y = r1.y
	sim.p.face = 0.0
	sim._romper_golpe(sim.p.x, sim.p.y - 14)
	ok(r1.roto, "el tajo lo rompe")
	# ---- mímico: muerde al acercarte ----
	sim = _piso(1, "mimico")
	sim.enemies.clear()
	var c := {"cx": 0, "cy": 0, "kind": "mimic", "room": null, "se": false, "x": sim.p.x + 30, "y": sim.p.y, "open": false, "open_t": 0.0, "best": 0, "guards": [], "msg_t": -9.0}
	c.cx = sim.cell_of(c.x); c.cy = sim.cell_of(c.y)
	sim.chests.append(c)
	_pasos(sim, 2)
	ok(not sim.chests.has(c) and sim.enemies.any(func(e): return e.mimic), "el mímico salta al acercarte")
	# ---- reto de oleadas ----
	sim = _piso(2, "reto")
	ok(not sim.reto.is_empty(), "hay sala de reto")
	var R: Dictionary = sim.L.rooms[sim.reto.room]
	ok(sim.enemies.all(func(e): return sim.room_at_px(e.x, e.y) != sim.reto.room or e.jefe), "la sala del reto empieza vacía")
	sim.p.x = (R.x + R.w / 2.0) * Sim.TS
	sim.p.y = (R.y + R.h / 2.0) * Sim.TS + 8
	sim.p.inv = 1e9   # que no le maten en la prueba
	_pasos(sim, 2)
	ok(sim.reto.estado == "activo", "al entrar empieza el reto")
	var sal: Array = sim.reto.salidas
	ok(sal.size() > 0 and sal.all(func(i): return sim.G[i] == DungeonGen.PILLAR), "rejas cerradas (%d salidas)" % sal.size())
	var olas := 0
	var elite := false
	for vuelta in 600:
		_pasos(sim, 1)
		var de_ola := sim.enemies.filter(func(e): return e.reto and not e.dying)
		if de_ola.size():
			olas = sim.reto.ola
			if de_ola.any(func(e): return e.rare and e.poder != ""):
				elite = true
			for e in de_ola:
				sim.kill_enemy(e, 0.0)
		if sim.reto.estado == "hecho":
			break
	ok(olas == 3 and sim.reto.estado == "hecho", "tres oleadas y se acaba (%d, %s)" % [olas, sim.reto.estado])
	ok(elite, "la tercera trae una élite")
	ok(sal.all(func(i): return sim.G[i] != DungeonGen.PILLAR), "se abren las rejas")
	var premio = null
	for ch in sim.chests:
		if ch.get("reto", false):
			premio = ch
	ok(premio != null, "aparece el cofre del reto")
	if premio != null:
		sim.enemies.clear()
		sim.loot.clear()
		var oro: int = sim.gold.size()
		sim.try_open_chest(premio)
		ok(sim.loot.any(func(l): return l.item.get("gear", false) and int(l.item.q) == 3), "con un legendario seguro")
		ok(sim.gold.size() >= oro + 5, "y mucho oro")
	# ---- trampas ----
	sim = _piso(3, "trampas")
	ok(sim.trampas.size() >= 4, "hay trampas en los pasillos (%d)" % sim.trampas.size())
	sim.enemies.clear()
	var tr: Dictionary = sim.trampas[0]
	sim.p.x = tr.x
	sim.p.y = tr.y
	var hp0: float = sim.p.hp
	_pasos(sim, 50)
	ok(sim.p.hp < hp0, "la trampa hace daño al pisarla (%s, %d → %d)" % [tr.kind, hp0, sim.p.hp])
	# con voltereta en el momento justo, nada
	sim = _piso(3, "trampas")
	sim.enemies.clear()
	tr = sim.trampas[0]
	sim.p.x = tr.x
	sim.p.y = tr.y
	hp0 = sim.p.hp
	tr.estado = "aviso"
	tr.t = 0.0
	sim.p.roll_t = 5.0
	sim._trampas_tick(1.0 / 60)
	ok(sim.p.hp == hp0 or tr.kind == "fuego", "la voltereta salva de los pinchos")
	# un enemigo encima también se lleva el daño
	sim = _piso(3, "trampas")
	sim.enemies.clear()
	tr = sim.trampas[0]
	sim.p.x = tr.x + 200
	var e: Ent.Enemy = sim.spawn_enemy("knight", tr.x, tr.y)
	e.state = "chase"   # los que esperan quietos no disparan las trampas
	var ehp: float = e.hp
	for i in 50:
		sim._trampas_tick(1.0 / 60)
	ok(e.hp < ehp, "daña también a los enemigos")
	print("test_mazmorra: ", "todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit(1 if fallos else 0)

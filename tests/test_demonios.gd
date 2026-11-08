extends SceneTree
## Los demonios salen en los pisos 1–5, cada tipo en su sala, y el salto del capitán demonio daña y aturde 2 s al héroe.
## godot --headless --path . -s tests/test_demonios.gd

var fallos := 0

func ok(c: bool, que: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", que)

func _init() -> void:
	# los demonios salen en los pisos 1–5, mezclados con el resto (decidido por Diego, 8 nov); nunca dos en la misma sala
	var vistos := {}
	for w in range(1, 8):
		for semilla in ["a", "b", "c", "d"]:
			var sim := Sim.new()
			sim.new_game(w, "demonios-" + semilla, "knight")
			sim.enter_level(DungeonGen.gen_level(sim.level_seed(w), w))
			var salas := {}
			for e in sim.enemies:
				if e.mon in ["miniDemon", "middleDemon", "demonCaptain", "firedemon"] and not e.jefe and e.invocador == null:
					vistos[e.mon + str(w)] = true
					var k: int = sim.room_at_px(e.x, e.y)
					if salas.has(k) and salas[k] != e.mon:
						ok(false, "piso %d %s: dos demonios distintos en la sala %d" % [w, semilla, k])
					salas[k] = e.mon
				if w > 5:
					ok(not (e.mon in ["miniDemon", "middleDemon", "demonCaptain", "firedemon"]) or e.jefe, "piso %d: sin demonios" % w)
	for id in ["miniDemon", "middleDemon", "demonCaptain", "firedemon"]:
		var n := 0
		for w in range(1, 6):
			if vistos.has(id + str(w)):
				n += 1
		ok(n >= 2, id + " sale en varios pisos del 1 al 5 (%d)" % n)
	# el salto: el capitán junto al héroe, sin más enemigos
	var sim := Sim.new()
	sim.new_game(1, "salto", "knight")
	sim.enter_level(DungeonGen.gen_level(sim.level_seed(1), 1))
	sim.enemies.clear()
	# un sitio libre y a la vista, a unos 150 px del héroe
	var sitio := Vector2.ZERO
	for k in 32:
		var a := k * TAU / 32
		var q := Vector2(sim.p.x, sim.p.y) + Vector2(cos(a), sin(a)) * 150
		if sim.fits(q.x, q.y, 10) and sim.has_los(q.x, q.y - 10, sim.p.x, sim.p.y - 10) and sim.clear_path(q.x, q.y, sim.p.x, sim.p.y):
			sitio = q
			break
	ok(sitio != Vector2.ZERO, "sitio libre para el capitán")
	var c := sim.mon_spawn("demonCaptain", sitio.x, sitio.y)
	c.state = "chase"
	var hp0: float = sim.p.hp
	var aturdido := false
	var salto := false
	for i in 240:
		sim.step(1.0 / 60, Sim.Inp.new())
		if c.act == "jump":
			salto = true
		if sim.p.aturdido > 0:
			aturdido = true
	ok(salto, "el capitán salta")
	ok(aturdido, "la caída aturde al héroe")
	ok(sim.p.hp < hp0, "la caída y los puñetazos hacen daño (%d → %d)" % [hp0, sim.p.hp])
	print("test_demonios: ", "todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit(1 if fallos else 0)

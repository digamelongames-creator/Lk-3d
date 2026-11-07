extends SceneTree
## Piso 1 de prueba: los cuatro demonios salen cada uno en su sala (4 minidemonios juntos)
## y el salto del capitán demonio daña y aturde 2 s al héroe.
## godot --headless --path . -s tests/test_demonios.gd

var fallos := 0

func ok(c: bool, que: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", que)

func _init() -> void:
	for semilla in ["a", "b", "c"]:
		var sim := Sim.new()
		sim.new_game(1, "demonios-" + semilla, "knight")
		sim.enter_level(DungeonGen.gen_level(sim.level_seed(1), 1))
		var salas := {}
		var cuenta := {}
		for e in sim.enemies:
			if e.mon in ["miniDemon", "middleDemon", "demonCaptain", "firedemon"]:
				cuenta[e.mon] = cuenta.get(e.mon, 0) + 1
				var k: int = sim.room_at_px(e.x, e.y)
				if not salas.has(e.mon):
					salas[e.mon] = k
		ok(cuenta.get("miniDemon", 0) >= 3, semilla + ": minidemonios en grupo (%d)" % cuenta.get("miniDemon", 0))
		for id in ["middleDemon", "demonCaptain", "firedemon"]:
			ok(cuenta.get(id, 0) == 1, semilla + ": un " + id)
		var distintas := {}
		for id in salas:
			distintas[salas[id]] = true
		ok(distintas.size() == salas.size(), semilla + ": cada demonio en su sala " + str(salas))
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

extends SceneTree
## Sala sellada del Devorador de Almas (piso 3): al entrar se cierran las puertas, al matarlo se abren
## y el héroe puede salir andando de la sala.
## godot --headless --path . -s tests/test_devorador.gd

var fallos := 0

func ok(c: bool, que: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", que)

func _pasos(sim: Sim, n: int, inp: Sim.Inp = null) -> void:
	for i in n:
		sim.step(1.0 / 60, inp if inp != null else Sim.Inp.new())

## casillas (Vector2i) desde la del héroe hasta la primera fuera de la sala k, pasando solo por donde cabe
func _camino(sim: Sim, k: int) -> Array:
	var ini := Vector2i(sim.cell_of(sim.p.x), sim.cell_of(sim.p.y - 3))
	var prev := {ini: ini}
	var cola := [ini]
	while cola.size():
		var c: Vector2i = cola.pop_front()
		if sim.room_at_px((c.x + .5) * Sim.TS, (c.y + .5) * Sim.TS) != k and c != ini:
			var out := []
			while c != ini:
				out.push_front(c)
				c = prev[c]
			return out
		for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + v
			if prev.has(n) or n.x < 0 or n.y < 0 or n.x >= DungeonGen.GW or n.y >= DungeonGen.GH:
				continue
			if not sim.fits((n.x + .5) * Sim.TS, (n.y + .5) * Sim.TS + 3, 6):
				continue
			prev[n] = c
			cola.append(n)
	return []

func _init() -> void:
	var probadas := 0
	for semilla in ["se1", "se2", "se3", "s17", "s56", "s58"]:
		var sim := Sim.new()
		sim.new_game(3, semilla, "knight")
		sim.enter_level(DungeonGen.gen_level(sim.level_seed(3), 3))
		var se: Ent.Enemy = null
		for e in sim.enemies:
			if e.se_room >= 0:
				se = e
		if se == null:
			continue
		probadas += 1
		var k: int = se.se_room
		var R: Dictionary = sim.L.rooms[k]
		# fuera los demás enemigos, que no estorben
		sim.enemies = sim.enemies.filter(func(e): return e == se)
		sim.p.inv = 1e9
		sim.p.x = (R.x + R.w / 2.0) * Sim.TS
		sim.p.y = (R.y + R.h / 2.0) * Sim.TS + 30
		_pasos(sim, 3)
		ok(se.sealed, "[%s] se sella al entrar" % semilla)
		sim.kill_enemy(se, 0.0)
		_pasos(sim, 240)
		ok(sim.doors.filter(func(d): return d.room == k).all(func(d): return d.open), "[%s] se abren las puertas" % semilla)
		# salir andando: camino por casillas libres hasta fuera de la sala y recorrerlo
		ok(sim.doors.filter(func(d): return d.room == k).size() > 0, "[%s] la sala tiene puertas" % semilla)
		sim.p.x = (R.x + R.w / 2.0) * Sim.TS
		sim.p.y = (R.y + R.h / 2.0) * Sim.TS + 30
		sim.unstick(sim.p)
		var camino := _camino(sim, k)
		ok(camino.size() > 0, "[%s] hay camino libre hacia fuera" % semilla)
		var fuera := false
		for c in camino:
			var tx: float = (c.x + .5) * Sim.TS
			var ty: float = (c.y + .5) * Sim.TS + 3
			for paso in 120:
				var dx: float = tx - sim.p.x
				var dy: float = ty - sim.p.y
				var l := sqrt(dx * dx + dy * dy)
				if l < 3:
					break
				var inp := Sim.Inp.new()
				inp.move = Vector2(dx / l, dy / l)
				_pasos(sim, 1, inp)
			if sim.room_at_px(sim.p.x, sim.p.y) != k and sim.room_at_px(sim.p.x, sim.p.y - 3) != k:
				fuera = true
				break
		ok(fuera, "[%s] el héroe sale de la sala tras matarlo (está en %.0f,%.0f, sala %d)" % [semilla, sim.p.x, sim.p.y, sim.room_at_px(sim.p.x, sim.p.y)])
	# la sala del Devorador nunca es la del reto (antes coincidían en ~1 de cada 20 pisos y no se podía salir)
	var juntas := []
	for i in 60:
		var s2 := Sim.new()
		s2.new_game(3, "s%d" % i, "knight")
		s2.enter_level(DungeonGen.gen_level(s2.level_seed(3), 3))
		for e in s2.enemies:
			if e.se_room >= 0 and not s2.reto.is_empty() and e.se_room == s2.reto.room:
				juntas.append("s%d" % i)
	ok(juntas.is_empty(), "el Devorador no comparte sala con el reto " + str(juntas))
	ok(probadas >= 2, "se han probado salas del Devorador (%d)" % probadas)
	print("todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit()

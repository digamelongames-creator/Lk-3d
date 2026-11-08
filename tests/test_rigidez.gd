extends SceneTree
## Combate más rígido (8 nov): quieto mientras dura el tajo, los básicos no empujan (élites sí, y al bloquear
## sigue el empujón pequeño), el golpe no corta el tajo ni congela, «Velocidad al andar» y sonido sí/no.
## godot --headless --path . -s tests/test_rigidez.gd

var fallos := 0

func ok(c: bool, que: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", que)

func _piso(semilla: String) -> Sim:
	var sim := Sim.new()
	sim.new_game(1, semilla, "knight")
	sim.enter_level(DungeonGen.gen_level(sim.level_seed(1), 1))
	sim.enemies.clear()
	return sim

func _andar(sim: Sim, n: int, v: Vector2) -> float:
	var x0 := sim.p.x
	var y0 := sim.p.y
	for i in n:
		var inp := Sim.Inp.new()
		inp.move = v
		sim.step(1.0 / 60, inp)
	return Vector2(sim.p.x - x0, sim.p.y - y0).length()

func _init() -> void:
	# ---- quieto mientras dura el tajo ----
	var sim := _piso("rig1")
	var inp := Sim.Inp.new()
	inp.attack = true
	inp.move = Vector2(1, 0)
	inp.aim = Vector2(sim.p.x + 50, sim.p.y)
	sim.step(1.0 / 60, inp)
	ok(sim.p.seq != null, "empieza el tajo")
	var x0 := sim.p.x
	var d := _andar(sim, 10, Vector2(1, 0))
	ok(sim.p.x - x0 < .5 and d < .5, "no se desplaza mientras ataca (%.2f px)" % (sim.p.x - x0))
	# ---- los básicos no empujan; la élite sí ----
	sim = _piso("rig2")
	var e := sim.spawn_enemy("knight", sim.p.x + 30, sim.p.y)
	ok(sim._basico(e), "un caballero normal es básico")
	var px := sim.p.x
	var py := sim.p.y
	sim.hurt_player(5, e.x, e.y, e)
	ok(absf(sim.p.x - px) < .01 and absf(sim.p.y - py) < .01, "el básico no te mueve")
	ok(sim.hitstop == 0.0, "sin congelado al recibir el golpe")
	sim.p.inv = 0
	sim.p.hurt_t = 0
	sim.make_rare(e)
	ok(not sim._basico(e), "la élite no es básica")
	px = sim.p.x
	sim.hurt_player(5, e.x, e.y, e)
	ok(absf(sim.p.x - px) > 1, "la élite sí empuja un poco")
	# ---- el golpe recibido no corta el tajo ----
	sim = _piso("rig3")
	e = sim.spawn_enemy("knight", sim.p.x + 30, sim.p.y)
	inp = Sim.Inp.new()
	inp.attack = true
	inp.aim = Vector2(sim.p.x + 50, sim.p.y)
	sim.step(1.0 / 60, inp)
	sim.hurt_player(5, e.x, e.y, e)
	ok(sim.p.seq != null, "el golpe no corta el tajo")
	# ---- velocidad al andar ----
	sim = _piso("rig4")
	var a := _andar(sim, 30, Vector2(0, 1))
	sim = _piso("rig4")
	sim.vel_mov = .5
	var b := _andar(sim, 30, Vector2(0, 1))
	ok(a > 10 and absf(b - a * .5) < a * .1, "al 50 %% anda la mitad (%.1f px frente a %.1f)" % [b, a])
	e = sim.spawn_enemy("knight", sim.p.x, sim.p.y)
	sim.vel_mov = 1.0
	var k1: float = sim.runes.e_slow(e)
	sim.vel_mov = .3
	ok(absf(sim.runes.e_slow(e) - k1 * .3) < 1e-6, "los enemigos también van más lentos")
	# ---- opciones ----
	Opciones.valores = Opciones.DEFECTO.duplicate()
	ok(Opciones.v("velocidad") == 100 and Opciones.vel_mov() == 1.0, "velocidad por defecto 100 %")
	Opciones.valores.sonido = false
	Opciones.aplicar_sonido()
	ok(AudioServer.is_bus_mute(0), "sin sonido: bus en silencio")
	Opciones.valores.sonido = true
	Opciones.aplicar_sonido()
	ok(not AudioServer.is_bus_mute(0), "con sonido")
	print("todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit()

extends SceneTree
## Los monstruos con modelo 3D (esqueleto, Bufona) se crean, animan y mueren sin errores.
## godot --headless --path . -s tests/test_modelos.gd

func _init() -> void:
	var fallos := 0
	for id in Modelo3D.FICHAS:
		if id == "heroe" and not Modelo3D.hay(id):
			print("(sin modelo del héroe todavía: sale la cápsula)")
			continue
		var m := Modelo3D.crear(id)
		if m == null or m.anim == null:
			print("FALLO sin modelo o sin animaciones: ", id)
			fallos += 1
			continue
		m.anadir_animaciones()   # la Maga saca «attack» de los Cast y anda con «andar»
		for a in ["idle", "walk" if not "walk" in m.ficha.get("sin", []) else "andar", "run", "attack", "hurt", "death"]:
			if not m.anim.has_animation(a):
				print("FALLO ", id, " sin ", a)
				fallos += 1
		m.free()
	# en partida: piso 3 (esqueletos) con el bot unos segundos
	var raiz := Node3D.new()
	root.add_child(raiz)
	var sim := Sim.new()
	var act := Actores3D.new()
	act.sim = sim
	raiz.add_child(act)
	sim.new_game(3, "prueba-modelos", "knight")
	sim.enter_level(DungeonGen.gen_level(sim.level_seed(3), 3))
	act.nuevo_piso()
	var bot := Bot.new()
	var con_modelo := 0
	for i in 600:
		sim.step(1.0 / 30, bot.play(sim))
		act.actualizar(1.0 / 30)
	for d in act._enemigos.values():
		if d.m != null:
			con_modelo += 1
	var mons := sim.enemies.filter(func(e): return e.mon != "").size()
	print("enemigos con modelo 3D: %d (monstruos en la sim: %d)" % [con_modelo, mons])
	print("test_modelos: ", "todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit(1 if fallos else 0)

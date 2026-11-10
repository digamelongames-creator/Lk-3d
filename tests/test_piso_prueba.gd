extends SceneTree
## «Piso de prueba» del menú lleva al piso de prueba 1: sin enemigos, todas las salas se alcanzan desde el inicio,
## las piezas de los paquetes existen, el cofre se abre y hay armas con modelo en el suelo.
## godot --headless --path . -s tests/test_piso_prueba.gd
var fallos := 0
func ok(c: bool, q: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", q)

func _init() -> void:
	# las piezas de los paquetes
	for p in Props3D.PAQUETES:
		ok(Props3D.hay(p), "existe el paquete " + p)
	for e in PisoPrueba.ESTILOS:
		var E: Dictionary = PisoPrueba.ESTILOS[e]
		for n in E.muros + E.suelos + [E.esquina]:
			ok(Props3D.tiene(e, n), "pieza %s/%s" % [e, n])
	for k in Repartidor.PROPOSITOS:
		for r in Repartidor.PROPOSITOS[k]:
			for n in r.piezas:
				ok(Props3D.tiene(r.p, n), "pieza %s/%s (%s)" % [r.p, n, k])
	ok(Props3D.tiene("polyhaven", "cofre") and Props3D.tiene("polyhaven", "cofre_tapa"), "cofre con tapa")
	# el juego
	var main: Node = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.menu.piso_prueba.emit(0, "")   # «Piso de prueba» → «Pasillo (entrada)»
	await process_frame
	var sim: Sim = main.sim
	ok(main.prueba == 1, "entra en el piso de prueba 1")
	var no_munecos := sim.enemies.filter(func(e): return not e.muneco)
	ok(no_munecos.is_empty(), "sin enemigos, salvo los muñecos de la sala de efectos (%d)" % no_munecos.size())
	var L: Dictionary = sim.L
	var salas: Array = L.salas_prueba
	ok(salas.size() == 12, "pasillo + 5 salas de paquete + 4 de propósito + aprendizaje + efectos (%d)" % salas.size())
	var d: PackedInt32Array = L.dist
	var W := DungeonGen.GW
	for s in salas:
		var c := Vector2i(s.x + 4, s.y + (s.h - 2 if s.get("arriba", false) else 1))
		ok(d[c.y * W + c.x] >= 0, "se llega a la sala " + s.nombre)
	var props: Array = L.props_prueba
	for s in salas:
		var n := 0
		for o in props:
			if s.celdas.has(o.celda):
				n += 1
		ok(n > 0, "la sala %s tiene adornos (%d)" % [s.nombre, n])
	var adornos := 0
	for c in main.mazmorra.adornos.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null and not c.is_queued_for_deletion():
			adornos += 1
	ok(adornos > 300, "piezas montadas (%d)" % adornos)
	# el cofre del tesoro se abre y suelta botín
	ok(sim.chests.size() == 1, "un cofre (%d)" % sim.chests.size())
	var antes := sim.loot.size()
	ok(antes >= 4, "armas de prueba en la sala de guardia (%d)" % antes)
	for i in 30:
		await process_frame
	var con_modelo := 0
	for n in main.actores._botin_nodos.values():
		if n.has_meta("weapon_set"):
			con_modelo += 1
	ok(con_modelo >= 2, "armas del botín con modelo (%d)" % con_modelo)
	ok(main.actores._cofres.size() == 1 and main.actores._cofres.values()[0].get_child(1).get_child_count() == 1, "cofre con el modelo y la tapa en la bisagra")
	var cf: Dictionary = sim.chests[0]
	sim.p.x = cf.x
	sim.p.y = cf.y + 12
	for i in 40:
		var inp := Sim.Inp.new()
		inp.interact = i % 2 == 0
		sim.step(1.0 / 60, inp)
	ok(cf.open, "el cofre se abre")
	ok(sim.loot.size() > antes or sim.pickups.size() > 0, "el cofre suelta algo")
	# créditos
	main.mostrar_creditos(true)
	ok(main.state == "creditos" and main._creditos.visible, "F1 abre los créditos")
	main.mostrar_creditos(false)
	ok(main.state == "play", "y se cierran")
	print("test_piso_prueba: ", "todo bien" if fallos == 0 else "%d fallos" % fallos)
	main.queue_free()
	await process_frame
	quit(1 if fallos else 0)

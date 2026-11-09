extends SceneTree
## Inca: la partida empieza en la ciudad (zona segura), la entrada a la mazmorra deja elegir la oleada,
## tras el jefe se puede bajar o subir a Inca y al morir se vuelve a Inca sin la mochila ni el oro de la bajada.
## godot --headless --path . -s tests/test_ciudad.gd
var fallos := 0
func ok(c: bool, q: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", q)

func botones(n: Node) -> Array:
	var r := []
	for b in n.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion():
			r.append(b.text)
	return r

func pisar(main: Node, c: Vector2i) -> void:
	main.sim.p.x = (c.x + .5) * DungeonGen.TS
	main.sim.p.y = (c.y + .5) * DungeonGen.TS + 3
	for i in 30:
		await process_frame
		if main.state != "play": break

func _init() -> void:
	var main: Node = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var sim: Sim = main.sim
	main.menu.empezar.emit("knight")
	await process_frame
	ok(main.state == "play" and Ciudad.es_ciudad(sim.L), "Nueva partida empieza en Inca")
	ok(sim.enemies.is_empty() and sim.chests.is_empty() and sim.trampas.is_empty() and sim.rompibles.is_empty(), "Inca sin enemigos, cofres, trampas ni rompibles")
	for i in 20: await process_frame
	ok(sim.enemies.is_empty(), "y no aparecen después")
	main._attack_edge = true
	main._skill_edge = 0
	var inp: Sim.Inp = main._read_input()
	ok(not inp.attack and inp.skill == -1 and not inp.block, "en Inca no se ataca")
	ok(sim.p.piso_max == 1, "al empezar solo se puede ir a la oleada 1")

	# la entrada a la mazmorra
	await pisar(main, Ciudad.PORTAL)
	ok(main.state == "puerta" and main._puerta.visible, "pisar la entrada abre la ventana (%s)" % main.state)
	await process_frame
	ok(botones(main._puerta) == ["1", "Quedarme en Inca"], "oleadas para elegir: %s" % [botones(main._puerta)])
	main._quedarme()
	await process_frame
	ok(main.state == "play" and not Ciudad.en_portal(sim), "Quedarme en Inca aparta al héroe de la entrada")

	# baja a la 1
	sim.p.gold = 50
	main._a_mazmorra(1)
	ok(not Ciudad.es_ciudad(sim.L) and sim.wave == 1 and not sim.enemies.is_empty(), "baja a la oleada 1 con enemigos")
	ok(sim.oro_salida == 50, "se apunta el oro con el que se sale")

	# con el jefe vivo, la escalera está cerrada; sin él, se pregunta
	var st: Dictionary = sim.L.stairs_cell
	ok(sim.jefe_vivo() != null, "hay jefe")
	for e in sim.enemies:
		e.dead = true
	sim.enemies.clear()
	await pisar(main, Vector2i(st.cx, st.cy))
	ok(main.state == "escalera" and main._escalera.visible, "tras el jefe, la escalera pregunta (%s)" % main.state)
	ok(botones(main._escalera) == ["Bajar a la oleada 2", "Subir a Inca", "Seguir en el piso"], "botones de la escalera: %s" % [botones(main._escalera)])
	ok(sim.p.piso_max == 2, "vencer al jefe abre la oleada 2 en Inca")
	main._escalera_seguir()
	for i in 10: await process_frame
	ok(main.state == "play", "Seguir en el piso no vuelve a preguntar mientras sigue en la escalera")
	main._ir_ciudad()
	await process_frame
	ok(Ciudad.es_ciudad(sim.L) and main.state == "play", "Subir a Inca")
	await pisar(main, Ciudad.PORTAL)
	await process_frame
	ok(botones(main._puerta) == ["1", "2", "Quedarme en Inca"], "ahora se puede elegir la 2: %s" % [botones(main._puerta)])
	main._a_mazmorra(2)
	ok(sim.wave == 2 and main.state == "play", "baja a la oleada 2")

	# bajar por la escalera: a la oleada 3
	for e in sim.enemies:
		e.dead = true
	sim.enemies.clear()
	st = sim.L.stairs_cell
	await pisar(main, Vector2i(st.cx, st.cy))
	main._escalera_bajar()
	for i in 120:
		await process_frame
		if sim.wave == 3: break
	ok(sim.wave == 3 and not Ciudad.es_ciudad(sim.L), "Bajar lleva a la oleada 3")

	# morir: se pierde la mochila y el oro de la bajada; el equipo se queda
	var arma = sim.p.eq.get("weapon")
	sim.p.bag.append(Items.make_gear(sim.rng, 2, sim.p.cls_key(), "helm"))
	var oro: int = sim.oro_salida
	sim.p.gold = oro + 300
	sim.p.hp = 0
	sim.p.dead = true
	sim.p.death_t = 1.7
	for i in 60:
		await process_frame
		if main.state == "over": break
	ok(main.state == "over", "panel «Has caído»")
	ok(botones(main._muerte) == ["Volver a Inca", "Volver al menú"], "sin Revivir: %s" % [botones(main._muerte)])
	main._volver_tras_morir()
	await process_frame
	ok(Ciudad.es_ciudad(sim.L) and main.state == "play" and not sim.p.dead, "vuelve a Inca")
	ok(sim.p.bag.is_empty(), "pierde la mochila")
	ok(sim.p.gold == oro, "pierde el oro ganado en la bajada (%d, salió con %d)" % [sim.p.gold, oro])
	ok(sim.p.eq.get("weapon") == arma, "conserva el equipo puesto")
	ok(sim.p.hp == sim.p.st.maxHp, "con la vida llena")
	ok(sim.p.piso_max == 3, "conserva las oleadas abiertas (%d)" % sim.p.piso_max)

	main.queue_free()
	await process_frame
	print("todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit(fallos)

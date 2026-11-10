extends SceneTree
## Efectos de las magias (Hechizos3D + catálogo) y panel de ajuste, en la sala Efectos del piso de prueba.
## godot --headless --path . -s tests/test_efectos.gd
var fallos := 0
func ok(c: bool, q: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", q)

func _init() -> void:
	# el catálogo: cada ficha con forma conocida y su hoja (o su reserva) en assets/vfx
	var cat := Hechizos3D.catalogo()
	ok(cat.size() >= 7, "catálogo (%d fichas)" % cat.size())
	for id in cat:
		var d: Dictionary = cat[id]
		ok(String(d.get("forma", "")) in ["proyectil", "golpe", "suelo", "aura"], "forma de " + id)
		ok(Hechizos3D.hoja_de(d).tex != null, "hoja de " + id)

	var main: Node = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var efectos := -1
	var l := PisoPrueba.salas_menu()
	for i in l.size():
		if l[i][1] == "efectos": efectos = i
	main.menu.piso_prueba.emit(efectos, "")
	for _f in 3:
		await process_frame
	var sim: Sim = main.sim
	var H: Hechizos3D = main.hechizos
	ok(main.clase == "mage", "en la sala de efectos, mago")

	# cada ficha sale con «probar» (lo que hace el botón del panel)
	for id in cat:
		var antes := H.vivos(id)
		H.probar(id)
		ok(H.vivos(id) > antes, "probar " + id)
	await create_timer(3.6).timeout
	ok(H.vivos() == 0, "los de prueba se acaban solos (%d vivos)" % H.vivos())

	# bola de fuego de verdad: vuela y al chocar, explosión
	sim.cls.fballs.append({"crit": false, "x": sim.p.x, "y": sim.p.y - 20, "vx": 0.0, "vy": -280.0, "life": .85, "ang": -PI / 2, "dmg": 1.0, "t": 0.0, "dead": false})
	await process_frame
	await process_frame
	ok(H.vivos("bola_fuego") == 1, "bola de fuego en vuelo")
	var exp := false
	for _f in 60:
		await process_frame
		if H.vivos("explosion_fuego") > 0: exp = true
	ok(exp and H.vivos("bola_fuego") == 0, "al acabar, la explosión")

	# habilidades del mago: 1 nova, 2 llamarada, 3 teletransporte
	sim.p.mana = 999
	sim.use_skill(sim.p.skills.find("nova"))
	for _f in 3:
		await process_frame
	ok(H.vivos("mago_nova") == 1, "nova: anillo en el suelo")
	ok(H.vivos("cast_circulo") >= 1 and H.vivos("cast_resplandor") >= 1 and H.vivos("cast_mano") >= 1, "aura de lanzar al usar una habilidad")
	var m: Ent.Enemy = sim.enemies.filter(func(e): return e.muneco)[0]
	sim.p.x = m.x + 30   # al lado de un muñeco, para que la llamarada lo alcance
	sim.p.y = m.y
	sim.unstick(sim.p)
	await process_frame
	sim.use_skill(sim.p.skills.find("freeze"))
	for _f in 3:
		await process_frame
	ok(H.vivos("mago_llamarada") == 1, "llamarada: la onda")
	var aturdidos := sim.enemies.filter(func(e): return e.frozen > 0).size()
	ok(aturdidos > 0 and H.vivos("mago_llamas") == aturdidos, "llamas sobre los aturdidos (%d de %d)" % [H.vivos("mago_llamas"), aturdidos])
	var x0 := sim.p.x
	sim.cur_inp = null
	sim.p.face = PI
	var tele0 := H.vivos("mago_teletransporte")
	sim.use_skill(sim.p.skills.find("blink"))
	await process_frame
	await process_frame
	ok(absf(sim.p.x - x0) > 40 and H.vivos("mago_teletransporte") == tele0 + 2, "teletransporte: al irse y al llegar")

	# panel: F4 lo abre, las barras cambian la ficha en vivo
	var P: PanelEfectos = main.panel_efectos
	P.visible = true
	P.refrescar()
	P._lista.select(P._ids.find("mago_nova"))
	P._cargar()
	var tam0: float = Hechizos3D.ficha("mago_nova").tam
	P._barras["tam"].value = tam0 + .5
	ok(absf(float(Hechizos3D.ficha("mago_nova").tam) - (tam0 + .5)) < .02, "la barra cambia la ficha")
	Hechizos3D.ficha("mago_nova").tam = tam0
	# el formato de guardado se vuelve a leer igual (sin escribir el de verdad)
	var lineas := []
	for k in cat:
		lineas.append(" %s: %s" % [JSON.stringify(k), JSON.stringify(cat[k], "", false)])
	var j = JSON.parse_string("{\n" + ",\n".join(lineas) + "\n}\n")
	ok(j is Dictionary and j.size() == cat.size(), "formato del catálogo")

	# caballero de la muerte y señor oscuro: cada habilidad saca su efecto
	for cl in ["dk", "dl"]:
		main._ir_menu()
		await process_frame
		main.menu.piso_prueba.emit(efectos, cl)
		for _f in 4:
			await process_frame
		sim = main.sim
		H = main.hechizos
		ok(main.clase == cl, "sala de efectos como " + cl)
		var esperado := {"dk": [["raise", "dk_levantar"], ["drain", "dk_drenaje"], ["whirl", "dk_torbellino"]],
			"dl": [["cloud", "dl_nube"], ["pool", "dl_charco"], ["pact", "dl_pacto"]]}
		for par in esperado[cl]:
			var i: int = sim.p.skills.find(par[0])
			if i < 0:
				ok(false, "%s no tiene %s (%s)" % [cl, par[0], sim.p.skills])
				continue
			sim.p.mana = 999
			sim.p.sk[i].cd = 0
			sim.p.pool_t = 0
			sim.use_skill(i)
			var visto := false
			for _f in 30:   # algunas salen al acabar el gesto (hasta 0,6 s)
				await create_timer(.05).timeout
				if H.vivos(par[1]) > 0:
					visto = true
					break
			ok(visto, "%s: %s → %s" % [cl, par[0], par[1]])

	main.queue_free()
	await process_frame
	print("test_efectos: ", "todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit(fallos)

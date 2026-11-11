extends SceneTree
## TemaMazmorra de la mazmorra: el «Piso de prueba 7 · Inframundo» sale del generador de siempre como piso de pasarelas,
## sin enemigos, con las texturas del tema, el mar de lava, cascadas, luces y brasas; al volver a Inca
## el entorno vuelve a ser el de antes.
## godot --headless --path . -s tests/test_temas.gd
var fallos := 0
func ok(c: bool, q: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", q)

func _init() -> void:
	# las texturas del tema
	for clave in ["suelo", "roca"]:
		for capa in ["color", "normal", "rugosidad", "brillo"]:
			ok(TemaMazmorra.tex("inframundo", clave, capa) != null, "textura %s_%s" % [clave, capa])
	ok(TemaMazmorra.tex("inframundo", "lava", "color") != null, "textura de la lava")
	# el mapa: mismo generador, piso de pasarelas, con el tema
	var L := PisoPrueba.generar(7)
	ok(L.get("plataformas", false), "piso de pasarelas sobre el abismo")
	ok(TemaMazmorra.de(L) == "inframundo", "lleva el tema del Inframundo")
	ok(PisoPrueba.nombre(7) == "Piso de prueba 7 · Inframundo", "nombre: " + PisoPrueba.nombre(7))
	var G: PackedByteArray = L.grid
	ok(G.count(DungeonGen.ABISMO) > 200, "hay vacío (lava) bajo las pasarelas (%d)" % G.count(DungeonGen.ABISMO))
	# los pisos 8 y 9 de verdad: pasarelas sobre lava, con el tema; el 7 y el 10 no
	for w in [8, 9]:
		var Lw := DungeonGen.gen_level("tema-%d" % w, w)
		ok(Lw.get("plataformas", false), "el piso %d es de pasarelas" % w)
		ok(TemaMazmorra.de(Lw) == "inframundo", "el piso %d es del Inframundo" % w)
	for w in [7, 10]:
		ok(TemaMazmorra.de(DungeonGen.gen_level("tema-%d" % w, w)) == "", "el piso %d no lleva tema" % w)
	# biblioteca del tema: mismos números de pieza que la normal
	var base := KitMazmorra.mesh_library()
	var lib := KitMazmorra.mesh_library("inframundo")
	ok(lib != base, "biblioteca propia del tema")
	for n in ["suelo", "suelo_sala", "cara", "nucleo", "arco", "agua"]:
		ok(lib.find_item_by_name(n) == base.find_item_by_name(n), "misma pieza " + n)
	var suelo: Mesh = lib.get_item_mesh(lib.find_item_by_name("suelo_sala"))
	ok(suelo.surface_get_material(0) == TemaMazmorra.material_suelo("inframundo"), "suelo con la textura del tema")
	var cara: Mesh = lib.get_item_mesh(lib.find_item_by_name("cara"))
	var con_tex := false
	for s in cara.get_surface_count():
		var m := cara.surface_get_material(s)
		if m is ShaderMaterial and float(m.get_shader_parameter("usar_tex")) > .5:
			con_tex = true
	ok(con_tex, "los muros llevan la roca del tema")
	# el juego: botón del menú
	var main: Node = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var e: Environment = main.entorno.environment
	var fondo_antes := e.background_color
	main.menu.piso_tema.emit(7)
	await process_frame
	await process_frame
	var sim: Sim = main.sim
	ok(main.prueba == 7, "entra en el piso de prueba 7")
	ok(sim.enemies.is_empty(), "sin enemigos (%d)" % sim.enemies.size())
	ok(main.mazmorra.tema == "inframundo", "la vista tiene el tema")
	ok(main.mazmorra.suelo.mesh_library == lib, "el GridMap usa la biblioteca del tema")
	ok(e.background_color != fondo_antes, "entorno del tema")
	var nombres := {}
	var luces := 0
	for c in main.mazmorra.adornos.get_children():
		if c.is_queued_for_deletion():
			continue
		nombres[String(c.name)] = true
		if c is OmniLight3D:
			luces += 1
	for n in ["ParedesAbismo", "MarDeLava", "Calima", "CascadasLava", "BrasasRaiz"]:
		ok(nombres.has(n), "hay " + n)
	ok(not nombres.has("Niebla0"), "sin la niebla del abismo normal")
	# piezas de Tripo del Inframundo
	var cuenta := {}
	for c in main.mazmorra.adornos.get_children():
		if not c.is_queued_for_deletion():
			cuenta[String(c.name).rstrip("0123456789@")] = cuenta.get(String(c.name).rstrip("0123456789@"), 0) + 1
	for n in ["pilar_retorcido", "muro_calavera", "puerta_demoniaca", "brasero_piedra", "remate_punta", "roca_borde", "estalagmitas"]:
		ok(cuenta.get(n, 0) > 0, "hay %s (%d)" % [n, cuenta.get(n, 0)])
	ok(luces > 20 and luces < 200, "luces razonables (%d)" % luces)
	for i in 20:
		await process_frame
	ok(main.state == "play", "se juega")
	# de vuelta a un piso normal: el entorno vuelve
	main._entrar(DungeonGen.gen_level("otro", 1))
	await process_frame
	ok(main.mazmorra.tema == "", "piso normal sin tema")
	ok(e.background_color == fondo_antes, "el entorno vuelve a ser el de siempre")
	ok(main.mazmorra.suelo.mesh_library == base, "y la biblioteca normal")
	print("test_temas: ", "todo bien" if fallos == 0 else "%d fallos" % fallos)
	main.queue_free()
	await process_frame
	quit(1 if fallos else 0)

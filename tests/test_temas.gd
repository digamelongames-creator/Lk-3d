extends SceneTree
## TemaMazmorra de la mazmorra: el «Piso de prueba 7 · Inframundo» sale del generador de siempre como piso de pasarelas,
## sin enemigos, con las texturas del tema, el mar de lava, cascadas, luces y brasas; al volver a Inca
## el entorno vuelve a ser el de antes. También el «Piso de prueba 3 · Galerías hundidas» (niebla azul, cascadas de agua).
## godot --headless --path . -s tests/test_temas.gd
var fallos := 0
func ok(c: bool, q: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", q)

const PUENTE := 9   # número de la escena «puente» (assets/escenas/puente.json)

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
	# prueba puente: mapa a mano, cámara fija, sin interfaz, con las piezas de Tripo
	main.menu.piso_tema.emit(PUENTE)
	await process_frame
	await process_frame
	ok(main.prueba == PUENTE, "entra en la prueba puente")
	ok(main.camara.fija and main.camara.projection == Camera3D.PROJECTION_PERSPECTIVE, "cámara fija en perspectiva")
	ok(not main.hud.visible, "sin interfaz, como en la imagen")
	var piezas := {}
	for c in main.mazmorra.adornos.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			piezas[(c as MeshInstance3D).mesh] = true
	for n in ["tramo_puente", "puente_lejano", "acantilado", "cadena", "jaula", "puerta_demoniaca", "brasero_piedra"]:
		var paq := "inframundo" if n in ["puerta_demoniaca", "brasero_piedra"] else "puente"
		ok(piezas.has(Props3D.malla(paq, n)), "en la prueba puente hay " + n)
	ok(DungeonGen.walk(sim.L.grid[int(sim.p.y / DungeonGen.TS) * DungeonGen.GW + int(sim.p.x / DungeonGen.TS)]), "el héroe empieza sobre el tablero")
	ok(not DungeonGen.walk(sim.L.grid[(20 - 1) * DungeonGen.GW + 15]), "fuera del pretil no se pisa")
	# Galerías hundidas: «Piso de prueba 3», pasarelas sobre un abismo de niebla azul con cascadas de agua
	for clave in ["suelo", "muro", "roca"]:
		for capa in ["color", "normal", "rugosidad"]:
			ok(TemaMazmorra.tex("galerias", clave, capa) != null, "galerías: textura %s_%s" % [clave, capa])
	ok(TemaMazmorra.tex("galerias", "agua", "color") != null, "galerías: textura del agua")
	ok(PisoPrueba.nombre(3) == "Piso de prueba 3 · Galerías hundidas", "nombre: " + PisoPrueba.nombre(3))
	var L3 := PisoPrueba.generar(3)
	ok(L3.get("plataformas", false) and TemaMazmorra.de(L3) == "galerias", "piso 3 de pasarelas con el tema")
	for w in [3, 4, 5]:
		ok(TemaMazmorra.de(DungeonGen.gen_level("tema-%d" % w, w)) == "", "el piso %d de las partidas aún no lleva tema" % w)
	var lib3 := KitMazmorra.mesh_library("galerias")
	var cara3: Mesh = lib3.get_item_mesh(lib3.find_item_by_name("cara"))
	var sillar := false
	for s in cara3.get_surface_count():
		var m := cara3.surface_get_material(s)
		if m is ShaderMaterial and m.get_shader_parameter("tex_color") == TemaMazmorra.tex("galerias", "muro", "color"):
			sillar = true
	ok(sillar, "los muros llevan la sillería del tema")
	main.menu.piso_tema.emit(3)
	await process_frame
	await process_frame
	ok(main.prueba == 3 and main.mazmorra.tema == "galerias", "entra en el piso de prueba 3 con el tema")
	ok(main.sim.enemies.is_empty(), "galerías: sin enemigos (%d)" % main.sim.enemies.size())
	var n3 := {}
	var luces3 := 0
	for c in main.mazmorra.adornos.get_children():
		if c.is_queued_for_deletion():
			continue
		n3[String(c.name)] = true
		if c is OmniLight3D:
			luces3 += 1
	for n in ["ParedesAbismo", "CascadasAgua", "RocioRaiz", "Niebla0", "FondoAbismo"]:
		ok(n3.has(n), "galerías: hay " + n)
	for n in ["MarDeLava", "Calima", "CascadasLava", "BrasasRaiz"]:
		ok(not n3.has(n), "galerías: sin " + n)
	ok(luces3 > 5 and luces3 < 200, "galerías: luces razonables (%d)" % luces3)
	ok(e.background_color == TemaMazmorra.dato("galerias", "entorno").bg, "entorno azul del tema")
	# de vuelta a un piso normal: el entorno vuelve
	main._entrar(DungeonGen.gen_level("otro", 1))
	await process_frame
	ok(main.mazmorra.tema == "", "piso normal sin tema")
	ok(not main.camara.fija, "la cámara vuelve a seguir al héroe")
	ok(e.background_color == fondo_antes, "el entorno vuelve a ser el de siempre")
	ok(main.mazmorra.suelo.mesh_library == base, "y la biblioteca normal")
	print("test_temas: ", "todo bien" if fallos == 0 else "%d fallos" % fallos)
	main.queue_free()
	await process_frame
	quit(1 if fallos else 0)

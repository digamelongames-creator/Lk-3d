extends SceneTree
## Escenas hechas a mano (Escena3D, assets/escenas/*.json): los archivos se leen, todas sus piezas están en el catálogo
## y existen, los tres modos se montan (geometría sin piezas de verdad, final con ellas y con su luz) y el informe sale.
## godot --headless --path . -s tests/test_escenas.gd
var fallos := 0
func ok(c: bool, q: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", q)

func _init() -> void:
	var cat := Escena3D.catalogo()
	ok(cat.size() >= 13, "catálogo de piezas (%d)" % cat.size())
	for id in cat:
		var p: PackedStringArray = String(id).split("/")
		ok(Props3D.tiene(p[0], p[1]), "la pieza del catálogo existe: " + id)
		for k in ["tipo", "medidas", "donde", "visible_hasta"]:
			ok(cat[id].has(k), "%s tiene «%s»" % [id, k])
	var escenas := Escena3D.todas()
	ok("puente" in escenas, "está la escena del puente")
	for e in escenas:
		var E := Escena3D.datos(e)
		ok(not E.is_empty(), "se lee " + e)
		ok(E.has("rejilla") and E.has("camara") and E.has("objetos"), e + " tiene rejilla, cámara y objetos")
		for o in E.get("objetos", []):
			if o.has("pieza"):
				ok(cat.has(String(o.pieza)), "%s: «%s» está en el catálogo" % [e, o.pieza])
	# los tres modos en el juego
	var main: Node = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var e: Environment = main.entorno.environment
	var fondo := e.background_color
	for modo in Escena3D.MODOS:
		main.modo_escena = modo
		main.menu.piso_tema.emit(9)
		await process_frame
		await process_frame
		var de_tripo := 0
		var bloques := 0
		var soles := 0
		for c in main.mazmorra.adornos.get_children():
			if c.is_queued_for_deletion():
				continue
			if c.has_meta("bloque"):
				bloques += 1
			elif c is MeshInstance3D and Props3D.malla("puente", "tramo_puente") == (c as MeshInstance3D).mesh:
				de_tripo += 1
			elif c.name == "Sol":
				soles += 1
		if modo == "geometria":
			ok(de_tripo == 0 and bloques > 40, "geometría: todo cajas (%d) y ninguna pieza de Tripo (%d)" % [bloques, de_tripo])
			ok(not e.volumetric_fog_enabled, "geometría: sin niebla")
		elif modo == "materiales":
			ok(de_tripo > 0 and soles == 0, "materiales: piezas de verdad y sin la luz de la escena")
		else:
			ok(de_tripo > 0 and soles == 1, "final: piezas de verdad y la luz de la escena")
			ok(e.volumetric_fog_enabled, "final: con niebla")
		var inf := Escena3D.informe(main.mazmorra, "puente", modo)
		ok(inf.triangulos_escena > 0 and inf.has("llamadas_de_dibujo") and inf.has("con_tarjeta_grafica"), "informe de " + modo)
	# abismo de cristal (sala especial, cámara del juego): se anda de punta a punta y por los bordes sin pretil se cae
	ok(PisoPrueba.nombre(10) == "Prueba 10 · Abismo de cristal", "nombre: " + PisoPrueba.nombre(10))
	var A := Escena3D.generar("abismo_cristal", 10)
	var G: PackedByteArray = A.grid
	var W := DungeonGen.GW
	ok(A.get("plataformas", false) and A.get("abismo_a_mano", false), "abismo: se cae y la roca la pone la escena")
	ok(TemaMazmorra.de(A) == "galerias", "abismo: tema Galerías hundidas")
	var dist: PackedInt32Array = A.dist
	for c in [Vector2i(20, 25), Vector2i(23, 22), Vector2i(23, 9), Vector2i(20, 4), Vector2i(21, 10)]:
		ok(dist[c.y * W + c.x] >= 0, "abismo: se llega andando a %s" % c)
	ok(not DungeonGen.walk(G[15 * W + 19]) and not DungeonGen.walk(G[15 * W + 22]), "abismo: los pretiles no se pisan")
	ok(G[15 * W + 23] == DungeonGen.ABISMO and G[15 * W + 18] == DungeonGen.ABISMO, "abismo: vacío a los dos lados del puente")
	ok(G[24 * W + 24] == DungeonGen.ABISMO and DungeonGen.walk(G[24 * W + 23]), "abismo: el rellano tiene un borde sin pretil")
	main.modo_escena = "geometria"
	main.menu.piso_tema.emit(10)
	await process_frame
	await process_frame
	var nb := 0
	for c in main.mazmorra.adornos.get_children():
		if c.has_meta("bloque") and not c.is_queued_for_deletion():
			nb += 1
	ok(main.prueba == 10 and nb > 60, "abismo: entra con los bloques (%d)" % nb)
	ok(not main.camara.fija and main.camara.projection == Camera3D.PROJECTION_ORTHOGONAL, "abismo: cámara del juego")
	ok(main.hud.visible, "abismo: sala especial con interfaz")
	ok(main.sim.L.get("plataformas", false) and int(main.sim.p.x / DungeonGen.TS) == 20 and int(main.sim.p.y / DungeonGen.TS) == 15, "abismo: el héroe empieza en el puente (%d, %d)" % [main.sim.p.x, main.sim.p.y])
	# modo final: piezas de Tripo, sin un solo bloque gris, dentro de los límites de una sala especial
	main.modo_escena = "final"
	main.menu.piso_tema.emit(10)
	await process_frame
	await process_frame
	var bloques := 0
	var discos := 0
	for c in main.mazmorra.adornos.get_children():
		if c.is_queued_for_deletion():
			continue
		if c.has_meta("bloque"):
			bloques += 1
		elif c.has_meta("disco"):
			discos += 1
	ok(bloques == 0, "abismo final: sin bloques grises (%d)" % bloques)
	ok(discos == 2, "abismo final: el agua de los dos cuencos")
	var inf := Escena3D.informe(main.mazmorra, "abismo_cristal", "final")
	ok(inf.luces <= 20 and inf.luces_con_sombra <= 1, "abismo final: luces de sala especial (%d, %d con sombra)" % [inf.luces, inf.luces_con_sombra])
	ok(inf.triangulos_escena <= 600000, "abismo final: triángulos de sala especial (%d)" % inf.triangulos_escena)
	for id in ["abismo_cristal/arco_puente", "abismo_cristal/estatua_cuenco", "abismo_cristal/cristales_grande"]:
		ok(Props3D.malla(id.get_slice("/", 0), id.get_slice("/", 1)) != null, "pieza " + id)
	main._entrar(DungeonGen.gen_level("otro", 1))
	await process_frame
	ok(e.background_color == fondo and not main.camara.fija, "al salir, entorno y cámara como antes")
	print("test_escenas: ", "todo bien" if fallos == 0 else "%d fallos" % fallos)
	main.queue_free()
	await process_frame
	quit(1 if fallos else 0)

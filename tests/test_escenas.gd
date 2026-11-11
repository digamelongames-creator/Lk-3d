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
	main.modo_escena = "final"
	main._entrar(DungeonGen.gen_level("otro", 1))
	await process_frame
	ok(e.background_color == fondo and not main.camara.fija, "al salir, entorno y cámara como antes")
	print("test_escenas: ", "todo bien" if fallos == 0 else "%d fallos" % fallos)
	main.queue_free()
	await process_frame
	quit(1 if fallos else 0)

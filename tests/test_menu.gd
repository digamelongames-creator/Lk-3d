extends SceneTree
## Pantalla de inicio, elección de clase, pausa con Esc, «Volver al menú» y opciones guardadas.
## godot --headless --path . -s tests/test_menu.gd
var fallos := 0
func ok(c: bool, q: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", q)

func esc(main: Node) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = KEY_ESCAPE
	e.pressed = true
	main.get_viewport().push_input(e)

func _init() -> void:
	# opciones: se guardan y se vuelven a leer
	var antes := FileAccess.get_file_as_string(Opciones.RUTA) if FileAccess.file_exists(Opciones.RUTA) else ""
	Opciones.cargar()
	Opciones.poner("zoom", 12)
	Opciones.poner("sombras", false)
	Opciones.valores = {}
	ok(Opciones.v("zoom") == 12 and Opciones.v("sombras") == false, "las opciones se guardan")
	Opciones.poner("zoom", 17)
	Opciones.poner("sombras", true)

	var main: Node = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var sim: Sim = main.sim
	ok(main.state == "menu", "arranca en la pantalla de inicio (%s)" % main.state)
	ok(main.menu.visible and main.menu.pagina == "inicio", "el menú se ve")
	ok(not main.hud.visible, "sin HUD en el menú")
	ok(sim.enemies.is_empty(), "el fondo del menú no tiene enemigos")
	var g0: float = main.camara.giro
	for i in 5: await process_frame
	ok(main.camara.giro > g0, "la cámara del fondo gira")

	# Nueva partida → elegir clase
	main.menu.mostrar("clase")
	main.menu.empezar.emit("mage")
	await process_frame
	ok(main.state == "play", "Nueva partida empieza a jugar")
	ok(sim.p.cls == "mage", "con la clase elegida (%s)" % sim.p.cls)
	ok(main.prueba == 0, "partida normal, no el piso de prueba")
	ok(not main.menu.visible and main.hud.visible, "menú oculto y HUD visible")
	ok(is_equal_approx(main.camara.giro, deg_to_rad(45.0)), "la cámara vuelve a 45°")
	ok(main.camara.zoom == 17.0, "zoom de las opciones")
	ok(Ciudad.es_ciudad(sim.L) and sim.enemies.is_empty(), "la partida empieza en Inca, sin enemigos")
	main._a_mazmorra(1)
	ok(not sim.enemies.is_empty(), "la mazmorra tiene enemigos")

	# Esc → pausa → Esc → sigue
	esc(main)
	await process_frame
	ok(main.state == "pausa" and main.menu.visible and main.menu.pagina == "pausa", "Esc abre la pausa (%s)" % main.state)
	var x: float = sim.p.x
	var hp: float = sim.p.hp
	for i in 10: await process_frame
	ok(sim.p.x == x and sim.p.hp == hp, "en pausa la partida no avanza")
	esc(main)
	await process_frame
	ok(main.state == "play" and not main.menu.visible, "Esc otra vez continúa")

	# muerte → Volver al menú
	sim.p.hp = 0
	sim.p.dead = true
	sim.p.death_t = 1.7   # sin esperar a que caiga
	for i in 200:
		await process_frame
		if main.state == "over": break
	ok(main.state == "over", "panel «Has caído»")
	var textos := []
	for b in main._muerte.find_children("*", "Button", true, false):
		textos.append(b.text)
	ok(textos == ["Volver a Inca", "Volver al menú"], "botones del panel de muerte: %s" % [textos])
	main._ir_menu()
	await process_frame
	ok(main.state == "menu" and main.menu.visible and not main._muerte.visible, "Volver al menú")

	# créditos desde el menú vuelven al menú
	main.menu.creditos.emit()
	ok(main.state == "creditos" and not main.menu.visible, "créditos desde el menú")
	main.mostrar_creditos(false)
	ok(main.state == "menu" and main.menu.visible, "al cerrar los créditos, otra vez el menú")

	# piso de prueba: primero la página con las salas; la de efectos va primero y entra con el mago
	main.menu.mostrar("pruebas")
	ok(main.menu.pagina == "pruebas", "Piso de prueba abre el menú de salas")
	var efectos := -1
	var l := PisoPrueba.salas_menu()
	for i in l.size():
		if l[i][1] == "efectos": efectos = i
	ok(efectos > 0 and PisoPrueba.clase_de_sala(efectos) == "mage" and PisoPrueba.clase_de_sala(0) == "knight", "sala de efectos (mago)")
	main.menu.piso_prueba.emit(efectos, "")
	await process_frame
	ok(main.prueba == 1 and main.state == "play" and main.clase == "mage", "Piso de prueba · Efectos")
	for _f in 5:
		await process_frame
	var munecos: Array = main.sim.enemies.filter(func(e): return e.muneco)
	ok(munecos.size() == PisoPrueba.MUNECOS.size(), "muñecos en la sala de efectos")

	main.queue_free()
	await process_frame
	if antes != "":
		var f := FileAccess.open(Opciones.RUTA, FileAccess.WRITE)
		f.store_string(antes)
	print("todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit(fallos)

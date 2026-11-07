extends SceneTree
## La rueda del ratón y +/− cambian el zoom de la cámara entre 7 y 20 m.
## godot --headless --path . -s tests/test_zoom.gd
var fallos := 0
func ok(c: bool, q: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", q)
func _init() -> void:
	var main: Node = load("res://scenes/main3d.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var cam: CamaraIso = main.camara
	var z0 := cam.zoom
	var rueda := InputEventMouseButton.new()
	rueda.button_index = MOUSE_BUTTON_WHEEL_UP
	rueda.pressed = true
	main._unhandled_input(rueda)
	ok(cam.zoom == z0 - 1, "la rueda acerca (%s → %s)" % [z0, cam.zoom])
	for i in 30:
		main._unhandled_input(rueda)
	ok(cam.zoom == main.ZOOM_MIN, "no baja de %s (%s)" % [main.ZOOM_MIN, cam.zoom])
	var mas := InputEventKey.new()
	mas.physical_keycode = KEY_MINUS
	mas.pressed = true
	for i in 30:
		main._unhandled_input(mas)
	ok(cam.zoom == main.ZOOM_MAX, "no sube de %s (%s)" % [main.ZOOM_MAX, cam.zoom])
	ok(main._zoom_label.text.begins_with("Zoom"), "se ve el zoom")
	print("test_zoom: ", "todo bien" if fallos == 0 else "%d fallos" % fallos)
	main.queue_free()
	await process_frame
	quit(1 if fallos else 0)

extends SceneTree
## godot --headless --path prototipos/coliseo-mecha -s tests/test_hangar.gd
## El taller (piezas con ←→ y teclado) y el editor de la mochila.

const Taller = preload("res://scripts/taller.gd")
const Mecha = preload("res://scripts/mecha.gd")
const Fx = preload("res://scripts/fx.gd")
const Modulos = preload("res://scripts/modulos.gd")
const Piezas = preload("res://scripts/piezas.gd")
var fallos := 0


func ok(cond: bool, texto: String) -> void:
	if not cond:
		fallos += 1
		print("FALLO: ", texto)


func _initialize() -> void:
	_probar.call_deferred()


func tecla(t: Node, k: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.pressed = true
	t._unhandled_input(e)


func _probar() -> void:
	var datos := {"montaje": Piezas.DE_SERIE.duplicate(), "construccion": Modulos.desde_lista(Modulos.DE_SERIE),
		"chatarra": 0, "rival_n": 0, "rival": Modulos.RIVALES[0]}
	var fx := Fx.new()
	root.add_child(fx)
	var m := Mecha.new()
	m.preparar("prueba", Color.GRAY, Color.CYAN, fx)
	root.add_child(m)
	var cam := Camera3D.new()
	root.add_child(cam)
	var t := Taller.new()
	root.add_child(t)
	t.preparar(datos, m, cam)
	t.cambio.connect(func(): m.equipar(datos.montaje, datos.construccion))
	var salir := [false]
	t.a_la_arena.connect(func(): salir[0] = true)
	t.abrir()

	ok(t.fila == 0 and t.modo == "lista", "empieza en la lista, en las piernas")
	var resaltadas := 0
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		if mi.material_overlay != null:
			resaltadas += 1
			ok(mi.get_meta("hueco") == "piernas", "solo se iluminan las piernas")
	ok(resaltadas > 3, "las piernas se iluminan")
	tecla(t, KEY_DOWN)
	tecla(t, KEY_DOWN)
	tecla(t, KEY_DOWN)
	ok(t._hueco() == "brazo_i", "↓↓↓ llega al brazo izquierdo")
	tecla(t, KEY_ENTER)
	ok(t.modo == "elegir", "Intro entra a cambiar la pieza")
	tecla(t, KEY_RIGHT)
	ok(datos.montaje.brazo_i == "martillo", "→ cambia el puño por el martillo")
	ok(m.brazos.i.id == "martillo", "el mecha lleva el martillo")
	for i in 4:
		tecla(t, KEY_LEFT)
	ok(datos.montaje.brazo_i == "vulcan", "← ← ← ← llega a la Vulcan en el brazo izquierdo")
	tecla(t, KEY_ENTER)
	ok(t.modo == "lista", "Intro acepta y vuelve")
	t._elegir_fila(Taller.FILAS.find("mochila"))
	tecla(t, KEY_ENTER)
	ok(t.modo == "mochila" and t.hangar.visible, "la mochila abre la cuadrícula")
	var h = t.hangar
	h.coger("bateria")
	h.clic_celda(Vector2i(0, 3))
	ok(datos.construccion.size() == 3 and m.construccion.size() == 3, "batería puesta y montada")
	h.clic_celda(Vector2i(2, 2))
	ok(h.en_mano != null and h.en_mano.id == "escudo_peq", "coger el escudo")
	h.girar()
	h.clic_celda(Vector2i(3, 3))
	ok(h.en_mano != null, "girado no cabe en la esquina")
	h.clic_celda(Vector2i(2, 0))
	ok(h.en_mano == null, "girado sí cabe arriba")
	h.listo.emit()
	ok(t.modo == "lista" and not h.visible, "volver al taller")
	t._elegir_fila(Taller.FILAS.find("arena"))
	tecla(t, KEY_ENTER)
	ok(salir[0], "a la arena")
	print("todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit(fallos)

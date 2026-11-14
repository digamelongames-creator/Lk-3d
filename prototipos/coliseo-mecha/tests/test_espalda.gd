extends SceneTree
## godot --headless --path prototipos/coliseo-mecha -s tests/test_espalda.gd
## Los tiros por la espalda rompen módulos; el escudo los para; por delante no rompen nada.

const Mecha = preload("res://scripts/mecha.gd")
const Fx = preload("res://scripts/fx.gd")
const Modulos = preload("res://scripts/modulos.gd")
var fallos := 0


func ok(cond: bool, texto: String) -> void:
	if not cond:
		fallos += 1
		print("FALLO: ", texto)


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	var fx := Fx.new()
	root.add_child(fx)
	var m := Mecha.new()
	m.preparar("prueba", Color.GRAY, Color.CYAN, fx)
	root.add_child(m)
	m.equipar(m.montaje, Modulos.desde_lista(Modulos.DE_SERIE))
	m.restablecer(Vector3.ZERO, 0.0)  # mira hacia -Z
	m.activo = true
	var rotos := [0]
	m.modulo_roto.connect(func(_n): rotos[0] += 1)
	var atras := Vector3(0, 0, -1)   # la bala va hacia -Z: viene de detrás
	var delante := Vector3(0, 0, 1)

	ok(m.escudo > 0.0, "empieza con escudo")
	m.recibir(26.0, false, Vector3.ZERO, atras)
	ok(m.vida == m.vida_max, "con escudo la vida no baja")
	m.escudo = 0.0
	for i in 10:
		m.recibir(26.0, false, Vector3.ZERO, delante)
	ok(rotos[0] == 0, "por delante no se rompe nada")
	for i in 6:
		m.recibir(26.0, false, Vector3.ZERO, atras)
	ok(rotos[0] >= 1, "por la espalda se rompe algún módulo")
	m.escudo = 50.0
	m.recibir(150.0, true, Vector3.ZERO, delante)
	ok(m.escudo == 0.0, "el puñetazo rompe el escudo")

	print("todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit(fallos)

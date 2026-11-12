extends SceneTree
## godot --headless --path prototipos/coliseo-mecha -s tests/test_hangar.gd

const Hangar = preload("res://scripts/hangar.gd")
const Modulos = preload("res://scripts/modulos.gd")
var fallos := 0


func ok(cond: bool, texto: String) -> void:
	if not cond:
		fallos += 1
		print("FALLO: ", texto)


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	var datos := {"construccion": Modulos.desde_lista(Modulos.DE_SERIE), "almacen": [], "chatarra": 150,
		"rival_n": 0, "rival": Modulos.RIVALES[0]}
	var h := Hangar.new()
	root.add_child(h)
	h.preparar(datos)
	h.comprar("bateria")
	ok(datos.chatarra == 90 and h.en_mano != null, "comprar descuenta y la pieza va a la mano")
	ok(h.boton_arena.disabled, "con una pieza en la mano no se sale a la arena")
	h.clic_celda(Vector2i(0, 3))
	ok(datos.construccion.size() == 3 and h.en_mano == null, "colocar la batería")
	h.clic_celda(Vector2i(2, 2))
	ok(h.en_mano != null and h.en_mano.id == "escudo_peq", "coger el escudo de la mochila")
	h.girar()
	h.clic_celda(Vector2i(3, 3))
	ok(h.en_mano != null, "girado no cabe en la esquina (2 de ancho)")
	h.clic_celda(Vector2i(2, 0))
	ok(h.en_mano == null, "girado sí cabe arriba")
	h.comprar("escudo")
	ok(h.en_mano == null and datos.chatarra == 90, "sin chatarra no compra")
	h.clic_celda(Vector2i(0, 3))
	h.vender()
	ok(datos.chatarra == 120, "vender da la mitad")
	h.comprar("bateria")
	h.guardar()
	ok(datos.almacen == ["bateria"], "al almacén")
	ok(not h.boton_arena.disabled, "se puede salir a la arena")
	print("todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit(fallos)

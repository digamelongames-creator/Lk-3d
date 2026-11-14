extends SceneTree
## godot --headless --path prototipos/coliseo-mecha -s tests/test_modulos.gd

const Modulos = preload("res://scripts/modulos.gd")
const Piezas = preload("res://scripts/piezas.gd")
var fallos := 0


func ok(cond: bool, texto: String) -> void:
	if not cond:
		fallos += 1
		print("FALLO: ", texto)


func valida(cons: Array, nombre: String) -> void:
	for p in cons:
		ok(Modulos.cabe(cons, p), "%s: %s no cabe o pisa a otra" % [nombre, p.id])
	ok(Modulos.problemas(cons).is_empty(), "%s: %s" % [nombre, Modulos.problemas(cons)])


func _init() -> void:
	valida(Modulos.desde_lista(Modulos.DE_SERIE), "de serie")
	var s0 := Modulos.calcular(Modulos.desde_lista(Modulos.DE_SERIE))
	ok(s0.prop_max > 0 and s0.escudo_max > 0, "de serie lleva propulsión y escudo")
	ok(Piezas.problemas(Piezas.DE_SERIE, Modulos.desde_lista(Modulos.DE_SERIE)).is_empty(), "de serie cabe en peso y reactor")
	for r in Modulos.RIVALES:
		var c := Modulos.desde_lista(r.construccion)
		for p in c:
			ok(Modulos.cabe(c, p), "%s: %s no cabe" % [r.nombre, p.id])
		ok(Piezas.problemas(r.montaje, c).is_empty(), "%s: %s" % [r.nombre, Piezas.problemas(r.montaje, c)])

	# la batería al lado refuerza; separada, no
	var sola: float = Modulos.calcular([Modulos.pieza("prop_peq", Vector2i(0, 0))]).prop_max
	var junta: float = Modulos.calcular([Modulos.pieza("prop_peq", Vector2i(0, 0)), Modulos.pieza("bateria", Vector2i(1, 0))]).prop_max
	var lejos: float = Modulos.calcular([Modulos.pieza("prop_peq", Vector2i(0, 0)), Modulos.pieza("bateria", Vector2i(2, 0))]).prop_max
	ok(is_equal_approx(junta, sola * 1.4), "batería al lado: +40 %")
	ok(is_equal_approx(lejos, sola), "batería lejos: nada")
	# en diagonal no cuenta
	var diag: float = Modulos.calcular([Modulos.pieza("prop_peq", Vector2i(0, 0)), Modulos.pieza("bateria", Vector2i(1, 1))]).prop_max
	ok(is_equal_approx(diag, sola), "batería en diagonal: nada")
	# el recargador refuerza escudo y propulsión a la vez
	var c := [Modulos.pieza("prop_peq", Vector2i(0, 0)), Modulos.pieza("recargador", Vector2i(1, 0)), Modulos.pieza("escudo_peq", Vector2i(2, 0))]
	var s := Modulos.calcular(c)
	ok(is_equal_approx(s.prop_regen, 16.0 * 1.5) and is_equal_approx(s.escudo_regen, 22.0 * 1.5), "recargador a dos lados")
	# girar cambia el tamaño y los bordes
	ok(not Modulos.cabe([], Modulos.pieza("escudo_peq", Vector2i(0, 3))), "1×2 en la última fila no cabe")
	ok(Modulos.cabe([], Modulos.pieza("escudo_peq", Vector2i(0, 3), true)), "girada sí cabe")
	# un módulo roto deja de contar
	c[0].vida = 0.0
	ok(Modulos.calcular(c).prop_max == 0.0, "generador roto: sin propulsión")
	# límites
	var pesada := []
	for x in 4:
		pesada.append(Modulos.pieza("blindaje", Vector2i(0, x)))
		pesada.append(Modulos.pieza("blindaje", Vector2i(2, x)))
	ok(not Piezas.problemas(Piezas.DE_SERIE, pesada).is_empty(), "8 blindajes pasan del peso")
	# piernas de tanque cargan más; torso reactor da más reactor
	var tanque := Piezas.DE_SERIE.duplicate()
	tanque.piernas = "tanque"
	ok(Piezas.problemas(tanque, pesada).is_empty() or Piezas.calcular(tanque, pesada).carga > Piezas.calcular(Piezas.DE_SERIE, pesada).carga, "el tanque carga más")
	var dos := Piezas.DE_SERIE.duplicate()
	dos.brazo_i = "vulcan"
	dos.brazo_d = "vulcan"
	ok(Piezas.calcular(dos, []).consumo == 4, "dos Vulcan gastan 4 de reactor")

	print("todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit(fallos)

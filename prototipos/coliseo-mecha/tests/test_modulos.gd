extends SceneTree
## godot --headless --path prototipos/coliseo-mecha -s tests/test_modulos.gd

const Modulos = preload("res://scripts/modulos.gd")
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
	for r in Modulos.RIVALES:
		valida(Modulos.desde_lista(r.construccion), r.nombre)

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
	ok(not Modulos.problemas(pesada).is_empty(), "8 blindajes pasan del peso")

	print("todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit(fallos)

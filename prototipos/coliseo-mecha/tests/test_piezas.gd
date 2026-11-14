extends SceneTree
## godot --headless --path prototipos/coliseo-mecha -s tests/test_piezas.gd
## Todas las piezas se montan, se marcan para el taller y cada arma dispara o golpea.

const Mecha = preload("res://scripts/mecha.gd")
const Fx = preload("res://scripts/fx.gd")
const Piezas = preload("res://scripts/piezas.gd")
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
	var suelo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	suelo.add_child(col)
	root.add_child(suelo)
	var m := Mecha.new()
	m.preparar("a", Color.GRAY, Color.CYAN, fx)
	root.add_child(m)
	var r := Mecha.new()
	r.preparar("b", Color.RED, Color.ORANGE, fx)
	root.add_child(r)
	m.rival = r
	r.rival = m
	r.restablecer(Vector3(0, 0, -5), PI)
	await physics_frame
	await physics_frame
	for hueco in ["piernas", "torso", "cabeza"]:
		for id in Piezas.catalogo(hueco):
			var mo := Piezas.DE_SERIE.duplicate()
			mo[hueco] = id
			m.equipar(mo, [])
			var n := 0
			for mi in m.find_children("*", "MeshInstance3D", true, false):
				if mi.get_meta("hueco", "") == hueco:
					n += 1
			ok(n >= 2, "%s %s tiene mallas" % [hueco, id])
	for id in Piezas.ARMAS:
		for lado in ["i", "d"]:
			var mo := Piezas.DE_SERIE.duplicate()
			mo["brazo_" + lado] = id
			mo["brazo_" + ("d" if lado == "i" else "i")] = "puno"
			m.equipar(mo, [])
			m.restablecer(Vector3.ZERO, 0.0)
			r.restablecer(Vector3(0, 0, -5), PI)
			m.activo = true
			r.activo = true
			var f: Dictionary = Piezas.ARMAS[id]
			m.punto_mira = r.centro()
			var antes := fx.get_child_count()
			var vida: float = r.vida + r.escudo
			for k in 90:
				if lado == "i":
					m.gatillo_i = f.tipo == "disparo" or k % 30 == 0
				else:
					m.gatillo_d = f.tipo == "disparo" or k % 30 == 0
				m.control = null
				m._physics_process(1.0 / 60.0)
			if f.tipo == "disparo":
				ok(fx.get_child_count() > antes, "%s en el brazo %s dispara" % [id, lado])
			else:
				ok(r.vida + r.escudo < vida, "%s en el brazo %s golpea" % [id, lado])
	print("todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit(fallos)

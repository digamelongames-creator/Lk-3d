extends SceneTree
## Todos los héroes corren con run (no con «andar», el Walk de Diego, que queda en heroe_anims).
## El mago lleva la Maga (Modelo3D.HEROE_CLASE), de pie, de 1,8 m y con sus ataques de Cast.
## godot --headless --path . -s tests/test_heroes_andar.gd

var fallos := 0

func ok(c: bool, que: String) -> void:
	if not c:
		print("FALLO ", que)
		fallos += 1

## transformación global sin estar en el árbol (en _init todavía no lo está)
func _glob(n: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	while n != null:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t

func _init() -> void:
	_correr.call_deferred()   # dentro del árbol, para que el AnimationPlayer ponga la pose

func _correr() -> void:
	var x := Modelo3D.extra()
	ok(x.anims.has("andar"), "heroe_anims.glb sin «andar»")
	ok(float(x.datos.get("andar", {}).get("avance", 0)) > 1.0, "«andar» sin avance en el .json")
	# ritmo: al 100 % (≈4,5 m/s) unas 3 veces el clip; a 1,5 m/s, el clip tal cual
	ok(absf(Actores3D.ritmo_andar(1.516 * 16.0) - 1.0) < .02, "ritmo a 1,5 m/s")
	ok(Actores3D.ritmo_andar(73.0) > 2.5, "ritmo al 100 %")
	ok(Modelo3D.de_clase("mage") == "maga", "el mago no lleva la Maga")
	ok(Modelo3D.de_clase("knight") == "esqueleto", "el caballero no lleva el esqueleto")
	var m := Modelo3D.crear("maga")
	ok(m != null and m.anim != null, "Maga sin modelo o sin animaciones")
	if m != null and m.anim != null:
		m.anadir_animaciones()
		for a in ["idle", "andar", "run", "hurt", "death", "attack", "lanzar_bola", "lanzar_estallido", "lanzar_menor", "lanzar_mayor"]:
			ok(m.anim.has_animation(a), "Maga sin " + a)
		ok(m.anim.get_animation("andar").loop_mode == Animation.LOOP_LINEAR, "«andar» no se repite")
		ok(m.golpe_de("attack") == m.golpe_de("lanzar_bola"), "el ataque de la Maga no es el Cast")
		# de pie y de 1,8 m: la cabeza por encima de la cadera tras poner la pose de «idle»
		root.add_child(m)
		for a in ["idle", "andar"]:
			m.reproducir(a, 1.0, 0.0, true)
			m.anim.advance(.3)
			var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
			var cab := (_glob(sk) * sk.get_bone_global_pose(sk.find_bone("mixamorig_HeadTop_End"))).origin
			var cad := (_glob(sk) * sk.get_bone_global_pose(sk.find_bone("mixamorig_Hips"))).origin
			print("Maga %s: cabeza %.2f m, cadera %.2f m" % [a, cab.y, cad.y])
			ok(cab.y > 1.5 and cab.y < 2.0, "Maga no mide ~1,8 m en " + a)
			ok(cad.y > .7 and cad.y < 1.2, "cadera de la Maga fuera de sitio en " + a)
		# lo colgado de la mano sale en metros como en el esqueleto
		var e := Modelo3D.crear("esqueleto")
		root.add_child(e)
		ok(absf(_glob(m.enganche("RightHand")).basis.get_scale().x - _glob(e.enganche("RightHand")).basis.get_scale().x) < .02, "escala de la mano de la Maga")
		e.free()
		m.free()
	# en partida: mago con la Maga, anda con «andar»
	var raiz := Node3D.new()
	root.add_child(raiz)
	var sim := Sim.new()
	var act := Actores3D.new()
	act.sim = sim
	raiz.add_child(act)
	sim.new_game(1, "prueba-andar", "mage")
	sim.enter_level(DungeonGen.gen_level(sim.level_seed(1), 1))
	act.nuevo_piso()
	ok(act._heroe_de == "maga", "el mago en partida no lleva la Maga")
	var vistos := {}
	var bot := Bot.new()
	for i in 300:
		sim.step(1.0 / 30, bot.play(sim))
		act.actualizar(1.0 / 30)
		if act._modelo_heroe != null:
			vistos[act._modelo_heroe.actual] = true
	print("animaciones vistas: ", vistos.keys())
	ok(vistos.has("run") and not vistos.has("andar"), "el héroe no corre con run")
	# panel F5: cambiar de skin y forzar cada carrera nueva
	for id in ["esqueleto", "maga"]:
		act.cambiar_skin(id)
		ok(act._heroe_de == id, "no cambia a la skin " + id)
		for n in ["correr_medio", "correr_rapido", "trotar", "correr_adelante", "correr_herido_atras"]:
			act.anim_forzada = n
			sim.step(1.0 / 30, Sim.Inp.new())
			act.actualizar(1.0 / 30)
			ok(act._modelo_heroe.actual == n, "%s no reproduce %s" % [id, n])
	act.anim_forzada = ""
	ok(PisoPrueba.salas_menu().any(func(x): return x[1] == "animaciones"), "falta la sala Animaciones")
	print("test_heroes_andar: ", "todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit(1 if fallos else 0)

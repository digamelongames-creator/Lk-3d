extends SceneTree
## Todos los héroes, con cualquier skin, corren con «correr_rapido» (13 nov); «andar» queda en heroe_anims sin usar.
## Skins de Diego (Amazona, Vaquita, Cuernitos, Elfa azul) y el «Piso de prueba · Animaciones» con enemigos.
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
	ok(Modelo3D.de_clase("knight") == "knight", "el caballero no lleva el Knight")
	ok(Modelo3D.de_clase("dl") == "brujo", "el señor oscuro no lleva el Brujo")
	ok(Modelo3D.de_clase("dk") == "esqueleto", "el caballero de la muerte no lleva el esqueleto")
	ok(Modelo3D.FICHAS.bufona.glb == "bufona" and Modelo3D.hay("bufona"), "el enemigo Bufona no lleva el modelo nuevo")
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
	ok(vistos.has("correr_rapido") and not vistos.has("andar"), "el héroe no corre con correr_rapido")
	# panel F5: cambiar de skin y forzar cada carrera nueva
	for s in Modelo3D.SKINS_HEROE:
		var id: String = s[1]
		act.cambiar_skin(id)
		ok(act._heroe_de == id, "no cambia a la skin " + id)
		for n in ["correr_medio", "correr_rapido", "trotar", "correr_adelante", "correr_herido_atras"]:
			act.anim_forzada = n
			sim.step(1.0 / 30, Sim.Inp.new())
			act.actualizar(1.0 / 30)
			ok(act._modelo_heroe.actual == n, "%s no reproduce %s" % [id, n])
	act.anim_forzada = ""
	# las skins nuevas: de pie, de ~1,7–1,8 m, y corren con correr_rapido en partida
	for id in ["amazona", "vaquita", "cuernitos", "elfa_azul", "bufona", "brujo", "knight", "medusa"]:
		ok(Modelo3D.hay(id), "falta la skin " + id)
		var k := Modelo3D.crear(id)
		k.anadir_animaciones()
		root.add_child(k)
		for a in ["idle", "run", "correr_rapido", "attack", "hurt", "death"]:
			ok(k.anim.has_animation(a), "%s sin %s" % [id, a])
		k.reproducir("correr_rapido", 1.0, 0.0, true)
		k.anim.advance(.3)
		var sk2: Skeleton3D = k.find_children("*", "Skeleton3D", true, false)[0]
		var cab2 := (_glob(sk2) * sk2.get_bone_global_pose(sk2.find_bone("mixamorig_HeadTop_End"))).origin
		print("%s: cabeza %.2f m" % [id, cab2.y])
		ok(cab2.y > 1.6 and cab2.y < 2.0, id + " no mide ~1,8 m")
		k.free()
	act.cambiar_skin("amazona")
	vistos.clear()
	sim.enemies.clear()   # solo andar: sin enemigos que le hagan atacar o rodar
	for i in 60:
		var inp := Sim.Inp.new()
		inp.move = Vector2(1, 0) if (i / 20) % 2 == 0 else Vector2(-1, 0)
		sim.step(1.0 / 30, inp)
		act.actualizar(1.0 / 30)
		vistos[act._modelo_heroe.actual] = true
	print("Amazona: ", vistos.keys())
	ok(vistos.has("correr_rapido"), "la Amazona no corre con correr_rapido")
	# el piso de prueba de animaciones: en el menú, sin la sala vieja, piso normal con enemigos
	ok(not PisoPrueba.salas_menu().any(func(x): return x[1] == "animaciones"), "sigue la sala Animaciones del piso 1")
	ok(PisoPrueba.ANIMACIONES in PisoPrueba.pisos_menu(), "falta el Piso de prueba · Animaciones en el menú")
	ok(PisoPrueba.con_enemigos(PisoPrueba.ANIMACIONES) and not PisoPrueba.con_enemigos(1), "enemigos en los pisos de prueba")
	var LA := PisoPrueba.generar(PisoPrueba.ANIMACIONES)
	ok(int(LA.get("prueba", 0)) == PisoPrueba.ANIMACIONES and not LA.has("salas_prueba"), "el piso de animaciones no es un piso normal")
	sim.enter_level(LA)
	ok(sim.enemies.size() > 5, "el piso de animaciones sin enemigos (%d)" % sim.enemies.size())
	print("test_heroes_andar: ", "todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit(1 if fallos else 0)

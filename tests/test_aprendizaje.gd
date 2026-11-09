extends SceneTree
## Enemigos que aprenden (9 nov): eligen la táctica que mejor les va, cada puesto tiene su carácter,
## el archivo se guarda y se suma (formato del servidor), títulos, puestos por piso y la sala del aprendizaje.
## godot --headless --path . -s tests/test_aprendizaje.gd

var fallos := 0

func ok(c: bool, que: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", que)

func _piso(semilla: String, w: int = 1) -> Sim:
	var sim := Sim.new()
	sim.new_game(w, semilla, "knight")
	sim.enter_level(DungeonGen.gen_level(sim.level_seed(w), w))
	return sim

func _vacio(semilla: String) -> Sim:
	var sim := _piso(semilla)
	sim.enemies.clear()
	return sim

func _pasos(sim: Sim, n: int, inp: Sim.Inp = null) -> void:
	for i in n:
		sim.step(1.0 / 60, inp if inp != null else Sim.Inp.new())

func _init() -> void:
	# ---- aprende cuál funciona: si «por la espalda» da más, acaba usándola casi siempre ----
	var a := Aprendizaje.new()
	a.rng.seed = 7
	for i in 400:
		var t := a.elegir("esqueleto/esbirro", "1-5", true)
		a.apuntar("esqueleto/esbirro", "1-5", t, 1.0 if t == "espalda" else .1, false)
	var veces := 0
	for i in 200:
		if a.elegir("esqueleto/esbirro", "1-5", true) == "espalda":
			veces += 1
	ok(veces > 150, "elige la táctica que mejor le va (%d de 200)" % veces)
	for i in 100:
		ok(a.elegir("x/grupo", "", false) != "escolta", "sin jefe, nunca «escolta»")
	# ---- cada puesto, su carácter: el 1-9 aprendió el contraataque aunque a su tipo le va la espalda ----
	a.fusionar({"puestos": {"1-9": {"t": {"contra": [30, 48]}, "combates": 30, "muertes": 0}}})   # su memoria propia
	var v9 := a.valores("esqueleto/esbirro", "1-9")
	var v10 := a.valores("esqueleto/esbirro", "1-10")
	ok(v9.contra > v9.espalda, "el 1-9 prefiere el contraataque")
	ok(v10.espalda > v10.contra, "el 1-10 (sin combates propios) sigue a su tipo")
	# ---- guardar, cargar y sumar (lo que hará el servidor con los de todos) ----
	var ruta := "user://test_aprendizaje.json"
	var b := Aprendizaje.new(ruta)
	b.apuntar("knight/grupo", "2-37", "rodear", .5, true)
	b.guardar()
	var c := Aprendizaje.new(ruta)
	ok(c.combates("2-37") == 1 and int(c.puestos["2-37"].muertes) == 1, "se guarda y se carga")
	c.fusionar(b.datos())
	ok(c.combates("2-37") == 2 and float(c.tipos["knight/grupo"].rodear[0]) == 2.0, "se suma lo de otra partida")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	# ---- títulos: Asesino a las ASESINO_N muertes, Experto a los EXPERTO_N combates ----
	var d := Aprendizaje.new()
	for i in Aprendizaje.ASESINO_N:
		d.apuntar("k/grupo", "3-1", "directo", 1, true)
	ok(d.titulo("3-1") == "Asesino", "Asesino")
	for i in Aprendizaje.EXPERTO_N:
		d.apuntar("k/grupo", "3-2", "directo", .2, false)
	ok(d.titulo("3-2") == "Experto", "Experto")
	ok(d.titulo("3-3") == "", "sin título")
	# ---- puestos por piso: «piso-n», sin repetir, en cualquier mazmorra ----
	for sem in ["ap1", "ap2"]:
		var sim := _piso(sem)
		var vistos := {}
		var bien := true
		for e in sim.enemies:
			bien = bien and e.puesto.begins_with("1-") and not vistos.has(e.puesto) and e.apr_clave.contains("/")
			vistos[e.puesto] = true
		ok(bien and vistos.size() > 40, "puestos únicos en el piso 1 (%s: %d)" % [sem, vistos.size()])
	# ---- el título pasa a la partida siguiente: el 1-3 te mató 3 veces y sale como Asesino ----
	var s0 := _piso("ap3")
	for i in Aprendizaje.ASESINO_N:
		s0.apr.apuntar("esqueleto/grupo", "1-3", "directo", 1, true)
	var s1 := Sim.new()
	s1.apr = s0.apr
	s1.new_game(1, "otra", "knight")
	s1.enter_level(DungeonGen.gen_level(s1.level_seed(1), 1))
	var e3: Ent.Enemy = null
	for e in s1.enemies:
		if e.puesto == "1-3":
			e3 = e
	ok(e3 != null and e3.apr_titulo == "Asesino", "el 1-3 sigue siendo Asesino en otra mazmorra")
	# ---- un combate de verdad: despierta, elige táctica y al morir lo apunta ----
	var sim := _vacio("ap4")
	var e := sim.mon_spawn("esqueleto", sim.p.x + 60, sim.p.y)
	e.puesto = "1-1"
	e.apr_clave = "esqueleto/grupo"
	sim.wake(e)
	ok(e.apr_activo and Aprendizaje.TACTICAS.has(e.tactica), "al despertar elige táctica (%s)" % e.tactica)
	_pasos(sim, 120)
	sim.kill_enemy(e, 0)
	ok(not e.apr_activo and sim.apr.combates("1-1") == 1, "al morir se apunta el combate")
	# ---- «por la espalda»: con el héroe mirando al este, el enemigo de delante acaba detrás ----
	sim = _vacio("ap5")
	sim.p.face = 0.0
	sim.p.hp = 9999; sim.p.st.maxHp = 9999
	e = sim.mon_spawn("esqueleto", sim.p.x + 70, sim.p.y)
	sim.wake(e)
	e.tactica = "espalda"
	var detras := false
	for i in 240:
		sim.p.face = 0.0
		sim.step(1.0 / 60, Sim.Inp.new())
		if e.x < sim.p.x - 4:
			detras = true
			break
	ok(detras, "«por la espalda» rodea hasta quedar detrás (x %.0f, héroe %.0f)" % [e.x, sim.p.x])
	# ---- «rematar»: se queda a distancia con tu vida llena y entra cuando te queda poca ----
	sim = _vacio("ap6")
	e = sim.mon_spawn("esqueleto", sim.p.x + 70, sim.p.y)
	sim.wake(e)
	e.tactica = "rematar"
	var golpes := 0
	for i in 150:
		sim.p.hp = sim.p.st.maxHp
		sim.step(1.0 / 60, Sim.Inp.new())
		if e.act == "wind":
			golpes += 1
	ok(golpes == 0, "con vida llena no se lanza (%d)" % golpes)
	var lanzo := false
	for i in 180:
		sim.p.hp = sim.p.st.maxHp * .3
		sim.p.inv = 1
		sim.step(1.0 / 60, Sim.Inp.new())
		if e.act == "wind" or e.act == "strike":
			lanzo = true
			break
	ok(lanzo, "con poca vida va a rematar")
	# ---- te mata: gana el que dio el golpe ----
	sim = _vacio("ap7")
	e = sim.mon_spawn("esqueleto", sim.p.x + 20, sim.p.y)
	e.puesto = "1-8"
	e.apr_clave = "esqueleto/grupo"
	sim.wake(e)
	sim.p.hp = 1
	sim.p.inv = 0
	sim.hurt_player(50, e.x, e.y, e)
	ok(sim.p.dead and int(sim.apr.puestos["1-8"].muertes) == 1, "la muerte del héroe cuenta para quien la dio")
	# ---- sala del aprendizaje del piso de prueba: 5 de siempre, que vuelven a salir ----
	sim = Sim.new()
	sim.new_game(1, "", "knight")
	sim.enter_level(PisoPrueba.generar(1))
	sim.enemies.clear()
	var S := PisoPrueba.sala_arena(sim)
	ok(not S.is_empty(), "hay sala del aprendizaje")
	sim.p.x = (S.x + 4.5) * DungeonGen.TS
	sim.p.y = (S.y + 3.5) * DungeonGen.TS
	for i in 200:
		PisoPrueba.arena(sim, 1.0 / 60)
	var nombres := []
	for o in sim.enemies:
		if o.en_arena:
			nombres.append(o.puesto)
	nombres.sort()
	ok(nombres == ["prueba-1", "prueba-2", "prueba-3", "prueba-4", "prueba-5"], "ronda 1: los 5 puestos (%s)" % str(nombres))
	ok(sim.enemies[0].rare and sim.enemies[1].apr_lider == sim.enemies[0], "miniboss y sus esbirros")
	for o in sim.enemies:
		sim.wake(o)
		sim.kill_enemy(o, 0)
		o.dead = true
	for i in 200:
		PisoPrueba.arena(sim, 1.0 / 60)
	ok(int(sim.L.arena_estado.ronda) == 2 and sim.apr.combates("prueba-2") == 1, "ronda 2 con los mismos, que recuerdan la 1")
	print("test_aprendizaje: ", "todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit()

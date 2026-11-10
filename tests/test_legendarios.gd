extends SceneTree
## 10 nov 2026: legendarios del caballero con efecto único, equipo que mejora con la oleada,
## jefe que pega ×2,2 y el teletransporte que no entra en las salas secretas.
## godot --headless --path . -s tests/test_legendarios.gd

var fallos := 0

func ok(c: bool, que: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", que)

func _piso(w: int, semilla: String, ck := "knight") -> Sim:
	var sim := Sim.new()
	sim.rng.seed = 7
	sim.new_game(w, semilla, ck)
	sim.enter_level(DungeonGen.gen_level(sim.level_seed(w), w))
	return sim

func _pasos(sim: Sim, n: int) -> void:
	for i in n:
		sim.step(1.0 / 60, Sim.Inp.new())

## pone un legendario del caballero en su hueco
func _poner(sim: Sim, hueco: String) -> Dictionary:
	var it := Items.make_gear(sim.rng, 3, "knight", hueco)
	sim.p.eq[hueco] = it
	sim.recalc(sim.p)
	return it

## un enemigo quieto delante del héroe, sin escudo ni bloqueo
func _enemigo(sim: Sim, dx: float, dy: float) -> Ent.Enemy:
	var e := sim.spawn_enemy("knight", sim.p.x + dx, sim.p.y + dy)
	e.hp = 5000; e.max_hp = 5000; e.ghost = 5000
	e.state = "fight"
	e.guard_cd = INF
	return e

func _init() -> void:
	# ---- equipo por oleada ----
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	ok(Items.escalar(3, 1) == 3 and Items.escalar(3, 11) == 6 and Items.escalar(1, 2) == 1, "afijos: +10 % por oleada, redondeado")
	var suma1 := 0
	var suma10 := 0
	for i in 200:
		suma1 += Items.puntos(Items.make_gear(rng, 1, "knight", "sword", false, false, 1))
		suma10 += Items.puntos(Items.make_gear(rng, 1, "knight", "sword", false, false, 10))
	ok(suma10 > suma1 * 1.6, "las piezas de la oleada 10 dan bastante más (%d frente a %d)" % [suma10, suma1])
	var s10 := _piso(10, "ola10")
	var e10 := s10.spawn_enemy("knight", s10.p.x + 30, s10.p.y)
	e10.rare = false
	var it10 := s10._gear_drop(1)
	ok(int(it10.get("ol", 0)) == 10, "lo que cae en la oleada 10 es de la oleada 10")
	ok(Sim.JEFE_DANO == 2.2, "el jefe pega ×2,2")

	# ---- todos los legendarios del caballero llevan su efecto; los de otras clases, no ----
	for s in Items.set_of("knight").slots:
		var it := Items.make_gear(rng, 3, "knight", s)
		ok(Legendarios.de(it) == Legendarios.EFECTO[s], "legendario del caballero en %s: %s" % [s, Legendarios.de(it)])
		ok(Comparar.lineas(it, null).any(func(l): return String(l[0]).begins_with("★")), "el efecto sale escrito (%s)" % s)
	ok(Legendarios.de(Items.make_gear(rng, 2, "knight", "sword")) == "", "un dorado no lleva efecto")
	ok(Legendarios.de(Items.make_gear(rng, 3, "dk", "sword")) == "", "los de otras clases, de momento, no")

	# ---- espada: el tercer tajo lanza la onda de fuego ----
	var sim := _piso(1, "leg1")
	_poner(sim, "sword")
	sim.p.face = 0
	var lejos := _enemigo(sim, 90, -10)   # fuera del alcance del tajo, en la línea de la onda
	var hp0 := lejos.hp
	sim.p.combo_step = 2
	sim.leg.tajo3()
	ok(sim.leg.ondas.size() == 1, "sale una onda")
	_pasos(sim, 40)
	ok(lejos.hp < hp0, "la onda quema al de delante (%d → %d)" % [hp0, lejos.hp])
	ok(sim.leg.ondas.is_empty(), "y se apaga")

	# ---- guanteletes: el crítico salta a 2 enemigos cercanos ----
	sim = _piso(1, "leg2")
	_poner(sim, "gloves")
	var a := _enemigo(sim, 20, 0)
	var b := _enemigo(sim, 50, 0)
	var c := _enemigo(sim, 80, 0)
	var d := _enemigo(sim, 900, 0)
	sim.leg.critico(a, 40)
	ok(b.hp < 5000 and c.hp < 5000 and d.hp == 5000, "el rayo salta a los 2 de al lado y no al lejano")
	ok(sim.leg.rayos.size() == 2, "dos rayos para la vista")

	# ---- yelmo: matar a una élite cura ----
	sim = _piso(1, "leg3")
	_poner(sim, "helm")
	sim.p.hp = 20
	var el := _enemigo(sim, 20, 0)
	el.rare = true
	sim.kill_enemy(el, 0.0)
	ok(sim.p.hp >= 20 + int(sim.p.st.maxHp * .2) - 1, "matar a una élite cura el 20 %% (%d)" % sim.p.hp)

	# ---- escudo: al bloquear, aturde ----
	sim = _piso(1, "leg4")
	_poner(sim, "shield")
	var at := _enemigo(sim, 20, 0)
	sim.leg.bloqueo(at)
	ok(at.hurt_t >= .99 and at.cool >= .99, "el que te golpea queda aturdido 1 s")

	# ---- coraza: escudo al bajar del 30 %, una vez por minuto ----
	sim = _piso(1, "leg5")
	_poner(sim, "chest")
	var src := _enemigo(sim, 20, 0)
	sim.p.hp = sim.p.st.maxHp * .35
	sim.hurt_player(sim.p.st.maxHp * .1, src.x, src.y, src)
	ok(sim.p.shield > 0, "sale el escudo al bajar del 30 %")
	var sh := sim.p.shield
	sim.p.shield = 0
	sim.p.inv = 0
	sim.hurt_player(5, src.x, src.y, src)
	ok(sim.p.shield == 0 and sh > 0, "no vuelve a salir hasta pasado un minuto")

	# ---- cinturón: la poción cura el doble y da furia ----
	sim = _piso(1, "leg6")
	var sin_c: float = sim.p.st.potionHeal
	Items.add_potion(sim.p)
	sim.p.pot_t = -99.0
	sim.p.hp = 1
	var antes := sim.p.hp
	sim.drink_potion()
	var cura_normal := sim.p.hp - antes
	sim = _piso(1, "leg6")
	_poner(sim, "belt")
	var dmg0: float = sim.p.st.dmg
	Items.add_potion(sim.p)
	sim.p.pot_t = -99.0
	sim.p.hp = 1
	sim.drink_potion()
	ok(sim.p.hp - 1 >= cura_normal * 2 - 1 and cura_normal > 0, "la poción cura el doble (%d frente a %d, base %d)" % [sim.p.hp - 1, cura_normal, sin_c])
	ok(sim.p.st.dmg > dmg0, "y da más daño durante un rato")

	# ---- botas: la voltereta deja fuego que quema ----
	sim = _piso(1, "leg7")
	_poner(sim, "boots")
	var en := _enemigo(sim, 0, 0)
	en.x = sim.p.x
	en.y = sim.p.y
	var hpb := en.hp
	sim.p.roll_t = .2
	sim.leg.paso(1.0 / 60)
	ok(sim.leg.fuegos.size() >= 1, "la voltereta deja fuego")
	sim.p.roll_t = 0
	for i in 70:
		sim.leg.paso(1.0 / 60)
	ok(en.hp < hpb, "el fuego quema al que lo pisa")

	# ---- sala secreta: el teletransporte no entra desde fuera ----
	var probada := false
	for k in 12:
		var sm := _piso(1 + (k % 3), "secreta%d" % k, "mage")
		var l: Array = sm.L.get("secretas", [])
		if l.is_empty():
			continue
		var r: Dictionary = l[0].sala
		var cx: float = (r.x + r.w / 2.0) * DungeonGen.TS
		var cy: float = (r.y + r.h / 2.0) * DungeonGen.TS + 10
		# el héroe, en el suelo más cercano fuera de la sala, apunta al centro de la sala
		var mejor := Vector2(INF, INF)
		for y in DungeonGen.GH:
			for x in DungeonGen.GW:
				var px := (x + .5) * DungeonGen.TS
				var py := (y + .5) * DungeonGen.TS + 10
				if sm.fits(px, py) and sm.sala_secreta_en(px, py - 3) < 0 and Vector2(px - cx, py - cy).length() < Vector2(mejor.x - cx, mejor.y - cy).length():
					mejor = Vector2(px, py)
		sm.p.x = mejor.x
		sm.p.y = mejor.y
		var inp := Sim.Inp.new()
		inp.aim_mouse = true
		inp.aim = Vector2(cx, cy)
		sm.cur_inp = inp
		sm.cls._blink(sm.p, {"cd": 0.0})
		ok(sm.sala_secreta_en(sm.p.x, sm.p.y - 3) < 0, "el teletransporte no cae dentro de la sala secreta")
		probada = true
		break
	ok(probada, "hay algún piso con sala secreta para probar")
	print("test_legendarios: ", "todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit()

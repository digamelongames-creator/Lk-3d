extends SceneTree
## Versión 3D del combate: el héroe no avanza al atacar, el golpe no corta el ataque del enemigo,
## el empujón es pequeño, el enemigo que te golpea queda marcado (ataco) y revivir no aparta a nadie.
## godot --headless --path . -s tests/test_combate.gd
var fallos := 0
func ok(c: bool, q: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", q)

func _init() -> void:
	var sim := Sim.new()
	sim.new_game(1, "combate", "knight")
	sim.enter_level(DungeonGen.gen_level(sim.level_seed(1), 1))
	sim.enemies.clear()
	var p := sim.p
	var sitio := Vector2.ZERO
	for k in 32:
		var q := Vector2(p.x, p.y) + Vector2.from_angle(k * TAU / 32) * 22
		if sim.fits(q.x, q.y, 8):
			sitio = q
			break
	var e := sim.spawn_enemy("knight", sitio.x, sitio.y)
	e.state = "chase"
	e.hp = 9999; e.max_hp = 9999
	# el enemigo prepara su golpe y el héroe le pega mientras
	e.act = "wind"
	e.act_t = .5
	var x0 := p.x
	var y0 := p.y
	var inp := Sim.Inp.new()
	inp.attack = true
	inp.aim = Vector2(e.x, e.y)
	var ex0 := e.x
	var ey0 := e.y
	sim.step(1.0 / 60, inp)
	for i in 8:
		sim.step(1.0 / 60, Sim.Inp.new())
	ok(JS.hypot(p.x - x0, p.y - y0) < 1.0, "el héroe se queda en el sitio (%.1f px)" % JS.hypot(p.x - x0, p.y - y0))
	ok(e.hp < e.max_hp, "el golpe le hace daño")
	ok(e.act == "wind" or e.act == "strike", "el golpe no le corta el ataque (act=%s)" % e.act)
	ok(JS.hypot(e.x - ex0, e.y - ey0) < 12, "empujón pequeño (%.1f px)" % JS.hypot(e.x - ex0, e.y - ey0))
	# acaba golpeando al héroe y queda marcado
	for i in 120:
		sim.step(1.0 / 60, Sim.Inp.new())
	ok(e.ataco, "el enemigo que te golpea queda marcado")
	# morir y revivir: no aparta a los enemigos
	p.hp = 0
	p.dead = true
	var ev := Vector2(e.vx, e.vy)
	sim.revive()
	ok(not p.dead and p.hp > 0, "revive con vida")
	ok(Vector2(e.vx, e.vy) == ev, "revivir no empuja a los enemigos")
	print("test_combate: ", "todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit(1 if fallos else 0)

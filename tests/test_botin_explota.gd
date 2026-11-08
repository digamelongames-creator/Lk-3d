extends SceneTree
## Botín (tanda 2): las élites, los jefes y los cofres lo sueltan en explosión (todas direcciones, en arco),
## el jefe suelta 3 piezas, y la comparación pone flechas junto a cada estadística.
## godot --headless --path . -s tests/test_botin_explota.gd

var fallos := 0

func ok(c: bool, que: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", que)

func _init() -> void:
	var sim := Sim.new()
	sim.new_game(1, "explota", "knight")
	sim.enter_level(DungeonGen.gen_level(sim.level_seed(1), 1))
	var j := sim.jefe_vivo()
	sim.enemies.clear()
	sim.enemies.append(j)
	sim.loot.clear()
	sim.kill_enemy(j, 0.0)
	var piezas := sim.loot.filter(func(l): return l.item.get("gear", false))
	ok(piezas.size() >= 3, "el jefe suelta 3 piezas (%d)" % piezas.size())
	ok(sim.loot.all(func(l): return l.fly != null and float(l.fly.h) > 50), "salen en explosión, en arco alto")
	var alto_max := 0.0
	for i in 120:
		sim.step(1.0 / 60, Sim.Inp.new())
		for l in sim.loot:
			alto_max = maxf(alto_max, float(l.get("alto", 0.0)))
	ok(alto_max > 40, "suben por el aire (%d px)" % alto_max)
	ok(sim.loot.all(func(l): return l.fly == null and float(l.alto) == 0.0), "todas aterrizan")
	# repartidas alrededor, no solo por delante
	var lados := {}
	for l in sim.loot:
		lados[int(floor((atan2(l.y - j.y, l.x - j.x) + PI) / (PI / 2))) % 4] = true
	ok(lados.size() >= 3, "repartidas alrededor (%d de 4 lados)" % lados.size())
	# un enemigo normal: abanico pequeño, como antes
	sim.loot.clear()
	var e := sim.spawn_enemy("knight", sim.p.x + 40, sim.p.y)
	sim._fan(e.x, e.y, [Items.make_gear(sim.rng, 1, "knight", "sword")], 0)
	ok(float(sim.loot[0].fly.h) < 30, "un enemigo normal no hace explosión")
	# comparación: flechas junto a cada estadística
	var a := {"bonus": {"dmg": 5, "hp": 2}, "socks": [null, null]}
	var b := {"bonus": {"dmg": 3, "spd": 1}, "socks": [null]}
	var t := ""
	for x in Comparar.lineas(a, b):
		t += String(x[0]) + "\n"
	ok(t.contains("▲ +2") and t.contains("Daño"), "gana daño con flecha verde:\n" + t)
	ok(t.contains("▼ −1"), "pierde velocidad con flecha roja")
	ok(t.contains("Engarces: 0 de 2   ▲ +1"), "un engarce más")
	print("test_botin_explota: ", "todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit(1 if fallos else 0)

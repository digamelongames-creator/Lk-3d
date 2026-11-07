extends SceneTree
## Las cinco clases del héroe: cada una pelea un rato en el piso 3 usando su ataque, el botón derecho,
## la voltereta y sus tres habilidades, primero sin árbol y luego con el árbol lleno (opciones A y luego B).
## Comprueba que todas hacen daño, matan y lanzan sus habilidades sin errores.
## Uso: godot --headless --path . -s res://tests/test_clases.gd

func _init() -> void:
	var fallos := 0
	for ck in Sim.CLASS_ORDER:
		for modo in ["sin árbol", "árbol A", "árbol B"]:
			var r := _pelea(ck, modo)
			var ok: bool = r.dmg > 0 and r.kills > 0 and r.skills >= 3
			if not ok:
				fallos += 1
			print("%-7s %-10s daño %6d · bajas %3d · habilidades %2d · nodos %2d · vida %4d/%4d%s" % [ck, modo, r.dmg, r.kills, r.skills, r.nodes, r.hp, r.max_hp, "" if ok else "   ← FALLO"])
	print("test_clases: " + ("todo bien" if fallos == 0 else "%d fallos" % fallos))
	quit(0 if fallos == 0 else 1)

func _pelea(ck: String, modo: String) -> Dictionary:
	var sim := Sim.new()
	sim.rng.seed = 11
	sim.new_game(3, "clases", ck)
	var p := sim.p
	if modo != "sin árbol":
		p.skp = 60
		var pref := "_a" if modo == "árbol A" else "_b"
		# varias pasadas: cada nodo que se pueda, primero el de la opción elegida
		for pas in 8:
			for b in 3:
				for t in range(1, 6):
					var ns := sim.arbol.nodes(p.cls_key(), b, t)
					ns.sort_custom(func(x, y): return x.id.ends_with(pref) and not y.id.ends_with(pref))
					for n in ns:
						sim.arbol.learn(n.id)
	var nodes := 0
	for k in p.tree:
		nodes += int(p.tree[k])
	var L := DungeonGen.gen_level(sim.level_seed(3), 3)
	sim.enter_level(L)
	var skills := 0
	var used := {}
	for i in 60 * 70:
		if p.dead:
			p.dead = false
			p.hp = p.st.maxHp
		if p.hp < p.st.maxHp * .3:
			p.hp = p.st.maxHp
		if sim.phase != "fight":
			sim.phase = "fight"
			p.inv = 0
		var inp := Sim.Inp.new()
		var best = null
		var bd := 1e9
		for e in sim.enemies:
			if e.dying:
				continue
			var d := JS.hypot(e.x - p.x, e.y - p.y)
			if d < bd:
				bd = d
				best = e
		if best == null:
			break
		# cada 8 s se va junto al enemigo más cercano (así no hay que buscar el camino)
		if i % 480 == 0 and bd > 90:
			p.x = best.x - 60
			p.y = best.y
			sim.unstick(p)
		inp.aim = Vector2(best.x, best.y)
		inp.aim_mouse = true
		var ranged := p.cls == "mage" or p.cls == "archer"
		if bd > (90.0 if ranged else 22.0):
			inp.move = Vector2(best.x - p.x, best.y - p.y).normalized()
		elif ranged and bd < 50:
			inp.move = -Vector2(best.x - p.x, best.y - p.y).normalized()
		inp.attack_held = true
		inp.attack = i % 20 == 0
		inp.block = (i / 90) % 4 == 3
		inp.dash = i % 400 == 199
		if i % 37 == 0:
			var k := (i / 37) % 3
			var s: Dictionary = p.sk[k]
			if s.cd <= 0 and not (p.skills[k] == "raise" and sim.corpses.is_empty() and sim.allies.is_empty()):
				inp.skill = k
				if not used.has(k):
					used[k] = true
				skills += 1
		sim.step(1.0 / 60, inp)
	return {"dmg": p.dmg_dealt, "kills": sim.kills, "skills": skills, "nodes": nodes, "hp": int(p.hp), "max_hp": int(p.st.maxHp)}

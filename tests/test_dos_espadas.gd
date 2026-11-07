extends SceneTree
## Segunda espada en el hueco del escudo: solo caballero y caballero oscuro; quita el bloqueo y da más daño;
## al quitarla vuelve todo como estaba. El arquero no puede (su hueco es el carcaj).
## Uso: godot --headless --path . -s res://tests/test_dos_espadas.gd

var fallos := 0

func _ok(c: bool, txt: String) -> void:
	if not c:
		fallos += 1
	print(("  bien  " if c else "  FALLO ") + txt)

func _init() -> void:
	for ck in ["knight", "dk"]:
		var sim := Sim.new()
		sim.rng.seed = 5
		sim.new_game(1, "dos", ck)
		sim.enter_level(DungeonGen.gen_level(sim.level_seed(1), 1))
		var p := sim.p
		var escudo = p.eq.shield
		var otra := Items.make_gear(sim.rng, 0, ck, "sword", true)
		_ok(Items.why_equip(p, otra, "shield") == "", ck + ": la espada cabe en el hueco del escudo")
		_ok(not Items.dos_espadas(p), ck + ": con escudo no son dos espadas")
		sim.recalc(p)
		var dmg0: float = p.st.dmg
		var bloq0: float = p.st.blockCh
		p.eq.shield = otra
		sim.recalc(p)
		_ok(Items.dos_espadas(p), ck + ": con dos espadas")
		_ok(p.st.dmg > dmg0, ck + ": más daño (%.1f → %.1f)" % [dmg0, p.st.dmg])
		_ok(p.st.blockCh < bloq0 or bloq0 == 0, ck + ": sin el bloqueo del escudo (%.2f → %.2f)" % [bloq0, p.st.blockCh])
		var inp := Sim.Inp.new()
		inp.block = true
		sim.step(1.0 / 60, inp)
		_ok(not p.blocking, ck + ": no bloquea con el botón derecho")
		p.eq.shield = escudo
		sim.recalc(p)
		_ok(is_equal_approx(p.st.dmg, dmg0), ck + ": al volver al escudo, el daño de antes")
		if ck == "knight":
			sim.step(1.0 / 60, inp)
			_ok(p.blocking, ck + ": con escudo vuelve a bloquear")
	var sa := Sim.new()
	sa.rng.seed = 5
	sa.new_game(1, "dos", "archer")
	var arco := Items.make_gear(sa.rng, 0, "archer", "sword", true)
	_ok(Items.why_equip(sa.p, arco, "shield") != "", "archer: el arco no va en el hueco del carcaj")
	print("test_dos_espadas: " + ("todo bien" if fallos == 0 else "%d fallos" % fallos))
	quit(0 if fallos == 0 else 1)

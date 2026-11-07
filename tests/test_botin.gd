extends SceneTree
## Fase 3: cofres, botín, mochila, equipo y runas, sin pantalla.
## Uso: godot --headless --path . -s res://tests/test_botin.gd

var fails := 0

func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
		print("FALLA: ", what)

func _init() -> void:
	var sim := Sim.new()
	sim.rng.seed = 7
	sim.new_game(1, "botin")
	var L := DungeonGen.gen_level(sim.level_seed(1), 1)
	sim.enter_level(L)
	var p := sim.p
	# equipo inicial: 7 piezas básicas sin engarces → armadura 6 + 4 + 2, 5 % de bloqueo
	ok(p.eq.size() == 7, "equipo inicial de 7 piezas")
	ok(int(p.st.armorPts) == 12, "armadura inicial 12 (%s)" % p.st.armorPts)
	ok(is_equal_approx(p.st.blockCh, .05), "bloqueo inicial")
	var dmg0: float = p.st.dmg - p.eq.sword.bonus.get("dmg", 0)
	# espada legendaria con Filo III: +3 de afijo y +7 de la runa
	var sw := Items.make_gear(sim.rng, 3, "dk", "sword")
	ok(sw.socks.size() == 3, "la espada legendaria trae 3 engarces")
	sw.socks[0] = "dmgF_3"
	ok(Items.why_equip(p, sw, "sword") == "", "se puede equipar")
	p.eq.sword = sw
	sim.runes.agg(p)
	ok(is_equal_approx(p.st.dmg, dmg0 + 10), "daño con espada y runa (%s → %s)" % [dmg0, p.st.dmg])
	# reglas de engarce
	ok(Items.why_not(p, Items.rune("armorPts_1"), "sword") != "", "una runa de armadura no va en el arma")
	ok(Items.why_not(p, Items.rune("dmgF_3"), "helm") != "", "una runa de arma no va en el casco")
	var other := Items.make_gear(sim.rng, 1, "mage")
	ok(Items.why_equip(p, other) != "", "no se equipa lo de otra clase")
	# mochila: piezas de 2×4 y montones de runas de hasta 20
	ok(Items.add_rune(p, "crit_1", 25) == 0 and p.bag.size() == 2, "runas apiladas en montones de 20")
	var n := 0
	while Items.bag_add(p, Items.make_gear(sim.rng, 0, "dk", "sword")):
		n += 1
	ok(n == 6, "caben 6 espadas con 2 montones dentro (%d)" % n)
	p.bag = []
	# cofres: cada tipo suelta lo suyo
	for kind in ["wood", "iron", "gold", "cursed"]:
		sim.loot = []
		p.keys = 1
		var c := {"cx": 0, "cy": 0, "kind": kind, "room": null, "se": false, "x": p.x, "y": p.y + 20, "open": false, "open_t": 0.0, "best": 0, "guards": [], "msg_t": -9.0}
		sim.chests.append(c)
		sim.try_open_chest(c)
		ok(c.open, "se abre el cofre " + kind)
		var gear := sim.loot.filter(func(l): return l.item.get("gear", false)).size()
		var rn := sim.loot.filter(func(l): return l.item.has("rune")).size()
		var want_g: Array = Sim.CHEST_LOOT[kind].n
		ok(gear >= want_g[0] and gear <= want_g[1], "%s: %d objetos" % [kind, gear])
		ok(rn == {"wood": 1, "iron": 2, "gold": 3, "cursed": 2}[kind], "%s: %d runas" % [kind, rn])
	# el de hierro sin llave no se abre
	p.keys = 0
	var ci := {"cx": 0, "cy": 0, "kind": "iron", "room": null, "se": false, "x": p.x, "y": p.y + 20, "open": false, "open_t": 0.0, "best": 0, "guards": [], "msg_t": -9.0}
	sim.try_open_chest(ci)
	ok(not ci.open, "el de hierro necesita llave")
	# los objetos vuelan y luego se recogen con «usar»
	for i in 60:
		sim._chest_tick(1.0 / 60)
	var l = sim.loot[0]
	p.x = l.x; p.y = l.y
	var before := p.bag.size()
	sim.interact()
	ok(p.bag.size() == before + 1, "recoger con usar")
	# un dorado suelta pieza y runa
	sim.loot = []
	var e := sim.spawn_enemy("knight", p.x + 40, p.y)
	sim.make_rare(e)
	sim.roll_drops(e)
	ok(sim.loot.size() >= 2, "el dorado suelta pieza y runa (%d)" % sim.loot.size())
	# runas de combate: +25 % contra caballeros y veneno
	p.eq.sword.socks = ["vs_knight_3", "poison_3", null]
	sim.runes.agg(p)
	var k := sim.spawn_enemy("knight", p.x + 20, p.y)
	var d := sim.runes.hit(k, 100, "melee", false)
	ok(d == 125, "vs caballeros: 100 → %d" % d)
	ok(k.rn_pois_t > 0, "el golpe envenena")
	# pociones en la mochila
	Items.bag_add(p, Items.potion_item())
	p.hp = 10
	sim.drink_potion()
	ok(Items.potion_count(p) == 0 and p.hp > 10, "beber la poción de la mochila")
	print("test_botin: ", "todo bien" if fails == 0 else "%d fallos" % fails)
	quit(1 if fails else 0)

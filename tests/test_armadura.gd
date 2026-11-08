extends SceneTree
## Autoequipado al recoger y piezas de armadura 3D (provisionales), sin pantalla.
## Uso: godot --headless --path . -s res://tests/test_armadura.gd

var fails := 0

func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
		print("FALLA: ", what)

func _init() -> void:
	var sim := Sim.new()
	sim.rng.seed = 11
	sim.new_game(1, "armadura")
	var L := DungeonGen.gen_level(sim.level_seed(1), 1)
	sim.enter_level(L)
	var p := sim.p
	var k: String = p.cls_key()
	p.bag = []
	# hueco vacío: el casco recogido se pone solo
	p.eq.helm = null
	sim.runes.agg(p)
	var armor0: float = p.st.armorPts
	var casco := Items.make_gear(sim.rng, 2, k, "helm")
	var l := {"x": p.x, "y": p.y, "item": casco, "bob": 0.0, "fly": null}
	sim.loot = [l]
	sim.try_pickup(l)
	ok(p.eq.helm == casco, "el casco se pone solo con el hueco vacío")
	ok(p.bag.is_empty(), "no pasa por la mochila")
	ok(sim.loot.is_empty(), "sale del suelo")
	ok(p.st.armorPts > armor0, "recalcula la armadura (%s → %s)" % [armor0, p.st.armorPts])
	# hueco ocupado: va a la mochila y no cambia lo puesto
	var otro := Items.make_gear(sim.rng, 3, k, "helm")
	var l2 := {"x": p.x, "y": p.y, "item": otro, "bob": 0.0, "fly": null}
	sim.loot = [l2]
	sim.try_pickup(l2)
	ok(p.eq.helm == casco, "con el hueco ocupado no se cambia")
	ok(p.bag.size() == 1 and p.bag[0] == otro, "la pieza nueva va a la mochila")
	# de otra clase: a la mochila aunque el hueco esté vacío
	p.eq.boots = null
	var ajena := Items.make_gear(sim.rng, 1, "mage" if k != "mage" else "knight", "boots")
	var l3 := {"x": p.x, "y": p.y, "item": ajena, "bob": 0.0, "fly": null}
	sim.loot = [l3]
	sim.try_pickup(l3)
	ok(p.eq.boots == null, "no se pone lo de otra clase")
	# Set del Caballero Oscuro: todas las piezas existen, con aura solo si no es básica
	var basica0 := Items.make_gear(sim.rng, 0, "knight", "helm")
	ok(basica0.name == "Yelmo del Caballero Oscuro", "nombre del set (%s)" % basica0.name)
	ok(not Armadura3D.tiene(Items.make_gear(sim.rng, 1, "mage", "boots")), "las otras clases no llevan el set")
	for s in Armadura3D.huecos():
		for d in Armadura3D.PIEZAS[s]:
			ok(ResourceLoader.exists(Armadura3D.CARPETA + d.archivo + ".gltf"), "existe %s" % d.archivo)
			ok(Armadura3D.centro(d.archivo) != Vector3.ZERO, "centro de %s" % d.archivo)
		var bas := Items.make_gear(sim.rng, 0, "knight", s)
		var leg := Items.make_gear(sim.rng, 3, "knight", s)
		ok(Armadura3D.tiene(bas), "%s: se ve con el set" % s)
		var basica := Armadura3D.pieza(Armadura3D.PIEZAS[s][0].archivo, Armadura3D.PIEZAS[s][0].hueso, bas)
		var magica := Armadura3D.pieza(Armadura3D.PIEZAS[s][0].archivo, Armadura3D.PIEZAS[s][0].hueso, leg)
		var mb: Array = basica.find_children("*", "MeshInstance3D", true, false)
		var mm: Array = magica.find_children("*", "MeshInstance3D", true, false)
		ok(mb.size() > 0, "%s: tiene malla" % s)
		ok(mb.all(func(m): return m.material_overlay == null), "%s básica: sin aura" % s)
		ok(mm.all(func(m): return m.material_overlay is ShaderMaterial), "%s legendaria: con aura" % s)
		ok(magica.find_children("*", "CPUParticles3D", true, false).size() == 1, "%s legendaria: con chispas" % s)
		var suelo := Armadura3D.suelta(Items.make_gear(sim.rng, 1, "knight", s))
		ok(suelo != null and suelo.get_child_count() == Armadura3D.PIEZAS[s].size() + 0, "%s: en el suelo, todas sus piezas" % s)
		basica.free()
		magica.free()
		suelo.free()
	for par in [["sword", "RightHand"], ["shield", "LeftHand"]]:
		var a := Armadura3D.arma(Items.make_gear(sim.rng, 2, "knight", par[0]), par[1])
		ok(a != null and a.find_children("*", "MeshInstance3D", true, false).size() > 0, "arma del set: %s" % par[0])
		if a != null:
			a.free()
	Armadura3D.limpiar()
	print("todo bien" if fails == 0 else "%d fallos" % fails)
	quit(1 if fails else 0)

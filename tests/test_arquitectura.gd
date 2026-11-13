extends SceneTree
## Creador de mundos (Arquitectura): papeles de sala, rasgos que no cortan caminos, muros bajos del lado
## de la cámara, tramos de muro compuestos y que la vista monta el piso con muros bajos y suciedad.
## godot --headless --path . -s tests/test_arquitectura.gd

var fallos := 0

func ok(c: bool, que: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", que)

func _init() -> void:
	var GW := DungeonGen.GW
	var rasgos := {}
	var caras := {}
	var pisos := 0
	for w in [1, 2, 4, 6, 7, 10]:
		for s in ["a", "b", "c"]:
			var L := DungeonGen.gen_level("arq-%s-%d" % [s, w], w)
			if L.get("plataformas", false):
				continue
			pisos += 1
			ok(L.has("arq") and L.has("papeles"), "piso %d%s con arquitectura" % [w, s])
			ok(L.papeles.size() == L.rooms.size(), "un papel por sala")
			var G: PackedByteArray = L.grid
			var d := Arquitectura.bfs(G, int(L.start.cx), int(L.start.cy))
			# lo importante sigue al alcance: escalera, cofres y el centro de cada sala que lo era
			ok(d[int(L.stairs_cell.cy) * GW + int(L.stairs_cell.cx)] >= 0, "escalera alcanzable (%d%s)" % [w, s])
			for c in L.chests:
				if c.has("cx"):
					var libre := false
					for dd in [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]]:
						var i: int = (int(c.cy) + dd[1]) * GW + int(c.cx) + dd[0]
						libre = libre or d[i] >= 0
					ok(libre, "cofre alcanzable (%d%s)" % [w, s])
			# los muros altos nunca tienen algo pisable al norte, al oeste ni al noroeste (no tapan nada)
			var b: PackedByteArray = L.arq.bajo
			var malos := 0
			for y in range(1, DungeonGen.GH - 1):
				for x in range(1, GW - 1):
					if G[y * GW + x] != DungeonGen.ROCK or b[y * GW + x]:
						continue
					for v in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, -1)]:
						var t := G[(y + v.y) * GW + x + v.x]
						if t != DungeonGen.ROCK and t != DungeonGen.ABISMO:
							malos += 1
			ok(malos == 0, "ningún muro alto tapa suelo (%d)" % malos)
			for k in L.rasgos:
				for r in L.rasgos[k]:
					rasgos[r] = true
			for v in L.arq.caras.values():
				caras[v] = true
			# siempre igual con la misma semilla
			var L2 := DungeonGen.gen_level("arq-%s-%d" % [s, w], w)
			ok(L2.grid == G and L2.arq.caras == L.arq.caras, "misma semilla, mismo piso")
	ok(pisos >= 12, "pisos probados %d" % pisos)
	for r in ["columnata", "estanques", "chaflan"]:
		ok(rasgos.has(r), "sale algún rasgo «%s»" % r)
	ok(caras.size() >= 6, "variedad de caras en los tramos: " + str(caras.keys()))
	# la vista: muros bajos en su GridMap, ninguna antorcha en un muro bajo y suciedad puesta
	var m := MazmorraGridMap.new()
	root.add_child(m)
	if m.muros == null:
		m._ready()   # en _init el árbol aún no ha llamado a _ready
	var L := DungeonGen.gen_level("arq-vista", 2)
	m.construir(L)
	ok(m.muros_b.get_used_cells().size() > 50, "muros bajos montados (%d)" % m.muros_b.get_used_cells().size())
	ok(m.muros.get_used_cells().size() > 50, "muros altos montados")
	ok(m.adornos.get_node_or_null("Suciedad") != null and m.adornos.get_node("Suciedad").get_child_count() > 30, "calcomanías de suciedad")
	var cajas := 0
	for c in Amueblado3D.casillas(L):
		cajas += 1 if m.objetos.get_cell_item(Vector3i(c.x, 0, c.y)) == KitMazmorra.id("mueble") else 0
	ok(Amueblado3D.casillas(L).size() > 0 and cajas == 0, "muebles con piezas 3D, sin cajas (%d cajas)" % cajas)
	ok(m.fuegos.size() > 0, "luces de fuego que pueden dar sombra")
	m.sombras_cerca(MazmorraGridMap.centro(Vector2i(int(L.start.cx), int(L.start.cy))), 1.0)
	var con := 0
	for l in m.fuegos:
		con += 1 if l.shadow_enabled else 0
	ok(con > 0 and con <= Opciones.SOMBRAS_A_LA_VEZ, "sombras solo en las antorchas cercanas (%d)" % con)
	m.free()
	KitMazmorra.limpiar()
	Suciedad3D.limpiar()
	Amueblado3D.limpiar()
	Props3D.limpiar()
	print("todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit()

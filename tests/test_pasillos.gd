extends SceneTree
## Pasillos (9 nov): anchos de 1, 2 y 3 casillas y algunos en zigzag. Todos los pisos se generan,
## la escalera se alcanza desde el inicio y hay galerías anchas (3×3 de pasillo seguido).
## godot --headless --path . -s tests/test_pasillos.gd

var fallos := 0

func ok(c: bool, que: String) -> void:
	if not c:
		fallos += 1
		print("FALLO ", que)

func _init() -> void:
	var W := DungeonGen.GW
	var anchas := 0
	var estrechas := 0
	var pisos := 0
	for s in 20:
		for piso in [1, 2, 3, 4, 6, 8]:
			var L := DungeonGen.gen_level("pas%d" % s, piso)
			if L.is_empty() or not L.has("corr"):
				ok(L.size() > 0, "se genera el piso %d (pas%d)" % [piso, s])
				continue
			pisos += 1
			var d: PackedInt32Array = L.dist
			var st: Dictionary = L.stairs_cell
			ok(d[st.cy * W + st.cx] >= 0, "la escalera se alcanza (pas%d, piso %d)" % [s, piso])
			var corr: PackedByteArray = L.corr
			var sala: PackedInt32Array = L.room_of
			for cy in range(1, DungeonGen.GH - 3):
				for cx in range(1, W - 3):
					var todo := true
					for j in 3:
						for i in 3:
							var k := (cy + j) * W + cx + i
							if corr[k] == 0 or sala[k] >= 0:
								todo = false
					if todo:
						anchas += 1
					# estrecha: pasillo con roca a los dos lados (este y oeste, o norte y sur)
					var k0 := cy * W + cx
					if corr[k0] != 0 and sala[k0] < 0:
						var G: PackedByteArray = L.grid
						if (G[k0 - 1] == DungeonGen.ROCK and G[k0 + 1] == DungeonGen.ROCK) or (G[k0 - W] == DungeonGen.ROCK and G[k0 + W] == DungeonGen.ROCK):
							estrechas += 1
	ok(pisos >= 100, "pisos generados (%d)" % pisos)
	ok(anchas > 0, "hay galerías de 3 casillas (%d bloques)" % anchas)
	ok(estrechas > 0, "quedan pasillos estrechos (%d casillas)" % estrechas)
	print("pisos %d · bloques anchos %d · casillas estrechas %d" % [pisos, anchas, estrechas])
	print("todo bien" if fallos == 0 else "%d fallos" % fallos)
	quit()

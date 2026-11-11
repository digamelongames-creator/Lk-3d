extends SceneTree
## Pone al día las medidas y los triángulos de assets/props/catalogo.json (lo demás de cada ficha se escribe a mano).
## godot --headless --path . -s tools/catalogo.gd
func _init():
	var ruta := "res://assets/props/catalogo.json"
	var cat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ruta)) if FileAccess.file_exists(ruta) else {}
	for id in cat:
		var p: PackedStringArray = String(id).split("/")
		var m := Props3D.malla(p[0], p[1])
		if m == null:
			print("FALTA ", id)
			continue
		var t := 0
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			t += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arr[Mesh.ARRAY_INDEX] != null else 0
		var a := m.get_aabb()
		cat[id]["medidas"] = [snappedf(a.size.x, .01), snappedf(a.size.y, .01), snappedf(a.size.z, .01)]
		cat[id]["triangulos"] = t
	var lineas := ["{"]
	var ids := cat.keys()
	ids.sort()
	for i in ids.size():
		lineas.append('\t"%s": %s%s' % [ids[i], JSON.stringify(cat[ids[i]]), "," if i < ids.size() - 1 else ""])
	lineas.append("}")
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	f.store_string("\n".join(lineas) + "\n")
	f.close()
	Props3D.limpiar()
	print("catálogo: ", ids.size(), " piezas")
	quit()

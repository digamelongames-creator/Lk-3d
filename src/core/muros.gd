class_name Muros
## Lo que la simulación necesita de los muros del piso sin pasar por el arte (servidor sin imágenes, pruebas):
## alto de la cara de cada muro, reparto del ornato (Ornato), antorchas a su altura y llaveros colgados.
## LevelArt pinta con lo mismo, así que el juego con arte y sin él ve el mismo piso.

const TS := DungeonGen.TS
const TALL := 64
const MID := 46
const SHORT := 24

## alto (px) de la cara del muro norte por casilla, con el mínimo de cada tramo (0 si no hay cara).
## En el nivel B del mapa de pruebas la cara de ladrillo mide una casilla.
static func alto_caras(L: Dictionary) -> PackedInt32Array:
	var GW := DungeonGen.GW
	var GH := DungeonGen.GH
	var G: PackedByteArray = L.grid
	var rock := func(x: int, y: int) -> bool:
		return x < 0 or y < 0 or x >= GW or y >= GH or G[y * GW + x] == 0
	var fh := PackedInt32Array(); fh.resize(DungeonGen.N)
	for y in GH:
		for x in GW:
			if rock.call(x, y) and not rock.call(x, y + 1):
				fh[y * GW + x] = (TALL if rock.call(x, y - 2) else MID) if rock.call(x, y - 1) else SHORT
	for y in GH:
		var x := 0
		while x < GW:
			if not fh[y * GW + x]:
				x += 1
				continue
			var s := x
			var m := 99
			while x < GW and fh[y * GW + x]:
				m = mini(m, fh[y * GW + x])
				x += 1
			for k in range(s, x):
				fh[y * GW + k] = m
	if String(L.get("estilo", "")) == "b":
		for cy in GH:
			for cx in GW:
				if G[cy * GW + cx] != 0 or (rock.call(cx, cy) and rock.call(cx, cy + 1)):
					continue
				var abajo: int = G[(cy + 1) * GW + cx] if cy + 1 < GH else 0
				if abajo != 0 and abajo != DungeonGen.ABISMO:
					fh[cy * GW + cx] = TS
	return fh

## reparte el ornato y apunta en L las antorchas a la altura de su cara (torches_px) y los llaveros (keyrings).
## Determinista y una sola vez por piso: lo llaman LevelArt.build y Sim.enter_level, el primero que llegue.
static func preparar(L: Dictionary) -> void:
	if L.has("torches_px"):
		return
	var fh := alto_caras(L)
	Ornato.prep(L, fh)
	var fh_at := func(cx: int, cy: int) -> int:
		var v := fh[cy * DungeonGen.GW + cx] if (cx >= 0 and cy >= 0 and cx < DungeonGen.GW and cy < DungeonGen.GH) else 0
		return v if v else SHORT
	var torches := []
	for tr in L.torches:
		var h: int = fh_at.call(tr.cx, tr.cy - 1)
		var t2: Dictionary = tr.duplicate()
		t2.y = tr.cy * TS - h + JS.roundi(h * .32)
		torches.append(t2)
	L["torches_px"] = torches
	var dm := GameData.deco_meta()
	var keyrings := []
	for w in L.wall_deco:
		if w.get("tp") != null or w.get("n") != "keyring_hanging" or dm.get(w.n) == null:
			continue
		var h: int = fh_at.call(w.cx, w.cy - 1)
		var ft: int = w.cy * TS - h
		var m: Array = dm[w.n]
		keyrings.append({"cx": w.cx, "cy": w.cy, "x": (w.cx + .5) * TS, "top": ft + maxi(1, JS.roundi((h - m[3]) * .35)), "ft": ft, "h": h})
	L["keyrings"] = keyrings

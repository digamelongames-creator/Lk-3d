class_name Ornato
## Reparto del ornato de los pisos 1–5 (ornPrep del juego web): columnas en las esquinas y entradas,
## galería de cuadros, tramos de pared con arcadas, hornacinas o relieves y sus antorchas.
## Cambia el mapa (quita muebles junto a las columnas, añade antorchas): es simulación, va antes de jugar.
## No carga imágenes: los tamaños de los cuadros y relieves salen de OrnatoMedidas. El pintado es Ornament.

const TS := DungeonGen.TS
const MAXWAVE := 5
const PAL := {
	"castle": {"O": "#151110", "D": "#443d37", "M": "#625a51", "L": "#81776a", "H": "#a09684", "HH": "#bbb09d", "DK": "#2a2420", "marble": [[23, 20, 26], [30, 26, 33], [17, 15, 20]], "stone": "piedra"},
	"crypt": {"O": "#11120b", "D": "#3d3e30", "M": "#595b4a", "L": "#777a65", "H": "#959880", "HH": "#b1b49a", "DK": "#26271c", "marble": [[21, 23, 19], [28, 31, 25], [15, 17, 13]], "stone": "cripta"},
}
const ORDER := ["velo", "medusa", "baco", "melena", "fauno", "aguila"]
const HALLS := {
	"arcade": {"kind": "arcade", "bay": 3, "marble": true, "size": "N", "mats": ["stone"], "pat": "RRT", "min": 6},
	"bare": {"kind": "bare", "step": 3, "size": "N", "mats": ["stone"], "pat": "TR", "min": 6},
	"niche": {"kind": "niche", "bay": 4, "size": "N", "mats": ["bronce", "hueso"], "min": 8},
	"grand": {"kind": "arcade", "bay": 4, "marble": true, "size": "G", "mats": ["hueso"], "sym": ["medusa", "velo", "aguila", "melena", "fauno"], "min": 9},
}

static func is_on(L: Dictionary) -> bool:
	return L.get("wave") != null and int(L.wave) <= MAXWAVE and PAL.has(L.theme) and not L.get("plataformas", false)

static func rel(key: String, mat: String, size: String, L: Dictionary) -> Variant:
	var m: String = (PAL.get(L.theme, PAL.castle)).stone if mat == "stone" else mat
	return medida("orn_rel_" + key + "_" + m + "_" + size)

## {n, w, h} de una imagen del ornato (null si no existe)
static func medida(name: String) -> Variant:
	var m = OrnatoMedidas.T.get(name)
	return {"n": name, "w": int(m[0]), "h": int(m[1])} if m != null else null

static func is_key(w: Dictionary) -> bool:
	return w.get("n", "") == "keyring_hanging"

# ======================================================================
#  reparto
# ======================================================================
static func prep(L: Dictionary, face_h: PackedInt32Array) -> void:
	if not is_on(L) or L.has("orn"):
		return
	L["orn"] = {"pal": PAL[L.theme], "cols": [], "rel_cols": [], "arches": [], "niches": [], "items": [], "lights": [], "gallery": [], "halls": [], "vein_px": []}
	var R := Mulberry32.new(JS.hash_str(L.seed + "|orn"))
	_gallery(L, face_h)
	_corners(L, face_h)
	_halls(L, R, face_h)

static func _gallery(L: Dictionary, fh: PackedInt32Array) -> void:
	var best := []
	var y := 0
	var room := -1
	var G: PackedByteArray = L.grid
	for k in L.rooms.size():
		var r: Dictionary = L.rooms[k]
		if k == L.end_room or (L.fount != null and L.fount.room == k):
			continue
		var yy: int = r.y
		var has_key := false
		for w in L.wall_deco:
			if is_key(w) and w.cy == yy and w.cx >= r.x and w.cx < r.x + r.w:
				has_key = true
		if has_key:
			continue
		if fh[(yy - 1) * DungeonGen.GW + r.x + (r.w >> 1)] < 46:
			continue
		var cur := []
		for x in range(r.x, r.x + r.w + 1):
			var ok := false
			if x < r.x + r.w:
				var t := G[yy * DungeonGen.GW + x]
				ok = G[(yy - 1) * DungeonGen.GW + x] == 0 and t != 0 and t != 2 and t != 9 and t != DungeonGen.DOOR
			if ok:
				cur.append(x)
			else:
				if cur.size() > best.size():
					best = cur
					y = yy
					room = k
				cur = []
	if best.size() < 7:
		return
	var x0: int = best[0]
	var x1: int = best[best.size() - 1] + 1
	var hh: int = fh[(y - 1) * DungeonGen.GW + ((x0 + x1) >> 1)]
	var h: int = hh if hh else 46
	var Sz := "T" if h >= 60 else "M"
	var order := ["duelo", "saturno", "aquelarre"]
	var W0 := x0 * TS + 22
	var W1 := x1 * TS - 22
	var out = null
	for S2 in (["T", "M"] if Sz == "T" else ["M"]):
		var ws := []
		var sum := 0
		for k2 in order:
			var w: int = medida("orn_gal_" + k2 + "_" + S2).w + 6
			ws.append(w)
			sum += w
		var free := (W1 - W0) - sum
		if free < (48 if S2 == "T" else 24):
			continue
		var gap := free / 4.0
		var x := W0 + gap
		out = []
		for i in 3:
			out.append({"k": order[i], "cx": x + ws[i] / 2.0, "w": ws[i], "S": S2})
			x += ws[i] + gap
		break
	if out == null:
		return
	var keep := []
	for o in L.decor:
		if o.cy == y and o.cx >= x0 and o.cx < x1 and not L.key_tables.has(o):
			G[o.cy * DungeonGen.GW + o.cx] = DungeonGen.FLOOR
		else:
			keep.append(o)
	L.decor = keep
	L.wall_deco = L.wall_deco.filter(func(w): return not (w.cy == y and w.cx >= x0 and w.cx < x1))
	L.wall_veg = L.wall_veg.filter(func(w): return not (w.cy == y and w.cx >= x0 and w.cx < x1))
	var on_wall := func(t): return t.cy == y and t.cx >= x0 and t.cx < x1
	var tpl = null
	for t in L.torches:
		if on_wall.call(t):
			tpl = t
			break
	if tpl == null and L.torches.size():
		tpl = L.torches[0]
	L.torches = L.torches.filter(func(t): return not on_wall.call(t))
	var gal := []
	for o in out:
		var g: Dictionary = o.duplicate()
		g["cy"] = y
		g["h"] = h
		gal.append(g)
	L.orn.gallery = gal
	L.orn["gal_row"] = {"y": y, "x0": x0, "x1": x1}
	L["gal_room"] = room
	if tpl != null:
		for i in range(1, 3):
			var a: float = out[i - 1].cx + out[i - 1].w / 2.0
			var b: float = out[i].cx - out[i].w / 2.0
			if b - a < 18:
				continue
			var x := JS.roundi((a + b) / 2)
			var t2: Dictionary = tpl.duplicate()
			t2.x = x
			t2.cx = int(floorf(x / float(TS)))
			t2.cy = y
			L.torches.append(t2)

static func _corners(L: Dictionary, fh: PackedInt32Array) -> void:
	var G: PackedByteArray = L.grid
	var is_f := func(i: int) -> bool:
		var t := G[i]
		return t != 0 and t != 2 and t != 9
	var busy := []
	for c in L.chests:
		busy.append([(c.cx + .5) * TS, (c.cy + .5) * TS])
	busy.append([L.stairs_px.x, L.stairs_px.y])
	for w in L.wall_deco:
		if is_key(w):
			busy.append([(w.cx + .5) * TS, w.cy * TS])
	var ends := []
	var par := []      # unión de conjuntos por índice de extremo
	var by_row := {}
	var run_list := []
	var find := func(e: int) -> int:
		while par[e] != e:
			e = par[e]
		return e
	var join := func(p: int, q: int) -> void:
		par[find.call(p)] = find.call(q)
	for y in range(1, DungeonGen.GH - 1):
		var x := 0
		while x < DungeonGen.GW:
			var ok: bool = is_f.call(y * DungeonGen.GW + x) and G[y * DungeonGen.GW + x] != DungeonGen.DOOR and G[(y - 1) * DungeonGen.GW + x] == 0
			if not ok:
				x += 1
				continue
			var a := x
			while x < DungeonGen.GW and is_f.call(y * DungeonGen.GW + x) and G[y * DungeonGen.GW + x] != DungeonGen.DOOR and G[(y - 1) * DungeonGen.GW + x] == 0:
				x += 1
			var b := x - 1
			var ln := b - a + 1
			var mk := func(cx: int, e: float, side: int) -> int:
				var hv: int = fh[(y - 1) * DungeonGen.GW + cx]
				var h := hv if hv else 46
				var pxx := e + side * 9
				var why := ""
				if ln < 2:
					why = "len"
				elif h < 64:
					why = "h"
				else:
					for bb in busy:
						if absf(pxx - bb[0]) < 26 and absf(y * TS - bb[1]) < 26:
							why = "busy"
							break
				var o := {"cx": cx, "e": e, "side": side, "cy": y, "h": h, "x": pxx, "ok": why == "", "id": ends.size(), "top": 0}
				ends.append(o)
				par.append(o.id)
				return o.id
			var l0: int = mk.call(a, a * TS, 1)
			var r0: int = mk.call(b, (b + 1) * TS, -1)
			join.call(l0, r0)
			if not by_row.has(y):
				by_row[y] = []
			by_row[y].append([a, b, l0, r0])
			run_list.append({"a": a, "b": b, "y": y, "L0": l0, "R0": r0})
	var rows := by_row.keys()
	rows.sort()
	for y in rows:
		var rs: Array = JS.stable_sort(by_row[y], func(p, q): return p[0] - q[0])
		for i in range(1, rs.size()):
			var gap: int = rs[i][0] - rs[i - 1][1] - 1
			if gap >= 1 and gap <= 3:
				join.call(rs[i - 1][3], rs[i][2])
	var bad := {}
	for e in ends:
		if not e.ok:
			bad[find.call(e.id)] = true
	var gid := {}
	var cols := []
	for e in ends:
		var root: int = find.call(e.id)
		if not gid.has(root):
			gid[root] = gid.size()
		e["grp"] = gid[root]
		if not bad.has(root):
			cols.append(e)
	var G2: PackedByteArray = L.grid
	for c in cols:
		L.wall_deco = L.wall_deco.filter(func(w): return is_key(w) or not (w.cy == c.cy and absf((w.cx + .5) * TS - c.x) < 24))
		L.wall_veg = L.wall_veg.filter(func(w): return not (w.cy == c.cy and absf((w.cx + .5) * TS - c.x) < 20))
		for t in L.torches:
			if t.cy == c.cy and absf(t.x - c.x) < 22:
				t.x = c.x + (22 if t.x >= c.x else -22)
				t.cx = int(floorf(t.x / TS))
		var keep := []
		for o in L.decor:
			if o.cy == c.cy and o.cx == c.cx and not L.key_tables.has(o):
				G2[o.cy * DungeonGen.GW + o.cx] = DungeonGen.FLOOR
			else:
				keep.append(o)
		L.decor = keep
	L.orn.cols = cols
	L.orn["ends"] = ends
	L.orn["runs"] = run_list

static func _halls(L: Dictionary, R: Mulberry32, fh: PackedInt32Array) -> void:
	var G: PackedByteArray = L.grid
	var col_ids := {}
	for c in L.orn.cols:
		col_ids[c.id] = true
	var gr = L.orn.get("gal_row")
	var busy := []
	for c in L.chests:
		busy.append([(c.cx + .5) * TS, (c.cy + .5) * TS])
	busy.append([L.stairs_px.x, L.stairs_px.y])
	var cand := []
	for r in L.orn.runs:
		var ln: int = r.b - r.a + 1
		if ln < 6: continue
		if not col_ids.has(r.L0) or not col_ids.has(r.R0): continue
		if fh[(r.y - 1) * DungeonGen.GW + r.a] < 64: continue
		if gr != null and gr.y == r.y and r.a < gr.x1 and r.b >= gr.x0: continue
		var has_key := false
		for w in L.wall_deco:
			if is_key(w) and w.cy == r.y and w.cx >= r.a - 1 and w.cx <= r.b + 1:
				has_key = true
		if has_key: continue
		var door := false
		for x in range(r.a - 1, r.b + 2):
			for dy in range(-1, 2):
				if G[(r.y + dy) * DungeonGen.GW + x] == DungeonGen.DOOR:
					door = true
		if door: continue
		var bz := false
		for bb in busy:
			if bb[0] > r.a * TS - 24 and bb[0] < (r.b + 1) * TS + 24 and bb[1] > r.y * TS - 40 and bb[1] < r.y * TS + 50:
				bz = true
		if bz: continue
		r["corr"] = L.corr[r.y * DungeonGen.GW + r.a] != 0 and L.room_of[r.y * DungeonGen.GW + r.a] < 0
		if r.corr or ln >= 8:
			cand.append(r)
	cand = JS.v8_sort(cand, func(p, q):
		var c := (1 if q.corr else 0) - (1 if p.corr else 0)
		if c != 0: return c
		var d: int = (q.b - q.a) - (p.b - p.a)
		if d != 0: return d
		return R.next() - .5)
	var want := 1 + (1 if R.next() < .55 else 0)
	var picked := []
	var kinds := HALLS.keys()
	var last_kind := ""
	for r in cand:
		if picked.size() >= want:
			break
		var near := false
		for p in picked:
			if absi(p.y - r.y) < 4 and r.a <= p.b + 4 and r.b >= p.a - 4:
				near = true
		if near:
			continue
		var ln: int = r.b - r.a + 1
		var ok := []
		for k in kinds:
			if HALLS[k].min <= ln and k != last_kind:
				ok.append(k)
		if not ok.size():
			continue
		var k: String = ok[int(floorf(R.next() * ok.size()))]
		last_kind = k
		var r2: Dictionary = r.duplicate()
		r2["kind"] = k
		picked.append(r2)
	for r in picked:
		_hall(L, r, HALLS[r.kind], fh)

static func _hall(L: Dictionary, r: Dictionary, H: Dictionary, fh: PackedInt32Array) -> void:
	var O: Dictionary = L.orn
	var y: int = r.y
	var A: int = r.a * TS
	var B: int = (r.b + 1) * TS
	var hv: int = fh[(y - 1) * DungeonGen.GW + r.a]
	var h: int = hv if hv else 64
	var FT := y * TS - h
	var FB := y * TS
	O.halls.append({"a": r.a, "b": r.b, "y": y, "kind": r.kind})
	var in_r := func(o): return o.cy == y and o.cx >= r.a and o.cx <= r.b
	L.torches = L.torches.filter(func(t): return not in_r.call(t))
	L.wall_deco = L.wall_deco.filter(func(w): return is_key(w) or not in_r.call(w))
	L.wall_veg = L.wall_veg.filter(func(w): return not in_r.call(w))
	var mats: Array = H.mats
	var st := {"mi": 0, "ri": int(floorf(JS.hash_str(L.seed + str(y)) % 6))}
	var next_mat := func() -> String:
		var m: String = mats[st.mi % mats.size()]
		st.mi += 1
		return m
	var stone: String = (PAL.get(L.theme, PAL.castle)).stone
	var add_rel := func(key: String, cx: float, top: float, size: String, mat: String) -> void:
		var im = rel(key, mat, size, L)
		if im == null or not im.w:
			return
		O.items.append({"n": im.n, "x": JS.roundi(cx - im.w / 2.0), "y": JS.roundi(top), "w": im.w, "h": im.h})
		O.lights.append({"x": cx, "y": top + im.h / 2.0})
	var torch := func(x: float) -> void:
		L.torches.append({"cx": int(floorf(x / TS)), "cy": y, "x": JS.round(x), "y": 0, "orn": true})
	if H.kind == "arcade" or H.kind == "niche":
		var n := maxi(1, JS.roundi((B - A) / float(H.bay * TS)))
		var cs := []
		for i in n + 1:
			cs.append(A + (B - A) * i / float(n))
		var spring: int = FT + (24 if H.size == "G" else 20) if H.kind == "arcade" else FT
		if spring > FT:
			var gs := {O.ends[r.L0].grp: true, O.ends[r.R0].grp: true}
			for c in O.cols:
				if gs.has(c.grp):
					c.top = maxi(c.top, spring - FT)
		for i in range(1, n):
			O.rel_cols.append({"e": JS.roundi(cs[i]) - 9, "side": 1, "top": spring, "bot": FB, "cy": y})
		var bays := []
		for i in n:
			var c1: float = A + 9 if i == 0 else cs[i]
			var c2: float = B - 9 if i == n - 1 else cs[i + 1]
			bays.append([c1, c2])
		var seq = null
		if H.has("sym"):
			seq = []
			for i in n:
				seq.append(H.sym[mini(i, n - 1 - i) % H.sym.size()])
		for i in n:
			var c1: float = bays[i][0]
			var c2: float = bays[i][1]
			var mx := (c1 + c2) / 2
			if H.kind == "arcade":
				var rxi := (c2 - c1) / 2 - 9
				var ryi := minf(18, spring - FT - 4)
				O.arches.append({"cx": mx, "sy": spring, "rxi": rxi, "ryi": ryi, "marble": H.marble, "bot": FB - 6})
				var slot: String = H.pat[i % H.pat.length()] if H.has("pat") else "R"
				if slot == "T" and not H.has("sym"):
					if not H.marble:
						torch.call(mx)
				else:
					var key: String
					if seq != null:
						key = seq[i]
					else:
						key = ORDER[st.ri % ORDER.size()]
						st.ri += 1
					var mat: String = mats[0] if H.has("sym") else next_mat.call()
					var im = rel(key, mat, H.size, L)
					var hh: float = im.h if im != null else 36.0
					var ww: float = im.w if im != null else 28.0
					var q := minf(1, (ww / 2 + 2) / rxi)
					var lim := spring - ryi * sqrt(1 - q * q) + 2
					var lo := FB - 8
					add_rel.call(key, mx, JS.round(maxf(lim, minf(lo - hh, (lim + lo) / 2 - hh / 2))), H.size, mat)
			else:
				var nw := 36
				var top := FT + 8
				var bot := FB - 7
				O.niches.append({"cx": mx, "w": nw, "top": top, "bot": bot})
				var key: String = ORDER[st.ri % ORDER.size()]
				st.ri += 1
				var mat: String = next_mat.call()
				var im = rel(key, mat, "N", L)
				add_rel.call(key, mx, JS.round(bot - 3 - (im.h if im != null else 36)), "N", mat)
				if i < n - 1:
					O.lights.append({"x": cs[i + 1], "y": FT + 30, "weak": true})
	else:
		var n := maxi(2, JS.roundi((B - A - 64) / float(H.step * TS)))
		var s0 := A + 32
		for i in n + 1:
			var x := s0 + (B - A - 64) * i / float(n)
			var slot: String = H.pat[i % H.pat.length()]
			if slot == "T":
				torch.call(x)
			else:
				var key: String = ORDER[st.ri % ORDER.size()]
				st.ri += 1
				var im = rel(key, "stone", "N", L)
				var hh: float = im.h if im != null else 36.0
				add_rel.call(key, x, JS.round(FT + (h - hh) / 2 - 2), "N", "stone")

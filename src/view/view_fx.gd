class_name ViewFx
extends SimFx
## La parte visible de la simulación: partículas, sangre en el suelo, textos flotantes, temblor y carteles.
## Copia el comportamiento de S.parts, S.texts, stain(), pool(), bloodPool() y stampCorpse() del juego web.

var sim: Sim
var blood   # en 3D no hay capa de sangre 2D
var sonidos
var parts: Array = []
var texts: Array = []
var shake_v := 0.0
var banner_top := ""
var banner_main := ""
var banner_t := 0.0
var hud_dirty := true
var rng := RandomNumberGenerator.new()

const BLOOD := ["#8e1a14", "#a8231a", "#6a120e", "#7d160f"]
static var _col_cache := {}

func _init() -> void:
	rng.randomize()

func rnd() -> float:
	return rng.randf()

static func col(h: String) -> Color:
	if not _col_cache.has(h):
		_col_cache[h] = Color(h)
	return _col_cache[h]

func reset() -> void:
	parts.clear()
	texts.clear()
	shake_v = 0

# ---------------- lo que pide la simulación ----------------
func burst(x: float, y: float, z: float, cols: Array, n: int, spd: float) -> void:
	for i in n:
		var a := rnd() * 6.283
		var v := spd * (.4 + rnd())
		parts.append({"x": x, "y": y, "z": z, "vx": cos(a) * v, "vy": sin(a) * v * .6, "vz": 40 + rnd() * 60, "life": .3 + rnd() * .3, "col": cols[i % cols.size()], "float": false, "blood": false})

func bleed(x: float, y: float, z: float, ang: float, n: int, spd: float, spread: float = .9) -> void:
	for i in n:
		var a := ang + (rnd() - .5) * spread * 2
		var v := spd * (.35 + rnd())
		parts.append({"x": x, "y": y, "z": z, "vx": cos(a) * v, "vy": sin(a) * v * .7, "vz": 20 + rnd() * 100, "life": 2.0, "col": BLOOD[i % 4], "blood": true, "float": false})

func part(q: Dictionary) -> void:
	if not q.has("blood"): q["blood"] = false
	if not q.has("float"): q["float"] = false
	parts.append(q)

func text(x: float, y: float, txt: String, c: String, size: float = 10, crit: bool = false, life: float = .8, slow: bool = false, jitter: bool = true) -> void:
	texts.append({"x": x + ((rnd() - .5) * 8 if jitter else 0.0), "y": y, "txt": txt, "col": c, "size": size, "crit": crit, "life": life, "max": life, "slow": slow})

func banner(top: String, main: String) -> void:
	banner_top = top
	banner_main = main
	banner_t = 1.6

func shake(v: float) -> void:
	shake_v = maxf(shake_v, v)

func hud() -> void:
	hud_dirty = true

func sonido(id: StringName, x: float, y: float) -> void:
	if sonidos != null:
		sonidos.tocar(id, x, y)

func blood_suck(x: float, y: float, r: float) -> void:
	blood.clear_ellipse(x, y, r * .7, r * .42)

## mancha en el suelo (stain): no cae en el agua; en la roca solo junto a un hueco, y a veces gotea por la cara del muro
func stain(x: float, y: float, c: String, sz: int = 1) -> void:
	var scx := int(floorf(x / Sim.TS))
	var scy := int(floorf(y / Sim.TS))
	var tt := sim.tile_at(scx, scy)
	if tt == 2:
		return
	var cc := col(c)
	if tt == 0:
		if sim.tile_at(scx, scy + 1) == 0 and sim.tile_at(scx, scy - 1) == 0 and sim.tile_at(scx - 1, scy) == 0 and sim.tile_at(scx + 1, scy) == 0:
			return
		if rnd() < .2:
			blood.rect(int(x), int(y) + sz, 1, 2 + int(rnd() * 6), cc)
	if JS.hypot(x - sim.CX, y - sim.CY) < Sim.FRAD:
		return
	blood.rect(int(x), int(y), sz, sz, cc)
	sim.bm_mark(int(x), int(y))

func pool(x: float, y: float, r: float) -> void:
	var n := int(r * r * 2.2)
	for i in n:
		var a := rnd() * 6.283
		var d := sqrt(rnd()) * r
		stain(x + cos(a) * d, y + sin(a) * d * .55, BLOOD[i % 4], 2 if rnd() < .4 else 1)

## charco que se extiende bajo un cuerpo caído: borde irregular, centro más oscuro
func blood_pool(o, R: float) -> void:
	if not o.pool_seed:
		o.pool_seed = 1 + rnd() * 6
	var s: float = o.pool_seed
	var cx: float = o.x
	var cy: float = o.y - 2
	var ry := .55
	var c_edge := col("#8e1a14"); var c_a := col("#7d160f"); var c_in := col("#420a07"); var c_mid := col("#560d0a")
	for y in range(int(floorf(-R * ry)) - 2, int(R * ry + 2) + 1):
		for x in range(int(floorf(-R * 1.3)) - 1, int(R * 1.3 + 1) + 1):
			var a := atan2(y / ry, x)
			var d := JS.hypot(x, y / ry)
			var rr := R * (1 + .17 * sin(3 * a + s) + .1 * sin(5 * a + s * 2.3))
			if d > rr:
				continue
			var wx := int(floorf(cx + x))
			var wy := int(floorf(cy + y))
			var tt := sim.tile_at(int(floorf(wx / float(Sim.TS))), int(floorf(wy / float(Sim.TS))))
			if tt == 0 or tt == 2:
				continue
			var h := ((wx * 73856093) ^ (wy * 19349663)) & 0xFFFFFFFF
			blood.rect(wx, wy, 1, 1, c_edge if d > rr - 1.3 else (c_a if h % 9 == 0 else (c_in if d < rr * .55 else c_mid)))
			sim.bm_mark(wx, wy)
	if R > 10:
		var c := col("#9a2a22")
		blood.rect(floorf(cx - R * .35), floorf(cy - R * ry * .4), 3, 1, c)
		blood.rect(floorf(cx - R * .2), floorf(cy - R * ry * .4) + 1, 2, 1, c)

## cadáver: el último fotograma de «morir», oscurecido, y algún hueso al lado
func corpse(c) -> void:
	var dir := Atlas.kdir(c.face)
	var mn: String = c.get("mon", "")
	if mn != "":
		# monstruo: último fotograma de su muerte, oscurecido (también se puede alzar)
		var M: Dictionary = GameData.get_table("monsters")[mn]
		if not M.n.has("die"):
			return
		var md: Array = Atlas.mon_dir(M, dir)
		var mf = M.meta.get("die_" + md[0] + "_" + str(int(M.n.die) - 1))
		if mf == null:
			return
		var K: float = M.K
		var w: float = mf[2] * K
		var hh: float = mf[3] * K
		var x0: float = JS.round(c.x - mf[4] * K)
		var r := Rect2(x0, JS.round(c.y - mf[5] * K), w, hh)
		c["rect"] = r
		if md[1]:
			r = Rect2(JS.round(2 * c.x - x0), r.position.y, -w, hh)
		blood.tex(Atlas.mon_sheet(mn), r, Rect2(mf[0] * Atlas.mon_src_k(M), mf[1] * Atlas.mon_src_k(M), mf[2] * Atlas.mon_src_k(M), mf[3] * Atlas.mon_src_k(M)), Color(.5, .45, .45))
		return
	var h: String = c.get("hero", "")
	if h != "":
		# renegado: su propio cuerpo, oscurecido (también se puede alzar)
		var T: Dictionary = Atlas.alt[h]
		var hf = T.meta.get("die_" + str(dir) + "_" + str(int(T.count.get("die", 1)) - 1))
		if hf != null:
			var hd := Rect2(c.x - hf[4] * .5, c.y - hf[5] * .5, hf[2] * .5, hf[3] * .5)
			c["rect"] = hd
			blood.tex(T.tex, hd, Rect2(hf[0], hf[1], hf[2], hf[3]), Color(.42, .4, .4))
		return
	var n := Atlas.kn_count_of("die")
	var f = Atlas.kn_meta.get("die_" + str(dir) + "_" + str(n - 1))
	var sc := 1.2 if c.get("champ", false) else 1.0
	if f != null:
		var dst := Rect2(c.x - f[4] * sc * .5, c.y - f[5] * sc * .5, f[2] * sc * .5, f[3] * sc * .5)
		c["rect"] = dst
		var src := Rect2(f[0], f[1], f[2], f[3])
		blood.tex(Atlas.knight, dst, src)
		blood.tex(Atlas.knight, dst, src, Atlas.soft(Color8(70, 10, 6), .35))
	var big: bool = c.get("champ", false) or c.get("rare", false)
	var bones: Array = ["boneB0", "boneB1"] if c.get("champ", false) else (["boneB2", "boneB3"] if c.get("rare", false) else ["bone0", "bone1", "bone2", "bone3", "bone4", "bone5", "bone6"])
	var nb := 2 if big else 1 + (1 if rnd() < .5 else 0)
	for i in nb:
		var bf = Atlas.items_meta.get("w_" + bones[int(rnd() * bones.size())])
		if bf == null:
			continue
		var side := (1.0 if i % 2 else -1.0) * (1.0 if rnd() < .5 else -1.0)
		var bx: float = c.x + side * (12 + rnd() * 8)
		var by: float = c.y + 2 + (rnd() - .5) * 8
		if JS.hypot(bx - sim.CX, by - sim.CY) < Sim.FRAD + 4:
			continue
		var bw := JS.roundi(bf[2] * .7)
		var bh := JS.roundi(bf[3] * .7)
		blood.tex(Atlas.items, Rect2(JS.roundi(bx - bw / 2.0), JS.roundi(by - bh / 2.0), bw, bh), Rect2(bf[0], bf[1], bf[2], bf[3]))

func corpse_raised(c: Dictionary) -> void:
	if c.has("rect"):
		var r: Rect2 = c.rect
		blood.clear_rect(Rect2(floorf(r.position.x) - 1, floorf(r.position.y) - 1, ceilf(r.size.x) + 2, ceilf(r.size.y) + 2))
		return
	var f = Atlas.kn_meta.get("die_" + str(Atlas.kdir(c.face)) + "_" + str(Atlas.kn_count_of("die") - 1))
	if f != null:
		blood.clear_rect(Rect2(floorf(c.x - f[4] * .5) - 1, floorf(c.y - f[5] * .5) - 1, ceilf(f[2] * .5) + 2, ceilf(f[3] * .5) + 2))

# ---------------- cada fotograma ----------------
func tick(dt: float) -> void:
	var keep := []
	for q in parts:
		q.life -= dt
		q.x += q.vx * dt
		q.y += q.vy * dt
		if q.float:
			q.z += q.vz * dt
		else:
			q.vz -= 300 * dt
			q.z += q.vz * dt
			q.vx *= .985
			q.vy *= .985
			if q.z <= 0:
				if q.blood:
					stain(q.x, q.y, q.col, 2 if rnd() < .35 else 1)
					q.life = 0
				else:
					q.z = 0
					q.vz *= -.3
					q.vx *= .5
					q.vy *= .5
		if q.life > 0:
			keep.append(q)
	parts = keep
	var kt := []
	for t in texts:
		t.life -= dt
		t.y -= (50.0 if t.life > t.max - .15 else 14.0) * dt
		if t.life > 0:
			kt.append(t)
	texts = kt
	shake_v = maxf(0, shake_v - dt * 24)
	if banner_t > 0:
		banner_t -= dt

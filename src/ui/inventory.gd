class_name Inventory
extends Control
## Equipo y mochila (renderInv del juego web): muñeco con las piezas y sus engarces + mochila en rejilla 12×6.
##   Clic: coger · clic: soltar (también se puede arrastrar y soltar).
##   Clic derecho: equipar / quitar / beber / engarzar en el primer hueco que valga / sacar una runa a la mochila.
##   Soltar fuera del panel: tirarlo al suelo. Esc con algo en la mano: devolverlo. Esc, I o Tab: cerrar.
## Mientras está abierto la partida se para.

signal closed

var sim: Sim
var hold = null          # {it, from: {where: bag|eq|sock, gx, gy, slot, i}}
var msg := ""
var _down = null         # punto donde se cogió algo (para arrastrar)
var _ptr := Vector2.ZERO
var _hover = null        # referencia bajo el puntero: {slot} | {sock, slot, i} | {id}

const W := 432.0
const CELL := 40.0       # paso de la rejilla del muñeco (36 + 4)
const BC := 33.0         # casilla de la mochila
const PAD := 14.0
const C_GOLDT := Color8(240, 215, 154)
const C_TXT := Color8(233, 223, 204)
const C_MUT := Color8(168, 151, 124)
const C_LINE := Color8(74, 58, 40)

var k := 1.0             # escala del panel
var org := Vector2.ZERO  # esquina del panel
var doll0 := Vector2.ZERO
var bag0 := Vector2.ZERO
var H := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false

func open() -> void:
	hold = null
	msg = ""
	_down = null
	sim.p.rn_new = 0
	visible = true
	queue_redraw()

func close() -> void:
	return_held()
	visible = false
	sim.runes.agg(sim.p)
	sim.fx.hud()
	closed.emit()

# ======================================================================
#  operaciones (rnPickBag, rnPutSock, rnQuick… de la web)
# ======================================================================
func _p() -> Ent.Hero:
	return sim.p

func _changed() -> void:
	sim.runes.agg(_p())
	sim.fx.hud()

func _warn(t: String) -> void:
	msg = t

func _bag_item(id: int):
	for it in _p().bag:
		if it.id == id:
			return it
	return null

func pick_bag(it: Dictionary) -> void:
	Items.bag_del(_p(), it)
	hold = {"it": it, "from": {"where": "bag", "gx": it.gx, "gy": it.gy}}

func pick_eq(s: String) -> void:
	var it = _p().eq[s]
	_p().eq[s] = null
	hold = {"it": it, "from": {"where": "eq", "slot": s}}
	_changed()

func pick_sock(s: String, i: int) -> void:
	var it: Dictionary = _p().eq[s]
	var id: String = it.socks[i]
	it.socks[i] = null
	hold = {"it": Items.rune_item(id, 1), "from": {"where": "sock", "slot": s, "i": i}}
	_changed()

func put_sock(s: String, i: int) -> void:
	var p := _p()
	var it = p.eq.get(s)
	var h: Dictionary = hold.it
	if it == null:
		return
	if not h.has("rune"):
		_warn("En los engarces solo van runas.")
		return
	var r := Items.rune(h.rune)
	var cur = it.socks[i]
	if cur == h.rune:
		return
	var why := Items.why_not(p, r, s)
	if why != "" and int(r.t) == 5 and cur != null and int(Items.rune(cur).t) == 5:
		var r4 := r.duplicate()
		r4.t = 4
		if Items.why_not(p, r4, s) == "":
			why = ""   # cambiar una legendaria por otra
	if why != "":
		_warn(why)
		return
	if cur != null and h.n > 1 and Items.add_rune(p, cur, 1):
		_warn("No queda sitio en la mochila para la runa que había.")
		return
	it.socks[i] = h.rune
	_flash_mark(s, i)
	h.n -= 1
	if cur != null and h.n <= 0:
		hold = {"it": Items.rune_item(cur, 1), "from": {"where": "sock", "slot": s, "i": i}}
	elif h.n <= 0:
		hold = null
	_warn("")
	_changed()

func put_eq(s: String) -> void:
	var p := _p()
	var h: Dictionary = hold.it
	if h.has("rune"):
		_warn("Pon la runa en uno de los engarces de la pieza.")
		return
	var why := Items.why_equip(p, h, s)
	if why != "":
		_warn(why)
		return
	var old = p.eq.get(s)
	p.eq[s] = h
	hold = {"it": old, "from": {"where": "eq", "slot": s}} if old != null else null
	_warn("")
	_changed()

func put_bag(gx: int, gy: int) -> void:
	var p := _p()
	var h: Dictionary = hold.it
	var sz := Items.size_of(h)
	gx = clampi(gx, 0, Items.RB_W - sz[0])
	gy = clampi(gy, 0, Items.RB_H - sz[1])
	var over := Items.bag_over(p, gx, gy, sz[0], sz[1])
	if over.size() > 1:
		_warn("Ahí no cabe: hay más de un objeto debajo.")
		return
	var o = over[0] if over.size() else null
	if o != null and h.has("rune") and o.get("rune", "") == h.rune:
		if o.n >= Items.RB_STACK:
			_warn("Ese montón ya está lleno (%d)." % Items.RB_STACK)
			return
		var kk := mini(h.n, Items.RB_STACK - o.n)
		o.n += kk
		h.n -= kk
		if h.n <= 0:
			hold = null
		_warn("")
		return
	if o != null and h.slot == "potion" and o.slot == "potion":
		var on := int(o.get("n", 1))
		if on >= Items.POT_STACK:
			_warn("Ese montón ya tiene %d pociones." % Items.POT_STACK)
			return
		var kk := mini(int(h.get("n", 1)), Items.POT_STACK - on)
		o.n = on + kk
		h.n = int(h.get("n", 1)) - kk
		if h.n <= 0:
			hold = null
		_warn("")
		return
	h.gx = gx
	h.gy = gy
	p.bag.append(h)
	if o != null:
		Items.bag_del(p, o)
		hold = {"it": o, "from": {"where": "bag", "gx": o.gx, "gy": o.gy}}
	else:
		hold = null
	_warn("")

func drop_held() -> void:
	if hold == null:
		return
	var it: Dictionary = hold.it
	hold = null
	sim.drop_item(it)
	_warn("")

## Esc o cerrar con algo en la mano: vuelve a su sitio (o al primer hueco; si no cabe, al suelo)
func return_held() -> void:
	if hold == null:
		return
	var h: Dictionary = hold
	var it: Dictionary = h.it
	var p := _p()
	hold = null
	var fr: Dictionary = h.from
	if fr.where == "eq" and p.eq.get(fr.slot) == null and Items.why_equip(p, it, fr.slot) == "":
		p.eq[fr.slot] = it
		_changed()
		return
	if fr.where == "sock" and it.n == 1:
		var e = p.eq.get(fr.slot)
		if e != null and e.socks[fr.i] == null and Items.why_not(p, Items.rune(it.rune), fr.slot) == "":
			e.socks[fr.i] = it.rune
			_changed()
			return
	if it.has("rune"):
		var left := Items.add_rune(p, it.rune, it.n)
		if left:
			it.n = left
			hold = {"it": it, "from": fr}
			drop_held()
		return
	if fr.where == "bag" and Items.bag_fits(p, it, fr.gx, fr.gy):
		it.gx = fr.gx
		it.gy = fr.gy
		p.bag.append(it)
		return
	if not Items.bag_add(p, it):
		hold = {"it": it, "from": fr}
		drop_held()

## de un golpe (clic derecho)
func quick(ref: Dictionary) -> void:
	var p := _p()
	var k_: String = p.cls_key()
	if ref.has("sock"):
		var it = p.eq.get(ref.slot)
		var id = it.socks[ref.i] if it != null else null
		if id == null:
			return
		if Items.add_rune(p, id, 1):
			_warn("No queda sitio en la mochila.")
			return
		it.socks[ref.i] = null
		_warn("Runa %s a la mochila" % Items.rune(id).n)
		_changed()
		return
	if ref.has("slot"):
		var it = p.eq.get(ref.slot)
		if it == null:
			return
		if Items.bag_spot(p, it) == null:
			_warn("No queda sitio en la mochila.")
			return
		p.eq[ref.slot] = null
		Items.bag_add(p, it)
		_warn("")
		_changed()
		return
	var it = _bag_item(ref.id)
	if it == null:
		return
	if it.slot == "potion":
		sim.drink_potion(it)
		return
	if it.has("rune"):
		var r := Items.rune(it.rune)
		if not Items.can_use(k_, r):
			_warn("Es una runa de %s." % r.k)
			return
		if int(r.t) == 5 and Items.leg_count(p) >= 2:
			_warn("Ya llevas 2 runas legendarias.")
			return
		for s in Items.fit(k_, r):
			var e = p.eq.get(s)
			if e == null or e.q < Items.rune_q(r):
				continue
			var i: int = e.socks.find(null)
			if i < 0:
				continue
			e.socks[i] = r.id
			_flash_mark(s, i)
			it.n -= 1
			if it.n <= 0:
				Items.bag_del(p, it)
			_warn("Runa %s engarzada en %s" % [r.n, Items.slot_name(k_, s).to_lower()])
			_changed()
			return
		var rq := Items.rune_q(r)
		_warn("No hay engarces libres en: %s%s." % [Items.fit_txt(k_, r), (" (objetos %s%s)" % [Items.RQ_NP[rq], " o mejores" if rq < 3 else ""]) if rq else ""])
		return
	if it.get("gear", false):
		var why := Items.why_equip(p, it)
		if why != "":
			_warn(why)
			return
		var old = p.eq.get(it.slot)
		Items.bag_del(p, it)
		p.eq[it.slot] = it
		if old != null:
			if Items.bag_fits(p, old, it.gx, it.gy):
				old.gx = it.gx
				old.gy = it.gy
				p.bag.append(old)
			elif not Items.bag_add(p, old):
				p.eq[it.slot] = old
				p.bag.append(it)
				_warn("No queda sitio en la mochila para lo que llevas puesto.")
				return
		_warn("")
		_changed()

# ======================================================================
#  colocación y entrada
# ======================================================================
func _layout() -> void:
	H = 30 + 7 * CELL + 26 + 6 * BC + 46 + PAD * 2
	_marco = _medir_marco()
	if _marco.is_empty():
		k = minf(1.35, minf((size.x - 20) / W, (size.y - 20) / H))
		org = ((size - Vector2(W, H) * k) / 2).floor()
	else:
		var fs: Vector2 = _marco.rect.size
		k = minf(1.35, minf((size.x - 20) / fs.x, (size.y - 20) / fs.y))
		org = ((size - fs * k) / 2 - _marco.rect.position * k).floor()
	doll0 = Vector2(PAD + 2, PAD + 34)
	bag0 = Vector2(PAD + 4, doll0.y + 7 * CELL + 26)

## marco de Diego con las dos estatuas (assets/ui/inventario_marco.png): se estira solo por la viga del
## centro y por el tramo liso de las columnas, para que las estatuas no se deformen
const MARCO_M := Vector4(400, 1052, 403, 230)   # márgenes en píxeles de la imagen (izq, arriba, der, abajo)
const MARCO_AIRE := 12.0                         # cuánto asoma el fondo de la hoja por dentro del marco
var _marco := {}

## {rect (en unidades del panel), k (escala de la imagen)} o vacío si no está la pieza
func _medir_marco() -> Dictionary:
	var t := UiArte.tex("inventario_marco")
	if t == null:
		return {}
	var ts := t.get_size()
	var h: Array = UiArte.med("inventario_marco").get("hueco", [.1471, .1009, .85, .9539])
	var hx0: float = h[0] * ts.x
	var hy0: float = h[1] * ts.y
	var hw: float = (h[2] - h[0]) * ts.x
	var hh: float = (h[3] - h[1]) * ts.y
	var e := (H + MARCO_AIRE * 2) / hh
	var extra := maxf(0, (W + MARCO_AIRE * 2) / e - hw)
	return {"rect": Rect2(Vector2(-MARCO_AIRE - hx0 * e, -MARCO_AIRE - hy0 * e), Vector2(ts.x + extra, ts.y) * e), "k": e}

func _to_panel(v: Vector2) -> Vector2:
	return (v - org) / k

func _slot_rect(s: String) -> Rect2:
	var L: Array = Items.set_of(_p().cls_key()).lay[s]
	return Rect2(doll0 + Vector2((L[0] - 1) * CELL, (L[1] - 1) * CELL), Vector2(L[2] * CELL - 4, L[3] * CELL - 4))

## posiciones de los engarces dentro de la pieza (rnSockPos)
func _sock_pos(n: int, vert: bool) -> Array:
	match n:
		1: return [[0, 0]]
		2: return [[0, 0], [0, 1]] if vert else [[0, 0], [1, 0]]
		3: return [[0, 0], [0, 1], [0, 2]] if vert else [[0, 0], [1, 0], [2, 0]]
		4: return [[0, 0], [1, 0], [1, 1], [0, 1]]
		5: return [[0, 0], [1, 0], [1, 1], [0, 1], [0, 2]]
	return [[0, 0], [1, 0], [1, 1], [0, 1], [0, 2], [1, 2]]

func _sock_rects(s: String) -> Array:
	var it = _p().eq.get(s)
	if it == null or it.socks.is_empty():
		return []
	var R := _slot_rect(s)
	var pos := _sock_pos(it.socks.size(), R.size.y >= R.size.x)
	var nc := 0
	var nr := 0
	for q in pos:
		nc = maxi(nc, q[0] + 1)
		nr = maxi(nr, q[1] + 1)
	var tight := nr * 26 > R.size.y - 14 or nc * 26 > R.size.x - 14
	var st := 21.0 if tight else 26.0
	var sz := 18.0 if tight else 22.0
	var o := R.get_center() - Vector2((nc - 1) * st + sz, (nr - 1) * st + sz) / 2 + Vector2(0, 6)
	var out := []
	for q in pos:
		out.append(Rect2(o + Vector2(q[0] * st, q[1] * st), Vector2(sz, sz)))
	return out

func _bag_rect(it: Dictionary) -> Rect2:
	var sz := Items.size_of(it)
	return Rect2(bag0 + Vector2(it.gx * BC, it.gy * BC), Vector2(sz[0] * BC, sz[1] * BC))

func _panel_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(W, H))

func _ref_at(v: Vector2):
	var p := _p()
	for s in Items.set_of(p.cls_key()).slots:
		var rs := _sock_rects(s)
		for i in rs.size():
			if rs[i].grow(1).has_point(v):
				return {"sock": true, "slot": s, "i": i}
	for s in Items.set_of(p.cls_key()).slots:
		if _slot_rect(s).has_point(v):
			return {"slot": s}
	for it in p.bag:
		if _bag_rect(it).has_point(v):
			return {"id": it.id}
	return null

func _bag_cell(v: Vector2, it: Dictionary) -> Dictionary:
	var sz := Items.size_of(it)
	var g := Rect2(bag0, Vector2(Items.RB_W * BC, Items.RB_H * BC))
	return {"gx": JS.roundi((v.x - bag0.x) / BC - sz[0] / 2.0), "gy": JS.roundi((v.y - bag0.y) / BC - sz[1] / 2.0), "inside": g.has_point(v)}

## clic (o soltar tras arrastrar) en el punto v del panel; devuelve true si ha hecho algo
func _act(v: Vector2) -> bool:
	var p := _p()
	if hold != null:
		if not _panel_rect().has_point(v):
			drop_held()
			return true
		var r = _ref_at(v)
		if r != null and r.has("sock") and hold.it.has("rune"):
			put_sock(r.slot, r.i)
			return true
		if r != null and r.has("slot") and not r.has("sock"):
			put_eq(r.slot)
			return true
		var c := _bag_cell(v, hold.it)
		if c.inside:
			put_bag(c.gx, c.gy)
			return true
		return false
	var r = _ref_at(v)
	if r == null:
		return false
	if r.has("sock"):
		var it = p.eq.get(r.slot)
		if it != null and it.socks[r.i] != null:
			pick_sock(r.slot, r.i)
			_warn("")
			return true
		return false
	if r.has("id"):
		var it = _bag_item(r.id)
		if it != null:
			pick_bag(it)
			_warn("")
			return true
		return false
	if p.eq.get(r.slot) != null:
		pick_eq(r.slot)
		_warn("")
		return true
	return false

func _gui_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev is InputEventMouseMotion:
		_ptr = ev.position
		_hover = _ref_at(_to_panel(_ptr)) if hold == null else null
		queue_redraw()
	elif ev is InputEventMouseButton:
		var v := _to_panel(ev.position)
		_ptr = ev.position
		if ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed and hold == null and _close_rect().has_point(v):
				accept_event()
				close()
				return
			if ev.pressed:
				var had: bool = hold != null
				var did := _act(v)
				_down = ev.position if (did and not had and hold != null) else null
			elif _down != null and hold != null:
				var moved: bool = (ev.position - _down).length() > 8
				_down = null
				if moved:
					_act(v)
		elif ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
			if hold != null:
				return_held()
			else:
				var r = _ref_at(v)
				if r != null:
					quick(r)
		_hover = _ref_at(v) if hold == null else null
		queue_redraw()
	accept_event()

func _unhandled_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev.is_action_pressed("lk_pause") or ev.is_action_pressed("lk_inv"):
		if hold != null and ev.is_action_pressed("lk_pause"):
			return_held()
			queue_redraw()
		else:
			close()
		get_viewport().set_input_as_handled()

# ======================================================================
#  dibujo
# ======================================================================
func _process(_dt: float) -> void:
	if visible:
		queue_redraw()

func _txt(pos: Vector2, s: String, sz: int, col: Color, align: int = 0, w: int = 600) -> void:
	Fonts.outlined(self, Fonts.px(w), org + pos * k, s, int(sz * k), col, align, 3)

func _rect(r: Rect2, c: Color, fill: bool = true, lw: float = 1.0) -> void:
	draw_rect(Rect2(org + r.position * k, r.size * k), c, fill, lw if not fill else -1.0)

func _tex(tex: Texture2D, r: Rect2, mod: Color = Color.WHITE) -> void:
	draw_texture_rect(tex, _fit(tex, r), false, mod)

## rectángulo de pantalla donde cabe la textura en r (panel) manteniendo la proporción
func _fit(tex: Texture2D, r: Rect2, sc: float = 1.0) -> Rect2:
	var ts := Vector2(tex.get_width(), tex.get_height())
	var d := ts * minf(r.size.x / ts.x, r.size.y / ts.y) * sc
	return Rect2(org + (r.get_center() - d / 2) * k, d * k)

# ---------- recursos de dibujo (como el CSS del inventario web) ----------
const C_SOCK_RING := Color8(110, 86, 54)     # #6e5636
const Q_BG := [Color(70 / 255.0, 66 / 255.0, 58 / 255.0, .35), Color(40 / 255.0, 70 / 255.0, 140 / 255.0, .35), Color(150 / 255.0, 110 / 255.0, 30 / 255.0, .35), Color(40 / 255.0, 150 / 255.0, 120 / 255.0, .35)]
const Q_LINE := ["#8a8270", "#4f7fd6", "#e0b040", "#3fe0b0"]
const Q_GLOW := [0.0, .35, .35, .45]
const FLASH_T := .8
var _spheres := {}
var _sil := {}
var _soft: Texture2D
var _hole: Texture2D
var _flash = null          # destello al engarzar: {s, i, at}
var _sparks: Array = []    # chispas de los objetos dorados y legendarios
var _last_t := 0.0
var demo_flash_e := -1.0   # capturas: congela el destello en este instante (s)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _flash_mark(s: String, i: int) -> void:
	_flash = {"s": s, "i": i, "at": _now()}

## textura redonda generada píxel a píxel: f(distancia al foco, normalizada a la esquina más lejana) → color
func _round_tex(N: int, focus: Vector2, f: Callable) -> Texture2D:
	var im := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var fc := focus * N
	var far := maxf(maxf(fc.length(), (Vector2(N, 0) - fc).length()), maxf((Vector2(0, N) - fc).length(), (Vector2(N, N) - fc).length()))
	for y in N:
		for x in N:
			var pp := Vector2(x + .5, y + .5)
			var d := pp.distance_to(Vector2(N, N) / 2.0)
			if d > N / 2.0 + .5:
				continue
			var c: Color = f.call(pp.distance_to(fc) / far)
			c.a *= clampf(N / 2.0 - d + .5, 0, 1)
			im.set_pixel(x, y, c)
	return ImageTexture.create_from_image(im)

## runa engarzada: esfera con brillo (radial-gradient circle at 38% 32%: blanco 8 %, color 30 %, #1a120c)
func _sphere(col: Color) -> Texture2D:
	var key := col.to_html()
	if not _spheres.has(key):
		var dark := Color8(26, 18, 12)
		_spheres[key] = _round_tex(64, Vector2(.38, .32), func(g: float) -> Color:
			if g < .08: return Color.WHITE
			if g < .30: return Color.WHITE.lerp(col, (g - .08) / .22)
			return col.lerp(dark, (g - .30) / .70))
	return _spheres[key]

## engarce vacío: agujero (#050404 hasta el 45 %, #1c1712 al 62 %, #0b0907 al 70 %)
func _hole_tex() -> Texture2D:
	if _hole == null:
		var a := Color8(5, 4, 4)
		var b := Color8(28, 23, 18)
		var c := Color8(11, 9, 7)
		_hole = _round_tex(64, Vector2(.5, .45), func(g: float) -> Color:
			if g < .45: return a
			if g < .62: return a.lerp(b, (g - .45) / .17)
			if g < .70: return b.lerp(c, (g - .62) / .08)
			return c)
	return _hole

## mancha de luz suave (blanca, se tiñe con modulate)
func _soft_tex() -> Texture2D:
	if _soft == null:
		_soft = _round_tex(64, Vector2(.5, .5), func(g: float) -> Color:
			var d := clampf(g / .7071, 0, 1)
			return Color(1, 1, 1, pow(1 - d, 2)))
	return _soft

func _glow(ce: Vector2, r: float, c: Color) -> void:
	draw_texture_rect(_soft_tex(), Rect2(org + (ce - Vector2(r, r)) * k, Vector2(r, r) * 2 * k), false, c)

## silueta blanca de una textura (para sombras y resplandores de color)
func _silhouette(tex: Texture2D) -> Texture2D:
	var id := tex.get_instance_id()
	if not _sil.has(id):
		var im := tex.get_image()
		if im.is_compressed():
			im.decompress()
		im.convert(Image.FORMAT_RGBA8)
		for y in im.get_height():
			for x in im.get_width():
				im.set_pixel(x, y, Color(1, 1, 1, im.get_pixel(x, y).a))
		_sil[id] = ImageTexture.create_from_image(im)
	return _sil[id]

## icono con drop-shadow(0 3px 2px #000) y, por calidad, drop-shadow(0 0 4–6px color)
func _icon(tex: Texture2D, r: Rect2, q: int, mod: Color = Color.WHITE, halo := 0.0) -> void:
	var dst := _fit(tex, r)
	var sil := _silhouette(tex)
	draw_texture_rect(sil, Rect2(dst.position + Vector2(0, 3 * k), dst.size), false, Color(0, 0, 0, .55 * mod.a))
	if q > 0:
		var c := ViewFx.col(Items.RQ_C[q])
		var rad := (2.0 + q) * k
		for a in 8:
			var o := Vector2(cos(a * PI / 4), sin(a * PI / 4)) * rad
			c.a = (.06 + .015 * q) * mod.a * (1 + halo)
			draw_texture_rect(sil, Rect2(dst.position + o, dst.size), false, c)
	draw_texture_rect(tex, dst, false, mod)

## box-shadow inset: degradado del borde hacia dentro (cuatro trapecios)
func _inset(r: Rect2, c: Color, blur: float) -> void:
	var b := minf(blur, minf(r.size.x, r.size.y) / 2) * k
	_frame(org + r.position * k, org + r.end * k, Vector2(b, b), c * Color(1, 1, 1, .7), Color(c.r, c.g, c.b, 0))

## resplandor exterior (box-shadow 0 0 Npx)
func _outset(r: Rect2, c: Color, blur: float) -> void:
	var b := blur * k
	_frame(org + r.position * k - Vector2(b, b), org + r.end * k + Vector2(b, b), Vector2(b, b), Color(c.r, c.g, c.b, 0), c * Color(1, 1, 1, .55))

## marco con degradado: co en el borde exterior (a, b) y ci en el interior (a + w, b − w)
func _frame(a: Vector2, b: Vector2, w: Vector2, co: Color, ci: Color) -> void:
	var A := a + w
	var B := b - w
	var cols := PackedColorArray([co, co, ci, ci])
	draw_polygon(PackedVector2Array([a, Vector2(b.x, a.y), Vector2(B.x, A.y), A]), cols)
	draw_polygon(PackedVector2Array([Vector2(b.x, a.y), b, B, Vector2(B.x, A.y)]), cols)
	draw_polygon(PackedVector2Array([b, Vector2(a.x, b.y), Vector2(A.x, B.y), B]), cols)
	draw_polygon(PackedVector2Array([Vector2(a.x, b.y), a, A, Vector2(A.x, B.y)]), cols)

func _circle(ce: Vector2, r: float, c: Color) -> void:
	draw_circle(org + ce * k, r * k, c, true, -1.0, true)

func _quad(r: Rect2, ctop: Color, cbot: Color) -> void:
	var a := org + r.position * k
	var b := org + r.end * k
	draw_polygon(PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]), PackedColorArray([ctop, ctop, cbot, cbot]))

## rombo de runa de la mochila (rnGem): cuadrado girado con borde de su color
func _gem(r: Rect2, rid: String, n: int = 1) -> void:
	var rr := Items.rune(rid)
	var c := ViewFx.col(Items.RN_TC[int(rr.t)])
	var ce := r.get_center()
	var h := 10.6     # media diagonal de un cuadrado de 15 px
	_glow(ce, h + 6, Color(c.r, c.g, c.b, .4))
	var pts := func(rad: float) -> PackedVector2Array:
		return PackedVector2Array([org + (ce + Vector2(0, -rad)) * k, org + (ce + Vector2(rad, 0)) * k, org + (ce + Vector2(0, rad)) * k, org + (ce + Vector2(-rad, 0)) * k])
	draw_colored_polygon(pts.call(h + 1.4), c)
	draw_colored_polygon(pts.call(h - 1.4), Color8(18, 13, 10))
	draw_texture_rect(_soft_tex(), Rect2(org + (ce - Vector2(h, h) * .8 + Vector2(-1, -1.5)) * k, Vector2(h, h) * 1.6 * k), false, c.lerp(Color.BLACK, .45))
	Fonts.outlined(self, Fonts.px(700), org + (ce + Vector2(0, 2.5)) * k, Items.RN_ROM[int(rr.t)], int(7 * k), Color.WHITE, 1, 2, Color.BLACK)
	if n > 1:
		Fonts.outlined(self, Fonts.px(700), org + (r.end - Vector2(2, 2)) * k, str(n), int(10 * k), Color8(243, 230, 200), 2, 3, Color.BLACK)

func _draw_item(it: Dictionary, r: Rect2, ghost: bool = false) -> void:
	if it.slot == "potion":
		var pt := Atlas.potion
		var d := Vector2(16, 16 * pt.get_height() / float(pt.get_width())) * 1.4
		draw_texture_rect(pt, Rect2(org + (r.get_center() - d / 2) * k, d * k), false)
		if int(it.get("n", 1)) > 1:
			Fonts.outlined(self, Fonts.px(700), org + (r.end - Vector2(2, 2)) * k, str(it.n), int(10 * k), Color8(243, 230, 200), 2, 3, Color.BLACK)
		return
	if it.has("rune"):
		_gem(r, it.rune, it.n)
		return
	var other: bool = it.cls != _p().cls_key() and not ghost
	_icon(Atlas.gear_tex(it.cls, it.slot, it.q), r.grow(-r.size.x * .08), it.q, Color(1, 1, 1, .6) if other else Color.WHITE, _pulse(it))
	# engarces: puntos de 6 px abajo a la izquierda (rbDots)
	var n: int = it.socks.size()
	for i in n:
		var ce := r.position + Vector2(5 + i * 8, r.size.y - 5)
		_circle(ce, 4, C_SOCK_RING)
		var c := Color8(5, 4, 4)
		if it.socks[i] != null:
			c = ViewFx.col(Items.RN_TC[int(Items.rune(it.socks[i]).t)])
		_circle(ce, 3, c)

## latido del halo de los objetos dorados y legendarios
func _pulse(it: Dictionary) -> float:
	if not it.get("gear", false) or it.q < 2:
		return 0.0
	return (.5 + .5 * sin(_now() * 3.2 + float(int(it.id) % 7))) * (.8 if it.q == 3 else .55)

## halo y chispas de un objeto dorado o legendario en el rectángulo r
func _rare_fx(it: Dictionary, r: Rect2, dt: float) -> void:
	if not it.get("gear", false) or it.q < 2:
		return
	var c := ViewFx.col(Items.RQ_C[it.q])
	var pl := _pulse(it)
	_glow(r.get_center(), maxf(r.size.x, r.size.y) * .62, Color(c.r, c.g, c.b, .08 + .12 * pl))
	var rate := (5.0 if it.q == 2 else 9.0) * maxf(1, r.size.x * r.size.y / 4000.0)
	if randf() < rate * dt:
		var lc := c.lerp(Color.WHITE, .55)
		_sparks.append({"x": r.position.x + randf() * r.size.x, "y": r.position.y + r.size.y * (.35 + randf() * .6), "vy": -(10 + randf() * 14), "vx": (randf() - .5) * 4,
			"life": 0.0, "max": .9 + randf() * .7, "col": lc if randf() < .5 else c, "s": 1.0 + randf() * 1.2})

func _draw_sparks(dt: float) -> void:
	var keep := []
	for sp in _sparks:
		sp.life += dt
		if sp.life >= sp.max:
			continue
		sp.x += sp.vx * dt
		sp.y += sp.vy * dt
		var f: float = sp.life / sp.max
		var a: float = minf(1, f * 5) * (1 - f)
		var c: Color = sp.col
		_glow(Vector2(sp.x, sp.y), 3.5 * sp.s, Color(c.r, c.g, c.b, .45 * a))
		_rect(Rect2(Vector2(sp.x, sp.y) - Vector2(.6, .6) * sp.s, Vector2(1.2, 1.2) * sp.s), Color(c.r, c.g, c.b, a))
		keep.append(sp)
	_sparks = keep

## destello al engarzar (rnFlS, rnFlK y rnFlA del CSS): la pieza se ilumina y del engarce sale una estrella
func _flash_slot(R: Rect2, e: float) -> void:
	var a := pow(1 - clampf(e / FLASH_T, 0, 1), 1.4)
	_outset(R, Color(1, 200 / 255.0, 80 / 255.0, .8 * a), 22)
	_inset(R, Color(1, 220 / 255.0, 120 / 255.0, .9 * a), 40)
	draw_rect(Rect2(org + R.position * k, R.size * k), Color(1, 246 / 255.0, 200 / 255.0, a), false, 2 * k)

func _flash_star(ce: Vector2, e: float) -> void:
	var f := clampf(e / .7, 0, 1)
	if f >= 1:
		return
	var op := f / .18 if f < .18 else 1 - (f - .18) / .82
	var R := 42.0 * lerpf(.3, 1.25, 1 - pow(1 - f, 2))
	_glow(ce, R * .62, Color(1, 170 / 255.0, 50 / 255.0, .45 * op))
	_glow(ce, R * .38, Color(1, 226 / 255.0, 140 / 255.0, .8 * op))
	_glow(ce, R * .16, Color(1, 1, 240 / 255.0, op))
	var rot := deg_to_rad(20 + 40 * f)
	var c0 := Color(1, 240 / 255.0, 190 / 255.0, .8 * op)
	var c1 := Color(1, 240 / 255.0, 190 / 255.0, 0)
	for q in [.12, .37, .62, .87]:
		var ang: float = rot + q * TAU - PI / 2
		var w := .035 * TAU
		var p1 := org + (ce + Vector2(cos(ang - w / 2), sin(ang - w / 2)) * R * .7) * k
		var p2 := org + (ce + Vector2(cos(ang + w / 2), sin(ang + w / 2)) * R * .7) * k
		draw_polygon(PackedVector2Array([org + ce * k, p1, p2]), PackedColorArray([c0, c1, c1]))

## botón «Cerrar» de la cabecera (rnClose)
func _close_rect() -> Rect2:
	return Rect2(W - PAD - 78, PAD + 1, 78, 24)

func _ptr_in(r: Rect2) -> bool:
	return r.has_point(_to_panel(_ptr))

## rayas rojas en diagonal: pieza de otra clase
func _stripes(R: Rect2) -> void:
	var c := Color(1, 60 / 255.0, 40 / 255.0, .14)
	var o := org + R.position * k
	var sz := R.size * k
	var box := PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), sz, Vector2(0, sz.y)])
	var step := 8 * k * sqrt(2)
	var d := -sz.y
	while d < sz.x:
		var band := PackedVector2Array([Vector2(d, 0), Vector2(d + step / 2, 0), Vector2(d + step / 2 + sz.y, sz.y), Vector2(d + sz.y, sz.y)])
		for poly in Geometry2D.intersect_polygons(band, box):
			var pp := PackedVector2Array()
			for q in poly:
				pp.append(o + q)
			draw_colored_polygon(pp, c)
		d += step

## hueco de objeto de Diego según la calidad (0 básico, 1 mágico, 2 dorado, 3 legendario); borde en unidades
## del panel. Mágico y legendario usan, teñidos, el normal y el dorado hasta que lleguen los suyos.
func _hueco_q(R: Rect2, q: int, borde: float) -> bool:
	var nombre := "hueco_objeto"
	var mod := Color.WHITE
	match q:
		1:
			if UiArte.tex("hueco_magico") != null:
				nombre = "hueco_magico"
			else:
				mod = Color(.6, .8, 1.5)
		2:
			nombre = "hueco_dorado"
		3:
			if UiArte.tex("hueco_legendario") != null:
				nombre = "hueco_legendario"
			else:
				nombre = "hueco_dorado"
				mod = Color(.5, 1.25, 1.05)
	return UiArte.caja(self, nombre, Rect2(org + R.position * k, R.size * k), 48, borde * k, mod)

func _draw() -> void:
	if not visible or sim == null or sim.p == null:
		return
	_layout()
	var now := _now()
	var dt := clampf(now - _last_t, 0, .1)
	_last_t = now
	var p := _p()
	var ck := p.cls_key()
	var C: Dictionary = Items.set_of(ck)
	var hit = hold.it if hold != null else null
	if demo_flash_e >= 0 and _flash != null:
		_flash.at = now - demo_flash_e
	var fl = _flash if _flash != null and now - _flash.at < FLASH_T else null
	draw_rect(Rect2(Vector2.ZERO, size), Color(10 / 255.0, 7 / 255.0, 5 / 255.0, .86))
	# hoja: borde 2px #000 y anillos #8a6a3c, #1a130c, #5a4428; fondo de #1b1611 a #100c09
	var pr := _panel_rect()
	if not _marco.is_empty():
		_quad(pr.grow(MARCO_AIRE + 4), Color8(27, 22, 17), Color8(16, 12, 9))
		var mr: Rect2 = _marco.rect
		UiArte.caja_lados(self, "inventario_marco", Rect2(org + mr.position * k, mr.size * k), MARCO_M, _marco.k * k)
	else:
		_outset(pr.grow(6), Color(0, 0, 0, .9), 18)
		_rect(pr.grow(7), Color8(90, 68, 40))
		_rect(pr.grow(6), Color8(26, 19, 12))
		_rect(pr.grow(3), Color8(138, 106, 60))
		_rect(pr.grow(2), Color.BLACK)
		_quad(pr, Color8(27, 22, 17), Color8(16, 12, 9))
	# cabecera
	Fonts.outlined(self, Fonts.gothic(800), org + Vector2(PAD, PAD + 19) * k, "EQUIPO", int(19 * k), Color8(240, 215, 154), 0, 3, Color.BLACK)
	var chr := Rect2(PAD + 98, PAD + 4, 142, 19)
	_rect(chr, Color8(22, 17, 13))
	_rect(chr, Color8(74, 58, 40), false)
	_txt(Vector2(chr.get_center().x, chr.end.y - 5), "Runas legendarias %d/2" % Items.leg_count(p), 11, Color8(201, 180, 138), 1, 500)
	var cr := _close_rect()
	var chv := _ptr_in(cr)
	_rect(Rect2(cr.position + Vector2(0, 3), cr.size).grow(2), Color8(12, 10, 8))
	_rect(Rect2(cr.position + Vector2(0, 3), cr.size), Color8(138, 90, 22))
	_quad(cr, Color8(255, 196, 92) if chv else Color8(240, 172, 66), Color8(214, 140, 40) if chv else Color8(196, 124, 32))
	Fonts.outlined_raw(self, Fonts.px(700), org + (cr.get_center() + Vector2(0, 5)) * k, Idioma.t("Cerrar"), int(13 * k), Color8(28, 16, 6), 1, 0)
	# estatuas a los lados del muñeco (rnSt: todo el alto, a un 18 % de cada lado, opacidad .7) — solo sin el marco de Diego, que ya trae las suyas
	if _marco.is_empty():
		var stt := Atlas.statue_tex()
		var dh := 7 * CELL + 4
		var stw := dh * stt.get_width() / float(stt.get_height())
		var dw := W - PAD * 2
		var sl := Rect2(Vector2(PAD + dw * .18, doll0.y - 6), Vector2(stw, dh))
		var sr := Rect2(Vector2(PAD + dw * .82 - stw, doll0.y - 6), Vector2(stw, dh))
		draw_texture_rect(stt, Rect2(org + sl.position * k, sl.size * k), false, Color(1, 1, 1, .5))
		# la de la derecha, reflejada (un Rect2 de ancho negativo no refleja en Godot)
		draw_set_transform(org + Vector2(sr.end.x, sr.position.y) * k, 0, Vector2(-1, 1))
		draw_texture_rect(stt, Rect2(Vector2.ZERO, sr.size * k), false, Color(1, 1, 1, .5))
		draw_set_transform(Vector2.ZERO)
	# piezas
	for s in C.slots:
		var R := _slot_rect(s)
		var it = p.eq.get(s)
		var can: bool = hit != null and hit.get("gear", false) and Items.cabe(ck, hit, s) and hit.cls == ck
		var fit_r: bool = hit != null and hit.has("rune") and it != null and Items.why_not(p, Items.rune(hit.rune), s) == ""
		var hov: bool = _hover != null and _hover.get("slot", "") == s and not _hover.has("sock")
		# fondo: radial-gradient(rgba(42,34,27,.62) → rgba(20,15,11,.85)), borde #000 e inset 14px #000
		var arte := _hueco_q(R, it.q if it != null else 0, 7)
		if not arte:
			_rect(R, Color(20 / 255.0, 15 / 255.0, 11 / 255.0, .85))
			_glow(R.get_center() - Vector2(0, R.size.y * .05), maxf(R.size.x, R.size.y) * .62, Color(42 / 255.0, 34 / 255.0, 27 / 255.0, .62))
			_inset(R, Color.BLACK, 14)
		var line := Color8(59, 46, 32)
		if it != null:
			line = ViewFx.col(Q_LINE[it.q])
			if Q_GLOW[it.q] > 0:
				var gc := line
				gc.a = Q_GLOW[it.q]
				_inset(R, gc, 16)
		if can or fit_r:
			line = Color8(127, 208, 106)
			_inset(R, Color(127 / 255.0, 208 / 255.0, 106 / 255.0, .55), 18)
		if it != null:
			_rare_fx(it, R, dt)
			_icon(Atlas.gear_tex(it.cls, s, it.q), R.grow(-R.size.x * .07), it.q, Color.WHITE, _pulse(it))
		else:
			_tex(Atlas.gear_tex(ck, s, 0), R.grow(-R.size.x * .07), Color(.55, .55, .55, .16))
		if not arte or can or fit_r:
			draw_rect(Rect2(org + R.position * k, R.size * k), Color.BLACK, false, k)
			draw_rect(Rect2(org + (R.position + Vector2(1, 1)) * k, (R.size - Vector2(2, 2)) * k), line, false, (2 if can or fit_r else 1) * k)
		if hov:
			_rect(R, Color(1, 1, 1, .07))
		if fl != null and fl.s == s:
			_flash_slot(R, now - fl.at)
		_txt(Vector2(R.position.x + 3, R.position.y + 10), Items.slot_name(ck, s).to_upper(), 8, Color8(125, 106, 82), 0, 500)
		# engarces: agujeros redondos; con runa, una esfera de su color con el número
		var rs := _sock_rects(s)
		for i in rs.size():
			var id = it.socks[i]
			var sk: Rect2 = rs[i]
			var hs: bool = _hover != null and _hover.has("sock") and _hover.slot == s and _hover.i == i
			var ce := sk.get_center()
			var rad := sk.size.x / 2
			var fk: bool = fl != null and fl.s == s and fl.i == i
			var fe: float = now - fl.at if fk else 0.0
			if fk:
				var f := clampf(fe / .6, 0, 1)
				rad *= lerpf(1.6, .95, f / .6) if f < .6 else lerpf(.95, 1, (f - .6) / .4)
				_glow(ce, rad + 16, Color(1, 246 / 255.0, 200 / 255.0, .9 * (1 - f)))
			elif hs:
				rad *= 1.12
			_glow(ce + Vector2(0, 2), rad + 3, Color(0, 0, 0, .8))
			_circle(ce, rad + 3, Color.BLACK)
			if fit_r:
				_glow(ce, rad + 9, Color(1, 176 / 255.0, 48 / 255.0, .55))
			_circle(ce, rad + 2, Color8(255, 210, 90) if fit_r or fk else C_SOCK_RING)
			var dst := Rect2(org + (ce - Vector2(rad, rad)) * k, Vector2(rad, rad) * 2 * k)
			if id != null:
				var rr := Items.rune(id)
				draw_texture_rect(_sphere(ViewFx.col(Items.RN_TC[int(rr.t)])), dst, false)
				Fonts.outlined_raw(self, Fonts.px(700), org + (ce + Vector2(0, 3.2 * rad / 11)) * k, Items.RN_ROM[int(rr.t)], int(9 * k * rad / 11), Color8(16, 10, 6), 1, 0)
			else:
				draw_texture_rect(_hole_tex(), dst, false)
			if fk:
				_flash_star(ce, fe)
	# mochila
	var hy := bag0.y - 8
	var mut := Color8(154, 138, 112)
	_txt(Vector2(bag0.x + 2, hy), ("Mochila · %d/%d" % [Items.bag_used(p), Items.RB_W * Items.RB_H]).to_upper(), 10, mut, 0, 500)
	var pc := Items.potion_count(p)
	_txt(Vector2(bag0.x + Items.RB_W * BC - 2, hy), ("%d oro · %d %s · %d %s" % [p.gold, p.keys, "llave" if p.keys == 1 else "llaves", pc, "poción" if pc == 1 else "pociones"]).to_upper(), 10, mut, 2, 500)
	var gr := Rect2(bag0, Vector2(Items.RB_W * BC, Items.RB_H * BC))
	_rect(gr, Color8(10, 7, 5))
	var ho := UiArte.tex("hueco_objeto")
	if ho != null:
		for y in Items.RB_H:
			for x in Items.RB_W:
				draw_texture_rect(ho, Rect2(org + (bag0 + Vector2(x * BC, y * BC)) * k, Vector2(BC, BC) * k), false, Color(.8, .8, .8))
	else:
		var gl := Color(90 / 255.0, 70 / 255.0, 50 / 255.0, .35)
		for x in Items.RB_W:
			draw_rect(Rect2(org + (bag0 + Vector2(x * BC, 0)) * k, Vector2(maxf(1, k * .8), gr.size.y * k)), gl)
		for y in Items.RB_H:
			draw_rect(Rect2(org + (bag0 + Vector2(0, y * BC)) * k, Vector2(gr.size.x * k, maxf(1, k * .8))), gl)
	_rect(gr.grow(1), Color8(61, 46, 32), false)
	for it in p.bag:
		var R := _bag_rect(it)
		var hv: bool = _hover != null and _hover.get("id", -1) == it.id
		var bg := Color(40 / 255.0, 30 / 255.0, 22 / 255.0, .85)
		var bl := Color8(90, 70, 48)
		if it.get("gear", false):
			bg = Q_BG[it.q]
			bl = ViewFx.col(Q_LINE[it.q])
		elif it.has("rune"):
			bg = Color(24 / 255.0, 18 / 255.0, 14 / 255.0, .9)
			bl = Color8(59, 46, 32)
		elif it.slot == "potion":
			bg = Color(60 / 255.0, 20 / 255.0, 16 / 255.0, .45)
			bl = Color8(122, 58, 42)
		if not (it.get("gear", false) and _hueco_q(R, it.q, 5)):
			_rect(R, bg)
		if it.get("gear", false) and it.cls != ck:
			_stripes(R)
		if hv:
			_rect(R, Color(1, 1, 1, .1))
		_rect(R, bl, false)
		_rare_fx(it, R, dt)
		_draw_item(it, R)
	_draw_sparks(dt)
	# sombra de dónde caerá lo que llevas en la mano
	var v := _to_panel(_ptr)
	if hit != null:
		var c := _bag_cell(v, hit)
		if c.inside:
			var sz := Items.size_of(hit)
			var gx := clampi(c.gx, 0, Items.RB_W - sz[0])
			var gy := clampi(c.gy, 0, Items.RB_H - sz[1])
			var ov := Items.bag_over(p, gx, gy, sz[0], sz[1])
			var merge: bool = ov.size() == 1 and ((hit.has("rune") and ov[0].get("rune", "") == hit.rune) or (hit.slot == "potion" and ov[0].slot == "potion"))
			var sh := Rect2(bag0 + Vector2(gx * BC, gy * BC), Vector2(sz[0] * BC, sz[1] * BC))
			var lc := Color8(127, 208, 106) if (ov.is_empty() or merge) else (Color8(255, 210, 90) if ov.size() == 1 else Color8(224, 70, 58))
			_rect(sh, Color(lc.r, lc.g, lc.b, .25))
			_rect(sh, lc, false)
	# mensaje y ayuda
	_txt(Vector2(W / 2, H - PAD - 22), msg, 12, Color8(255, 154, 106), 1, 500)
	var hint := "Clic: coger · clic derecho: equipar, quitar, beber o engarzar · arrastra para mover"
	if hit != null:
		hint = "Suéltala en un engarce iluminado, en la mochila o fuera para tirarla. Esc: devolverla." if hit.has("rune") else "Suéltalo en su hueco, en la mochila o fuera del panel para tirarlo. Esc: devolverlo."
	_txt(Vector2(PAD, H - PAD - 4), hint, 9, mut, 0, 500)
	# lo que llevas en la mano
	if hit != null:
		var sz := Items.size_of(hit)
		var gs := Vector2(sz[0] * BC, sz[1] * BC)
		var gR := Rect2(v - gs / 2, gs)
		_glow(gR.get_center() + Vector2(0, 4), maxf(gs.x, gs.y) * .6, Color(0, 0, 0, .5))
		_draw_item(hit, gR, true)
	elif _hover != null:
		_draw_tip(_tip_for(_hover))

# ---------- ayudas al pasar el ratón (rnTipFor) ----------
## líneas [texto, color, tamaño]
func _tip_for(ref: Dictionary) -> Array:
	var p := _p()
	var ck := p.cls_key()
	if ref.has("sock"):
		var it = p.eq.get(ref.slot)
		var id = it.socks[ref.i] if it != null else null
		if id == null:
			return [["Engarce vacío de " + Items.slot_name(ck, ref.slot).to_lower(), C_MUT, 11]]
		return _rune_tip(Items.rune(id)) + [["Clic: cogerla · clic derecho: a la mochila", C_MUT, 10]]
	if ref.has("slot"):
		var it = p.eq.get(ref.slot)
		if it == null:
			return [[Items.slot_name(ck, ref.slot), C_GOLDT, 13], ["Hueco vacío", C_MUT, 11]]
		return _gear_tip(it, true)
	var it = _bag_item(ref.id)
	if it == null:
		return []
	if it.slot == "potion":
		return [["Poción de vida", ViewFx.col("#ff8a7a"), 13], ["Cura %d de vida" % p.st.potionHeal, C_TXT, 11],
			[("%d en este montón (máximo %d) · " % [it.n, Items.POT_STACK] if int(it.get("n", 1)) > 1 else "") + "Bébela con Q o con clic derecho.", C_MUT, 10],
			["Recarga de %d s entre pociones." % int(Sim.POT_CD), C_MUT, 10]]
	if it.has("rune"):
		return _rune_tip(Items.rune(it.rune)) + [[("%d en este montón · " % it.n if it.n > 1 else "") + "clic derecho: engarzarla", C_MUT, 10]]
	return _gear_tip(it, false)

func _rune_tip(r: Dictionary) -> Array:
	var p := _p()
	var ck := p.cls_key()
	var tt := int(r.t)
	var rq := Items.rune_q(r)
	var out := [["Runa " + String(r.n), ViewFx.col(Items.RN_TC[tt]), 13],
		["Rango %s · %s · %s" % [Items.RN_ROM[tt], Items.RN_TN[tt], r.c], C_MUT, 10],
		[String(r.e), C_TXT, 11],
		["Se engarza en: " + Items.fit_txt(ck, r) + ("" if r.k == "Todas" else " · solo " + String(r.k)), C_MUT, 10],
		["En objetos " + Items.RQ_NP[rq] + (" o mejores" if rq < 3 else ""), C_MUT, 10]]
	if not Items.can_use(ck, r):
		out.append(["Tu clase no puede usarla", ViewFx.col("#ff6a5a"), 11])
	return out

func _gear_tip(it: Dictionary, is_eq: bool) -> Array:
	var p := _p()
	var k_: String = it.cls
	var own := k_ == p.cls_key()
	var out := [[String(it.name), ViewFx.col(Items.RQ_C[it.q]), 13],
		["%s · %s%s" % [Items.slot_name(k_, it.slot), Items.RQ_N[it.q], "" if own else " · " + Items.CLS_N[k_]], C_MUT, 10]]
	if not own:
		out.append(["Solo para " + Items.CLS_N[k_], ViewFx.col("#ff6a5a"), 11])
	var bt := Items.base_txt(k_, it.slot)
	if bt != "":
		out.append([bt, C_TXT, 11])
	# cada estadística con su flecha comparada con lo que llevas puesto (si es de tu clase y no es lo puesto)
	var cur = p.eq.get(it.slot) if own and not is_eq else null
	if cur != null:
		out.append(["Comparado con " + String(cur.name) + ":", C_MUT, 10])
	out.append_array(Comparar.lineas(it, cur))
	for id in it.socks:
		if id != null:
			var r := Items.rune(id)
			out.append([String(r.n) + " · " + String(r.e), ViewFx.col(Items.RN_TC[int(r.t)]), 10])
	if is_eq:
		out.append(["Puesto · clic derecho para quitártelo", C_MUT, 10])
	elif own and cur == null:
		out.append(["El hueco está libre: equípalo con clic derecho.", C_MUT, 10])
	return out

func _draw_tip(lines: Array) -> void:
	if lines.is_empty():
		return
	var font := Fonts.px(500)
	var tw := 250.0 * k
	var wrapped := []
	var h := 8.0 * k
	for l in lines:
		var fs := int(l[2] * k)
		var words: PackedStringArray = Idioma.t(String(l[0])).split(" ")
		var cur := ""
		for w in words:
			var t := w if cur == "" else cur + " " + w
			if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > tw - 16 * k and cur != "":
				wrapped.append([cur, l[1], fs])
				cur = w
			else:
				cur = t
		wrapped.append([cur, l[1], fs])
	for l in wrapped:
		h += l[2] + 4 * k
	var pos := _ptr + Vector2(16, 14)
	if pos.x + tw > size.x - 6:
		pos.x = _ptr.x - tw - 14
	if pos.y + h > size.y - 6:
		pos.y = maxf(6, size.y - h - 6)
	if not UiArte.caja(self, "panel", Rect2(pos, Vector2(tw, h)).grow(6 * k), 40, 12 * k):
		draw_rect(Rect2(pos, Vector2(tw, h)), Color(14 / 255.0, 10 / 255.0, 8 / 255.0, .96))
		draw_rect(Rect2(pos, Vector2(tw, h)), Color8(138, 106, 60), false, 1)
	var y := pos.y + 6 * k
	for l in wrapped:
		y += l[2]
		Fonts.outlined_raw(self, font, Vector2(pos.x + 8 * k, y), l[0], l[2], l[1], 0, 2)
		y += 4 * k

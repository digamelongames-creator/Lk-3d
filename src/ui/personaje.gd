class_name Personaje
extends Control
## Panel del personaje (Tab o C) y árbol de habilidades a pantalla completa (T), como en el juego web.
##   Personaje: nivel, experiencia, reparto de los puntos de nivel (Daño, Vida, Agilidad; lo repartido en esta
##   visita se puede deshacer con «−») y la hoja de estadísticas completa.
##   Árbol: tres paneles (una rama por habilidad), cinco escalones de abajo arriba. Clic en un nodo: ver su efecto;
##   doble clic o «Aprender»: gastar un punto. Lo aprendido es definitivo.
## Mientras está abierto la partida se para.

signal closed

var sim: Sim
var mode := "stats"           # stats o tree
var session := {}             # puntos repartidos en esta visita (se pueden quitar)
var sel := ""                 # nodo del árbol elegido

const C_FG := Color8(239, 227, 204)
const C_MUT := Color8(168, 151, 124)
const C_GOLD := Color8(201, 162, 74)
const C_GOLDT := Color8(255, 226, 168)
const C_RED := Color8(255, 122, 106)
const STATS := [["dmg", "Daño", "+1 de daño final (no se multiplica)"], ["hp", "Vida", "+8 de vida máxima"], ["agi", "Agilidad", "+0,5 % de velocidad de ataque y de movimiento"]]
## árbol: tamaño de un panel, columnas de los escalones con dos nodos, centro, filas (de la clave al escalón 1) y lado del nodo
const TP := {"W": 300.0, "H": 560.0, "cols": [82.0, 218.0], "mid": 150.0, "rows": [96.0, 196.0, 296.0, 396.0, 496.0], "N": 58.0}

var _icons: Texture2D
var _stone: Texture2D
var _root: Control
var _theme: Theme

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_icons = load("res://assets/web/img/tree_icons_src.png")
	_stone = load("res://assets/web/img/stone.png")
	_theme = _make_theme()
	theme = _theme

func open(m: String) -> void:
	mode = m
	session = {}
	sel = ""
	visible = true
	_rebuild()

func close() -> void:
	if not visible:
		return
	visible = false
	sim.fx.hud()
	closed.emit()

func _unhandled_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev.is_action_pressed("lk_pause") or (mode == "stats" and ev.is_action_pressed("lk_char")) or (mode == "tree" and ev.is_action_pressed("lk_tree")) or (mode == "partida" and ev.is_action_pressed("lk_stats")):
		get_viewport().set_input_as_handled()
		close()
	elif mode == "stats" and ev.is_action_pressed("lk_tree"):
		get_viewport().set_input_as_handled()
		open("tree")
	elif mode == "tree" and ev.is_action_pressed("lk_char"):
		get_viewport().set_input_as_handled()
		open("stats")

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = Fonts.px(600)
	th.default_font_size = 15
	var n := StyleBoxFlat.new()
	n.bg_color = Color8(29, 20, 16)
	n.border_color = Color8(74, 58, 38)
	n.set_border_width_all(1)
	n.content_margin_left = 10; n.content_margin_right = 10; n.content_margin_top = 4; n.content_margin_bottom = 5
	var h := n.duplicate()
	h.bg_color = Color8(58, 42, 26)
	h.border_color = C_GOLD
	var f := h.duplicate()
	f.border_color = Color8(95, 180, 214)
	f.set_border_width_all(2)
	var d := n.duplicate()
	d.bg_color = Color8(20, 15, 12)
	d.border_color = Color8(40, 32, 26)
	th.set_stylebox("normal", "Button", n)
	th.set_stylebox("hover", "Button", h)
	th.set_stylebox("pressed", "Button", h)
	th.set_stylebox("focus", "Button", f)
	th.set_stylebox("disabled", "Button", d)
	th.set_color("font_color", "Button", C_FG)
	th.set_color("font_hover_color", "Button", C_GOLDT)
	th.set_color("font_focus_color", "Button", C_GOLDT)
	th.set_color("font_pressed_color", "Button", C_GOLDT)
	th.set_color("font_disabled_color", "Button", Color8(90, 80, 68))
	th.set_color("font_color", "Label", C_FG)
	return th

func _label(parent: Node, txt: String, size: int = 15, col: Color = C_FG, font: Font = null) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font != null:
		l.add_theme_font_override("font", font)
	parent.add_child(l)
	return l

func _button(parent: Node, txt: String, cb: Callable, red := false) -> Button:
	var b := Button.new()
	b.text = txt
	b.pressed.connect(cb)
	if red:
		var n := StyleBoxFlat.new()
		n.bg_color = Color8(162, 33, 22)
		n.border_color = C_GOLD
		n.set_border_width_all(1)
		n.content_margin_left = 16; n.content_margin_right = 16; n.content_margin_top = 5; n.content_margin_bottom = 6
		var h := n.duplicate()
		h.bg_color = Color8(194, 43, 30)
		var f := h.duplicate()
		f.border_color = Color8(95, 180, 214)
		f.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("focus", f)
		b.add_theme_stylebox_override("pressed", n)
		b.add_theme_font_override("font", Fonts.gothic(800))
		for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			b.add_theme_color_override(k, C_GOLDT)
	parent.add_child(b)
	return b

func _rebuild() -> void:
	if _root != null:
		_root.queue_free()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(6 / 255.0, 4 / 255.0, 3 / 255.0, .86)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	if mode == "stats":
		_build_stats()
	elif mode == "partida":
		_build_partida()
	else:
		_build_tree()

# ======================================================================
#  personaje
# ======================================================================
func _panel(w: float) -> VBoxContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(22, 16, 12)
	sb.border_color = Color8(107, 84, 52)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(18)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size.x = w
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(cc)
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	return v

func _build_stats() -> void:
	var p := sim.p
	var C: Dictionary = GameData.get_table("classes")[p.cls_key()]
	var v := _panel(720)
	var top := HBoxContainer.new()
	v.add_child(top)
	_label(top, "Héroe del Descenso · " + String(C.n), 24, Color8(233, 207, 138), Fonts.gothic(800))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	_button(top, "Árbol de habilidades" + (" +%d" % p.skp if p.skp > 0 else "") + " · T", func(): open("tree"))
	var maxed := p.lvl >= Sim.MAXLVL
	_label(v, "Nivel %d%s   ·   Experiencia %s" % [p.lvl, " (máximo)" if maxed else " / %d" % Sim.MAXLVL, "—" if maxed else "%d / %d" % [p.xp, sim.xp_need(p.lvl)]], 16)
	var xb := ProgressBar.new()
	xb.max_value = 1
	xb.value = 1.0 if maxed else float(p.xp) / sim.xp_need(p.lvl)
	xb.show_percentage = false
	xb.custom_minimum_size.y = 8
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color8(150, 110, 255)
	var back := StyleBoxFlat.new()
	back.bg_color = Color8(26, 18, 30)
	xb.add_theme_stylebox_override("fill", fill)
	xb.add_theme_stylebox_override("background", back)
	v.add_child(xb)
	_label(v, "Puntos por asignar: %d   ·   De habilidad: %d" % [p.pts, p.skp], 16, C_GOLDT if p.pts > 0 else C_FG)
	_label(v, "Los puntos de habilidad se gastan en el árbol (T).", 12, C_MUT)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 6)
	v.add_child(g)
	var first: Button = null
	for st in STATS:
		var id: String = st[0]
		var nb := VBoxContainer.new()
		nb.custom_minimum_size.x = 330
		nb.add_theme_constant_override("separation", 0)
		_label(nb, st[1], 16, C_FG)
		_label(nb, st[2], 11, C_MUT)
		g.add_child(nb)
		var val := ""
		match id:
			"dmg": val = str(JS.round(p.st.dmg * 10) / 10.0)
			"hp": val = str(int(p.st.maxHp))
			"agi": val = "%.2f/s · %d%%" % [1 / p.st.atkCd, JS.roundi(p.st.spd / Sim.BASE_SPD * 100)]
		var vl := _label(g, val + ("   (%d pts)" % p.alloc[id] if p.alloc[id] else ""), 15, C_GOLDT)
		vl.custom_minimum_size.x = 190
		var mb := _button(g, "−", func(): _unalloc(id))
		mb.disabled = not (session.get(id, 0) > 0)
		var ab := _button(g, "+", func(): _alloc(id))
		ab.disabled = p.pts <= 0
		if first == null and not ab.disabled:
			first = ab
	# hoja completa en dos columnas
	_label(v, "Hoja de estadísticas", 15, Color8(233, 207, 138), Fonts.gothic(700))
	var sh := GridContainer.new()
	sh.columns = 4
	sh.add_theme_constant_override("h_separation", 16)
	sh.add_theme_constant_override("v_separation", 0)
	v.add_child(sh)
	var cb: Dictionary = C.base
	for k in sim.stat_defs:
		var d: Dictionary = sim.stat_defs[k]
		if k == "maxMana" or k == "manaRegen":
			if not (p.st.maxMana > 0):
				continue
		var vv: float = p.st[k]
		var b0: float = cb[k] if cb.has(k) else d.base
		var diff := absf(vv - b0) > 1e-6
		var better: bool = (vv > b0) == (k != "blockRed" and k != "rollCdMax")
		var l1 := _label(sh, d.n, 12, C_MUT)
		l1.custom_minimum_size.x = 200
		var l2 := _label(sh, fmt_stat(k, vv), 12, (Color8(140, 220, 120) if better else Color8(230, 110, 90)) if diff else C_FG)
		l2.custom_minimum_size.x = 120
	var close := _button(v, "Volver al combate", close, true)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	(first if first != null else close).call_deferred("grab_focus")

# ======================================================================
#  crónica del descenso (tecla P): datos de la partida, como renderStats de la web
# ======================================================================
static func fmt_t(s: float) -> String:
	var x := int(floorf(s))
	var h := x / 3600
	var m := (x / 60) % 60
	var ss := x % 60
	return ("%d:%02d:%02d" % [h, m, ss]) if h > 0 else ("%d:%02d" % [m, ss])

static func miles(n: int) -> String:
	var t := str(absi(n))
	var out := ""
	while t.length() > 3:
		out = "." + t.substr(t.length() - 3) + out
		t = t.substr(0, t.length() - 3)
	return ("-" if n < 0 else "") + t + out

func _build_partida() -> void:
	var st: Dictionary = sim.stats
	var k: Dictionary = st.get("kills", {})
	var v := _panel(440)
	var tl := _label(v, "Crónica del descenso", 24, Color8(233, 207, 138), Fonts.gothic(800))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(400, minf(460, get_viewport_rect().size.y * .62))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var g := GridContainer.new()
	g.columns = 2
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 3)
	sc.add_child(g)
	var head := func(txt: String) -> void:
		for i in 2:
			var l := _label(g, txt if i == 0 else "", 14, Color8(233, 207, 138), Fonts.gothic(800))
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := func(a: String, b: String) -> void:
		var l1 := _label(g, a, 14, C_MUT)
		l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l2 := _label(g, b, 14, C_FG)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.call("Partida")
	row.call("Tiempo total", fmt_t(st.get("t", 0.0)))
	row.call("Veces que has muerto", str(st.get("deaths", 0)))
	row.call("Oleada actual", str(sim.wave) + (" (empezaste en la %d)" % sim.start_wave if sim.start_wave > 1 else ""))
	head.call("Tiempo por oleada")
	var ws: Array = st.get("waves", {}).keys()
	ws.sort_custom(func(a, b): return int(a) < int(b))
	for w in ws:
		row.call("Oleada %s%s" % [w, " (en curso)" if int(w) == sim.wave else ""], fmt_t(st.waves[w]))
	head.call("Movimiento")
	var dist: float = st.get("dist", 0.0)
	row.call("Pasos dados", miles(int(floorf(dist / 16))))
	row.call("Distancia recorrida", miles(JS.roundi(dist / Sim.TS * 1.5)) + " m")
	head.call("Combate")
	var sw: int = st.get("swings", 0)
	var hi: int = st.get("hits", 0)
	row.call("Ataques realizados", miles(sw))
	row.call("Golpes a monstruos", miles(hi))
	row.call("Precisión", ("%d %%" % JS.roundi(minf(1, float(hi) / sw) * 100)) if sw > 0 else "—")
	row.call("Daño total causado", miles(sim.p.dmg_dealt))
	row.call("Mejor racha de golpes", str(sim.p.best_chain))
	head.call("Monstruos abatidos")
	var tot := 0
	for kk in k:
		tot += int(k[kk])
	for r in [["knight", "Caballeros (azules)"], ["slayer", "Degolladores (rojos)"], ["sargwen", "Lanzadores (verdes)"], ["rare", "Caballeros legendarios"], ["champ", "Campeones"], ["hero", "Héroes renegados"], ["mon", "Bestias y jefes"]]:
		if r[0] in ["hero", "mon"] and not k.get(r[0], 0):
			continue
		row.call(r[1], str(k.get(r[0], 0)))
	row.call("Total", str(tot))
	var close := _button(v, "Volver al combate · P", close, true)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.call_deferred("grab_focus")

func _alloc(id: String) -> void:
	var p := sim.p
	if p.pts <= 0:
		return
	p.pts -= 1
	p.alloc[id] += 1
	session[id] = session.get(id, 0) + 1
	sim.recalc(p)
	sim.fx.hud()
	_rebuild_keep_focus()

func _unalloc(id: String) -> void:
	var p := sim.p
	if not (session.get(id, 0) > 0):
		return
	p.pts += 1
	p.alloc[id] -= 1
	session[id] -= 1
	sim.recalc(p)
	sim.fx.hud()
	_rebuild_keep_focus()

func _rebuild_keep_focus() -> void:
	var f := get_viewport().gui_get_focus_owner()
	var path := _root.get_path_to(f) if f != null and _root.is_ancestor_of(f) else NodePath("")
	_rebuild()
	if path != NodePath(""):
		var n := _root.get_node_or_null(path)
		if n is Control and not (n is Button and n.disabled):
			n.call_deferred("grab_focus")

static func fmt_stat(k: String, v: float) -> String:
	var pct := func(x: float) -> String: return "%d%%" % JS.roundi(x * 100)
	var dec := func(x: float) -> String: return str(JS.round(x * 10) / 10.0)
	match k:
		"dmg": return dec.call(v)
		"range", "maxHp", "potionHeal", "pickupR", "maxMana", "armorPts": return str(JS.roundi(v))
		"critMult": return "×" + str(JS.round(v * 100) / 100.0)
		"backstab": return "+" + pct.call(v)
		"parryStun", "parryWin": return dec.call(v) + " s"
		"regen", "manaRegen": return dec.call(v) + "/s"
		"spd": return "%d%%" % JS.roundi(v / Sim.BASE_SPD * 100)
		"rollCdMax": return str(JS.round(v * 100) / 100.0) + " s"
		"thorns", "killHeal": return dec.call(v)
		"chainT": return dec.call(v) + " s"
	return pct.call(v)

# ======================================================================
#  árbol de habilidades
# ======================================================================
class _Branch extends Control:
	var ui: Personaje
	var b := 0
	func _draw() -> void:
		var tp: Dictionary = Personaje.TP
		draw_texture_rect(ui._stone, Rect2(0, 0, tp.W, tp.H), true, Color(.62, .66, .7))
		draw_rect(Rect2(0, 0, tp.W, tp.H), Color(0, 0, 0, .25))
		draw_rect(Rect2(0, 0, tp.W, tp.H), Color8(26, 22, 18), false, 2)
		draw_rect(Rect2(2, 2, tp.W - 4, tp.H - 4), Color8(74, 64, 54), false, 2)
		var p := ui.sim.p
		var c := p.cls_key()
		var T := func(t: int) -> Array: return ui.sim.arbol.nodes(c, b, t)
		var link := func(a: Dictionary, z: Dictionary) -> void:
			var p1: Vector2 = ui.node_pos(a)
			var p2: Vector2 = ui.node_pos(z)
			var u := (p2 - p1).normalized()
			var o: float = tp.N / 2 + 4
			var A := p1 + u * o
			var Z := p2 - u * (o + 4)
			var lit := int(p.tree.get(a.id, 0)) > 0
			draw_line(A, Z, Color8(14, 10, 8), 7)
			draw_line(A, Z, Color8(255, 154, 58) if lit else Color8(58, 52, 48), 3)
			var n := Vector2(-u.y, u.x)
			draw_colored_polygon(PackedVector2Array([Z + u * 6, Z - u * 2 + n * 5, Z - u * 2 - n * 5]), Color8(255, 154, 58) if lit else Color8(26, 20, 16))
		var t1: Array = T.call(1)
		var t2: Array = T.call(2)
		var t3: Array = T.call(3)
		for i in t1.size(): link.call(t1[i], t2[i])
		for i in t2.size(): link.call(t2[i], t3[i])
		for n in t3: link.call(n, T.call(4)[0])
		link.call(T.call(4)[0], T.call(5)[0])

class _NodeBtn extends Control:
	var ui: Personaje
	var n: Dictionary
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if ev.double_click:
				ui._learn(n.id)
			else:
				grab_focus()
				ui._select(n.id)
		elif ev.is_action_pressed("ui_accept"):
			accept_event()
			ui._learn(n.id)
	func _draw() -> void:
		var p := ui.sim.p
		var r := int(p.tree.get(n.id, 0))
		var st := ui.sim.arbol.node_state(p, n)
		var N: float = Personaje.TP.N
		var has := r > 0
		var edge := Color8(255, 176, 74) if has else (Color8(232, 224, 208) if st == "ok" else (Color8(200, 160, 80) if int(n.t) == 5 else Color8(138, 106, 62)))
		if has:
			for k in 4:
				draw_rect(Rect2(-4 - k * 2, -4 - k * 2, N + 8 + k * 4, N + 8 + k * 4), Color(1, .47, .12, .12 - k * .025), false, 2)
		draw_rect(Rect2(0, 0, N, N), Color8(26, 20, 16))
		draw_rect(Rect2(0, 0, N, N), Color8(14, 10, 8), false, 2)
		draw_rect(Rect2(2, 2, N - 4, N - 4), edge, false, 2)
		var i: int = Arbol.TREE.find(n)
		var dim := Color(1, 1, 1)
		if st == "locked" or (st == "nopts" and not has): dim = Color(.42, .42, .42)
		if st == "excluded" or st == "keytaken": dim = Color(.28, .28, .28)
		draw_texture_rect_region(ui._icons, Rect2(5, 5, 48, 48), Rect2(i * 16, 0, 16, 16), dim)
		if st == "excluded" or st == "keytaken":
			draw_line(Vector2(10, N - 10), Vector2(N - 10, 10), Color8(176, 40, 26), 3)
		if has_focus() or ui.sel == n.id:
			draw_rect(Rect2(-5, -5, N + 10, N + 10), Color8(143, 208, 234), false, 2)
		var rk := "%d/%d" % [r, int(n.max)]
		draw_rect(Rect2(N - 14, N - 12, 24, 20), Color8(26, 22, 18))
		draw_rect(Rect2(N - 14, N - 12, 24, 20), Color8(255, 176, 74) if has else Color8(138, 128, 112), false, 1)
		draw_string(Fonts.px(600), Vector2(N - 14, N + 3), rk, HORIZONTAL_ALIGNMENT_CENTER, 24, 11, Color8(255, 216, 144) if has else Color8(232, 224, 208))

func node_pos(n: Dictionary) -> Vector2:
	var ns := sim.arbol.nodes(n.c, int(n.b), int(n.t))
	var k := ns.find(n)
	return Vector2(TP.cols[k] if ns.size() > 1 else TP.mid, TP.rows[5 - int(n.t)])

func _build_tree() -> void:
	var p := sim.p
	var c := p.cls_key()
	var C: Dictionary = GameData.get_table("classes")[c]
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	cc.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	v.add_child(top)
	_label(top, "Árbol de habilidades · " + String(C.n), 24, Color8(233, 207, 138), Fonts.gothic(800))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	_label(top, "Puntos de habilidad: %d" % p.skp, 18, Color8(255, 138, 58) if p.skp > 0 else C_FG)
	_button(top, "Personaje · Tab", func(): open("stats"))
	_button(top, "Cerrar · T", close)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var first: Control = null
	for b in 3:
		var br := _Branch.new()
		br.ui = self
		br.b = b
		br.custom_minimum_size = Vector2(TP.W, TP.H)
		row.add_child(br)
		var bp := sim.arbol.branch_pts(p, c, b)
		var h := _label(br, String(Sim.SK[C.skills[b]].n), 17, Color8(244, 226, 184), Fonts.gothic(800))
		h.position = Vector2(0, 8)
		h.size.x = TP.W
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_theme_color_override("font_shadow_color", Color.BLACK)
		var l2 := _label(br, "%d / 15 puntos en la rama" % bp, 11, Color8(224, 214, 196))
		l2.position = Vector2(0, 32)
		l2.size.x = TP.W
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		for t in range(2, 6):
			if bp < Arbol.TIER_REQ[t]:
				var rq := _label(br, "necesita %d" % Arbol.TIER_REQ[t], 10, Color8(224, 214, 196))
				rq.position = Vector2(8, TP.rows[5 - t] + TP.N / 2 + 4)
		for n in sim.arbol.nodes(c, b):
			var nb := _NodeBtn.new()
			nb.name = "N_" + String(n.id)
			nb.ui = self
			nb.n = n
			nb.focus_mode = Control.FOCUS_ALL
			nb.mouse_filter = Control.MOUSE_FILTER_STOP
			nb.size = Vector2(TP.N, TP.N)
			nb.position = node_pos(n) - Vector2(TP.N, TP.N) / 2
			var id: String = n.id
			nb.focus_entered.connect(func(): _select(id))
			nb.focus_exited.connect(func(): nb.queue_redraw())
			nb.mouse_entered.connect(func(): if sel == "": _show_info(id))
			br.add_child(nb)
			if (sel == "" and first == null and int(n.t) == 1) or sel == String(n.id):
				first = nb
	# ficha del nodo
	var info := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(20 / 255.0, 16 / 255.0, 12 / 255.0, .92)
	sb.border_color = Color8(107, 84, 52)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(10)
	info.add_theme_stylebox_override("panel", sb)
	info.custom_minimum_size = Vector2(0, 92)
	info.name = "Info"
	v.add_child(info)
	_show_info(sel)
	if first != null:
		first.call_deferred("grab_focus")

func _show_info(id: String) -> void:
	var info := _root.find_child("Info", true, false)
	if info == null:
		return
	for ch in info.get_children():
		ch.queue_free()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	info.add_child(h)
	var n: Dictionary = Arbol.BY_ID.get(id, {})
	if n.is_empty():
		var l := _label(h, "Elige un nodo para ver su efecto; doble clic o «Aprender» para gastar un punto. Los escalones se abren con 3, 6, 9 y 11 puntos en la rama; en el escalón 3 eliges A o B y solo puedes tener una clave en todo el árbol. Lo aprendido es definitivo.", 13, C_MUT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 900
		return
	var p := sim.p
	var st := sim.arbol.node_state(p, n)
	var r := int(p.tree.get(id, 0))
	var tx := VBoxContainer.new()
	tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tx)
	_label(tx, "%s   ·   escalón %d · %s · rango %d/%d" % [n.n, int(n.t), Arbol.TIER_NAME[int(n.t)], r, int(n.max)], 17, C_GOLDT, Fonts.gothic(800))
	var ds := _label(tx, n.ds, 14)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size.x = 700
	if st == "ok":
		_label(tx, "Puedes aprenderlo (1 punto).", 12, Color8(159, 224, 138))
	elif st == "max":
		_label(tx, "Rango máximo.", 12, Color8(159, 224, 138))
	else:
		_label(tx, Arbol.WHY.get(st, ""), 12, C_RED)
	var lb := _button(h, "Aprender · 1 punto", func(): _learn(id), true)
	lb.disabled = st != "ok"
	lb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lb.focus_mode = Control.FOCUS_NONE

func _select(id: String) -> void:
	sel = id
	_show_info(id)
	for b in _root.find_children("N_*", "", true, false):
		b.queue_redraw()

func _learn(id: String) -> void:
	sel = id
	if sim.arbol.learn(id):
		_rebuild()
	else:
		_show_info(id)

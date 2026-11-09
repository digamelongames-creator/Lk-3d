class_name Hud
extends Control
## Interfaz en partida, con la disposición del juego web a pantalla completa:
## vida y nivel abajo a la izquierda, oleada y puntos abajo a la derecha, habilidades y poción abajo en el centro,
## experiencia en una franja al pie, minimapa arriba a la derecha y el cartel grande en el centro.

var sim: Sim
var fx   # Fx3D (o ViewFx en 2D): solo se leen banner_t, banner_top y banner_main
var ghost_hp := 1.0
var hit_shake := 0.0
var _last_hp := -1.0
var mini_img: Image
var mini_tex: ImageTexture
var big_map := false
var show_hint := ""
var _icons: Array = []
var _icons_cls := ""
var _blink_t := 0.0

const C_LINE := Color8(61, 50, 40)
const C_GOLD := Color8(201, 162, 74)
const C_FG := Color8(239, 227, 204)
const C_MUTED := Color8(168, 151, 124)
const C_TORCH := Color8(232, 163, 58)
const C_PANEL := Color(10 / 255.0, 7 / 255.0, 5 / 255.0, .62)
const C_PANEL_LINE := Color(107 / 255.0, 84 / 255.0, 52 / 255.0, .8)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_img = Image.create(DungeonGen.GW, DungeonGen.GH, false, Image.FORMAT_RGBA8)
	mini_tex = ImageTexture.create_from_image(mini_img)

func _process(dt: float) -> void:
	if sim == null or sim.p == null:
		return
	_blink_t += dt
	var p := sim.p
	var f: float = clampf(p.hp / p.st.maxHp, 0, 1)
	if _last_hp >= 0 and p.hp < _last_hp:
		hit_shake = .25
	_last_hp = p.hp
	# la barra «fantasma» baja con retraso, como en la web
	ghost_hp = f if f > ghost_hp else lerpf(ghost_hp, f, minf(1, dt * 4))
	hit_shake = maxf(0, hit_shake - dt)
	if sim.map_dirty:
		_rebuild_minimap()
	queue_redraw()

func _rebuild_minimap() -> void:
	sim.map_dirty = false
	var G := sim.G
	var E := sim.explored
	var L := sim.L
	var corr: PackedByteArray = L.corr
	mini_img.fill(Color(0, 0, 0, 0))
	var AL: PackedByteArray = L.get("alt", PackedByteArray())
	for y in DungeonGen.GH:
		for x in DungeonGen.GW:
			var i := y * DungeonGen.GW + x
			if not E[i]:
				continue
			var t := G[i]
			var c = null
			if t == 0:
				var nb := false
				for j in range(-1, 2):
					for k in range(-1, 2):
						if sim.tile_at(x + k, y + j) != 0:
							nb = true
				if nb: c = ViewFx.col("#4a4858")
			elif t == DungeonGen.ABISMO: c = null
			elif t == 2: c = ViewFx.col("#2f6f80")
			elif t == 9: c = ViewFx.col("#8a6038")
			elif t == DungeonGen.DOWN: c = ViewFx.col("#ff8a3a")
			elif t == DungeonGen.UP: c = ViewFx.col("#e8e0cc")
			elif t == DungeonGen.DECOR: c = ViewFx.col("#6a5038")
			elif not AL.is_empty() and AL[i] == 2: c = ViewFx.col("#d8cfbd")
			elif not AL.is_empty() and AL[i] == 1: c = ViewFx.col("#bdb3a0")
			else: c = ViewFx.col("#7d7466") if corr[i] else ViewFx.col("#a39886")
			if c != null:
				mini_img.set_pixel(x, y, c)
	mini_tex.update(mini_img)

func panel(r: Rect2) -> void:
	draw_rect(r, C_PANEL)
	draw_rect(r, C_PANEL_LINE, false, 1)

func _draw() -> void:
	if sim == null or sim.p == null:
		return
	var W := size.x
	var H := size.y
	var p := sim.p
	if _icons_cls != p.cls_key():
		_icons_cls = p.cls_key()
		_icons = []
		for i in 3:
			_icons.append(load("res://assets/web/gen/icon_%s_%d.png" % [_icons_cls, i]))
	var font := Fonts.px(600)
	var font5 := Fonts.px(500)
	var gothic := Fonts.gothic(800)
	# ---- arriba a la izquierda: dónde estás, equipo, puntos, nivel y cuentas (sobre el panel de mármol) ----
	var left := 0
	for e in sim.enemies:
		if not e.dying:
			left += 1
	var lugar := "%s · zona segura" % Ciudad.NOMBRE if Ciudad.es_ciudad(sim.L) else "Oleada %d · quedan %d" % [sim.wave, left]
	var cab := Rect2(4, 4, 300, 118)
	if not UiArte.caja(self, "panel", cab, 40, 14):
		panel(cab)
	Fonts.outlined(self, font5, Vector2(18, 31), lugar, 19, C_FG, 0)
	Fonts.outlined(self, font5, Vector2(18, 51), "I · Equipo" + (" · %d nuevo%s" % [p.rn_new, "" if p.rn_new == 1 else "s"] if p.rn_new > 0 else ""), 13, Color8(255, 210, 90) if p.rn_new > 0 else C_MUTED, 0)
	var pend := p.pts + p.skp
	Fonts.outlined(self, font5, Vector2(18, 69), ("+%d puntos · Tab / T" % pend) if pend > 0 else "Tab · Personaje · T · Árbol", 13, Color8(255, 210, 90) if pend > 0 and int(_blink_t * 2) % 2 == 0 else C_MUTED, 0)
	Fonts.outlined(self, Fonts.px(700), Vector2(18, 90), "Nivel %d" % p.lvl, 14, C_GOLD, 0, 3, Color.BLACK)
	Fonts.outlined(self, font5, Vector2(cab.end.x - 16, 90), "Oro %d · Llaves %d" % [p.gold, p.keys], 13, C_MUTED, 2, 3, Color.BLACK)
	Fonts.outlined(self, font5, Vector2(18, 108), "Bajas %d · Puntos %d" % [sim.kills, sim.score], 13, C_MUTED, 0, 3, Color.BLACK)
	if p.chain >= 3:
		var mult := 1 + mini(4, int(floorf(p.chain / 5.0)))
		var big := p.chain_t > 1.2
		Fonts.outlined(self, font, Vector2(W - 12, 222 + (4 if big else 0)), "%d golpes" % p.chain, 34 if big else 30, ViewFx.col("#ffd25a") if mult > 1 else C_FG, 2)
		if mult > 1:
			Fonts.outlined(self, font5, Vector2(W - 12, 246), "puntos x%d" % mult, 19, ViewFx.col("#e8a33a"), 2)
	# ---- vida del campeón a la vista (arriba en el centro) ----
	# el jefe del piso tiene prioridad; después campeones, jefes de sala y élites
	var arriba: Ent.Enemy = null
	for e in sim.enemies:
		if (e.jefe or e.type == "champ" or e.boss != "" or e.rare) and not e.dying and e.state != "idle" and e.los and JS.hypot(e.x - p.x, e.y - p.y) < (260.0 if e.jefe else 118 * 1.15):
			if arriba == null or (e.jefe and not arriba.jefe):
				arriba = e
	if arriba != null:
		var e := arriba
		var cw := 420.0 if e.jefe else 320.0
		var bh := 8.0 if e.jefe else 4.0
		var cx := W / 2 - cw / 2 - 80
		Fonts.outlined(self, font, Vector2(cx + cw / 2, 30), e.title, 22 if e.jefe else 19, ViewFx.col("#ff5a3a" if e.jefe else "#ff9a3a"), 1, 3, Color.BLACK)
		draw_rect(Rect2(cx - 2, 38, cw + 4, bh + 4), ViewFx.col("#0a0607"))
		draw_rect(Rect2(cx, 40, cw, bh), ViewFx.col("#26090d"))
		draw_rect(Rect2(cx, 40, maxf(0, cw * e.hp / e.max_hp), bh), ViewFx.col("#a01020" if e.jefe else "#6a0d1a"))
		if e.escudo_max > 0 and e.escudo > 0:
			draw_rect(Rect2(cx, 40 + bh - 2, cw * e.escudo / e.escudo_max, 2), ViewFx.col("#7cc4ff"))
		var sub: String = "Jefe del piso" if e.jefe else (Sim.PODER_N.get(e.poder, "") if e.poder != "" else "")
		if sub != "":
			Fonts.outlined(self, font5, Vector2(cx + cw / 2, 40 + bh + 18), sub, 14, ViewFx.col("#d8c8a8"), 1, 3, Color.BLACK)
	# ---- minimapa (arriba a la derecha) ----
	var s := 3.6
	var mw := DungeonGen.GW * s
	var mh := DungeonGen.GH * s
	var x0 := W - mw - 18
	var y0 := 18.0
	if not UiArte.caja(self, "panel", Rect2(x0 - 12, y0 - 12, mw + 24, mh + 24), 40, 14):
		draw_rect(Rect2(x0 - 4, y0 - 4, mw + 8, mh + 8), Color(10 / 255.0, 8 / 255.0, 6 / 255.0, .62))
		draw_rect(Rect2(x0 - 4, y0 - 4, mw + 8, mh + 8), Color(239 / 255.0, 227 / 255.0, 204 / 255.0, .22), false, 1)
	draw_texture_rect(mini_tex, Rect2(x0, y0, mw, mh), false)
	if sim.L.fount != null and sim.explored[sim.cell_of(sim.CY) * DungeonGen.GW + sim.cell_of(sim.CX)]:
		draw_rect(Rect2(x0 + sim.CX / Sim.TS * s - 2, y0 + (sim.CY - 8) / Sim.TS * s - 2, 5, 5), ViewFx.col("#5fb4d6"))
	if int(_blink_t * 3) % 2 == 0:
		draw_rect(Rect2(x0 + p.x / Sim.TS * s - 2, y0 + (p.y - 6) / Sim.TS * s - 2, 5, 5), ViewFx.col("#ffd25a"))
	# ---- abajo: orbe de vida, habilidades y experiencia en el centro, orbe de maná (piezas de Diego) ----
	var u := H / 1080.0
	var oh := 236.0 * u
	var tam_i: Array = UiArte.med("orbe_marco_izq").get("tam", [640, 586])
	var tam_d: Array = UiArte.med("orbe_marco_der").get("tam", [640, 588])
	var ri := Rect2(6 * u, H - oh - 2 * u, oh * tam_i[0] / tam_i[1], oh)
	var wd: float = oh * tam_d[0] / tam_d[1]
	var rd := Rect2(W - wd - 6 * u, H - oh - 2 * u, wd, oh)
	if hit_shake > 0:
		ri.position.x += sin(hit_shake * 80) * 3
	var f: float = clampf(p.hp / p.st.maxHp, 0, 1)
	var hv := _orbe("orbe_marco_izq", "orbe_vida_liquido", ri, f, ghost_hp, Color8(168, 35, 26))
	Fonts.outlined(self, font, hv.get_center() + Vector2(0, 6 * u), "%d / %d" % [maxi(0, ceili(p.hp)), int(p.st.maxHp)] + (" +%d" % JS.roundi(p.shield) if p.shield > 0 else ""), int(17 * u), C_FG, 1, 4, Color.BLACK)
	var con_mana: bool = p.st.maxMana > 0
	var fm: float = clampf(p.mana / p.st.maxMana, 0, 1) if con_mana else 0.0
	var hm := _orbe("orbe_marco_der", "orbe_mana_liquido", rd, fm, fm, Color8(60, 100, 230))
	if con_mana:
		Fonts.outlined(self, font, hm.get_center() + Vector2(0, 6 * u), "%d / %d" % [maxi(0, int(p.mana)), int(p.st.maxMana)], int(17 * u), C_FG, 1, 4, Color.BLACK)
	# barra de habilidades y poción
	var bs := 72.0 * u
	var gap := 10.0 * u
	var total_w := 4 * bs + 3 * gap
	var kx := W / 2 - total_w / 2
	var ew := total_w + 200 * u
	var tam_e: Array = UiArte.med("exp_marco").get("tam", [1100, 49])
	var eh: float = ew * tam_e[1] / tam_e[0]
	var ey := H - eh - 10 * u
	var ky := ey - bs - 22 * u
	UiArte.caja(self, "panel", Rect2(kx - 22 * u, ky - 16 * u, total_w + 44 * u, bs + 32 * u), 40, 16 * u)
	for i in 4:
		var r := Rect2(kx + i * (bs + gap), ky, bs, bs)
		var dentro := r.grow(-bs * .17)
		var on := i < 3 and sim.skill_on(i)
		var ht := UiArte.tex("hueco_habilidad")
		if ht != null:
			draw_texture_rect(ht, r.grow(bs * .06), false, Color(1.35, .85, .75) if on else Color.WHITE)
		else:
			draw_rect(r, Color(58 / 255.0, 36 / 255.0, 24 / 255.0, .85))
			draw_rect(dentro, Color(18 / 255.0, 12 / 255.0, 8 / 255.0, .55))
		if i < 3:
			draw_texture_rect(_icons[i], dentro.grow(-dentro.size.x * .08), false)
			var sk: Dictionary = p.sk[i]
			var def: Dictionary = Sim.SK[p.skills[i]]
			if sk.cd > 0 and sk.t <= 0:
				var k: float = minf(1, sk.cd / maxf(.01, def.cd - def.dur))
				draw_rect(Rect2(dentro.position.x, dentro.end.y - dentro.size.y * k, dentro.size.x, dentro.size.y * k), Color(0, 0, 0, .7))
				Fonts.outlined(self, Fonts.px(700), dentro.get_center() + Vector2(0, 7 * u), str(ceili(sk.cd)), int(19 * u), Color.WHITE, 1, 3, Color.BLACK)
			if sk.t > 0 and def.dur > 0:
				draw_rect(Rect2(dentro.position.x, dentro.end.y - 3, dentro.size.x * minf(1, sk.t / def.dur), 3), ViewFx.col("#ff5a46"))
			if on:
				draw_rect(dentro, ViewFx.col("#ff5a46"), false, 2)
			Fonts.outlined(self, Fonts.px(700), r.position + Vector2(5 * u, 17 * u), str(i + 1), int(14 * u), Color8(243, 220, 160), 0, 3, Color.BLACK)
			Fonts.outlined(self, font5, Vector2(r.get_center().x, r.end.y + 12 * u), Idioma.t(def.n).split(" ")[0], int(11 * u), Color8(233, 207, 138), 1, 3, Color.BLACK)
		else:
			var pt := Atlas.potion
			var ps := minf(dentro.size.x / pt.get_width(), dentro.size.y / pt.get_height()) * .8
			draw_texture_rect(pt, Rect2(dentro.get_center() - pt.get_size() * ps / 2, pt.get_size() * ps), false)
			var pot_w := sim.pot_wait()
			if pot_w > 0:
				var k2 := pot_w / Sim.POT_CD
				draw_rect(Rect2(dentro.position.x, dentro.end.y - dentro.size.y * k2, dentro.size.x, dentro.size.y * k2), Color(0, 0, 0, .7))
				Fonts.outlined(self, Fonts.px(700), dentro.get_center() + Vector2(0, 7 * u), str(ceili(pot_w)), int(19 * u), Color.WHITE, 1, 3, Color.BLACK)
			Fonts.outlined(self, Fonts.px(700), r.position + Vector2(5 * u, 17 * u), "Q", int(14 * u), Color8(243, 220, 160), 0, 3, Color.BLACK)
			Fonts.outlined(self, Fonts.px(700), dentro.end + Vector2(-2, -3), str(Items.potion_count(p)), int(16 * u), Color.WHITE, 2, 3, Color.BLACK)
	# experiencia: marco y relleno dorado debajo de las habilidades
	var need := sim.xp_need(p.lvl)
	var xf := 1.0 if p.lvl >= Sim.MAXLVL else float(p.xp) / need
	var em := UiArte.tex("exp_marco")
	var er := UiArte.tex("exp_relleno")
	var re := Rect2(W / 2 - ew / 2, ey, ew, eh)
	var dentro_e := Rect2(re.position + Vector2(re.size.x * EXP_HUECO.position.x, re.size.y * EXP_HUECO.position.y), re.size * EXP_HUECO.size)
	draw_rect(dentro_e, Color(0, 0, 0, .7))
	if er != null and xf > 0:
		var ts := er.get_size()
		draw_texture_rect_region(er, Rect2(dentro_e.position, Vector2(dentro_e.size.x * xf, dentro_e.size.y)), Rect2(0, 0, ts.x * xf, ts.y))
	elif xf > 0:
		draw_rect(Rect2(dentro_e.position, Vector2(dentro_e.size.x * xf, dentro_e.size.y)), Color8(214, 160, 40))
	if em != null:
		draw_texture_rect(em, re, false)
	# ---- pieza del suelo a tus pies: comparada con lo que llevas puesto ----
	_tip_suelo(W, ky - 44, font5)
	# ---- aviso de «Usar» ----
	if show_hint != "":
		Fonts.outlined(self, font, Vector2(W / 2, ky - 18), show_hint, 15, ViewFx.col("#ffd25a"), 1, 4, Color.BLACK)
	# ---- cartel grande ----
	if fx.banner_t > 0:
		var a := minf(1, fx.banner_t / .25) * minf(1, (1.6 - fx.banner_t) / .25 + .2)
		var cy := H * .36
		var c := C_FG
		c.a = a
		var t2 := C_TORCH
		t2.a = a
		Fonts.outlined(self, Fonts.px(700), Vector2(W / 2, cy), Idioma.t(fx.banner_top).to_upper(), 16, t2, 1, 5, Color.BLACK)
		Fonts.outlined(self, Fonts.px(700), Vector2(W / 2, cy + 44), fx.banner_main, 40, c, 1, 8, Color.BLACK)
	# ---- fundido al bajar ----
	if sim.fade > 0:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, minf(1, sim.fade)))
		if sim.phase == "descend" and sim.fade > .5:
			var c := C_TORCH
			c.a = (sim.fade - .5) * 2
			Fonts.outlined(self, Fonts.px(700), Vector2(W / 2, H / 2), "Descendiendo…", 30, c, 1, 4, Color.BLACK)
	if big_map:
		_draw_big_map(W, H)

## parte de dentro del marco de la experiencia (fracciones de la imagen)
const EXP_HUECO := Rect2(.055, .3, .89, .42)

## orbe: fondo oscuro, líquido que baja de arriba abajo (con el «fantasma» detrás) y el marco encima;
## devuelve el hueco del marco
func _orbe(marco: String, liquido: String, r: Rect2, frac: float, fantasma: float, reserva: Color) -> Rect2:
	var hu := UiArte.hueco(marco, r)
	var ce := hu.get_center()
	var rad := minf(hu.size.x, hu.size.y) / 2
	draw_circle(ce, rad * 1.02, Color(.03, .02, .02, .92))
	var dr := Rect2(ce - Vector2(rad, rad) * 1.04, Vector2(rad, rad) * 2.08)
	var liq := UiArte.tex(liquido)
	if liq != null:
		_liquido(liq, dr, fantasma, Color(1, 1, 1, .3))
		_liquido(liq, dr, frac, Color.WHITE)
	elif frac > 0:
		draw_circle(ce, rad * frac, reserva)
	var mt := UiArte.tex(marco)
	if mt != null:
		draw_texture_rect(mt, r, false)
	return hu

func _liquido(t: Texture2D, dr: Rect2, frac: float, mod: Color) -> void:
	if frac <= 0:
		return
	var ts := t.get_size()
	draw_texture_rect_region(t, Rect2(dr.position.x, dr.position.y + dr.size.y * (1 - frac), dr.size.x, dr.size.y * frac), Rect2(0, ts.y * (1 - frac), ts.x, ts.y * frac), mod)

func _draw_big_map(W: float, H: float) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(6 / 255.0, 6 / 255.0, 10 / 255.0, .92))
	var s := 12.0
	var mw := DungeonGen.GW * s
	var mh := DungeonGen.GH * s
	var x0 := (W - mw) / 2
	var y0 := (H - mh) / 2 + 10
	draw_rect(Rect2(x0 - 3, y0 - 3, mw + 6, mh + 6), Color8(13, 14, 18))
	draw_texture_rect(mini_tex, Rect2(x0, y0, mw, mh), false)
	var p := sim.p
	var pulse := 6 + sin(_blink_t * 6) * 2
	draw_circle(Vector2(x0 + p.x / Sim.TS * s, y0 + (p.y - 6) / Sim.TS * s), pulse + 3, Color(228 / 255.0, 155 / 255.0, 76 / 255.0, .35))
	draw_circle(Vector2(x0 + p.x / Sim.TS * s, y0 + (p.y - 6) / Sim.TS * s), 5, Color8(228, 155, 76))
	Fonts.outlined(self, Fonts.px(700), Vector2(W / 2, y0 - 16), ("Mapa de %s" % Ciudad.NOMBRE if Ciudad.es_ciudad(sim.L) else "Mapa de la mazmorra · Oleada %d" % sim.wave), 22, ViewFx.col("#e9cf8a"))
	var st: Dictionary = sim.L.stairs_cell
	var seen: bool = sim.explored[st.cy * DungeonGen.GW + st.cx] != 0
	var left := 0
	for e in sim.enemies:
		if not e.dying:
			left += 1
	Fonts.outlined(self, Fonts.px(500), Vector2(W / 2, y0 + mh + 26), ("Escalera a la vista" if seen else "Escalera sin descubrir") + " · quedan %d · M cierra" % left, 16, C_MUTED)


## ventanita encima del aviso de «Usar» con la pieza más cercana del suelo y sus flechas (Comparar)
func _tip_suelo(W: float, abajo: float, f: Font) -> void:
	var l = sim.nearest_loot()
	if l == null or not l.item.get("gear", false):
		return
	var it: Dictionary = l.item
	var p := sim.p
	var own: bool = it.cls == p.cls_key()
	var lineas := [[String(it.name), ViewFx.col(Items.RQ_C[clampi(int(it.q), 0, 3)]), 15],
		["%s · %s" % [Items.slot_name(it.cls, it.slot), Items.RQ_N[clampi(int(it.q), 0, 3)]] + ("" if own else " · solo " + Items.CLS_N[it.cls]), C_MUTED, 12]]
	var cur = p.eq.get(it.slot) if own else null
	for x in Comparar.lineas(it, cur, 13):
		lineas.append(x)
	if own and cur != null:
		lineas.append(["Comparado con " + String(cur.name), C_MUTED, 11])
	var w := 300.0
	var h := 10.0
	for x in lineas:
		h += x[2] + 5
	var r := Rect2(W / 2 - w / 2, abajo - h, w, h)
	if not UiArte.caja(self, "panel", r.grow(6), 40, 12):
		draw_rect(r, Color(14 / 255.0, 10 / 255.0, 8 / 255.0, .88))
		draw_rect(r, Color8(138, 106, 60), false, 1)
	var y := r.position.y + 6
	for x in lineas:
		y += x[2]
		Fonts.outlined(self, f, Vector2(W / 2, y), x[0], x[2], x[1], 1, 3, Color.BLACK)
		y += 5

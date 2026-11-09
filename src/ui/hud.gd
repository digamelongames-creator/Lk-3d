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
	# ---- oleada y enemigos que quedan (arriba a la izquierda) ----
	var left := 0
	for e in sim.enemies:
		if not e.dying:
			left += 1
	var lugar := "%s · zona segura" % Ciudad.NOMBRE if Ciudad.es_ciudad(sim.L) else "Oleada %d · quedan %d" % [sim.wave, left]
	Fonts.outlined(self, font5, Vector2(12, 26), lugar, 19, C_FG, 0)
	Fonts.outlined(self, font5, Vector2(12, 46), "I · Equipo" + (" · %d nuevo%s" % [p.rn_new, "" if p.rn_new == 1 else "s"] if p.rn_new > 0 else ""), 13, Color8(255, 210, 90) if p.rn_new > 0 else C_MUTED, 0)
	var pend := p.pts + p.skp
	Fonts.outlined(self, font5, Vector2(12, 64), ("+%d puntos · Tab / T" % pend) if pend > 0 else "Tab · Personaje · T · Árbol", 13, Color8(255, 210, 90) if pend > 0 and int(_blink_t * 2) % 2 == 0 else C_MUTED, 0)
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
	var x0 := W - mw - 12
	var y0 := 12.0
	draw_rect(Rect2(x0 - 4, y0 - 4, mw + 8, mh + 8), Color(10 / 255.0, 8 / 255.0, 6 / 255.0, .62))
	draw_rect(Rect2(x0 - 4, y0 - 4, mw + 8, mh + 8), Color(239 / 255.0, 227 / 255.0, 204 / 255.0, .22), false, 1)
	draw_texture_rect(mini_tex, Rect2(x0, y0, mw, mh), false)
	if sim.L.fount != null and sim.explored[sim.cell_of(sim.CY) * DungeonGen.GW + sim.cell_of(sim.CX)]:
		draw_rect(Rect2(x0 + sim.CX / Sim.TS * s - 2, y0 + (sim.CY - 8) / Sim.TS * s - 2, 5, 5), ViewFx.col("#5fb4d6"))
	if int(_blink_t * 3) % 2 == 0:
		draw_rect(Rect2(x0 + p.x / Sim.TS * s - 2, y0 + (p.y - 6) / Sim.TS * s - 2, 5, 5), ViewFx.col("#ffd25a"))
	# ---- vida y nivel (abajo a la izquierda) ----
	var pw := minf(W * .34, 300)
	var ph := 64.0
	var px0 := 10.0
	var py0 := H - 16 - ph
	if hit_shake > 0:
		px0 += sin(hit_shake * 80) * 3
	panel(Rect2(px0, py0, pw, ph))
	var bx := px0 + 9
	var by := py0 + 8
	var bw := pw - 18
	draw_rect(Rect2(bx - 2, by - 2, bw + 4, 20), Color8(12, 10, 8))
	draw_rect(Rect2(bx - 1, by - 1, bw + 2, 18), C_LINE)
	draw_rect(Rect2(bx, by, bw, 16), Color8(18, 12, 8))
	var f: float = clampf(p.hp / p.st.maxHp, 0, 1)
	draw_rect(Rect2(bx, by, bw * ghost_hp, 16), Color8(240, 224, 192))
	if f > 0:
		draw_rect(Rect2(bx, by, bw * f, 8), Color8(224, 83, 62))
		draw_rect(Rect2(bx, by + 8, bw * f, 8), Color8(168, 35, 26))
	Fonts.outlined(self, font, Vector2(bx + bw / 2, by + 13), "%d / %d" % [maxi(0, ceili(p.hp)), int(p.st.maxHp)] + (" +%d" % JS.roundi(p.shield) if p.shield > 0 else ""), 13, C_FG, 1, 3, Color.BLACK)
	if p.st.maxMana > 0:
		draw_rect(Rect2(bx, by + 19, bw, 5), Color8(10, 14, 30))
		draw_rect(Rect2(bx, by + 19, bw * clampf(p.mana / p.st.maxMana, 0, 1), 5), Color8(80, 130, 255))
	Fonts.outlined(self, Fonts.px(700), Vector2(bx, by + 38), "Nivel %d" % p.lvl, 14, C_GOLD, 0, 3, Color.BLACK)
	var extra := "Oro %d · Llaves %d" % [p.gold, p.keys]
	Fonts.outlined(self, font5, Vector2(bx + bw, by + 38), extra, 13, C_MUTED, 2, 3, Color.BLACK)
	# ---- oleada, bajas y puntos (abajo a la derecha) ----
	var sw := 150.0
	var sh := 64.0
	var sx := W - 10 - sw
	var sy := H - 16 - sh
	panel(Rect2(sx, sy, sw, sh))
	var rows := [["Oleada", sim.wave], ["Bajas", sim.kills], ["Puntos", sim.score]]
	for i in rows.size():
		var yy := sy + 19 + i * 18
		Fonts.outlined(self, font5, Vector2(sx + 10, yy), rows[i][0], 14, C_MUTED, 0, 2, Color.BLACK)
		Fonts.outlined(self, font, Vector2(sx + sw - 10, yy), str(rows[i][1]), 14, C_FG, 2, 2, Color.BLACK)
	# ---- habilidades y poción (abajo en el centro) ----
	var bs := 50.0
	var gap := 8.0
	var total_w := 4 * bs + 3 * gap
	var kx := W / 2 - total_w / 2
	var ky := H - 16 - bs
	for i in 4:
		var r := Rect2(kx + i * (bs + gap), ky, bs, bs)
		var on := i < 3 and sim.skill_on(i)
		draw_rect(r.grow(2), Color8(12, 10, 8))
		draw_rect(r, Color(58 / 255.0, 36 / 255.0, 24 / 255.0, .85))
		draw_rect(r.grow(-6), Color(18 / 255.0, 12 / 255.0, 8 / 255.0, .55))
		if i < 3:
			draw_texture_rect(_icons[i], Rect2(r.position + Vector2(9, 9), Vector2(32, 32)), false)
			var sk: Dictionary = p.sk[i]
			var def: Dictionary = Sim.SK[p.skills[i]]
			if sk.cd > 0 and sk.t <= 0:
				var k: float = minf(1, sk.cd / maxf(.01, def.cd - def.dur))
				draw_rect(Rect2(r.position.x, r.end.y - bs * k, bs, bs * k), Color(0, 0, 0, .7))
				Fonts.outlined(self, Fonts.px(700), r.get_center() + Vector2(0, 6), str(ceili(sk.cd)), 16, Color.WHITE, 1, 3, Color.BLACK)
			if sk.t > 0 and def.dur > 0:
				draw_rect(Rect2(r.position.x, r.end.y - 3, bs * minf(1, sk.t / def.dur), 3), ViewFx.col("#ff5a46"))
			draw_rect(r.grow(1), ViewFx.col("#ff5a46") if on else C_GOLD, false, 2)
			Fonts.outlined(self, Fonts.px(700), r.position + Vector2(4, 13), str(i + 1), 12, Color8(243, 220, 160), 0, 2, Color.BLACK)
			Fonts.outlined(self, font5, Vector2(r.get_center().x, r.end.y - 2), Idioma.t(def.n).split(" ")[0], 8, Color8(233, 207, 138), 1, 2, Color.BLACK)
		else:
			draw_rect(r.grow(1), Color8(138, 58, 42), false, 2)
			draw_texture_rect(Atlas.potion, Rect2(r.get_center() - Vector2(Atlas.potion.get_width(), Atlas.potion.get_height()), Vector2(Atlas.potion.get_width(), Atlas.potion.get_height()) * 2), false)
			var pot_w := sim.pot_wait()
			if pot_w > 0:
				var k2 := pot_w / Sim.POT_CD
				draw_rect(Rect2(r.position.x, r.end.y - bs * k2, bs, bs * k2), Color(0, 0, 0, .7))
				Fonts.outlined(self, Fonts.px(700), r.get_center() + Vector2(0, 6), str(ceili(pot_w)), 16, Color.WHITE, 1, 3, Color.BLACK)
			Fonts.outlined(self, Fonts.px(700), r.position + Vector2(4, 13), "Q", 12, Color8(243, 220, 160), 0, 2, Color.BLACK)
			Fonts.outlined(self, Fonts.px(700), r.end + Vector2(-4, -4), str(Items.potion_count(p)), 14, Color.WHITE, 2, 3, Color.BLACK)
	# ---- experiencia (franja al pie) ----
	var need := sim.xp_need(p.lvl)
	var xf := 1.0 if p.lvl >= Sim.MAXLVL else float(p.xp) / need
	draw_rect(Rect2(0, H - 8, W, 8), Color(18 / 255.0, 12 / 255.0, 8 / 255.0, .75))
	draw_rect(Rect2(0, H - 9, W, 1), C_PANEL_LINE)
	draw_rect(Rect2(0, H - 8, W * xf, 4), Color8(184, 155, 255))
	draw_rect(Rect2(0, H - 4, W * xf, 4), Color8(106, 68, 216))
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
	draw_rect(r, Color(14 / 255.0, 10 / 255.0, 8 / 255.0, .88))
	draw_rect(r, Color8(138, 106, 60), false, 1)
	var y := r.position.y + 6
	for x in lineas:
		y += x[2]
		Fonts.outlined(self, f, Vector2(W / 2, y), x[0], x[2], x[1], 1, 3, Color.BLACK)
		y += 5

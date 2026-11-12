extends CanvasLayer
## Hangar antes de cada combate: tienda de módulos, almacén y la mochila 4×4.
## Clic izquierdo coloca la pieza que llevas en la mano; clic derecho (o R) la gira;
## clic en una pieza colocada la coge. El mecha de detrás se monta en directo.

signal cambio
signal a_la_arena

const Modulos = preload("res://scripts/modulos.gd")
const CELDA := 110.0

var datos: Dictionary  # {"construccion", "almacen", "chatarra", "rival"}
var en_mano = null     # pieza (Dictionary) o null

var chatarra_txt: Label
var tienda: VBoxContainer
var almacen: VBoxContainer
var info: Label
var stats_txt: RichTextLabel
var rival_txt: RichTextLabel
var boton_arena: Button
var boton_guardar: Button
var boton_vender: Button
var rejilla: Control


class Rejilla extends Control:
	var hangar
	var raton := Vector2i(-1, -1)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			raton = Vector2i(floori(e.position.x / hangar.CELDA), floori(e.position.y / hangar.CELDA))
			queue_redraw()
		elif e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_LEFT:
				hangar.clic_celda(raton)
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				hangar.girar()
			queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			raton = Vector2i(-1, -1)
			queue_redraw()

	func _draw() -> void:
		var M = hangar.Modulos
		var c: float = hangar.CELDA
		draw_rect(Rect2(-8, -8, c * 4 + 16, c * 4 + 16), Color(0.05, 0.05, 0.07, 0.85))
		for x in 4:
			for y in 4:
				draw_rect(Rect2(x * c + 3, y * c + 3, c - 6, c - 6), Color(1, 1, 1, 0.07))
		var cons: Array = hangar.datos.construccion
		for p in cons:
			_pieza(p, M, Color(1, 1, 1, 1))
		# vecinos que se refuerzan: una raya entre la batería/recargador y el generador
		for p in cons:
			var tipo: String = M.CATALOGO[p.id].tipo
			if tipo != "bateria" and tipo != "recarga":
				continue
			for v in M.vecinos(cons, p):
				var tv: String = M.CATALOGO[v.id].tipo
				if tv == "prop" or tv == "escudo":
					draw_line(_centro(p, M), _centro(v, M), Color(1, 1, 0.6, 0.9), 4.0)
		var m = hangar.en_mano
		if m != null and raton.x >= 0:
			m.pos = raton
			var ok: bool = M.cabe(cons, m)
			_pieza(m, M, Color(0.6, 1, 0.6, 0.6) if ok else Color(1, 0.4, 0.4, 0.6))

	func _centro(p, M) -> Vector2:
		var t: Vector2i = M.tam(p)
		var c: float = hangar.CELDA
		return Vector2((p.pos.x + t.x * 0.5) * c, (p.pos.y + t.y * 0.5) * c)

	func _pieza(p, M, tinte: Color) -> void:
		var t: Vector2i = M.tam(p)
		var c: float = hangar.CELDA
		var r := Rect2(p.pos.x * c + 4, p.pos.y * c + 4, t.x * c - 8, t.y * c - 8)
		var col: Color = M.CATALOGO[p.id].color
		draw_rect(r, col * tinte)
		draw_rect(r, Color(0, 0, 0, 0.6), false, 3.0)
		var f := ThemeDB.fallback_font
		var nombre: String = M.CATALOGO[p.id].nombre
		var corto: String = nombre.replace("Generador de ", "").replace("Generador", "Gen.").replace(" pequeño", " peq.")
		draw_string(f, r.position + Vector2(8, 24), corto, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 17, Color(0, 0, 0, 0.9 * tinte.a))


func _label(tam: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l


func _panel(izq: float, der: float) -> VBoxContainer:
	var fondo := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.06, 0.08, 0.82)
	s.set_corner_radius_all(8)
	fondo.add_theme_stylebox_override("panel", s)
	fondo.anchor_left = izq
	fondo.anchor_right = der
	fondo.anchor_top = 0.04
	fondo.anchor_bottom = 0.96
	add_child(fondo)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 20
	v.offset_right = -20
	v.offset_top = 16
	v.offset_bottom = -16
	v.add_theme_constant_override("separation", 6)
	fondo.add_child(v)
	return v


func preparar(p_datos: Dictionary) -> void:
	datos = p_datos

	# izquierda: tienda y almacén
	var izq := _panel(0.02, 0.27)
	izq.add_child(_label(40, Color(1, 0.85, 0.3)))
	izq.get_child(0).text = "HANGAR"
	chatarra_txt = _label(26)
	izq.add_child(chatarra_txt)
	izq.add_child(_label(22, Color(0.7, 0.8, 1)))
	izq.get_child(2).text = "TIENDA"
	tienda = VBoxContainer.new()
	izq.add_child(tienda)
	for id in Modulos.CATALOGO:
		var d: Dictionary = Modulos.CATALOGO[id]
		var b := Button.new()
		b.text = "%s  ·  %d×%d  ·  %d chatarra" % [d.nombre, d.tam.x, d.tam.y, d.precio]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(comprar.bind(id))
		b.mouse_entered.connect(func(): info.text = "%s\n%s\nPeso %d · Reactor %d" % [d.nombre, d.texto, d.peso, d.consumo])
		tienda.add_child(b)
	info = _label(17, Color(0.85, 0.85, 0.85))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.y = 90
	izq.add_child(info)
	izq.add_child(_label(22, Color(0.7, 0.8, 1)))
	izq.get_child(izq.get_child_count() - 1).text = "ALMACÉN"
	almacen = VBoxContainer.new()
	izq.add_child(almacen)

	# derecha: mochila, números, rival y botón
	var der := _panel(0.71, 0.98)
	var t := _label(26, Color(1, 0.85, 0.3))
	t.text = "MOCHILA 4×4"
	der.add_child(t)
	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(CELDA * 4 + 16, CELDA * 4 + 16)
	der.add_child(hueco)
	rejilla = Rejilla.new()
	rejilla.hangar = self
	rejilla.position = Vector2(8, 8)
	rejilla.size = Vector2(CELDA * 4, CELDA * 4)
	hueco.add_child(rejilla)
	var ayuda := _label(15, Color(1, 1, 1, 0.6))
	ayuda.text = "Clic izq.: colocar o coger · Clic der./R: girar\nLas rayas amarillas: batería o recargador reforzando un generador."
	der.add_child(ayuda)
	var fila := HBoxContainer.new()
	boton_guardar = Button.new()
	boton_guardar.text = "Al almacén"
	boton_guardar.pressed.connect(guardar)
	fila.add_child(boton_guardar)
	boton_vender = Button.new()
	boton_vender.pressed.connect(vender)
	fila.add_child(boton_vender)
	der.add_child(fila)
	stats_txt = RichTextLabel.new()
	stats_txt.bbcode_enabled = true
	stats_txt.fit_content = true
	stats_txt.add_theme_font_size_override("normal_font_size", 18)
	der.add_child(stats_txt)
	rival_txt = RichTextLabel.new()
	rival_txt.bbcode_enabled = true
	rival_txt.fit_content = true
	rival_txt.add_theme_font_size_override("normal_font_size", 18)
	der.add_child(rival_txt)
	boton_arena = Button.new()
	boton_arena.text = "¡A LA ARENA!"
	boton_arena.add_theme_font_size_override("font_size", 32)
	boton_arena.custom_minimum_size.y = 64
	boton_arena.pressed.connect(func(): a_la_arena.emit())
	der.add_child(boton_arena)
	refrescar()


func _unhandled_input(e: InputEvent) -> void:
	if visible and e is InputEventKey and e.pressed and e.physical_keycode == KEY_R:
		girar()


func comprar(id: String) -> void:
	var precio: int = Modulos.CATALOGO[id].precio
	if datos.chatarra < precio:
		info.text = "No tienes chatarra suficiente (%d)." % precio
		return
	datos.chatarra -= precio
	guardar()
	en_mano = Modulos.pieza(id, Vector2i.ZERO)
	refrescar()


func coger_almacen(i: int) -> void:
	var id: String = datos.almacen[i]
	datos.almacen.remove_at(i)
	guardar()
	en_mano = Modulos.pieza(id, Vector2i.ZERO)
	refrescar()


func clic_celda(celda: Vector2i) -> void:
	if celda.x < 0 or celda.y < 0 or celda.x >= 4 or celda.y >= 4:
		return
	if en_mano != null:
		en_mano.pos = celda
		if Modulos.cabe(datos.construccion, en_mano):
			datos.construccion.append(en_mano)
			en_mano = null
	else:
		var p = Modulos.pieza_en(datos.construccion, celda)
		if p != null:
			datos.construccion.erase(p)
			en_mano = p
	refrescar()


func girar() -> void:
	if en_mano != null:
		en_mano.girado = not en_mano.girado
		rejilla.queue_redraw()


func guardar() -> void:
	if en_mano != null:
		datos.almacen.append(en_mano.id)
		en_mano = null
		refrescar()


func vender() -> void:
	if en_mano != null:
		datos.chatarra += Modulos.CATALOGO[en_mano.id].precio / 2
		en_mano = null
		refrescar()


func refrescar() -> void:
	if chatarra_txt == null:
		return
	chatarra_txt.text = "Chatarra: %d" % datos.chatarra
	for b in almacen.get_children():
		b.queue_free()
	for i in datos.almacen.size():
		var b := Button.new()
		b.text = Modulos.CATALOGO[datos.almacen[i]].nombre
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(coger_almacen.bind(i))
		almacen.add_child(b)
	boton_guardar.disabled = en_mano == null
	boton_vender.disabled = en_mano == null
	boton_vender.text = "Vender (+%d)" % (Modulos.CATALOGO[en_mano.id].precio / 2) if en_mano != null else "Vender"

	var s := Modulos.calcular(datos.construccion)
	var pr := Modulos.problemas(datos.construccion)
	var rojo := func(v, lim): return "[color=#ff6050]%d / %d[/color]" % [v, lim] if v > lim else "%d / %d" % [v, lim]
	var txt := "[b]Vida[/b] %d" % (1000 + s.vida_extra)
	txt += "\n[b]Escudo[/b] %d  (recarga %d/s)" % [s.escudo_max, s.escudo_regen] if s.escudo_max > 0 else "\n[b]Escudo[/b] [color=#ff6050]ninguno[/color]"
	txt += "\n[b]Propulsión[/b] %d  (recarga %d/s)" % [s.prop_max, s.prop_regen] if s.prop_max > 0 else "\n[b]Propulsión[/b] [color=#ff6050]ninguna: ni impulso ni vuelo[/color]"
	txt += "\n[b]Velocidad[/b] %d %%" % roundi(100.0 * (1.0 - 0.015 * s.peso))
	if s.calor < 1.0:
		txt += "\n[b]Cañón[/b] calienta %d %% menos" % roundi(100.0 * (1.0 - s.calor))
	txt += "\n[b]Peso[/b] %s    [b]Reactor[/b] %s" % [rojo.call(s.peso, Modulos.PESO_MAX), rojo.call(s.consumo, Modulos.REACTOR)]
	for p in pr:
		txt += "\n[color=#ff6050]%s[/color]" % p
	stats_txt.text = txt

	var r: Dictionary = datos.rival
	rival_txt.text = "\n[color=#ffd84d][b]Próximo rival (%d/%d): %s[/b][/color]\n%s\nPremio: %d chatarra" % [
		datos.rival_n + 1, Modulos.RIVALES.size(), r.nombre, r.texto, r.premio]
	boton_arena.disabled = not pr.is_empty() or en_mano != null
	boton_arena.text = "¡A LA ARENA!" if en_mano == null else "Suelta la pieza primero"
	rejilla.queue_redraw()
	cambio.emit()

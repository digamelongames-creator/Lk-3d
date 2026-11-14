extends CanvasLayer
## Editor de la mochila 4×4 (se abre desde el taller). Todo gratis por ahora.
## Clic en un módulo de la lista lo coge; clic izquierdo en la cuadrícula lo coloca;
## clic derecho (o R) lo gira; clic en una pieza colocada la coge. Esc o «Volver» al taller.

signal cambio
signal listo

const Modulos = preload("res://scripts/modulos.gd")
const Piezas = preload("res://scripts/piezas.gd")
const CELDA := 110.0

var datos: Dictionary  # {"montaje", "construccion", ...}
var en_mano = null

var tienda: VBoxContainer
var info: Label
var stats_txt: RichTextLabel
var boton_volver: Button
var boton_quitar: Button
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
		var nombre: String = M.CATALOGO[p.id].nombre
		var corto: String = nombre.replace("Generador de ", "").replace(" pequeño", " peq.")
		draw_string(ThemeDB.fallback_font, r.position + Vector2(8, 24), corto, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 17, Color(0, 0, 0, 0.9 * tinte.a))


func _label(tam: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l


func _boton(texto: String, tam := 17) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", tam)
	return b


func _panel(izq: float, der: float) -> VBoxContainer:
	var fondo := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.06, 0.08, 0.85)
	s.border_color = Color(1, 0.75, 0.25, 0.5)
	s.set_border_width_all(2)
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
	var izq := _panel(0.02, 0.27)
	var t := _label(36, Color(1, 0.85, 0.3))
	t.text = "MOCHILA · MÓDULOS"
	izq.add_child(t)
	tienda = VBoxContainer.new()
	izq.add_child(tienda)
	for id in Modulos.CATALOGO:
		var d: Dictionary = Modulos.CATALOGO[id]
		var b := _boton("%s  ·  %d×%d" % [d.nombre, d.tam.x, d.tam.y])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(coger.bind(id))
		b.mouse_entered.connect(func(): info.text = "%s\n%s\nPeso %d · Reactor %d" % [d.nombre, d.texto, d.peso, d.consumo])
		tienda.add_child(b)
	info = _label(17, Color(0.85, 0.85, 0.85))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.y = 110
	izq.add_child(info)

	var der := _panel(0.71, 0.98)
	var t2 := _label(26, Color(1, 0.85, 0.3))
	t2.text = "MOCHILA 4×4"
	der.add_child(t2)
	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(CELDA * 4 + 16, CELDA * 4 + 16)
	der.add_child(hueco)
	rejilla = Rejilla.new()
	rejilla.hangar = self
	rejilla.position = Vector2(8, 8)
	rejilla.size = Vector2(CELDA * 4, CELDA * 4)
	hueco.add_child(rejilla)
	var ayuda := _label(15, Color(1, 1, 1, 0.6))
	ayuda.text = "Clic izq.: colocar o coger · Clic der./R: girar\nRayas amarillas: batería o recargador reforzando un generador."
	der.add_child(ayuda)
	boton_quitar = _boton("Quitar la pieza de la mano")
	boton_quitar.pressed.connect(quitar)
	der.add_child(boton_quitar)
	stats_txt = RichTextLabel.new()
	stats_txt.bbcode_enabled = true
	stats_txt.fit_content = true
	stats_txt.add_theme_font_size_override("normal_font_size", 18)
	der.add_child(stats_txt)
	boton_volver = _boton("VOLVER AL TALLER", 28)
	boton_volver.custom_minimum_size.y = 56
	boton_volver.pressed.connect(func(): listo.emit())
	der.add_child(boton_volver)
	refrescar()


func _unhandled_input(e: InputEvent) -> void:
	if not visible or not (e is InputEventKey and e.pressed and not e.echo):
		return
	if e.physical_keycode == KEY_R:
		girar()
	elif e.physical_keycode == KEY_ESCAPE:
		quitar()
		listo.emit()
		get_viewport().set_input_as_handled()


func coger(id: String) -> void:
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


func quitar() -> void:
	en_mano = null
	refrescar()


func refrescar() -> void:
	if stats_txt == null:
		return
	boton_quitar.disabled = en_mano == null
	stats_txt.text = texto_totales(datos.montaje, datos.construccion)
	rejilla.queue_redraw()
	cambio.emit()


## Los números del mecha entero, para el hangar y el taller.
static func texto_totales(montaje: Dictionary, cons: Array) -> String:
	var s := Piezas.calcular(montaje, cons)
	var rojo := func(v, lim): return "[color=#ff6050]%d / %d[/color]" % [v, lim] if v > lim else "%d / %d" % [v, lim]
	var txt := "[b]Vida[/b] %d" % s.vida
	txt += "\n[b]Escudo[/b] %d  (recarga %d/s)" % [s.escudo_max, s.escudo_regen] if s.escudo_max > 0 else "\n[b]Escudo[/b] [color=#ff6050]ninguno[/color]"
	txt += "\n[b]Propulsión[/b] %d  (recarga %d/s)" % [s.prop_max, s.prop_regen] if s.prop_max > 0 else "\n[b]Propulsión[/b] [color=#ff6050]ninguna: ni impulso ni vuelo[/color]"
	txt += "\n[b]Velocidad[/b] %.1f m/s    [b]Giro[/b] %d °/s" % [s.vel, roundi(rad_to_deg(s.giro))]
	if s.calor < 1.0:
		txt += "\n[b]Armas[/b] calientan %d %% menos" % roundi(100.0 * (1.0 - s.calor))
	txt += "\n[b]Peso[/b] %s    [b]Reactor[/b] %s" % [rojo.call(s.peso, s.carga), rojo.call(s.consumo, s.reactor)]
	for p in Piezas.problemas(montaje, cons):
		txt += "\n[color=#ff6050]%s[/color]" % p
	return txt

class_name UiArte
## Piezas del HUD que dibujó Diego (assets/ui, convertidas con tools/hud_piezas.py).
## Si falta una pieza, tex() devuelve null y quien dibuja usa su reserva.

const DIR := "res://assets/ui/"

static var _tex := {}
static var _cajas := {}
static var _med = null

static func tex(nombre: String) -> Texture2D:
	if not _tex.has(nombre):
		var ruta := DIR + nombre + ".png"
		_tex[nombre] = load(ruta) if ResourceLoader.exists(ruta) else null
		if nombre == "orbe_mana_liquido" and _tex[nombre] == null:
			_tex[nombre] = _mana_de_reserva()
	return _tex[nombre]

static func med(nombre: String) -> Dictionary:
	if _med == null:
		_med = {}
		var f := FileAccess.open(DIR + "medidas.json", FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_med = d
	return _med.get(nombre, {})

## hueco del marco en píxeles de la imagen dibujada en r
static func hueco(nombre: String, r: Rect2) -> Rect2:
	var h: Array = med(nombre).get("hueco", [0.2, 0.2, 0.8, 0.8])
	return Rect2(r.position + Vector2(h[0], h[1]) * r.size, Vector2(h[2] - h[0], h[3] - h[1]) * r.size)

## pieza estirable (9 cortes): margen en píxeles de la imagen; borde = cuánto mide ese margen en pantalla
static func caja(ci: CanvasItem, nombre: String, r: Rect2, margen: float, borde: float, mod := Color.WHITE) -> bool:
	return caja_lados(ci, nombre, r, Vector4(margen, margen, margen, margen), borde / margen, mod)

## lo mismo con un margen por lado (izquierda, arriba, derecha, abajo) y la escala de la imagen en pantalla
static func caja_lados(ci: CanvasItem, nombre: String, r: Rect2, m: Vector4, k: float, mod := Color.WHITE) -> bool:
	var t := tex(nombre)
	if t == null or k <= 0:
		return false
	var clave := "%s:%s" % [nombre, m]
	if not _cajas.has(clave):
		var sb := StyleBoxTexture.new()
		sb.texture = t
		sb.texture_margin_left = m.x
		sb.texture_margin_top = m.y
		sb.texture_margin_right = m.z
		sb.texture_margin_bottom = m.w
		_cajas[clave] = sb
	var s: StyleBoxTexture = _cajas[clave]
	s.modulate_color = mod
	ci.draw_set_transform(r.position, 0, Vector2(k, k))
	ci.draw_style_box(s, Rect2(Vector2.ZERO, r.size / k))
	ci.draw_set_transform(Vector2.ZERO)
	return true

## estilo de las ventanas: el panel de mármol (o el plano de antes si falta la pieza)
static func estilo_panel(contenido := 22.0) -> StyleBox:
	var t := tex("panel")
	if t == null:
		var f := StyleBoxFlat.new()
		f.bg_color = Color(.07, .04, .03, .93)
		f.border_color = Color8(150, 110, 50)
		f.set_border_width_all(2)
		f.set_content_margin_all(contenido)
		return f
	var s := StyleBoxTexture.new()
	s.texture = t
	s.set_texture_margin_all(40)
	s.set_content_margin_all(contenido + 6)
	return s

const MARGEN_BOTON := Vector2(34, 16)   # en píxeles de boton_*.png (56 de alto); el chico, la mitad larga
## estilo de un estado del botón: normal, hover, pressed, focus o disabled
static func estilo_boton(estado: String, chico := false) -> StyleBox:
	var nombre: String = {"hover": "boton_encima", "focus": "boton_encima", "pressed": "boton_pulsado"}.get(estado, "boton_normal")
	var t := tex(nombre + ("_chico" if chico else ""))
	if t == null:
		return null
	var m := MARGEN_BOTON * (32.0 / 56.0 if chico else 1.0)
	var s := StyleBoxTexture.new()
	s.texture = t
	s.texture_margin_left = m.x
	s.texture_margin_right = m.x
	s.texture_margin_top = m.y
	s.texture_margin_bottom = m.y
	s.content_margin_left = m.x * .7
	s.content_margin_right = m.x * .7
	s.content_margin_top = 3
	s.content_margin_bottom = 4
	if estado == "disabled":
		s.modulate_color = Color(.55, .55, .55, .8)
	return s

## pone los botones de Diego a un botón; devuelve false si faltan las piezas
static func vestir_boton(b: Button, chico := false) -> bool:
	if tex("boton_normal") == null:
		return false
	for e in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(e, estilo_boton(e, chico))
	return true

## mientras Diego no pase el líquido azul: el rojo con el tono girado
static func _mana_de_reserva() -> Texture2D:
	var rojo := tex("orbe_vida_liquido")
	if rojo == null:
		return null
	var im := rojo.get_image()
	if im == null:
		return null
	im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	im.resize(256, int(256.0 * im.get_height() / im.get_width()), Image.INTERPOLATE_BILINEAR)
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a > 0:
				var h := fposmod(c.h + .62, 1.0)
				var n := Color.from_hsv(h, c.s, c.v, c.a)
				im.set_pixel(x, y, n)
	return ImageTexture.create_from_image(im)

static func limpiar() -> void:
	_tex.clear()
	_cajas.clear()
	_med = null

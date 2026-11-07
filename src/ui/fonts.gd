class_name Fonts
## Tipografías del juego web: Pixelify Sans (todo) y Cinzel (títulos y botones).

static var _px := {}
static var _gothic := {}

static func px(weight: int = 500) -> FontFile:
	if not _px.has(weight):
		var o := _prueba("--fuente=", weight)
		_px[weight] = o if o != null else load("res://assets/fonts/PixelifySans-%d.woff2" % weight)
	return _px[weight]

static func gothic(weight: int = 700) -> FontFile:
	if not _gothic.has(weight):
		var o := _prueba("--fuente_tit=", weight)
		_gothic[weight] = o if o != null else load("res://assets/fonts/Cinzel-%d.woff2" % weight)
	return _gothic[weight]

## pruebas de letra: --fuente=/ruta/letra.woff2 (texto) y --fuente_tit=… (títulos) sustituyen a las del juego.
## Con «%d» en la ruta se busca el grosor pedido (o el más parecido que exista).
static func _prueba(flag: String, weight: int) -> FontFile:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with(flag):
			continue
		var path := a.substr(flag.length())
		if path.contains("%d"):
			for w in [weight, 400, 500, 600, 700, 800, 300]:
				if FileAccess.file_exists(path % w):
					path = path % w
					break
		var f := FontFile.new()
		f.hinting = TextServer.HINTING_NORMAL
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_ONE_QUARTER
		if f.load_dynamic_font(path) == OK:
			return f
	return null

## texto con contorno oscuro, alineado en x según align (0 izquierda, 1 centro, 2 derecha); se traduce al idioma elegido
static func outlined(ci: CanvasItem, font: Font, pos: Vector2, txt: String, size: int, col: Color, align: int = 1, outline: int = 4, ocol: Color = Color(10 / 255.0, 6 / 255.0, 4 / 255.0, .92)) -> void:
	outlined_raw(ci, font, pos, Idioma.t(txt), size, col, align, outline, ocol)

## igual que outlined, sin traducir (para texto ya traducido)
static func outlined_raw(ci: CanvasItem, font: Font, pos: Vector2, txt: String, size: int, col: Color, align: int = 1, outline: int = 4, ocol: Color = Color(10 / 255.0, 6 / 255.0, 4 / 255.0, .92)) -> void:
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := pos.x - (w / 2.0 if align == 1 else (w if align == 2 else 0.0))
	ocol.a *= col.a
	ci.draw_string_outline(font, Vector2(x, pos.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, ocol)
	ci.draw_string(font, Vector2(x, pos.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

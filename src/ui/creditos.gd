class_name Creditos
extends Control
## Créditos que suben por la pantalla: autores y licencias de assets/creditos.json.
## Salen al final del juego; de momento también con F1 (main3d.gd). Esc, F1 o un clic los cierran.

signal cerrado

const RUTA := "res://assets/creditos.json"
const VELOCIDAD := 42.0   # píxeles por segundo

var _lista: VBoxContainer
var _y := 0.0

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, .92)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 10)
	add_child(_lista)
	var d := _datos()
	for s in d.get("secciones", []):
		_lista.add_child(_texto(String(s.get("titulo", "")), Fonts.gothic(700), 34, Color8(233, 207, 138)))
		for l in s.get("lineas", []):
			_lista.add_child(_texto(String(l), Fonts.px(500), 20, Color(.88, .86, .82)))
		var hueco := Control.new()
		hueco.custom_minimum_size = Vector2(0, 40)
		_lista.add_child(hueco)
	var pie := _texto("Esc · F1 · clic para cerrar", Fonts.px(500), 14, Color(.6, .58, .55))
	pie.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pie.offset_top = -34
	add_child(pie)

static func _datos() -> Dictionary:
	if not FileAccess.file_exists(RUTA):
		return {}
	var j = JSON.parse_string(FileAccess.get_file_as_string(RUTA))
	return j if j is Dictionary else {}

func _texto(t: String, f: Font, tam: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", c)
	return l

## vuelve a empezar desde abajo
func empezar() -> void:
	_y = size.y

func _process(dt: float) -> void:
	if not visible:
		return
	var ancho := minf(size.x - 80, 900)
	_lista.size = Vector2(ancho, 0)
	_lista.position = Vector2((size.x - ancho) / 2, _y)
	_y -= VELOCIDAD * dt
	if _y < -_lista.size.y - 40:
		_y = size.y   # da la vuelta

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		_cerrar()

func _unhandled_input(ev: InputEvent) -> void:
	if visible and ev is InputEventKey and ev.pressed and ev.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_cerrar()

func _cerrar() -> void:
	visible = false
	cerrado.emit()

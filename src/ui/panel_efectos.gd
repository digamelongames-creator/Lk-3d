class_name PanelEfectos
extends PanelContainer
## Panel de ajuste de los efectos (F4 en el piso de prueba; pensado para la sala Efectos).
## Eliges un efecto del catálogo (Hechizos3D, assets/vfx/catalogo.json) y cambias con barras su tamaño,
## brillo, velocidad y altura. Los cambios se ven al momento en los efectos que estén saliendo.
## «Probar» (o F6) lo saca sobre el muñeco más cercano; «Guardar» escribe el catálogo.

var hechizos: Hechizos3D
var _lista: OptionButton
var _ids: Array = []
var _barras := {}    # clave de la ficha → HSlider
var _valores := {}   # clave → Label con el número
var _info: Label
var _aviso: Label
var _cargando := false

## clave de la ficha, texto, mínimo, máximo, paso
const BARRAS := [["tam", "Tamaño", .2, 8.0, .05], ["brillo", "Brillo", .1, 3.0, .05], ["velocidad", "Velocidad", .2, 3.0, .05],
	["alto", "Altura", 0.0, 3.0, .05], ["luz_energia", "Luz", 0.0, 15.0, .1]]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 16
	offset_top = 110
	custom_minimum_size = Vector2(380, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiArte.estilo_panel(12))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	col.add_child(_texto("Ajuste de efectos · F4 cierra", 18, Color8(233, 207, 138)))
	_lista = OptionButton.new()
	_lista.add_theme_font_override("font", Fonts.px(500))
	_lista.add_theme_font_size_override("font_size", 14)
	_lista.item_selected.connect(func(_i): _cargar())
	col.add_child(_lista)
	_info = _texto("", 12, Color(.8, .72, .6))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_info)
	for b in BARRAS:
		var fila := HBoxContainer.new()
		var et := _texto(b[1], 14, Color(.9, .85, .75))
		et.custom_minimum_size = Vector2(90, 0)
		fila.add_child(et)
		var s := HSlider.new()
		s.min_value = b[2]
		s.max_value = b[3]
		s.step = b[4]
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.custom_minimum_size = Vector2(180, 22)
		var clave: String = b[0]
		s.value_changed.connect(func(v): _cambiar(clave, v))
		fila.add_child(s)
		var n := _texto("", 14, Color(1, .9, .6))
		n.custom_minimum_size = Vector2(50, 0)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		fila.add_child(n)
		col.add_child(fila)
		_barras[clave] = s
		_valores[clave] = n
	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 8)
	var probar := MenuInicio.boton("Probar (F6)", func(): probar_actual(), 36)
	probar.add_theme_font_size_override("font_size", 17)
	probar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	botones.add_child(probar)
	var guardar := MenuInicio.boton("Guardar", func(): guardar(), 36)
	guardar.add_theme_font_size_override("font_size", 17)
	guardar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	botones.add_child(guardar)
	col.add_child(botones)
	_aviso = _texto("", 12, Color(.6, 1, .6))
	col.add_child(_aviso)
	refrescar()

func _texto(t: String, tam: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", Fonts.px(500))
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", c)
	return l

## vuelve a leer el catálogo (por si se han añadido efectos)
func refrescar() -> void:
	var antes := _id_actual()
	_ids = Hechizos3D.catalogo().keys()
	_lista.clear()
	for id in _ids:
		var d := Hechizos3D.ficha(id)
		var falta := "" if Hechizos3D.hoja(String(d.get("hoja", ""))).tex != null else "  (sin imagen)"
		_lista.add_item(String(d.get("nombre", id)) + falta)
	var i := _ids.find(antes)
	_lista.select(maxi(i, 0))
	_cargar()

func _id_actual() -> String:
	var i := _lista.selected if _lista != null else -1
	return _ids[i] if i >= 0 and i < _ids.size() else ""

func _cargar() -> void:
	var d := Hechizos3D.ficha(_id_actual())
	_cargando = true
	for b in BARRAS:
		var v := float(d.get(b[0], 0.0))
		_barras[b[0]].value = v
		_valores[b[0]].text = "%.2f" % v
	_cargando = false
	var h := Hechizos3D.hoja_de(d)
	var tiene: bool = Hechizos3D.hoja(String(d.get("hoja", ""))).tex != null
	var extra := "" if tiene else (" (falta; usa «%s»)" % d.get("reserva", "") if h.tex != null else " (falta la imagen)")
	_info.text = "%s · forma: %s · hoja: %s%s" % [_id_actual(), d.get("forma", "golpe"), d.get("hoja", ""), extra]
	_aviso.text = ""

func _cambiar(clave: String, v: float) -> void:
	_valores[clave].text = "%.2f" % v
	if _cargando:
		return
	var d := Hechizos3D.ficha(_id_actual())
	if d.is_empty():
		return
	d[clave] = snappedf(v, .01)
	_aviso.text = "Sin guardar"
	_aviso.add_theme_color_override("font_color", Color(1, .8, .4))

func probar_actual() -> void:
	if hechizos != null:
		hechizos.probar(_id_actual())

func guardar() -> void:
	var err := Hechizos3D.guardar_catalogo()
	_aviso.text = "Guardado en assets/vfx/catalogo.json" if err == "" else "Error: " + err
	_aviso.add_theme_color_override("font_color", Color(.6, 1, .6) if err == "" else Color(1, .4, .3))

## el ratón está encima (para no lanzar magias al tocar las barras)
func tapa_raton() -> bool:
	return visible and get_global_rect().has_point(get_viewport().get_mouse_position())

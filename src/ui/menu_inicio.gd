class_name MenuInicio
extends Control
## Pantalla de inicio y menú de pausa (main3d.gd).
##   inicio: Nueva partida (elige la clase), Piso de prueba (elige la sala), Opciones, Créditos y Salir.
##   pausa (Esc en la partida): Continuar, Opciones y Volver al menú.
##   opciones: pantalla completa, zoom por defecto, brillo, sonido, velocidad al andar, sombras, niebla y postprocesado (Opciones).
## El fondo es la mazmorra 3D que monta main3d.gd detrás; aquí solo va el viñeteado y los paneles.

signal empezar(clase: String)
signal piso_prueba(sala: int, clase: String)   # sala del piso de prueba donde se empieza (PisoPrueba.salas_menu) y clase ("" = la de la sala)
signal creditos
signal salir
signal continuar
signal volver_menu
signal opciones_cambiadas

const ORO := Color8(233, 207, 138)
const DESCRIPCION := {
	"knight": "Espada y escudo · Set del Caballero Oscuro",
	"mage": "Explosiones y bolas de fuego",
	"dk": "Levanta a los muertos · Aura · Torbellino",
	"archer": "Arco y carcaj · Lluvia de flechas",
	"dl": "Nubes de muerte",
}

var pagina := "inicio"
var _de := "inicio"      # a qué página vuelve Opciones
var _paginas := {}
var _velo: ColorRect
var _titulo: Control
var _version: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_velo = ColorRect.new()
	_velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float fuerza = 1.0;
uniform float lado = 1.0;
void fragment() {
	// en el inicio, oscuro a la izquierda (menú) y claro a la derecha (el héroe); en la pausa, uniforme
	vec2 d = (UV - mix(vec2(.5, .45), vec2(.66, .55), lado)) * vec2(1.25, 1.0);
	float v = smoothstep(.12, .8, length(d));
	float izq = (1. - smoothstep(.0, .55, UV.x)) * .55 * lado;
	COLOR = vec4(0., 0., 0., clamp(mix(.25, .05, lado) + v * .7 + izq, 0., .94) * fuerza);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_velo.material = mat
	add_child(_velo)
	_titulo = _hacer_titulo()
	add_child(_titulo)
	_paginas.inicio = _columna([
		["Nueva partida", func(): mostrar("clase")],
		["Piso de prueba", func(): mostrar("pruebas")],
		["Opciones", func(): _abrir_opciones()],
		[_txt_sonido(), func(): _cambiar_sonido()],
		["Créditos", func(): creditos.emit()],
		["Salir", func(): salir.emit()],
	])
	_paginas.pausa = _columna([
		["Continuar", func(): continuar.emit()],
		["Opciones", func(): _abrir_opciones()],
		[_txt_sonido(), func(): _cambiar_sonido()],
		["Volver al menú", func(): volver_menu.emit()],
	], "Pausa")
	_paginas.clase = _pagina_clase()
	_paginas.pruebas = _pagina_pruebas()
	_paginas.opciones = _pagina_opciones()
	for k in _paginas:
		add_child(_paginas[k])
	_version = Label.new()
	_version.text = "Last Knight 3D · versión de desarrollo"
	_version.add_theme_font_override("font", Fonts.px(500))
	_version.add_theme_font_size_override("font_size", 13)
	_version.add_theme_color_override("font_color", Color(1, 1, 1, .35))
	_version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_version.offset_left = 18
	_version.offset_top = -32
	add_child(_version)
	var ver := visible   # quien lo crea decide si se ve (main3d lo crea oculto)
	mostrar(pagina)
	visible = ver

## inicio, clase, opciones o pausa
func mostrar(p: String) -> void:
	pagina = p
	for b in _botones_sonido:
		b.text = _txt_sonido()
	for k in _paginas:
		_paginas[k].visible = k == p
	var en_pausa := p == "pausa" or (p == "opciones" and _de == "pausa")
	_titulo.visible = p == "inicio"   # en la de clases manda su encabezado
	_version.visible = not en_pausa
	(_velo.material as ShaderMaterial).set_shader_parameter("fuerza", 1.15 if en_pausa else 1.0)
	(_velo.material as ShaderMaterial).set_shader_parameter("lado", 0.0 if en_pausa else 1.0)
	# inicio y clase a la izquierda (el héroe se ve a la derecha); opciones y pausa, en el centro
	for k in ["inicio", "clase", "pruebas"]:
		_a_la_izquierda(_paginas[k], true)
	visible = true
	# el primer botón con el foco, para poder usar el teclado o el mando
	var b := _primer_boton(_paginas[p])
	if b != null and is_inside_tree():
		b.call_deferred("grab_focus")

func _unhandled_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		match pagina:
			"clase", "pruebas": mostrar("inicio")
			"opciones": mostrar(_de)
			"pausa": continuar.emit()
		get_viewport().set_input_as_handled()

const IZQ := 110   # margen izquierdo del título y de las columnas del inicio

func _a_la_izquierda(c: Control, si: bool) -> void:
	var ancho := c.offset_right - c.offset_left
	if si:
		c.set_anchor(SIDE_LEFT, 0, true)
		c.set_anchor(SIDE_RIGHT, 0, true)
		c.offset_left = IZQ + 40
		c.offset_right = IZQ + 40 + ancho
	else:
		c.set_anchor(SIDE_LEFT, .5, true)
		c.set_anchor(SIDE_RIGHT, .5, true)
		c.offset_left = -ancho / 2
		c.offset_right = ancho / 2

func _abrir_opciones() -> void:
	_de = pagina
	_refrescar_opciones()
	mostrar("opciones")

# ======================================================================
#  piezas
# ======================================================================
func _hacer_titulo() -> Control:
	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_TOP_LEFT)
	caja.offset_left = IZQ
	caja.offset_right = IZQ + 560
	caja.offset_top = 80
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_theme_constant_override("separation", -6)
	var t := Label.new()
	t.text = "Last Knight"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.add_theme_font_override("font", Fonts.gothic(700))
	t.add_theme_font_size_override("font_size", 84)
	t.add_theme_color_override("font_color", Color8(214, 160, 70))
	t.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.01))
	t.add_theme_constant_override("outline_size", 14)
	t.add_theme_color_override("font_shadow_color", Color(.9, .25, .05, .35))
	t.add_theme_constant_override("shadow_offset_y", 0)
	t.add_theme_constant_override("shadow_outline_size", 30)
	caja.add_child(t)
	var s := Label.new()
	s.text = "El Descenso"
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	s.add_theme_font_override("font", Fonts.gothic(700))
	s.add_theme_font_size_override("font_size", 30)
	s.add_theme_color_override("font_color", Color8(170, 140, 100))
	s.add_theme_color_override("font_outline_color", Color.BLACK)
	s.add_theme_constant_override("outline_size", 8)
	caja.add_child(s)
	return caja

## columna de botones centrada; titulo opcional encima (la pausa)
func _columna(botones: Array, titulo: String = "") -> Control:
	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_CENTER)
	caja.offset_left = -170
	caja.offset_right = 170
	caja.offset_top = -60 if titulo == "" else -150
	caja.grow_vertical = Control.GROW_DIRECTION_END
	caja.add_theme_constant_override("separation", 12)
	if titulo != "":
		caja.add_child(_cabecera(titulo))
	for b in botones:
		var bt := boton(b[0], b[1])
		if b[0] == _txt_sonido():
			_botones_sonido.append(bt)
		caja.add_child(bt)
	return caja

## botón «Sonido: sí / no» del inicio y de la pausa (es la misma opción que la casilla de Opciones)
var _botones_sonido: Array[Button] = []

func _txt_sonido() -> String:
	return "Sonido: sí" if Opciones.v("sonido") else "Sonido: no"

func _cambiar_sonido() -> void:
	Opciones.poner("sonido", not Opciones.v("sonido"))
	_refrescar_opciones()
	opciones_cambiadas.emit()

func _cabecera(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Fonts.gothic(700))
	l.add_theme_font_size_override("font_size", 44)
	l.add_theme_color_override("font_color", Color8(214, 160, 70))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	return l

func _pagina_clase() -> Control:
	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_CENTER)
	caja.offset_left = -210
	caja.offset_right = 210
	caja.offset_top = -250
	caja.grow_vertical = Control.GROW_DIRECTION_END
	caja.add_theme_constant_override("separation", 8)
	var cab := _cabecera("Elige tu clase")
	cab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	caja.add_child(cab)
	for k in Items.CLASSES:
		# el botón sin texto propio: nombre arriba y descripción debajo, en dos etiquetas
		var b := boton("", func(): empezar.emit(k), 56)
		var col := VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var n := Label.new()
		n.text = Items.CLS_N[k]
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.add_theme_font_override("font", Fonts.gothic(700))
		n.add_theme_font_size_override("font_size", 21)
		n.add_theme_color_override("font_color", ORO)
		col.add_child(n)
		var d := Label.new()
		d.text = DESCRIPCION.get(k, "")
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.add_theme_font_override("font", Fonts.px(500))
		d.add_theme_font_size_override("font_size", 13)
		d.add_theme_color_override("font_color", Color(.8, .72, .6, .85))
		col.add_child(d)
		b.add_child(col)
		caja.add_child(b)
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 6)
	caja.add_child(sep)
	caja.add_child(boton("Volver", func(): mostrar("inicio"), 42))
	return caja

## «Piso de prueba»: las salas del piso de prueba; se empieza dentro de la elegida
func _pagina_pruebas() -> Control:
	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_CENTER)
	caja.offset_left = -210
	caja.offset_right = 210
	caja.offset_top = -400
	caja.grow_vertical = Control.GROW_DIRECTION_END
	caja.add_theme_constant_override("separation", 5)
	var cab := _cabecera("Salas de prueba")
	cab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	caja.add_child(cab)
	var l := PisoPrueba.salas_menu()
	# la de efectos, la primera (es la nueva); luego el resto en su orden
	var orden := []
	for i in l.size():
		if l[i][1] == "efectos":
			orden.push_front(i)
		else:
			orden.append(i)
	for i in orden:
		var n: String = l[i][0]
		if l[i][1] == "efectos":   # una entrada por clase con magias dibujadas
			for c in [["mage", "mago"], ["knight", "caballero (combos nuevos)"], ["dk", "caballero de la muerte"], ["dl", "señor oscuro"]]:
				var cl: String = c[0]
				caja.add_child(boton(n + "  · " + c[1], func(): piso_prueba.emit(i, cl), 36))
			continue
		caja.add_child(boton(n, func(): piso_prueba.emit(i, ""), 36))
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 6)
	caja.add_child(sep)
	caja.add_child(boton("Volver", func(): mostrar("inicio"), 42))
	return caja

var _ctl := {}   # controles de la página de opciones, por clave

func _pagina_opciones() -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = -260
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.add_theme_stylebox_override("panel", UiArte.estilo_panel(22))
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	panel.add_child(caja)
	caja.add_child(_cabecera("Opciones"))
	_ctl.pantalla_completa = _casilla(caja, "Pantalla completa (F11)", "pantalla_completa")
	_ctl.zoom = _barra(caja, "Zoom al empezar", "zoom", 7, 20, " m")
	_ctl.brillo = _barra(caja, "Brillo", "brillo", 60, 160, " %")
	_ctl.sonido = _casilla(caja, "Sonido", "sonido")
	_ctl.velocidad = _barra(caja, "Velocidad al andar", "velocidad", 30, 100, " %")
	caja.add_child(_subtitulo("Calidad gráfica"))
	_ctl.sombras = _casilla(caja, "Sombras", "sombras")
	_ctl.niebla = _casilla(caja, "Niebla", "niebla")
	_ctl.postprocesado = _casilla(caja, "Resplandor y oclusión ambiental", "postprocesado")
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 4)
	caja.add_child(sep)
	caja.add_child(boton("Volver", func(): mostrar(_de), 42))
	return panel

func _subtitulo(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", Fonts.gothic(700))
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color8(190, 150, 90))
	return l

func _texto(l: Control) -> void:
	l.add_theme_font_override("font", Fonts.px(600))
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", ORO)

func _casilla(caja: Container, texto: String, k: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = texto
	_texto(c)
	c.add_theme_color_override("font_hover_color", Color(1, .9, .6))
	c.add_theme_color_override("font_pressed_color", ORO)
	c.add_theme_color_override("font_focus_color", Color(1, .9, .6))
	c.toggled.connect(func(si: bool):
		Opciones.poner(k, si)
		opciones_cambiadas.emit())
	caja.add_child(c)
	return c

func _barra(caja: Container, texto: String, k: String, a: int, b: int, unidad: String) -> HSlider:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = texto
	l.custom_minimum_size = Vector2(170, 0)
	_texto(l)
	fila.add_child(l)
	var s := HSlider.new()
	s.min_value = a
	s.max_value = b
	s.step = 1 if b - a < 30 else 5
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(s)
	var n := Label.new()
	n.custom_minimum_size = Vector2(60, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_texto(n)
	fila.add_child(n)
	s.value_changed.connect(func(x: float):
		n.text = "%d%s" % [int(x), unidad]
		if int(x) != int(Opciones.v(k)):
			Opciones.poner(k, int(x))
			opciones_cambiadas.emit())
	caja.add_child(fila)
	return s

## pone los controles con lo guardado (sin disparar cambios)
func _refrescar_opciones() -> void:
	for b in _botones_sonido:
		b.text = _txt_sonido()
	for k in _ctl:
		var c = _ctl[k]
		if c is CheckButton:
			c.set_pressed_no_signal(Opciones.v(k))
		elif c is HSlider:
			c.value = Opciones.v(k)
			c.value_changed.emit(c.value)

func _primer_boton(n: Node) -> Control:
	for h in n.get_children():
		if h is Button:
			return h
		var r := _primer_boton(h)
		if r != null:
			return r
	return null

## botón con el estilo del juego (el mismo que el panel «Has caído»)
static func boton(texto: String, accion: Callable, alto: int = 48) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, alto)
	b.add_theme_font_override("font", Fonts.gothic(700))
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", ORO)
	b.add_theme_color_override("font_hover_color", Color(1, .9, .6))
	b.add_theme_color_override("font_focus_color", Color(1, .9, .6))
	b.add_theme_color_override("font_pressed_color", Color(1, .9, .6))
	for estado in ([] if UiArte.vestir_boton(b) else ["normal", "hover", "pressed", "focus"]):
		var st := StyleBoxFlat.new()
		st.bg_color = Color(.12, .06, .04, .95) if estado == "normal" else Color(.25, .1, .05, .95)
		st.border_color = Color8(230, 180, 90) if estado in ["hover", "focus"] else Color8(150, 110, 50)
		st.set_border_width_all(2)
		st.set_corner_radius_all(3)
		if estado == "focus":
			st.draw_center = false
		b.add_theme_stylebox_override(estado, st)
	b.pressed.connect(accion)
	return b

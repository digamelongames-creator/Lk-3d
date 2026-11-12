extends CanvasLayer
## Interfaz: vidas con la franja blanca que se queda atrás (como en los juegos de lucha),
## rondas ganadas, reloj, mira, calor del cañón, energía y mensajes grandes.

var jugador
var enemigo
var control_jugador  # jugador.gd o null

var vida_j: ProgressBar
var vida_j_atras: ProgressBar
var vida_e: ProgressBar
var vida_e_atras: ProgressBar
var rondas_j: Array[Panel] = []
var rondas_e: Array[Panel] = []
var reloj: Label
var mensaje: Label
var submensaje: Label
var calor: ProgressBar
var calor_txt: Label
var energia: ProgressBar
var energia_txt: Label
var escudo_j: ProgressBar
var escudo_e: ProgressBar
var aviso: Label
var nombre_e: Label
var t_aviso := 0.0
var mapa: Control
var puno_txt: Label
var mira: Control
var ayuda: Label
var t := 0.0


## La mochila del jugador en pequeño: cada módulo con su color; los rotos, en rojo oscuro.
class MapaMochila extends Control:
	var mecha
	const C := 26.0
	func _draw() -> void:
		var Modulos = load("res://scripts/modulos.gd")
		draw_rect(Rect2(-4, -4, C * 4 + 8, C * 4 + 8), Color(0, 0, 0, 0.5))
		for x in 4:
			for y in 4:
				draw_rect(Rect2(x * C, y * C, C - 2, C - 2), Color(1, 1, 1, 0.08))
		if mecha == null:
			return
		for p in mecha.construccion:
			var t: Vector2i = Modulos.tam(p)
			var vivo: bool = p.vida > 0.0
			var c: Color = Modulos.CATALOGO[p.id].color if vivo else Color(0.35, 0.05, 0.05)
			var r := Rect2(p.pos.x * C, p.pos.y * C, t.x * C - 2, t.y * C - 2)
			draw_rect(r, c)
			if vivo:
				var f: float = p.vida / Modulos.vida_de(p.id)
				draw_rect(Rect2(r.position.x + 2, r.end.y - 5, (r.size.x - 4) * f, 3), Color.WHITE)


class Mira extends Control:
	var asistido := false
	var abierta := 0.0
	func _draw() -> void:
		var c := Color(1, 0.3, 0.2) if asistido else Color(1, 1, 1, 0.85)
		var r := 14.0 + abierta * 10.0
		draw_arc(Vector2.ZERO, r, 0, TAU, 32, c, 2.0, true)
		draw_circle(Vector2.ZERO, 2.5, c)
		for v in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(v * (r + 4.0), v * (r + 12.0), c, 2.0, true)


func _barra(color: Color, fondo := Color(0, 0, 0, 0.55)) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = 1.0
	b.step = 0.0
	var f := StyleBoxFlat.new()
	f.bg_color = color
	var bg := StyleBoxFlat.new()
	bg.bg_color = fondo
	bg.border_color = Color(1, 1, 1, 0.5)
	bg.set_border_width_all(2)
	b.add_theme_stylebox_override("fill", f)
	b.add_theme_stylebox_override("background", bg)
	return b


func _label(tam: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", maxi(4, tam / 8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _vida(nombre: String, izquierda: bool, color: Color) -> Array:
	var atras := _barra(Color(1, 1, 1, 0.9))
	var delante := _barra(color, Color(0, 0, 0, 0))
	for b in [atras, delante]:
		b.anchor_left = 0.03 if izquierda else 0.57
		b.anchor_right = 0.43 if izquierda else 0.97
		b.anchor_top = 0.035
		b.anchor_bottom = 0.035
		b.offset_bottom = 30
		b.fill_mode = ProgressBar.FILL_BEGIN_TO_END if izquierda else ProgressBar.FILL_END_TO_BEGIN
		add_child(b)
	var l := _label(26)
	l.text = nombre
	l.anchor_left = atras.anchor_left
	l.anchor_right = atras.anchor_right
	l.anchor_top = 0.035
	l.anchor_bottom = 0.035
	l.offset_top = 32
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if izquierda else HORIZONTAL_ALIGNMENT_RIGHT
	add_child(l)
	var pips: Array[Panel] = []
	for i in 2:
		var p := Panel.new()
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0, 0, 0, 0.5)
		s.border_color = Color.WHITE
		s.set_border_width_all(2)
		s.set_corner_radius_all(9)
		p.add_theme_stylebox_override("panel", s)
		p.anchor_left = 0.43 - 0.02 * (i + 1) if izquierda else 0.57 + 0.02 * i + 0.005
		p.anchor_right = p.anchor_left
		p.anchor_top = 0.035
		p.anchor_bottom = 0.035
		p.offset_top = 40
		p.offset_right = 18
		p.offset_bottom = 58
		add_child(p)
		pips.append(p)
	return [delante, atras, pips, l]


func preparar(p_jugador, p_enemigo, p_control) -> void:
	jugador = p_jugador
	enemigo = p_enemigo
	control_jugador = p_control

	var a := _vida(jugador.nombre, true, Color(0.25, 0.65, 1.0))
	vida_j = a[0]; vida_j_atras = a[1]; rondas_j = a[2]
	var b := _vida(enemigo.nombre, false, Color(1.0, 0.3, 0.2))
	vida_e = b[0]; vida_e_atras = b[1]; rondas_e = b[2]; nombre_e = b[3]
	escudo_j = _barra(Color(0.4, 0.8, 1.0), Color(0, 0, 0, 0.4))
	escudo_e = _barra(Color(0.4, 0.8, 1.0), Color(0, 0, 0, 0.4))
	for e in [escudo_j, escudo_e]:
		var base: ProgressBar = vida_j if e == escudo_j else vida_e
		e.anchor_left = base.anchor_left
		e.anchor_right = base.anchor_right
		e.anchor_top = 0.035
		e.anchor_bottom = 0.035
		e.offset_top = -12
		e.offset_bottom = -2
		e.fill_mode = base.fill_mode
		add_child(e)

	reloj = _label(48)
	reloj.anchor_left = 0.5
	reloj.anchor_right = 0.5
	reloj.offset_left = -60
	reloj.offset_right = 60
	reloj.offset_top = 22
	add_child(reloj)

	mensaje = _label(120, Color(1, 0.85, 0.3))
	mensaje.set_anchors_preset(Control.PRESET_FULL_RECT)
	mensaje.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mensaje.offset_top = -120
	add_child(mensaje)
	submensaje = _label(34)
	submensaje.set_anchors_preset(Control.PRESET_FULL_RECT)
	submensaje.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	submensaje.offset_top = 40
	add_child(submensaje)

	# calor y energía abajo en el centro
	calor = _barra(Color(1, 0.6, 0.1))
	energia = _barra(Color(0.3, 0.9, 1.0))
	var y := 0.0
	for barra in [calor, energia]:
		barra.anchor_left = 0.36
		barra.anchor_right = 0.64
		barra.anchor_top = 0.9
		barra.anchor_bottom = 0.9
		barra.offset_top = y
		barra.offset_bottom = y + 18
		y += 34
		add_child(barra)
	energia_txt = _label(16)
	energia_txt.anchor_left = 0.36
	energia_txt.anchor_right = 0.64
	energia_txt.anchor_top = 0.9
	energia_txt.anchor_bottom = 0.9
	energia_txt.offset_top = 52
	add_child(energia_txt)
	calor_txt = _label(20)
	calor_txt.anchor_left = 0.36
	calor_txt.anchor_right = 0.64
	calor_txt.anchor_top = 0.9
	calor_txt.anchor_bottom = 0.9
	calor_txt.offset_top = -28
	add_child(calor_txt)
	puno_txt = _label(20)
	puno_txt.anchor_left = 0.64
	puno_txt.anchor_right = 0.64
	puno_txt.anchor_top = 0.9
	puno_txt.anchor_bottom = 0.9
	puno_txt.offset_left = 16
	puno_txt.offset_right = 200
	puno_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(puno_txt)

	aviso = _label(30, Color(1, 0.5, 0.3))
	aviso.anchor_left = 0.3
	aviso.anchor_right = 0.7
	aviso.anchor_top = 0.72
	aviso.anchor_bottom = 0.72
	add_child(aviso)

	mapa = MapaMochila.new()
	mapa.mecha = jugador
	mapa.anchor_left = 1.0
	mapa.anchor_right = 1.0
	mapa.anchor_top = 1.0
	mapa.anchor_bottom = 1.0
	mapa.offset_left = -140
	mapa.offset_top = -150
	add_child(mapa)

	mira = Mira.new()
	mira.anchor_left = 0.5
	mira.anchor_right = 0.5
	mira.anchor_top = 0.5
	mira.anchor_bottom = 0.5
	mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mira)

	ayuda = _label(18, Color(1, 1, 1, 0.75))
	ayuda.anchor_top = 1.0
	ayuda.anchor_bottom = 1.0
	ayuda.offset_left = 20
	ayuda.offset_top = -150
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ayuda.text = "WASD mover · Ratón apuntar\nClic izq. cañón · Clic der./F puñetazo\nMayús impulso · Espacio propulsores\nQ fijar rival · Esc soltar ratón · F11 pantalla\nR reiniciar combate"
	add_child(ayuda)


func avisar(texto: String) -> void:
	aviso.text = texto
	t_aviso = 2.5


func poner_rondas(v_j: int, v_e: int) -> void:
	for i in 2:
		_pip(rondas_j[i], i < v_j, Color(0.25, 0.65, 1.0))
		_pip(rondas_e[i], i < v_e, Color(1.0, 0.3, 0.2))


func _pip(p: Panel, on: bool, c: Color) -> void:
	var s: StyleBoxFlat = p.get_theme_stylebox("panel")
	s.bg_color = c if on else Color(0, 0, 0, 0.5)


func decir(texto: String, sub := "") -> void:
	mensaje.text = texto
	submensaje.text = sub
	mensaje.pivot_offset = mensaje.size * 0.5
	mensaje.scale = Vector2.ONE * 1.4
	create_tween().tween_property(mensaje, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func poner_reloj(segundos: float) -> void:
	reloj.text = str(ceili(maxf(segundos, 0.0)))


func _process(d: float) -> void:
	if jugador == null:
		return
	t += d
	nombre_e.text = enemigo.nombre
	vida_j.value = jugador.vida / jugador.vida_max
	vida_e.value = enemigo.vida / enemigo.vida_max
	escudo_j.value = jugador.escudo / maxf(jugador.stats.escudo_max, 1.0)
	escudo_e.value = enemigo.escudo / maxf(enemigo.stats.escudo_max, 1.0)
	mapa.queue_redraw()
	t_aviso -= d
	aviso.modulate.a = clampf(t_aviso, 0.0, 1.0)
	vida_j_atras.value = move_toward(vida_j_atras.value, vida_j.value, d * 0.35)
	vida_e_atras.value = move_toward(vida_e_atras.value, vida_e.value, d * 0.35)
	if vida_j_atras.value < vida_j.value:
		vida_j_atras.value = vida_j.value
	if vida_e_atras.value < vida_e.value:
		vida_e_atras.value = vida_e.value

	calor.value = jugador.calor / 100.0
	var f: StyleBoxFlat = calor.get_theme_stylebox("fill")
	if jugador.sobrecalentado:
		f.bg_color = Color(1, 0.15, 0.1) if fmod(t, 0.3) < 0.15 else Color(0.5, 0.05, 0.05)
		calor_txt.text = "¡SOBRECALENTADO!"
		calor_txt.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
	else:
		f.bg_color = Color(1, 0.6, 0.1).lerp(Color(1, 0.2, 0.1), jugador.calor / 100.0)
		calor_txt.text = "CALOR DEL CAÑÓN"
		calor_txt.add_theme_color_override("font_color", Color.WHITE)
	energia.value = jugador.prop / maxf(jugador.stats.prop_max, 1.0)
	energia_txt.text = "PROPULSIÓN" if jugador.stats.prop_max > 0.0 else "SIN PROPULSIÓN"
	puno_txt.text = "PUÑO LISTO" if jugador.t_puno_recarga <= 0.0 else "puño..."
	puno_txt.add_theme_color_override("font_color", Color(1, 0.85, 0.3) if jugador.t_puno_recarga <= 0.0 else Color(1, 1, 1, 0.4))

	if control_jugador:
		mira.visible = true
		mira.asistido = control_jugador.asistido
		mira.abierta = jugador.calor / 100.0
		mira.queue_redraw()
		ayuda.visible = true
	else:
		mira.visible = false
		ayuda.visible = false

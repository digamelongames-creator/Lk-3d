extends CanvasLayer
## Taller de montaje (al estilo del garaje de Need for Speed 2): el mecha quieto en el centro,
## la pieza elegida se ilumina; ↑↓ o el ratón (sobre la lista o sobre el propio mecha) eligen
## la pieza; Intro o clic hacen zoom a ella; ←→ o las flechas de pantalla cambian entre las
## variantes; Intro o Esc vuelven. La mochila abre el editor de la cuadrícula 4×4.

signal cambio
signal a_la_arena

const Piezas = preload("res://scripts/piezas.gd")
const Modulos = preload("res://scripts/modulos.gd")
const Hangar = preload("res://scripts/hangar.gd")

const FILAS := ["piernas", "torso", "cabeza", "brazo_i", "brazo_d", "mochila", "arena"]

## Cámara de cada vista, en coordenadas del mecha (mira hacia -Z): [dónde, a qué mira].
const VISTAS := {
	"general": [Vector3(7.0, 7.2, 12.0), Vector3(0, 3.4, 0)],
	"piernas": [Vector3(5.0, 2.4, 6.5), Vector3(0, 1.8, 0)],
	"torso": [Vector3(3.8, 5.6, -6.4), Vector3(0, 4.4, 0)],
	"cabeza": [Vector3(2.0, 7.0, -4.4), Vector3(0, 6.1, 0)],
	"brazo_i": [Vector3(-6.4, 5.2, -3.6), Vector3(-2.3, 3.6, -1.2)],
	"brazo_d": [Vector3(6.4, 5.2, -3.6), Vector3(2.3, 3.6, -1.2)],
	"mochila": [Vector3(-1.5, 5.6, 7.5), Vector3(0, 4.7, 1.2)],
	"arena": [Vector3(7.0, 7.2, 12.0), Vector3(0, 3.4, 0)],
}
## Puntos del mecha para elegir pieza con el ratón.
const PUNTOS := {
	"piernas": Vector3(0, 1.6, 0), "torso": Vector3(0, 4.4, 0), "cabeza": Vector3(0, 6.2, -0.2),
	"brazo_i": Vector3(-2.4, 3.6, -0.9), "brazo_d": Vector3(2.4, 3.6, -0.9), "mochila": Vector3(0, 4.8, 1.4),
}

var datos: Dictionary
var mecha
var camara: Camera3D
var hangar
var modo := "lista"  # lista | elegir | mochila
var fila := 0
var cam_pos := Vector3.ZERO
var cam_mira := Vector3.ZERO

var panel_izq: Control
var panel_der: Control
var panel_abajo: Control
var botones: Array[Button] = []
var totales: RichTextLabel
var rival_txt: RichTextLabel
var nombre_pieza: Label
var texto_pieza: Label
var cuenta_pieza: Label
var rejilla_stats: GridContainer
var ayuda: Label


func _label(tam: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l


func _estilo(fondo: Color, borde: Color, grosor := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(grosor)
	s.set_corner_radius_all(6)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _panel(izq: float, der: float, arriba: float, abajo: float) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _estilo(Color(0.05, 0.05, 0.07, 0.82), Color(1, 0.75, 0.25, 0.5)))
	p.anchor_left = izq
	p.anchor_right = der
	p.anchor_top = arriba
	p.anchor_bottom = abajo
	add_child(p)
	return p


func _caja_v(padre: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 20
	v.offset_right = -20
	v.offset_top = 16
	v.offset_bottom = -16
	v.add_theme_constant_override("separation", 8)
	padre.add_child(v)
	return v


func preparar(p_datos: Dictionary, p_mecha, p_camara: Camera3D) -> void:
	datos = p_datos
	mecha = p_mecha
	camara = p_camara

	# izquierda: las piezas
	panel_izq = _panel(0.02, 0.27, 0.04, 0.70)
	var v := _caja_v(panel_izq)
	var t := _label(44, Color(1, 0.85, 0.3))
	t.text = "TALLER"
	v.add_child(t)
	var st := _label(17, Color(1, 1, 1, 0.6))
	st.text = "↑↓ o ratón: pieza · Intro o clic: cambiarla"
	v.add_child(st)
	for i in FILAS.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 58 if FILAS[i] != "arena" else 70
		b.add_theme_font_size_override("font_size", 19 if FILAS[i] != "arena" else 30)
		b.mouse_entered.connect(func(): if modo == "lista": _elegir_fila(i))
		b.pressed.connect(func():
			_elegir_fila(i)
			_entrar())
		v.add_child(b)
		botones.append(b)

	# derecha: el mecha entero y el rival
	panel_der = _panel(0.74, 0.98, 0.04, 0.70)
	var v2 := _caja_v(panel_der)
	var t2 := _label(26, Color(1, 0.85, 0.3))
	t2.text = "TU MECHA"
	v2.add_child(t2)
	totales = RichTextLabel.new()
	totales.bbcode_enabled = true
	totales.fit_content = true
	totales.add_theme_font_size_override("normal_font_size", 18)
	totales.add_theme_font_size_override("bold_font_size", 18)
	v2.add_child(totales)
	rival_txt = RichTextLabel.new()
	rival_txt.bbcode_enabled = true
	rival_txt.fit_content = true
	rival_txt.add_theme_font_size_override("normal_font_size", 18)
	rival_txt.add_theme_font_size_override("bold_font_size", 20)
	v2.add_child(rival_txt)

	# abajo: la pieza que se está cambiando (◀ nombre ▶) y sus números
	panel_abajo = _panel(0.27, 0.73, 0.70, 0.97)
	var v3 := _caja_v(panel_abajo)
	var fila_nombre := HBoxContainer.new()
	fila_nombre.alignment = BoxContainer.ALIGNMENT_CENTER
	var izqb := Button.new()
	izqb.text = "  ◀  "
	izqb.focus_mode = Control.FOCUS_NONE
	izqb.add_theme_font_size_override("font_size", 34)
	izqb.pressed.connect(func(): _cambiar(-1))
	fila_nombre.add_child(izqb)
	nombre_pieza = _label(38, Color(1, 0.85, 0.3))
	nombre_pieza.custom_minimum_size.x = 520
	nombre_pieza.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fila_nombre.add_child(nombre_pieza)
	var derb := Button.new()
	derb.text = "  ▶  "
	derb.focus_mode = Control.FOCUS_NONE
	derb.add_theme_font_size_override("font_size", 34)
	derb.pressed.connect(func(): _cambiar(1))
	fila_nombre.add_child(derb)
	v3.add_child(fila_nombre)
	cuenta_pieza = _label(16, Color(1, 1, 1, 0.55))
	cuenta_pieza.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v3.add_child(cuenta_pieza)
	texto_pieza = _label(18, Color(0.9, 0.9, 0.9))
	texto_pieza.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_pieza.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v3.add_child(texto_pieza)
	rejilla_stats = GridContainer.new()
	rejilla_stats.columns = 6
	rejilla_stats.add_theme_constant_override("h_separation", 14)
	v3.add_child(rejilla_stats)
	var ok := Button.new()
	ok.text = "ACEPTAR (Intro)"
	ok.focus_mode = Control.FOCUS_NONE
	ok.add_theme_font_size_override("font_size", 20)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_salir)
	v3.add_child(ok)

	ayuda = _label(18, Color(1, 1, 1, 0.7))
	ayuda.anchor_left = 0.27
	ayuda.anchor_right = 0.73
	ayuda.anchor_top = 0.95
	ayuda.anchor_bottom = 0.95
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(ayuda)

	hangar = Hangar.new()
	add_child(hangar)
	hangar.preparar(datos)
	hangar.visible = false
	hangar.cambio.connect(func(): cambio.emit())
	hangar.listo.connect(_salir)
	_refrescar()


# ---------------------------------------------------------------- abrir y cerrar
func abrir() -> void:
	visible = true
	modo = "lista"
	fila = 0
	hangar.visible = false
	_mostrar_paneles()
	_poner_camara(true)
	_refrescar()


func _mostrar_paneles() -> void:
	var en_mochila := modo == "mochila"
	panel_izq.visible = not en_mochila
	panel_der.visible = not en_mochila
	panel_abajo.visible = modo == "elegir"
	ayuda.visible = modo == "lista"
	hangar.visible = en_mochila


func _hueco() -> String:
	return FILAS[fila]


func _elegir_fila(i: int) -> void:
	fila = clampi(i, 0, FILAS.size() - 1)
	_refrescar()


func _entrar() -> void:
	var h := _hueco()
	if h == "arena":
		if Piezas.problemas(datos.montaje, datos.construccion).is_empty():
			a_la_arena.emit()
		return
	modo = "mochila" if h == "mochila" else "elegir"
	if modo == "mochila":
		hangar.refrescar()
	_mostrar_paneles()
	_poner_camara(false)
	_refrescar()


func _salir() -> void:
	modo = "lista"
	_mostrar_paneles()
	_poner_camara(false)
	_refrescar()


func _cambiar(paso: int) -> void:
	var h := _hueco()
	var cat := Piezas.catalogo(h)
	if cat.is_empty():
		return
	var ids := cat.keys()
	var i := ids.find(datos.montaje[h])
	datos.montaje[h] = ids[(i + paso + ids.size()) % ids.size()]
	cambio.emit()
	_refrescar()


# ---------------------------------------------------------------- teclado y ratón
func _unhandled_input(e: InputEvent) -> void:
	if not visible or modo == "mochila":
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_UP, KEY_W:
				if modo == "lista":
					_elegir_fila(fila - 1)
			KEY_DOWN, KEY_S:
				if modo == "lista":
					_elegir_fila(fila + 1)
			KEY_LEFT, KEY_A:
				if modo == "elegir":
					_cambiar(-1)
			KEY_RIGHT, KEY_D:
				if modo == "elegir":
					_cambiar(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if modo == "lista":
					_entrar()
				else:
					_salir()
			KEY_ESCAPE, KEY_BACKSPACE:
				if modo == "elegir":
					_salir()
		get_viewport().set_input_as_handled()
	elif modo == "lista" and e is InputEventMouseMotion:
		var h := _hueco_bajo_raton(e.position)
		if h != "" and h != _hueco():
			_elegir_fila(FILAS.find(h))
	elif modo == "lista" and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var h := _hueco_bajo_raton(e.position)
		if h != "":
			_elegir_fila(FILAS.find(h))
			_entrar()


func _hueco_bajo_raton(p: Vector2) -> String:
	var mejor := ""
	var dist := 110.0
	for h in PUNTOS:
		var w: Vector3 = mecha.global_transform * PUNTOS[h]
		if camara.is_position_behind(w):
			continue
		var dd := camara.unproject_position(w).distance_to(p)
		if dd < dist:
			dist = dd
			mejor = h
	return mejor


# ---------------------------------------------------------------- cámara
func _poner_camara(de_golpe: bool) -> void:
	var v: Array = VISTAS[_hueco() if modo != "lista" else "general"]
	cam_pos = mecha.global_transform * v[0]
	cam_mira = mecha.global_transform * v[1]
	if de_golpe:
		camara.global_position = cam_pos
		camara.look_at(cam_mira)


func _process(d: float) -> void:
	if not visible:
		return
	var k := 1.0 - exp(-6.0 * d)
	camara.global_position = camara.global_position.lerp(cam_pos, k)
	var actual := camara.global_position - camara.global_basis.z * 10.0
	var hacia := actual.lerp(cam_mira, k)
	if camara.global_position.distance_to(hacia) > 0.1:
		camara.look_at(hacia)
	camara.fov = lerpf(camara.fov, 55.0 if modo == "lista" else 45.0, k)


# ---------------------------------------------------------------- textos
func _refrescar() -> void:
	if totales == null:
		return
	for i in FILAS.size():
		var h: String = FILAS[i]
		var b := botones[i]
		var activa := i == fila
		if h == "arena":
			var pr := Piezas.problemas(datos.montaje, datos.construccion)
			b.text = "  ¡A LA ARENA!" if pr.is_empty() else "  Arregla el peso o el reactor"
			b.disabled = not pr.is_empty()
		elif h == "mochila":
			b.text = "  MOCHILA\n  %d módulos en la cuadrícula 4×4" % datos.construccion.size()
		else:
			b.text = "  %s\n  %s" % [Piezas.NOMBRE_HUECO[h], Piezas.ficha(datos.montaje, h).nombre]
		var borde := Color(1, 0.8, 0.3) if activa else Color(1, 1, 1, 0.15)
		var fondo := Color(0.35, 0.25, 0.05, 0.9) if activa else Color(0.1, 0.1, 0.12, 0.85)
		for estado in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(estado, _estilo(fondo, borde, 3 if activa else 1))
		b.add_theme_color_override("font_color", Color(1, 0.9, 0.5) if activa else Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.5) if activa else Color.WHITE)

	totales.text = Hangar.texto_totales(datos.montaje, datos.construccion)
	var r: Dictionary = datos.rival
	var m: Dictionary = r.montaje
	rival_txt.text = "\n[color=#ffd84d][b]Próximo rival (%d/%d)[/b][/color]\n[b]%s[/b]\n%s\n[color=#aaaaaa]%s · %s · %s\n%s y %s[/color]" % [
		datos.rival_n + 1, Modulos.RIVALES.size(), r.nombre, r.texto,
		Piezas.PIERNAS[m.piernas].nombre, Piezas.TORSOS[m.torso].nombre, Piezas.CABEZAS[m.cabeza].nombre,
		Piezas.ARMAS[m.brazo_i].nombre, Piezas.ARMAS[m.brazo_d].nombre]
	ayuda.text = "↑↓ elegir pieza · Intro cambiarla · también con el ratón sobre el mecha"

	var h := _hueco()
	mecha.resaltar(h if h != "arena" and modo != "mochila" else "")
	if modo == "elegir":
		var cat := Piezas.catalogo(h)
		var ids := cat.keys()
		var id: String = datos.montaje[h]
		var f: Dictionary = cat[id]
		nombre_pieza.text = f.nombre.to_upper()
		cuenta_pieza.text = "%s · %d de %d   (← →)" % [Piezas.NOMBRE_HUECO[h], ids.find(id) + 1, ids.size()]
		texto_pieza.text = f.texto
		_poner_numeros(h, f)


## Números de la pieza en barras, comparadas con lo mejor del catálogo.
func _poner_numeros(h: String, f: Dictionary) -> void:
	for c in rejilla_stats.get_children():
		c.queue_free()
	var filas := []
	match h:
		"piernas":
			filas = [["Carga", f.carga, 42.0, "%d"], ["Velocidad", f.vel, 14.0, "%.1f m/s"], ["Vida", f.vida + 300.0, 550.0, "%+d" % f.vida],
				["Salto", f.empuje, 1.25, "×%.2f"], ["Aguante", 1.0 / f.aturdir, 2.0, "×%.1f"]]
		"torso":
			filas = [["Reactor", f.reactor, 16.0, "%d"], ["Vida", f.vida + 200.0, 550.0, "%+d" % f.vida], ["Peso", f.peso, 9.0, "%d"]]
		"cabeza":
			filas = [["Ayuda al apuntar", f.ayuda, 9.0, "%d °"], ["Precisión", 1.0 / f.dispersion, 2.0, "×%.1f"], ["Giro", f.giro, 1.0, "×%.2f"],
				["Vida", f.vida + 100.0, 250.0, "%+d" % f.vida], ["Peso", f.peso, 3.0, "%d"], ["Reactor", f.consumo, 2.0, "%d"]]
		_:
			if f.tipo == "disparo":
				var dps: float = f.dano * f.balas / f.cadencia
				filas = [["Daño por segundo", dps, 200.0, "%d"], ["Daño por disparo", f.dano * f.balas, 140.0, "%d"],
					["Disparos por segundo", 1.0 / f.cadencia, 22.0, "%.1f"], ["Alcance", f.vel * f.vida, 220.0, "%d m"],
					["Calor por segundo", f.calor / f.cadencia, 60.0, "%d"], ["Peso", f.peso, 5.0, "%d"]]
			else:
				filas = [["Daño", f.dano, 270.0, "%d"], ["Rapidez", 1.0 / (f.carga + f.recarga), 1.7, "%.1f /s"],
					["Alcance", f.alcance, 6.8, "%.1f m"], ["Empujón", f.empujon, 34.0, "%d"],
					["Aturde", f.aturdido, 0.9, "%.2f s"], ["Peso", f.peso, 5.0, "%d"]]
	for fl in filas:
		var nombre := _label(16, Color(0.85, 0.85, 0.85))
		nombre.text = fl[0]
		rejilla_stats.add_child(nombre)
		var barra := ProgressBar.new()
		barra.show_percentage = false
		barra.max_value = 1.0
		barra.step = 0.0
		barra.value = clampf(float(fl[1]) / float(fl[2]), 0.04, 1.0)
		barra.custom_minimum_size = Vector2(110, 14)
		barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var lleno := StyleBoxFlat.new()
		lleno.bg_color = Color(1, 0.75, 0.25)
		var fondo := StyleBoxFlat.new()
		fondo.bg_color = Color(1, 1, 1, 0.1)
		barra.add_theme_stylebox_override("fill", lleno)
		barra.add_theme_stylebox_override("background", fondo)
		rejilla_stats.add_child(barra)
		var valor := _label(16)
		var formato: String = fl[3]
		valor.text = formato if not "%" in formato else formato % fl[1]
		valor.custom_minimum_size.x = 70
		rejilla_stats.add_child(valor)

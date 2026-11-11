extends Node3D
## Last Knight en 3D: la misma simulación (src/core) con vista 3D, mazmorra en GridMap
## y la interfaz de siempre (HUD, inventario, personaje y árbol).
##
## Opciones de línea de órdenes (después de --):
##   --clase=knight|dk|archer|mage|dl   --piso=N   --semilla=texto   --bot   --shot=/tmp/x.png,frames
##   --inclinacion=33   --giro=45   --perspectiva
##   --prueba=N (piso de prueba N; es como arranca)   --partida (partida normal, sin piso de prueba)
##   --sala=N (en el piso de prueba, empieza en la sala N: 0 pasillo, 1–5 paquetes, 6–9 propósitos, 10 aprendizaje, 11 efectos)
##   --hechizo (en la sala de efectos, el mago lanza bolas de fuego solo; para capturas)
##   --menu (abre la pantalla de inicio aunque haya otras opciones; --menu=opciones|clase|pausa para las capturas)
##   --ciudad (empieza en Inca; --ciudad=puerta|escalera abre esa ventana, para las capturas)
## Sin opciones arranca en la pantalla de inicio (MenuInicio). Las opciones que empiezan una partida
## (--partida, --prueba, --piso, --junto, --sala, --equipo, --morir, --bot, --clase) se la saltan.

var sim := Sim.new()
var fx := Fx3D.new()
var mazmorra: MazmorraGridMap
var actores: Actores3D
var hechizos: Hechizos3D   # efectos de las magias con hojas de fotogramas (assets/vfx, catálogo)
var panel_efectos: PanelEfectos   # F4 en el piso de prueba: ajustar los efectos
var camara: CamaraIso
var hud: Hud
var inventory: Inventory
var personaje: Personaje
var state := "play"
var clase := "knight"
var _muerte: Control   # panel «Has caído»: Volver a Inca (pierdes la mochila y el oro de la bajada) o al menú
var _escalera: Control   # tras vencer al jefe: bajar a la oleada siguiente, subir a Inca o seguir en el piso
var _puerta: Control     # la entrada a la mazmorra de Inca: elegir la oleada
var _secreta: Control    # puerta de una sala secreta: «¿Entrar?» (SalaSecreta)
var _negro: ColorRect    # fundido a negro al cruzar una puerta secreta
var _ciudad := ""        # --ciudad[=puerta|escalera]: empieza en Inca (pruebas y capturas)
var _visitas := 0        # cada bajada genera pisos nuevos aunque se repita la oleada
var opciones_camara: Array = []
var heroe_id := "esqueleto"   # modelo del héroe (--heroe=… para probar otro)
var prueba := 0   # piso de prueba N (PisoPrueba); 0 = partida normal
var _directo := false   # alguna opción de arranque empieza la partida sin pasar por el menú
var _menu_pagina := ""  # --menu=…: página del menú con la que se abre (capturas)
var menu: MenuInicio
var entorno: WorldEnvironment
var _antes_creditos := "play"   # a qué estado vuelven los créditos al cerrarse
var _luz_menu: OmniLight3D   # luz cálida sobre el héroe en el fondo del menú
const GIRO := 45.0
var _creditos: Creditos
var _panel_fx := false   # --f4: el panel de ajuste de efectos abierto (capturas)
var _hechizo := false   # --hechizo: en la sala de efectos, lanza solo (capturas)
var _sala := -1   # pruebas: --sala=N pone al héroe en la sala N del piso de prueba (0 = pasillo)
var _panel_apr: Label   # F3: lo que han aprendido los enemigos cercanos (solo para pruebas)
var _panel_apr_t := 0.0
var _f3 := false   # --f3: el panel abierto desde el principio (capturas)


var _bot: Bot = null
const ZOOM_MIN := 7.0
const ZOOM_MAX := 20.0
var _zoom_label: Label
var _zoom_t := 0.0
var _morir := false
var _equipo := -1  # pruebas: --equipo=0..3 pone casco, peto, guantes, cinturón y botas de esa calidad y suelta una de cada calidad al lado
var _junto := ""   # pruebas: --junto=demonCaptain pone al héroe al lado de ese monstruo (también jefe o elite)
var _shot_path := ""
var _shot_frames := 0
var _frame := 0
var _attack_edge := false
var _dash_edge := false
var _skill_edge := -1
var _interact_edge := false
var _potion_edge := false

func _ready() -> void:
	Idioma.iniciar()
	Atlas.load_all()   # iconos de objetos, pociones y runas para la interfaz
	_setup_input()
	Opciones.cargar()
	Opciones.aplicar_pantalla(get_window())
	clase = "knight"
	var piso := 1
	var semilla := ""
	var con_menu := false
	var args := OS.get_cmdline_user_args()
	if not Array(args).any(func(a): return a.begins_with("--clase=")):
		for a in args:
			if a.begins_with("--sala="):   # sin --clase, la de la sala (mago en la de efectos)
				clase = PisoPrueba.clase_de_sala(int(a.get_slice("=", 1)))
	for a in args:
		if a.begins_with("--clase="):
			clase = a.get_slice("=", 1)
			_directo = true
		elif a.begins_with("--piso="):
			piso = int(a.get_slice("=", 1))
			prueba = 0
			_directo = true
		elif a.begins_with("--prueba="):
			prueba = maxi(1, int(a.get_slice("=", 1)))
			_directo = true
		elif a == "--partida":
			prueba = 0
			_directo = true
		elif a.begins_with("--sala="):
			_sala = int(a.get_slice("=", 1))
			if prueba == 0: prueba = 1
			_directo = true
		elif a.begins_with("--semilla="): semilla = a.get_slice("=", 1)
		elif a == "--bot":
			_bot = Bot.new()
			_directo = true
		elif a.begins_with("--heroe="): heroe_id = a.get_slice("=", 1)
		elif a.begins_with("--junto="):
			_junto = a.get_slice("=", 1)
			prueba = 0
			_directo = true
		elif a.begins_with("--equipo="):
			_equipo = int(a.get_slice("=", 1))
			_directo = true
		elif a == "--hechizo":
			_hechizo = true
		elif a == "--f4":
			_panel_fx = true
		elif a == "--f3":
			_f3 = true
		elif a == "--morir":   # pruebas: el héroe cae al empezar (panel de muerte)
			_morir = true
			_directo = true
		elif a == "--ciudad" or a.begins_with("--ciudad="):
			_ciudad = a.get_slice("=", 1) if "=" in a else "si"
			_directo = true
		elif a == "--menu" or a.begins_with("--menu="):
			con_menu = true
			_menu_pagina = a.get_slice("=", 1) if "=" in a else ""
		elif a.begins_with("--inclinacion=") or a.begins_with("--giro=") or a.begins_with("--zoom=") or a == "--perspectiva": opciones_camara.append(a)
		elif a.begins_with("--shot="):
			var p := a.get_slice("=", 1).split(",")
			_shot_path = p[0]
			_shot_frames = int(p[1]) if p.size() > 1 else 60
	if con_menu:
		_directo = false
	entorno = CamaraIso.ambiente(self)
	Opciones.aplicar_grafico(entorno, get_viewport())
	Opciones.aplicar_sonido()
	sim.vel_mov = Opciones.vel_mov()
	sim.preguntar_escalera = _bot == null
	sim.apr = Aprendizaje.new("user://aprendizaje.json")   # lo que aprenden los enemigos, entre partidas
	mazmorra = MazmorraGridMap.new()
	add_child(mazmorra)
	actores = Actores3D.new()
	actores.sim = sim
	actores.heroe_id = heroe_id
	add_child(actores)
	hechizos = Hechizos3D.new()
	hechizos.sim = sim
	hechizos.actores = actores
	add_child(hechizos)
	fx.raiz = self
	fx.sim = sim
	sim.fx = fx
	camara = CamaraIso.new()
	camara.zoom = Opciones.v("zoom")
	for a in opciones_camara:
		if a.begins_with("--inclinacion="): camara.inclinacion = deg_to_rad(float(a.get_slice("=", 1)))
		elif a.begins_with("--giro="): camara.giro = deg_to_rad(float(a.get_slice("=", 1)))
		elif a.begins_with("--zoom="): camara.zoom = float(a.get_slice("=", 1))
		elif a == "--perspectiva": camara.ortografica = false
	add_child(camara)
	var ui := CanvasLayer.new()
	add_child(ui)
	hud = Hud.new()
	hud.sim = sim
	hud.fx = fx
	hud.act = actores
	ui.add_child(hud)
	inventory = Inventory.new()
	inventory.sim = sim
	ui.add_child(inventory)
	inventory.closed.connect(func(): if state == "inv": _set_state("play"))
	personaje = Personaje.new()
	personaje.sim = sim
	ui.add_child(personaje)
	personaje.closed.connect(func(): if state == "char": _set_state("play"))
	_muerte = _panel_muerte()
	ui.add_child(_muerte)
	_escalera = _panel_escalera()
	ui.add_child(_escalera)
	_puerta = Control.new()
	_puerta.set_anchors_preset(Control.PRESET_FULL_RECT)
	_puerta.visible = false
	ui.add_child(_puerta)
	_secreta = _panel_secreta()
	ui.add_child(_secreta)
	_creditos = Creditos.new()
	_creditos.visible = false
	_creditos.cerrado.connect(func(): if state == "creditos": mostrar_creditos(false))
	ui.add_child(_creditos)
	# indicador del zoom (aparece al cambiarlo y se apaga solo)
	_zoom_label = Label.new()
	_zoom_label.add_theme_font_override("font", Fonts.px(700))
	_zoom_label.add_theme_font_size_override("font_size", 16)
	_zoom_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_zoom_label.add_theme_constant_override("outline_size", 5)
	_zoom_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_zoom_label.offset_left = -170
	_zoom_label.offset_right = -20
	_zoom_label.offset_top = 296
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_zoom_label.modulate.a = 0
	ui.add_child(_zoom_label)
	_panel_apr = Label.new()
	_panel_apr.add_theme_font_override("font", Fonts.px(400))
	_panel_apr.add_theme_font_size_override("font_size", 13)
	_panel_apr.add_theme_color_override("font_outline_color", Color.BLACK)
	_panel_apr.add_theme_constant_override("outline_size", 5)
	var caja_apr := StyleBoxFlat.new()
	caja_apr.bg_color = Color(0, 0, 0, .62)
	caja_apr.set_content_margin_all(10)
	_panel_apr.add_theme_stylebox_override("normal", caja_apr)
	_panel_apr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel_apr.offset_left = -470
	_panel_apr.offset_right = -20
	_panel_apr.offset_top = 330
	_panel_apr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel_apr.visible = _f3
	ui.add_child(_panel_apr)
	panel_efectos = PanelEfectos.new()
	panel_efectos.hechizos = hechizos
	panel_efectos.visible = _panel_fx
	ui.add_child(panel_efectos)
	menu = MenuInicio.new()
	menu.visible = false
	menu.empezar.connect(func(c: String): _empezar(c, 0))
	menu.piso_prueba.connect(func(sala: int, cl: String):
		_sala = sala
		_empezar(cl if cl != "" else PisoPrueba.clase_de_sala(sala), 1))
	menu.creditos.connect(func(): mostrar_creditos(true))
	menu.salir.connect(func(): get_tree().quit())
	menu.continuar.connect(_continuar)
	menu.volver_menu.connect(_ir_menu)
	menu.opciones_cambiadas.connect(_opciones_cambiadas)
	ui.add_child(menu)
	_luz_menu = OmniLight3D.new()
	_luz_menu.light_color = Color(1, .62, .32)
	_luz_menu.light_energy = 3.2
	_luz_menu.omni_range = 7.0
	_luz_menu.omni_attenuation = 1.4
	_luz_menu.shadow_enabled = true
	_luz_menu.visible = false
	add_child(_luz_menu)
	ui.move_child(_creditos, -1)   # los créditos, por encima del menú
	if not _directo:
		_ir_menu()
		if _menu_pagina == "pausa":
			pass   # en _process: empieza la partida y luego pausa, como al pulsar los botones
		elif _menu_pagina == "opciones":
			menu._abrir_opciones()
		elif _menu_pagina != "":
			menu.mostrar(_menu_pagina)
		return
	sim.new_game(piso, semilla, clase)
	sim.oro_salida = sim.p.gold
	if _ciudad != "":
		_ir_ciudad()
		if _ciudad == "puerta":
			sim.p.piso_max = 12
			Ciudad.salir_del_portal(sim)
			_camara(1.0)
			_abrir_puerta()
		elif _ciudad == "portal":   # capturas: junto a la entrada, sin la ventana
			Ciudad.salir_del_portal(sim)
			_camara(1.0)
		elif _ciudad == "escalera":
			_abrir_escalera()
		return
	if prueba > 0:
		_entrar_prueba(prueba)
	else:
		_entrar(DungeonGen.gen_level(sim.level_seed(sim.wave), sim.wave))
		fx.banner("Derrota al jefe y baja por la escalera", "Oleada %d" % sim.wave)
	if _junto == "reto" and not sim.reto.is_empty():   # pruebas: dentro de la sala del reto (empieza solo)
		var R: Dictionary = sim.L.rooms[sim.reto.room]
		sim.p.x = (R.x + R.w / 2.0) * DungeonGen.TS
		sim.p.y = (R.y + R.h / 2.0) * DungeonGen.TS + 8
	elif _junto == "trampa" and sim.trampas.size():   # pruebas: al lado de una trampa
		sim.p.x = sim.trampas[0].x
		sim.p.y = sim.trampas[0].y
		sim.unstick(sim.p)
	elif _junto != "":
		for e in sim.enemies:
			if e.mon == _junto or (_junto == "jefe" and e.jefe) or (_junto == "elite" and e.rare and e.poder != "" and not e.jefe):
				for k in 16:
					var q := Vector2(e.x, e.y) + Vector2.from_angle(k * TAU / 16) * 110
					if sim.fits(q.x, q.y, 8):
						sim.p.x = q.x
						sim.p.y = q.y
						break
				break
		_camara(1.0)
	if _equipo >= 0:
		var k: String = sim.p.cls_key()
		for s_ in ["helm", "chest", "gloves", "belt", "boots"]:
			if Items.set_of(k).slots.has(s_):
				sim.p.eq[s_] = Items.make_gear(sim.rng, clampi(_equipo, 0, 3), k, s_)
		sim.runes.agg(sim.p)
		var i := 0
		for q in 4:
			for s_ in ["helm", "chest", "boots"]:
				var v := sim.safe_spot(sim.p.x - 70 + q * 45, sim.p.y + 40 + i % 3 * 26, Vector2(sim.p.x, sim.p.y))
				sim.loot.append({"x": v.x, "y": v.y, "item": Items.make_gear(sim.rng, q, k, s_), "bob": 0.0, "fly": null})
				i += 1

func _entrar(L: Dictionary) -> void:
	fx.reset()
	Ciudad.ambiente(entorno.environment, Ciudad.es_ciudad(L))
	sim.enter_level(L)
	mazmorra.construir(sim.L)
	actores.nuevo_piso()
	hechizos.reset()
	_camara(1.0)

## piso de prueba: el mapa hecho a mano, sin enemigos, con los kits y adornos montados encima
func _entrar_prueba(n: int) -> void:
	var L := PisoPrueba.generar(n)
	_entrar(L)
	sim.enemies.clear()
	sim.cleared = true   # sin el aviso de «Mazmorra despejada» al empezar
	PisoPrueba.amueblar(sim.L, mazmorra)
	PisoPrueba.botin(sim)
	var salas: Array = sim.L.salas_prueba
	if _sala >= 0 and _sala < salas.size():
		var s: Dictionary = salas[_sala]
		sim.p.x = (s.x + 4.5) * DungeonGen.TS
		sim.p.y = (s.y + s.h / 2.0) * DungeonGen.TS
		sim.unstick(sim.p)
		_camara(1.0)
	if not PisoPrueba.sala_efectos(sim).is_empty() and _sala >= 0 and PisoPrueba.salas_menu()[_sala][1] == "efectos":
		fx.banner("Muñecos para probar las magias · F4: ajustar los efectos · F6: probar · 4: orbe (señor oscuro)", "Sala de efectos")
	else:
		fx.banner("Sin enemigos · F1: créditos", PisoPrueba.nombre(n))

func _bajar() -> void:
	sim.score += sim.wave * 25
	sim.p.inv = 0
	sim.wave += 1
	_entrar(DungeonGen.gen_level(sim.level_seed(sim.wave), sim.wave))
	fx.banner("Derrota al jefe y baja por la escalera", "Oleada %d" % sim.wave)
	Guardado.guardar(sim)
	sim.apr.guardar()

# ======================================================================
#  bucle
# ======================================================================
func _process(dt: float) -> void:
	_frame += 1
	dt = minf(dt, .033)
	if _menu_pagina == "pausa":
		if _frame == 20: _empezar("knight", 0)
		elif _frame == 60: _pausa()
	if state in ["menu", "pausa"] and menu.pagina != "pausa" and not (menu.pagina == "opciones" and state == "pausa"):
		camara.giro += dt * .07   # el fondo del menú: la cámara da vueltas despacio alrededor del héroe
	if state == "play":
		var inp := _read_input() if _bot == null else _bot.play(sim)
		if _hechizo:   # capturas: el mago lanza bolas de fuego al muñeco más cercano sin parar
			inp.block = true
			inp.aim_mouse = false
		var r := sim.step(dt, inp)
		if prueba > 0:
			# el piso de prueba no tiene enemigos (ni los que aparecen por el camino), salvo la sala del aprendizaje
			sim.enemies = sim.enemies.filter(func(e): return e.en_arena or e.mimic)
			PisoPrueba.arena(sim, dt)
			PisoPrueba.mimico(sim, dt)
			PisoPrueba.efectos(sim)
		if r == "descend":
			_bajar()
		elif r == "escalera":
			if Ciudad.es_ciudad(sim.L):
				_abrir_puerta()
			else:
				_abrir_escalera()
		elif r == "secreta":
			_abrir_secreta()
		elif r == "over" and prueba > 0:
			# en el piso de prueba se revive en el sitio, con la vida llena, para no perder la prueba (10 nov)
			sim.revive()
			sim.p.hp = sim.p.st.maxHp
			sim.fx.hud()
		elif r == "over":
			state = "over"
			_muerte.visible = true
			sim.apr.guardar()
	fx.tick(dt)
	if _panel_apr.visible:
		_panel_apr_t -= dt
		if _panel_apr_t <= 0:
			_panel_apr_t = .25
			_panel_apr.text = _texto_aprendizaje()
	if _zoom_t > 0:
		_zoom_t -= dt
		_zoom_label.modulate.a = clampf(_zoom_t / .5, 0, 1)
	actores.actualizar(dt)
	if mazmorra != null and not sim.L.is_empty():
		mazmorra.tapas_secretas(sim.heroe_en_secreta())
	_camara(dt)
	hechizos.camara = camara
	actores.combos_prueba = prueba > 0   # los combos nuevos del caballero, de momento solo en el piso de prueba
	hechizos.actualizar(dt)
	if sim.p != null:
		RenderingServer.global_shader_parameter_set("pos_heroe", MazmorraGridMap.a3d(sim.p.x, sim.p.y))
	if _morir and _frame == 20:
		sim.p.hp = 0
		sim.p.dead = true
	if _shot_path != "" and _frame == _shot_frames:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot_path)
		print("captura: ", _shot_path)
		get_tree().quit()

func _camara(dt: float) -> void:
	if sim.p == null:
		return
	camara.temblor = fx.temblor
	var mira := MazmorraGridMap.a3d(sim.p.x, sim.p.y) + Vector3(0, 1, 0)
	if state == "menu":
		# en el inicio el héroe va a la derecha de la pantalla (el menú ocupa la izquierda)
		var a := camara.hacia_camara()
		mira += Vector3(-a.y, 0, a.x) * camara.zoom * .3
		camara.seguir(mira, dt, false)
		return
	camara.seguir(mira, dt)

## el punto del suelo bajo el ratón, en px de la simulación
func _raton_en_suelo() -> Vector2:
	return MazmorraGridMap.a_px(camara.suelo_bajo(get_viewport().get_mouse_position()))

# ======================================================================
#  ventanas: muerte, escalera tras el jefe y entrada a la mazmorra
# ======================================================================
## ventana centrada con fondo oscuro: devuelve [raíz, caja] (la caja es un VBox para los botones)
func _ventana(titulo_txt: String, texto: String, ancho := 380) -> Array:
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.visible = false
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, .55)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(centro)
	var marco := PanelContainer.new()
	marco.add_theme_stylebox_override("panel", UiArte.estilo_panel(26))
	centro.add_child(marco)
	var caja := VBoxContainer.new()
	caja.custom_minimum_size = Vector2(ancho, 0)
	caja.add_theme_constant_override("separation", 14)
	marco.add_child(caja)
	var titulo := Label.new()
	titulo.text = titulo_txt
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_override("font", Fonts.gothic(700))
	titulo.add_theme_font_size_override("font_size", 46)
	titulo.add_theme_color_override("font_color", Color(.85, .12, .08) if titulo_txt == "Has caído" else MenuInicio.ORO)
	titulo.add_theme_color_override("font_outline_color", Color.BLACK)
	titulo.add_theme_constant_override("outline_size", 8)
	caja.add_child(titulo)
	if texto != "":
		var t := Label.new()
		t.text = texto
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_font_override("font", Fonts.px(500))
		t.add_theme_font_size_override("font_size", 17)
		t.add_theme_color_override("font_color", Color(.92, .86, .74))
		t.add_theme_color_override("font_outline_color", Color.BLACK)
		t.add_theme_constant_override("outline_size", 4)
		caja.add_child(t)
	return [raiz, caja]

## al morir no se revive: vuelves a Inca con el equipo puesto y pierdes la mochila y el oro de esta bajada
func _panel_muerte() -> Control:
	var v := _ventana("Has caído", "Pierdes lo que llevabas en la mochila y el oro ganado en esta bajada. Conservas el equipo puesto.")
	v[1].add_child(MenuInicio.boton("Volver a %s" % Ciudad.NOMBRE, _volver_tras_morir))
	v[1].add_child(MenuInicio.boton("Volver al menú", _ir_menu))
	return v[0]

func _volver_tras_morir() -> void:
	sim.p.bag.clear()
	sim.p.rn_new = 0
	sim.p.gold = mini(sim.p.gold, sim.oro_salida)
	sim.p.dead = false
	sim.p.death_t = 0
	sim.p.effects = []
	sim.over = false
	_ir_ciudad()

## tras vencer al jefe del piso, en la escalera: bajar, subir a Inca o seguir recogiendo
func _panel_escalera() -> Control:
	var v := _ventana("Escalera", "Has vencido al jefe de esta oleada.")
	v[1].add_child(MenuInicio.boton("Bajar", _escalera_bajar))
	v[1].add_child(MenuInicio.boton("Subir a %s" % Ciudad.NOMBRE, _ir_ciudad))
	v[1].add_child(MenuInicio.boton("Seguir en el piso", _escalera_seguir, 40))
	v[0].set_meta("caja", v[1])
	return v[0]

func _escalera_bajar() -> void:
	_escalera.visible = false
	state = "play"
	sim.begin_descend()

func _escalera_seguir() -> void:
	_escalera.visible = false
	state = "play"

func _abrir_escalera() -> void:
	sim.p.piso_max = maxi(sim.p.piso_max, sim.wave + 1)
	var caja: VBoxContainer = _escalera.get_meta("caja")
	(caja.get_child(2) as Button).text = "Bajar a la oleada %d" % (sim.wave + 1)
	_escalera.visible = true
	sim.fade = 0.0
	state = "escalera"

## la entrada a la mazmorra de Inca: una casilla por oleada alcanzada (las de jefe vencido y la siguiente)
func _abrir_puerta() -> void:
	for c in _puerta.get_children():
		c.queue_free()
	var n: int = maxi(1, sim.p.piso_max)
	var v := _ventana("La Mazmorra", "¿A qué oleada bajas?" if n > 1 else "Aún solo puedes bajar a la oleada 1.", 460)
	v[0].visible = true
	_puerta.add_child(v[0])
	var rejilla := GridContainer.new()
	rejilla.columns = mini(n, 6)
	rejilla.add_theme_constant_override("h_separation", 8)
	rejilla.add_theme_constant_override("v_separation", 8)
	var centro := CenterContainer.new()
	centro.add_child(rejilla)
	v[1].add_child(centro)
	for k in n:
		var b := MenuInicio.boton(str(k + 1), _a_mazmorra.bind(k + 1), 52)
		b.custom_minimum_size.x = 64
		if k + 1 == n:
			b.add_theme_color_override("font_color", Color(1, .9, .6))
		rejilla.add_child(b)
	v[1].add_child(MenuInicio.boton("Quedarme en %s" % Ciudad.NOMBRE, _quedarme, 40))
	_puerta.visible = true
	sim.fade = 0.0
	fx.banner_t = 0
	state = "puerta"

## puerta de una sala secreta: entrar (o salir) con un fundido a negro, o quedarse
func _panel_secreta() -> Control:
	var v := _ventana("Puerta oculta", "¿Quieres entrar?")
	v[1].add_child(MenuInicio.boton("Entrar", _cruzar_secreta))
	v[1].add_child(MenuInicio.boton("No", _no_secreta, 40))
	v[0].set_meta("caja", v[1])
	return v[0]

func _abrir_secreta() -> void:
	if _bot != null:
		_cruzar_secreta()
		return
	var sale: bool = sim.secreta_pedida.sale
	var caja: VBoxContainer = _secreta.get_meta("caja")
	(caja.get_child(1) as Label).text = "¿Vuelves a la mazmorra?" if sale else "Detrás de esta puerta hay algo. ¿Quieres entrar?"
	(caja.get_child(2) as Button).text = "Salir" if sale else "Entrar"
	_secreta.visible = true
	state = "secreta"

func _no_secreta() -> void:
	_secreta.visible = false
	sim.cancelar_secreta()
	state = "play"

## fundido a negro (la pequeña pantalla de carga), el héroe pasa al otro lado y vuelve la imagen
func _cruzar_secreta() -> void:
	_secreta.visible = false
	state = "fundido"
	if _negro == null:
		_negro = ColorRect.new()
		_negro.color = Color.BLACK
		_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
		_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_secreta.get_parent().add_child(_negro)
	_negro.modulate.a = 0.0
	_negro.visible = true
	var tw := create_tween()
	tw.tween_property(_negro, "modulate:a", 1.0, .35)
	tw.tween_callback(func():
		sim.cruzar_secreta()
		_camara(1.0))
	tw.tween_interval(.35)
	tw.tween_property(_negro, "modulate:a", 0.0, .35)
	tw.tween_callback(func():
		_negro.visible = false
		if state == "fundido":
			state = "play")

func _quedarme() -> void:
	_puerta.visible = false
	Ciudad.salir_del_portal(sim)
	state = "play"

# ======================================================================
#  Inca y bajar a la mazmorra
# ======================================================================
## a Inca: la ciudad, zona segura, con la vida y el maná llenos
func _ir_ciudad() -> void:
	_muerte.visible = false
	_escalera.visible = false
	_puerta.visible = false
	prueba = 0
	_entrar(Ciudad.generar())
	Ciudad.vaciar(sim)
	Ciudad.amueblar(sim.L, mazmorra)
	sim.p.hp = sim.p.st.maxHp
	sim.p.mana = sim.p.st.maxMana
	fx.banner("Zona segura · la mazmorra está al norte", Ciudad.NOMBRE)
	fx.hud()
	state = "play"

## de Inca a la oleada n (las que se pueden elegir: hasta piso_max)
func _a_mazmorra(n: int) -> void:
	_puerta.visible = false
	_visitas += 1
	sim.wave = n
	sim.oro_salida = sim.p.gold
	_entrar(DungeonGen.gen_level(sim.level_seed(n) + "-v%d" % _visitas, n))
	fx.banner("Derrota al jefe y baja por la escalera", "Oleada %d" % n)
	state = "play"

# ======================================================================
#  menú de inicio y pausa
# ======================================================================
## la pantalla de inicio: de fondo, un piso 1 fijo sin enemigos con el héroe quieto y la cámara girando
func _ir_menu() -> void:
	panel_efectos.visible = false
	sim.apr.cerrar_todos(sim)
	sim.apr.guardar()
	_muerte.visible = false
	_escalera.visible = false
	_puerta.visible = false
	_set_state("menu")
	hud.big_map = false
	prueba = 0
	sim.new_game(1, "menu", "knight")
	_entrar(DungeonGen.gen_level("menu-fondo", 1))
	sim.enemies.clear()
	sim.loot.clear()
	sim.cleared = true
	fx.banner_t = 0
	camara.zoom = 8.0
	camara.aplicar()
	_camara(1.0)
	_luz_menu.position = MazmorraGridMap.a3d(sim.p.x, sim.p.y) + Vector3(1.2, 2.6, 1.0)
	_luz_menu.visible = true
	hud.visible = false
	menu.mostrar("inicio")

## empieza una partida (n = 0) o el piso de prueba n con la clase elegida
func _empezar(c: String, n: int) -> void:
	clase = c
	prueba = n
	menu.visible = false
	_luz_menu.visible = false
	hud.visible = true
	camara.giro = deg_to_rad(GIRO)
	camara.zoom = Opciones.v("zoom")
	camara.aplicar()
	sim.new_game(1, "", clase)
	state = "play"
	if n > 0:
		_entrar_prueba(n)
	else:
		_ir_ciudad()   # la partida empieza en Inca

func _pausa() -> void:
	_set_state("pausa")
	hud.big_map = false
	menu.mostrar("pausa")

func _continuar() -> void:
	menu.visible = false
	state = "play"

func _opciones_cambiadas() -> void:
	Opciones.aplicar_pantalla(get_window())
	Opciones.aplicar_grafico(entorno, get_viewport())
	Opciones.aplicar_sonido()
	sim.vel_mov = Opciones.vel_mov()

## los créditos (autores y licencias de assets/creditos.json): desde el menú, al final del juego y con F1
func mostrar_creditos(si: bool = true) -> void:
	if si and state != "creditos":
		_antes_creditos = state
	_creditos.visible = si
	state = "creditos" if si else _antes_creditos
	menu.visible = not si and state in ["menu", "pausa"]
	if si:
		_creditos.empezar()

func _set_state(s: String) -> void:
	state = s
	if s == "inv":
		inventory.open()
	if s != "inv" and inventory.visible:
		inventory.close()
	if s != "char" and personaje.visible:
		personaje.visible = false

# ======================================================================
#  entrada (como en Last Knight 2D)
# ======================================================================
func _setup_input() -> void:
	var add := func(name: String, events: Array) -> void:
		if not InputMap.has_action(name):
			InputMap.add_action(name, .2)
		for e in events:
			InputMap.action_add_event(name, e)
	var key := func(k: Key) -> InputEventKey:
		var e := InputEventKey.new(); e.physical_keycode = k; return e
	var mb := func(b: MouseButton) -> InputEventMouseButton:
		var e := InputEventMouseButton.new(); e.button_index = b; return e
	add.call("lk_left", [key.call(KEY_A), key.call(KEY_LEFT)])
	add.call("lk_right", [key.call(KEY_D), key.call(KEY_RIGHT)])
	add.call("lk_up", [key.call(KEY_W), key.call(KEY_UP)])
	add.call("lk_down", [key.call(KEY_S), key.call(KEY_DOWN)])
	add.call("lk_attack", [mb.call(MOUSE_BUTTON_LEFT), key.call(KEY_J)])
	add.call("lk_block", [mb.call(MOUSE_BUTTON_RIGHT), key.call(KEY_E)])
	add.call("lk_dash", [key.call(KEY_SHIFT), key.call(KEY_K)])
	add.call("lk_skill1", [key.call(KEY_1)])
	add.call("lk_skill2", [key.call(KEY_2)])
	add.call("lk_skill3", [key.call(KEY_3)])
	add.call("lk_skill4", [key.call(KEY_4)])   # 4.ª habilidad (el orbe de muerte del señor oscuro)
	add.call("lk_use", [key.call(KEY_SPACE)])
	add.call("lk_potion", [key.call(KEY_Q)])
	add.call("lk_map", [key.call(KEY_M)])
	add.call("lk_inv", [key.call(KEY_I)])
	add.call("lk_char", [key.call(KEY_TAB), key.call(KEY_C)])
	add.call("lk_tree", [key.call(KEY_T)])
	add.call("lk_fullscreen", [key.call(KEY_F11)])

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("lk_fullscreen"):
		Opciones.poner("pantalla_completa", not Opciones.v("pantalla_completa"))
		Opciones.aplicar_pantalla(get_window())
		if menu.pagina == "opciones":
			menu._refrescar_opciones()
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_F4 and state == "play" and prueba > 0:
		panel_efectos.visible = not panel_efectos.visible
		if panel_efectos.visible:
			panel_efectos.refrescar()
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_F6 and state == "play" and prueba > 0:
		panel_efectos.probar_actual()
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_F3 and state == "play":
		_panel_apr.visible = not _panel_apr.visible
		_panel_apr_t = 0
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_F1 and state in ["play", "creditos"]:
		mostrar_creditos(state == "play")
		get_viewport().set_input_as_handled()
		return
	if state != "play" or sim.p == null:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		_pausa()
		get_viewport().set_input_as_handled()
		return
	# zoom: rueda del ratón o + y −, entre ZOOM_MIN y ZOOM_MAX metros de alto en pantalla
	var dz := 0.0
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP: dz = -1.0
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN: dz = 1.0
	elif ev is InputEventKey and ev.pressed:
		if ev.physical_keycode in [KEY_EQUAL, KEY_KP_ADD, KEY_PLUS, KEY_BRACKETRIGHT]: dz = -1.0
		elif ev.physical_keycode in [KEY_MINUS, KEY_KP_SUBTRACT, KEY_SLASH]: dz = 1.0
	if dz != 0:
		camara.zoom = clampf(camara.zoom + dz, ZOOM_MIN, ZOOM_MAX)
		camara.aplicar()
		_zoom_label.text = "Zoom: %d m" % int(camara.zoom)
		_zoom_label.modulate.a = 1.0
		_zoom_t = 2.0
		get_viewport().set_input_as_handled()
		return
	if ev.is_action_pressed("lk_map"):
		hud.big_map = not hud.big_map
		return
	if ev.is_action_pressed("lk_inv") and not sim.p.dead:
		hud.big_map = false
		_set_state("inv")
		get_viewport().set_input_as_handled()
		return
	if (ev.is_action_pressed("lk_char") or ev.is_action_pressed("lk_tree")) and not sim.p.dead:
		get_viewport().set_input_as_handled()
		_set_state("char")
		personaje.open("stats" if ev.is_action_pressed("lk_char") else "tree")
		return
	if ev.is_action_pressed("lk_attack"): _attack_edge = true
	if ev.is_action_pressed("lk_dash"): _dash_edge = true
	for i in 4:
		if ev.is_action_pressed("lk_skill%d" % (i + 1)):
			_skill_edge = i
	if ev.is_action_pressed("lk_use"): _interact_edge = true
	if ev.is_action_pressed("lk_potion"): _potion_edge = true

## la cámara mira al norte, así que W/S/A/D son norte/sur/oeste/este del mapa, igual que en 2D
func _read_input() -> Sim.Inp:
	var inp := Sim.Inp.new()
	var kx := (1 if Input.is_action_pressed("lk_right") else 0) - (1 if Input.is_action_pressed("lk_left") else 0)
	var ky := (1 if Input.is_action_pressed("lk_down") else 0) - (1 if Input.is_action_pressed("lk_up") else 0)
	# W va «hacia arriba de la pantalla»: con la cámara girada, se gira también el movimiento
	inp.move = Vector2(kx, ky).rotated(-camara.giro)
	inp.aim = _raton_en_suelo()
	inp.aim_mouse = true
	sim.ally_target = {"x": inp.aim.x, "y": inp.aim.y}
	inp.attack = _attack_edge
	inp.attack_held = Input.is_action_pressed("lk_attack")
	inp.block = Input.is_action_pressed("lk_block")
	if panel_efectos.tapa_raton():   # tocando el panel de efectos no se lanza nada
		inp.attack = false
		inp.attack_held = false
		inp.block = false
	inp.dash = _dash_edge
	inp.skill = _skill_edge
	inp.interact = _interact_edge
	inp.potion = _potion_edge
	if Ciudad.es_ciudad(sim.L):   # zona segura: en Inca no se ataca
		inp.attack = false
		inp.attack_held = false
		inp.block = false
		inp.skill = -1
	_attack_edge = false
	_dash_edge = false
	_skill_edge = -1
	_interact_edge = false
	_potion_edge = false
	return inp


## panel F3 (pruebas): los enemigos despiertos o cercanos, su táctica de ahora y lo que ha aprendido cada puesto
func _texto_aprendizaje() -> String:
	var cerca := []
	for e in sim.enemies:
		if e.dying or e.dead:
			continue
		var dist := Vector2(e.x - sim.p.x, e.y - sim.p.y).length() * MazmorraGridMap.PX_M
		if e.apr_activo or dist < 14.0:
			cerca.append([dist, e])
	cerca.sort_custom(func(a, b): return a[0] < b[0])
	var t := "Aprendizaje (F3)"
	if cerca.is_empty():
		return t + "\nNingún enemigo cerca"
	for par in cerca.slice(0, 6):
		var e: Ent.Enemy = par[1]
		var nombre: String = e.puesto if e.puesto != "" else "sin puesto"
		t += "\n\n%s · %s%s · %d combates" % [nombre, e.apr_clave, (" · " + e.apr_titulo) if e.apr_titulo != "" else "", sim.apr.combates(e.puesto)]
		t += "\n  ahora: %s" % (Aprendizaje.NOMBRE.get(e.tactica, "—") if e.apr_activo else ("dormido" if e.state == "idle" else "combate acabado"))
		var v := sim.apr.valores(e.apr_clave, e.puesto)
		var ts: Array = Aprendizaje.TACTICAS.duplicate()
		ts.sort_custom(func(a, b): return v[a] > v[b])
		var partes := []
		for k in ts:
			partes.append("%s %.2f" % [Aprendizaje.NOMBRE[k], v[k]])
		t += "\n  " + "  ".join(partes.slice(0, 3)) + "\n  " + "  ".join(partes.slice(3))
	return t

## al salir, soltar las cachés estáticas antes de que Godot apague el servidor gráfico
func _exit_tree() -> void:
	sim.apr.cerrar_todos(sim)
	sim.apr.guardar()
	KitMazmorra.limpiar()
	Props3D.limpiar()
	Ciudad.limpiar()
	Modelo3D.limpiar()
	Armadura3D.limpiar()
	Hechizos3D.limpiar()
	MazmorraGridMap.limpiar()
	Atlas.limpiar()
	Fonts.limpiar()
	UiArte.limpiar()
	Idioma.soltar()

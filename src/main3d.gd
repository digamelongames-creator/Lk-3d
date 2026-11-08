extends Node3D
## Last Knight en 3D: la misma simulación (src/core) con vista 3D, mazmorra en GridMap
## y la interfaz de siempre (HUD, inventario, personaje y árbol).
##
## Opciones de línea de órdenes (después de --):
##   --clase=knight|dk|archer|mage|dl   --piso=N   --semilla=texto   --bot   --shot=/tmp/x.png,frames
##   --inclinacion=33   --giro=45   --perspectiva
##   --prueba=N (piso de prueba N; es como arranca)   --partida (partida normal, sin piso de prueba)
##   --sala=N (en el piso de prueba, empieza en la sala N: 0 pasillo, 1–5 paquetes, 6–9 propósitos)
##   --menu (abre la pantalla de inicio aunque haya otras opciones; --menu=opciones|clase|pausa para las capturas)
## Sin opciones arranca en la pantalla de inicio (MenuInicio). Las opciones que empiezan una partida
## (--partida, --prueba, --piso, --junto, --sala, --equipo, --morir, --bot, --clase) se la saltan.

var sim := Sim.new()
var fx := Fx3D.new()
var mazmorra: MazmorraGridMap
var actores: Actores3D
var camara: CamaraIso
var hud: Hud
var inventory: Inventory
var personaje: Personaje
var state := "play"
var clase := "knight"
var _muerte: Control   # panel «Has caído» con Revivir y Nueva partida
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
var _sala := -1   # pruebas: --sala=N pone al héroe en la sala N del piso de prueba (0 = pasillo)


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
	for a in OS.get_cmdline_user_args():
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
		elif a == "--morir":   # pruebas: el héroe cae al empezar (panel de muerte)
			_morir = true
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
	mazmorra = MazmorraGridMap.new()
	add_child(mazmorra)
	actores = Actores3D.new()
	actores.sim = sim
	actores.heroe_id = heroe_id
	add_child(actores)
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
	menu = MenuInicio.new()
	menu.visible = false
	menu.empezar.connect(func(c: String): _empezar(c, 0))
	menu.piso_prueba.connect(func(): _empezar("knight", 1))
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
	if prueba > 0:
		_entrar_prueba(prueba)
	else:
		_entrar(DungeonGen.gen_level(sim.level_seed(sim.wave), sim.wave))
		fx.banner("Derrota al jefe y baja por la escalera", "Oleada %d" % sim.wave)
	if _junto != "":
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
	sim.enter_level(L)
	mazmorra.construir(sim.L)
	actores.nuevo_piso()
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
	fx.banner("Sin enemigos · F1: créditos", PisoPrueba.nombre(n))

func _bajar() -> void:
	sim.score += sim.wave * 25
	sim.p.inv = 0
	sim.wave += 1
	_entrar(DungeonGen.gen_level(sim.level_seed(sim.wave), sim.wave))
	fx.banner("Derrota al jefe y baja por la escalera", "Oleada %d" % sim.wave)
	Guardado.guardar(sim)

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
		var r := sim.step(dt, inp)
		if prueba > 0:
			sim.enemies.clear()   # el piso de prueba no tiene enemigos (ni los que aparecen por el camino)
		if r == "descend":
			_bajar()
		elif r == "over":
			state = "over"
			_muerte.visible = true
	fx.tick(dt)
	if _zoom_t > 0:
		_zoom_t -= dt
		_zoom_label.modulate.a = clampf(_zoom_t / .5, 0, 1)
	actores.actualizar(dt)
	_camara(dt)
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
#  muerte: revivir o empezar de nuevo
# ======================================================================
func _panel_muerte() -> Control:
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.visible = false
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, .55)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(fondo)
	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_CENTER)
	caja.offset_left = -170
	caja.offset_right = 170
	caja.offset_top = -110
	caja.offset_bottom = 110
	caja.add_theme_constant_override("separation", 18)
	raiz.add_child(caja)
	var titulo := Label.new()
	titulo.text = "Has caído"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_override("font", Fonts.gothic(700))
	titulo.add_theme_font_size_override("font_size", 46)
	titulo.add_theme_color_override("font_color", Color(.85, .12, .08))
	titulo.add_theme_color_override("font_outline_color", Color.BLACK)
	titulo.add_theme_constant_override("outline_size", 8)
	caja.add_child(titulo)
	caja.add_child(MenuInicio.boton("Revivir", _revivir))
	caja.add_child(MenuInicio.boton("Volver al menú", _ir_menu))
	return raiz

## se levanta en el sitio con media vida (Sim.revive), sin apartar a los enemigos
func _revivir() -> void:
	sim.revive()
	_muerte.visible = false
	state = "play"

# ======================================================================
#  menú de inicio y pausa
# ======================================================================
## la pantalla de inicio: de fondo, un piso 1 fijo sin enemigos con el héroe quieto y la cámara girando
func _ir_menu() -> void:
	_muerte.visible = false
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
	if n > 0:
		_entrar_prueba(n)
	else:
		_entrar(DungeonGen.gen_level(sim.level_seed(sim.wave), sim.wave))
		fx.banner("Derrota al jefe y baja por la escalera", "Oleada %d" % sim.wave)
	state = "play"

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
	for i in 3:
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
	inp.dash = _dash_edge
	inp.skill = _skill_edge
	inp.interact = _interact_edge
	inp.potion = _potion_edge
	_attack_edge = false
	_dash_edge = false
	_skill_edge = -1
	_interact_edge = false
	_potion_edge = false
	return inp


## al salir, soltar las cachés estáticas antes de que Godot apague el servidor gráfico
func _exit_tree() -> void:
	KitMazmorra.limpiar()
	Props3D.limpiar()
	Modelo3D.limpiar()
	Armadura3D.limpiar()
	MazmorraGridMap.limpiar()
	Atlas.limpiar()
	Fonts.limpiar()
	Idioma.soltar()

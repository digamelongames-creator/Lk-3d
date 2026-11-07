extends Node3D
## Last Knight en 3D: la misma simulación (src/core) con vista 3D, mazmorra en GridMap
## y la interfaz de siempre (HUD, inventario, personaje y árbol).
##
## Opciones de línea de órdenes (después de --):
##   --clase=knight|dk|archer|mage|dl   --piso=N   --semilla=texto   --bot   --shot=/tmp/x.png,frames
##   --inclinacion=33   --giro=45   --perspectiva

var sim := Sim.new()
var fx := Fx3D.new()
var mazmorra: MazmorraGridMap
var actores: Actores3D
var camara: CamaraIso
var hud: Hud
var inventory: Inventory
var personaje: Personaje
var state := "play"
var opciones_camara: Array = []
var heroe_id := "esqueleto"   # modelo del héroe (--heroe=… para probar otro)


var _bot: Bot = null
const ZOOM_MIN := 7.0
const ZOOM_MAX := 20.0
var _zoom_label: Label
var _zoom_t := 0.0
var _junto := ""   # pruebas: --junto=demonCaptain pone al héroe al lado de ese monstruo
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
	var clase := "knight"
	var piso := 1
	var semilla := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--clase="): clase = a.get_slice("=", 1)
		elif a.begins_with("--piso="): piso = int(a.get_slice("=", 1))
		elif a.begins_with("--semilla="): semilla = a.get_slice("=", 1)
		elif a == "--bot": _bot = Bot.new()
		elif a.begins_with("--heroe="): heroe_id = a.get_slice("=", 1)
		elif a.begins_with("--junto="): _junto = a.get_slice("=", 1)
		elif a.begins_with("--inclinacion=") or a.begins_with("--giro=") or a.begins_with("--zoom=") or a == "--perspectiva": opciones_camara.append(a)
		elif a.begins_with("--shot="):
			var p := a.get_slice("=", 1).split(",")
			_shot_path = p[0]
			_shot_frames = int(p[1]) if p.size() > 1 else 60
	CamaraIso.ambiente(self)
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
	sim.new_game(piso, semilla, clase)
	_entrar(DungeonGen.gen_level(sim.level_seed(sim.wave), sim.wave))
	fx.banner("Busca la escalera para bajar", "Oleada %d" % sim.wave)
	if _junto != "":
		for e in sim.enemies:
			if e.mon == _junto:
				for k in 16:
					var q := Vector2(e.x, e.y) + Vector2.from_angle(k * TAU / 16) * 110
					if sim.fits(q.x, q.y, 8):
						sim.p.x = q.x
						sim.p.y = q.y
						break
				break
		_camara(1.0)

func _entrar(L: Dictionary) -> void:
	fx.reset()
	sim.enter_level(L)
	mazmorra.construir(sim.L)
	actores.nuevo_piso()
	_camara(1.0)

func _bajar() -> void:
	sim.score += sim.wave * 25
	sim.p.inv = 0
	sim.wave += 1
	_entrar(DungeonGen.gen_level(sim.level_seed(sim.wave), sim.wave))
	fx.banner("Un campeón guarda la escalera" if sim.wave % 5 == 0 else "Busca la escalera para bajar", "Oleada %d" % sim.wave)
	Guardado.guardar(sim)

# ======================================================================
#  bucle
# ======================================================================
func _process(dt: float) -> void:
	_frame += 1
	dt = minf(dt, .033)
	if state == "play":
		var inp := _read_input() if _bot == null else _bot.play(sim)
		var r := sim.step(dt, inp)
		if r == "descend":
			_bajar()
		elif r == "over":
			fx.banner("Has caído", "Fin de la partida")
			state = "over"
	fx.tick(dt)
	if _zoom_t > 0:
		_zoom_t -= dt
		_zoom_label.modulate.a = clampf(_zoom_t / .5, 0, 1)
	actores.actualizar(dt)
	_camara(dt)
	if sim.p != null:
		RenderingServer.global_shader_parameter_set("pos_heroe", MazmorraGridMap.a3d(sim.p.x, sim.p.y))
	if _shot_path != "" and _frame == _shot_frames:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot_path)
		print("captura: ", _shot_path)
		get_tree().quit()

func _camara(dt: float) -> void:
	if sim.p == null:
		return
	camara.temblor = fx.temblor
	camara.seguir(MazmorraGridMap.a3d(sim.p.x, sim.p.y) + Vector3(0, 1, 0), dt)

## el punto del suelo bajo el ratón, en px de la simulación
func _raton_en_suelo() -> Vector2:
	return MazmorraGridMap.a_px(camara.suelo_bajo(get_viewport().get_mouse_position()))

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
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		return
	if state != "play" or sim.p == null:
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
	Modelo3D.limpiar()
	MazmorraGridMap.limpiar()
	Atlas.limpiar()
	Fonts.limpiar()
	Idioma.soltar()

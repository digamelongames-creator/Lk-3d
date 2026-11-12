extends Node3D
## Coliseo Mecha (prototipo): tu mecha contra otro en la arena del Coliseo.
## Combate a 3 rondas (gana quien gane 2), 99 segundos por ronda.
## «-- --prueba» enfrenta a dos IA a cámara rápida, escribe el resultado y se cierra.

const Mecha = preload("res://scripts/mecha.gd")
const IA = preload("res://scripts/ia.gd")
const Jugador = preload("res://scripts/jugador.gd")
const Coliseo = preload("res://scripts/coliseo.gd")
const Hud = preload("res://scripts/hud.gd")
const Fx = preload("res://scripts/fx.gd")

const RONDAS_PARA_GANAR := 2
const TIEMPO_RONDA := 99.0
const INICIO_J := Vector3(0, 0, 21)
const INICIO_E := Vector3(0, 0, -21)

var jugador
var enemigo
var control_j
var camara: Camera3D
var hud
var coliseo
var fx
var victorias := [0, 0]
var ronda := 0
var estado := "cuenta"
var t_estado := 0.0
var t_ronda := TIEMPO_RONDA
var prueba := false
var escala := 1.0
var animo := 0.15
var t_prueba := 0.0


func _ready() -> void:
	randomize()
	_acciones()
	prueba = "--prueba" in OS.get_cmdline_user_args()
	if prueba:
		escala = 4.0

	_ambiente()
	coliseo = Coliseo.new()
	add_child(coliseo)
	fx = Fx.new()
	add_child(fx)

	camara = Camera3D.new()
	camara.fov = 72
	camara.far = 600
	camara.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camara)
	camara.position = Vector3(0, 30, 60)
	camara.look_at(Vector3.ZERO)

	jugador = Mecha.new()
	jugador.preparar("TÚ · CENTURIÓN", Color(0.32, 0.42, 0.55), Color(0.3, 0.8, 1.0), fx)
	enemigo = Mecha.new()
	enemigo.preparar("GLADIADOR ROJO", Color(0.55, 0.2, 0.15), Color(1.0, 0.45, 0.15), fx)
	jugador.rival = enemigo
	enemigo.rival = jugador
	if prueba:
		control_j = IA.new(jugador)
	else:
		control_j = Jugador.new(jugador, camara)
		add_child(control_j)
	jugador.control = control_j
	enemigo.control = IA.new(enemigo)
	add_child(jugador)
	add_child(enemigo)
	jugador.golpeado.connect(_on_golpe.bind(jugador))
	enemigo.golpeado.connect(_on_golpe.bind(enemigo))
	jugador.destruido.connect(_on_destruido.bind(jugador))
	enemigo.destruido.connect(_on_destruido.bind(enemigo))

	hud = Hud.new()
	add_child(hud)
	hud.preparar(jugador, enemigo, null if prueba else control_j)
	_nueva_ronda()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _acciones() -> void:
	_accion("adelante", [KEY_W, KEY_UP])
	_accion("atras", [KEY_S, KEY_DOWN])
	_accion("izquierda", [KEY_A, KEY_LEFT])
	_accion("derecha", [KEY_D, KEY_RIGHT])
	_accion("impulso", [KEY_SHIFT])
	_accion("propulsor", [KEY_SPACE])
	_accion("punetazo", [KEY_F], [MOUSE_BUTTON_RIGHT])
	_accion("disparar", [], [MOUSE_BUTTON_LEFT])
	_accion("fijar", [KEY_Q], [MOUSE_BUTTON_MIDDLE])
	_accion("soltar_raton", [KEY_ESCAPE])
	_accion("reiniciar", [KEY_R])
	_accion("pantalla", [KEY_F11])


func _accion(nombre: String, teclas: Array, botones: Array = []) -> void:
	if not InputMap.has_action(nombre):
		InputMap.add_action(nombre)
	for k in teclas:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(nombre, e)
	for b in botones:
		var m := InputEventMouseButton.new()
		m.button_index = b
		InputMap.action_add_event(nombre, m)


func _ambiente() -> void:
	var cielo_mat := ProceduralSkyMaterial.new()
	cielo_mat.sky_top_color = Color(0.25, 0.45, 0.75)
	cielo_mat.sky_horizon_color = Color(0.95, 0.75, 0.55)
	cielo_mat.ground_horizon_color = Color(0.7, 0.55, 0.4)
	cielo_mat.ground_bottom_color = Color(0.3, 0.25, 0.2)
	cielo_mat.sun_angle_max = 20.0
	var cielo := Sky.new()
	cielo.sky_material = cielo_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = cielo
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.9, 0.75, 0.6)
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-38, 35, 0)
	sol.light_color = Color(1.0, 0.9, 0.75)
	sol.light_energy = 1.4
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 160.0
	add_child(sol)


# ---------------------------------------------------------------- rondas
func _nueva_ronda() -> void:
	ronda += 1
	Engine.time_scale = escala
	for b in get_tree().get_nodes_in_group("balas"):
		b.queue_free()
	jugador.restablecer(INICIO_J, 0.0)
	enemigo.restablecer(INICIO_E, PI)
	if control_j is Node:
		control_j.mirar_a(0.0)
	t_ronda = TIEMPO_RONDA
	estado = "cuenta"
	t_estado = 0.0
	hud.poner_rondas(victorias[0], victorias[1])
	hud.poner_reloj(t_ronda)
	var final: bool = victorias[0] == RONDAS_PARA_GANAR - 1 and victorias[1] == RONDAS_PARA_GANAR - 1
	hud.decir("RONDA FINAL" if final else "RONDA %d" % ronda)


func _reiniciar_combate() -> void:
	victorias = [0, 0]
	ronda = 0
	_nueva_ronda()


func _on_golpe(cantidad: float, por_punetazo: bool, quien) -> void:
	animo = minf(1.0, animo + (0.35 if por_punetazo else 0.04))
	if por_punetazo:
		_parada(0.08)
	if control_j is Node:
		if quien == jugador:
			control_j.sacudir(0.55 if por_punetazo else 0.12)
		elif por_punetazo:
			control_j.sacudir(0.35)


## Congela el tiempo un instante para que el golpe pese.
func _parada(t: float) -> void:
	if estado != "lucha":
		return
	Engine.time_scale = 0.03
	await get_tree().create_timer(t, true, false, true).timeout
	if estado == "lucha":
		Engine.time_scale = escala


func _on_destruido(quien) -> void:
	if estado != "lucha":
		return
	_fin_ronda(enemigo if quien == jugador else jugador, "K.O.")


func _fin_ronda(ganador, texto: String) -> void:
	estado = "ko"
	t_estado = 0.0
	jugador.activo = false
	enemigo.activo = false
	if ganador == jugador:
		victorias[0] += 1
	elif ganador == enemigo:
		victorias[1] += 1
	hud.poner_rondas(victorias[0], victorias[1])
	animo = 1.0
	Engine.time_scale = escala * 0.3
	var sub := "Empate" if ganador == null else ("Ganas la ronda" if ganador == jugador else "Gana %s" % enemigo.nombre)
	hud.decir(texto, sub)
	if prueba:
		print("Ronda %d: %s en %.1f s · vida %d / %d · %s" % [ronda, texto, TIEMPO_RONDA - t_ronda,
			jugador.vida, enemigo.vida, "gana A" if ganador == jugador else ("gana B" if ganador == enemigo else "empate")])


func _process(d: float) -> void:
	var real := d / maxf(Engine.time_scale, 0.001)
	t_estado += real * (escala if prueba else 1.0)

	if Input.is_action_just_pressed("pantalla"):
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN else Window.MODE_FULLSCREEN
	if Input.is_action_just_pressed("reiniciar") and not prueba:
		_reiniciar_combate()
		return

	animo = move_toward(animo, 0.15, real * 0.25)
	coliseo.mat_publico.set_shader_parameter("animo", animo)

	match estado:
		"cuenta":
			var n := 3 - int(t_estado)
			if t_estado > 1.2 and n >= 1 and hud.mensaje.text != str(n):
				hud.decir(str(n))
			if t_estado >= 3.0:
				estado = "lucha"
				jugador.activo = true
				enemigo.activo = true
				hud.decir("¡LUCHA!")
				animo = 0.8
		"lucha":
			if t_estado > 0.8 and hud.mensaje.text == "¡LUCHA!":
				hud.decir("")
			t_ronda -= d
			hud.poner_reloj(t_ronda)
			if t_ronda <= 0.0:
				var g = null
				if jugador.vida > enemigo.vida:
					g = jugador
				elif enemigo.vida > jugador.vida:
					g = enemigo
				_fin_ronda(g, "¡TIEMPO!")
		"ko":
			if t_estado > 1.2:
				Engine.time_scale = escala
			if t_estado > 3.5:
				if victorias[0] >= RONDAS_PARA_GANAR or victorias[1] >= RONDAS_PARA_GANAR:
					estado = "final"
					t_estado = 0.0
					var gano: bool = victorias[0] >= RONDAS_PARA_GANAR
					hud.decir("¡VICTORIA!" if gano else "DERROTA", "R para otro combate")
					if prueba:
						print("Combate: %d - %d" % victorias)
						print("PRUEBA: todo bien")
						get_tree().quit()
				else:
					_nueva_ronda()
		"final":
			pass

	if prueba:
		t_prueba += real
		if t_prueba > 240.0:
			print("PRUEBA: el combate no ha terminado a tiempo")
			get_tree().quit(1)

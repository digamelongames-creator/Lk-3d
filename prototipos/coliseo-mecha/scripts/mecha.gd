extends CharacterBody3D
## Un mecha hecho con formas básicas: andar, cañón que se recalienta, puñetazo,
## impulso lateral y propulsores. Lo maneja un control (jugador.gd o ia.gd)
## que rellena las órdenes de abajo al principio de cada paso de física.

signal golpeado(cantidad: float, por_punetazo: bool)
signal destruido
signal modulo_roto(nombre: String)

const Proyectil = preload("res://scripts/proyectil.gd")
const Modulos = preload("res://scripts/modulos.gd")

const VIDA_MAX := 1000.0
const VEL := 10.0
const ACEL := 45.0
const GRAVEDAD := 30.0
const ESPERA_ESCUDO := 2.5
const GIRO := 2.3  # rad/s sin carga; el peso lo baja
const IMPULSO_COSTE := 30.0
const IMPULSO_VEL := 34.0
const IMPULSO_T := 0.22
const PROPULSOR_EMPUJE := 55.0
const PROPULSOR_COSTE := 40.0
const PROPULSOR_VMAX := 9.0
const CALOR_DISPARO := 8.5
const CALOR_ENFRIA := 34.0
const CALOR_ENFRIA_BLOQUEO := 42.0
const ESPERA_ENFRIAR := 0.35
const CADENCIA := 0.14
const DANO_BALA := 26.0
const VEL_BALA := 80.0
const DISPERSION := 0.012
const PUNO_DANO := 150.0
const PUNO_ALCANCE := 6.2
const PUNO_CARGA := 0.28
const PUNO_RECARGA := 1.1
const PUNO_ESTOCADA := 20.0
const PUNO_EMPUJON := 18.0
const ATURDIDO_T := 0.5
const ALTO_CADERA := 3.2

# --- órdenes del control ---
var mover := Vector3.ZERO
var mirar_yaw := 0.0
var punto_mira := Vector3.ZERO
var disparando := false
var pedir_punetazo := false
var pedir_impulso := false
var propulsor := false

# --- estado ---
var control  # objeto con pensar(delta)
var nombre := ""
var rival  # el otro mecha
var activo := false
var muerto := false
var vida := VIDA_MAX
var vida_max := VIDA_MAX
var prop := 0.0      # energía de propulsión (impulso y vuelo)
var escudo := 0.0    # energía del escudo
var t_escudo := 0.0  # tiempo sin recibir en el escudo
var construccion: Array = []
var stats: Dictionary = {}
var nodos_modulo: Array = []
var mochila: Node3D
var burbuja: MeshInstance3D
var mat_burbuja: ShaderMaterial
var destello_escudo := 0.0
var golpes_espalda := 0  # para la prueba
var calor := 0.0
var sobrecalentado := false
var t_disparo := 0.0
var t_sin_disparar := 0.0
var t_impulso := 0.0
var dir_impulso := Vector3.ZERO
var t_puno := 0.0
var t_puno_recarga := 0.0
var t_golpe_anim := 0.0
var t_aturdido := 0.0
var vel_h := Vector3.ZERO
var empuje := Vector3.ZERO
var propulsando := false
var fx  # fx.gd

# --- piezas ---
var color_cuerpo: Color
var color_luz: Color
var mat_cuerpo: StandardMaterial3D
var mat_oscuro: StandardMaterial3D
var mat_luz: StandardMaterial3D
var cadera: Node3D
var torso: Node3D
var muslo_i: Node3D
var muslo_d: Node3D
var rodilla_i: Node3D
var rodilla_d: Node3D
var brazo_d: Node3D
var brazo_i: Node3D
var boca: Node3D
var puno: Node3D
var llamas: Array[MeshInstance3D] = []
var t_paso := 0.0
var humo: CPUParticles3D


func preparar(p_nombre: String, cuerpo: Color, luz: Color, p_fx) -> void:
	nombre = p_nombre
	color_cuerpo = cuerpo
	color_luz = luz
	fx = p_fx
	collision_layer = 2
	collision_mask = 1 | 2
	floor_snap_length = 0.6
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 1.8
	capsula.height = 6.4
	forma.shape = capsula
	forma.position.y = 3.2
	add_child(forma)
	_construir_cuerpo()
	montar([])


func pintar(p_nombre: String, cuerpo: Color, luz: Color) -> void:
	nombre = p_nombre
	color_cuerpo = cuerpo
	color_luz = luz
	mat_cuerpo.albedo_color = cuerpo
	mat_luz.albedo_color = luz
	mat_luz.emission = luz
	mat_burbuja.set_shader_parameter("color", luz.lerp(Color(0.3, 0.7, 1.0), 0.6))


func centro() -> Vector3:
	return global_position + Vector3(0, 3.6, 0)


# ---------------------------------------------------------------- cuerpo
func _mat(c: Color, rugoso := 0.55, metal := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugoso
	m.metallic = metal
	return m


func _caja(padre: Node3D, tam: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	padre.add_child(mi)
	return mi


func _cilindro(padre: Node3D, r_arriba: float, r_abajo: float, alto: float, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_arriba
	cm.bottom_radius = r_abajo
	cm.height = alto
	cm.radial_segments = 16
	mi.mesh = cm
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	padre.add_child(mi)
	return mi


func _pivote(padre: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	padre.add_child(n)
	return n


func _construir_cuerpo() -> void:
	mat_cuerpo = _mat(color_cuerpo)
	mat_cuerpo.emission_enabled = true
	mat_cuerpo.emission = Color.BLACK
	mat_oscuro = _mat(Color(0.13, 0.13, 0.15), 0.4, 0.8)
	mat_luz = StandardMaterial3D.new()
	mat_luz.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_luz.albedo_color = color_luz
	mat_luz.emission_enabled = true
	mat_luz.emission = color_luz
	mat_luz.emission_energy_multiplier = 3.0

	cadera = _pivote(self, Vector3(0, ALTO_CADERA, 0))
	_caja(cadera, Vector3(2.2, 0.8, 1.4), Vector3.ZERO, mat_oscuro)

	# piernas
	for lado in [-1.0, 1.0]:
		var muslo := _pivote(cadera, Vector3(0.95 * lado, -0.1, 0))
		_caja(muslo, Vector3(0.85, 1.7, 1.0), Vector3(0, -0.8, 0), mat_cuerpo)
		_cilindro(muslo, 0.35, 0.35, 1.1, Vector3(0, 0, 0), Vector3(0, 0, PI / 2), mat_oscuro)
		var rodilla := _pivote(muslo, Vector3(0, -1.55, 0))
		_caja(rodilla, Vector3(0.75, 0.6, 0.75), Vector3(0, 0, -0.1), mat_oscuro)
		_caja(rodilla, Vector3(0.95, 1.4, 1.05), Vector3(0, -0.75, 0.05), mat_cuerpo)
		_caja(rodilla, Vector3(1.15, 0.35, 1.9), Vector3(0, -1.45, -0.25), mat_oscuro)
		if lado < 0:
			muslo_i = muslo
			rodilla_i = rodilla
		else:
			muslo_d = muslo
			rodilla_d = rodilla

	# torso
	torso = _pivote(cadera, Vector3(0, 0.35, 0))
	_caja(torso, Vector3(3.0, 1.9, 2.0), Vector3(0, 1.1, 0), mat_cuerpo)
	_caja(torso, Vector3(2.4, 0.6, 1.6), Vector3(0, 0.15, 0), mat_oscuro)
	_caja(torso, Vector3(1.5, 0.95, 1.4), Vector3(0, 2.4, -0.25), mat_cuerpo)
	_caja(torso, Vector3(1.1, 0.24, 0.1), Vector3(0, 2.45, -0.97), mat_luz)
	_caja(torso, Vector3(0.6, 0.5, 0.1), Vector3(0, 1.1, -1.03), mat_luz)
	# brazo derecho: cañón
	brazo_d = _pivote(torso, Vector3(1.95, 1.6, 0))
	_caja(brazo_d, Vector3(1.3, 0.9, 1.6), Vector3(0.15, 0.2, 0), mat_cuerpo)
	_caja(brazo_d, Vector3(0.7, 1.2, 0.7), Vector3(0.2, -0.7, 0), mat_oscuro)
	_caja(brazo_d, Vector3(0.95, 0.95, 1.6), Vector3(0.2, -1.4, -0.3), mat_cuerpo)
	_cilindro(brazo_d, 0.3, 0.3, 2.4, Vector3(0.2, -1.4, -1.6), Vector3(PI / 2, 0, 0), mat_oscuro)
	_cilindro(brazo_d, 0.36, 0.36, 0.3, Vector3(0.2, -1.4, -2.75), Vector3(PI / 2, 0, 0), mat_cuerpo)
	boca = _pivote(brazo_d, Vector3(0.2, -1.4, -3.0))

	# brazo izquierdo: puño
	brazo_i = _pivote(torso, Vector3(-1.95, 1.6, 0))
	_caja(brazo_i, Vector3(1.3, 0.9, 1.6), Vector3(-0.15, 0.2, 0), mat_cuerpo)
	_caja(brazo_i, Vector3(0.7, 1.2, 0.7), Vector3(-0.2, -0.7, 0), mat_oscuro)
	_caja(brazo_i, Vector3(0.95, 0.95, 1.7), Vector3(-0.2, -1.4, -0.5), mat_cuerpo)
	puno = _pivote(brazo_i, Vector3(-0.2, -1.4, -1.6))
	_caja(puno, Vector3(1.3, 1.3, 1.2), Vector3.ZERO, mat_oscuro)
	_caja(puno, Vector3(1.35, 0.25, 0.3), Vector3(0, 0.3, -0.5), mat_luz)

	burbuja = MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 4.4
	esfera.height = 8.4
	burbuja.mesh = esfera
	mat_burbuja = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_ESCUDO
	mat_burbuja.shader = sh
	mat_burbuja.set_shader_parameter("color", color_luz.lerp(Color(0.3, 0.7, 1.0), 0.6))
	burbuja.material_override = mat_burbuja
	burbuja.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burbuja.position.y = 3.4
	add_child(burbuja)

	humo = CPUParticles3D.new()
	humo.emitting = false
	humo.amount = 40
	humo.lifetime = 2.0
	humo.direction = Vector3.UP
	humo.spread = 20
	humo.initial_velocity_min = 2.0
	humo.initial_velocity_max = 4.0
	humo.gravity = Vector3(0, 1.0, 0)
	humo.scale_amount_min = 0.8
	humo.scale_amount_max = 1.8
	var hm := SphereMesh.new()
	hm.radius = 0.6
	hm.height = 1.2
	hm.radial_segments = 8
	hm.rings = 4
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.1, 0.1, 0.1, 0.6)
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.material = hmat
	humo.mesh = hm
	humo.position = Vector3(0, 4.5, 0)
	add_child(humo)


const SHADER_ESCUDO := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform float carga = 1.0;
uniform float destello = 0.0;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float lineas = 0.5 + 0.5 * sin(UV.y * 120.0 + TIME * 3.0);
	ALBEDO = color.rgb * (f * (0.6 + 0.6 * carga) * (0.8 + 0.2 * lineas) + destello * 0.5);
	ALPHA = clamp(f * (0.4 + 0.5 * carga) + destello * 0.4, 0.0, 1.0);
}
"""


# ---------------------------------------------------------------- mochila
## Pone la construcción (copia) en la espalda y recalcula lo que da.
func montar(cons: Array) -> void:
	construccion = Modulos.copiar(cons)
	for p in construccion:
		p.vida = Modulos.vida_de(p.id)
	stats = Modulos.calcular(construccion)
	vida_max = VIDA_MAX + stats.vida_extra
	if mochila:
		mochila.queue_free()
	nodos_modulo.clear()
	mochila = _pivote(torso, Vector3(0, 1.3, 1.05))
	_caja(mochila, Vector3(2.45, 2.45, 0.25), Vector3.ZERO, mat_oscuro)
	var c := 0.58
	for p in construccion:
		var d: Dictionary = Modulos.CATALOGO[p.id]
		var t := Modulos.tam(p)
		var cx: float = p.pos.x + (t.x - 1) * 0.5
		var cy: float = p.pos.y + (t.y - 1) * 0.5
		var prof: float = {"escudo": 0.75, "prop": 0.65, "bateria": 0.45, "recarga": 0.45, "disipador": 0.35,
			"propulsor": 0.5, "blindaje": 0.3}[d.tipo]
		var nodo := _pivote(mochila, Vector3((cx - 1.5) * c, (1.5 - cy) * c, 0.125))
		var m := _mat(d.color, 0.45, 0.5)
		_caja(nodo, Vector3(t.x * c - 0.08, t.y * c - 0.08, prof), Vector3(0, 0, prof * 0.5), m)
		if d.tipo in ["prop", "escudo", "bateria", "recarga"]:
			_caja(nodo, Vector3(t.x * c - 0.3, 0.08, 0.06), Vector3(0, 0, prof + 0.02), mat_luz)
		if d.tipo == "disipador":
			for k in 4:
				_caja(nodo, Vector3(0.04, t.y * c - 0.15, 0.25), Vector3((k - 1.5) * 0.25, 0, prof + 0.12), mat_oscuro)
		if d.tipo == "propulsor":
			_cilindro(nodo, 0.15, 0.25, 0.4, Vector3(0, -t.y * c * 0.5, prof * 0.5), Vector3.ZERO, mat_oscuro)
		nodos_modulo.append(nodo)
	# llamas debajo de la mochila
	for l in llamas:
		l.queue_free()
	llamas.clear()
	for lado in [-0.6, 0.6]:
		_cilindro(mochila, 0.25, 0.38, 0.5, Vector3(lado, -1.4, 0.3), Vector3.ZERO, mat_oscuro)
		var llama := _cilindro(mochila, 0.3, 0.02, 1.6, Vector3(lado, -2.4, 0.3), Vector3.ZERO, mat_luz)
		llama.visible = false
		llamas.append(llama)


func _recalcular() -> void:
	stats = Modulos.calcular(construccion)
	prop = minf(prop, stats.prop_max)
	escudo = minf(escudo, stats.escudo_max)


func _danar_modulo(dano: float) -> void:
	var vivos := []
	var blindajes := []
	for i in construccion.size():
		if Modulos.vivo(construccion[i]):
			vivos.append(i)
			if Modulos.CATALOGO[construccion[i].id].tipo == "blindaje":
				blindajes.append(i)
	if vivos.is_empty():
		return
	var i: int = blindajes.pick_random() if not blindajes.is_empty() and randf() < 0.75 else vivos.pick_random()
	var p: Dictionary = construccion[i]
	p.vida -= dano
	if p.vida <= 0.0:
		p.vida = 0.0
		var nodo: Node3D = nodos_modulo[i]
		fx.chispas(nodo.global_position, global_basis.z, Color(1, 0.7, 0.3), 40, 10.0)
		fx.polvo(nodo.global_position, Vector3.ZERO)
		for h in nodo.get_children():
			h.visible = false
		_caja(nodo, Vector3(0.35, 0.35, 0.15), Vector3(0, 0, 0.08), mat_oscuro)
		_recalcular()
		modulo_roto.emit(Modulos.CATALOGO[p.id].nombre)


# ---------------------------------------------------------------- ronda
func restablecer(pos: Vector3, yaw: float) -> void:
	global_position = pos
	rotation = Vector3(0, yaw, 0)
	mirar_yaw = yaw
	velocity = Vector3.ZERO
	vel_h = Vector3.ZERO
	empuje = Vector3.ZERO
	montar(construccion)
	vida = vida_max
	prop = stats.prop_max
	escudo = stats.escudo_max
	t_escudo = 0.0
	destello_escudo = 0.0
	calor = 0.0
	sobrecalentado = false
	muerto = false
	activo = false
	t_impulso = 0.0
	t_puno = 0.0
	t_puno_recarga = 0.0
	t_aturdido = 0.0
	t_golpe_anim = 0.0
	mover = Vector3.ZERO
	disparando = false
	pedir_punetazo = false
	pedir_impulso = false
	propulsor = false
	cadera.position = Vector3(0, ALTO_CADERA, 0)
	cadera.rotation = Vector3.ZERO
	torso.rotation = Vector3.ZERO
	humo.emitting = false
	mat_cuerpo.emission = Color.BLACK
	reset_physics_interpolation()


# ---------------------------------------------------------------- paso
func _physics_process(d: float) -> void:
	if control and activo and not muerto:
		control.pensar(d)
	if not activo or muerto:
		disparando = false
		propulsor = false
		pedir_impulso = false
		pedir_punetazo = false
		mover = Vector3.ZERO

	t_disparo -= d
	t_sin_disparar += d
	t_puno_recarga -= d
	t_aturdido -= d
	t_golpe_anim -= d

	# calor
	if sobrecalentado:
		calor -= CALOR_ENFRIA_BLOQUEO * stats.enfria * d
		if calor <= 0.0:
			calor = 0.0
			sobrecalentado = false
	elif t_sin_disparar > ESPERA_ENFRIAR:
		calor = maxf(0.0, calor - CALOR_ENFRIA * stats.enfria * d)

	if not muerto:
		var giro: float = GIRO * (1.0 - 0.025 * stats.peso)
		rotation.y = rotate_toward(rotation.y, mirar_yaw, giro * d)

	# escudo
	t_escudo += d
	if t_escudo > ESPERA_ESCUDO and not muerto:
		escudo = minf(stats.escudo_max, escudo + stats.escudo_regen * d)
	destello_escudo = maxf(0.0, destello_escudo - d * 4.0)
	burbuja.visible = escudo > 1.0 and not muerto
	if burbuja.visible:
		mat_burbuja.set_shader_parameter("carga", escudo / maxf(stats.escudo_max, 1.0))
		mat_burbuja.set_shader_parameter("destello", destello_escudo)

	# impulso
	if pedir_impulso:
		pedir_impulso = false
		if prop >= IMPULSO_COSTE and t_impulso <= 0.0 and t_aturdido <= 0.0:
			prop -= IMPULSO_COSTE
			t_impulso = IMPULSO_T
			t_puno = 0.0
			dir_impulso = mover.normalized() if mover.length() > 0.2 else global_basis.z
			fx.polvo(global_position, dir_impulso)

	# puñetazo
	if pedir_punetazo:
		pedir_punetazo = false
		if t_puno_recarga <= 0.0 and t_puno <= 0.0 and t_aturdido <= 0.0 and t_impulso <= 0.0:
			t_puno = PUNO_CARGA
			t_puno_recarga = PUNO_RECARGA

	# movimiento horizontal
	var hacia_rival := Vector3.ZERO
	if rival:
		hacia_rival = rival.global_position - global_position
		hacia_rival.y = 0
	if t_impulso > 0.0:
		t_impulso -= d
		vel_h = dir_impulso * IMPULSO_VEL * stats.impulso
		if t_impulso <= 0.0:
			vel_h = dir_impulso * velocidad()
	elif t_aturdido > 0.0:
		vel_h = vel_h.move_toward(Vector3.ZERO, ACEL * d)
	elif t_puno > 0.0:
		if hacia_rival.length() < 12.0 and hacia_rival.length() > 3.5:
			vel_h = hacia_rival.normalized() * PUNO_ESTOCADA
			mirar_yaw = atan2(-hacia_rival.x, -hacia_rival.z)
		else:
			vel_h = vel_h.move_toward(Vector3.ZERO, ACEL * d)
		t_puno -= d
		if t_puno <= 0.0:
			_soltar_puno()
	else:
		var ctrl := 1.0 if is_on_floor() else 0.6
		vel_h = vel_h.move_toward(mover.limit_length(1.0) * velocidad(), ACEL * ctrl * d)

	empuje = empuje.move_toward(Vector3.ZERO, 38.0 * d)
	velocity.x = vel_h.x + empuje.x
	velocity.z = vel_h.z + empuje.z

	# vertical: propulsores
	propulsando = propulsor and prop > 0.0 and t_aturdido <= 0.0
	if propulsando:
		velocity.y = minf(velocity.y + PROPULSOR_EMPUJE * stats.empuje * d, PROPULSOR_VMAX * stats.empuje)
		prop = maxf(0.0, prop - PROPULSOR_COSTE * d)
	else:
		velocity.y -= GRAVEDAD * d
		if t_impulso <= 0.0:
			prop = minf(stats.prop_max, prop + stats.prop_regen * d * (1.0 if is_on_floor() else 0.4))

	var en_aire := not is_on_floor()
	var vy_antes := velocity.y
	move_and_slide()
	if en_aire and is_on_floor() and vy_antes < -14.0:
		fx.polvo(global_position, Vector3.ZERO)

	# disparo
	if disparando and not sobrecalentado and t_disparo <= 0.0 and t_aturdido <= 0.0 and t_puno <= 0.0 and not muerto:
		# el cañón solo apunta hacia delante: si la mira está muy de lado, hay que girar primero
		var a := punto_mira - global_position
		a.y = 0
		if a.length() < 0.5 or (-global_basis.z).angle_to(a.normalized()) < deg_to_rad(75.0):
			_disparar()

	_animar(d)


func _disparar() -> void:
	t_disparo = CADENCIA
	t_sin_disparar = 0.0
	calor += CALOR_DISPARO * stats.calor
	if calor >= 100.0:
		calor = 100.0
		sobrecalentado = true
		fx.vapor(boca.global_position)
	var desde := boca.global_position
	var dir := (punto_mira - desde).normalized()
	if dir.length() < 0.5:
		dir = -global_basis.z
	dir = (dir + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * DISPERSION).normalized()
	var p := Proyectil.new()
	p.preparar(self, desde, dir * VEL_BALA, DANO_BALA, color_luz)
	fx.add_child(p)
	fx.fogonazo(desde, color_luz)
	brazo_d.position.z = 0.35  # retroceso


func _soltar_puno() -> void:
	t_golpe_anim = 0.25
	if not rival or rival.muerto:
		return
	var a: Vector3 = rival.global_position - global_position
	var dy := absf(a.y)
	a.y = 0
	var frente := -global_basis.z
	if a.length() <= PUNO_ALCANCE and dy < 4.5 and frente.dot(a.normalized()) > 0.35:
		var dir := a.normalized()
		rival.recibir(PUNO_DANO, true, dir * PUNO_EMPUJON, dir)
		fx.chispas(rival.centro() - dir * 1.6, -dir, Color(1, 0.8, 0.4), 60, 14.0)
	else:
		fx.polvo(puno.global_position, Vector3.ZERO)


func velocidad() -> float:
	return VEL * (1.0 - 0.015 * stats.peso)


## `dir`: hacia dónde va el golpe. Si va en el mismo sentido que mira el mecha, es por la espalda.
func recibir(cantidad: float, por_punetazo: bool, empujon: Vector3, dir := Vector3.ZERO) -> void:
	if muerto or not activo:
		return
	var por_detras := dir.length() > 0.1 and dir.normalized().dot(-global_basis.z) > -0.1
	if por_detras:
		golpes_espalda += 1
	empuje += empujon
	if escudo > 0.0:
		t_escudo = 0.0
		destello_escudo = 1.0
		if por_punetazo:
			escudo = 0.0
			cantidad *= 0.5
			fx.chispas(centro(), Vector3.UP, Color(0.4, 0.8, 1.0), 70, 16.0)
		else:
			escudo -= cantidad
			cantidad = maxf(0.0, -escudo)
			escudo = maxf(0.0, escudo)
			if escudo <= 0.0:
				fx.chispas(centro(), Vector3.UP, Color(0.4, 0.8, 1.0), 50, 12.0)
		if cantidad <= 0.0:
			golpeado.emit(0.0, false)
			return
	vida = maxf(0.0, vida - cantidad)
	if por_detras:
		_danar_modulo(cantidad * (3.0 if por_punetazo else 2.0))
	if por_punetazo:
		t_aturdido = ATURDIDO_T
		t_puno = 0.0
		velocity.y = maxf(velocity.y, 4.0)
	_destello(1.0 if por_punetazo else 0.45)
	golpeado.emit(cantidad, por_punetazo)
	if vida <= 0.0:
		_morir()


func _destello(fuerza: float) -> void:
	mat_cuerpo.emission = Color(1.0, 0.75, 0.5) * fuerza
	var tw := create_tween()
	tw.tween_property(mat_cuerpo, "emission", Color.BLACK, 0.18)


func _morir() -> void:
	muerto = true
	activo = false
	fx.explosion(centro(), 2.5)
	humo.emitting = true
	var tw := create_tween().set_parallel()
	tw.tween_property(cadera, "position:y", 1.3, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(cadera, "rotation:x", 0.35, 0.9)
	tw.tween_property(torso, "rotation:x", 0.7, 1.0)
	tw.tween_property(brazo_d, "rotation:x", -0.9, 0.8)
	tw.tween_property(brazo_i, "rotation:x", -0.9, 0.8)
	destruido.emit()


# ---------------------------------------------------------------- animación
func _animar(d: float) -> void:
	for l in llamas:
		var on := (propulsando or t_impulso > 0.0) and not muerto
		l.visible = on
		if on:
			l.scale = Vector3(1, randf_range(0.8, 1.3) * (1.6 if t_impulso > 0.0 else 1.0), 1)
	if muerto:
		return
	# piernas
	var local_v := global_basis.inverse() * Vector3(velocity.x, 0, velocity.z)
	var rapidez := clampf(local_v.length() / VEL, 0.0, 1.0)
	if is_on_floor():
		t_paso += d * (2.0 + 6.5 * rapidez)
		var paso := sin(t_paso) * 0.55 * rapidez
		var signo := -1.0 if local_v.z <= 0.0 else 1.0
		muslo_i.rotation.x = paso * signo
		muslo_d.rotation.x = -paso * signo
		rodilla_i.rotation.x = maxf(0.0, -sin(t_paso)) * 0.8 * rapidez
		rodilla_d.rotation.x = maxf(0.0, sin(t_paso)) * 0.8 * rapidez
		cadera.position.y = ALTO_CADERA - absf(sin(t_paso)) * 0.15 * rapidez
		cadera.rotation.z = lerpf(cadera.rotation.z, -local_v.x / VEL * 0.08, 0.2)
	else:
		muslo_i.rotation.x = lerpf(muslo_i.rotation.x, -0.35, 0.15)
		muslo_d.rotation.x = lerpf(muslo_d.rotation.x, 0.15, 0.15)
		rodilla_i.rotation.x = lerpf(rodilla_i.rotation.x, 0.7, 0.15)
		rodilla_d.rotation.x = lerpf(rodilla_d.rotation.x, 0.3, 0.15)

	# el torso se inclina con la marcha y al aturdirse
	var incl := -local_v.z / VEL * 0.08
	if t_aturdido > 0.0:
		incl = 0.35
	torso.rotation.x = lerpf(torso.rotation.x, incl, 0.2)

	# brazo del cañón: apunta arriba/abajo hacia la mira
	var hacia := global_basis.inverse() * (punto_mira - brazo_d.global_position)
	var cabeceo := atan2(hacia.y, Vector2(hacia.x, hacia.z).length())
	brazo_d.rotation.x = lerpf(brazo_d.rotation.x, clampf(cabeceo, -0.8, 0.9), 0.3)
	brazo_d.position.z = lerpf(brazo_d.position.z, 0.0, 0.25)

	# brazo del puño
	if t_puno > 0.0:
		brazo_i.position.z = lerpf(brazo_i.position.z, 0.9, 0.35)
		brazo_i.rotation.x = lerpf(brazo_i.rotation.x, 0.25, 0.35)
	elif t_golpe_anim > 0.0:
		brazo_i.position.z = lerpf(brazo_i.position.z, -2.0, 0.6)
		brazo_i.rotation.x = lerpf(brazo_i.rotation.x, 0.0, 0.6)
	else:
		brazo_i.position.z = lerpf(brazo_i.position.z, 0.0, 0.15)
		brazo_i.rotation.x = lerpf(brazo_i.rotation.x, 0.0, 0.15)

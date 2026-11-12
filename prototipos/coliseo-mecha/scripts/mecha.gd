extends CharacterBody3D
## Un mecha hecho con formas básicas: andar, cañón que se recalienta, puñetazo,
## impulso lateral y propulsores. Lo maneja un control (jugador.gd o ia.gd)
## que rellena las órdenes de abajo al principio de cada paso de física.

signal golpeado(cantidad: float, por_punetazo: bool)
signal destruido

const Proyectil = preload("res://scripts/proyectil.gd")

const VIDA_MAX := 1000.0
const VEL := 10.0
const ACEL := 45.0
const GRAVEDAD := 30.0
const ENERGIA_MAX := 100.0
const ENERGIA_REGEN := 24.0
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
var energia := ENERGIA_MAX
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
	# mochila con toberas
	_caja(torso, Vector3(2.2, 1.5, 0.9), Vector3(0, 1.3, 1.35), mat_oscuro)
	for lado in [-0.6, 0.6]:
		_cilindro(torso, 0.25, 0.38, 0.6, Vector3(lado, 0.35, 1.5), Vector3.ZERO, mat_oscuro)
		var llama := _cilindro(torso, 0.3, 0.02, 1.6, Vector3(lado, -0.6, 1.5), Vector3.ZERO, mat_luz)
		llama.visible = false
		llamas.append(llama)

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


# ---------------------------------------------------------------- ronda
func restablecer(pos: Vector3, yaw: float) -> void:
	global_position = pos
	rotation = Vector3(0, yaw, 0)
	mirar_yaw = yaw
	velocity = Vector3.ZERO
	vel_h = Vector3.ZERO
	empuje = Vector3.ZERO
	vida = VIDA_MAX
	energia = ENERGIA_MAX
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
		calor -= CALOR_ENFRIA_BLOQUEO * d
		if calor <= 0.0:
			calor = 0.0
			sobrecalentado = false
	elif t_sin_disparar > ESPERA_ENFRIAR:
		calor = maxf(0.0, calor - CALOR_ENFRIA * d)

	if not muerto:
		rotation.y = lerp_angle(rotation.y, mirar_yaw, 1.0 - exp(-14.0 * d))

	# impulso
	if pedir_impulso:
		pedir_impulso = false
		if energia >= IMPULSO_COSTE and t_impulso <= 0.0 and t_aturdido <= 0.0:
			energia -= IMPULSO_COSTE
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
		vel_h = dir_impulso * IMPULSO_VEL
		if t_impulso <= 0.0:
			vel_h = dir_impulso * VEL
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
		vel_h = vel_h.move_toward(mover.limit_length(1.0) * VEL, ACEL * ctrl * d)

	empuje = empuje.move_toward(Vector3.ZERO, 38.0 * d)
	velocity.x = vel_h.x + empuje.x
	velocity.z = vel_h.z + empuje.z

	# vertical: propulsores
	propulsando = propulsor and energia > 0.0 and t_aturdido <= 0.0
	if propulsando:
		velocity.y = minf(velocity.y + PROPULSOR_EMPUJE * d, PROPULSOR_VMAX)
		energia = maxf(0.0, energia - PROPULSOR_COSTE * d)
	else:
		velocity.y -= GRAVEDAD * d
		if t_impulso <= 0.0:
			energia = minf(ENERGIA_MAX, energia + ENERGIA_REGEN * d * (1.0 if is_on_floor() else 0.4))

	var en_aire := not is_on_floor()
	var vy_antes := velocity.y
	move_and_slide()
	if en_aire and is_on_floor() and vy_antes < -14.0:
		fx.polvo(global_position, Vector3.ZERO)

	# disparo
	if disparando and not sobrecalentado and t_disparo <= 0.0 and t_aturdido <= 0.0 and t_puno <= 0.0 and not muerto:
		_disparar()

	_animar(d)


func _disparar() -> void:
	t_disparo = CADENCIA
	t_sin_disparar = 0.0
	calor += CALOR_DISPARO
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
		rival.recibir(PUNO_DANO, true, dir * PUNO_EMPUJON)
		fx.chispas(rival.centro() - dir * 1.6, -dir, Color(1, 0.8, 0.4), 60, 14.0)
	else:
		fx.polvo(puno.global_position, Vector3.ZERO)


func recibir(cantidad: float, por_punetazo: bool, empujon: Vector3) -> void:
	if muerto or not activo:
		return
	vida = maxf(0.0, vida - cantidad)
	empuje += empujon
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

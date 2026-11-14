extends Node
## Control del jugador: ratón y teclado, cámara en tercera persona detrás del hombro
## y apuntado con ayuda (si el rival está cerca de la mira, el cañón va a él).

const SENS := 0.0025

var mecha  # mecha.gd
var camara: Camera3D
var yaw := 0.0
var pitch := -0.12
var fijado := false
var asistido := false
var temblor := 0.0
var distancia := 12.0


func _init(p_mecha, p_camara: Camera3D) -> void:
	mecha = p_mecha
	camara = p_camara


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func mirar_a(p_yaw: float) -> void:
	yaw = p_yaw
	pitch = -0.12


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * SENS
		pitch = clampf(pitch - e.relative.y * SENS, -0.85, 0.55)
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("soltar_raton"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif e.is_action_pressed("fijar"):
		fijado = not fijado


## Lo llama el mecha al principio de su paso de física.
func pensar(d: float) -> void:
	var r = mecha.rival
	if fijado and r and not r.muerto:
		var a: Vector3 = r.global_position - mecha.global_position
		yaw = lerp_angle(yaw, atan2(-a.x, -a.z), 1.0 - exp(-10.0 * d))

	var v := Input.get_vector("izquierda", "derecha", "adelante", "atras")
	var adelante := Vector3(-sin(yaw), 0, -cos(yaw))
	var derecha := Vector3(cos(yaw), 0, -sin(yaw))
	mecha.mover = (derecha * v.x - adelante * v.y).limit_length(1.0)
	mecha.mirar_yaw = yaw

	# mira: rayo desde el centro de la cámara
	var origen := camara.global_position
	var dir := -camara.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(origen, origen + dir * 300.0)
	q.exclude = [mecha.get_rid()]
	var hit: Dictionary = mecha.get_world_3d().direct_space_state.intersect_ray(q)
	var punto: Vector3 = hit.position if not hit.is_empty() else origen + dir * 300.0
	asistido = false
	if r and not r.muerto:
		var al_rival: Vector3 = r.centro() - origen
		if rad_to_deg(dir.angle_to(al_rival)) < float(mecha.stats.ayuda):
			asistido = true
			var vel_bala := 80.0
			for l in mecha.LADOS:
				if mecha.brazos[l].f.tipo == "disparo":
					vel_bala = mecha.brazos[l].f.vel
			punto = r.centro() + r.velocity * (al_rival.length() / vel_bala) * 0.5
	mecha.punto_mira = punto

	# clic izquierdo: brazo derecho · clic derecho (o F): brazo izquierdo
	var capturado := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	mecha.gatillo_d = Input.is_action_pressed("disparar") and capturado
	mecha.gatillo_i = Input.is_action_pressed("punetazo") and capturado
	if Input.is_action_just_pressed("impulso"):
		mecha.pedir_impulso = true
	mecha.propulsor = Input.is_action_pressed("propulsor")


func _process(d: float) -> void:
	var base: Vector3 = mecha.get_global_transform_interpolated().origin + Vector3(0, 5.6, 0)
	var giro := Basis.from_euler(Vector3(pitch, yaw, 0))
	var deseado := base + giro * Vector3(2.4, 0.9, distancia)
	# que la cámara no atraviese el muro ni las columnas
	var q := PhysicsRayQueryParameters3D.create(base, deseado)
	q.collision_mask = 1
	var hit: Dictionary = mecha.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		deseado = base.lerp(hit.position, 0.9)
	temblor = maxf(0.0, temblor - d * 2.5)
	var sacudida := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * temblor * temblor * 0.6
	camara.global_transform = Transform3D(giro, deseado + giro * sacudida)
	camara.fov = lerpf(camara.fov, 82.0 if mecha.t_impulso > 0.0 else 72.0, 1.0 - exp(-10.0 * d))


func sacudir(fuerza: float) -> void:
	temblor = minf(1.2, temblor + fuerza)

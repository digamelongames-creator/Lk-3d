extends RefCounted
## Piloto de la máquina: rodea al rival a media distancia, dispara a ráfagas cuidando el calor,
## esquiva algunas balas con el impulso, se acerca a dar puñetazos y salta de vez en cuando.

const A := 40.0
const B := 30.0

var mecha  # mecha.gd
var punteria := 1.0      # 1 = normal; más alto, falla más
var reflejos := 0.35     # probabilidad de esquivar una bala que viene

var lado := 1.0
var dist_pref := 16.0
var agresivo := false
var t_decision := 0.0
var t_rafaga := 0.0
var en_rafaga := false
var t_vista := 0.0
var le_ve := true
var t_reaccion := 0.0
var t_salto := 0.0
var t_propulsor := 0.0
var error := Vector3.ZERO
var balas_vistas := {}


func _init(p_mecha) -> void:
	mecha = p_mecha


func pensar(d: float) -> void:
	var r = mecha.rival
	if r == null or r.muerto:
		mecha.disparando = false
		mecha.mover = Vector3.ZERO
		return
	var a: Vector3 = r.global_position - mecha.global_position
	a.y = 0
	var dist := a.length()
	var dir := a / maxf(dist, 0.01)
	mecha.mirar_yaw = atan2(-dir.x, -dir.z)

	# decisiones cada poco
	t_decision -= d
	if t_decision <= 0.0:
		t_decision = randf_range(1.0, 2.6)
		if randf() < 0.45:
			lado = -lado
		agresivo = randf() < 0.3
		dist_pref = randf_range(6.0, 10.0) if agresivo else randf_range(13.0, 22.0)
		error = Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)) * 0.9 * punteria

	# movimiento: rodear + acercarse o alejarse
	var tang := Vector3(-dir.z, 0, dir.x) * lado
	var radial := dir * clampf((dist - dist_pref) / 4.0, -1.0, 1.0)
	var m := tang * 0.85 + radial
	# no pegarse al muro
	var p: Vector3 = mecha.global_position
	var e := pow(p.x / (A - 4.0), 2) + pow(p.z / (B - 4.0), 2)
	if e > 0.7:
		m += -Vector3(p.x / A, 0, p.z / B).normalized() * (e - 0.7) * 4.0
		if e > 0.9:
			lado = -lado if randf() < d * 2.0 else lado
	mecha.mover = m.limit_length(1.0)

	# puñetazo
	if dist < 8.5 and mecha.t_puno_recarga <= 0.0 and randf() < (6.0 if agresivo else 2.5) * d:
		mecha.pedir_punetazo = true

	# esquivar: puñetazo que viene o balas
	t_reaccion -= d
	if t_reaccion <= 0.0 and mecha.energia >= 30.0:
		if r.t_puno > 0.0 and dist < 12.0 and randf() < 0.5:
			mecha.mover = tang
			mecha.pedir_impulso = true
			t_reaccion = 0.8
		else:
			for b in mecha.get_tree().get_nodes_in_group("balas"):
				if b.dueno == mecha or balas_vistas.has(b.get_instance_id()):
					continue
				var hacia: Vector3 = mecha.centro() - b.global_position
				if hacia.length() < 30.0 and b.vel.normalized().dot(hacia.normalized()) > 0.97:
					balas_vistas[b.get_instance_id()] = true
					if randf() < reflejos:
						mecha.mover = tang if randf() < 0.7 else -tang
						mecha.pedir_impulso = true
						t_reaccion = 0.9
					break
	if balas_vistas.size() > 200:
		balas_vistas.clear()

	# saltos
	t_salto -= d
	if t_salto <= 0.0:
		t_salto = randf_range(3.0, 7.0)
		if randf() < 0.5:
			t_propulsor = randf_range(0.4, 0.9)
	t_propulsor -= d
	mecha.propulsor = t_propulsor > 0.0

	# disparo a ráfagas, con línea de tiro
	t_vista -= d
	if t_vista <= 0.0:
		t_vista = 0.2
		var q := PhysicsRayQueryParameters3D.create(mecha.boca.global_position, r.centro())
		q.exclude = [mecha.get_rid(), r.get_rid()]
		q.collision_mask = 1
		le_ve = mecha.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	t_rafaga -= d
	if t_rafaga <= 0.0:
		en_rafaga = not en_rafaga
		t_rafaga = randf_range(0.6, 1.3) if en_rafaga else randf_range(0.3, 0.9)
	var limite_calor := 92.0 if agresivo else 78.0
	mecha.disparando = le_ve and en_rafaga and mecha.calor < limite_calor and dist < 60.0

	# puntería con adelanto
	var tiempo: float = dist / mecha.VEL_BALA
	mecha.punto_mira = r.centro() + r.velocity * tiempo * randf_range(0.6, 1.0) + error * (0.5 + dist * 0.06)

extends Node3D
## Bala del cañón: avanza en línea recta y mira con un rayo si ha chocado en el último paso.

var dueno
var vel := Vector3.ZERO
var dano := 0.0
var color := Color.WHITE
var vida_t := 2.0
var tam := 1.0
var empujon := 1.5


func preparar(p_dueno, desde: Vector3, p_vel: Vector3, p_dano: float, p_color: Color, p_vida := 2.0, p_tam := 1.0, p_empujon := 1.5) -> void:
	dueno = p_dueno
	vel = p_vel
	dano = p_dano
	color = p_color
	vida_t = p_vida
	tam = p_tam
	empujon = p_empujon
	position = desde
	add_to_group("balas")


func _ready() -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22 * tam, 0.22 * tam, 2.2 * sqrt(tam))
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 6.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	look_at(global_position + vel, Vector3.UP if absf(vel.normalized().y) < 0.99 else Vector3.RIGHT)


func _physics_process(d: float) -> void:
	var desde := global_position
	var hasta := desde + vel * d
	var q := PhysicsRayQueryParameters3D.create(desde, hasta)
	if is_instance_valid(dueno):
		q.exclude = [dueno.get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		var fx = get_parent()
		if r.collider.has_method("recibir"):
			r.collider.recibir(dano, false, vel.normalized() * empujon, vel.normalized())
			fx.chispas(r.position, r.normal, color, 18, 9.0)
		else:
			fx.chispas(r.position, r.normal, Color(0.85, 0.75, 0.55), 10, 6.0)
		if tam > 1.5:
			fx.explosion(r.position, 0.8)
		queue_free()
		return
	global_position = hasta
	vida_t -= d
	if vida_t <= 0.0:
		queue_free()

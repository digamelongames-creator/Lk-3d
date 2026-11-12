extends Node3D
## Efectos de un solo disparo: chispas, fogonazos, polvo, vapor y explosiones.
## También es el padre de las balas.


func _particulas(pos: Vector3, cant: int, vida: float, color: Color, tam: float, unshaded := true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = cant
	p.lifetime = vida
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * tam
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 4.0
	bm.material = m
	p.mesh = bm
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(vida + 0.3, false).timeout.connect(p.queue_free)
	return p


func chispas(pos: Vector3, normal: Vector3, color: Color, cant: int, fuerza: float) -> void:
	var p := _particulas(pos, cant, 0.45, color, 0.12)
	p.direction = normal if normal.length() > 0.1 else Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = fuerza * 0.5
	p.initial_velocity_max = fuerza * 1.4
	p.gravity = Vector3(0, -20, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	_luz(pos, color, 0.08, 6.0)


func fogonazo(pos: Vector3, color: Color) -> void:
	var p := _particulas(pos, 6, 0.08, color.lerp(Color.WHITE, 0.5), 0.35)
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3.ZERO


func polvo(pos: Vector3, dir: Vector3) -> void:
	var p := _particulas(pos + Vector3(0, 0.3, 0), 24, 0.9, Color(0.72, 0.62, 0.45), 0.6, false)
	p.direction = (-dir + Vector3.UP * 0.4).normalized() if dir.length() > 0.1 else Vector3.UP
	p.spread = 70.0 if dir.length() > 0.1 else 90.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3(0, -4, 0)
	p.damping_min = 4.0
	p.damping_max = 6.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6


func vapor(pos: Vector3) -> void:
	var p := _particulas(pos, 20, 1.0, Color(0.9, 0.9, 0.9), 0.4, false)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, 2, 0)


func explosion(pos: Vector3, tam: float) -> void:
	var p := _particulas(pos, 80, 1.0, Color(1.0, 0.55, 0.15), 0.5 * tam)
	p.spread = 180.0
	p.initial_velocity_min = 6.0 * tam
	p.initial_velocity_max = 14.0 * tam
	p.gravity = Vector3(0, -12, 0)
	p.damping_min = 3.0
	p.damping_max = 5.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.5
	chispas(pos, Vector3.UP, Color(1, 0.9, 0.5), 60, 20.0)
	polvo(pos - Vector3(0, 3, 0), Vector3.ZERO)
	_luz(pos, Color(1, 0.6, 0.2), 0.5, 30.0)


func _luz(pos: Vector3, color: Color, t: float, alcance: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 4.0
	l.omni_range = alcance
	l.position = pos
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, t)
	tw.tween_callback(l.queue_free)

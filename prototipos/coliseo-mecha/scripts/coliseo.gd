extends Node3D
## El Coliseo hecho con formas básicas: arena elíptica, podio, gradas con público,
## fachada de tres pisos de arcos (con el lado roto, como el de verdad) y columnas caídas
## en la arena que sirven de cobertura.

const A := 40.0  # semieje mayor de la arena (x)
const B := 30.0  # semieje menor (z)

var mat_publico: ShaderMaterial

const SHADER_PUBLICO := """
shader_type spatial;
uniform float animo = 0.15;
void vertex() {
	float f = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
	VERTEX.y += abs(sin(TIME * (5.0 + f * 5.0) + f * 6.28)) * animo * 0.7;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
}
"""


func _ready() -> void:
	var piedra := _mat(Color(0.86, 0.79, 0.66))
	var piedra_os := _mat(Color(0.66, 0.59, 0.49))
	var sombra := _mat(Color(0.22, 0.19, 0.17))
	var marmol := _mat(Color(0.93, 0.91, 0.86), 0.35)
	var rojo := _mat(Color(0.55, 0.12, 0.08))

	_suelo()

	# podio (muro de la arena) y su colisión alta para que nadie salga volando
	var cuerpo := StaticBody3D.new()
	cuerpo.collision_layer = 1
	add_child(cuerpo)
	var n := 72
	var tr_podio: Array[Transform3D] = []
	var tr_banda: Array[Transform3D] = []
	for i in n:
		var s := _segmento(i, n, A + 1.2, B + 1.2)
		tr_podio.append(_tr(s, Vector3(s.largo + 0.2, 6.0, 1.6), 3.0))
		tr_banda.append(_tr(s, Vector3(s.largo + 0.25, 0.7, 1.7), 5.2))
		var col := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(s.largo + 0.4, 80.0, 1.6)
		col.shape = caja
		col.transform = _tr(s, Vector3.ONE, 40.0)
		cuerpo.add_child(col)
	_multi(tr_podio, marmol)
	_multi(tr_banda, rojo)

	# puertas en los extremos
	for lado in [-1.0, 1.0]:
		var p := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.4, 4.6, 6.0)
		p.mesh = bm
		p.material_override = sombra
		p.position = Vector3(lado * (A + 0.35), 2.3, 0)
		add_child(p)

	# gradas escalonadas y público
	var tr_gradas: Array[Transform3D] = []
	var tr_publico: Array[Transform3D] = []
	var col_publico: Array[Color] = []
	var paleta := [Color(0.75, 0.2, 0.15), Color(0.9, 0.85, 0.75), Color(0.25, 0.35, 0.6), Color(0.55, 0.45, 0.3),
		Color(0.85, 0.65, 0.2), Color(0.35, 0.5, 0.3), Color(0.6, 0.3, 0.5), Color(0.95, 0.95, 0.9)]
	for k in 6:
		var off := 2.0 + k * 3.4
		var alto := 6.5 + k * 2.6
		for i in n:
			var s := _segmento(i, n, A + off + 1.7, B + off + 1.7)
			tr_gradas.append(_tr(s, Vector3(s.largo + 0.3, alto, 3.4), alto * 0.5))
			for j in 7:
				if randf() < 0.15:
					continue
				var t := (float(j) + randf_range(0.2, 0.8)) / 7.0 - 0.5
				var pos: Vector3 = s.pos + s.tangente * s.largo * t + s.fuera * randf_range(-1.0, 1.0)
				pos.y = alto + 0.45
				tr_publico.append(Transform3D(Basis.from_euler(Vector3(0, randf() * TAU, 0)), pos))
				col_publico.append(paleta[randi() % paleta.size()] * randf_range(0.8, 1.1))
	_multi(tr_gradas, piedra_os)
	mat_publico = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_PUBLICO
	mat_publico.shader = sh
	_multi(tr_publico, mat_publico, Vector3(0.55, 0.9, 0.45), col_publico)

	# fachada de arcos (3 pisos y ático); entre 0,55π y 1,05π falta la parte alta (lado roto)
	var nf := 80
	var tr_pilar: Array[Transform3D] = []
	var tr_dintel: Array[Transform3D] = []
	var tr_atico: Array[Transform3D] = []
	var tr_fondo: Array[Transform3D] = []
	for i in nf:
		var s := _segmento(i, nf, A + 23.0, B + 23.0)
		var roto: bool = s.ang > PI * 0.55 and s.ang < PI * 1.05
		var pisos := 3
		if roto:
			pisos = 2 if fmod(s.ang * 7.0, 1.0) > 0.35 else 1
		var esquina: Vector3 = s.pos - s.tangente * s.largo * 0.5
		for p in pisos:
			var y0 := p * 9.0
			tr_pilar.append(Transform3D(_tr(s, Vector3(1.7, 9.0, 2.8), 0.0).basis, esquina + Vector3(0, y0 + 4.5, 0)))
			tr_dintel.append(_tr(s, Vector3(s.largo + 0.1, 1.3, 3.0), y0 + 8.35))
			tr_dintel.append(_tr(s, Vector3(s.largo + 0.1, 0.35, 3.3), y0 + 0.2))
		if not roto:
			tr_atico.append(_tr(s, Vector3(s.largo + 0.1, 5.0, 2.6), 29.5))
		var s2 := _segmento(i, nf, A + 25.5, B + 25.5)
		tr_fondo.append(_tr(s2, Vector3(s2.largo + 0.3, pisos * 9.0 - 0.5, 1.0), (pisos * 9.0 - 0.5) * 0.5))
	_multi(tr_pilar, piedra)
	_multi(tr_dintel, piedra)
	_multi(tr_atico, piedra)
	_multi(tr_fondo, sombra)

	# cobertura en la arena: columnas caídas y un pedestal central
	for c in [[-15.0, -7.0, 7.0], [15.0, 7.0, 5.0], [-13.0, 12.0, 9.0], [13.0, -12.0, 4.0], [-27.0, 0.0, 6.0], [27.0, 0.0, 8.0]]:
		_columna(Vector3(c[0], 0, c[1]), c[2], marmol)
	_pedestal(marmol, piedra_os)


func _mat(c: Color, rugoso := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugoso
	return m


func _segmento(i: int, n: int, a: float, b: float) -> Dictionary:
	var t0 := TAU * i / n
	var t1 := TAU * (i + 1) / n
	var p0 := Vector3(a * cos(t0), 0, b * sin(t0))
	var p1 := Vector3(a * cos(t1), 0, b * sin(t1))
	var tang := (p1 - p0).normalized()
	return {
		"pos": (p0 + p1) * 0.5,
		"largo": p0.distance_to(p1),
		"tangente": tang,
		"fuera": Vector3(tang.z, 0, -tang.x),
		"ang": (t0 + t1) * 0.5,
		"giro": atan2(-tang.z, tang.x),
	}


func _tr(s: Dictionary, tam: Vector3, y: float) -> Transform3D:
	var base := Basis(Vector3.UP, s.giro) * Basis.from_scale(tam)
	var p: Vector3 = s.pos
	p.y = y
	return Transform3D(base, p)


func _multi(trs: Array[Transform3D], mat: Material, tam := Vector3.ONE, colores: Array[Color] = []) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colores.is_empty()
	var bm := BoxMesh.new()
	bm.size = tam
	mm.mesh = bm
	mm.instance_count = trs.size()
	for i in trs.size():
		mm.set_instance_transform(i, trs[i])
		if mm.use_colors:
			mm.set_instance_color(i, colores[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)


func _suelo() -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.collision_layer = 1
	var col := CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	cuerpo.add_child(col)
	add_child(cuerpo)

	var exterior := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	exterior.mesh = pm
	exterior.material_override = _mat(Color(0.45, 0.42, 0.33))
	exterior.position.y = -0.02
	add_child(exterior)

	var arena := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.1
	cm.radial_segments = 64
	arena.mesh = cm
	arena.scale = Vector3(A + 2.0, 1.0, B + 2.0)
	arena.position.y = -0.04
	var m := StandardMaterial3D.new()
	var ruido := FastNoiseLite.new()
	ruido.frequency = 0.02
	var tex := NoiseTexture2D.new()
	tex.noise = ruido
	tex.seamless = true
	var rampa := Gradient.new()
	rampa.set_color(0, Color(0.74, 0.6, 0.4))
	rampa.set_color(1, Color(0.9, 0.78, 0.56))
	tex.color_ramp = rampa
	m.albedo_texture = tex
	m.uv1_scale = Vector3(6, 6, 6)
	m.roughness = 1.0
	arena.material_override = m
	add_child(arena)


func _columna(pos: Vector3, alto: float, mat: Material) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.position = pos
	add_child(cuerpo)
	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 1.4
	cs.height = alto
	col.shape = cs
	col.position.y = alto * 0.5
	cuerpo.add_child(col)
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.4, 0.8, 3.4)
	base.mesh = bm
	base.position.y = 0.4
	base.material_override = mat
	cuerpo.add_child(base)
	var fuste := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.15
	cm.bottom_radius = 1.35
	cm.height = alto
	cm.radial_segments = 20
	fuste.mesh = cm
	fuste.position.y = alto * 0.5
	fuste.rotation = Vector3(randf_range(-0.04, 0.04), 0, randf_range(-0.04, 0.04))
	fuste.material_override = mat
	cuerpo.add_child(fuste)


func _pedestal(mat: Material, mat2: Material) -> void:
	var cuerpo := StaticBody3D.new()
	add_child(cuerpo)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6, 1.6, 6)
	col.shape = bs
	col.position.y = 0.8
	cuerpo.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(6, 1.6, 6)
	mi.mesh = bm
	mi.position.y = 0.8
	mi.material_override = mat2
	cuerpo.add_child(mi)
	var col2 := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 1.0
	cs.height = 3.5
	col2.shape = cs
	col2.position.y = 3.35
	cuerpo.add_child(col2)
	var estatua := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.7
	cm.bottom_radius = 1.0
	cm.height = 3.5
	estatua.mesh = cm
	estatua.position.y = 3.35
	estatua.rotation.z = 0.08
	estatua.material_override = mat
	cuerpo.add_child(estatua)

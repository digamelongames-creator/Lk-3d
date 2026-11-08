class_name Fx3D
extends SimFx
## Lo que la simulación pide que se vea (SimFx), dibujado en 3D: chispas, sangre, números de daño,
## charcos, temblor de cámara y carteles. Sustituye a ViewFx (la versión 2D).

var raiz: Node3D
var sim: Sim
var temblor := 0.0
var banner_top := ""
var banner_main := ""
var banner_t := 0.0
var _charcos: Array[Node3D] = []
const MAX_CHARCOS := 120

func tick(dt: float) -> void:
	banner_t = maxf(0, banner_t - dt)
	temblor = maxf(0, temblor - dt * 2.5)

func burst(x: float, y: float, z: float, cols: Array, n: int, spd: float) -> void:
	_chispas(MazmorraGridMap.a3d(x, y, z), _c(cols[0] if cols.size() else "#ffffff"), n, spd * MazmorraGridMap.PX_M, false)

func bleed(x: float, y: float, z: float, ang: float, n: int, spd: float, spread: float = .9) -> void:
	_gotas(MazmorraGridMap.a3d(x, y, z), ang, n, spd * MazmorraGridMap.PX_M, spread)

func esquirlas(x: float, y: float, z: float, ang: float, n: int, spd: float, tipo: String) -> void:
	var p := MazmorraGridMap.a3d(x, y, z)
	if tipo == "hueso":
		_trozos(p, ang, n, spd * MazmorraGridMap.PX_M, _malla_hueso(), 9.8, .7)
	else:
		_trozos(p, ang, n, spd * MazmorraGridMap.PX_M * .7, _malla_brasa(), 1.5, .9)

## mancha de sangre en el suelo: se queda todo el piso (decidido por Diego)
func stain(x: float, y: float, col: String, sz: int = 1) -> void:
	_mancha(MazmorraGridMap.a3d(x, y), (.08 + randf() * .07) * sz, _c(col).darkened(.45))

func text(x: float, y: float, txt: String, col: String, size: float = 10, crit: bool = false, life: float = .8, slow: bool = false, jitter: bool = true) -> void:
	if raiz == null:
		return
	var l := Label3D.new()
	l.text = txt
	l.modulate = _c(col)
	l.outline_modulate = Color.BLACK
	l.outline_size = 10
	l.font_size = int(size * (5 if crit else 4))
	l.outline_size = 14 if crit else 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = MazmorraGridMap.a3d(x + (randf() - .5) * 10 if jitter else x, y, 40)
	raiz.add_child(l)
	if crit:   # el crítico salta: sale grande y se encoge
		l.scale = Vector3.ONE * 1.9
		l.create_tween().tween_property(l, "scale", Vector3.ONE, .14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y + (.8 if slow else 1.5), life)
	tw.tween_property(l, "modulate:a", 0.0, life).set_delay(life * .4)
	tw.chain().tween_callback(l.queue_free)

func banner(top: String, main: String) -> void:
	banner_top = top
	banner_main = main
	banner_t = 1.6

func shake(v: float) -> void:
	temblor = minf(1.0, temblor + v * .08)

func pool(x: float, y: float, r: float) -> void:
	_charco(MazmorraGridMap.a3d(x, y), r * MazmorraGridMap.PX_M)

func blood_pool(o, r: float) -> void:
	_charco(MazmorraGridMap.a3d(o.x, o.y), r * MazmorraGridMap.PX_M)

func reset() -> void:
	for c in _charcos:
		if is_instance_valid(c):
			c.queue_free()
	_charcos.clear()
	if is_instance_valid(_manchas):
		_manchas.queue_free()
	_manchas = null
	_n_manchas = 0

## aviso en el suelo: un aro del radio del golpe y un disco que se llena hasta que cae
func aviso(x: float, y: float, r: float, t: float, col: String) -> void:
	if raiz == null:
		return
	var c := _c(col)
	var rm := r * MazmorraGridMap.PX_M
	var n := Node3D.new()
	n.position = MazmorraGridMap.a3d(x, y) + Vector3(0, .04, 0)
	var aro := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = rm - .08
	tm.outer_radius = rm
	tm.rings = 48
	tm.material = _mat_brillo(c, .9)
	aro.mesh = tm
	aro.scale = Vector3(1, .05, 1)
	n.add_child(aro)
	var disco := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rm
	cm.bottom_radius = rm
	cm.height = .01
	cm.radial_segments = 48
	cm.material = _mat_brillo(c, .35)
	disco.mesh = cm
	disco.scale = Vector3(.05, 1, .05)
	n.add_child(disco)
	raiz.add_child(n)
	var tw := n.create_tween()
	tw.tween_property(disco, "scale", Vector3.ONE, t)
	tw.tween_callback(n.queue_free)

## sonidos sintetizados (tools/sonidos.py → assets/sonidos/*.wav); varias tomas por sonido si hay _1, _2…
var _sonidos := {}
var _voces: Array[AudioStreamPlayer] = []
var _voz := 0
const VOCES := 16
const VOLUMEN := {"impacto": -4.0, "critico": -2.0, "muerte_enemigo": -5.0, "oro": -10.0, "herido": -3.0, "bloqueo": -4.0,
	"explosion": 0.0, "onda": 0.0, "jefe": -1.0, "jefe_muere": 0.0, "invocar": -5.0, "carga": -6.0, "elite": -4.0,
	"escudo_roto": -4.0, "escalera_cerrada": -6.0}

func sonido(id: StringName, x: float, y: float) -> void:
	if raiz == null or not raiz.is_inside_tree():
		return
	var tomas: Array = _tomas(String(id))
	if tomas.is_empty():
		return
	# más bajo cuanto más lejos del héroe; a más de 30 m no se oye
	var d := 0.0
	if sim != null and sim.p != null:
		d = Vector2(x - sim.p.x, y - sim.p.y).length() * MazmorraGridMap.PX_M
	if d > 30:
		return
	if _voces.is_empty():
		for i in VOCES:
			var v := AudioStreamPlayer.new()
			raiz.add_child(v)
			_voces.append(v)
	var v := _voces[_voz]
	_voz = (_voz + 1) % VOCES
	v.stream = tomas[randi() % tomas.size()]
	v.pitch_scale = randf_range(.92, 1.08)
	v.volume_db = float(VOLUMEN.get(String(id), -4.0)) - d * .5
	v.play()

func _tomas(id: String) -> Array:
	if _sonidos.has(id):
		return _sonidos[id]
	var t := []
	var base := "res://assets/sonidos/%s" % id
	if ResourceLoader.exists(base + ".wav"):
		t.append(load(base + ".wav"))
	for i in range(1, 6):
		if ResourceLoader.exists("%s_%d.wav" % [base, i]):
			t.append(load("%s_%d.wav" % [base, i]))
	_sonidos[id] = t
	return t

# ---------- piezas ----------
## gotas de sangre: redondas, de borde suave, que se estiran en la dirección en que vuelan;
## al caer dejan su mancha en el suelo
func _gotas(p: Vector3, ang: float, n: int, v: float, spread: float) -> void:
	if raiz == null:
		return
	var f := CPUParticles3D.new()
	f.one_shot = true
	f.emitting = true
	f.explosiveness = .9
	f.amount = clampi(n, 2, 40)
	f.lifetime = .7
	f.position = p
	f.direction = Vector3(cos(ang), 1.1, sin(ang)).normalized()
	f.spread = clampf(rad_to_deg(spread) * .55, 18, 75)
	f.initial_velocity_min = v * .35
	f.initial_velocity_max = v * 1.1
	f.gravity = Vector3(0, -12, 0)
	f.particle_flag_align_y = true
	f.scale_amount_min = .5
	f.scale_amount_max = 1.2
	var curva := Curve.new()
	curva.add_point(Vector2(0, .6))
	curva.add_point(Vector2(.15, 1))
	curva.add_point(Vector2(1, .5))
	f.scale_amount_curve = curva
	f.mesh = _malla_gota()
	raiz.add_child(f)
	f.finished.connect(f.queue_free)
	# manchas donde caen (más o menos): por delante del golpe, en abanico
	var k := clampi(n / 5, 1, 7)
	for i in k:
		var a := ang + randf_range(-spread, spread) * .6
		var dist := randf_range(.15, .35 + v * .12)
		var q := Vector3(p.x + cos(a) * dist, 0, p.z + sin(a) * dist)
		if raiz.is_inside_tree():
			raiz.get_tree().create_timer(.18 + dist * .12).timeout.connect(_mancha.bind(q, randf_range(.08, .22), Color(.32, .01, .01)))

var _gota: Mesh
func _malla_gota() -> Mesh:
	if _gota == null:
		var m := SphereMesh.new()
		m.radius = .022
		m.height = .07   # alargada: con align_y apunta hacia donde vuela
		m.radial_segments = 8
		m.rings = 4
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(.42, .015, .015)
		mat.roughness = .18
		mat.metallic_specular = .8
		m.material = mat
		_gota = m
	return _gota

var _hueso: Mesh
func _malla_hueso() -> Mesh:
	if _hueso == null:
		var m := BoxMesh.new()
		m.size = Vector3(.025, .07, .025)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(.86, .82, .7)
		mat.roughness = .7
		m.material = mat
		_hueso = m
	return _hueso

var _brasa: Mesh
func _malla_brasa() -> Mesh:
	if _brasa == null:
		var m := SphereMesh.new()
		m.radius = .025
		m.height = .05
		m.radial_segments = 6
		m.rings = 3
		m.material = _mat_brillo(Color(1, .5, .12), 1.0, 4.0)
		_brasa = m
	return _brasa

func _trozos(p: Vector3, ang: float, n: int, v: float, malla: Mesh, gravedad: float, vida: float) -> void:
	if raiz == null:
		return
	var f := CPUParticles3D.new()
	f.one_shot = true
	f.emitting = true
	f.explosiveness = .9
	f.amount = clampi(n, 2, 40)
	f.lifetime = vida
	f.position = p
	f.direction = Vector3(cos(ang), 1.0, sin(ang)).normalized()
	f.spread = 55
	f.initial_velocity_min = v * .4
	f.initial_velocity_max = v * 1.1
	f.gravity = Vector3(0, -gravedad, 0)
	f.angular_velocity_min = -400
	f.angular_velocity_max = 400
	f.scale_amount_min = .6
	f.scale_amount_max = 1.3
	var curva := Curve.new()
	curva.add_point(Vector2(0, 1))
	curva.add_point(Vector2(.7, .8))
	curva.add_point(Vector2(1, 0))
	f.scale_amount_curve = curva
	f.mesh = malla
	raiz.add_child(f)
	f.finished.connect(f.queue_free)

## manchas del suelo: una sola MultiMesh para todo el piso (miles sin coste); si se llena, se reutilizan las más viejas
const MAX_MANCHAS := 4000
var _manchas: MultiMeshInstance3D
var _n_manchas := 0

func _mancha(q: Vector3, r: float, c: Color) -> void:
	if raiz == null or not raiz.is_inside_tree():
		return
	if not is_instance_valid(_manchas):
		_manchas = MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var pm := PlaneMesh.new()
		pm.size = Vector2.ONE
		pm.material = _mat_mancha()
		mm.mesh = pm
		mm.instance_count = MAX_MANCHAS
		mm.visible_instance_count = 0
		_manchas.multimesh = mm
		_manchas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(_manchas)
	var mm := _manchas.multimesh
	var i := _n_manchas % MAX_MANCHAS
	var b := Basis(Vector3.UP, randf() * TAU).scaled(Vector3(r * 2 * randf_range(.8, 1.3), 1, r * 2))
	mm.set_instance_transform(i, Transform3D(b, Vector3(q.x, .012 + (i % 50) * .0002, q.z)))
	mm.set_instance_color(i, c.darkened(randf() * .25))
	_n_manchas += 1
	mm.visible_instance_count = mini(_n_manchas, MAX_MANCHAS)

var _mat_manchas: StandardMaterial3D
func _mat_mancha() -> StandardMaterial3D:
	if _mat_manchas == null:
		var m := StandardMaterial3D.new()
		m.albedo_texture = _tex_mancha()
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = .2
		m.metallic_specular = .7
		_mat_manchas = m
	return _mat_manchas

## salpicadura dibujada por código: un borrón con borde irregular y gotitas alrededor
func _tex_mancha() -> Texture2D:
	var N := 128
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var ruido := FastNoiseLite.new()
	ruido.seed = 7
	ruido.frequency = .09
	var gotas := []
	for k in 7:
		var a := randf() * TAU
		gotas.append([Vector2(N / 2.0, N / 2.0) + Vector2(cos(a), sin(a)) * randf_range(36, 56), randf_range(3.0, 7.0)])
	for y in N:
		for x in N:
			var v := Vector2(x - N / 2.0, y - N / 2.0)
			var borde := 30.0 + ruido.get_noise_2d(x * .5, y * .5) * 18.0
			var a := clampf((borde - v.length()) / 4.0, 0, 1)
			for g in gotas:
				a = maxf(a, clampf((g[1] - Vector2(x, y).distance_to(g[0])) / 2.0, 0, 1))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

func _mat_brillo(c: Color, alfa: float, energia: float = 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r, c.g, c.b, alfa)
	if alfa < 1:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energia
	return m

func _chispas(p: Vector3, c: Color, n: int, v: float, sangre: bool) -> void:
	if raiz == null:
		return
	var f := CPUParticles3D.new()
	f.one_shot = true
	f.emitting = true
	f.explosiveness = .95
	f.amount = clampi(n, 2, 40)
	f.lifetime = .6
	f.position = p
	f.direction = Vector3.UP
	f.spread = 70
	f.initial_velocity_min = v * .4
	f.initial_velocity_max = v * 1.2
	f.gravity = Vector3(0, -9.8, 0)
	f.scale_amount_min = .05
	f.scale_amount_max = .12
	var b := BoxMesh.new()
	b.size = Vector3.ONE
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if not sangre:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 3.0
	b.material = m
	f.mesh = b
	raiz.add_child(f)
	f.finished.connect(f.queue_free)

func _charco(p: Vector3, r: float) -> void:
	if raiz == null:
		return
	var d := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = maxf(.2, r)
	c.bottom_radius = c.top_radius
	c.height = .01
	c.radial_segments = 20
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(.22, .01, .01)
	m.roughness = .15
	c.material = m
	d.mesh = c
	d.position = p + Vector3(0, .01 + _charcos.size() * .0001, 0)
	d.scale = Vector3(1, 1, .7)
	raiz.add_child(d)
	_charcos.append(d)
	if _charcos.size() > MAX_CHARCOS:
		var v: Node3D = _charcos.pop_front()
		if is_instance_valid(v):
			v.queue_free()

static func _c(s) -> Color:
	if s is Color:
		return s
	if s is Array and s.size() > 0:
		return _c(s[0])
	return Color.from_string(String(s), Color.WHITE)

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
	_chispas(MazmorraGridMap.a3d(x, y, z), Color(.55, .02, .02), n, spd * MazmorraGridMap.PX_M, true)

func text(x: float, y: float, txt: String, col: String, size: float = 10, crit: bool = false, life: float = .8, slow: bool = false, jitter: bool = true) -> void:
	if raiz == null:
		return
	var l := Label3D.new()
	l.text = txt
	l.modulate = _c(col)
	l.outline_modulate = Color.BLACK
	l.outline_size = 10
	l.font_size = int(size * (5 if crit else 4))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = MazmorraGridMap.a3d(x + (randf() - .5) * 10 if jitter else x, y, 40)
	raiz.add_child(l)
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
	_charcos.clear()

# ---------- piezas ----------
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

extends SceneTree
## Vitrina de los efectos de golpe: sangre (gotas y manchas), esquirlas de hueso, brasas, aviso en el suelo
## y números de daño, para ajustarlos sin jugar.
## Uso: xvfb-run -a godot --path . -s res://tools/vitrina_sangre.gd -- --shot=/tmp/sangre.png [--frames=12]

var _shot := "/tmp/sangre.png"
var _frames := 5
var _n := 0
var fx := Fx3D.new()

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): _shot = a.get_slice("=", 1)
		if a.begins_with("--frames="): _frames = int(a.get_slice("=", 1))
	var raiz := Node3D.new()
	root.add_child(raiz)
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(14, 14)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(.36, .33, .3)
	m.roughness = .85
	pm.material = m
	suelo.mesh = pm
	suelo.position = Vector3(3, 0, 3)
	raiz.add_child(suelo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55, 30, 0)
	sol.light_energy = 1.2
	raiz.add_child(sol)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.0
	cam.transform = Transform3D(Basis(), Vector3(3.2 + 8, 8, 3.2 + 8)).looking_at(Vector3(3.2, 0, 3.2))
	raiz.add_child(cam)
	cam.current = true
	fx.raiz = raiz

func _process(_dt: float) -> bool:
	_n += 1
	if _n == 2:
		_efectos()
	if _n == _frames:
		root.get_texture().get_image().save_png(_shot)
		print("captura: ", _shot)
		fx.reset()
		return true
	return false

func _efectos() -> void:
	# las posiciones van en px de la simulación (32 px = 2 m)
	for k in 30:
		fx.stain(30 + randf() * 30, 40 + randf() * 14, "#7a0c0c", 1 + (k % 2))
	fx.bleed(40, 48, 16, 0.3, 46, 150)
	fx.bleed(40, 48, 14, PI + .3, 12, 50, 1.4)
	fx.esquirlas(70, 30, 16, .4, 30, 150, "hueso")
	fx.esquirlas(30, 80, 16, -.4, 30, 150, "brasas")
	fx.aviso(62, 62, 14, 3.0, "#ff3a1a")
	fx.text(40, 48, "128!", Sim.COL_CRIT, 18, true)
	fx.text(70, 30, "34", Sim.COL_GOLPE, 11)
	fx.text(30, 70, "-21", Sim.COL_RECIBIDO, 14)

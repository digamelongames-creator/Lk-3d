extends SceneTree
## Vitrina del contorno rojo (9 nov): a la izquierda sin contorno, en medio el fino (bajo el ratón)
## y a la derecha el grueso (al que estás golpeando), con un esqueleto, un humano y un demonio.
## Uso: xvfb-run -a godot --path . -s res://tools/vitrina_contorno.gd -- --shot=/tmp/c.png

var _shot := "/tmp/contorno.png"
var _n := 0
var act := Actores3D.new()
var _modelos: Array[Modelo3D] = []

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): _shot = a.get_slice("=", 1)
	var raiz := Node3D.new()
	root.add_child(raiz)
	raiz.add_child(act)
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(16, 16)
	pm.material = KitMazmorra.material("losa")
	suelo.mesh = pm
	raiz.add_child(suelo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55, 30, 0)
	sol.shadow_enabled = true
	raiz.add_child(sol)
	var amb := WorldEnvironment.new()
	amb.environment = Environment.new()
	amb.environment.background_mode = Environment.BG_COLOR
	amb.environment.background_color = Color(.05, .04, .04)
	amb.environment.ambient_light_color = Color(.6, .55, .5)
	amb.environment.ambient_light_energy = .5
	raiz.add_child(amb)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 10.0
	cam.transform = Transform3D(Basis(), Vector3(8, 7, 8)).looking_at(Vector3(0, .8, 0))
	raiz.add_child(cam)
	cam.current = true
	var fino := act._mat_contorno(Actores3D.CONTORNO_FINO)
	var grueso := act._mat_contorno(Actores3D.CONTORNO_GRUESO)
	var ids := ["esqueleto", Actores3D.MODELO_HUMANOS, "firedemon"]
	for fila in ids.size():
		for col in 3:
			var m := Modelo3D.crear(ids[fila], Color.WHITE)
			if m == null:
				continue
			m.position = Vector3(-2.6 + col * 2.6, 0, 2.6 - col * 2.6) + Vector3(-1, 0, -1) * (fila - 1) * 2.4
			m.rotation.y = PI / 4
			raiz.add_child(m)
			_modelos.append(m)
			var mat: Material = [null, fino, grueso][col]
			for mi in m.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_overlay = mat

func _process(_dt: float) -> bool:
	_n += 1
	if _n == 3:
		for m in _modelos:
			m.reproducir("walk", 1.0)
	if _n == 30:
		root.get_texture().get_image().save_png(_shot)
		print("captura: ", _shot)
		return true
	return false

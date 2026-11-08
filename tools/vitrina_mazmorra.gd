extends SceneTree
## Vitrina de la tanda 3: barril, caja y urna rompibles, trampa de pinchos y de fuego (en reposo, en aviso
## y disparadas), rejas del reto y el mímico mordiendo.
## Uso: xvfb-run -a godot --path . -s res://tools/vitrina_mazmorra.gd -- --shot=/tmp/m.png

var _shot := "/tmp/mazmorra.png"
var _n := 0
var act := Actores3D.new()
var _trampas := []

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): _shot = a.get_slice("=", 1)
	var raiz := Node3D.new()
	root.add_child(raiz)
	raiz.add_child(act)
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(16, 16)
	pm.material = KitMazmorra.material("piedra") if KitMazmorra.material("piedra") != null else StandardMaterial3D.new()
	suelo.mesh = pm
	raiz.add_child(suelo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55, 30, 0)
	sol.light_energy = 1.0
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
	cam.size = 9.0
	cam.transform = Transform3D(Basis(), Vector3(8, 7, 8)).looking_at(Vector3(0, .3, 0))
	raiz.add_child(cam)
	cam.current = true
	var x := -3.0
	for k in ["barril", "caja", "urna"]:
		var n := act._rompible(k)
		n.position = Vector3(x, 0, -3)
		act.add_child(n)
		x += 1.6
	var estados := [["pinchos", "listo"], ["pinchos", "aviso"], ["pinchos", "activa"], ["fuego", "activa"]]
	for i in estados.size():
		var n := act._trampa(estados[i][0])
		n.position = Vector3(-3 + i * 1.9, 0, 0.5)
		act.add_child(n)
		_trampas.append([n, {"kind": estados[i][0], "estado": estados[i][1]}])
	var mim := act._cofre()
	mim.position = Vector3(2.5, 0, -2.5)
	mim.get_child(1).rotation.x = -1.1
	act.add_child(mim)
	var rejas := Node3D.new()
	rejas.position = Vector3(-3, 0, 3)
	act.add_child(rejas)

func _process(_dt: float) -> bool:
	_n += 1
	act._t += .016
	for t in _trampas:
		act._animar_trampa(t[0], t[1])
	if _n == 30:
		root.get_texture().get_image().save_png(_shot)
		print("captura: ", _shot)
		return true
	return false

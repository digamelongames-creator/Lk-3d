extends SceneTree
var f := 0
func _initialize() -> void:
	root.size = Vector2i(1000, 1000)
	var w := Node3D.new(); root.add_child(w)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(.1,.1,.12)
	env.environment.ambient_light_color = Color.WHITE; env.environment.ambient_light_energy = .8
	w.add_child(env)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-30, 60, 0); w.add_child(l)
	var m := Modelo3D.crear("esqueleto"); w.add_child(m)
	for a in m.find_children("arma_*", "MeshInstance3D", true, false): a.visible = false
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var fm := StandardMaterial3D.new(); fm.albedo_color = Color(1,1,1,.3); fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = fm
	var rng := RandomNumberGenerator.new()
	var eq := {}
	for s in Armadura3D.huecos(): eq[s] = Items.make_gear(rng, 0, "knight", s)
	Armadura3D.vestir(m, eq)
	m.enganche("RightHand").add_child(Armadura3D.arma(Items.make_gear(rng, 0, "knight", "sword"), "RightHand"))
	m.enganche("LeftHand").add_child(Armadura3D.arma(Items.make_gear(rng, 0, "knight", "shield"), "LeftHand"))
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 2.0
	var arg := OS.get_cmdline_user_args()
	if arg.has("--frente"): cam.position = Vector3(0, 1, -3); cam.rotation_degrees.y = 180
	else: cam.position = Vector3(3, 1, 0); cam.rotation_degrees.y = 90   # de lado: delante (−z) = derecha de la imagen
	w.add_child(cam); cam.current = true
func _process(_d: float) -> bool:
	f += 1
	if f == 30:
		root.get_texture().get_image().save_png("/tmp/_crudo.png")
		return true
	return false

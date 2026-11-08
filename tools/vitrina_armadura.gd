extends SceneTree
## Vitrina de la armadura: el héroe con las piezas de cada calidad (básico, mágico, dorado, legendario),
## de frente y de lado, y la fila de piezas sueltas del suelo. Para ajustar Armadura3D.AJUSTE.
## Uso: xvfb-run -a godot --path . -s res://tools/vitrina_armadura.gd -- --shot=/tmp/vitrina.png [--anim=walk] [--cerca=0..3] [--fantasma]

var _shot := "/tmp/vitrina.png"
var _anim := "idle"
var _f := 0
var _cx := 0.0
var _dist := 8.5
var _fantasma := false

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): _shot = a.get_slice("=", 1)
		elif a.begins_with("--anim="): _anim = a.get_slice("=", 1)
		elif a == "--fantasma": _fantasma = true   # el cuerpo semitransparente, para ver dónde cae cada pieza
		elif a.begins_with("--cerca="):   # --cerca=0..3: acerca la cámara a esa calidad
			_cx = -4.7 + int(a.get_slice("=", 1)) * 3.0
			_dist = 2.6
	root.size = Vector2i(1600, 900)
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.08, .07, .07)
	env.environment.ambient_light_color = Color(.5, .5, .55)
	env.environment.ambient_light_energy = .6
	env.environment.glow_enabled = true
	w.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40, 30, 0)
	sol.light_energy = 1.3
	w.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 10)
	suelo.mesh = pm
	w.add_child(suelo)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for q in 4:
		var eq := {}
		for s in Armadura3D.huecos():
			eq[s] = Items.make_gear(rng, q, "knight", s)
		for lado in 2:
			var m := Modelo3D.crear("esqueleto")
			m.position = Vector3(-5.25 + q * 3.0 + lado * 1.1, 0, 0)
			m.rotation_degrees.y = 180 if lado == 0 else 90
			w.add_child(m)
			m.reproducir(_anim)
			if _fantasma:
				for mi in m.find_children("*", "MeshInstance3D", true, false):
					if true:
						var fm := StandardMaterial3D.new()
						fm.albedo_color = Color(1, 1, 1, .25)
						fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						mi.material_override = fm
			Armadura3D.vestir(m, eq)
			for par in [["sword", "RightHand"], ["shield", "LeftHand"]]:
				var a := Armadura3D.arma(Items.make_gear(rng, q, "knight", par[0]), par[1])
				if a != null:
					m.enganche(par[1]).add_child(a)
			for a in m.find_children("arma_*", "MeshInstance3D", true, false):
				a.visible = false

		var i := 0
		for s in Armadura3D.huecos() + ["sword", "shield"]:
			var n := Armadura3D.suelta(Items.make_gear(rng, q, "knight", s))
			n.position = Vector3(-5.8 + q * 3.0 + i * .42, .0, 2.2)
			w.add_child(n)
			i += 1
	var cam := Camera3D.new()
	cam.position = Vector3(_cx, 1.3, _dist)
	cam.rotation_degrees.x = -4
	cam.fov = 55
	w.add_child(cam)
	cam.current = true

func _process(_dt: float) -> bool:
	_f += 1
	if _f == 40:
		root.get_texture().get_image().save_png(_shot)
		print("captura: ", _shot)
		Armadura3D.limpiar()
		Modelo3D.limpiar()
		return true
	return false

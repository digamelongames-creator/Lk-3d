extends Node3D
## Sala de prueba: la «Sala de combate» del concept montada a mano con el kit de Blender,
## para ajustar cámara, escala, materiales y luz antes de tocar el generador.
## Usa la misma MazmorraGridMap que el juego (se le pasa un piso escrito a mano).
##
## godot --path . res://scenes/sala_prueba.tscn -- [--shot=/tmp/sala.png,60] [--giro=45] [--inclinacion=33] [--perspectiva]

## # roca · . suelo · D arco (puerta)
const PLANO := [
	"############",
	"###.####.###",
	"###D####D###",
	"##........##",
	"##........##",
	".D........##",
	"##........##",
	"##........D.",
	"##........##",
	"##........##",
	"############",
]

var mazmorra: MazmorraGridMap
var camara: CamaraIso
var heroe: Node3D
var _shot := ""
var _shot_frames := 60
var _frame := 0
var _t := 0.0
var _centro := Vector3(11.5, 0, 12.5)
var _heroe_id := ""   # --heroe=esqueleto: el héroe con modelo y la espada en la mano
var _anim := "idle"   # animación de los monstruos de la galería (--anim=walk…)

func _ready() -> void:
	CamaraIso.ambiente(self)
	mazmorra = MazmorraGridMap.new()
	add_child(mazmorra)
	camara = CamaraIso.new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--giro="): camara.giro = deg_to_rad(float(a.get_slice("=", 1)))
		elif a.begins_with("--inclinacion="): camara.inclinacion = deg_to_rad(float(a.get_slice("=", 1)))
		elif a.begins_with("--zoom="): camara.zoom = float(a.get_slice("=", 1))
		elif a == "--perspectiva": camara.ortografica = false
		elif a.begins_with("--anim="): _anim = a.get_slice("=", 1)
		elif a.begins_with("--heroe="): _heroe_id = a.get_slice("=", 1)
		elif a.begins_with("--centro="):
			var c := a.get_slice("=", 1).split(",")
			_centro = Vector3(float(c[0]), 0, float(c[1]))
		elif a.begins_with("--shot="):
			var p := a.get_slice("=", 1).split(",")
			_shot = p[0]
			_shot_frames = int(p[1]) if p.size() > 1 else 60
	add_child(camara)
	mazmorra.construir(_piso())
	_amueblar()
	heroe = _heroe()
	heroe.position = Vector3(12.5, 0, 14.5)
	add_child(heroe)
	_galeria()
	camara.seguir(_centro, 1.0, false)

## los monstruos de SPRITE_FACTORY en fila, cada uno con la animación pedida
func _galeria() -> void:
	var ids := Modelo3D.FICHAS.keys()
	for i in ids.size():
		var m := Modelo3D.crear(ids[i])
		if m == null:
			continue
		m.position = Vector3(6.5 + i * 2.0, 0, 9.5 + (i % 2) * 1.2)
		m.rotation.y = deg_to_rad(-135)   # mirando a la cámara
		add_child(m)
		m.reproducir(_anim)
		if m.anim != null:
			m.anim.seek(fmod(i * .37, m.duracion(_anim)), true)

## el plano escrito arriba, como un piso de DungeonGen (rejilla del tamaño del mapa, todo roca alrededor)
func _piso() -> Dictionary:
	var W := DungeonGen.GW
	var grid := PackedByteArray()
	grid.resize(W * DungeonGen.GH)
	grid.fill(DungeonGen.ROCK)
	var sala := PackedInt32Array()
	sala.resize(W * DungeonGen.GH)
	sala.fill(-1)
	for y in PLANO.size():
		for x in PLANO[y].length():
			var c: String = PLANO[y][x]
			var i: int = y * W + x
			grid[i] = DungeonGen.FLOOR if c == "." else DungeonGen.DOOR if c == "D" else DungeonGen.ROCK
			if c == "." and x >= 2 and x <= 9 and y >= 3 and y <= 9:
				sala[i] = 0
	return {"grid": grid, "room_of": sala, "torches": [], "deco": {}}

func _amueblar() -> void:
	var M := mazmorra
	var N := Vector2i(0, -1)
	var O := Vector2i(-1, 0)
	# antorchas en la pared del fondo (norte) y la izquierda (oeste), a los lados de los arcos
	M.poner_antorcha(Vector2i(2, 3), N, .4)
	M.poner_antorcha(Vector2i(4, 3), N, -.5)
	M.poner_antorcha(Vector2i(7, 3), N, .5)
	M.poner_antorcha(Vector2i(9, 3), N, -.4)
	M.poner_antorcha(Vector2i(2, 4), O, .2)
	M.poner_antorcha(Vector2i(2, 7), O)
	# estandartes entre los arcos y en la pared oeste
	M.poner_en_pared("estandarte", Vector2i(5, 3), N, 2.15, .3)
	M.poner_en_pared("estandarte", Vector2i(6, 3), N, 2.15, -.3)
	M.poner_en_pared("estandarte", Vector2i(2, 9), O, 2.15)
	# braseros alrededor del círculo
	for c in [Vector2(9.0, 10.5), Vector2(15.0, 10.5), Vector2(9.0, 16.0), Vector2(15.0, 16.0)]:
		M.poner_en_suelo("brasero", Vector3(c.x, 0, c.y))
	# barriles y cajas en las esquinas
	M.poner_en_suelo("barril", Vector3(18.9, 0, 7.0), .3)
	M.poner_en_suelo("barril", Vector3(19.0, 0, 7.9), 1.2)
	M.poner_en_suelo("caja", Vector3(18.2, 0, 7.2), .2)
	M.poner_en_suelo("caja", Vector3(4.9, 0, 18.9), -.3)
	M.poner_en_suelo("barril", Vector3(5.7, 0, 19.1), .8)
	M.poner_en_suelo("caja", Vector3(19.0, 0, 15.3), .5)
	_circulo(Vector3(12, 0, 13.2), 2.6)
	_alfombra(Vector3(6.2, 0, 12.5), Vector2(1.6, 4.2))
	_rejilla(Vector3(17.0, 0, 18.5))
	for s in [[Vector3(10.5, 0, 14.6), .9], [Vector3(14.6, 0, 12.0), .6], [Vector3(7.5, 0, 17.3), .7], [Vector3(16.5, 0, 8.4), .5]]:
		_sangre(s[0], s[1])

# ---------- piezas provisionales de la sala (hasta tener sus modelos) ----------
func _heroe() -> Node3D:
	var mod := Modelo3D.crear(_heroe_id) if _heroe_id != "" else null
	if mod != null:
		var raiz := Node3D.new()
		raiz.add_child(mod)
		mod.rotation.y = deg_to_rad(-135)
		mod.reproducir(_anim)
		var ag := Modelo3D.agarre()
		if not ag.is_empty():
			var e := MeshInstance3D.new()
			e.mesh = ag.mesh
			e.transform = ag.t
			mod.enganche("RightHand").add_child(e)
		return raiz
	var n := Node3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(.55, .58, .65)
	m.metallic = .6
	m.roughness = .4
	var c := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = .33
	cm.height = 1.75
	cm.material = m
	c.mesh = cm
	c.position.y = .88
	n.add_child(c)
	var hoja := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(.07, .07, 1.0)
	b.material = m
	hoja.mesh = b
	hoja.position = Vector3(.42, 1.0, -.4)
	hoja.rotation.x = -.5
	n.add_child(hoja)
	var luz := OmniLight3D.new()
	luz.position = Vector3(0, 3, .5)
	luz.light_color = Color(1, .85, .7)
	luz.light_energy = .8
	luz.omni_range = 7
	n.add_child(luz)
	return n

## círculo grabado en el suelo: anillos y una estrella de 8 puntas pintados en una textura
func _circulo(pos: Vector3, r: float) -> void:
	var S := 512
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var c := S / 2.0
	for y in S:
		for x in S:
			var dx := (x - c) / c
			var dy := (y - c) / c
			var d := sqrt(dx * dx + dy * dy)
			var a := 0.0
			for rr in [.97, .9, .62, .56, .2]:
				a = maxf(a, 1.0 - smoothstep(.006, .016, absf(d - rr)))
			var ang := atan2(dy, dx)
			var k := fposmod(ang, PI / 4) - PI / 8
			var punta := 1.0 - d / .9
			if d < .9 and absf(k) * d < .05 * punta + .004:
				a = maxf(a, .85)
			if a > 0:
				img.set_pixel(x, y, Color(.12, .07, .05, a * .9))
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(r * 2, r * 2)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = .6
	q.material = m
	mi.mesh = q
	mi.position = pos + Vector3(0, .012, 0)
	add_child(mi)

func _alfombra(pos: Vector3, t: Vector2) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(t.x, .02, t.y)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(.22, .03, .03)
	m.roughness = 1
	b.material = m
	mi.mesh = b
	mi.position = pos + Vector3(0, .015, 0)
	add_child(mi)
	var borde := MeshInstance3D.new()
	var b2 := BoxMesh.new()
	b2.size = Vector3(t.x - .2, .021, t.y - .2)
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(.3, .05, .04)
	b2.material = m2
	borde.mesh = b2
	borde.position = pos + Vector3(0, .017, 0)
	add_child(borde)

func _rejilla(pos: Vector3) -> void:
	var hierro := KitMazmorra.material("hierro")
	var fondo := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(1.1, .02, 1.1)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	b.material = m
	fondo.mesh = b
	fondo.position = pos + Vector3(0, .005, 0)
	add_child(fondo)
	for i in 6:
		for eje in 2:
			var barra := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(1.1, .04, .05) if eje == 0 else Vector3(.05, .04, 1.1)
			bb.material = hierro
			barra.mesh = bb
			var o := (i - 2.5) * .19
			barra.position = pos + Vector3(0 if eje == 0 else o, .03, o if eje == 0 else 0)
			add_child(barra)

func _sangre(pos: Vector3, r: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(.2, .01, .01)
	m.roughness = .2
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pos)
	for k in 5:
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		var rr := r * rng.randf_range(.3, .7)
		c.top_radius = rr
		c.bottom_radius = rr
		c.height = .01
		c.material = m
		mi.mesh = c
		mi.position = pos + Vector3(rng.randf_range(-r, r) * .6, .013 + k * .0005, rng.randf_range(-r, r) * .5)
		mi.scale = Vector3(1, 1, rng.randf_range(.4, .9))
		mi.rotation.y = rng.randf() * TAU
		add_child(mi)

func _process(dt: float) -> void:
	_frame += 1
	_t += dt
	RenderingServer.global_shader_parameter_set("pos_heroe", heroe.position)
	if _shot != "" and _frame == _shot_frames:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot)
		print("captura: ", _shot)
		get_tree().quit()

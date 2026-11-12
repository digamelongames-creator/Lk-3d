class_name Abismo3D
## El abismo de los pisos de pasarelas (3 a 5): paredes de roca bajo cada borde que bajan hasta perderse
## y capas de niebla con un brillo tenue. La niebla de altura del entorno (CamaraIso.ambiente) oscurece todo
## lo que queda por debajo del suelo, así que la roca se funde con la niebla según baja.
## Todo se crea por piso (sin recursos estáticos) y cuelga del nodo que se le pase.
## Con un tema con lava (TemaMazmorra, el Inframundo): la roca es la del tema, abajo hay un mar de lava
## que corre, cascadas de lava que salen de algunos bordes, luces naranjas bajo los bordes y brasas.
## Con un tema con agua (Galerías hundidas): roca del tema, niebla azul espesa, cascadas de agua que se
## pierden en ella, luces azules bajo los bordes y rocío que sube.

const MAX_LUCES_LAVA := 40
const MAX_CASCADAS := 14

const HONDO := 14.0      # m que baja la pared de roca
const NIEBLA_Y := [-2.2, -4.5, -7.5]   # capas de niebla que brillan un poco
## profundidad de cada fila de vértices de la pared (más juntas arriba, donde se ve mejor)
const FILAS := [0.0, .35, .9, 1.6, 2.5, 3.6, 5.0, 6.8, 9.0, 11.5, HONDO]
const COLUMNAS := 6      # vértices por casilla a lo ancho (cada 0,33 m)
const RELIEVE := .7      # m que sale o entra la roca

static func crear(G: PackedByteArray, padre: Node3D, tema: String = "") -> void:
	var tipo := TemaMazmorra.abismo(tema) if tema != "" else ""   # "lava", "agua" o "" (niebla gris)
	var lava := tipo == "lava"
	var con_tema := tipo != ""
	var lava_y: float = TemaMazmorra.dato(tema, "lava_y", -5.5) if lava else 0.0
	# las cascadas caen hasta la lava o, con agua, hasta perderse en la niebla
	var caida: float = (-lava_y + .5) if lava else HONDO
	var cae := SurfaceTool.new()
	cae.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_cae := 0
	var bordes := []   # [punto del borde, hacia el vacío] para las luces de abajo
	var W := DungeonGen.GW
	var H := DungeonGen.GH
	var ruido := FastNoiseLite.new()
	ruido.seed = 7
	ruido.frequency = .6
	ruido.fractal_octaves = 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var C := KitMazmorra.CELDA
	var hay := false
	for cy in H:
		for cx in W:
			if G[cy * W + cx] != DungeonGen.ABISMO:
				continue
			for d in MazmorraGridMap.DIRS:
				var nx: int = cx + d.x
				var ny: int = cy + d.y
				if nx < 0 or ny < 0 or nx >= W or ny >= H:
					continue
				if not _con_cuerpo(G, nx, ny):
					continue
				# borde común entre el vacío (cx, cy) y la casilla con suelo o muro (nx, ny); la cara mira al vacío
				var centro := Vector3((cx + .5) * C, 0, (cy + .5) * C)
				var mitad := Vector3(d.x, 0, d.y) * C * .5
				var a := centro + mitad + Vector3(-d.y, 0, d.x) * C * .5
				var b := centro + mitad - Vector3(-d.y, 0, d.x) * C * .5
				_pared(st, ruido, a, b)
				hay = true
				if con_tema:
					var fuera := Vector3(-d.x, 0, -d.y)
					bordes.append([centro + mitad, fuera])
					# cascada en algunos bordes (fijo por casilla, para que no cambie al volver)
					if n_cae < MAX_CASCADAS and absi(hash(Vector3i(cx, cy, d.x * 3 + d.y))) % 11 == 0:
						_cascada(cae, ruido, a, b, fuera, caida)
						n_cae += 1
	if not hay:
		return
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "ParedesAbismo"
	mi.mesh = st.commit()
	mi.material_override = TemaMazmorra.material_roca(tema) if con_tema else _roca()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	if not con_tema:
		_niebla(padre, W * C, H * C)
		return
	if lava:
		_lava(padre, W * C, H * C, lava_y, tema)
	else:
		# agua: niebla del color del tema, más espesa, y un fondo que se funde con ella
		_niebla(padre, W * C, H * C, TemaMazmorra.dato(tema, "niebla_abismo", Color(.3, .6, .7)), .16, Color(.02, .07, .1))
	if n_cae > 0:
		var mc := MeshInstance3D.new()
		mc.name = "CascadasLava" if lava else "CascadasAgua"
		mc.mesh = cae.commit()
		mc.material_override = TemaMazmorra.material_liquido(tema, true)
		mc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		padre.add_child(mc)
	# luces bajo los bordes: la lava (o el brillo azul del abismo) alumbra la roca desde abajo
	# (repartidas, como mucho MAX_LUCES_LAVA; con agua, la mitad)
	var maximo := MAX_LUCES_LAVA if lava else MAX_LUCES_LAVA / 2
	var paso := maxi(1, ceili(bordes.size() / float(maximo)))
	var hondo_luz: float = lava_y * .55 if lava else -3.5
	for i in range(0, bordes.size(), paso):
		var l := OmniLight3D.new()
		l.position = bordes[i][0] + bordes[i][1] * 1.6 + Vector3(0, hondo_luz, 0)
		l.light_color = TemaMazmorra.dato(tema, "luz_abismo", Color(1, .38, .1))
		l.light_energy = float(TemaMazmorra.dato(tema, "luz_abismo_e", 2.4))
		l.omni_range = 8.5
		l.omni_attenuation = 1.2
		l.light_volumetric_fog_energy = .4
		padre.add_child(l)

## casilla que tiene algo encima (suelo, agua, puerta… o muro que se dibuja)
static func _con_cuerpo(G: PackedByteArray, x: int, y: int) -> bool:
	var t := G[y * DungeonGen.GW + x]
	if t == DungeonGen.ABISMO:
		return false
	if t != DungeonGen.ROCK:
		return true
	for j in [-1, 0, 1]:
		for i in [-1, 0, 1]:
			var u: int = x + i
			var v: int = y + j
			if u < 0 or v < 0 or u >= DungeonGen.GW or v >= DungeonGen.GH:
				continue
			var tt := G[v * DungeonGen.GW + u]
			if tt != DungeonGen.ROCK and tt != DungeonGen.ABISMO:
				return true
	return false

## una tira de roca de a a b (en el borde, y = 0) hasta HONDO; los vértices se desplazan según su posición
## en el mundo, así que las tiras vecinas comparten bordes sin rendijas
static func _pared(st: SurfaceTool, ruido: FastNoiseLite, a: Vector3, b: Vector3) -> void:
	var rejilla := []
	for f in FILAS.size():
		var fila := []
		var y: float = -FILAS[f]
		for c in COLUMNAS + 1:
			var p := a.lerp(b, float(c) / COLUMNAS) + Vector3(0, y, 0)
			# arriba queda pegada al borde del suelo; más abajo, la roca sale y entra
			var k := clampf(-y / 1.2, 0, 1)
			var off := Vector3(ruido.get_noise_3dv(p), ruido.get_noise_3dv(p + Vector3(31, 7, 13)) * .6, ruido.get_noise_3dv(p + Vector3(-17, 3, 41)))
			p += off * RELIEVE * k * 2.0
			p.y = minf(p.y, -.02 if f > 0 else 0.0)
			fila.append(p)
		rejilla.append(fila)
	for f in FILAS.size() - 1:
		# más oscura según baja (además de la niebla)
		var c1 := Color.WHITE.lerp(Color(.3, .3, .32), clampf(FILAS[f] / 8.0, 0, 1))
		var c2 := Color.WHITE.lerp(Color(.3, .3, .32), clampf(FILAS[f + 1] / 8.0, 0, 1))
		for c in COLUMNAS:
			var p00: Vector3 = rejilla[f][c]
			var p01: Vector3 = rejilla[f][c + 1]
			var p10: Vector3 = rejilla[f + 1][c]
			var p11: Vector3 = rejilla[f + 1][c + 1]
			# orden de giro con la cara hacia el vacío (Godot: horario visto de frente)
			_tri(st, p00, p10, p01, c1, c2, c1)
			_tri(st, p01, p10, p11, c1, c2, c2)

static func _tri(st: SurfaceTool, p1: Vector3, p2: Vector3, p3: Vector3, c1: Color, c2: Color, c3: Color) -> void:
	st.set_color(c1); st.add_vertex(p1)
	st.set_color(c2); st.add_vertex(p2)
	st.set_color(c3); st.add_vertex(p3)

## roca sin licencias de fuera: ruido de Godot como color y como relieve, proyectado desde los tres ejes
static func _roca() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	var n := FastNoiseLite.new()
	n.seed = 21
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = .025
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 4
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0, .45, 1])
	g.colors = PackedColorArray([Color(.13, .12, .11), Color(.3, .28, .25), Color(.46, .43, .39)])
	var col := NoiseTexture2D.new()
	col.width = 512
	col.height = 512
	col.seamless = true
	col.noise = n
	col.color_ramp = g
	m.albedo_texture = col
	var nor := NoiseTexture2D.new()
	nor.width = 512
	nor.height = 512
	nor.seamless = true
	nor.noise = n
	nor.as_normal_map = true
	nor.bump_strength = 10.0
	m.normal_enabled = true
	m.normal_texture = nor
	m.normal_scale = 1.2
	m.roughness = .95
	# abajo no llega la luz de las antorchas: un poco de luz propia (la del brillo de la niebla) deja ver la roca
	m.emission_enabled = true
	m.emission = Color(.42, .45, .55)
	m.emission_texture = col
	m.emission_energy_multiplier = .18
	m.rim_enabled = true
	m.rim = .25
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(.4, .4, .4)
	return m

## cascada de lava: una tira pegada a la pared de roca (mismo relieve, un poco hacia fuera), del borde a la lava
static func _cascada(st: SurfaceTool, ruido: FastNoiseLite, a: Vector3, b: Vector3, fuera: Vector3, hondo: float) -> void:
	var filas := 8
	var cols := 4
	var rej := []
	for f in filas + 1:
		var fila := []
		var y := -hondo * float(f) / filas
		for c in cols + 1:
			var u := .15 + .7 * float(c) / cols   # el medio del borde
			var p := a.lerp(b, u) + Vector3(0, y, 0)
			var k := clampf(-y / 1.2, 0, 1)
			var off := Vector3(ruido.get_noise_3dv(p), ruido.get_noise_3dv(p + Vector3(31, 7, 13)) * .6, ruido.get_noise_3dv(p + Vector3(-17, 3, 41)))
			p += off * RELIEVE * k * 2.0
			p.y = y
			p += fuera * (.12 + .25 * k)
			fila.append([p, Vector2(float(c) / cols, float(f) / filas)])
		rej.append(fila)
	for f in filas:
		for c in cols:
			var q := [rej[f][c], rej[f][c + 1], rej[f + 1][c], rej[f + 1][c + 1]]
			for t in [[0, 2, 1], [1, 2, 3]]:
				for v in t:
					st.set_uv(q[v][1])
					st.add_vertex(q[v][0])

## el mar de lava (no le afecta la niebla) y una capa de calima naranja por encima
static func _lava(padre: Node3D, ancho: float, largo: float, y: float, tema: String) -> void:
	var centro := Vector3(ancho / 2, y, largo / 2)
	var pl := PlaneMesh.new()
	pl.size = Vector2(ancho + 80, largo + 80)
	var mi := MeshInstance3D.new()
	mi.name = "MarDeLava"
	mi.mesh = pl
	mi.material_override = TemaMazmorra.material_lava(tema)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = centro
	padre.add_child(mi)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D ruido : repeat_enable, filter_linear;
varying vec3 mundo;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = mundo.xz * .03;
	float n = texture(ruido, uv + TIME * vec2(.006, .003)).r * texture(ruido, uv * 1.6 - TIME * vec2(.004, .007)).r;
	ALBEDO = vec3(1.0, .32, .08) * clamp(n * 2.0 - .1, 0.0, 1.0) * .35;
}
"""
	var n := FastNoiseLite.new()
	n.seed = 9
	n.frequency = .012
	n.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = n
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("ruido", tex)
	var calima := MeshInstance3D.new()
	calima.name = "Calima"
	var pc := PlaneMesh.new()
	pc.size = pl.size
	calima.mesh = pc
	calima.material_override = mat
	calima.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	calima.position = centro + Vector3(0, 1.4, 0)
	padre.add_child(calima)

## partículas que suben alrededor de la cámara (MazmorraGridMap las mueve con ella): brasas sobre la lava
## y, con agua, gotas de rocío frías que suben despacio desde la niebla
static func brasas(padre: Node3D, tema: String = "") -> Node3D:
	var agua := TemaMazmorra.abismo(tema) == "agua"
	var f := CPUParticles3D.new()
	f.name = "Rocio" if agua else "Brasas"
	f.amount = 90 if agua else 140
	f.lifetime = 7.0 if agua else 5.0
	f.preprocess = f.lifetime
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	f.emission_box_extents = Vector3(16, 2.5, 16)
	f.position = Vector3(0, -2.5, 0)
	f.direction = Vector3.UP
	f.spread = 25
	f.initial_velocity_min = .2 if agua else .4
	f.initial_velocity_max = .6 if agua else 1.3
	f.gravity = Vector3(.1, .12, .05) if agua else Vector3(.15, .25, .05)
	var q := QuadMesh.new()
	q.size = Vector2(.05, .05) if agua else Vector2(.06, .06)   # pequeñas y redondas
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.2, 1.7, 2.0) if agua else Color(2.2, 1.2, .6)   # algo de resplandor
	m.albedo_texture = MazmorraGridMap._punto()
	q.material = m
	f.mesh = q
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0, .15, .7, 1])
	if agua:
		g.colors = PackedColorArray([Color(.5, .85, 1, 0), Color(.6, .9, 1, .8), Color(.4, .75, 1, .5), Color(.2, .5, .7, 0)])
	else:
		g.colors = PackedColorArray([Color(1, .6, .2, 0), Color(1, .55, .15, 1), Color(1, .3, .05, .7), Color(.5, .1, .02, 0)])
	f.color_ramp = g
	var raiz := Node3D.new()
	raiz.name = "RocioRaiz" if agua else "BrasasRaiz"
	raiz.add_child(f)
	padre.add_child(raiz)
	return raiz

## capas de niebla que se mueven despacio y brillan un poco; debajo, un fondo del color de la niebla
static func _niebla(padre: Node3D, ancho: float, largo: float, color := Color(.2, .22, .28), fuerza := .1, fondo_c := Color(.05, .05, .06)) -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D ruido : repeat_enable, filter_linear;
uniform vec3 color : source_color = vec3(.2, .22, .28);
uniform float fuerza = .3;
uniform vec2 deriva = vec2(.004, .002);
varying vec3 mundo;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = mundo.xz * .025;
	float n = texture(ruido, uv + TIME * deriva).r * texture(ruido, uv * 1.7 - TIME * deriva * 1.3).r;
	ALBEDO = color;
	ALPHA = clamp(n * 2.2 - .15, 0.0, 1.0) * fuerza;
}
"""
	var n := FastNoiseLite.new()
	n.seed = 5
	n.frequency = .012
	n.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = n
	var centro := Vector3(ancho / 2, 0, largo / 2)
	for i in NIEBLA_Y.size():
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("ruido", tex)
		mat.set_shader_parameter("color", color)
		mat.set_shader_parameter("fuerza", fuerza + i * .05)
		mat.set_shader_parameter("deriva", Vector2(.004, .002).rotated(i * 2.1))
		var pl := PlaneMesh.new()
		pl.size = Vector2(ancho + 40, largo + 40)
		var mi := MeshInstance3D.new()
		mi.name = "Niebla%d" % i
		mi.mesh = pl
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = centro + Vector3(0, NIEBLA_Y[i], 0)
		padre.add_child(mi)
	# fondo: la niebla de altura lo deja del todo del color de la niebla
	var fondo := MeshInstance3D.new()
	fondo.name = "FondoAbismo"
	var pf := PlaneMesh.new()
	pf.size = Vector2(ancho + 80, largo + 80)
	fondo.mesh = pf
	var mf := StandardMaterial3D.new()
	mf.albedo_color = fondo_c
	fondo.material_override = mf
	fondo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fondo.position = centro + Vector3(0, -HONDO, 0)
	padre.add_child(fondo)

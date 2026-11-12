class_name Escena3D
## Escenas hechas a mano desde un archivo de datos (assets/escenas/<nombre>.json): la forma de montar salas especiales,
## salas de jefe y escenas de vitrina a partir de una imagen de referencia. El procedimiento está en docs/ESCENAS.md.
##
## El archivo dice qué se pisa (rejilla), dónde está la cámara, el entorno y la lista de objetos:
##   {"pieza": "paquete/pieza", "pos": [x,y,z], "giro": grados, "escala": n | [x,y,z]}   pieza del catálogo (Props3D)
##   {"bloque": [ancho,alto,fondo], "pos": …, "giro": …, "nombre": "…"}                  caja gris (pieza aún sin hacer)
##   {"caja": [x,y,z], "pos": …, "material": "suelo_tema|roca_tema|muro_tema", "metros": 6.5}   suelo, roca o sillería del tema
##   {"lava": [ancho, fondo], "pos": …, "fuerza": 2.4}                                      plano de lava que corre
##   {"cascada": [ancho, alto], "pos": …, "giro": …}                                        cascada de lava o agua (pos = arriba)
## rejilla: {"inicio": [cx, cy], "suelo": [[x0, y0, x1, y1], …], "abismo": [[…], …]} (casillas de 2 m; el abismo hace caer)
##   {"luz": {"color": [r,g,b], "energia": e, "rango": r, "parpadea": false}, "pos": …}
##   {"fuego": tamaño, "pos": …}                                                            llamas (sin luz)
##   {"disco": radio, "pos": …, "color": [r,g,b], "fuerza": f}                               disco que brilla (agua de un cuenco…)
##   {"sol": {"color": [r,g,b], "energia": e, "sombras": true}, "giro": [x, y]}             luz direccional
##   {"cadena": {"a": [..], "b": [..], "caida": m}}  ·  {"jaula": {"arriba": [..], "largo": m, "escala": s}}
##
## Modos (para saber qué cambió entre una captura y otra; --modo=…):
##   geometria: todo como cajas grises con luz neutra (validar tamaños, silueta, cámara y por dónde se anda)
##   materiales: piezas y materiales definitivos con luz neutra fija (sin niebla, ni luces, ni partículas)
##   final: todo, con la luz y el entorno de la escena

const RUTA := "res://assets/escenas/"
const MODOS := ["geometria", "materiales", "final"]

static var _cache := {}
static var _antes := {}

# ======================================================================
#  catálogo de escenas
# ======================================================================
static func todas() -> Array:
	var out := []
	var d := DirAccess.open(RUTA)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".json"):
			out.append(f.get_basename())
	out.sort()
	return out

static func datos(nombre: String) -> Dictionary:
	if not _cache.has(nombre):
		var txt := FileAccess.get_file_as_string(RUTA + nombre + ".json")
		var j = JSON.parse_string(txt)
		_cache[nombre] = j if j is Dictionary else {}
	return _cache[nombre]

## nombre de la escena que va con un número de piso de prueba (el «numero» del archivo)
static func de_numero(n: int) -> String:
	for e in todas():
		if int(datos(e).get("numero", -1)) == n:
			return e
	return ""

static func numeros() -> Array:
	var out := []
	for e in todas():
		if datos(e).has("numero"):
			out.append(int(datos(e).numero))
	return out

static func limpiar() -> void:
	_cache.clear()
	_catalogo.clear()

## fichas de las piezas (assets/props/catalogo.json): tipo, medidas, dónde puede ir, rango de visibilidad…
static var _catalogo := {}
static func catalogo() -> Dictionary:
	if _catalogo.is_empty():
		var j = JSON.parse_string(FileAccess.get_file_as_string("res://assets/props/catalogo.json"))
		_catalogo = j if j is Dictionary else {}
	return _catalogo

static func _v(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a is Array and a.size() >= 3 else Vector3.ZERO

static func _c(a, si_no: Color = Color.WHITE) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2])) if a is Array and a.size() >= 3 else si_no

# ======================================================================
#  mapa para la simulación: los rectángulos de «rejilla.suelo» se pisan, lo demás no
# ======================================================================
static func generar(nombre: String, n: int) -> Dictionary:
	var E := datos(nombre)
	var R: Dictionary = E.get("rejilla", {})
	var L := DungeonGen.gen_level("escena-" + nombre, 1)
	var W := DungeonGen.GW
	var H := DungeonGen.GH
	var G := PackedByteArray()
	G.resize(W * H)
	G.fill(DungeonGen.ROCK)
	var room_of := PackedInt32Array()
	room_of.resize(W * H)
	room_of.fill(-1)
	var corr := PackedByteArray()
	corr.resize(W * H)
	var mano := PackedByteArray()
	mano.resize(W * H)
	mano.fill(MazmorraGridMap.A_MANO_MURO | MazmorraGridMap.A_MANO_SUELO | MazmorraGridMap.A_MANO_OBJETO)
	var x0 := W
	var y0 := H
	var x1 := 0
	var y1 := 0
	for r in R.get("suelo", []):
		for cy in range(int(r[1]), int(r[3]) + 1):
			for cx in range(int(r[0]), int(r[2]) + 1):
				G[cy * W + cx] = DungeonGen.FLOOR
				room_of[cy * W + cx] = 0
		x0 = mini(x0, int(r[0])); y0 = mini(y0, int(r[1])); x1 = maxi(x1, int(r[2])); y1 = maxi(y1, int(r[3]))
	# vacío (si lo pisas, te caes, como en los pisos de pasarelas): Abismo3D pone la roca bajo los bordes y la niebla
	var hay_abismo := false
	for r in R.get("abismo", []):
		for cy in range(int(r[1]), int(r[3]) + 1):
			for cx in range(int(r[0]), int(r[2]) + 1):
				if G[cy * W + cx] == DungeonGen.ROCK:
					G[cy * W + cx] = DungeonGen.ABISMO
					hay_abismo = true
	var ini: Array = R.get("inicio", [x0, y0])
	var inicio := {"cx": int(ini[0]), "cy": int(ini[1])}
	for clave in ["plataformas", "tramos", "escaleras", "esc_mask", "alt", "pozos", "p5_obj", "_esc_idx", "torches_px", "keyrings", "estilo"]:
		L.erase(clave)
	L.merge({"grid": G, "room_of": room_of, "corr": corr, "a_mano": mano,
		"rooms": [{"x": x0, "y": y0, "w": x1 - x0 + 1, "h": y1 - y0 + 1, "cx": (x0 + x1) / 2, "cy": (y0 + y1) / 2}],
		"room_num": [1], "start_room": 0, "end_room": 0, "grave_room": -1, "start": inicio,
		"stairs_cell": {"cx": 0, "cy": 0}, "stairs_px": {"x": 16.0, "y": 16.0}, "fount": null,
		"torches": [], "decor": [], "litter": [], "wall_deco": [], "wall_veg": [], "flats": [],
		"chests": [], "gold": [], "doors": [], "key_tables": [], "deco": {},
		"dist": PisoPrueba._distancias(G, inicio, W, H), "prueba": n, "escena": nombre}, true)
	if hay_abismo:
		L["plataformas"] = true      # pisar el vacío hace caer (Sim._vigilar_caida_heroe)
		L["abismo_a_mano"] = true    # la roca, las cascadas y las luces del abismo las pone la escena
	if E.has("tema"):
		L["tema3d"] = String(E.tema)
	return L

# ======================================================================
#  montaje
# ======================================================================
static func montar(nombre: String, M: MazmorraGridMap, e: Environment, modo: String = "final") -> void:
	var E := datos(nombre)
	var tema := String(E.get("tema", ""))
	if not modo in MODOS:
		modo = "final"
	for o in E.get("objetos", []):
		_objeto(o, M, tema, modo)
	if modo == "final":
		ambiente(e, E.get("entorno", {}))
	else:
		ambiente(e, _NEUTRO)
		var sol := DirectionalLight3D.new()
		sol.name = "LuzNeutra"
		sol.light_energy = 1.1
		sol.shadow_enabled = true
		sol.light_volumetric_fog_energy = 0.0
		sol.rotation = Vector3(deg_to_rad(-55), deg_to_rad(150), 0)
		M.adornos.add_child(sol)
	# las brasas, el rocío y la niebla del tema solo en el modo final; en geometría, la roca del abismo en gris
	if modo != "final":
		for c in M.adornos.get_children():
			var n := String(c.name)
			if n in ["BrasasRaiz", "RocioRaiz", "Calima"] or n.begins_with("Niebla"):
				c.visible = false
			elif modo == "geometria" and n == "ParedesAbismo":
				(c as MeshInstance3D).material_override = _gris()

## la cámara de la escena: propia (fija, en perspectiva) o la del juego
static func camara(nombre: String) -> Dictionary:
	return datos(nombre).get("camara", {"tipo": "juego"})

static func _gris() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(.62, .6, .58)
	m.roughness = .9
	return m

static func _bloque(M: MazmorraGridMap, tam: Vector3, centro: Vector3, giro: float, nombre: String, color: Color = Color(.62, .6, .58)) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Bloque_" + nombre
	mi.set_meta("bloque", nombre)   # (el nombre se repite y Godot lo cambia)
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	var m := _gris()
	m.albedo_color = color
	mi.material_override = m
	mi.position = centro
	mi.rotation.y = giro
	M.adornos.add_child(mi)

static func _objeto(o: Dictionary, M: MazmorraGridMap, tema: String, modo: String) -> void:
	var pos := _v(o.get("pos", [0, 0, 0]))
	var giro := deg_to_rad(float(o.get("giro", 0.0))) if not o.get("giro") is Array else 0.0
	var geo := modo == "geometria"
	if o.has("pieza"):
		var partes := String(o.pieza).split("/")
		var esc = o.get("escala", 1.0)
		var vesc := _v(esc) if esc is Array else Vector3.ONE * float(esc)
		if geo:   # su caja, con el mismo tamaño que ocupa la pieza
			var m := Props3D.malla(partes[0], partes[1])
			if m != null:
				var a := m.get_aabb()
				var centro := Basis(Vector3.UP, giro) * ((a.position + a.size / 2) * vesc)
				_bloque(M, a.size * vesc, pos + centro, giro, partes[1])
			return
		var n := Props3D.crear(partes[0], partes[1])
		if n == null:
			return
		n.position = pos
		n.rotation.y = giro
		n.scale = vesc
		# rango de visibilidad: el de la escena o el de la ficha del catálogo (no es el detalle por distancia, que pone Godot)
		var hasta := float(o.get("visible_hasta", catalogo().get(String(o.pieza), {}).get("visible_hasta", 0.0)))
		if hasta > 0:
			n.visibility_range_end = hasta
		M.adornos.add_child(n)
	elif o.has("bloque"):
		var t := _v(o.bloque)
		_bloque(M, t, pos + Vector3(0, t.y / 2, 0), giro, String(o.get("nombre", "bloque")), Color(.75, .55, .45))
	elif o.has("caja"):
		var mi := MeshInstance3D.new()
		mi.name = String(o.get("nombre", "Caja"))
		var b := BoxMesh.new()
		b.size = _v(o.caja)
		mi.mesh = b
		if geo:
			mi.material_override = _gris()
		elif String(o.get("material", "")) == "suelo_tema" and tema != "":
			var m := TemaMazmorra.material_suelo(tema).duplicate() as StandardMaterial3D
			m.uv1_scale = Vector3.ONE / float(o.get("metros", TemaMazmorra.dato(tema, "suelo_m", 4.0)))
			mi.material_override = m
		elif String(o.get("material", "")) == "roca_tema" and tema != "":
			mi.material_override = TemaMazmorra._pbr(tema, "roca", float(o.get("metros", TemaMazmorra.dato(tema, "roca_m", 4.0))), true)
		elif String(o.get("material", "")) == "muro_tema" and tema != "":
			var k := TemaMazmorra.clave_muro(tema)
			mi.material_override = TemaMazmorra._pbr(tema, k, float(o.get("metros", TemaMazmorra.dato(tema, k + "_m", 3.0))), true)
		mi.position = pos
		mi.rotation.y = giro
		M.adornos.add_child(mi)
	elif o.has("lava"):
		var mi := MeshInstance3D.new()
		mi.name = String(o.get("nombre", "Lava"))
		var pl := PlaneMesh.new()
		pl.size = Vector2(float(o.lava[0]), float(o.lava[1]))
		mi.mesh = pl
		if geo:
			var m := _gris()
			m.albedo_color = Color(.8, .35, .1)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mi.material_override = m
		else:
			var m := TemaMazmorra.material_lava(tema)
			if o.has("fuerza"):
				m = m.duplicate() as ShaderMaterial
				m.set_shader_parameter("fuerza", float(o.fuerza))
			mi.material_override = m
		mi.position = pos
		M.adornos.add_child(mi)
	elif o.has("cascada"):
		if geo:
			var cc := Color(.3, .6, .85) if TemaMazmorra.abismo(tema) == "agua" else Color(.8, .35, .1)
			_bloque(M, Vector3(float(o.cascada[0]), float(o.cascada[1]), .2), pos - Vector3(0, float(o.cascada[1]) / 2, 0), giro, "cascada", cc)
			return
		var q := MeshInstance3D.new()
		q.name = "Cascada"
		var qm := QuadMesh.new()
		qm.size = Vector2(float(o.cascada[0]), float(o.cascada[1]))
		q.mesh = qm
		q.material_override = TemaMazmorra.material_liquido(tema, true)   # lava o agua, según el tema
		q.position = pos - Vector3(0, float(o.cascada[1]) / 2, 0)
		q.rotation.y = giro
		M.adornos.add_child(q)
	elif o.has("luz"):
		if modo != "final":
			return
		var d: Dictionary = o.luz
		if d.get("parpadea", false):
			M.fuego_luz(pos, float(d.get("energia", 3.0)), float(d.get("rango", 10.0)))
			return
		var l := OmniLight3D.new()
		l.position = pos
		l.light_color = _c(d.get("color"), Color(1, .5, .2))
		l.light_energy = float(d.get("energia", 3.0))
		l.omni_range = float(d.get("rango", 10.0))
		l.omni_attenuation = float(d.get("atenuacion", 1.1))
		l.light_volumetric_fog_energy = float(d.get("niebla", .5))
		l.shadow_enabled = bool(d.get("sombras", false))
		M.adornos.add_child(l)
	elif o.has("fuego"):
		if modo == "final":
			M.fuego_sin_luz(pos, float(o.fuego))
	elif o.has("disco"):
		if geo:
			return
		var mi := MeshInstance3D.new()
		mi.name = "Disco"
		mi.set_meta("disco", true)   # con dos, Godot cambia el nombre del segundo
		var c := CylinderMesh.new()
		c.top_radius = float(o.disco)
		c.bottom_radius = float(o.disco)
		c.height = .02
		c.radial_segments = 24
		mi.mesh = c
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = _c(o.get("color"), Color(.4, .9, 1)) * float(o.get("fuerza", 2.0))   # más de 1 resplandece
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = pos
		M.adornos.add_child(mi)
	elif o.has("sol"):
		if modo != "final":
			return
		var d: Dictionary = o.sol
		var s := DirectionalLight3D.new()
		s.name = "Sol"
		s.light_color = _c(d.get("color"))
		s.light_energy = float(d.get("energia", 1.0))
		s.shadow_enabled = bool(d.get("sombras", true))
		s.light_volumetric_fog_energy = float(d.get("niebla", 0.0))   # 0: si no, toda la niebla se tiñe
		var g: Array = o.get("giro", [-50, 150])
		s.rotation = Vector3(deg_to_rad(float(g[0])), deg_to_rad(float(g[1])), 0)
		M.adornos.add_child(s)
	elif o.has("cadena"):
		_cadena(M, _v(o.cadena.a), _v(o.cadena.b), float(o.cadena.get("caida", 0.0)), geo)
	elif o.has("jaula"):
		var d: Dictionary = o.jaula
		var arriba := _v(d.arriba)
		var largo := float(d.get("largo", 4.0))
		var esc := float(d.get("escala", 1.0))
		_cadena(M, arriba, arriba - Vector3(0, largo, 0), 0.0, geo)
		_objeto({"pieza": "puente/jaula", "pos": [arriba.x, arriba.y - largo - 2.3 * esc, arriba.z], "giro": float(d.get("giro", 0.0)), "escala": esc}, M, tema, modo)

## cadena colgada entre dos puntos: tramos de la pieza «puente/cadena» (3 m) siguiendo una catenaria
static func _cadena(M: MazmorraGridMap, a: Vector3, b: Vector3, caida: float, geo: bool) -> void:
	var n := maxi(2, ceili(a.distance_to(b) / 2.7))
	var puntos := []
	for i in n + 1:
		var t := float(i) / n
		puntos.append(a.lerp(b, t) - Vector3(0, caida * 4 * t * (1 - t), 0))
	for i in n:
		var p: Vector3 = puntos[i]
		var q: Vector3 = puntos[i + 1]
		var d := q - p
		var y := d.normalized()
		var x := y.cross(Vector3.UP).normalized() if absf(y.y) < .99 else Vector3.RIGHT
		var z := x.cross(y).normalized()
		var basis := Basis(x, y, z).scaled(Vector3(1.2, d.length() / 3.0, 1.2))
		if i % 2 == 1:
			basis = basis * Basis(Vector3.UP, PI / 2)
		var c: MeshInstance3D
		if geo:
			c = MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(.35, 3.0, .35)
			c.mesh = bm
			c.material_override = _gris()
			c.transform = Transform3D(basis, p + d / 2)
			M.adornos.add_child(c)
			continue
		c = Props3D.crear("puente", "cadena")
		if c == null:
			return
		c.basis = basis
		c.position = p
		M.adornos.add_child(c)

# ======================================================================
#  entorno (se guarda lo que había y se devuelve al salir: quitar())
# ======================================================================
const _NEUTRO := {"background_color": [.08, .08, .09], "ambient_light_color": [.7, .7, .72], "ambient_light_energy": .35,
	"volumetric_fog_enabled": false, "fog_enabled": false, "glow_enabled": false, "tonemap_exposure": 1.0}

static func ambiente(e: Environment, d: Dictionary) -> void:
	for k in d:
		if not _antes.has(k):
			_antes[k] = e.get(k)
		var v = d[k]
		e.set(k, _c(v) if v is Array else v)

static func quitar(e: Environment) -> void:
	for k in _antes:
		e.set(k, _antes[k])
	_antes.clear()

# ======================================================================
#  informe de rendimiento (con --shot y con F7). Recuentos: valen en cualquier máquina;
#  fotogramas por segundo y tiempo por fotograma: solo valen con tarjeta gráfica («medido_en»).
# ======================================================================
static func informe(raiz: Node, nombre: String, modo: String) -> Dictionary:
	var mallas := 0
	var tris := 0
	var luces := 0
	var sombras := 0
	var particulas := 0
	var vistos := {}
	for n in raiz.find_children("*", "", true, false):
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as Node3D).is_visible_in_tree():
			mallas += 1
			var m: Mesh = (n as MeshInstance3D).mesh
			if not vistos.has(m):
				var t := 0
				for s in m.get_surface_count():
					var arr := m.surface_get_arrays(s)
					var idx = arr[Mesh.ARRAY_INDEX]
					t += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
				vistos[m] = t
			tris += vistos[m]
		elif n is Light3D and (n as Node3D).is_visible_in_tree():
			luces += 1
			if (n as Light3D).shadow_enabled:
				sombras += 1
		elif (n is CPUParticles3D or n is GPUParticles3D) and (n as Node3D).is_visible_in_tree():
			particulas += 1
	var rs := RenderingServer
	return {
		"escena": nombre, "modo": modo, "fecha": Time.get_datetime_string_from_system(),
		"medido_en": rs.get_video_adapter_name(),
		"con_tarjeta_grafica": not rs.get_video_adapter_name().to_lower().contains("llvmpipe"),
		"objetos_con_malla": mallas, "triangulos_escena": tris, "luces": luces, "luces_con_sombra": sombras, "particulas": particulas,
		"dibujado_objetos": rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"dibujado_triangulos": rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"llamadas_de_dibujo": rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"memoria_video_mb": snappedf(rs.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, .1),
		"memoria_texturas_mb": snappedf(rs.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0, .1),
		"fps": Engine.get_frames_per_second(),
		"ms_por_fotograma": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, .01),
	}

static func guardar_informe(d: Dictionary, ruta: String) -> void:
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d, "  "))

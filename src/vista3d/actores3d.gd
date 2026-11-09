class_name Actores3D
extends Node3D
## Pinta en 3D lo que se mueve en la simulación: héroe, enemigos, botín, oro, cofres y puertas.
## Todo provisional (cápsulas y cajas) hasta que haya modelos: cada cosa se crea en un solo sitio
## (_nuevo_heroe, _nuevo_enemigo…) para cambiarla por una escena .glb sin tocar el resto.
##
## Equipo: el héroe tiene «enganches» (Marker3D) en la mano derecha, la izquierda y la cabeza, que hacen
## de BoneAttachment3D. Al cambiar el equipo en el inventario se cuelga la pieza nueva del enganche.
## Con un modelo de Mixamo: BoneAttachment3D en mixamorig_RightHand y la misma función _vestir().
## La armadura (casco, peto y hombreras, guantes, cinturón y botas) la pone Armadura3D en sus huesos.

var sim: Sim
const VEL_TAJO := 2.5   # ritmo del clip de ataque del héroe (recortado, ver _animar_heroe)
var heroe_id := "esqueleto"   # modelo del héroe (Modelo3D.FICHAS); si no existe, cápsula
## los enemigos sin modelo propio (caballeros, renegados…) usan este, provisional
const MODELO_HUMANOS := "prueba2"
## los esqueletos enemigos, más oscuros y rojizos que el héroe
const TINTE_ENEMIGO := Color(.72, .42, .36)
var heroe: Node3D
var _modelo_heroe: Modelo3D
var _hp_antes := -1.0
var _combo_antes := -2
var _mano_der: Node3D
var _mano_izq: Node3D
var _cabeza: Node3D
var _cuerpo: MeshInstance3D
var _firma_equipo := ""
var _armadura: Array[Node3D] = []
var _botin_nodos := {}     # id del objeto del suelo → Node3D
var _enemigos := {}        # id del objeto → Node3D
var _botin: Array[Node3D] = []
var _oro: Array[Node3D] = []
var _cofres := {}           # id de vista del cofre (c.vid) → Node3D
var _vid := 0
var _puertas: Array[Node3D] = []
var _rompibles: Array[Node3D] = []
var _trampas: Array[Node3D] = []
var _rejas: Array[Node3D] = []
var _firma_rejas := -1
var _t := 0.0

const COL_CLASE := {"knight": Color(.55, .6, .75), "dk": Color(.25, .22, .3), "archer": Color(.3, .5, .3), "mage": Color(.6, .25, .15), "dl": Color(.35, .1, .4)}

func nuevo_piso() -> void:
	for d in _enemigos.values():
		d.n.queue_free()
	for d in [_botin, _oro, _puertas, _rompibles, _trampas, _rejas]:
		for n in d:
			n.queue_free()
	for n in _cofres.values():
		n.queue_free()
	_rompibles.clear()
	_trampas.clear()
	_rejas.clear()
	_firma_rejas = -1
	_enemigos.clear()
	for n in _botin_nodos.values():
		n.queue_free()
	_botin_nodos.clear()
	_botin.clear()
	_oro.clear()
	_cofres.clear()
	_puertas.clear()
	if heroe == null:
		heroe = _nuevo_heroe()
		add_child(heroe)
	_firma_equipo = ""
	_sincronizar_cofres()
	for r in sim.rompibles:
		var n := _rompible(r.kind)
		n.position = MazmorraGridMap.a3d(r.x, r.y - 6)
		n.rotation.y = r.giro
		add_child(n)
		_rompibles.append(n)
	for tr in sim.trampas:
		var n := _trampa(tr.kind)
		n.position = Vector3((tr.cx + .5) * 2.0, 0, (tr.cy + .5) * 2.0)
		add_child(n)
		_trampas.append(n)
	if is_instance_valid(_sello):
		_sello.queue_free()
	_sello = _sello_escalera()
	add_child(_sello)
	for d in sim.doors:
		var n := Node3D.new()
		for ci in d.cells:   # índice de casilla: cy * GW + cx
			var hoja := _caja(Vector3(2.0, 2.6, .25) if d.h else Vector3(.25, 2.6, 2.0), Color(.3, .18, .08))
			hoja.position = Vector3((ci % DungeonGen.GW + .5) * 2.0, 1.3, (ci / DungeonGen.GW + .5) * 2.0)
			n.add_child(hoja)
		add_child(n)
		_puertas.append(n)

func actualizar(dt: float) -> void:
	_t += dt
	var p := sim.p
	if p == null:
		return
	if _modelo_heroe == null:
		heroe.visible = not p.dead   # con modelo se queda tumbado (animación de muerte) y con su luz
	heroe.position = MazmorraGridMap.a3d(p.x, p.y)
	heroe.rotation.y = _giro(p.face)
	heroe.rotation.x = 0.0
	if p.caida_t > 0:   # cae al abismo; al terminar la simulación lo devuelve al borde
		var t := Sim.CAIDA_T - p.caida_t
		heroe.position += caida(t, Vector2(p.x - p.seg_x, p.y - p.seg_y), p.face)
		heroe.rotation.x = -minf(1.1, t * 1.4)
	_animar_heroe(p)
	_vestir()
	_actualizar_enemigos(dt)
	# botín y oro: reserva de nodos del tamaño de la lista
	_actualizar_botin()
	_reserva(_oro, sim.gold.size(), func(): return _caja(Vector3(.3, .08, .3), Color(1, .8, .2), Color(1, .7, .1)))
	for i in sim.gold.size():
		_oro[i].position = MazmorraGridMap.a3d(sim.gold[i].x, sim.gold[i].y, 2)
	_sincronizar_cofres()
	_sello.visible = sim.jefe_vivo() != null
	if _sello.visible:
		_sello.rotation.y = _t * .6
	for c in sim.chests:
		var nc: Node3D = _cofres.get(c.get("vid", -1))
		if nc != null and nc.get_child_count() > 1:
			nc.get_child(1).rotation.x = -1.2 if c.open else 0.0
	for i in mini(_rompibles.size(), sim.rompibles.size()):
		_rompibles[i].visible = not sim.rompibles[i].roto
	for i in mini(_trampas.size(), sim.trampas.size()):
		_animar_trampa(_trampas[i], sim.trampas[i])
	_actualizar_rejas()
	for i in mini(_puertas.size(), sim.doors.size()):
		_puertas[i].visible = not sim.doors[i].open

## botín del suelo: las piezas de equipo con su forma 3D y su aura; runas y pociones, cajitas de color
func _actualizar_botin() -> void:
	var vistos := {}
	for l in sim.loot:
		var it: Dictionary = l.item
		var k = it.get("id", -1)
		vistos[k] = true
		var n: Node3D = _botin_nodos.get(k)
		if n == null:
			n = _nueva_pieza_suelo(it)
			add_child(n)
			_botin_nodos[k] = n
		var flota: bool = n.get_meta("caja", false)
		var vuela: bool = l.get("fly") != null
		n.position = MazmorraGridMap.a3d(l.x, l.y, (6 if flota else 2) + float(l.get("alto", 0.0))) + Vector3(0, (.15 if flota else .06) * sin(_t * 3 + l.bob), 0)
		n.rotation.y = _t * (9.0 if vuela else (1.5 if flota else .6))
		var haz: Node3D = n.get_meta("haz") if n.has_meta("haz") else null
		if haz != null:
			haz.visible = not vuela
			if not vuela:
				haz.scale.x = 1.0 + .12 * sin(_t * 4 + l.bob)
				haz.scale.z = haz.scale.x
	for k in _botin_nodos.keys():
		if not vistos.has(k):
			_botin_nodos[k].queue_free()
			_botin_nodos.erase(k)

func _nueva_pieza_suelo(it: Dictionary) -> Node3D:
	var n: Node3D = null
	# en el piso de prueba, las armas salen con su modelo del Weapon set, tumbadas en el suelo
	if it.get("gear", false) and sim.L.has("prueba"):
		var arma := _arma_de(it)
		var m: MeshInstance3D = Props3D.crear("armas", arma) if arma != "" else null
		if m != null:
			n = Node3D.new()
			m.rotation.x = -PI / 2
			n.add_child(m)
			n.set_meta("weapon_set", arma)
	if n == null and it.get("gear", false):
		n = Armadura3D.suelta(it)
		if n == null and it.slot == "shield":
			n = Node3D.new()
			var e := _escudo(it)
			e.rotation_degrees.x = -80
			n.add_child(e)
		elif n == null and it.slot == "sword":
			var ag := Modelo3D.agarre()
			if not ag.is_empty():
				n = Node3D.new()
				var mi := MeshInstance3D.new()
				mi.mesh = ag.mesh
				mi.rotation_degrees = Vector3(90, 0, 0)
				mi.scale = ag.t.basis.get_scale()
				n.add_child(mi)
	if n == null:
		var c := Color(Items.RN_TC[clampi(int(it.get("n", 1)), 1, 5)]) if it.slot == "rune" else Color(Items.RQ_C[clampi(int(it.get("q", 0)), 0, 3)])
		n = _caja(Vector3(.35, .35, .35), c, c)
		n.set_meta("caja", true)
	# los objetos mágicos o mejores dan un poco de luz de su color en el suelo
	var q := clampi(int(it.get("q", 0)), 0, 3)
	if it.get("gear", false) and q >= 2:
		# la pieza puede ir tumbada (girada): el haz va aparte, siempre vertical
		var envol := Node3D.new()
		envol.add_child(n)
		for mk in n.get_meta_list():
			envol.set_meta(mk, n.get_meta(mk))
		n = envol
		var haz := _haz(Color(Items.RQ_C[q]), q == 3)
		n.add_child(haz)
		n.set_meta("haz", haz)
	if it.get("gear", false) and q > 0:
		var luz := OmniLight3D.new()
		luz.light_color = Color(Items.RQ_C[q])
		luz.light_energy = .5 + .3 * q
		luz.omni_range = 1.8
		luz.position.y = .4
		n.add_child(luz)
	return n

## mímico: da saltitos al moverse y abre y cierra la tapa (rápido al atacar); al morir, se queda abierto y se hunde
func _animar_mimico(d: Dictionary, e: Ent.Enemy, dt: float) -> void:
	var cofre: Node3D = d.mimico
	var tapa: Node3D = cofre.get_child(1) if cofre.get_child_count() > 1 else null
	if e.dead or e.dying > 0:
		d.muerto = d.get("muerto", 0.0) + dt
		if tapa != null:
			tapa.rotation.x = -1.4
		cofre.rotation.z = lerpf(cofre.rotation.z, 1.4, minf(1, dt * 6))
		return
	var ataca: bool = e.act == "wind" or e.act == "strike"
	var t := _t + e.seed
	if tapa != null:
		tapa.rotation.x = -(.9 + .5 * sin(t * 26)) if ataca else -(.25 + .2 * absf(sin(t * 5)))
	cofre.position.y = absf(sin(t * 9)) * (.35 if e.state != "idle" else 0.0)

## rompibles: barril y caja del kit; la urna, de barro, hecha aquí girando un perfil
func _rompible(kind: String) -> Node3D:
	var n := Node3D.new()
	if kind != "urna" and KitMazmorra.tiene(kind):
		n.add_child(KitMazmorra.pieza(kind))
		return n
	if kind == "urna":
		var mi := MeshInstance3D.new()
		mi.mesh = _malla_urna()
		n.add_child(mi)
		return n
	n.add_child(_caja(Vector3(.8, .8, .8), Color(.42, .28, .15)))
	n.get_child(0).position.y = .4
	return n

var _urna: Mesh
func _malla_urna() -> Mesh:
	if _urna != null:
		return _urna
	# perfil (radio, altura) de abajo arriba: pie, panza, cuello y boca
	var perfil := [Vector2(0, 0), Vector2(.17, 0), Vector2(.2, .05), Vector2(.3, .22), Vector2(.34, .38), Vector2(.3, .55),
		Vector2(.18, .68), Vector2(.14, .76), Vector2(.19, .82), Vector2(.17, .85), Vector2(.12, .8)]
	var lados := 20
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in perfil.size() - 1:
		for j in lados:
			var a0 := TAU * j / lados
			var a1 := TAU * (j + 1) / lados
			var p0: Vector2 = perfil[i]
			var p1: Vector2 = perfil[i + 1]
			var v00 := Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var v01 := Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var v10 := Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var v11 := Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			st.add_vertex(v00); st.add_vertex(v10); st.add_vertex(v11)
			st.add_vertex(v00); st.add_vertex(v11); st.add_vertex(v01)
	st.generate_normals()
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.58, .32, .2)
	mat.roughness = .8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mat)
	_urna = m
	return m

## trampa: losa de hierro con rejilla; los pinchos salen de ella, y la de fuego echa una llamarada
func _trampa(kind: String) -> Node3D:
	var n := Node3D.new()
	var losa := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.5, .05, 1.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.42, .38, .34)   # más clara que las losas: se tiene que ver
	mat.metallic = .5
	mat.roughness = .45
	mat.emission_enabled = true
	mat.emission = Color(1, .35, .05)
	mat.emission_energy_multiplier = 0.0
	bm.material = mat
	losa.mesh = bm
	losa.position.y = .025
	n.add_child(losa)
	# rejilla: barras oscuras encima de la losa
	for k in 5:
		var barra := MeshInstance3D.new()
		var b2 := BoxMesh.new()
		b2.size = Vector3(1.4, .04, .06)
		var m2 := StandardMaterial3D.new()
		m2.albedo_color = Color(.08, .07, .07)
		b2.material = m2
		barra.mesh = b2
		barra.position = Vector3(0, .055, -.56 + k * .28)
		n.add_child(barra)
	var activo := Node3D.new()
	activo.visible = false
	n.add_child(activo)
	if kind == "pinchos":
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = .06
		cm.height = .55
		cm.radial_segments = 6
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(.7, .7, .72)
		pm.metallic = .9
		pm.roughness = .3
		cm.material = pm
		for x in 4:
			for z in 4:
				var pin := MeshInstance3D.new()
				pin.mesh = cm
				pin.position = Vector3(-.5 + x * .33, .27, -.5 + z * .33)
				activo.add_child(pin)
	else:
		var llama := CPUParticles3D.new()
		llama.amount = 60
		llama.lifetime = .6
		llama.direction = Vector3.UP
		llama.spread = 14
		llama.initial_velocity_min = 3.0
		llama.initial_velocity_max = 5.0
		llama.gravity = Vector3(0, 1.5, 0)
		llama.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		llama.emission_box_extents = Vector3(.5, .05, .5)
		llama.scale_amount_min = .6
		llama.scale_amount_max = 1.4
		var curva := Curve.new()
		curva.add_point(Vector2(0, .5))
		curva.add_point(Vector2(.3, 1))
		curva.add_point(Vector2(1, 0))
		llama.scale_amount_curve = curva
		var sm := SphereMesh.new()
		sm.radius = .12
		sm.height = .24
		sm.radial_segments = 6
		sm.rings = 3
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.albedo_color = Color(1, .55, .15)
		fm.emission_enabled = true
		fm.emission = Color(1, .45, .1)
		fm.emission_energy_multiplier = 4
		sm.material = fm
		llama.mesh = sm
		llama.emitting = false
		activo.add_child(llama)
		var luz := OmniLight3D.new()
		luz.light_color = Color(1, .5, .15)
		luz.light_energy = 3
		luz.omni_range = 5
		luz.position.y = 1.2
		activo.add_child(luz)
	n.set_meta("losa", mat)
	n.set_meta("activo", activo)
	return n

func _animar_trampa(n: Node3D, tr: Dictionary) -> void:
	var mat: StandardMaterial3D = n.get_meta("losa")
	var activo: Node3D = n.get_meta("activo")
	# aviso: la losa se pone al rojo (parpadea) medio segundo antes de dispararse
	mat.emission_energy_multiplier = (1.5 + sin(_t * 40) * 1.2) if tr.estado == "aviso" else (.6 if tr.estado == "activa" else .12)
	var on: bool = tr.estado == "activa"
	activo.visible = on or (tr.kind == "fuego" and tr.estado == "recarga")
	if tr.kind == "pinchos":
		activo.visible = on
	else:
		var llama: CPUParticles3D = activo.get_child(0)
		llama.emitting = on
		(activo.get_child(1) as OmniLight3D).visible = on

## rejas del reto: barras de hierro en cada salida de la sala mientras dura
func _actualizar_rejas() -> void:
	var sal: Array = sim.rejas_cerradas()
	if sal.size() == _firma_rejas:
		return
	_firma_rejas = sal.size()
	for r in _rejas:
		r.queue_free()
	_rejas.clear()
	for i in sal:
		var n := Node3D.new()
		n.position = Vector3((i % DungeonGen.GW + .5) * 2.0, 0, (i / DungeonGen.GW + .5) * 2.0)
		for k in 7:
			for eje in 2:
				var barra := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = .04
				cm.bottom_radius = .04
				cm.height = 2.8
				cm.radial_segments = 6
				var m := StandardMaterial3D.new()
				m.albedo_color = Color(.15, .14, .14)
				m.metallic = .8
				m.roughness = .45
				cm.material = m
				barra.mesh = cm
				var off := -.9 + k * .3
				barra.position = Vector3(off if eje == 0 else 0.0, 1.4, 0.0 if eje == 0 else off)
				n.add_child(barra)
		add_child(n)
		_rejas.append(n)
		# bajan desde arriba
		n.position.y = 2.8
		n.create_tween().tween_property(n, "position:y", 0.0, .35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

## haz de luz vertical sobre el botín: fuerte en los legendarios y más suave en los dorados
## (es redondo, así que da igual que gire con la pieza)
func _haz(c: Color, fuerte: bool) -> Node3D:
	var raiz := Node3D.new()
	var alto := 6.5 if fuerte else 3.5
	for capa in 2:   # núcleo estrecho y halo ancho
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = (.09 if capa == 0 else .32) * (1.0 if fuerte else .75)
		cm.bottom_radius = cm.top_radius * 1.3
		cm.height = alto
		cm.radial_segments = 16
		cm.cap_top = false
		cm.cap_bottom = false
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = false
		m.albedo_texture = _degradado_haz()
		m.texture_repeat = false   # si no, el borde de arriba toma el color del de abajo y sale un aro
		var k := (1.0 if capa == 0 else .45) * (1.0 if fuerte else .55)
		m.albedo_color = Color(c.r * k + (.4 if capa == 0 else 0.0), c.g * k + (.4 if capa == 0 else 0.0), c.b * k + (.4 if capa == 0 else 0.0), 1)
		cm.material = m
		mi.mesh = cm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.y = alto / 2
		raiz.add_child(mi)
	var luz := OmniLight3D.new()
	luz.light_color = c
	luz.light_energy = 2.5 if fuerte else 1.2
	luz.omni_range = 4.0 if fuerte else 2.5
	luz.position.y = .8
	raiz.add_child(luz)
	return raiz

var _tex_haz: Texture2D
## de abajo (lleno) a arriba (nada); en el CylinderMesh la v = 0 es la boca de arriba
func _degradado_haz() -> Texture2D:
	if _tex_haz == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0))
		g.set_color(1, Color(1, 1, 1, 1))
		g.add_point(.6, Color(1, 1, 1, .3))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_from = Vector2(0, 0)
		t.fill_to = Vector2(0, 1)
		t.width = 4
		t.height = 128
		_tex_haz = t
	return _tex_haz

## enemigos: se crean al aparecer; al morir se quedan tumbados un rato y se hunden en el suelo
func _actualizar_enemigos(dt: float) -> void:
	var vistos := {}
	for e in sim.enemies:
		var k: int = e.get_instance_id()
		var d: Dictionary = _enemigos.get(k, {})
		if d.is_empty():
			if e.dead:
				continue
			d = _nuevo_enemigo(e)
			_enemigos[k] = d
		vistos[k] = true
		var n: Node3D = d.n
		# lejos del héroe y sin despertar: ni se ve ni se anima (hay muchos enemigos por piso)
		var lejos: bool = e.state == "idle" and Vector2(e.x - sim.p.x, e.y - sim.p.y).length() * MazmorraGridMap.PX_M > LEJOS_M
		if lejos != d.get("lejos", false):
			d.lejos = lejos
			n.visible = not lejos
			n.process_mode = Node.PROCESS_MODE_DISABLED if lejos else Node.PROCESS_MODE_INHERIT
		if lejos:
			continue
		if d.has("escudo"):
			d.escudo.visible = e.escudo > 0 and not (e.dying > 0)
			if d.escudo.visible:
				d.escudo.scale = Vector3.ONE * (1.0 + sin(_t * 6) * .03)
		if d.has("aura"):
			d.aura.visible = not (e.dying > 0) and not e.dead
		var antes: Vector3 = n.position
		n.position = MazmorraGridMap.a3d(e.x, e.y, e.bz)
		if e.caida_t > 0 or d.get("cae", false):
			# cae al abismo: baja acelerando hasta perderse en la niebla; luego ya no se ve
			if not d.get("cae", false):
				d.cae = true
				d.cae_t = 0.0
				if d.m != null:
					d.m.reproducir("death", 1.0, .1, true)   # sin gesto de dolor en los enemigos
					d.muere = true
			d.cae_t += dt
			n.position += caida(d.cae_t, Vector2(e.x - e.seg_x, e.y - e.seg_y), e.face)
			n.rotation.x = -minf(1.1, d.cae_t * 1.4)
			if d.cae_t >= Sim.CAIDA_T:
				n.visible = false
				d.muerto = 100.0
			continue
		n.rotation.y = lerp_angle(n.rotation.y, _giro(e.face), minf(1, dt * 12))
		var m: Modelo3D = d.m
		if d.has("mimico"):
			_animar_mimico(d, e, dt)
			continue
		if m == null:   # cápsula provisional
			var golpe: bool = e.act == "strike" or e.act == "wind"
			n.get_child(0).position.z = -.25 if e.act == "strike" else 0.0
			n.get_child(0).rotation.x = -.35 if golpe else 0.0
			if e.dead or e.dying > 0:
				d.muerto = d.get("muerto", 0.0) + dt
			continue
		if e.dead or e.dying > 0:
			if not d.get("muere", false):
				d.muere = true
				m.reproducir("death", 1.0, .1, true)
			d.muerto = d.get("muerto", 0.0) + dt
			continue
		var vel := Vector2(n.position.x - antes.x, n.position.z - antes.z).length() / maxf(dt, .001)
		if e.act == "jump":
			if m.actual != "jump":
				m.reproducir("jump", 1.0, .08, true)
		elif e.act == "strike" and d.get("act", "") == "jump":
			m.reproducir("attack", 2.0, .05, true)   # puñetazos tras el salto
		elif e.act == "strike" and d.get("act", "") != "strike" and d.get("act", "") != "wind":
			m.reproducir("attack", 2.0, .05, true)
		elif e.act == "wind" and d.get("act", "") != "wind":
			# el golpe de la animación cae al final de la preparación (hit_at de la fábrica)
			var t_golpe: float = m.duracion("attack") * float(m.ficha.get("golpe", .6))
			m.reproducir("attack", t_golpe / maxf(.12, e.wind_t), .08, true)
		elif e.act == "wind" or e.act == "strike":
			pass
		elif vel > .15:
			# andar o correr con los pasos al ritmo del desplazamiento (los clips de Mixamo avanzan ~1,4 y ~3,5 m/s)
			if vel > 2.4:
				m.reproducir("run", clampf(vel / 3.5, .6, 1.8))
			else:
				m.reproducir("walk", clampf(vel / 1.4, .25, 1.8))
		else:
			m.reproducir("idle")
		d.act = e.act
	# los que ya no están (o llevan rato muertos): se hunden y se quitan
	for k in _enemigos.keys():
		var d: Dictionary = _enemigos[k]
		if not vistos.has(k):
			d.muerto = maxf(d.get("muerto", 0.0), .01) + dt
			if d.m != null and not d.get("muere", false):
				d.muere = true
				d.m.reproducir("death", 1.0, .1, true)
		var t: float = d.get("muerto", 0.0)
		if t > 6.0:
			d.n.position.y -= dt * .4
		if t > 8.0 or (d.m == null and t > 0):
			d.n.queue_free()
			_enemigos.erase(k)

## desplazamiento al caer al abismo t s después de pisar el vacío: sigue hacia donde iba (lejos del último
## suelo) y baja acelerando; en CAIDA_T s baja unos 11 m, ya dentro de la niebla
const CAIDA_G := 22.0
static func caida(t: float, dir_px: Vector2, face: float) -> Vector3:
	var d := dir_px.normalized() if dir_px.length() > .5 else Vector2(cos(face), sin(face))
	var lado := minf(t, .5) * 2.4   # sale del borde y después cae casi recto
	return Vector3(d.x * lado, -.5 * CAIDA_G * t * t, d.y * lado)

## en la simulación face es el ángulo en el plano (x, y) con y hacia abajo; en 3D el nodo mira a -z
static func _giro(face: float) -> float:
	return atan2(-cos(face), -sin(face))

func _animar_heroe(p: Ent.Hero) -> void:
	var corre := p.mx != 0 or p.my != 0
	var m := _modelo_heroe
	if m != null:
		if p.dead:
			if m.actual != "death":
				m.reproducir("death", 1.0, .1, true)
		elif p.caida_t > 0:
			if m.actual != "hurt":
				m.reproducir("hurt", .7, .05, true)
		elif p.atk_t > 0:
			# cada golpe del combo vuelve a empezar el tajo
			# el clip se recorta: empieza poco antes del impacto para que la espada toque justo cuando la simulación hace el daño
			if m.actual != "attack" or p.combo_step != _combo_antes:
				var t_imp: float = m.duracion("attack") * float(m.ficha.get("golpe", .5))
				var t_dano: float = (float(p.seq.hit) if p.seq != null else 3.0) * Sim.AFT
				m.reproducir_desde("attack", t_imp - t_dano * VEL_TAJO, VEL_TAJO)
			_combo_antes = p.combo_step
		elif _hp_antes >= 0 and p.hp < _hp_antes - .5 and m.actual != "attack":
			m.reproducir("hurt", 1.6, .05, true)
		elif m.actual == "hurt" and not m.terminada():
			pass
		elif p.roll_t > 0 or corre:
			m.reproducir("run", 1.3 if p.roll_t > 0 else maxf(.3, sim.vel_mov))   # los pasos al ritmo de «Velocidad al andar»
		else:
			m.reproducir("idle")
			_combo_antes = -2
		_hp_antes = p.hp
		return
	_cuerpo.position.y = .9 + (absf(sin(_t * 12)) * .06 if corre else sin(_t * 2) * .015)
	var ataca := p.atk_t > 0
	_mano_der.rotation.x = lerpf(_mano_der.rotation.x, -1.6 if ataca else -.2, .4)
	_mano_izq.position.z = -.25 if p.blocking else -.05
	heroe.scale = Vector3.ONE * (.9 if p.roll_t > 0 else 1.0)

# ---------- equipo ----------
## cuelga de los enganches lo que lleva puesto el héroe; solo rehace si ha cambiado algo
func _vestir() -> void:
	var eq: Dictionary = sim.p.eq
	var firma := ""
	for s in ["sword", "shield", "helm", "chest", "gloves", "belt", "boots"]:
		var it = eq.get(s)
		firma += "%s:%s;" % [s, "" if it == null else str(it.id)]
	if firma == _firma_equipo:
		return
	_firma_equipo = firma
	for m in [_mano_der, _mano_izq, _cabeza]:
		for c in m.get_children():
			c.queue_free()
	for c in _armadura:
		if is_instance_valid(c):
			c.queue_free()
	_armadura.clear()
	if _modelo_heroe != null:   # casco, peto y hombreras, guantes, cinturón y botas en sus huesos
		_armadura = Armadura3D.vestir(_modelo_heroe, eq)
	var arma = eq.get("sword")
	var guantes = eq.get("gloves")
	var agarre := Modelo3D.agarre() if _modelo_heroe != null else {}
	var arma_set := Armadura3D.arma(arma, "RightHand") if _modelo_heroe != null else null
	if arma_set != null:   # la espada del Set del Caballero Oscuro
		_mano_der.add_child(arma_set)
		_armadura.append(arma_set)
	elif arma != null and not agarre.is_empty():
		# la espada de la fábrica, cogida como la coge el esqueleto; brilla con el color de su calidad
		_mano_der.add_child(_arma_modelo(agarre, arma))
	elif arma != null:
		var hoja := _caja(Vector3(.08, .08, 1.1), Color(.8, .8, .85), Items_col(arma))
		hoja.position = Vector3(0, 0, -.55)
		_mano_der.add_child(hoja)
	elif guantes != null and _modelo_heroe == null:   # mago y Señor Oscuro pegan con los guantes
		_mano_der.add_child(_caja(Vector3(.2, .2, .2), Items_col(guantes), Items_col(guantes)))
	# mano izquierda: escudo, segunda espada o nada
	var izq = eq.get("shield")
	if izq != null:
		var tipo := "espada" if izq.slot == "sword" else "escudo"
		var ag := Modelo3D.agarre("esqueleto", "off_hand", tipo) if _modelo_heroe != null else {}
		var izq_set := Armadura3D.arma(izq, "LeftHand") if _modelo_heroe != null else null
		if izq_set != null:   # escudo (o segunda espada) del Set del Caballero Oscuro
			_mano_izq.add_child(izq_set)
		elif not ag.is_empty():
			_mano_izq.add_child(_arma_modelo(ag, izq))
		elif tipo == "escudo":
			_mano_izq.add_child(_escudo(izq))
		else:
			var hoja2 := _caja(Vector3(.08, .08, 1.1), Color(.8, .8, .85), Items_col(izq))
			hoja2.position = Vector3(0, 0, -.55)
			_mano_izq.add_child(hoja2)
	var casco = eq.get("helm")
	if casco != null and _modelo_heroe == null:   # el modelo ya trae su cabeza: el casco se verá cuando haya modelos de casco
		_cabeza.add_child(_caja(Vector3(.36, .3, .38), Color(.5, .5, .55), Items_col(casco)))
	var pecho = eq.get("chest")
	if _cuerpo != null:
		var base: Color = COL_CLASE.get(sim.p.cls, Color.GRAY)
		_color(_cuerpo, base.lerp(Items_col(pecho), .35) if pecho != null else base)

## un arma de la fábrica con su agarre; las mágicas o mejores brillan con el color de su calidad
func _arma_modelo(ag: Dictionary, it) -> MeshInstance3D:
	var e := MeshInstance3D.new()
	e.mesh = ag.mesh
	e.transform = ag.t
	if int(it.get("q", 0)) > 0:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(.7, .7, .75)
		mat.metallic = .9
		mat.roughness = .3
		mat.emission_enabled = true
		mat.emission = Items_col(it)
		mat.emission_energy_multiplier = .6
		e.material_overlay = mat
	return e

## escudo redondo de madera con borde y umbo de hierro; los mágicos o mejores brillan un poco con su color
func _escudo(it) -> Node3D:
	var raiz := Node3D.new()
	var madera := KitMazmorra.material("madera")
	var hierro := KitMazmorra.material("hierro")
	var tabla := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = .3
	c.bottom_radius = .3
	c.height = .04
	c.radial_segments = 24
	c.material = madera
	tabla.mesh = c
	raiz.add_child(tabla)
	var borde := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = .285
	t.outer_radius = .33
	t.material = hierro
	borde.mesh = t
	raiz.add_child(borde)
	var umbo := MeshInstance3D.new()
	var e := SphereMesh.new()
	e.radius = .07
	e.height = .07
	e.material = hierro
	umbo.mesh = e
	umbo.position.y = .02
	raiz.add_child(umbo)
	if int(it.get("q", 0)) > 0:
		var brillo := StandardMaterial3D.new()
		brillo.albedo_color = Color(0, 0, 0, 0)
		brillo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		brillo.emission_enabled = true
		brillo.emission = Items_col(it)
		brillo.emission_energy_multiplier = .5
		borde.material_overlay = brillo
	# la cara del escudo mira hacia fuera del brazo (eje x del hueso de la mano izquierda)
	raiz.rotation.z = PI / 2
	raiz.position = Vector3(-.08, .05, 0) if _modelo_heroe != null else Vector3.ZERO
	return raiz

static func Items_col(it) -> Color:
	if it == null:
		return Color.WHITE
	return Color(Items.RQ_C[clampi(int(it.get("q", 0)), 0, 3)])

# ---------- piezas provisionales ----------
func _nuevo_heroe() -> Node3D:
	var n := Node3D.new()
	n.name = "Heroe"
	_modelo_heroe = Modelo3D.crear(heroe_id)
	if _modelo_heroe != null:
		n.add_child(_modelo_heroe)
		# el arma que traiga el modelo de la fábrica se esconde: la pone el equipo (_vestir)
		for a in _modelo_heroe.find_children("arma_*", "MeshInstance3D", true, false):
			a.visible = false
		_mano_der = _modelo_heroe.enganche("RightHand")
		_mano_izq = _modelo_heroe.enganche("LeftHand")
		_cabeza = _modelo_heroe.enganche("HeadTop_End")
	else:
		_cuerpo = _capsula(.35, 1.8, Color.GRAY)
		_cuerpo.position.y = .9
		n.add_child(_cuerpo)
		_mano_der = Marker3D.new()
		_mano_der.position = Vector3(.45, .35, -.1)
		_cuerpo.add_child(_mano_der)
		_mano_izq = Marker3D.new()
		_mano_izq.position = Vector3(-.45, .2, -.05)
		_cuerpo.add_child(_mano_izq)
		_cabeza = Marker3D.new()
		_cabeza.position = Vector3(0, .75, 0)
		_cuerpo.add_child(_cabeza)
	# el radio de luz del héroe, como en Diablo
	var luz := OmniLight3D.new()
	luz.position = Vector3(0, 3.0, .5)
	luz.light_color = Color(1, .85, .7)
	luz.light_energy = 1.6
	luz.omni_range = 11
	luz.shadow_enabled = true
	n.add_child(luz)
	return n

func _nuevo_enemigo(e: Ent.Enemy) -> Dictionary:
	if e.mimic:   # el mímico es el propio cofre, que salta y muerde
		var raiz := Node3D.new()
		var cofre := _cofre()
		raiz.add_child(cofre)
		var ojos := OmniLight3D.new()
		ojos.light_color = Color(1, .15, .05)
		ojos.light_energy = 2.0
		ojos.omni_range = 2.5
		ojos.position = Vector3(0, .6, -.3)
		raiz.add_child(ojos)
		add_child(raiz)
		return {"n": raiz, "m": null, "mimico": cofre}
	var id: String = e.mon if e.mon != "" else MODELO_HUMANOS
	var m := Modelo3D.crear(id, TINTE_ENEMIGO if id == heroe_id else Color.WHITE)
	var d := {}
	if m != null:
		var raiz := Node3D.new()
		raiz.add_child(m)
		if e.jefe:
			m.scale = Vector3.ONE * ESCALA_JEFE
		elif e.rare:
			m.scale = Vector3.ONE * ESCALA_ELITE
		add_child(raiz)
		d = {"n": raiz, "m": m}
	else:
		var n := _capsula_enemigo(e)
		add_child(n)
		d = {"n": n, "m": null}
	if e.jefe or (e.rare and e.poder != ""):
		_marcar_elite(e, d)
	elif e.apr_titulo != "":
		_marcar_titulo(e, d)
	return d

## «Asesino» (te ha matado varias veces) o «Experto» (muchos combates) encima de su cabeza (Aprendizaje)
const COL_TITULO := {"Asesino": Color(1, .32, .25), "Experto": Color(1, .78, .35)}
func _marcar_titulo(e: Ent.Enemy, d: Dictionary) -> void:
	var l := Label3D.new()
	l.text = e.apr_titulo
	l.modulate = COL_TITULO.get(e.apr_titulo, Color.WHITE)
	l.outline_modulate = Color.BLACK
	l.outline_size = 8
	l.font_size = 28
	l.pixel_size = .005
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position.y = 2.35
	d.n.add_child(l)

const LEJOS_M := 32.0
const ESCALA_ELITE := 1.22
const ESCALA_JEFE := 1.6
## color del aura según el poder de la élite (el jefe, rojo)
const COL_PODER := {"rapido": Color(1, .85, .25), "escudo": Color(.45, .75, 1), "explota": Color(1, .45, .1), "invoca": Color(.7, .35, 1)}

## élites y jefe: aro de luz en el suelo, luz de su color, nombre encima y, con escudo, una burbuja
func _marcar_elite(e: Ent.Enemy, d: Dictionary) -> void:
	var c: Color = Color(1, .15, .1) if e.jefe else COL_PODER.get(e.poder, Color(1, .6, .1))
	var k := ESCALA_JEFE if e.jefe else ESCALA_ELITE
	var aura := Node3D.new()
	var aro := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = .55 * k
	tm.outer_radius = .68 * k
	tm.rings = 40
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(c.r, c.g, c.b, .55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 2.5
	tm.material = mat
	aro.mesh = tm
	aro.scale = Vector3(1, .04, 1)
	aro.position.y = .05
	aura.add_child(aro)
	var luz := OmniLight3D.new()
	luz.light_color = c
	luz.light_energy = 2.2 if e.jefe else 1.3
	luz.omni_range = 4.5 if e.jefe else 3.0
	luz.position.y = 1.2
	aura.add_child(luz)
	var l := Label3D.new()
	l.text = e.title if e.apr_titulo == "" else "%s · %s" % [e.apr_titulo, e.title]
	l.modulate = c.lightened(.35)
	l.outline_modulate = Color.BLACK
	l.outline_size = 8
	l.font_size = 40 if e.jefe else 30
	l.pixel_size = .005
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position.y = 2.3 * k + (.6 if e.jefe else 0.0)
	aura.add_child(l)
	d.n.add_child(aura)
	d.aura = aura
	if e.escudo_max > 0:
		var b := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = .9 * k
		sm.height = 2.3 * k
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.albedo_color = Color(.5, .8, 1, .16)
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.rim_enabled = true
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.material = bm
		b.mesh = sm
		b.position.y = 1.0 * k
		d.n.add_child(b)
		d.escudo = b

## cofres: uno por cada cofre de la simulación, por su id de vista (el jefe y el reto dejan el suyo, más grande;
## el mímico sale de la lista al morder y su cofre pasa a ser el enemigo)
func _sincronizar_cofres() -> void:
	var hay := {}
	for c in sim.chests:
		if not c.has("vid"):
			_vid += 1
			c["vid"] = _vid
		hay[c.vid] = true
		if not _cofres.has(c.vid):
			var n := _cofre()
			n.position = MazmorraGridMap.a3d(c.x, c.y - 12)
			if c.get("grande", false):
				n.scale *= 1.6
			add_child(n)
			_cofres[c.vid] = n
	for k in _cofres.keys():
		if not hay.has(k):
			_cofres[k].queue_free()
			_cofres.erase(k)

## sello rojo sobre la escalera mientras el jefe del piso siga vivo
var _sello: Node3D
func _sello_escalera() -> Node3D:
	var n := Node3D.new()
	if sim.L.is_empty() or not sim.L.has("stairs_px"):
		return n
	n.position = MazmorraGridMap.a3d(sim.L.stairs_px.x, sim.L.stairs_px.y) + Vector3(0, .1, 0)
	var c := Color(1, .12, .06)
	for i in 2:
		var aro := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.0 + i * .35
		tm.outer_radius = 1.1 + i * .35
		tm.rings = 48
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 3
		tm.material = m
		aro.mesh = tm
		aro.scale = Vector3(1, .04, 1)
		n.add_child(aro)
	var col := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.1
	cm.height = 2.4
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.albedo_color = Color(1, .1, .05, .12)
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.material = cmat
	col.mesh = cm
	col.position.y = 1.2
	n.add_child(col)
	var luz := OmniLight3D.new()
	luz.light_color = c
	luz.light_energy = 2.0
	luz.omni_range = 5
	luz.position.y = 1.5
	n.add_child(luz)
	return n

func _capsula_enemigo(e: Ent.Enemy) -> Node3D:
	var n := Node3D.new()
	var grande := e.boss != "" or e.elite or e.rare
	var k := 1.6 if e.boss != "" else (1.2 if grande else 1.0)
	var c := Color.from_hsv(float(hash(e.type) % 360) / 360.0, .45, .55)
	var cuerpo := _capsula(.33 * k, 1.6 * k, c)
	cuerpo.position.y = .8 * k
	n.add_child(cuerpo)
	if grande:
		var m: StandardMaterial3D = (cuerpo.mesh as CapsuleMesh).material
		m.emission_enabled = true
		m.emission = Color(1, .6, .1) if e.boss == "" else Color(1, .1, .1)
		m.emission_energy_multiplier = .4
	var ojo := _caja(Vector3(.3 * k, .06, .06), Color.BLACK, Color(1, .2, .1))
	ojo.position = Vector3(0, .55 * k, -.3 * k)
	cuerpo.add_child(ojo)
	return n

func _capsula(r: float, h: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = .6
	cm.material = m
	mi.mesh = cm
	return mi

## cofre de Poly Haven (cuerpo + tapa en su bisagra); si no está el paquete, la caja provisional.
## La tapa va en get_child(1) (se abre girándola en x, ver actualizar()).
func _cofre() -> Node3D:
	var cuerpo := Props3D.crear("polyhaven", "cofre")
	var tapa := Props3D.crear("polyhaven", "cofre_tapa")
	if cuerpo == null or tapa == null:
		return _caja(Vector3(1.0, .7, .7), Color(.4, .25, .1), Color(.9, .7, .2))
	var raiz := Node3D.new()
	raiz.add_child(cuerpo)
	var bisagra := Node3D.new()
	bisagra.position = BISAGRA_COFRE
	bisagra.add_child(tapa)
	raiz.add_child(bisagra)
	raiz.scale = Vector3.ONE * 1.25
	return raiz

## dónde va la bisagra de la tapa respecto al origen del cofre (lo imprime tools/blender/props_glb.py)
const BISAGRA_COFRE := Vector3(0, .418, -.261)

## qué modelo del Weapon set le va a un objeto ("" si ninguno)
static func _arma_de(it: Dictionary) -> String:
	if not it.get("gear", false):
		return ""
	var n := String(it.get("name", "")).to_lower()
	for par in [["hacha", "hacha"], ["martillo", "martillo"], ["maza", "garrote"], ["garrote", "garrote"], ["daga", "daga"], ["lanza", "lanza"], ["guadaña", "guadana"]]:
		if n.contains(par[0]):
			return par[1]
	var cls := String(it.get("cls", ""))
	if it.slot == "shield" and cls != "archer":
		return "escudo"
	if it.slot == "sword" and cls != "archer":
		return "espada"
	return ""

## caja con color; si brillo no es blanco, emite un poco (objetos mágicos, oro)
func _caja(t: Vector3, c: Color, brillo: Color = Color.WHITE) -> Node3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = t
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if brillo != Color.WHITE:
		m.emission_enabled = true
		m.emission = brillo
		m.emission_energy_multiplier = .8
	b.material = m
	mi.mesh = b
	if t.y < 1.0 and t.x > .8:   # cofre: cuerpo + tapa
		mi.position.y = t.y / 2
		var tapa := MeshInstance3D.new()
		var bt := BoxMesh.new()
		bt.size = Vector3(t.x, .15, t.z)
		bt.material = m
		tapa.mesh = bt
		tapa.position = Vector3(0, t.y / 2 + .07, t.z / 2)
		var raiz := Node3D.new()
		raiz.add_child(mi)
		var bisagra := Node3D.new()
		bisagra.position = Vector3(0, t.y, -t.z / 2)
		tapa.position = Vector3(0, .07, t.z / 2)
		bisagra.add_child(tapa)
		raiz.add_child(bisagra)
		return raiz
	return mi

func _color(n: Node, c: Color) -> void:
	var mi: MeshInstance3D = n as MeshInstance3D
	if mi == null or mi.mesh == null:
		return
	var m := (mi.mesh as PrimitiveMesh).material as StandardMaterial3D
	if m != null:
		m.albedo_color = c
		if m.emission_enabled:
			m.emission = c

func _reserva(lista: Array[Node3D], n: int, crear: Callable) -> void:
	while lista.size() < n:
		var x = crear.call()
		x.mesh = (x.mesh as PrimitiveMesh).duplicate(true)
		add_child(x)
		lista.append(x)
	for i in lista.size():
		lista[i].visible = i < n

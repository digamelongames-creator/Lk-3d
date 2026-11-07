class_name Actores3D
extends Node3D
## Pinta en 3D lo que se mueve en la simulación: héroe, enemigos, botín, oro, cofres y puertas.
## Todo provisional (cápsulas y cajas) hasta que haya modelos: cada cosa se crea en un solo sitio
## (_nuevo_heroe, _nuevo_enemigo…) para cambiarla por una escena .glb sin tocar el resto.
##
## Equipo: el héroe tiene «enganches» (Marker3D) en la mano derecha, la izquierda y la cabeza, que hacen
## de BoneAttachment3D. Al cambiar el equipo en el inventario se cuelga la pieza nueva del enganche.
## Con un modelo de Mixamo: BoneAttachment3D en mixamorig_RightHand y la misma función _vestir().

var sim: Sim
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
var _enemigos := {}        # id del objeto → Node3D
var _botin: Array[Node3D] = []
var _oro: Array[Node3D] = []
var _cofres: Array[Node3D] = []
var _puertas: Array[Node3D] = []
var _t := 0.0

const COL_CLASE := {"knight": Color(.55, .6, .75), "dk": Color(.25, .22, .3), "archer": Color(.3, .5, .3), "mage": Color(.6, .25, .15), "dl": Color(.35, .1, .4)}

func nuevo_piso() -> void:
	for d in _enemigos.values():
		d.n.queue_free()
	for d in [_botin, _oro, _cofres, _puertas]:
		for n in d:
			n.queue_free()
	_enemigos.clear()
	_botin.clear()
	_oro.clear()
	_cofres.clear()
	_puertas.clear()
	if heroe == null:
		heroe = _nuevo_heroe()
		add_child(heroe)
	_firma_equipo = ""
	for c in sim.chests:
		var n := _caja(Vector3(1.0, .7, .7), Color(.4, .25, .1), Color(.9, .7, .2))
		n.position = MazmorraGridMap.a3d(c.x, c.y - 12)
		add_child(n)
		_cofres.append(n)
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
	_animar_heroe(p)
	_vestir()
	_actualizar_enemigos(dt)
	# botín y oro: reserva de nodos del tamaño de la lista
	_reserva(_botin, sim.loot.size(), func(): return _caja(Vector3(.35, .35, .35), Color.WHITE, Color.WHITE))
	for i in sim.loot.size():
		var l: Dictionary = sim.loot[i]
		var n := _botin[i]
		var it: Dictionary = l.item
		var c := Color(Items.RN_TC[clampi(int(it.get("n", 1)), 1, 5)]) if it.slot == "rune" else Color(Items.RQ_C[clampi(int(it.q), 0, 3)])
		_color(n, c)
		n.position = MazmorraGridMap.a3d(l.x, l.y, 6) + Vector3(0, .15 * sin(_t * 3 + l.bob), 0)
		n.rotation.y = _t * 1.5
	_reserva(_oro, sim.gold.size(), func(): return _caja(Vector3(.3, .08, .3), Color(1, .8, .2), Color(1, .7, .1)))
	for i in sim.gold.size():
		_oro[i].position = MazmorraGridMap.a3d(sim.gold[i].x, sim.gold[i].y, 2)
	for i in mini(_cofres.size(), sim.chests.size()):
		_cofres[i].get_child(1).rotation.x = -1.2 if sim.chests[i].open else 0.0
	for i in mini(_puertas.size(), sim.doors.size()):
		_puertas[i].visible = not sim.doors[i].open

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
		var antes: Vector3 = n.position
		n.position = MazmorraGridMap.a3d(e.x, e.y, e.bz)
		n.rotation.y = lerp_angle(n.rotation.y, _giro(e.face), minf(1, dt * 12))
		var m: Modelo3D = d.m
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
		elif vel > .4:
			# andar o correr con los pasos al ritmo del desplazamiento (los clips de Mixamo avanzan ~1,4 y ~3,5 m/s)
			if vel > 2.4:
				m.reproducir("run", clampf(vel / 3.5, .6, 1.8))
			else:
				m.reproducir("walk", clampf(vel / 1.4, .6, 1.8))
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
		elif p.atk_t > 0:
			# cada golpe del combo vuelve a empezar el tajo
			if m.actual != "attack" or p.combo_step != _combo_antes:
				m.reproducir("attack", 1.6, .06, true)
			_combo_antes = p.combo_step
		elif _hp_antes >= 0 and p.hp < _hp_antes - .5 and m.actual != "attack":
			m.reproducir("hurt", 1.6, .05, true)
		elif m.actual == "hurt" and not m.terminada():
			pass
		elif p.roll_t > 0 or corre:
			m.reproducir("run", 1.3 if p.roll_t > 0 else 1.0)
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
	for s in ["sword", "shield", "helm", "chest", "gloves"]:
		var it = eq.get(s)
		firma += "%s:%s;" % [s, "" if it == null else str(it.id)]
	if firma == _firma_equipo:
		return
	_firma_equipo = firma
	for m in [_mano_der, _mano_izq, _cabeza]:
		for c in m.get_children():
			c.queue_free()
	var arma = eq.get("sword")
	var guantes = eq.get("gloves")
	var agarre := Modelo3D.agarre() if _modelo_heroe != null else {}
	if arma != null and not agarre.is_empty():
		# la espada de la fábrica, cogida como la coge el esqueleto; brilla con el color de su calidad
		var e := MeshInstance3D.new()
		e.mesh = agarre.mesh
		e.transform = agarre.t
		if int(arma.get("q", 0)) > 0:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(.7, .7, .75)
			mat.metallic = .9
			mat.roughness = .3
			mat.emission_enabled = true
			mat.emission = Items_col(arma)
			mat.emission_energy_multiplier = .6
			e.material_overlay = mat
		_mano_der.add_child(e)
	elif arma != null:
		var hoja := _caja(Vector3(.08, .08, 1.1), Color(.8, .8, .85), Items_col(arma))
		hoja.position = Vector3(0, 0, -.55)
		_mano_der.add_child(hoja)
	elif guantes != null:   # mago y Señor Oscuro pegan con los guantes
		_mano_der.add_child(_caja(Vector3(.2, .2, .2), Items_col(guantes), Items_col(guantes)))
	var escudo = eq.get("shield")
	if escudo != null:
		_mano_izq.add_child(_escudo(escudo))
	var casco = eq.get("helm")
	if casco != null and _modelo_heroe == null:   # el modelo ya trae su cabeza: el casco se verá cuando haya modelos de casco
		_cabeza.add_child(_caja(Vector3(.36, .3, .38), Color(.5, .5, .55), Items_col(casco)))
	var pecho = eq.get("chest")
	if _cuerpo != null:
		var base: Color = COL_CLASE.get(sim.p.cls, Color.GRAY)
		_color(_cuerpo, base.lerp(Items_col(pecho), .35) if pecho != null else base)

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
	var id: String = e.mon if e.mon != "" else MODELO_HUMANOS
	var m := Modelo3D.crear(id, TINTE_ENEMIGO if id == heroe_id else Color.WHITE)
	if m != null:
		var raiz := Node3D.new()
		raiz.add_child(m)
		add_child(raiz)
		return {"n": raiz, "m": m}
	var n := _capsula_enemigo(e)
	add_child(n)
	return {"n": n, "m": null}

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

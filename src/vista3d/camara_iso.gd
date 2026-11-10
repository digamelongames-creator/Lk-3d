class_name CamaraIso
extends Camera3D
## Cámara isométrica (ortográfica, mapa en diagonal), como en el concept y en Diablo 2.
## inclinacion: 90° = cenital; ~33° = isométrica. giro: 45° = mapa en diagonal; 0° = mira al norte.
## Con ortografica = false es perspectiva con campo de visión estrecho (más parecido a Diablo 3/4).

var inclinacion := deg_to_rad(33.0)
var giro := deg_to_rad(45.0)
var ortografica := true
var zoom := 17.0         # metros de alto que caben en pantalla (ortográfica)
var temblor := 0.0
const DIST := 40.0

func _ready() -> void:
	near = .1
	far = 200
	aplicar()

func aplicar() -> void:
	projection = PROJECTION_ORTHOGONAL if ortografica else PROJECTION_PERSPECTIVE
	size = zoom
	fov = 30

## dirección (x, z) del suelo que va del objetivo hacia la cámara
func hacia_camara() -> Vector2:
	return Vector2(0, 1).rotated(-giro)

## coloca la cámara mirando a objetivo; suave > 0 la lleva poco a poco
func seguir(objetivo: Vector3, dt: float, suave: bool = true) -> void:
	var a := hacia_camara()
	var vista := Vector3(a.x * cos(inclinacion), sin(inclinacion), a.y * cos(inclinacion))
	var dist := DIST if ortografica else zoom / (2.0 * tan(deg_to_rad(fov) / 2.0))
	var destino := objetivo + vista * dist
	position = position.lerp(destino, minf(1, dt * 8)) if suave else destino
	if temblor > 0:
		position += Vector3(randf() - .5, randf() - .5, randf() - .5) * temblor * .4
	look_at(position - vista)
	RenderingServer.global_shader_parameter_set("dir_camara", a)

## el punto del suelo (y = 0) bajo una posición de pantalla
func suelo_bajo(pantalla: Vector2) -> Vector3:
	var o := project_ray_origin(pantalla)
	var d := project_ray_normal(pantalla)
	if absf(d.y) < .001:
		return o
	return o + d * (-o.y / d.y)

## luz, niebla y postprocesado compartidos por el juego y la sala de prueba
static func ambiente(padre: Node) -> WorldEnvironment:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(.012, .009, .012)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(.42, .42, .5)
	e.ambient_light_energy = .35
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.2
	e.glow_enabled = true
	e.glow_intensity = .55
	e.glow_bloom = .03
	e.glow_hdr_threshold = 1.3
	e.ssao_enabled = true
	e.ssao_radius = .8
	e.ssao_intensity = 3.0
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = .012
	e.volumetric_fog_albedo = Color(.9, .7, .55)
	e.volumetric_fog_length = 60
	# sin reproyección temporal: con ella la niebla y las luces temblaban al moverse hasta asentarse
	e.volumetric_fog_temporal_reprojection_enabled = false
	# niebla de altura: solo actúa por debajo del suelo (el abismo de los pisos 3 a 5); la roca se pierde en ella
	e.fog_enabled = true
	e.fog_density = .0005   # casi nada por distancia; con 0 Godot no aplica la de altura
	e.fog_light_color = Color(.07, .075, .095)
	e.fog_height = -.6
	e.fog_height_density = .32
	e.adjustment_enabled = true
	e.adjustment_saturation = .9
	e.adjustment_contrast = 1.12
	we.environment = e
	padre.add_child(we)
	var luna := DirectionalLight3D.new()
	luna.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-30), 0)
	luna.light_color = Color(.55, .6, .85)
	luna.light_energy = .08
	padre.add_child(luna)
	return we

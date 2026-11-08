class_name Opciones
extends RefCounted
## Opciones del jugador: pantalla, zoom por defecto, brillo, calidad gráfica, sonido y velocidad de movimiento.
## Se guardan en user://opciones.cfg y se aplican al arrancar y cada vez que se cambian (MenuInicio).

const RUTA := "user://opciones.cfg"
const DEFECTO := {
	"pantalla_completa": true,
	"zoom": 17,          # metros de alto en pantalla al empezar (CamaraIso.zoom, de 7 a 20)
	"brillo": 100,       # % sobre la exposición de CamaraIso.ambiente
	"sombras": true,     # sombras de antorchas, braseros y la luz del héroe
	"niebla": true,      # niebla volumétrica
	"postprocesado": true,  # resplandor y oclusión ambiental (SSAO)
	"sonido": true,      # false: el bus principal en silencio
	"velocidad": 100,    # % de la velocidad de andar del héroe y de los enemigos (banco de pruebas, 30–100)
}
const EXPOSICION := 1.2   # la de CamaraIso.ambiente con brillo 100 %
const ATLAS_SOMBRAS := 4096

static var valores := {}

static func cargar() -> void:
	valores = DEFECTO.duplicate()
	var cf := ConfigFile.new()
	if cf.load(RUTA) != OK:
		return
	for k in DEFECTO:
		valores[k] = cf.get_value("opciones", k, DEFECTO[k])
	valores.zoom = clampi(int(valores.zoom), 7, 20)
	valores.brillo = clampi(int(valores.brillo), 60, 160)
	valores.velocidad = clampi(int(valores.velocidad), 30, 100)

static func guardar() -> void:
	var cf := ConfigFile.new()
	for k in valores:
		cf.set_value("opciones", k, valores[k])
	cf.save(RUTA)

static func v(k: String):
	if valores.is_empty():
		cargar()
	return valores.get(k, DEFECTO.get(k))

static func poner(k: String, valor) -> void:
	if valores.is_empty():
		cargar()
	valores[k] = valor
	guardar()

## pantalla completa o ventana (solo si cambia: no tocar la ventana en cada arranque sin motivo)
static func aplicar_pantalla(w: Window) -> void:
	var completa: bool = v("pantalla_completa")
	var es := w.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	if completa != es:
		w.mode = Window.MODE_FULLSCREEN if completa else Window.MODE_WINDOWED

## brillo y calidad sobre el entorno de CamaraIso.ambiente y la vista
static func aplicar_grafico(we: WorldEnvironment, vp: Viewport) -> void:
	if we != null and we.environment != null:
		var e := we.environment
		e.tonemap_exposure = EXPOSICION * float(v("brillo")) / 100.0
		e.volumetric_fog_enabled = v("niebla")
		e.glow_enabled = v("postprocesado")
		e.ssao_enabled = v("postprocesado")
	if vp != null:
		vp.positional_shadow_atlas_size = ATLAS_SOMBRAS if v("sombras") else 0

## sonido sí o no: silencia el bus principal (lo que suena por Fx3D y cualquier otro)
static func aplicar_sonido() -> void:
	AudioServer.set_bus_mute(0, not v("sonido"))

## factor de velocidad de andar para la simulación (Sim.vel_mov)
static func vel_mov() -> float:
	return float(v("velocidad")) / 100.0

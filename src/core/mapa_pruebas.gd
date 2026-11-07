class_name MapaPruebas
## Mapa de pruebas: el piso 3 con una semilla fija, para probar suelos, decoración y texturas.
## Niveles A y B: el mismo mapa con las losetas de cada paquete (`--pruebas=a`, `--pruebas=b`; ver Losetas).
## siempre sobre el mismo sitio. Juego: `-- --pruebas[=clase]`. Foto: `foto_piso.gd -- --pruebas`.
## Lo experimental se enciende solo aquí con `MapaPruebas.es(L)`.

const PISO := 3
const SEMILLA := "pruebas"
## estilo de losetas del mapa de pruebas: "" (el del juego), "a" (Dungeon Wall and Floor) o "b" (Ancient Ruins)
const ESTILOS := ["", "a", "b"]
## en el menú de inicio, debajo de las oleadas
const NOMBRES := ["Prueba · Mapa de pruebas", "Prueba · Nivel A (losetas pintadas)", "Prueba · Nivel B (ruinas de arenisca)"]
const ID_MENU := 100

## lo que se elige en el menú: un número de oleada (1–15) o ID_MENU + estilo
static func desde_menu(id: int) -> bool:
	if id < ID_MENU:
		estilo = ""
		return false
	estilo = ESTILOS[clampi(id - ID_MENU, 0, ESTILOS.size() - 1)]
	return true
static var estilo := ""

static func semilla_piso() -> String:
	return SEMILLA + "-" + str(PISO)   # como Sim.level_seed

static func es(L: Dictionary) -> bool:
	return int(L.get("wave", 0)) == PISO and String(L.get("seed", "")).begins_with(semilla_piso() + "#")

static func generar(e: String = estilo) -> Dictionary:
	var antes := estilo
	estilo = e
	var L := DungeonGen.gen_level(semilla_piso(), PISO)
	estilo = antes
	return L

## lo llama DungeonGen._post: marca el estilo en el mapa de pruebas
static func marcar(L: Dictionary) -> void:
	if estilo != "" and es(L):
		L["estilo"] = estilo

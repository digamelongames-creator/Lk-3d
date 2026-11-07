class_name SimFx
extends RefCounted
## Lo que la simulación «pide que se vea»: sangre, chispas, textos, temblor, avisos.
## La simulación nunca dibuja: llama a estos métodos y la presentación decide cómo se ven.
## Esta versión no hace nada (sirve para las pruebas sin pantalla); la vista la sustituye.

## partículas que salen disparadas desde (x, y) a altura z
func burst(x: float, y: float, z: float, cols: Array, n: int, spd: float) -> void: pass
## sangre que salpica en dirección ang
func bleed(x: float, y: float, z: float, ang: float, n: int, spd: float, spread: float = .9) -> void: pass
## partícula suelta (dict con x, y, z, vx, vy, vz, life, col, float)
func part(q: Dictionary) -> void: pass
## mancha de 1–2 px en el suelo
func stain(x: float, y: float, col: String, sz: int = 1) -> void: pass
## charco bajo un cuerpo
func pool(x: float, y: float, r: float) -> void: pass
func blood_pool(o, r: float) -> void: pass
## texto flotante (daño, avisos sobre la cabeza)
func text(x: float, y: float, txt: String, col: String, size: float = 10, crit: bool = false, life: float = .8, slow: bool = false, jitter: bool = true) -> void: pass
## cartel grande en el centro
func banner(top: String, main: String) -> void: pass
func shake(v: float) -> void: pass
## cadáver estampado en el suelo
func corpse(e) -> void: pass
## un cadáver se levanta: borrar su dibujo del suelo
func corpse_raised(c: Dictionary) -> void: pass
func hud() -> void: pass
## un sonido en (x, y): tajo1–3, impacto, bloqueo, herido, muerte_enemigo, oro… (ver assets/audio/sonidos.json)
func sonido(id: StringName, x: float, y: float) -> void: pass
## el Charco de sangre absorbe la sangre del suelo bajo (x, y)
func blood_suck(x: float, y: float, r: float) -> void: pass

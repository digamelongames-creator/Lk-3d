class_name Mulberry32
extends RefCounted
## Generador mulberry32 del juego web: misma semilla, misma secuencia.

var a: int

func _init(seed_u32: int) -> void:
	a = seed_u32 & JS.M32

## Siguiente número en [0, 1).
func next() -> float:
	a = (a + 0x6D2B79F5) & JS.M32
	var t := JS.imul(a ^ (a >> 15), 1 | a)
	t = ((t + JS.imul(t ^ (t >> 7), 61 | t)) & JS.M32) ^ t
	return float((t ^ (t >> 14)) & JS.M32) / 4294967296.0

## Entero en [lo, hi] (el ri del generador).
func ri(lo: int, hi: int) -> int:
	return lo + int(floorf(next() * float(hi - lo + 1)))

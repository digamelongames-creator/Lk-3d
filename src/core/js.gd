class_name JS
## Aritmética de JavaScript, número a número, para que la misma semilla dé el mismo mapa
## que el juego web. Los enteros de 32 bits se guardan como uint32 (0 … 2^32-1).

const M32 := 0xFFFFFFFF

## Math.imul: producto de 32 bits (sin desbordar el int de 64 bits de GDScript).
static func imul(a: int, b: int) -> int:
	a &= M32
	b &= M32
	var lo := (a & 0xFFFF) * b
	var hi := (((a >> 16) * b) & 0xFFFF) << 16
	return (lo + hi) & M32

## x | 0 en JavaScript (ToInt32), devuelto como uint32. x es un double con valor entero.
static func to_u32(x: float) -> int:
	if is_nan(x) or is_inf(x):
		return 0
	var t := int(x) if absf(x) < 9.0e18 else int(fmod(x, 4294967296.0))
	return t & M32

## Interpreta un uint32 como entero con signo de 32 bits.
static func i32(u: int) -> int:
	u &= M32
	return u - 0x100000000 if u >= 0x80000000 else u

## hashStr del juego web.
static func hash_str(s: String) -> int:
	var h := (1779033703 ^ s.length()) & M32
	var u := s.to_utf16_buffer()
	for i in range(0, u.size(), 2):
		var c := u[i] | (u[i + 1] << 8)
		h = imul(h ^ c, 3432918353)
		h = ((h << 13) | (h >> 19)) & M32
	return h

## Math.round de JavaScript (redondea .5 hacia +∞).
static func round(x: float) -> float:
	return floorf(x + 0.5)

static func roundi(x: float) -> int:
	return int(floorf(x + 0.5))

## Math.hypot de V8 (suma de Kahan escalada): coincide bit a bit con el navegador.
static func hypot(x: float, y: float) -> float:
	var ax := absf(x)
	var ay := absf(y)
	var mx := maxf(ax, ay)
	if mx == 0.0:
		return 0.0
	var s := 0.0
	var comp := 0.0
	for v in [ax, ay]:
		var n: float = v / mx
		var summand := n * n - comp
		var pre := s + summand
		comp = (pre - s) - summand
		s = pre
	return sqrt(s) * mx

## Math.sign
static func sign(x: float) -> float:
	return 1.0 if x > 0.0 else (-1.0 if x < 0.0 else 0.0)

## Orden estable (como Array.prototype.sort de V8). cmp(a, b) devuelve un número: <0, 0 o >0.
static func stable_sort(arr: Array, cmp: Callable) -> Array:
	var n := arr.size()
	if n < 2:
		return arr.duplicate()
	var a := arr.duplicate()
	var b := []
	b.resize(n)
	var width := 1
	while width < n:
		var i := 0
		while i < n:
			var mid := mini(i + width, n)
			var hi := mini(i + 2 * width, n)
			var l := i
			var r := mid
			var k := i
			while l < mid and r < hi:
				if cmp.call(a[r], a[l]) < 0:
					b[k] = a[r]; r += 1
				else:
					b[k] = a[l]; l += 1
				k += 1
			while l < mid:
				b[k] = a[l]; l += 1; k += 1
			while r < hi:
				b[k] = a[r]; r += 1; k += 1
			i += 2 * width
		var t := a
		a = b
		b = t
		width *= 2
	return a

## Array.prototype.sort de V8 para listas de menos de 64 elementos (TimSort: tramo inicial + inserción binaria).
## Hace falta cuando el comparador gasta números al azar: el orden de las comparaciones debe ser el mismo.
static func v8_sort(arr: Array, cmp: Callable) -> Array:
	var a := arr.duplicate()
	var n := a.size()
	if n < 2:
		return a
	if n >= 64:
		return stable_sort(arr, cmp)
	# CountAndMakeRun(0, n)
	var run := 2
	var desc: bool = cmp.call(a[1], a[0]) < 0
	var prev = a[1]
	for idx in range(2, n):
		var cur = a[idx]
		var order: float = cmp.call(cur, prev)
		if desc:
			if order >= 0: break
		else:
			if order < 0: break
		prev = cur
		run += 1
	if desc:
		var lo := 0
		var hi := run - 1
		while lo < hi:
			var t = a[lo]; a[lo] = a[hi]; a[hi] = t
			lo += 1; hi -= 1
	# BinaryInsertionSort(0, run, n)
	for start in range(run, n):
		var left := 0
		var right := start
		var pivot = a[start]
		while left < right:
			var mid := left + ((right - left) >> 1)
			if cmp.call(pivot, a[mid]) < 0:
				right = mid
			else:
				left = mid + 1
		var p := start
		while p > left:
			a[p] = a[p - 1]
			p -= 1
		a[left] = pivot
	return a

## cuál de las 8 direcciones de los sprites corresponde a un ángulo
static func dir8(a: float) -> int:
	return ((roundi(a / (PI / 4)) % 8) + 8) % 8

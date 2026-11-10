class_name Comparar
## Comparación de una pieza con la que lleva puesta el héroe en ese hueco: cada estadística con su flecha
## al lado (▲ verde si gana, ▼ rojo si pierde). La usan la ventana del objeto del inventario y el aviso
## del botín del suelo en el HUD. Devuelve líneas [texto, color, tamaño].

const C_MAS := Color8(143, 224, 138)
const C_MENOS := Color8(255, 122, 96)
const C_IGUAL := Color8(159, 208, 255)
const C_LEG := Color8(63, 224, 176)   # legendario: turquesa (#3fe0b0)

static func lineas(it: Dictionary, cur, tam: int = 11) -> Array:
	var out := []
	var ks := []
	for a in it.bonus:
		ks.append(a)
	if cur != null:
		for a in cur.bonus:
			if not ks.has(a):
				ks.append(a)
	for a in ks:
		var v: int = int(it.bonus.get(a, 0))
		if cur == null:
			out.append([Items.stat_txt(a, v), C_IGUAL, tam])
			continue
		var d: int = v - int(cur.bonus.get(a, 0))
		var txt := Items.stat_txt(a, v) if v != 0 else "Sin " + String(Items.STAT_NM[a]).to_lower()
		if d > 0:
			out.append([txt + "   ▲ +" + str(d), C_MAS, tam])
		elif d < 0:
			out.append([txt + "   ▼ −" + str(-d), C_MENOS, tam])
		else:
			out.append([txt + "   =", C_IGUAL, tam])
	var n: int = it.socks.size()
	var used: int = it.socks.filter(func(x): return x != null).size()
	var st := ("Engarces: %d de %d" % [used, n]) if n else "Sin engarces"
	var ds: int = n - cur.socks.size() if cur != null else 0
	if ds > 0:
		out.append([st + "   ▲ +" + str(ds), C_MAS, tam - 1])
	elif ds < 0:
		out.append([st + "   ▼ −" + str(-ds), C_MENOS, tam - 1])
	else:
		out.append([st, Color8(150, 140, 120), tam - 1])
	# efecto único de los legendarios (10 nov 2026)
	var ef := Legendarios.texto(it)
	if ef != "":
		out.append(["★ " + ef, C_LEG, tam])
	if cur != null and Legendarios.de(cur) != "" and Legendarios.de(cur) != Legendarios.de(it):
		out.append(["Pierdes: " + Legendarios.texto(cur), C_MENOS, tam - 1])
	return out

class_name Atlas
## Hojas de sprites del juego web y cómo se dibujan (drawKF, drawDK, drawFrame…).
## Los atlas de personajes están a doble resolución y se dibujan a la mitad, como en la web.

static var kn_meta: Dictionary
static var kn_count: Dictionary
static var dk_meta: Dictionary
static var dk_count: Dictionary
static var knight: Texture2D           # caballero sin teñir (muertos alzados, cadáveres)
static var knight_var: Array = []      # por tipo de enemigo (pecho azul, verde, rojo, negro y oro)
static var dk: Texture2D
static var deco: Texture2D
static var tiles: Texture2D
static var items: Texture2D
static var items_meta: Dictionary
static var sprites: Texture2D
static var sp_meta: Dictionary
static var potion: Texture2D
static var chest: Dictionary = {}
static var fountain_base: Texture2D
static var alt: Dictionary = {}        # héroes renegados: mage, archer, dk, dl → {tex, meta, count}
static var fxa: Dictionary             # atlas de efectos (nube de muerte…)
static var fx_tex: Texture2D
static var _ready := false

# modos del shader sprite_tint (ver el .gdshader)
static func hard(c: Color, a: float = 1.0) -> Color:
	return Color(c.r + 2.0, c.g + 2.0, c.b + 2.0, a)
static func soft(c: Color, a: float = 1.0) -> Color:
	return Color(-c.r - 1.0, -c.g - 1.0, -c.b - 1.0, a)

static func load_all() -> void:
	if _ready:
		return
	var kn: Dictionary = GameData.get_table("knight_atlas")
	kn_meta = kn.meta
	kn_count = kn.count
	var dka: Dictionary = GameData.get_table("death_knight_atlas")
	dk_meta = dka.meta
	dk_count = dka.count
	knight = load("res://assets/web/img/knight.webp")
	for i in 4:
		knight_var.append(load("res://assets/web/gen/knight_variant_%d.webp" % i))
	dk = load("res://assets/web/img/death_knight.webp")
	deco = load("res://assets/web/img/deco.png")
	tiles = load("res://assets/web/img/tiles.webp")
	items = load("res://assets/web/img/items.png")
	items_meta = GameData.get_table("items_atlas")
	sprites = load("res://assets/web/img/atlas_sprites.png")
	sp_meta = GameData.get_table("sprites_atlas")
	potion = load("res://assets/web/img/potion.png")
	for k in ["wood", "iron", "gold", "cursed", "mimic"]:
		chest[k] = load("res://assets/web/gen/chest_%s_closed.png" % k)
		chest[k + "_open"] = load("res://assets/web/gen/chest_%s_open.png" % k)
	fountain_base = load("res://assets/web/gen/fountain_base.png")
	for h in [["mage", "wizard_atlas", "wizard"], ["archer", "archer_atlas", "archer"], ["dk", "death_knight_atlas", "death_knight"], ["dl", "dark_lord_atlas", "dark_lord"]]:
		var A: Dictionary = GameData.get_table(h[1])
		alt[h[0]] = {"tex": load("res://assets/web/img/%s.webp" % h[2]), "meta": A.meta, "count": A.count}
	alt["minion"] = {"tex": knight, "meta": kn_meta, "count": kn_count}
	fxa = GameData.get_table("fx_atlas")
	fx_tex = load("res://assets/web/img/fx.webp")
	_ready = true

static func kdir(a: float) -> int:
	return JS.dir8(a)

## fotograma de un caballero (enemigo o muerto alzado); devuelve false si no existe
static func draw_kf(ci: CanvasItem, tex: Texture2D, anim: String, dir: int, i: float, x: float, y: float, mod: Color = Color.WHITE, sc: float = 1.0) -> bool:
	var n: int = int(kn_count.get(anim, 1))
	var ii := clampi(int(floorf(i)), 0, n - 1)
	var f = kn_meta.get(anim + "_" + str(dir) + "_" + str(ii))
	if f == null:
		return false
	ci.draw_texture_rect_region(tex, Rect2(x - f[4] * sc * .5, y - f[5] * sc * .5, f[2] * sc * .5, f[3] * sc * .5), Rect2(f[0], f[1], f[2], f[3]), mod)
	return true

## fotograma del Caballero de la Muerte
static func draw_dk(ci: CanvasItem, anim: String, dir: int, i: float, x: float, y: float, mod: Color = Color.WHITE) -> bool:
	var n: int = int(dk_count.get(anim, 1))
	var ii := clampi(int(floorf(i)), 0, n - 1)
	var f = dk_meta.get(anim + "_" + str(dir) + "_" + str(ii))
	if f == null:
		return false
	ci.draw_texture_rect_region(dk, Rect2(x - f[4] * .5, y - f[5] * .5, f[2] * .5, f[3] * .5), Rect2(f[0], f[1], f[2], f[3]), mod)
	return true

static func dk_count_of(a: String) -> int:
	return int(dk_count.get(a, 1))

static func kn_count_of(a: String) -> int:
	return int(kn_count.get(a, 1))

## fotograma del atlas de sprites con su ancla en (x, y), como drawFrame de la web
static func draw_frame(ci: CanvasItem, n: String, x: float, y: float, mod: Color = Color.WHITE) -> void:
	var f = sp_meta.get(n)
	if f == null:
		return
	ci.draw_texture_rect_region(sprites, Rect2(JS.roundi(x - f[4]), JS.roundi(y - f[5]), f[2], f[3]), Rect2(f[0], f[1], f[2], f[3]), mod)

## fotograma de un héroe renegado (hhBlit); devuelve false si no existe
static func draw_alt(ci: CanvasItem, h: String, anim: String, dir: int, i: float, x: float, y: float, mod: Color = Color.WHITE) -> bool:
	var T: Dictionary = alt[h]
	var n: int = int(T.count.get(anim, 1))
	var ii := clampi(int(floorf(i)), 0, n - 1)
	var f = T.meta.get(anim + "_" + str(dir) + "_" + str(ii))
	if f == null:
		return false
	ci.draw_texture_rect_region(T.tex, Rect2(x - f[4] * .5, y - f[5] * .5, f[2] * .5, f[3] * .5), Rect2(f[0], f[1], f[2], f[3]), mod)
	return true

static func alt_count(h: String, a: String) -> int:
	return int(alt[h].count.get(a, 1))

## fotograma del atlas de efectos con su ancla en (0, 0) y escala sc (fxSprite)
static func draw_fx(ci: CanvasItem, k: String, i: int, x: float, y: float, sc: float, mod: Color = Color.WHITE) -> void:
	var n: int = int(fxa.count.get(k, 1))
	var f = fxa.meta.get(k + "_" + str(((i % n) + n) % n))
	if f == null:
		return
	ci.draw_texture_rect_region(fx_tex, Rect2(x - f[4] * sc, y - f[5] * sc, f[2] * sc, f[3] * sc), Rect2(f[0], f[1], f[2], f[3]), mod)

# ---------------- monstruos con hoja propia ----------------
## direcciones de la web (0 = derecha, en sentido horario) → columna de la hoja y si se refleja
const MON_DIR := {0: ["R", false], 1: ["FR", false], 2: ["F", false], 3: ["FR", true], 4: ["R", true], 5: ["BR", true], 6: ["B", false], 7: ["BR", false]}
## monstruos con las 8 direcciones reales en la hoja: nada se refleja
## "dirs8" (Bufona, columnas R/FR/F/FL/L/BL/B/BR) o "dir8" (fábrica de sprites, columnas por rumbo E/SE/S/…)
const MON_DIR8 := {0: ["R", false], 1: ["FR", false], 2: ["F", false], 3: ["FL", false], 4: ["L", false], 5: ["BL", false], 6: ["B", false], 7: ["BR", false]}
const MON_DIR8_RUMBO := {0: ["E", false], 1: ["SE", false], 2: ["S", false], 3: ["SW", false], 4: ["W", false], 5: ["NW", false], 6: ["N", false], 7: ["NE", false]}
static var mon_sheets: Dictionary = {}

## columna de la hoja y si se refleja para la dirección dir (0 = derecha, en sentido horario)
static func mon_dir(M: Dictionary, dir: int) -> Array:
	if M.get("dir8", false):
		return MON_DIR8_RUMBO[dir]
	return MON_DIR8[dir] if M.get("dirs8", false) else MON_DIR[dir]

## la hoja ya reducida a su escala K (suavizada, como imageSmoothing de la web) para dibujarla 1:1
static func mon_sheet(id: String) -> Texture2D:
	if mon_sheets.has(id):
		return mon_sheets[id]
	var M: Dictionary = GameData.get_table("monsters")[id]
	if (M.get("hoja_pp", false) or "--hoja_pp" in OS.get_cmdline_user_args()) and _cargar_pp(id, M):
		return mon_sheets[id]
	var img: Image = (load("res://assets/web/img/enemies/%s.webp" % id) as Texture2D).get_image()
	if M.get("hd", false):
		# hoja en alta (fábrica de sprites): se guarda tal cual y se reduce al dibujar, con mipmaps y filtro
		# lineal, así a pantalla completa se ve con la definición del render y no con la del mundo
		img.generate_mipmaps()
		var ct := CanvasTexture.new()
		ct.diffuse_texture = ImageTexture.create_from_image(img)
		ct.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mon_sheets[id] = ct
		return ct
	var K: float = M.K
	if K != 1.0:
		img.resize(maxi(1, JS.roundi(img.get_width() * K)), maxi(1, JS.roundi(img.get_height() * K)), Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.create_from_image(img)
	mon_sheets[id] = tex
	return tex

## hoja postprocesada a pixel art (tools/postproceso_sprites.py, carpeta <id>_pp/): ya va a la escala del
## mundo, así que se dibuja 1:1 y sin suavizar. Cambia la meta y la escala de M (solo las usa el dibujo).
## Se enciende con "hoja_pp": true en monsters.json o con -- --hoja_pp; si falta la hoja, se queda la original.
static func _cargar_pp(id: String, M: Dictionary) -> bool:
	var dir := "res://assets/web/img/enemies/%s_pp/%s_pp" % [id, id]
	if not ResourceLoader.exists(dir + ".png") or not FileAccess.file_exists(dir + "_meta.json"):
		push_warning("hoja_pp de %s no encontrada: se usa la original" % id)
		return false
	var meta = JSON.parse_string(FileAccess.get_file_as_string(dir + "_meta.json"))
	if not meta is Dictionary:
		return false
	var ct := CanvasTexture.new()
	ct.diffuse_texture = load(dir + ".png")
	ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	M.meta = meta
	M.K = 1.0
	M.hd = false
	mon_sheets[id] = ct
	return true

## escala de las coordenadas de la meta dentro de la textura cargada (1 si la hoja va en alta)
static func mon_src_k(M: Dictionary) -> float:
	return 1.0 if M.get("hd", false) else float(M.K)

## fotograma de un monstruo con el pie en (x, y); i fraccionario funde con el siguiente si la animación es corta
static func draw_mon(ci: CanvasItem, id: String, a: String, dir: int, i: float, x: float, y: float, mod: Color = Color.WHITE) -> void:
	var M: Dictionary = GameData.get_table("monsters")[id]
	var md: Array = mon_dir(M, dir)
	var col: String = md[0]
	var flip: bool = md[1]
	var n: int = int(M.n.get(a, 1))
	var loop := a == "walk" or a == "idle"
	var fi := floorf(i)
	var fr := i - fi
	var ii := int(fi)
	ii = ((ii % n) + n) % n if loop else clampi(ii, 0, n - 1)
	var tex := mon_sheet(id)
	var fix: Dictionary = mon_anclas(id)
	_mon_blit(ci, tex, M, a + "_" + col + "_" + str(ii), x, y, flip, mod, fix)
	if n < 12 and fr > .08:
		var i2 := (ii + 1) % n if loop else mini(n - 1, ii + 1)
		if i2 != ii:
			_mon_blit(ci, tex, M, a + "_" + col + "_" + str(i2), x, y, flip, Color(mod.r, mod.g, mod.b, mod.a * fr), fix)

## corrección del ancla por fotograma (tools/reanclar_monstruos.py): quita el movimiento de raíz de los clips 3D
static var _anclas: Dictionary = {}
static func mon_anclas(id: String) -> Dictionary:
	if _anclas.is_empty():
		var t = GameData.get_table("mon_anclas") if FileAccess.file_exists(GameData.DIR + "mon_anclas.json") else null
		_anclas = t if t is Dictionary else {"_": {}}
	return _anclas.get(id, {})

## transformación de fondo mientras se dibuja un personaje (la caída al abismo); los reflejos la respetan
static var xf_base := Transform2D.IDENTITY

static func _mon_blit(ci: CanvasItem, tex: Texture2D, M: Dictionary, key: String, x: float, y: float, flip: bool, mod: Color, fix: Dictionary = {}) -> void:
	var f = M.meta.get(key)
	if f == null:
		return
	var o: Array = fix.get(key, [0.0, 0.0])
	var K: float = M.K
	var w: float = f[2] * K
	var h: float = f[3] * K
	var dx: float = x - (f[4] + o[0]) * K
	var r := Rect2(JS.round(dx), JS.round(y - (f[5] + o[1]) * K), w, h)
	var sk := mon_src_k(M)
	var src := Rect2(f[0] * sk, f[1] * sk, f[2] * sk, f[3] * sk)
	if flip:
		# reflejo alrededor de los pies: un Rect2 de ancho negativo no refleja la textura (solo la movía)
		ci.draw_set_transform_matrix(xf_base * Transform2D(0, Vector2(-1, 1), 0, Vector2(2 * JS.round(x), 0)))
		ci.draw_texture_rect_region(tex, r, src, mod)
		ci.draw_set_transform_matrix(xf_base)
		return
	ci.draw_texture_rect_region(tex, r, src, mod)

## sprite del pack de decoración con el pie en (x, y)
static func draw_deco(ci: CanvasItem, n: String, x: float, y: float, mod: Color = Color.WHITE) -> void:
	var m = GameData.deco_meta().get(n)
	if m == null:
		return
	ci.draw_texture_rect_region(deco, Rect2(JS.roundi(x - m[2] / 2.0), JS.roundi(y - m[3]), m[2], m[3]), Rect2(m[0], m[1], m[2], m[3]), mod)

# ---------------- piezas de equipo (láminas del inventario, teñidas por calidad) ----------------
static var _gear_img: Dictionary = {}
static var _gear_tex: Dictionary = {}
static var _gear_world: Dictionary = {}
static var statue: Texture2D

static func piece_path(cls: String, s: String) -> String:
	return "res://assets/web/img/rn_pieces_%s.webp" % s if cls == "knight" else "res://assets/web/img/rn_sets_img_%s_%s.webp" % [cls, s]

## lámina reducida a 200 px como mucho y teñida con el modo «color» del lienzo (tono del color, luz de la lámina)
static func gear_img(cls: String, s: String, q: int) -> Image:
	var key := "%s|%s|%d" % [cls, s, q]
	if _gear_img.has(key):
		return _gear_img[key]
	var img: Image = (load(piece_path(cls, s)) as Texture2D).get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var sc := minf(1, 200.0 / maxf(img.get_width(), img.get_height()))
	img.resize(maxi(1, JS.roundi(img.get_width() * sc)), maxi(1, JS.roundi(img.get_height() * sc)), Image.INTERPOLATE_LANCZOS)
	if q > 0:
		var tc := ViewFx.col(Items.RQ_C[q])
		var ga: float = [0.0, .5, .55, .55][q]
		var lc := .3 * tc.r + .59 * tc.g + .11 * tc.b
		var d := img.get_data()
		for i in range(0, d.size(), 4):
			if d[i + 3] == 0:
				continue
			var r := d[i] / 255.0
			var g := d[i + 1] / 255.0
			var b := d[i + 2] / 255.0
			var dl := (.3 * r + .59 * g + .11 * b) - lc
			var cr := tc.r + dl
			var cg := tc.g + dl
			var cb := tc.b + dl
			# recorte de setLum (W3C) para no salirse de [0, 1]
			var l := .3 * cr + .59 * cg + .11 * cb
			var n := minf(cr, minf(cg, cb))
			var x := maxf(cr, maxf(cg, cb))
			if n < 0:
				cr = l + (cr - l) * l / (l - n); cg = l + (cg - l) * l / (l - n); cb = l + (cb - l) * l / (l - n)
			if x > 1:
				cr = l + (cr - l) * (1 - l) / (x - l); cg = l + (cg - l) * (1 - l) / (x - l); cb = l + (cb - l) * (1 - l) / (x - l)
			d[i] = clampi(int((r + (cr - r) * ga) * 255), 0, 255)
			d[i + 1] = clampi(int((g + (cg - g) * ga) * 255), 0, 255)
			d[i + 2] = clampi(int((b + (cb - b) * ga) * 255), 0, 255)
		img = Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d)
	_gear_img[key] = img
	return img

## para el inventario (se dibuja suavizado)
static func gear_tex(cls: String, s: String, q: int) -> Texture2D:
	var key := "%s|%s|%d" % [cls, s, q]
	if not _gear_tex.has(key):
		_gear_tex[key] = ImageTexture.create_from_image(gear_img(cls, s, q))
	return _gear_tex[key]

## para el suelo: ya reducida al tamaño del mundo (16×22 las grandes, 13×15 las demás)
static func gear_world(cls: String, s: String, q: int) -> Texture2D:
	var key := "%s|%s|%d" % [cls, s, q]
	if not _gear_world.has(key):
		var img: Image = gear_img(cls, s, q).duplicate()
		var big := s == "sword" or s == "chest" or s == "shield"
		var sc := minf((16.0 if big else 13.0) / img.get_width(), (22.0 if big else 15.0) / img.get_height())
		img.resize(maxi(1, JS.roundi(img.get_width() * sc)), maxi(1, JS.roundi(img.get_height() * sc)), Image.INTERPOLATE_LANCZOS)
		_gear_world[key] = ImageTexture.create_from_image(img)
	return _gear_world[key]

static func statue_tex() -> Texture2D:
	if statue == null:
		statue = load("res://assets/web/img/rn_statue.png")
	return statue

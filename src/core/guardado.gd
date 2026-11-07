class_name Guardado
## Partida guardada (saveGame / loadSave / continueGame del juego web), en user://partida.save.
## Se guarda al empezar cada piso, al salir al menú y al cerrar o dejar la ventana; «Continuar» la recupera
## en el piso donde se guardó. Morir y empezar de cero la borra.

const PATH := "user://partida.save"
const V := 1
const HERO := ["lvl", "xp", "pts", "skp", "tree", "alloc", "upg", "bag", "eq", "hp", "best_chain", "dmg_dealt", "gold", "keys", "rn_cls"]

static func guardar(sim: Sim) -> void:
	var p := sim.p
	if p == null or p.dead or sim.over or sim.L.is_empty():
		return
	var h := {}
	for k in HERO:
		h[k] = p.get(k)
	var d := {"v": V, "cls": p.cls_key(), "wave": sim.wave, "seed": sim.run_seed, "score": sim.score, "kills": sim.kills, "stats": sim.stats, "start_wave": sim.start_wave, "t": Time.get_unix_time_from_system(), "p": h}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(var_to_str(d))

static func cargar() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = str_to_var(f.get_as_text())
	if not (d is Dictionary) or d.get("v") != V or not Sim.CLASS_ORDER.has(d.get("cls", "")):
		return {}
	return d

static func borrar() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

## pone al héroe de la partida nueva (ya creada con su clase y piso) lo guardado
static func aplicar(sim: Sim, d: Dictionary) -> void:
	var p := sim.p
	var h: Dictionary = d.p
	for k in HERO:
		if h.has(k) and h[k] != null:
			p.set(k, h[k])
	sim.score = d.get("score", 0)
	sim.kills = d.get("kills", 0)
	if d.has("stats"):
		sim.stats = Sim.new_stats()
		sim.stats.merge(d.stats, true)
	sim.start_wave = int(d.get("start_wave", sim.wave))
	# los objetos nuevos no repiten número con los guardados
	var mx := 0
	for it in p.bag:
		mx = maxi(mx, int(it.id))
	for s in p.eq:
		if p.eq[s] != null:
			mx = maxi(mx, int(p.eq[s].id))
	Items.item_id = maxi(Items.item_id, mx + 1)
	var hp: float = p.hp
	sim.runes.agg(p)
	p.hp = clampf(hp, 1, p.st.maxHp)
	p.mana = p.st.maxMana
	sim.fx.hud()

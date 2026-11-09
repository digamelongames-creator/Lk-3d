class_name Ent
## Personajes de la simulación: el héroe, los enemigos y los muertos alzados.
## Mismos campos que en el juego web para que el código traducido se pueda comparar línea a línea.

class Hero extends RefCounted:
	var cls := "knight"          # knight (también el Caballero de la Muerte y el Señor Oscuro), mage o archer
	var dk := true
	var dl := false
	var skills: Array = []       # ids de sus tres habilidades
	var tree := {}               # nodos del árbol aprendidos: id → rango
	var alloc := {"dmg": 0, "hp": 0, "agi": 0}   # puntos de nivel repartidos
	var upg: Array = []
	var mana := 0.0
	var no_mana_t := -9.0
	# acción con animación propia (arquero y Señor Oscuro): heroAct
	var ar_a := "idle"
	var ar_t := 0.0
	var ar_max := 1.0
	var ar_fire := 0.0
	var ar_cb = null
	var ar_sk := false
	var aim_pt = null
	var pow_cd := 0.0
	var multi_q := 0
	var multi_qt := 0.0
	var rain_cnt := 0
	# Señor Oscuro: charco de sangre y pacto
	var pool_t := 0.0
	var pool_max := 1.0
	var pool_x := 0.0
	var pool_tick := 0.0
	var pool_hit := 0.0
	var pool_acc := 0.0
	var pool_fast := false
	var rn_pact_paid := 0.0
	var rn_pact_seen := false
	# mago
	var nova_x = null
	var nova_y := 0.0
	var nova_tick := 0.0
	var nova_anim := 0.0
	var spell_anim := 0.0
	var shot_cd := 0.0
	var shot_t := 0.0
	var fire_at := 0.0
	var shot_ang := 0.0
	var cast_t := 0.0
	var next_fb_crit := false
	var blink_second := false
	# caballero y Caballero de la Muerte
	var valor_heal_t := 0.0
	var drain_x = null
	var drain_y := 0.0
	var x := 0.0
	var y := 0.0
	# caída al abismo (piso de pasarelas): tiempo que queda y último sitio con suelo
	var caida_t := 0.0
	var caida_atras := false     # cae por detrás de una plataforma (no baja en pantalla)
	var seg_x := 0.0
	var seg_y := 0.0
	var hp := 1.0
	var st := {}                 # hoja de estadísticas calculada (recalc)
	var face := -PI / 2
	var flip := false
	var inv := 0.0
	var roll_t := 0.0
	var aturdido := 0.0          # segundos sin poder moverse ni atacar
	var roll_cd := 0.0
	var roll_dx := 0.0
	var roll_dy := 0.0
	var hurt_t := 0.0
	var walk_t := 0.0
	var idle_t := 0.0
	var heal_t := 0.0
	var moving := false
	var mx := 0.0                # dirección pedida este paso (_mx/_my)
	var my := 0.0
	var lunge := 0.0
	var blocking := false
	var block_t := 0.0
	var block_hit_t := 0.0
	var block_q := 0
	var parry_t := 0.0
	var parry_src = null
	var riposte := false
	var rip_target = null
	var atk_t := 0.0
	var anim := 0.0
	var seq = null               # ataque en curso (dict de ATK) o null
	var hit_done := true
	var combo_step := -1
	var combo_t := 0.0
	var chain := 0
	var chain_t := 0.0
	var best_chain := 0
	var dead := false
	var death_t := 0.0
	var dmg_dealt := 0
	var lvl := 1
	var xp := 0
	var pts := 0
	var skp := 0
	var sk := []                 # [{t, cd}] por habilidad
	var spin_t := 0.0
	var spin_hits := 0
	var cast_anim := 0.0
	var drain_tick := 0.0
	var leech_acc := 0.0
	var gold := 0
	var piso_max := 1             # el piso más hondo al que se puede ir desde Inca (se gana al vencer al jefe del anterior)
	var keys := 0
	var healed := 0
	var effects := []
	var no_pot_t := -9.0
	var pot_t := -9.0              # cuándo se bebió la última poción (recarga de Sim.POT_CD s)
	var pool_seed := 0.0
	var shield := 0.0            # escudo que absorbe daño (Segunda piel)
	var regen_acc := 0.0
	# equipo y mochila (sistema de runas): eq[hueco] = pieza o null; bag = objetos con gx, gy
	var eq := {}
	var bag: Array = []
	var rn_cls := {3: 0, 4: 0, 5: 0}   # runas de clase que ya han caído por rango (para darle las suyas)
	var rn_new := 0
	# estado de las runas
	var rn_after_roll := 0.0
	var rn_counter := 0.0
	var rn_aegis_t := 0.0
	var rn_wave := 0.0
	var rn_wave_n := 0
	var rn_veng_t := 0.0
	var rn_still := 0.0
	var rn_run := 0.0
	var rn_charged := false
	var rn_skin_cd := 0.0
	var rn_roll_hit: Array = []
	var rn_trail_t := 0.0
	var rn_hundred := false
	var rn_ramp_e = null
	var rn_ramp_n := 0
	var rn_ghost_n := 0
	var rn_spin_n := 0
	var rn_bridge := false

	func cls_key() -> String: return "dl" if dl else ("dk" if dk else cls)

	func dmg() -> float: return st.dmg
	func spd() -> float: return st.spd
	func max_hp() -> int: return int(st.maxHp)
	func crit() -> float: return st.crit
	func range_() -> float: return st.range
	func atk_cd() -> float: return st.atkCd

class Enemy extends RefCounted:
	var type := "knight"
	var b := 0                   # color del pecho (0 azul, 1 verde, 2 rojo, 3 negro y oro)
	var x := 0.0
	var y := 0.0
	var caida_t := 0.0           # cayendo al abismo (piso de pasarelas)
	var caida_atras := false
	var seg_x := 0.0
	var seg_y := 0.0
	var state := "idle"
	var hp := 1.0
	var max_hp := 1.0
	var ghost := 1.0
	var spd := 76.0
	var dmg := 1.0
	var xp := 0
	var reach := 20.0
	var wind_t := .34
	var score := 10
	var thrower := false
	var armor := false
	var name := ""
	var title := ""
	var act := ""                # "" (nada), wind, strike, guard, repo, dodge, throw
	var act_t := 0.0
	var cool := .3
	var hurt_t := 0.0
	var flash := 0.0
	var vx := 0.0
	var vy := 0.0
	var flip := false
	var walk_t := 0.0
	var moving := false
	var has_sword := true
	var throw_cd := 1.0
	var catch_t := 0.0
	var seed := 0.0
	var tang := 1.0
	var rare := false
	# élites y jefes de la vista 3D (Sim._dar_poder, Sim._jefe_piso)
	var poder := ""              # "rapido", "escudo", "explota", "invoca"
	var escudo := 0.0            # vida del escudo de daño
	var escudo_max := 0.0
	var escudo_t := 0.0          # tiempo sin recibir golpes (a los 5 s se recarga)
	var invoca_t := 0.0
	var invocador: Object = null # quién lo ha invocado
	var jefe := false            # jefe del piso: guarda la escalera
	var reto := false            # sale en una oleada del reto de la sala
	var jefe_visto := false
	var jefe_mitad := false      # ya llamó a sus siervos (al 50 % de vida)
	var onda_t := 0.0
	var am := 1.0
	var dealt := 0.0
	var los := false
	var clear := false
	var ambush := false
	var ambush_hit := false
	var face := 0.0
	var burst_t := 0.0
	var guard_cd := 1.0
	var flank_cd := 0.0
	var los_t := 0.0
	var idle_t := 0.0
	var wake_t := 0.0
	var combo := 0
	var hit_done := true
	var dying := 0.0
	var die_a := 0.0
	var dead := false
	var no_corpse := false
	var wall := false
	var wall_t := 0.0
	var wall_far := 0.0
	var repo_dir := 1.0
	var dodge_a := 0.0
	var frozen := 0.0
	var back_t := -9.0
	var hit_count := 0
	var last_hit := -9.0
	var guard_chest := false
	var pool_seed := 0.0
	# campeón: tajo con cuña, embestida y furia (champAI)
	var cs := ""                 # "", slash, aim, charge, tired
	var cs_t := 0.0
	var cs_w := 0.0
	var cs_left := 0
	var cs_seen := -1.0
	var atk_a := 0.0
	var c_mk = null              # marca de la cuña (dict de Sim.marks)
	var ch_mk = null             # marca de la línea de embestida
	var ch_cd := -1.0
	var rage := false
	var ch0 := Vector2.ZERO
	var ch1 := Vector2.ZERO
	var ch_hit := false
	var tired_t := 0.0
	# héroes renegados (hhAI): mage, archer, dk, dl o minion (esbirro del Caballero de la Muerte)
	var hero := ""
	var elite := false
	var cd_a := 0.0
	var cd_b := 0.0
	var act_max := 1.0
	var aim_a := 0.0
	var rise := 0.0
	var master = null
	var drain_t := 0.0
	var drain_tick := 0.0
	var pool_t := 0.0
	var pool_hp := 0.0
	var pooled := false
	var cloud_at := Vector2.ZERO
	var blink_t := 0.0
	# monstruos con hoja propia (registro ENEMIES de la web) y jefes
	var mon := ""
	var mon_dodge := 0.0
	var mon_hurt := 0.0
	var dash_cd := 0.0
	var dodge_t := 0.0
	var bz := 0.0                # altura sobre el suelo (picado del Ángel)
	var cuerpo := 0.0            # radio del cuerpo de los monstruos grandes (golpes y empuje)
	var ms := {}                 # estado de sus habilidades (giro, tirón, embestidas…)
	var se_room := -1            # sala sellada del Soul Eater
	var sealed := false
	var imp := false             # diablillo del Demon Overseer
	var boss := ""
	var bs := ""                 # estado del jefe: intro, chase, combo, dive, feathers, heal, recover, dash, stun, roar
	var b_phase := 1
	var bstun := 0.0
	var boss_air := false
	var boss_shield := false
	var chan_dmg := 0.0
	var arena := {}
	var arena_on := false
	# cofres y runas
	var mimic := false
	# enemigos que aprenden (Aprendizaje): puesto fijo por piso, táctica del combate y su título
	var puesto := ""             # "piso-n" (p. ej. "2-37"); "" = sin puesto (refuerzos, siervos, oleadas)
	var apr_clave := ""          # memoria compartida: "tipo/papel" (p. ej. "esqueleto/esbirro")
	var apr_lider: Object = null # élite o jefe de su sala (para la táctica «escolta»)
	var tactica := ""            # táctica de este combate ("" = aún no ha empezado)
	var apr_activo := false      # combate en curso (despierto)
	var apr_t0 := 0.0
	var apr_dealt0 := 0.0
	var apr_ult := 0.0           # último golpe empezado (para no quedarse esperando para siempre)
	var apr_ang := 0.0           # «rodear»: ángulo de su hueco alrededor del héroe
	var apr_titulo := ""         # "Experto", "Asesino" o ""
	var en_arena := false        # sale en la sala del aprendizaje del piso de prueba
	var burn_t := 0.0
	var burn_d := 0.0
	var burn_tick := 0.0
	var rn_slow_t := 0.0
	var rn_slow_n := 0
	var rn_bleed: Array = []
	var rn_bleed_t := 0.0
	var rn_pois_t := 0.0
	var rn_pois_d := 0.0
	var rn_disarm := 0.0
	var rn_no_block := 0.0
	var rn_winter_cd := 0.0
	var rn_terror := false
	# efectos de las habilidades del héroe
	var flee_t := 0.0            # «Grito de guerra»: huye
	var contagion := false       # «Contagio»: al acabar el aturdimiento lo pasa a los de al lado
	var frz_dur := 0.0

class Ally extends RefCounted:
	var x := 0.0
	var y := 0.0
	var face := 0.0
	var t := 15.0
	var max_t := 15.0
	var rise := .6
	var cool := .3
	var act := ""
	var act_t := 0.0
	var walk_t := 0.0
	var idle_t := 0.0
	var moving := false
	var hit_done := true
	var seed := 0.0
	var dead := false
	var goal = null              # {x, y} o null
	var arrived := false
	var los := false
	var los_t := 0.0

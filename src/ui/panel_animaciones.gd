class_name PanelAnimaciones
extends PanelContainer
## Panel de animaciones (F5 en el piso de prueba; pensado para la sala «Animaciones»).
## Eliges la skin del héroe (esqueleto o Maga) y pasas por todas sus animaciones: la elegida se repite sin parar.
## «Normal» devuelve el héroe a sus animaciones de siempre.

var actores: Actores3D
var _skins: OptionButton
var _lista: ItemList
const SKINS := [["Esqueleto", "esqueleto"], ["Maga", "maga"]]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -320
	offset_right = -16
	offset_top = 110
	custom_minimum_size = Vector2(300, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiArte.estilo_panel(12))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	var t := Label.new()
	t.text = "Animaciones · F5 cierra"
	t.add_theme_font_override("font", Fonts.px(500))
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", Color8(233, 207, 138))
	col.add_child(t)
	_skins = OptionButton.new()
	for s in SKINS:
		_skins.add_item(s[0])
	_skins.item_selected.connect(func(i): _poner_skin(SKINS[i][1]))
	col.add_child(_skins)
	_lista = ItemList.new()
	_lista.custom_minimum_size = Vector2(0, 360)
	_lista.item_selected.connect(_elegir)
	col.add_child(_lista)
	var normal := Button.new()
	normal.text = "Normal (sus animaciones de siempre)"
	normal.pressed.connect(func():
		actores.anim_forzada = ""
		_lista.deselect_all())
	col.add_child(normal)

func refrescar() -> void:
	if actores == null:
		return
	var id := actores._heroe_de
	for i in SKINS.size():
		if SKINS[i][1] == id:
			_skins.select(i)
	_lista.clear()
	var m := actores._modelo_heroe
	if m == null or m.anim == null:
		return
	var nombres := Array(m.anim.get_animation_list())
	nombres.sort()
	for n in nombres:
		if n != "RESET":
			_lista.add_item(n)
			if n == actores.anim_forzada:
				_lista.select(_lista.item_count - 1)

func _poner_skin(id: String) -> void:
	actores.cambiar_skin(id)
	refrescar()

func _elegir(i: int) -> void:
	actores.anim_forzada = _lista.get_item_text(i)

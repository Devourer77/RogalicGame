class_name HubHud
extends CanvasLayer
# Интерфейс хаба поверх 3D: портрет героя и Отзвуки, подсказка над точкой, реплики героя,
# строка управления. Панели точек открываются внутри (layer выше 3D, ниже ничего нет).

signal menu_requested   # нажали «В меню»

var panel_root: Control         # сюда хаб кладёт панели точек

var _hero_icon: TextureRect
var _hero_name: Label
var _echo_label: Label
var _prompt: PanelContainer
var _prompt_label: Label
var _say_label: Label
var _say_tween: Tween
var _controls: Label
var _fade: ColorRect


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Тема игры не проходит сквозь CanvasLayer — ставим её сами (как в battle_hud.gd)
	root.theme = UiKit.theme()
	add_child(root)

	# Слева сверху: герой и Отзвуки
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.PANEL, 0.85), UiKit.LINE, 1, 9, 12, 8))
	top.position = Vector2(16, 16)
	root.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	top.add_child(top_row)
	_hero_icon = UiKit.icon_rect("star", 30, UiKit.TEXT)
	top_row.add_child(_hero_icon)
	_hero_name = UiKit.make_label("", 17, UiKit.TEXT, true)
	top_row.add_child(_hero_name)
	var echo_chip: HBoxContainer = UiKit.chip("echo", "", UiKit.ECHO, "Отзвуки: память о пройденном пути.", 20, 24)
	_echo_label = UiKit.make_label("0", 20, UiKit.ECHO, true)
	echo_chip.add_child(_echo_label)
	top_row.add_child(echo_chip)

	# Справа сверху: в меню
	var menu: Button = UiKit.make_button("В меню", func() -> void: menu_requested.emit())
	menu.custom_minimum_size = Vector2(110, 36)
	menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	root.add_child(menu)

	# Подсказка над точкой
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", UiKit.box(Color(0.04, 0.055, 0.055, 0.92), UiKit.BRASS_DARK, 1, 7, 10, 5))
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label = UiKit.make_label("", 16, UiKit.TEXT, true)
	_prompt.add_child(_prompt_label)
	root.add_child(_prompt)

	# Реплика героя (внизу) и строка управления
	_say_label = UiKit.make_label("", 18, UiKit.TEXT)
	_say_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_say_label.custom_minimum_size.x = 720
	_say_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_say_label.add_theme_constant_override("outline_size", 6)
	_say_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 70)
	_say_label.modulate.a = 0.0
	root.add_child(_say_label)
	_controls = UiKit.make_label("WASD — идти   ·   E — действие   ·   Tab — сменить героя   ·   Q / R — повернуть камеру   ·   колесо — зум", 14, UiKit.TEXT_DIM)
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
	_controls.visible = Meta.history.size() < 3   # после трёх забегов подсказка не нужна
	root.add_child(_controls)

	panel_root = Control.new()
	panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel_root)

	# Затемнение при пробуждении
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)

	Meta.changed.connect(_refresh_echoes)
	_refresh_echoes()


func _refresh_echoes() -> void:
	_echo_label.text = str(Meta.echoes)


func set_hero(hero: HeroData) -> void:
	_hero_name.text = hero.title
	_hero_icon.texture = UiKit.icon(hero.id if UiKit.has_icon(hero.id) else "star")
	_hero_icon.modulate = hero.color.lightened(0.4)


## Показать подсказку в точке экрана. dim — тусклая (герой не тот).
func show_prompt(text: String, screen_pos: Vector2, dim: bool) -> void:
	_prompt.visible = true
	_prompt_label.text = text
	_prompt_label.add_theme_color_override("font_color", UiKit.TEXT_DIM if dim else UiKit.TEXT)
	_prompt.reset_size()
	_prompt.position = screen_pos - Vector2(_prompt.size.x / 2.0, _prompt.size.y + 8.0)


func hide_prompt() -> void:
	_prompt.visible = false


## Реплика героя на 3 секунды.
func say(text: String) -> void:
	_say_label.text = text
	if _say_tween != null and _say_tween.is_valid():
		_say_tween.kill()
	_say_label.modulate.a = 1.0
	_say_tween = create_tween()
	_say_tween.tween_interval(3.0)
	_say_tween.tween_property(_say_label, "modulate:a", 0.0, 0.6)


## Проявить мир из темноты (пробуждение у колокола).
func fade_in(duration: float = 1.4) -> void:
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, duration)

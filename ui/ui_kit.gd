class_name UiKit
extends RefCounted
# Общий «набор для интерфейса»: цвета, шрифты, иконки и готовые детали
# (панель, кнопка, значок с числом, полоса здоровья), из которых собраны все экраны.
# Хочешь поменять цвет латуни или шрифт заголовков во всей игре — меняй здесь.

# ---------- Палитра (по мир.md: холодные тёмные тона, латунь Стражи, бирюза Раскола) ----------
const BG_COLOR := Color(0.05, 0.068, 0.068)          # фон экранов
const BG_GLOW := Color(0.105, 0.15, 0.14)            # светлое пятно в центре фона
const PANEL := Color(0.075, 0.1, 0.1, 0.93)          # панели поверх боя
const PANEL_LIGHT := Color(0.125, 0.16, 0.158)       # кнопки, плашки
const LINE := Color(0.25, 0.32, 0.31)                # тонкие рамки
const BRASS := Color(0.84, 0.67, 0.34)               # латунь: выбранное, важное
const BRASS_DARK := Color(0.4, 0.31, 0.15)
const TEXT := Color(0.88, 0.9, 0.86)
const TEXT_DIM := Color(0.6, 0.67, 0.64)
const RIFT := Color(0.37, 0.92, 0.83)                # бирюза Раскола
const HP := Color(0.47, 0.8, 0.44)                   # здоровье героев
const HP_ENEMY := Color(0.86, 0.33, 0.36)            # здоровье врагов
const BLOCK := Color(0.66, 0.8, 0.94)
const MANA := Color(0.36, 0.6, 1.0)
const MANA_CHEAP := Color(0.3, 0.82, 0.55)
const GOLD := Color(0.96, 0.8, 0.36)
const THREAT := Color(1.0, 0.36, 0.33)               # красный — только про угрозу
const RAGE := Color(1.0, 0.58, 0.3)
const MOMENTUM := Color(1.0, 0.74, 0.3)
const CHARGE := Color(0.72, 0.62, 1.0)
const ECHO := Color(1.0, 0.93, 0.74)                  # Отзвуки: свечной белый (валюта хаба)

const ICON_DIR: String = "res://assets/icons/"
const FONT_TITLE_PATH: String = "res://assets/fonts/AlegreyaSC-Bold.ttf"

static var _theme: Theme
static var _font_title: FontVariation
static var _font_bold: FontVariation
static var _icons: Dictionary[String, Texture2D] = {}
static var _bg_texture: GradientTexture2D


# ---------- Шрифты ----------

# Шрифт заголовков (Alegreya SC). lnum — «ровные» цифры одной высоты.
static func font_title() -> Font:
	if _font_title == null:
		_font_title = FontVariation.new()
		# load, а не preload: так скрипт не ломается, если Godot ещё не успел импортировать шрифт
		_font_title.base_font = load(FONT_TITLE_PATH) if ResourceLoader.exists(FONT_TITLE_PATH) else ThemeDB.fallback_font
		_font_title.opentype_features = {"lnum": 1}
	return _font_title


# Жирный вариант обычного шрифта — для чисел и названий
static func font_bold() -> Font:
	if _font_bold == null:
		_font_bold = FontVariation.new()
		_font_bold.base_font = ThemeDB.fallback_font
		_font_bold.variation_embolden = 0.7
	return _font_bold


# ---------- Тема: как по умолчанию выглядят кнопки, подсказки, поля ввода ----------

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)

	t.set_stylebox("normal", "Button", box(PANEL_LIGHT, LINE, 1, 7, 12, 7))
	t.set_stylebox("hover", "Button", box(PANEL_LIGHT.lightened(0.07), BRASS, 2, 7, 12, 7))
	t.set_stylebox("pressed", "Button", box(PANEL_LIGHT.darkened(0.25), BRASS, 2, 7, 12, 7))
	t.set_stylebox("disabled", "Button", box(Color(PANEL_LIGHT, 0.5), LINE.darkened(0.3), 1, 7, 12, 7))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", BRASS.lightened(0.3))
	t.set_color("font_disabled_color", "Button", TEXT_DIM.darkened(0.35))
	t.set_color("icon_normal_color", "Button", TEXT)
	t.set_color("icon_hover_color", "Button", Color.WHITE)
	t.set_color("icon_pressed_color", "Button", BRASS.lightened(0.3))
	t.set_color("icon_disabled_color", "Button", TEXT_DIM.darkened(0.35))
	t.set_constant("h_separation", "Button", 8)
	t.set_constant("icon_max_width", "Button", 22)

	t.set_stylebox("normal", "LineEdit", box(Color(0.04, 0.055, 0.055), LINE, 1, 7, 12, 7))
	t.set_stylebox("focus", "LineEdit", box(Color(0.04, 0.055, 0.055), BRASS, 2, 7, 12, 7))
	t.set_color("font_placeholder_color", "LineEdit", TEXT_DIM.darkened(0.2))

	t.set_stylebox("panel", "PanelContainer", box(PANEL, LINE, 1, 9, 12, 10))
	t.set_stylebox("panel", "TooltipPanel", box(Color(0.04, 0.055, 0.055, 0.97), BRASS_DARK, 1, 6, 10, 7))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 14)

	t.set_stylebox("background", "ProgressBar", box(Color(0.02, 0.03, 0.03, 0.9), Color(0, 0, 0, 0.8), 1, 4, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(HP, Color(0, 0, 0, 0), 0, 3, 0, 0))
	_theme = t
	return t


# Включает тему для всей игры. Зовётся один раз из Run (autoload) при запуске.
static func apply_theme(tree: SceneTree) -> void:
	tree.root.theme = theme()


# Прямоугольник со скруглением и рамкой — основа всех панелей и кнопок.
# margin_x / margin_y — отступ содержимого от краёв.
static func box(bg: Color, border: Color, border_width: int = 1, radius: int = 8,
		margin_x: int = 10, margin_y: int = 8) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_width)
	b.set_corner_radius_all(radius)
	b.content_margin_left = margin_x
	b.content_margin_right = margin_x
	b.content_margin_top = margin_y
	b.content_margin_bottom = margin_y
	b.anti_aliasing = true
	return b


# ---------- Иконки ----------

# Иконка по имени файла из assets/icons (без расширения). Иконки белые — цвет задаётся при показе.
# Подойдёт и .svg, и .png: положи свой файл с тем же именем — игра возьмёт его.
# Делаем уменьшенные копии (mipmaps), чтобы мелкие значки не «рябили».
static func icon(icon_name: String) -> Texture2D:
	if _icons.has(icon_name):
		return _icons[icon_name]
	var path: String = _icon_path(icon_name)
	var tex: Texture2D = null
	if path != "":
		var image: Image = (load(path) as Texture2D).get_image()
		if image.is_compressed():
			image.decompress()
		image.generate_mipmaps()
		tex = ImageTexture.create_from_image(image)
	else:
		push_warning("Нет иконки: %s%s.svg" % [ICON_DIR, icon_name])
	_icons[icon_name] = tex
	return tex


static func has_icon(icon_name: String) -> bool:
	return _icon_path(icon_name) != ""


# Путь к файлу иконки: сначала ищем .png (свой рисунок поверх набора), потом .svg. Пусто — такой иконки нет.
static func _icon_path(icon_name: String) -> String:
	for extension: String in [".png", ".svg"]:
		if ResourceLoader.exists(ICON_DIR + icon_name + extension):
			return ICON_DIR + icon_name + extension
	return ""


# Иконка как узел: квадрат size×size нужного цвета. Клики пропускает сквозь себя.
static func icon_rect(icon_name: String, size: float = 20.0, color: Color = TEXT) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(icon_name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.custom_minimum_size = Vector2(size, size)
	r.size = Vector2(size, size)
	r.modulate = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# ---------- Готовые детали ----------

static func make_label(text: String, font_size: int = 16, color: Color = TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font_bold())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# Заголовок шрифтом Alegreya SC, по центру
static func make_title(text: String, font_size: int = 34, color: Color = TEXT) -> Label:
	var l: Label = make_label(text, font_size, color)
	l.add_theme_font_override("font", font_title())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# Абзац по центру с переносом строк (описания событий, пояснения)
static func make_text(text: String, font_size: int = 18, color: Color = TEXT, width: float = 720.0) -> Label:
	var l: Label = make_label(text, font_size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


# Кнопка меню. icon_name — иконка слева (можно пусто), primary — главная кнопка экрана (латунная).
static func make_button(text: String, on_pressed: Callable, icon_name: String = "", primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 46)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	if icon_name != "":
		b.icon = icon(icon_name)
	if primary:
		style_primary(b)
	Sfx.bind_button(b)
	b.pressed.connect(on_pressed)
	return b


# Латунная «главная» кнопка
static func style_primary(b: Button) -> void:
	b.add_theme_stylebox_override("normal", box(BRASS_DARK, BRASS, 2, 7, 12, 7))
	b.add_theme_stylebox_override("hover", box(BRASS_DARK.lightened(0.12), BRASS.lightened(0.25), 2, 7, 12, 7))
	b.add_theme_stylebox_override("pressed", box(BRASS_DARK.darkened(0.2), BRASS, 2, 7, 12, 7))
	b.add_theme_font_override("font", font_bold())
	b.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	b.add_theme_color_override("icon_normal_color", Color(1.0, 0.95, 0.82))


static func make_panel(bg: Color = PANEL, border: Color = LINE, border_width: int = 1) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box(bg, border, border_width, 9, 12, 10))
	return panel


# Значок с числом или словом (например, щит и «4»). Наведи — всплывёт подсказка hint.
static func chip(icon_name: String, text: String, color: Color = TEXT, hint: String = "",
		font_size: int = 15, icon_size: float = 18.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(icon_rect(icon_name, icon_size, color))
	if text != "":
		var l: Label = make_label(text, font_size, color, true)
		row.add_child(l)
	if hint != "":
		row.tooltip_text = hint
		row.mouse_filter = Control.MOUSE_FILTER_PASS   # подсказка есть, но клик уходит дальше (в кнопку под значком)
	else:
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


# Полоса (здоровье и т.п.) с подписью «30 / 45» поверх
static func make_bar(value: int, max_value: int, color: Color, size: Vector2 = Vector2(160, 18),
		with_text: bool = true) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = maxi(max_value, 1)
	bar.value = clampi(value, 0, max_value)
	bar.show_percentage = false
	bar.custom_minimum_size = size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("fill", box(color, Color(0, 0, 0, 0), 0, 3, 0, 0))
	if with_text:
		var l: Label = make_label("%d / %d" % [value, max_value], int(size.y) - 5, Color.WHITE, true)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("outline_size", 4)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bar.add_child(l)
	return bar


# Тонкая латунная черта-разделитель
static func make_divider(width: float = 260.0) -> Control:
	var line := ColorRect.new()
	line.color = Color(BRASS, 0.55)
	line.custom_minimum_size = Vector2(width, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


# ---------- Экраны-меню ----------

# Тёмный фон со светлым пятном в центре + колонка по центру. Возвращает колонку,
# в которую экран добавляет свои надписи и кнопки.
static func make_screen(parent: Control) -> VBoxContainer:
	parent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _bg_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, BG_GLOW)
		gradient.set_color(1, BG_COLOR)
		_bg_texture = GradientTexture2D.new()
		_bg_texture.gradient = gradient
		_bg_texture.fill = GradientTexture2D.FILL_RADIAL
		_bg_texture.fill_from = Vector2(0.5, 0.42)
		_bg_texture.fill_to = Vector2(1.05, 0.42)
		_bg_texture.width = 256
		_bg_texture.height = 256
	var bg := TextureRect.new()
	bg.texture = _bg_texture
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	return column


# Полоса отряда для экранов между боями: портрет, здоровье и колода каждого героя, золото.
# on_deck — что делать по нажатию на «колоду» героя (обычно показать его карты); можно не задавать.
static func party_bar(on_deck: Callable = Callable()) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	for rh in Run.party:
		var panel: PanelContainer = make_panel(PANEL, rh.data.color.darkened(0.35))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		panel.add_child(line)
		line.add_child(icon_rect(rh.data.id if has_icon(rh.data.id) else "heart", 30, rh.data.color.lightened(0.35)))
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		info.add_child(make_label(rh.data.title, 15, TEXT, true))
		info.add_child(make_bar(rh.hp, rh.data.max_hp, HP, Vector2(150, 17)))
		line.add_child(info)
		var deck := Button.new()
		deck.icon = icon("deck")
		deck.text = str(rh.deck.size())
		deck.focus_mode = Control.FOCUS_NONE
		deck.tooltip_text = "Колода героя «%s»:\n%s" % [rh.data.title, Run.deck_summary(rh)]
		if on_deck.is_valid():
			Sfx.bind_button(deck)
			deck.pressed.connect(on_deck.bind(rh))
			deck.tooltip_text += "\n\nНажми, чтобы посмотреть карты"
		line.add_child(deck)
		row.add_child(panel)
	var gold_panel: PanelContainer = make_panel(PANEL, BRASS_DARK)
	var gold: HBoxContainer = chip("coin", str(Run.gold), GOLD, "Золото: тратится в лавке", 20, 24)
	gold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gold_panel.add_child(gold)
	row.add_child(gold_panel)
	return row


# Строка «HP героев / золото» текстом (осталась для отладки и старых мест)
static func run_status() -> String:
	var parts: PackedStringArray = []
	for rh in Run.party:
		parts.append("%s %d/%d HP (%d карт)" % [rh.data.title, rh.hp, rh.data.max_hp, rh.deck.size()])
	parts.append("Золото: %d" % Run.gold)
	return "     ".join(parts)


static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

extends Control
# Карта забега (тз-карта-пути.md): старая карта на пергаменте, рисунок Gemini (assets/textures/map/).
# Две ветки акта (в акте 1 слева Гнилые топи, справа Густые леса; названия — Run.branch_titles()), между ними овраг с мостом — тропа-переход на ряду Run.CROSS_ROW.
# Тропы извилистые, нарисованы «чернилами» — пунктиром следов. Туман войны: что за точка, видно на
# Run.FOG_SIGHT рядов вперёд; дальше — плывущий туман и размытые силуэты. Босс — корона в тумане,
# его имя открывается, когда до него остаётся FOG_SIGHT рядов.
# Наведи мышь на открытую точку — над ней поднимется карточка (MapCard): место, тип, опасность.

const AREA_RATIO: float = 1024.0 / 572.0     # пропорции рисунка карты
const RESERVED_HEIGHT: float = 178.0         # над и под картой: полоса отряда, заголовок, памятка
const ROMAN: Array[String] = ["", "I", "II", "III", "IV"]
const NODE_SIZE: float = 34.0
const BOSS_SIZE: float = 46.0
const INK := Color(0.8, 0.72, 0.54, 0.78)       # «следы» троп: светлая выцветшая охра (фон карты тёмный)
const INK_SHADOW := Color(0.04, 0.03, 0.02, 0.6) # тёмная подложка под следом — читается и на светлой траве
const INK_FOG := Color(0.8, 0.72, 0.54, 0.3)    # тропы в тумане — бледнее
const STEP_DOT: float = 8.0                    # шаг «следов» на тропе, точек экрана
const GLOW := Color(0.95, 0.86, 0.6)            # свет под значком
const BRANCH_TEXT: Array[Color] = [Color(0.72, 0.82, 0.78), Color(0.74, 0.86, 0.66)]

const HINTS: Dictionary[int, String] = {
	MapNode.Type.BATTLE: "Бой: враги и награда — золото и карта на выбор.",
	MapNode.Type.ELITE: "Элита: сильный враг и его свита. Награда — реликвия.",
	MapNode.Type.EVENT: "Событие: выбор — бывает с риском, бывает и бой.",
	MapNode.Type.SHOP: "Лавка: купить карту или убрать лишнюю из колоды.",
	MapNode.Type.REST: "Привал: оба героя лечатся.",
	MapNode.Type.BOSS: "Босс: последний бой акта.",
	MapNode.Type.LAIR: "Логово духа: победи духа — и он присоединится к герою.",
}

var AREA_SIZE: Vector2 = Vector2(1000, 560)   # рисунок карты на экране — по размеру окна (в _ready)
var _area: Control                    # рисунок карты: фон, тропы, точки, туман, карточка
var _ink: Control                     # слой троп
var _fog: ColorRect
var _available: Array[MapNode] = []
var _card: MapCard = null
var _time: float = 0.0


func _ready() -> void:
	Hints.offer(self, "map")   # при первом заходе — подсказка слева внизу (scripts/tutorial/hints.gd)
	var vp: Vector2 = get_viewport_rect().size
	var h: float = vp.y - RESERVED_HEIGHT
	AREA_SIZE = Vector2(minf(h * AREA_RATIO, vp.x - 40.0), 0.0)
	AREA_SIZE.y = AREA_SIZE.x / AREA_RATIO
	var column: VBoxContainer = UiKit.make_screen(self)
	column.add_theme_constant_override("separation", 6)
	column.add_child(UiKit.party_bar(_show_deck))

	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 14)
	head.add_child(UiKit.make_title(_area_title(), 28, UiKit.BRASS.lightened(0.2)))
	var seed_label: Label = UiKit.make_label("акт %s · %s  ·  Звон %d  ·  сид %d" % [ROMAN[Run.act], Run.act_data().title, Run.bell, Run.seed_value], 14, UiKit.TEXT_DIM)
	seed_label.size_flags_vertical = Control.SIZE_SHRINK_END
	seed_label.tooltip_text = "Сид забега: введи его в главном меню, чтобы повторить этот же забег."
	seed_label.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_child(seed_label)
	column.add_child(head)

	_area = Control.new()
	_area.custom_minimum_size = AREA_SIZE
	_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_area.clip_contents = true
	column.add_child(_area)

	var bg := TextureRect.new()
	bg.texture = load(Run.map_background()) as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = AREA_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.add_child(bg)

	_ink = Control.new()
	_ink.size = AREA_SIZE
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.draw.connect(_draw_trails)
	_area.add_child(_ink)

	_available = Run.available_nodes()
	for branch in [MapNode.BOG, MapNode.FOREST]:
		_area.add_child(_branch_label(branch))
	for n in Run.map:
		_area.add_child(_make_node(n))

	_fog = ColorRect.new()
	_fog.size = AREA_SIZE
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/map_fog.gdshader") as Shader
	mat.set_shader_parameter("fog_edge", _fog_edge())
	_fog.material = mat
	_area.add_child(_fog)

	# Памятка: что значит каждый значок
	var legend := HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 20)
	for type: int in [MapNode.Type.BATTLE, MapNode.Type.ELITE, MapNode.Type.LAIR, MapNode.Type.EVENT, MapNode.Type.SHOP, MapNode.Type.REST, MapNode.Type.BOSS]:
		var probe := MapNode.new()
		probe.type = type as MapNode.Type
		legend.add_child(UiKit.chip(MapCard.icon_for(probe), HINTS[type].get_slice(":", 0), UiKit.BRASS.lightened(0.25), HINTS[type], 14, 20))
	var fog_chip: Control = UiKit.chip("map_event", "Туман: видно на %d ряда вперёд" % (Run.FOG_SIGHT + Run.fog_bonus), UiKit.TEXT_DIM,
			"Что за точка, видно только вблизи. Дорожки видны всегда.", 14, 20)
	legend.add_child(fog_chip)
	column.add_child(legend)
	# «Знакомая тропа» (улучшение из хаба): один раз перебросить карту до первого шага
	if Run.can_reroll_map():
		var reroll: Button = UiKit.make_button("Перебросить путь (один раз)", Run.reroll_map, "star")
		reroll.tooltip_text = "Карта пути создастся заново. Больше в этом забеге так сделать нельзя."
		column.add_child(reroll)


func _process(delta: float) -> void:
	_time += delta


# ---------- Точки ----------

# Точка: значок-штамп латунью со светом под ним. В тумане — тусклый кружок; босс — корона без имени.
# Куда можно пойти — свет ярче и значок «дышит»; где отряд — тёплый фонарь.
func _make_node(n: MapNode) -> Control:
	var revealed: bool = Run.node_revealed(n)
	var is_available: bool = _available.has(n)
	var is_current: bool = n == Run.current
	var size: float = BOSS_SIZE if n.type == MapNode.Type.BOSS else NODE_SIZE
	var b := Button.new()
	b.size = Vector2(size, size) * 1.5
	b.position = _center(n) - b.size / 2.0
	b.pivot_offset = b.size / 2.0
	b.disabled = not is_available
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	var empty := StyleBoxEmpty.new()
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, empty)

	var glow_color: Color = GLOW
	var glow_alpha: float = 0.32
	if is_available:
		glow_alpha = 0.6
	elif is_current:
		glow_color = Color(1.0, 0.72, 0.38)
		glow_alpha = 0.75
	elif n.visited:
		glow_alpha = 0.12
	if not revealed:
		glow_alpha = 0.0
	if glow_alpha > 0.0:
		var glow := TextureRect.new()
		glow.texture = _glow_texture()
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.size = b.size
		glow.modulate = Color(glow_color, glow_alpha)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(glow)

	var icon_color: Color = UiKit.BRASS.lightened(0.15)
	if n.visited and not is_current:
		icon_color = Color(UiKit.BRASS.darkened(0.2), 0.6)
	var icon_name: String = MapCard.icon_for(n)
	if not revealed:
		icon_name = "map_boss" if n.type == MapNode.Type.BOSS else "map_event"
		icon_color = Color(0.75, 0.75, 0.7, 0.35)   # в тумане: только силуэт
	var pic: TextureRect = UiKit.icon_rect(icon_name, size * (0.9 if revealed else 0.7), icon_color)
	pic.position = (b.size - pic.size) / 2.0
	b.add_child(pic)
	if is_current:
		var ring := Panel.new()
		ring.size = Vector2(size, size) * 1.15
		ring.position = (b.size - ring.size) / 2.0
		ring.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0), Color(1.0, 0.78, 0.45, 0.9), 2, int(ring.size.x / 2.0)))
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ring)

	b.tooltip_text = _hint(n, revealed)
	if is_available:
		var tween: Tween = b.create_tween().set_loops()
		tween.tween_property(b, "scale", Vector2.ONE * 1.08, 0.7).set_trans(Tween.TRANS_SINE)
		tween.tween_property(b, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
	b.pressed.connect(Run.enter_node.bind(n))
	if revealed:
		b.mouse_entered.connect(_show_card.bind(n))
		b.mouse_exited.connect(_hide_card.bind(n))
	Sfx.bind_button(b, "step")
	return b


func _hint(n: MapNode, revealed: bool) -> String:
	if not revealed:
		if n.type == MapNode.Type.BOSS:
			if Run.bosses_differ():
				return "В конце пути ждёт хозяин этих мест — у каждой ветки свой. Кто — откроется, когда подойдёшь ближе."
			return "В конце пути ждёт хозяин этих мест. Кто — откроется, когда подойдёшь ближе.\nПодсказки — знаки на первых аренах."
		return "Туман: что здесь — не видно. Подойди ближе."
	var text: String = HINTS[n.type]
	if n.type == MapNode.Type.BOSS and Run.run_boss != null:
		text = "Босс: %s — последний бой акта.\n%s" % [Run.run_boss.title, _boss_hint(Run.run_boss)]
		if Run.bosses_differ():   # босс зависит от ветки — говорим, кто ждёт на другой
			var other: int = MapNode.FOREST if Run.current_branch() == MapNode.BOG else MapNode.BOG
			text += "\nНа ветке «%s» ждёт другой: %s." % [Run.branch_titles()[other], Run.boss_for_branch(other).title]
	if n.branch != MapNode.COMMON:
		text += "\n%s." % Run.branch_titles()[n.branch]
		if _crosses_from(n):
			text += "\nОтсюда тропа через мост в другую ветку."
	if n == Run.current:
		text += "\nВы здесь."
	elif n.visited:
		text += "\nУже пройдено."
	return text


# Мягкое пятно света под значком (одна текстура на всех)
static var _glow_tex: Texture2D = null

static func _glow_texture() -> Texture2D:
	if _glow_tex == null:
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		grad.add_point(0.45, Color(1, 1, 1, 0.35))
		g.gradient = grad
		g.width = 128
		g.height = 128
		_glow_tex = g
	return _glow_tex


# Центр точки на рисунке
func _center(n: MapNode) -> Vector2:
	return Vector2(n.pos.x * AREA_SIZE.x, n.pos.y * AREA_SIZE.y)


# Граница тумана (доля высоты сверху): посередине между последним видимым рядом и следующим
func _fog_edge() -> float:
	var here: int = Run.current.row if Run.current != null else -1
	var last_seen: int = here + Run.FOG_SIGHT + Run.fog_bonus
	if last_seen >= Run.MAP_ROWS - 1:
		return 0.0   # всё видно
	var y_seen: float = _row_y(last_seen)
	var y_next: float = _row_y(last_seen + 1)
	return (y_seen + y_next) / 2.0


# Средняя высота ряда на рисунке (доля сверху)
func _row_y(row: int) -> float:
	var nodes: Array[MapNode] = Run.row_nodes(row)
	if nodes.is_empty():
		return 0.0
	var sum: float = 0.0
	for n in nodes:
		sum += n.pos.y
	return sum / nodes.size()


# ---------- Тропы ----------

# Тропы — пунктир «следов» по плавной кривой с изгибом от сида точки: пройденные — латунью,
# ближайшие шаги — светлее, остальные — чернилами; в тумане — бледнее.
func _draw_trails() -> void:
	var fog_y: float = _fog_edge() * AREA_SIZE.y
	for n in Run.map:
		for c in n.next:
			var target: MapNode = Run.find_map_node(n.row + 1, c)
			if target == null:
				continue
			var color: Color = INK
			var dot: float = 1.9
			if n.visited and target.visited:
				color = UiKit.BRASS.darkened(0.1)
				dot = 2.5
			elif n == Run.current and _available.has(target):
				color = UiKit.BRASS.lightened(0.25)
				dot = 2.4
			var a: Vector2 = _center(n)
			var b: Vector2 = _center(target)
			var seed_h: int = hash(Vector3i(n.row, n.col, c))
			var bend: float = (float(seed_h % 1000) / 1000.0 - 0.5) * 0.5   # изгиб тропы
			var dirv: Vector2 = b - a
			var perp: Vector2 = Vector2(-dirv.y, dirv.x).normalized()
			var ctrl: Vector2 = (a + b) / 2.0 + perp * dirv.length() * bend
			var bridge: Vector2 = Run.act_data().bridge_point
			if bridge != Vector2.ZERO and target.branch != MapNode.COMMON and target.branch != n.branch:
				# Переход между ветками идёт точно через мост на рисунке акта (середина кривой — в мосту)
				ctrl = bridge * AREA_SIZE * 2.0 - (a + b) / 2.0
			var length: float = dirv.length() * 1.1
			var steps: int = maxi(3, int(length / STEP_DOT))
			for i in range(1, steps):
				var t: float = float(i) / steps
				var p: Vector2 = a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
				# следы чуть в шахматном порядке, не точно по линии
				var side: float = (1.0 if i % 2 == 0 else -1.0) * 2.2
				p += perp * side
				if p.distance_to(a) < NODE_SIZE * 0.55 or p.distance_to(b) < NODE_SIZE * 0.55:
					continue
				var col: Color = color
				if p.y < fog_y and color == INK:
					col = INK_FOG
				_ink.draw_circle(p + Vector2(0.6, 0.9), dot + 1.0, Color(INK_SHADOW, INK_SHADOW.a * col.a))
				_ink.draw_circle(p, dot, col)


# Есть ли из точки тропа-переход в другую ветку
func _crosses_from(n: MapNode) -> bool:
	for c in n.next:
		var target: MapNode = Run.find_map_node(n.row + 1, c)
		if target != null and target.branch != MapNode.COMMON and target.branch != n.branch:
			return true
	return false


# ---------- Карточка ----------

func _show_card(n: MapNode) -> void:
	_hide_card(null)
	_card = MapCard.build(n)
	var c: Vector2 = _center(n)
	var pos := Vector2(c.x - _card.size.x / 2.0, c.y - _card.size.y - NODE_SIZE * 0.9)
	if pos.y < 4.0:
		pos.y = c.y + NODE_SIZE * 0.9   # у верхнего края — карточка под точкой
	pos.x = clampf(pos.x, 4.0, AREA_SIZE.x - _card.size.x - 4.0)
	_card.position = pos
	_card.modulate = Color(1, 1, 1, 0)
	_area.add_child(_card)
	var tw: Tween = _card.create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.12)


func _hide_card(_n: Variant) -> void:
	if _card != null and is_instance_valid(_card):
		_card.queue_free()
	_card = null


# ---------- Подписи ----------

# Заголовок: где отряд сейчас; до первого шага — развилка
func _area_title() -> String:
	var branch: int = Run.current_branch()
	if branch == MapNode.COMMON:
		return Run.act_data().fork_title if Run.current == null else Run.act_data().common_title
	return Run.branch_titles()[branch]


# Подпись ветки внизу её половины
func _branch_label(branch: int) -> Label:
	var label: Label = UiKit.make_label(Run.branch_titles()[branch], 19, BRANCH_TEXT[branch])
	label.add_theme_font_override("font", UiKit.font_title())
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.03))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(AREA_SIZE.x * 0.4, 30)
	label.position = Vector2((0.05 if branch == MapNode.BOG else 0.55) * AREA_SIZE.x, AREA_SIZE.y - 38.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# Одна строка о боссе для подсказки: его строка лора
func _boss_hint(enc: EncounterData) -> String:
	if enc.core.is_empty():
		return ""
	return enc.core[0].description


func _show_deck(rh: RunHero) -> void:
	var sections: Array[Dictionary] = [{"title": rh.data.title, "color": rh.data.color, "cards": rh.deck}]
	DeckOverlay.open(self, "Колода: %s" % rh.data.title, sections)

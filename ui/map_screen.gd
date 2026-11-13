extends Control
# Карта забега: ряды точек снизу вверх, наверху босс.
# Можно пойти только в точки, куда ведёт дорожка из текущей (они в латунной рамке и «дышат»).

const COL_SPACING: float = 190.0
const ROW_SPACING: float = 62.0
const NODE_SIZE: float = 52.0
const BOSS_SIZE: float = 66.0

# Для каждого типа точки: иконка, цвет кружка и подсказка
const NODE_LOOK: Dictionary[int, Array] = {
	MapNode.Type.BATTLE: ["battle", Color(0.27, 0.33, 0.37), "Бой: враги и награда — золото и карта на выбор."],
	MapNode.Type.ELITE: ["elite", Color(0.52, 0.33, 0.12), "Элита: бой с сильным врагом и его свитой."],
	MapNode.Type.EVENT: ["event", Color(0.28, 0.28, 0.55), "Событие: выбор с риском."],
	MapNode.Type.SHOP: ["shop", Color(0.47, 0.4, 0.14), "Лавка: купить карту или убрать лишнюю из колоды."],
	MapNode.Type.REST: ["rest", Color(0.2, 0.43, 0.27), "Привал: оба героя лечатся."],
	MapNode.Type.BOSS: ["boss", Color(0.5, 0.15, 0.17), "Босс: последний бой акта."],
}

var _area: Control                          # область, где рисуются точки и дорожки
var _available: Array[MapNode] = []


func _ready() -> void:
	var column: VBoxContainer = UiKit.make_screen(self)
	column.add_theme_constant_override("separation", 10)
	column.add_child(UiKit.party_bar(_show_deck))

	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 14)
	head.add_child(UiKit.make_title("Гнилые топи", 30, UiKit.BRASS.lightened(0.2)))
	var seed_label: Label = UiKit.make_label("акт I  ·  Звон %d  ·  сид %d" % [Run.bell, Run.seed_value], 14, UiKit.TEXT_DIM)
	seed_label.size_flags_vertical = Control.SIZE_SHRINK_END
	seed_label.tooltip_text = "Сид забега: введи его в главном меню, чтобы повторить этот же забег."
	seed_label.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_child(seed_label)
	column.add_child(head)

	_area = Control.new()
	_area.custom_minimum_size = Vector2(COL_SPACING * (Run.MAP_COLS - 1) + BOSS_SIZE,
			ROW_SPACING * (Run.MAP_ROWS - 1) + BOSS_SIZE)
	_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_area.draw.connect(_draw_links)   # дорожки рисуем сами в сигнале draw
	column.add_child(_area)

	_available = Run.available_nodes()
	for n in Run.map:
		_area.add_child(_make_node_button(n))

	# Памятка: что значит каждая иконка
	var legend := HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 20)
	for type: int in [MapNode.Type.BATTLE, MapNode.Type.ELITE, MapNode.Type.EVENT, MapNode.Type.SHOP, MapNode.Type.REST, MapNode.Type.BOSS]:
		var look: Array = NODE_LOOK[type]
		var title: String = (look[2] as String).get_slice(":", 0)
		legend.add_child(UiKit.chip(look[0], title, (look[1] as Color).lightened(0.55), look[2], 14, 18))
	column.add_child(legend)
	# «Знакомая тропа» (улучшение из хаба): один раз перебросить карту до первого шага
	if Run.can_reroll_map():
		var reroll: Button = UiKit.make_button("Перебросить путь (один раз)", Run.reroll_map, "star")
		reroll.tooltip_text = "Карта пути создастся заново. Больше в этом забеге так сделать нельзя."
		column.add_child(reroll)


# Круглая кнопка точки с иконкой. Куда можно пойти — латунная рамка и лёгкое «дыхание».
func _make_node_button(n: MapNode) -> Button:
	var look: Array = NODE_LOOK[n.type]
	var size: float = BOSS_SIZE if n.type == MapNode.Type.BOSS else NODE_SIZE
	var is_available: bool = _available.has(n)
	var is_current: bool = n == Run.current
	var b := Button.new()
	b.size = Vector2(size, size)
	b.position = _node_center(n) - b.size / 2.0
	b.pivot_offset = b.size / 2.0
	b.disabled = not is_available
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = look[2]
	if n.type == MapNode.Type.BOSS and Run.run_boss != null:
		b.tooltip_text = "Босс: %s — последний бой акта.\n%s" % [Run.run_boss.title, _boss_hint(Run.run_boss)]
	elif n.type == MapNode.Type.ELITE and n.row < Run.MAP_ROWS - 3:
		b.tooltip_text += "\nНеобязательная: можно обойти. Награда — реликвия на выбор."
	if is_current:
		b.tooltip_text += "\nВы здесь."
	elif n.visited:
		b.tooltip_text += "\nУже пройдено."

	var base: Color = look[1]
	var border := Color(0, 0, 0, 0.6)
	var border_width: int = 2
	if is_available:
		border = UiKit.BRASS.lightened(0.25)
		border_width = 3
	elif is_current:
		border = UiKit.RIFT
		border_width = 3
	var radius: int = int(size / 2.0)
	b.add_theme_stylebox_override("normal", UiKit.box(base, border, border_width, radius, 0, 0))
	b.add_theme_stylebox_override("hover", UiKit.box(base.lightened(0.18), Color.WHITE, 3, radius, 0, 0))
	b.add_theme_stylebox_override("pressed", UiKit.box(base.darkened(0.15), UiKit.BRASS, 3, radius, 0, 0))
	b.add_theme_stylebox_override("disabled", UiKit.box(base, border, border_width, radius, 0, 0))

	var icon_size: float = size * 0.58
	var picture: TextureRect = UiKit.icon_rect(look[0], icon_size, Color(1, 1, 1, 0.95))
	picture.position = Vector2.ONE * (size - icon_size) / 2.0
	b.add_child(picture)

	if n.type == MapNode.Type.BOSS and Run.run_boss != null:
		# Имя босса под его точкой: виден с начала забега, чтобы собирать колоду под него
		var boss_label: Label = UiKit.make_label(Run.run_boss.title, 15, UiKit.BRASS.lightened(0.3))
		boss_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		boss_label.size = Vector2(220, size)
		boss_label.position = Vector2(size + 10, 0)   # справа от точки босса
		boss_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(boss_label)

	if is_available:
		var tween: Tween = b.create_tween().set_loops()
		tween.tween_property(b, "scale", Vector2.ONE * 1.1, 0.7).set_trans(Tween.TRANS_SINE)
		tween.tween_property(b, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
	elif n.visited and not is_current:
		b.modulate = Color(1, 1, 1, 0.4)    # пройденное — бледное
	elif not is_current:
		b.modulate = Color(1, 1, 1, 0.78)   # ещё впереди — видно, но не отвлекает
	b.pressed.connect(Run.enter_node.bind(n))
	Sfx.bind_button(b, "step")
	return b


# Центр точки. Ряд 0 — внизу.
func _node_center(n: MapNode) -> Vector2:
	var cols: int = Run.row_nodes(n.row).size()
	var x_offset: float = (Run.MAP_COLS - cols) * COL_SPACING / 2.0   # одиночного босса — по центру
	var x: float = x_offset + n.col * COL_SPACING + BOSS_SIZE / 2.0
	var y: float = (Run.MAP_ROWS - 1 - n.row) * ROW_SPACING + BOSS_SIZE / 2.0
	return Vector2(x, y)


# Дорожки между точками: пройденный путь — латунный, ближайшие шаги — светлые, остальное — тусклое
func _draw_links() -> void:
	for n in Run.map:
		for c in n.next:
			var target: MapNode = Run.find_map_node(n.row + 1, c)
			if target == null:
				continue
			var color := Color(UiKit.LINE, 0.9)
			var width: float = 2.0
			if n.visited and target.visited:
				color = UiKit.BRASS
				width = 4.0
			elif n == Run.current and _available.has(target):
				color = UiKit.BRASS.lightened(0.35)
				width = 3.0
			_area.draw_line(_node_center(n), _node_center(target), color, width, true)


# Одна строка о боссе для подсказки: его строка лора из подсказки в бою
func _boss_hint(enc: EncounterData) -> String:
	if enc.core.is_empty():
		return ""
	return enc.core[0].description


func _show_deck(rh: RunHero) -> void:
	var sections: Array[Dictionary] = [{"title": rh.data.title, "color": rh.data.color, "cards": rh.deck}]
	DeckOverlay.open(self, "Колода: %s" % rh.data.title, sections)

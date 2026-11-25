class_name TurnOrderBar
extends HBoxContainer
# Полоса порядка ходов врагов — вверху по центру экрана боя.
# Карточки слева направо: кто ходит первым, вторым… В конце — «Конец раунда» (огонь, яд, подмога).
# Наведение на карточку сообщает сцене боя (сигнал enemy_hovered) — та подсвечивает врага на поле
# и показывает его путь. Наведение на врага на поле подсвечивает его карточку (highlight).
# Во время хода врагов полоса работает как очередь (set_current): текущий выделен, отыгравшие гаснут.

signal enemy_hovered(unit: BattleUnit)   # null — курсор ушёл с карточки

const CARD_WIDTH: float = 104.0       # обычная ширина карточки
const CARD_WIDTH_MIN: float = 78.0    # когда врагов много — карточки ужимаются до этой ширины
const MAX_WIDTH: float = 1180.0       # шире полоса не растёт
const SIDE_RESERVE: float = 340.0     # по краям экрана место панелей героев (слева) и журнала (справа)
const DONE_ALPHA: float = 0.35        # отыгравшие и бездействующие — бледные

var _cards: Dictionary[BattleUnit, PanelContainer] = {}   # карточка каждого врага (призванные — без ключа)
var _order: Array[BattleUnit] = []    # враги в порядке хода (для очереди)
var _highlighted: BattleUnit = null
var _current: BattleUnit = null


func _init() -> void:
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# entries — карточки врагов уже в порядке показа, каждая:
#   unit (BattleUnit или null у призванных), order (номер хода, 0 — без номера), title,
#   intent_icon, intent_value, intent_color, hp, max_hp,
#   idle (в этот ход ничего не делает — бледная), spawned (появится в этот ход).
# round_end — значки того, что случится в конце раунда: [{icon, color, hint}]
func show_order(entries: Array[Dictionary], round_end: Array[Dictionary]) -> void:
	UiKit.clear(self)
	_cards.clear()
	_order.clear()
	_current = null
	if entries.is_empty():
		visible = false
		return
	visible = true
	# Ширина карточки: сколько влезает в MAX_WIDTH (+1 — карточка «Конец раунда»)
	var count: int = entries.size() + 1
	var room: float = minf(MAX_WIDTH, get_viewport_rect().size.x - SIDE_RESERVE * 2.0)
	var width: float = clampf((room - 6.0 * count) / count, CARD_WIDTH_MIN, CARD_WIDTH)
	for entry: Dictionary in entries:
		var card: PanelContainer = _make_card(entry, width)
		add_child(card)
		var u: BattleUnit = entry.get("unit", null)
		if u != null:
			_cards[u] = card
			if not entry.get("idle", false):
				_order.append(u)
	add_child(_make_round_end(round_end, width))
	_apply_styles()


# Подсветить карточку врага (курсор на нём на поле). null — снять подсветку.
func highlight(unit: BattleUnit) -> void:
	if unit == _highlighted:
		return
	_highlighted = unit
	_apply_styles()


# Ход врагов: unit начинает ходить. Его карточка — текущая, все до него — отыгравшие.
func set_current(unit: BattleUnit) -> void:
	if not _cards.has(unit):
		return
	_current = unit
	_apply_styles()


func clear() -> void:
	UiKit.clear(self)
	_cards.clear()
	_order.clear()
	_current = null
	_highlighted = null
	visible = false


# Рамка и прозрачность карточек по состоянию: обычная / под курсором / текущая / отыгравшая
func _apply_styles() -> void:
	var current_index: int = _order.find(_current) if _current != null else -1
	for u: BattleUnit in _cards:
		var card: PanelContainer = _cards[u]
		var lit: bool = u == _highlighted or u == _current
		var border: Color = UiKit.BRASS if lit else Color(UiKit.LINE, 0.9)
		card.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.PANEL, 0.9), border, 2 if lit else 1, 7, 7, 5))
		var idx: int = _order.find(u)
		var faded: bool = idx < 0 or (current_index >= 0 and idx < current_index) or not u.is_alive()
		card.modulate.a = DONE_ALPHA if faded and not lit else 1.0


func _make_card(entry: Dictionary, width: float) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size.x = width
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var u: BattleUnit = entry.get("unit", null)
	if u != null:
		card.mouse_entered.connect(func() -> void: enemy_hovered.emit(u))
		card.mouse_exited.connect(func() -> void: enemy_hovered.emit(null))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)

	# Номер хода и имя
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 5)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	var order: int = entry.get("order", 0)
	if order > 0:
		head.add_child(UiKit.make_label(str(order), 16, UiKit.BRASS.lightened(0.2), true))
	var name_label: Label = UiKit.make_label(entry.get("title", ""), 12, UiKit.TEXT)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size.x = 20
	head.add_child(name_label)

	# Удар и здоровье
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	if entry.get("spawned", false):
		row.add_child(UiKit.make_label(Loc.t("появится"), 12, UiKit.TEXT_DIM))
		card.tooltip_text = Loc.t("Появится в этот ход врагов (призыв)")
		return card
	var icon_name: String = entry.get("intent_icon", "")
	if icon_name != "":
		var value: int = entry.get("intent_value", 0)
		row.add_child(UiKit.chip(icon_name, str(value) if value > 0 else "", entry.get("intent_color", UiKit.threat()), "", 13, 15))
	var bar: ProgressBar = UiKit.make_bar(entry.get("hp", 0), entry.get("max_hp", 1), UiKit.hp_enemy(), Vector2(10, 5), false)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	return card


# Последняя карточка: что случится в конце раунда, после всех врагов
func _make_round_end(icons: Array[Dictionary], width: float) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size.x = width
	card.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.PANEL, 0.75), Color(UiKit.LINE, 0.6), 1, 7, 7, 5))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.tooltip_text = Loc.t("Конец раунда: после хода всех врагов горит огонь, действует яд, приходит подмога")
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var title: Label = UiKit.make_label(Loc.t("Конец раунда"), 12, UiKit.TEXT_DIM)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	if icons.is_empty():
		row.add_child(UiKit.make_label("—", 13, UiKit.TEXT_DIM))
	for item: Dictionary in icons:
		row.add_child(UiKit.icon_rect(item["icon"], 15, item["color"]))
	return card

class_name BattleHud
extends CanvasLayer
# Интерфейс боя поверх 3D. Что где:
#   слева сверху  — панели героев (портрет, здоровье, мана, шаги, ярость/натиск/заряд);
#   справа сверху — номер раунда, арена, журнал событий и карточка врага под курсором;
#   снизу         — рука карт, над ней строка-подсказка «что сейчас можно сделать»;
#   справа снизу  — кнопка «Конец хода»; слева снизу — цвета клеток и кнопка справки (F1).
# Узлы создаются в коде. HUD сам ничего не решает — только показывает
# и сообщает о нажатиях сигналами.

signal card_pressed(index: int)
signal hero_pressed(index: int)
signal end_turn_pressed
signal discard_toggled   # нажали «Сбросить» или клавишу X
signal card_keep_toggled(index: int)   # ПКМ по карте в руке: удержать её на следующий ход
signal speed_toggled   # нажали «×1 / ×2» или клавишу F

const LOG_LINES: int = 6
const HAND_PEEK: float = 116.0     # сколько карты торчит над нижним краем экрана, пока на неё не навели
const HAND_MAX_WIDTH: float = 800.0 # шире этого рука не растягивается
const SIDE_WIDTH: float = 300.0

# Цвета клеток на поле — такие же, как в scripts/battle.gd (для памятки слева снизу)
const LEGEND: Array[Array] = [
	[Color(0.3, 0.6, 1.0), "сюда можно идти"],
	[Color(1.0, 0.25, 0.25), "сюда ударят враги"],
	[Color(1.0, 0.85, 0.4), "путь врага в его ход"],
	[Color(0.37, 0.92, 0.83), "шаман усилит своих"],
]

var _root: Control
var _hero_box: VBoxContainer
var _hand_box: HBoxContainer
var _hint_panel: PanelContainer
var _hint: Label
var _end_button: Button
var _speed_button: Button
var _discard_button: Button
var _end_tween: Tween
var _round_label: Label
var _objective_row: HBoxContainer   # цель боя под шапкой журнала (скрыта в обычном бою)
var _relic_row: HBoxContainer       # значки реликвий забега (подсказка при наведении)
var relic_list: Array[RelicData] = []   # обереги и реликвии забега — задаёт сцена боя (логика знает только id)
var _arena_label: Label
var _log_box: VBoxContainer
var _enemy_card: PanelContainer
var _enemy_box: VBoxContainer
var _shown_enemy: BattleUnit      # чья карточка сейчас показана (чтобы не пересобирать её на каждое движение мыши)
var _help: PanelContainer
var _banner: Label
var _banner_bg: ColorRect
var _log_lines: PackedStringArray = []
var _hand_gap: int = 6            # расстояние между картами в руке (отрицательное — внахлёст)


func _ready() -> void:
	# Корневой узел на весь экран. MOUSE_FILTER_IGNORE — пропускает клики
	# сквозь себя в 3D-сцену, иначе по полю было бы не кликнуть.
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Тема (вид кнопок и подсказок) сама не «проходит» внутрь CanvasLayer — задаём её здесь явно
	_root.theme = UiKit.theme()
	add_child(_root)

	_build_hero_box()
	_build_side_column()
	_build_hand()
	_build_end_button()
	_build_speed_button()
	_build_discard_button()
	_build_legend()
	_build_help()
	_build_banner()


# ---------- Сборка частей экрана ----------

func _build_hero_box() -> void:
	_hero_box = VBoxContainer.new()
	_hero_box.position = Vector2(14, 14)
	_hero_box.add_theme_constant_override("separation", 8)
	_hero_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hero_box)


# Правая колонка: раунд и арена, журнал, под ним карточка врага
func _build_side_column() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	column.offset_left = -SIDE_WIDTH - 14
	column.offset_right = -14
	column.offset_top = 14
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(column)

	var log_panel: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL, 0.72), Color(UiKit.LINE, 0.7))
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(log_panel)
	var log_column := VBoxContainer.new()
	log_column.add_theme_constant_override("separation", 5)
	log_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_panel.add_child(log_column)

	# Шапка: «Раунд 3 · Старая гать»
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 7)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_column.add_child(head)
	head.add_child(UiKit.icon_rect("hourglass", 16, UiKit.BRASS))
	_round_label = UiKit.make_label("Раунд 1", 15, UiKit.BRASS.lightened(0.2), true)
	head.add_child(_round_label)
	_arena_label = UiKit.make_label("", 14, UiKit.TEXT_DIM)
	head.add_child(_arena_label)
	_objective_row = HBoxContainer.new()
	_objective_row.add_theme_constant_override("separation", 6)
	_objective_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_row.visible = false
	log_column.add_child(_objective_row)
	_relic_row = HBoxContainer.new()
	_relic_row.add_theme_constant_override("separation", 6)
	_relic_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relic_row.visible = false
	log_column.add_child(_relic_row)
	var line := ColorRect.new()
	line.color = Color(UiKit.LINE, 0.8)
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_column.add_child(line)

	_log_box = VBoxContainer.new()
	_log_box.add_theme_constant_override("separation", 1)
	_log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_column.add_child(_log_box)
	_redraw_log()

	_enemy_card = UiKit.make_panel(Color(UiKit.PANEL, 0.96), UiKit.HP_ENEMY.darkened(0.35), 2)
	_enemy_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_card.visible = false
	column.add_child(_enemy_card)
	_enemy_box = VBoxContainer.new()
	_enemy_box.add_theme_constant_override("separation", 5)
	_enemy_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_card.add_child(_enemy_box)


# Рука и строка-подсказка над ней
func _build_hand() -> void:
	_hand_box = HBoxContainer.new()
	_hand_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hand_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hand_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_box.add_theme_constant_override("separation", _hand_gap)
	_root.add_child(_hand_box)

	# Подсказка — справа снизу, прямо над кнопкой «Конец хода»
	_hint_panel = PanelContainer.new()
	_hint_panel.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.PANEL, 0.82), Color(UiKit.LINE, 0.8), 1, 9, 10, 5))
	_hint_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_panel.offset_right = -14
	_hint_panel.offset_bottom = -82
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.visible = false
	_root.add_child(_hint_panel)
	_hint = UiKit.make_label("", 13, UiKit.TEXT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 232
	_hint_panel.add_child(_hint)


func _build_end_button() -> void:
	_end_button = Button.new()
	_end_button.text = "Конец хода"
	_end_button.icon = UiKit.icon("hourglass")
	_end_button.focus_mode = Control.FOCUS_NONE
	_end_button.add_theme_font_override("font", UiKit.font_bold())
	_end_button.add_theme_font_size_override("font_size", 18)
	_end_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_end_button.offset_left = -204
	_end_button.offset_top = -72
	_end_button.offset_right = -14
	_end_button.offset_bottom = -14
	_end_button.tooltip_text = "Закончить ход героев. Враги сделают ровно то, что показано на поле:\nжёлтые линии — куда пойдут, красные клетки — куда ударят."
	Sfx.bind_button(_end_button, "turn")
	_end_button.pressed.connect(end_turn_pressed.emit)
	_root.add_child(_end_button)


# Памятка по цветам клеток и кнопка справки — слева снизу
# Маленькая кнопка слева от «Конец хода»: ход врагов быстрее в два раза (клавиша F)
func _build_speed_button() -> void:
	_speed_button = Button.new()
	_speed_button.toggle_mode = true
	_speed_button.focus_mode = Control.FOCUS_NONE
	_speed_button.add_theme_font_size_override("font_size", 13)
	_speed_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_speed_button.offset_left = -344
	_speed_button.offset_top = -72
	_speed_button.offset_right = -214
	_speed_button.offset_bottom = -14
	_speed_button.tooltip_text = "Скорость хода врагов: обычная или в два раза быстрее. Клавиша F.\nМожно переключать и пока враги ходят."
	Sfx.bind_button(_speed_button)
	_speed_button.pressed.connect(toggle_speed_from_button)
	_root.add_child(_speed_button)
	_update_speed_button()


# Кнопка «Сбросить» слева от кнопки скорости: сбросить одну карту из руки за ход (клавиша X)
func _build_discard_button() -> void:
	_discard_button = Button.new()
	_discard_button.toggle_mode = true
	_discard_button.focus_mode = Control.FOCUS_NONE
	_discard_button.add_theme_font_size_override("font_size", 13)
	_discard_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_discard_button.offset_left = -484
	_discard_button.offset_top = -72
	_discard_button.offset_right = -354
	_discard_button.offset_bottom = -14
	Sfx.bind_button(_discard_button)
	_discard_button.pressed.connect(discard_toggled.emit)
	_root.add_child(_discard_button)


# Обновляет кнопку сброса: сколько сбросов осталось и включён ли режим выбора карты
func update_discard_button(logic: BattleLogic, active: BattleUnit, discarding: bool, busy: bool) -> void:
	var enabled: bool = BattleLogic.DRAW_MODE != BattleLogic.DrawMode.DISCARD_ALL \
			and BattleLogic.DRAW_MODE != BattleLogic.DrawMode.KEEP_2
	_discard_button.visible = enabled
	if not enabled or active == null:
		return
	var left: int = logic.discards_left(active)
	_discard_button.text = "Сбросить · X\n(осталось %d)" % left
	_discard_button.button_pressed = discarding
	_discard_button.disabled = busy or left <= 0 or active.hand.is_empty()
	if left <= 0:
		_discard_button.tooltip_text = "В этот ход карту уже сбрасывали. В следующий ход снова можно."
	else:
		_discard_button.tooltip_text = "Выбери эту кнопку (или X), потом карту в руке — она уйдёт в сброс.\nОдна карта за ход, добор не даётся."


# Кнопка сама меняет своё состояние при нажатии, поэтому тут только синхронизация с Run
func toggle_speed_from_button() -> void:
	Run.fast_enemies = _speed_button.button_pressed
	_update_speed_button()
	speed_toggled.emit()


func _build_legend() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_left = 14
	column.offset_bottom = -14
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(column)
	for item: Array in LEGEND:
		column.add_child(_legend_row(item[0], item[1], 13))
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	column.add_child(gap)
	var help_button := Button.new()
	help_button.text = "Управление · F1"
	help_button.icon = UiKit.icon("help")
	help_button.focus_mode = Control.FOCUS_NONE
	help_button.add_theme_font_size_override("font_size", 13)
	help_button.add_theme_constant_override("icon_max_width", 15)
	help_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	Sfx.bind_button(help_button)
	help_button.pressed.connect(toggle_help)
	column.add_child(help_button)


func _legend_row(color: Color, text: String, font_size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var swatch := Panel.new()
	swatch.add_theme_stylebox_override("panel", UiKit.box(Color(color, 0.75), color.lightened(0.2), 1, 3, 0, 0))
	swatch.custom_minimum_size = Vector2(13, 13)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(swatch)
	var label: Label = UiKit.make_label(text, font_size, UiKit.TEXT_DIM.lightened(0.25))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	row.add_child(label)
	return row


# Окно справки по управлению (скрыто, пока не нажали F1 или кнопку)
func _build_help() -> void:
	_help = UiKit.make_panel(Color(0.05, 0.07, 0.07, 0.97), UiKit.BRASS_DARK, 2)
	_help.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_help.grow_vertical = Control.GROW_DIRECTION_BOTH
	_help.visible = false
	_root.add_child(_help)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	_help.add_child(column)
	column.add_child(UiKit.make_title("Как играть", 26, UiKit.BRASS.lightened(0.2)))
	column.add_child(UiKit.make_divider(300))
	var rows: Array[Array] = [
		["mouse_l", "", "ЛКМ по синей клетке — идти выбранным героем"],
		["mouse_l", "", "ЛКМ по карте, потом по клетке — сыграть карту"],
		["mouse_r", "", "ПКМ или Esc — отменить выбранную карту"],
		["", "1–7", "Сыграть карту по её номеру"],
		["mouse_r", "", "ПКМ по карте в руке (или Shift + цифра) — удержать её на следующий ход, до %d карт" % BattleLogic.KEEP_LIMIT],
		["hourglass", "", "В конце хода остальная рука уходит в сброс, рука пополняется минимум до %d карт" % BattleLogic.HAND_SIZE],
		["drop", "", "Мокрый враг (был в луже): молния бьёт по нему на 3 сильнее. Огонь сушит"],
		["", "Tab", "Другой герой (или клик по герою, по его панели)"],
		["target", "", "Наведи на врага — его удар, зона и особенности"],
		["rotate", "", "Q / E — повернуть камеру"],
		["zoom", "", "Колесо мыши — приблизить или отдалить"],
		["hourglass", "", "«Конец хода» — враги делают то, что показано на поле"],
		["", "F", "Ход врагов в два раза быстрее (кнопка «×1 / ×2» слева от «Конец хода»)"],
		["target", "", "Враги бьют туда, где выгоднее; причина — в их карточке, строка «Цель»"],
	]
	for item: Array in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var slot := CenterContainer.new()
		slot.custom_minimum_size = Vector2(46, 26)
		if item[0] != "":
			slot.add_child(UiKit.icon_rect(item[0], 22, UiKit.BRASS.lightened(0.15)))
		else:
			var key := PanelContainer.new()
			key.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL_LIGHT, UiKit.LINE.lightened(0.2), 1, 5, 7, 1))
			key.add_child(UiKit.make_label(item[1], 13, UiKit.TEXT, true))
			slot.add_child(key)
		row.add_child(slot)
		row.add_child(UiKit.make_label(item[2], 15))
		column.add_child(row)
	column.add_child(UiKit.make_divider(300))
	column.add_child(UiKit.make_label("Над врагом: значок и число — чем и на сколько он ударит в этом раунде.", 13, UiKit.TEXT_DIM))
	var colors := HBoxContainer.new()
	colors.add_theme_constant_override("separation", 16)
	colors.alignment = BoxContainer.ALIGNMENT_CENTER
	for item: Array in LEGEND:
		colors.add_child(_legend_row(item[0], item[1], 13))
	column.add_child(colors)
	var close: Button = UiKit.make_button("Понятно", toggle_help, "", true)
	close.custom_minimum_size = Vector2(180, 38)
	column.add_child(close)


func _build_banner() -> void:
	# Тёмная полоса и большая надпись «Победа!/Поражение» — по центру, пока скрыты
	_banner_bg = ColorRect.new()
	_banner_bg.color = Color(0.02, 0.03, 0.03, 0.72)
	_banner_bg.set_anchors_and_offsets_preset(Control.PRESET_HCENTER_WIDE)
	_banner_bg.offset_top = -64
	_banner_bg.offset_bottom = 64
	_banner_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_bg.visible = false
	_root.add_child(_banner_bg)
	_banner = UiKit.make_title("", 68, UiKit.BRASS.lightened(0.25))
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 10)
	_banner_bg.add_child(_banner)


# F1 — показать/скрыть справку
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		var key: int = (event as InputEventKey).keycode
		if key == KEY_F1:
			toggle_help()
			get_viewport().set_input_as_handled()
		elif key == KEY_X and BattleLogic.DRAW_MODE != BattleLogic.DrawMode.KEEP_2:
			discard_toggled.emit()
			get_viewport().set_input_as_handled()
		elif key == KEY_F:
			toggle_speed()
			get_viewport().set_input_as_handled()


# «×1 / ×2»: ускорение хода врагов. Выбор хранится в Run на весь забег.
func toggle_speed() -> void:
	Run.fast_enemies = not Run.fast_enemies
	_update_speed_button()
	speed_toggled.emit()


func _update_speed_button() -> void:
	_speed_button.text = "Ход врагов ×2" if Run.fast_enemies else "Ход врагов ×1"
	_speed_button.button_pressed = Run.fast_enemies


func toggle_help() -> void:
	_help.visible = not _help.visible


# ---------- Обновление ----------

# Обереги и реликвии: латунные значки, при наведении — описание (у реликвий плюс и минус)
func _refresh_relics() -> void:
	if _relic_row.get_child_count() == relic_list.size():
		return   # не пересобираем каждый кадр — набор реликвий в бою не меняется
	UiKit.clear(_relic_row)
	_relic_row.visible = not relic_list.is_empty()
	for r in relic_list:
		_relic_row.add_child(UiKit.chip(r.icon if r.icon != "" else "relic", "", UiKit.BRASS, r.full_text(), 14, 18))


# Цель боя: значок, название и что осталось («Ритуал: 3 р. до призыва»)
func _refresh_objective(logic: BattleLogic) -> void:
	UiKit.clear(_objective_row)
	_objective_row.visible = logic.objective != BattleLogic.Objective.KILL_ALL
	if not _objective_row.visible:
		return
	_objective_row.add_child(UiKit.icon_rect(logic.objective_icon(), 16, UiKit.BRASS))
	_objective_row.add_child(UiKit.make_label(logic.objective_title() + ":", 14, UiKit.BRASS, true))
	var text: Label = UiKit.make_label(logic.objective_text(), 14, UiKit.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 200
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_objective_row.add_child(text)


# Перерисовывает панели героев и руку активного героя.
# selected — номер выбранной карты (-1 — нет), busy — идут анимации.
func refresh(logic: BattleLogic, active: BattleUnit, selected: int, busy: bool) -> void:
	_round_label.text = "Раунд %d" % maxi(logic.turn, 1)
	_arena_label.text = ("·  " + logic.arena_title()) if logic.arena_title() != "" else ""
	_refresh_objective(logic)
	_refresh_relics()

	UiKit.clear(_hero_box)
	for i in logic.heroes.size():
		_hero_box.add_child(_make_hero_panel(logic.heroes[i], i, logic.heroes[i] == active, busy))

	UiKit.clear(_hand_box)
	var any_playable: bool = false
	if active != null and active.is_alive():
		# Если карт в руке много, они встают «внахлёст», чтобы рука не залезала на кнопки по бокам
		var count: int = active.hand.size()
		var gap: float = 6.0
		if count > 1:
			gap = minf(6.0, (HAND_MAX_WIDTH - count * CardView.CARD_SIZE.x) / (count - 1))
		if int(gap) != _hand_gap:   # трогаем настройку, только когда она правда изменилась
			_hand_gap = int(gap)
			_hand_box.add_theme_constant_override("separation", _hand_gap)
		for i in active.hand.size():
			var playable: bool = logic.can_play(active, i)
			any_playable = any_playable or playable
			_hand_box.add_child(_make_hand_slot(active, i, logic.card_cost(active, i), playable, i == selected, busy))

	# Остались ли у кого-то действия: шаги (и есть куда идти) или карта по карману
	var team_can_act: bool = false
	for h: BattleUnit in logic.living_heroes():
		if h.moves_left > 0 and not logic.get_move_targets(h).is_empty():
			team_can_act = true
		for i in h.hand.size():
			if logic.can_play(h, i):
				team_can_act = true

	_end_button.disabled = busy
	_set_end_button_ready(not busy and not team_can_act)
	_update_hint(logic, active, selected, busy, any_playable, team_can_act)


# Панель героя. Нажатие по ней выбирает героя (как Tab).
func _make_hero_panel(h: BattleUnit, index: int, is_active: bool, busy: bool) -> PanelContainer:
	var hero_color: Color = h.hero_data.color
	var alive: bool = h.is_alive()
	var panel := PanelContainer.new()
	var normal: StyleBoxFlat = UiKit.box(
			Color(UiKit.PANEL, 0.95) if is_active else Color(UiKit.PANEL, 0.78),
			UiKit.BRASS if is_active else hero_color.darkened(0.45), 2 if is_active else 1, 9, 10, 8)
	var hover: StyleBoxFlat = UiKit.box(Color(UiKit.PANEL.lightened(0.04), 0.95), UiKit.BRASS.lightened(0.2), 2, 9, 10, 8)
	panel.add_theme_stylebox_override("panel", normal)
	panel.custom_minimum_size.x = 308
	if not alive:
		panel.modulate = Color(1, 1, 1, 0.55)
	elif not busy:
		# Панель ведёт себя как кнопка: подсветка при наведении, клик — выбрать героя
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.mouse_entered.connect(func() -> void: panel.add_theme_stylebox_override("panel", hover))
		panel.mouse_exited.connect(func() -> void: panel.add_theme_stylebox_override("panel", normal))
		panel.gui_input.connect(func(event: InputEvent) -> void:
			var click := event as InputEventMouseButton
			if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
				hero_pressed.emit(index)
		)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(line)

	# Портрет: кружок цвета героя с его иконкой
	var portrait := Panel.new()
	portrait.add_theme_stylebox_override("panel", UiKit.box(hero_color.darkened(0.6), hero_color.lightened(0.1), 2, 24, 0, 0))
	portrait.custom_minimum_size = Vector2(48, 48)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face: TextureRect = UiKit.icon_rect(h.hero_data.id if UiKit.has_icon(h.hero_data.id) else "heart", 30,
			hero_color.lightened(0.55))
	face.position = Vector2(9, 9)
	portrait.add_child(face)
	line.add_child(portrait)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(info)

	# Имя, справа — блок
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(head)
	var title: Label = UiKit.make_label(h.title, 16, Color.WHITE if is_active else UiKit.TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if not alive:
		head.add_child(UiKit.make_label("пал в бою", 13, UiKit.TEXT_DIM))
		return panel
	if h.block > 0:
		head.add_child(UiKit.chip("shield", str(h.block), UiKit.BLOCK,
				"Блок %d: поглощает урон. Сгорает в начале следующего хода героев." % h.block, 16, 18))
	elif not is_active:
		head.add_child(UiKit.make_label("Tab", 11, UiKit.TEXT_DIM))

	info.add_child(UiKit.make_bar(h.hp, h.max_hp, UiKit.HP, Vector2(210, 18)))

	# Мана, шаги, колода, сброс
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(stats)
	stats.add_child(_mana_row(h))
	stats.add_child(UiKit.chip("boot", str(h.moves_left), UiKit.TEXT if h.moves_left > 0 else UiKit.TEXT_DIM.darkened(0.2),
			"Шаги: на сколько клеток герой ещё может пройти в этот ход."))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_child(spacer)
	stats.add_child(UiKit.chip("deck", str(h.draw_pile.size()), UiKit.TEXT_DIM,
			"Колода: карт осталось добрать — %d." % h.draw_pile.size(), 13, 15))
	stats.add_child(UiKit.chip("discard", str(h.discard_pile.size()), UiKit.TEXT_DIM,
			"Сброс: %d. Когда колода кончится, сброс перемешается в новую колоду." % h.discard_pile.size(), 13, 15))

	# Особые счётчики героя и состояния
	# (HFlowContainer сам переносит плашки на вторую строку, если в одну не влезли)
	var extra := HFlowContainer.new()
	extra.add_theme_constant_override("h_separation", 5)
	extra.add_theme_constant_override("v_separation", 4)
	extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if h.hero_data.gains_rage:
		extra.add_child(_pill("rage", "Ярость %d" % h.rage, UiKit.RAGE, h.rage > 0,
				"Ярость: +1 за каждый полученный удар (даже в блок).\n«Кровавый удар» и «Берсерк» тратят её всю ради урона."))
	if h.hero_data.gains_momentum:
		extra.add_child(_pill("momentum", "Натиск %d" % h.momentum, UiKit.MOMENTUM, h.momentum > 0,
				"Натиск: +1 за каждую пройденную клетку (до 5).\nСледующая карта с уроном прибавит весь натиск. Сгорает в начале хода."))
	if h.hero_data.uses_charge:
		extra.add_child(_pill("bolt", "Заряд %d" % h.charge, UiKit.CHARGE, h.charge > 0,
				"Заряд: копится от заклинаний Бури и не пропадает между ходами.\n«Разрядки» тратят его весь ради урона."))
	if h.overloaded:
		extra.add_child(_pill("overload", "Перегрузка", UiKit.THREAT, true,
				"Перегрузка: не потратишь заряд до конца хода — маг получит урон, равный заряду."))
	if h.taunt:
		extra.add_child(_pill("taunt", "Провокация", UiKit.BLOCK, true, "Враги, которые могут достать героя, бьют только его."))
	if h.outpost:
		extra.add_child(_pill("outpost", "Застава", UiKit.BLOCK, true, "Враг, подошедший вплотную, получает урон."))
	if h.unstoppable:
		extra.add_child(_pill("unstoppable", "Неудержимый", UiKit.MOMENTUM, true, "До конца хода каждое убийство даёт 1 ману и 2 шага."))
	if h.discount > 0:
		extra.add_child(_pill("discount", "−%d" % h.discount, UiKit.MANA_CHEAP, true, "Следующая карта дешевле на %d." % h.discount))
	if h.entangled > 0:
		extra.add_child(_pill("entangled", "Опутан", UiKit.THREAT, true, "Опутан корнями: в этот ход нет шагов. Карты играть можно."))
	if h.rune != "" and h.rune_hits > 0:
		var rune_names: Dictionary = {"fire": "огонь", "storm": "буря", "rot": "гниль"}
		var rune_hints: Dictionary = {
			"fire": "поджигают клетку под каждым задетым врагом",
			"storm": "считаются молнией: по мокрым врагам +%d урона" % BattleLogic.WET_SHOCK_BONUS,
			"rot": "отравляют задетых врагов (%d урона в конце раунда мимо блока)" % BattleLogic.POISON_DAMAGE,
		}
		extra.add_child(_pill("rune_" + h.rune, "Руна: %s · %d" % [rune_names[h.rune], h.rune_hits], UiKit.TEXT, true,
				"Руна на клинке: следующие удары (%d) %s.\nОдна карта с уроном тратит один удар руны." % [h.rune_hits, rune_hints[h.rune]]))
	if h.wet > 0:
		extra.add_child(_pill("drop", "Мокрый %d" % h.wet, UnitPlate.COLOR_WET, true, "Мокрый: молния бьёт по нему на %d сильнее. Высыхает через пару раундов или от огня." % BattleLogic.WET_SHOCK_BONUS))
	if h.poison > 0:
		extra.add_child(_pill("poison", "Яд %d" % h.poison, UnitPlate.COLOR_POISON, true, "Яд: %d урона в конце раунда мимо блока." % BattleLogic.POISON_DAMAGE))
	if extra.get_child_count() > 0:
		info.add_child(extra)
	else:
		extra.free()
	return panel


# Мана «камнями»: яркие — есть, тёмные — потрачены. Если маны много — просто числом.
func _mana_row(h: BattleUnit) -> HBoxContainer:
	var total: int = maxi(h.mana, h.hero_data.mana_per_turn)
	var hint: String = "Мана: %d из %d. Можно уйти в минус до −%d (перегрев): если в минусе 2 или больше, в следующий ход маны на 1 меньше." % [h.mana, h.hero_data.mana_per_turn, BattleLogic.MAX_OVERHEAT]
	if h.mana < 0:
		return UiKit.chip("mana", "%d (перегрев)" % h.mana, UiKit.GOLD, hint)
	if total > 6:
		return UiKit.chip("mana", str(h.mana), UiKit.MANA, hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	row.tooltip_text = hint
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	for i in total:
		row.add_child(UiKit.icon_rect("mana", 18, UiKit.MANA.lightened(0.15) if i < h.mana else Color(0.2, 0.26, 0.32)))
	return row


# Маленькая плашка со значком: «Ярость 2». lit — яркая (есть что показать) или тусклая (ноль).
func _pill(icon_name: String, text: String, color: Color, lit: bool, hint: String) -> PanelContainer:
	var pill := PanelContainer.new()
	var shown: Color = color if lit else UiKit.TEXT_DIM.darkened(0.25)
	pill.add_theme_stylebox_override("panel", UiKit.box(
			Color(color.darkened(0.75), 0.9) if lit else Color(UiKit.PANEL_LIGHT, 0.6),
			Color(color, 0.7) if lit else Color(UiKit.LINE, 0.6), 1, 9, 6, 1))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(UiKit.chip(icon_name, text, shown, hint, 12, 13))
	return pill


# Карта в руке. Стоит в «гнезде» и наполовину спрятана за нижним краем экрана;
# при наведении выезжает целиком, выбранная — стоит поднятой.
func _make_hand_slot(active: BattleUnit, index: int, cost: int, playable: bool, is_selected: bool, busy: bool) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(CardView.CARD_SIZE.x, HAND_PEEK)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card: Button = CardView.make_button(active.hand[index], active.hero_data.color, cost, index + 1)
	var raised_y: float = HAND_PEEK - CardView.CARD_SIZE.y   # отрицательное: карта видна целиком
	card.disabled = busy or not playable
	card.tooltip_text = ""   # в бою карту и так видно целиком при наведении
	if card.disabled:
		card.modulate = Color(0.68, 0.7, 0.74)   # не хватает маны — карта тусклая
	if is_selected:
		card.position.y = raised_y - 10.0
		card.add_theme_stylebox_override("normal", _selected_frame())
		card.add_theme_stylebox_override("hover", _selected_frame())
		card.z_index = 1
	else:
		card.mouse_entered.connect(_slide_card.bind(card, raised_y, 1.06, 3))
		card.mouse_exited.connect(_slide_card.bind(card, 0.0, 1.0, 0))
	card.pressed.connect(card_pressed.emit.bind(index))
	# ПКМ по карте — удержать её на следующий ход (режим KEEP_2). Замок показывает отметку.
	if BattleLogic.DRAW_MODE == BattleLogic.DrawMode.KEEP_2:
		card.gui_input.connect(func(event: InputEvent) -> void:
			var click := event as InputEventMouseButton
			if click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
				card.accept_event()
				card_keep_toggled.emit(index))
		if active.kept.has(index):
			var lock_back := Panel.new()
			lock_back.add_theme_stylebox_override("panel", UiKit.box(Color(0.04, 0.05, 0.05, 0.92), UiKit.BRASS, 2, 14, 0, 0))
			lock_back.position = Vector2(CardView.CARD_SIZE.x - 34.0, 34.0)
			lock_back.size = Vector2(28, 28)
			lock_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var lock_icon: TextureRect = UiKit.icon_rect("lock", 18, UiKit.BRASS.lightened(0.25))
			lock_icon.position = Vector2(5, 5)
			lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lock_back.add_child(lock_icon)
			card.add_child(lock_back)
	slot.add_child(card)
	return slot


func _selected_frame() -> StyleBoxFlat:
	var frame: StyleBoxFlat = UiKit.box(CardView.COLOR_PAPER.lightened(0.06), UiKit.BRASS.lightened(0.3), 4, 8, 0, 0)
	frame.corner_detail = 1   # срезанные углы, как у самой карты
	frame.shadow_color = Color(UiKit.BRASS, 0.55)
	frame.shadow_size = 12
	return frame


func _slide_card(card: Button, y: float, zoom: float, z: int) -> void:
	if not is_instance_valid(card) or not card.is_inside_tree():
		return
	if y < 0.0 and not card.disabled:
		Sfx.play("ui_hover", 0.05)
	card.z_index = z
	var tween: Tween = card.create_tween().set_parallel(true)
	tween.tween_property(card, "position:y", y, 0.09).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE * zoom, 0.09)


# Кнопка «Конец хода» загорается латунью и мягко мигает, когда делать больше нечего
func _set_end_button_ready(ready: bool) -> void:
	if _end_tween != null:
		_end_tween.kill()
		_end_tween = null
	_end_button.modulate = Color.WHITE
	for state: String in ["normal", "hover", "pressed"]:
		_end_button.remove_theme_stylebox_override(state)
	_end_button.remove_theme_color_override("font_color")
	_end_button.remove_theme_color_override("icon_normal_color")
	if ready:
		UiKit.style_primary(_end_button)
		_end_tween = _end_button.create_tween().set_loops()
		_end_tween.tween_property(_end_button, "modulate", Color(1.25, 1.2, 1.05), 0.6).set_trans(Tween.TRANS_SINE)
		_end_tween.tween_property(_end_button, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)


# Строка над рукой: что можно сделать прямо сейчас
func _update_hint(logic: BattleLogic, active: BattleUnit, selected: int, busy: bool,
		any_playable: bool, team_can_act: bool) -> void:
	var text: String = ""
	if busy or active == null or not active.is_alive():
		text = ""
	elif selected >= 0 and selected < active.hand.size():
		text = "«%s»: выбери жёлтую клетку на поле.\nПКМ или Esc — отмена" % active.hand[selected].title
	elif not team_can_act:
		text = "Шагов и маны не осталось — жми «Конец хода»"
	else:
		var can_move: bool = active.moves_left > 0 and not logic.get_move_targets(active).is_empty()
		if can_move and any_playable:
			text = "%s: клик по синей клетке — идти, клик по карте — сыграть её" % active.title
		elif can_move:
			text = "%s: карты не по карману, но можно идти — клик по синей клетке" % active.title
		elif any_playable:
			text = "%s: шагов нет — выбери карту" % active.title
			if active.entangled > 0:
				text = "%s опутан и не может идти — выбери карту" % active.title
		else:
			text = "%s больше ничего не может.\nTab — другой герой" % active.title
	# Подсказка про удержание: есть карты, но ни одна не отмечена
	if text != "" and selected < 0 and BattleLogic.DRAW_MODE == BattleLogic.DrawMode.KEEP_2 \
			and not active.hand.is_empty() and active.kept.is_empty():
		text += "\nПКМ по карте — удержать (до %d)" % BattleLogic.KEEP_LIMIT
	_hint.text = text
	_hint_panel.visible = text != ""


# ---------- Журнал ----------

func add_log(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > LOG_LINES:
		_log_lines.remove_at(0)
	_redraw_log()


# Свежая строка яркая, старые — тусклее. Строки вида «— Ход 2 —» — заголовки раундов.
func _redraw_log() -> void:
	UiKit.clear(_log_box)
	if _log_lines.is_empty():
		_log_box.add_child(UiKit.make_label("Журнал боя", 13, UiKit.TEXT_DIM))
		return
	for i in _log_lines.size():
		var line: String = _log_lines[i]
		var age: int = _log_lines.size() - 1 - i
		var label: Label = UiKit.make_label(line, 13, Color(UiKit.TEXT, clampf(1.0 - age * 0.14, 0.35, 1.0)))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = SIDE_WIDTH - 26
		if line.begins_with("—"):
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_color_override("font_color", Color(UiKit.BRASS, clampf(1.0 - age * 0.14, 0.4, 1.0)))
		_log_box.add_child(label)


# ---------- Карточка врага под курсором ----------

# e — враг под курсором (null — убрать карточку)
func show_enemy(e: BattleUnit, logic: BattleLogic) -> void:
	if e == _shown_enemy:
		return
	_shown_enemy = e
	_enemy_card.visible = e != null
	if e == null:
		return
	UiKit.clear(_enemy_box)
	var d: EnemyData = e.data
	var width: float = SIDE_WIDTH - 28

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var title: Label = UiKit.make_label(d.title, 20, Color.WHITE)
	title.add_theme_font_override("font", UiKit.font_title())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if d.is_boss:
		head.add_child(UiKit.chip("boss", "Босс", UiKit.BRASS, "", 13, 15))
	elif d.is_elite:
		head.add_child(UiKit.chip("elite", "Элита", UiKit.BRASS, "", 13, 15))
	_enemy_box.add_child(head)

	if d.description != "":
		var quote: Label = UiKit.make_label("«%s»" % d.description, 13, UiKit.TEXT_DIM)
		quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		quote.custom_minimum_size.x = width
		_enemy_box.add_child(quote)

	var health := HBoxContainer.new()
	health.add_theme_constant_override("separation", 10)
	health.add_child(UiKit.make_bar(e.hp, e.max_hp, UiKit.HP_ENEMY, Vector2(190, 17)))
	if e.block > 0:
		health.add_child(UiKit.chip("shield", str(e.block), UiKit.BLOCK, "", 15, 17))
	_enemy_box.add_child(health)
	# Состояния врага: мокрый, отравлен
	if logic.is_wet(e) or e.poison > 0:
		var states := HBoxContainer.new()
		states.add_theme_constant_override("separation", 10)
		if logic.is_wet(e):
			var wet_text: String = "Мокрый" if e.data.always_wet else "Мокрый (%d)" % logic.wet_turns(e)
			states.add_child(UiKit.chip("drop", wet_text + ": молния +%d" % BattleLogic.WET_SHOCK_BONUS, UnitPlate.COLOR_WET, "", 14, 13))
		if e.poison > 0:
			states.add_child(UiKit.chip("poison", "Яд (%d): −%d в конце раунда" % [e.poison, BattleLogic.POISON_DAMAGE], UnitPlate.COLOR_POISON, "", 14, 13))
		_enemy_box.add_child(states)

	var now: EnemyAttackData = logic.enemy_attack(e)
	_enemy_box.add_child(_attack_row("Сейчас", now, e.bonus_damage, true, width))
	if e.ai_reason != "":
		# Почему враг так ходит — из прогноза «если нажать Конец хода сейчас»
		var reason_label: Label = UiKit.make_label("Цель: " + e.ai_reason, 13, UiKit.TEXT)
		reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason_label.custom_minimum_size.x = width
		_enemy_box.add_child(reason_label)
	if d.cycle.size() > 1:
		_enemy_box.add_child(_attack_row("Потом", d.attack_on_turn(logic.turn + 1), 0, false, width))
	for t: String in d.traits():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var dot: TextureRect = UiKit.icon_rect("spark", 9, UiKit.RIFT)
		dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		dot.custom_minimum_size = Vector2(9, 16)
		row.add_child(dot)
		var trait_label: Label = UiKit.make_label(t, 13, UiKit.TEXT)
		trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		trait_label.custom_minimum_size.x = width - 16
		row.add_child(trait_label)
		_enemy_box.add_child(row)


# Строка «Сейчас: [значок] Удар: 4 урона вплотную». bonus — прибавка от «зова» шамана.
func _attack_row(caption: String, attack: EnemyAttackData, bonus: int, bright: bool, width: float) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	var is_buff: bool = attack.shape == EnemyData.Attack.AURA
	var color: Color = UiKit.RIFT if is_buff else UiKit.THREAT
	if not bright:
		color = color.darkened(0.25)
	var icons: Array[String] = ["sword", "arrow", "slash", "buff"]
	var head: HBoxContainer = UiKit.chip(icons[attack.shape] if attack.shape < icons.size() else "sword",
			"%s — %s" % [caption, attack.title], color, "", 13, 15)
	column.add_child(head)
	var text: String = attack.describe().trim_prefix(attack.title + ": ")
	if bonus > 0:
		text += " (+%d от «зова»)" % bonus
	var label: Label = UiKit.make_label(text, 13, UiKit.TEXT if bright else UiKit.TEXT_DIM)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = width
	column.add_child(label)
	return column


# ---------- Надписи по центру ----------

# Название арены в начале боя: появляется сверху по центру и тает
func show_arena(title: String) -> void:
	if title == "":
		return
	var label: Label = UiKit.make_title(title, 44, Color(0.9, 0.94, 0.86))
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.offset_top = 78
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.04))
	label.add_theme_constant_override("outline_size", 10)
	_root.add_child(label)
	var tween: Tween = label.create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(label.queue_free)


func show_banner(text: String) -> void:
	_banner.text = text
	_banner_bg.visible = true
	_hint_panel.visible = false

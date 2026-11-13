class_name ShrinePanel
extends HubPanel
# Святилище духов: кого отряд встречал и покорял, что каждый дух даёт героям, и улучшения духов.
# Сами духи живут только внутри забега: здесь — память о них (Meta.spirits_seen / spirits_tamed).
#
# Что видно о духе:
#   не встречен — только силуэт (у уникального — намёк, что он где-то есть);
#   встречен    — имя, строка лора; у уникального — условие, как его покорить;
#   покорён     — всё: пассивка, Зов, карты обоих героев, с кем есть смешанные карты.

const CARD_SCALE: float = 0.44
const SCROLL_HEIGHT: float = 455.0   # всё под вкладками листается: панель влезает в 720 по высоте
const UNKNOWN_COLOR: Color = Color(0.42, 0.45, 0.44)

const INTRO: String = "Камни помнят каждого духа, которого отряд сломил и взял в узду. Сами духи остаются в топях: в каждом пути их покоряют заново."

var _selected: String = ""


static func open(parent: Node, for_hero: String = "") -> HubPanel:
	var panel := ShrinePanel.new()
	panel.hero_id = for_hero
	create(parent, panel, "Святилище духов", 1040)
	panel._selected = Run.ALL_SPIRIT_IDS[0]
	Meta.changed.connect(panel._rebuild)
	panel._rebuild()
	return panel


func _rebuild() -> void:
	UiKit.clear(body)
	body.add_child(UiKit.make_text(INTRO, 15, UiKit.TEXT_DIM, 980))
	body.add_child(_make_tabs())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(990, SCROLL_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	scroll.add_child(inner)
	inner.add_child(_make_detail(Run.spirit_data(_selected)))
	for u in Meta.UPGRADES:
		if u.board == MetaUpgradeData.Desk.SPIRIT:
			inner.add_child(UpgradePanel.make_row(u))


# Вкладки духов: значок и имя (или «???», если дух ещё не встречен)
func _make_tabs() -> Control:
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	for id in Run.ALL_SPIRIT_IDS:
		var sp: SpiritData = Run.spirit_data(id)
		if sp == null:
			continue
		var seen: bool = Meta.is_spirit_seen(id)
		var b: Button = UiKit.make_button(sp.title if seen else "???", _select.bind(id), sp.icon if seen else "help")
		b.custom_minimum_size = Vector2(200, 42)
		b.add_theme_color_override("icon_normal_color", sp.color if seen else UNKNOWN_COLOR)
		b.add_theme_color_override("icon_hover_color", sp.color if seen else UNKNOWN_COLOR)
		if Meta.is_spirit_tamed(id):
			b.tooltip_text = "Покорён: %d раз" % Meta.tamed_count(id)
		elif seen:
			b.tooltip_text = "Встречен, но ещё не покорён"
		else:
			b.tooltip_text = "Отряд ещё не встречал этого духа"
		if id == _selected:
			recolor_button(b, (sp.color if seen else UNKNOWN_COLOR).lightened(0.2), 3)
		tabs.add_child(b)
	return tabs


func _select(id: String) -> void:
	_selected = id
	_rebuild()


func _make_detail(sp: SpiritData) -> Control:
	var panel: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL_LIGHT, 0.5), UiKit.LINE)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	if sp == null:
		return panel
	var seen: bool = Meta.is_spirit_seen(sp.id)
	var tamed: bool = Meta.is_spirit_tamed(sp.id)

	# Заголовок: значок, имя, отметка
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(ic(sp.icon if seen else "help", 30, sp.color if seen else UNKNOWN_COLOR))
	var name_label: Label = UiKit.make_label(sp.title if seen else "Неизвестный дух", 22, UiKit.TEXT, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	if sp.is_unique and seen:
		head.add_child(UiKit.make_label("Уникальный", 15, UiKit.BRASS.lightened(0.15), true))
	if tamed:
		head.add_child(UiKit.make_label("Покорён ×%d" % Meta.tamed_count(sp.id), 15, sp.color.lightened(0.2), true))
	var bait: Control = _make_bait_button(sp) if tamed else null
	if bait != null:
		head.add_child(bait)
	box.add_child(head)

	if not seen:
		var hint: String = "Этого духа отряд ещё не встречал. Духи ждут в логове — по одному на акт."
		if sp.is_unique:
			hint = "Говорят, в топях живёт кто-то старше духов логова. В логове его не найти."
		box.add_child(UiKit.make_text(hint, 16, UiKit.TEXT_DIM, 960))
		return panel

	box.add_child(UiKit.make_text("«%s»" % sp.description, 16, UiKit.TEXT, 960))
	if sp.is_unique:
		box.add_child(UiKit.make_text("Как покорить: " + _unique_condition(sp.id), 15, UiKit.BRASS.lightened(0.15), 960))
	if not tamed:
		box.add_child(UiKit.make_text("Ещё не покорён. Что он даёт героям, станет видно после первой победы над ним.", 15, UiKit.TEXT_DIM, 960))
		return panel

	box.add_child(UiKit.make_text("Пассивно: " + sp.passive_text, 16, sp.color.lightened(0.25), 960))
	box.add_child(_make_cards(sp))
	box.add_child(UiKit.make_text(_pairs_text(sp), 14, UiKit.TEXT_DIM, 960))
	return panel


# Зов и карты обоих героев. Первые карты приходят сразу, остальные — в наградах.
func _make_cards(sp: SpiritData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	if sp.call_card != null:
		row.add_child(_card_column("Зов", [sp.call_card], sp.color, 1))
	for h in Run.HEROES:
		row.add_child(_card_column(h.title, sp.cards_for(h.id), h.color, 3))
	return row


func _card_column(title: String, cards: Array[CardData], color: Color, columns: int) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.add_child(UiKit.make_label(title, 15, color.lightened(0.3), true))
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	for c in cards:
		grid.add_child(mini_card(c, color, CARD_SCALE, Callable()))
	col.add_child(grid)
	return col


# С кем у духа есть смешанные карты (их дают два духа в одном отряде)
func _pairs_text(sp: SpiritData) -> String:
	var names: Array[String] = []
	for id in Run.ALL_SPIRIT_IDS:
		if id == sp.id:
			continue
		var other: SpiritData = Run.spirit_data(id)
		if other == null:
			continue
		names.append(other.title if Meta.is_spirit_seen(id) else "???")
	return "Смешанные карты (по 2 каждому герою) — если в отряде с ним ещё: %s." % ", ".join(names)


# «Приманка»: кнопка «Звать в логово» у покорённого обычного духа (уникальные в логове не живут)
func _make_bait_button(sp: SpiritData) -> Control:
	if Meta.effect_total("lair_bait") <= 0 or not Run.SPIRIT_IDS.has(sp.id):
		return null
	var chosen: bool = Meta.lair_bait == sp.id
	var b: Button = UiKit.make_button("Зовётся в логово ✓" if chosen else "Звать в логово", Meta.choose_bait.bind(sp.id), "orb")
	b.custom_minimum_size = Vector2(210, 36)
	b.tooltip_text = "Нажми ещё раз, чтобы в логове снова ждал случайный дух." if chosen \
			else "«Приманка»: в следующих путях логово позовёт этого духа (если его ещё нет в отряде)."
	if chosen:
		recolor_button(b, UiKit.BRASS, 2)
	Sfx.bind_button(b, "magic")
	return b


func _unique_condition(id: String) -> String:
	match id:
		"bog":
			return "утопить %d врагов в бою с корягачом (элита). Тогда Хозяин трясины сам выйдет к отряду." % Run.BOG_SPIRIT_DROWNS
	return "условие пока не описано."

extends Control
# Привал: оба героя восстанавливают часть здоровья — или вместо отдыха
# «Закалка» (улучшить одну карту) или «Перевязка» (убрать Раны одного героя).

const FORGE_TOAST_TIME: float = 1.2   # сколько показывать закалённую карту перед переходом на карту пути


func _ready() -> void:
	Hints.offer(self, "rest")   # при первом заходе — подсказка слева внизу (scripts/tutorial/hints.gd)
	var column: VBoxContainer = UiKit.make_screen(self)
	var fire: TextureRect = UiKit.icon_rect("rest", 84, Color(1.0, 0.68, 0.32))
	fire.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(fire)
	column.add_child(UiKit.make_title(Loc.t("Привал"), 40, UiKit.BRASS.lightened(0.25)))
	column.add_child(UiKit.make_text(Loc.t("Сухая кочка, огонь и час тишины. Топь подождёт."), 18, UiKit.TEXT_DIM))
	column.add_child(UiKit.party_bar())
	var heal_share: float = Run.rest_percent()
	var percent: int = roundi(heal_share * 100.0)
	var gains: PackedStringArray = []
	for rh in Run.party:
		var amount: int = mini(ceili(rh.data.max_hp * heal_share), rh.data.max_hp - rh.hp)
		gains.append("%s +%d" % [Loc.t(rh.data.title), amount])
	var rest: Button = UiKit.make_button(Loc.t("Отдохнуть  ·  +%d%% здоровья") % percent, _rest, "heart", true)
	rest.custom_minimum_size.x = 340
	rest.tooltip_text = Loc.t("Вылечит: ") + ", ".join(gains)
	column.add_child(rest)
	# «Закалка»: вместо отдыха улучшить одну карту любого героя (сначала карта, потом ветка)
	var can_forge: bool = false
	for rh in Run.party:
		can_forge = can_forge or not Run.upgradable(rh).is_empty()
	var forge: Button = UiKit.make_button(Loc.t("Закалка  ·  улучшить карту (вместо отдыха)"), _start_forge, "star")
	forge.custom_minimum_size.x = 340
	forge.disabled = not can_forge
	forge.tooltip_text = Loc.t("Выбери карту любого героя и ветку: I «Сила» или II «Приём». Лечения на этом привале не будет.") if can_forge else Loc.t("Все карты уже улучшены")
	column.add_child(forge)
	# «Перевязка»: вместо отдыха убрать все Раны одного героя
	for rh in Run.party:
		var n: int = Run.wound_count(rh)
		if n > 0:
			var bandage: Button = UiKit.make_button(Loc.t("Перевязка: %s  ·  убрать Ран: %d (вместо отдыха)") % [Loc.t(rh.data.title), n],
					_bandage.bind(rh), "wound")
			bandage.custom_minimum_size.x = 340
			bandage.tooltip_text = Loc.t("Раны уйдут из колоды. Лечения на этом привале не будет.")
			column.add_child(bandage)
	_add_spirit_transfers(column)
	var skip: Button = UiKit.make_button(Loc.t("Идти дальше"), Run.goto.bind(Run.MAP_SCENE))
	skip.custom_minimum_size.x = 340
	column.add_child(skip)


# Передать духа другому герою: его карты сменятся на карты нового героя (улучшения сохранятся)
func _add_spirit_transfers(column: VBoxContainer) -> void:
	for rh in Run.party:
		for sp: SpiritData in rh.spirits:
			for other in Run.party:
				if other == rh:
					continue
				var b: Button = UiKit.make_button(Loc.t("Передать «%s»: %s → %s") % [Loc.t(sp.title), Loc.t(rh.data.title), Loc.t(other.data.title)], func() -> void: pass, sp.icon)
				b.custom_minimum_size.x = 340
				b.disabled = not Run.can_take_spirit(other)
				b.tooltip_text = Loc.t("Карты духа сменятся на карты другого героя, улучшения сохранятся.") if not b.disabled else Loc.t("У %s заняты места для духов") % Loc.t(other.data.title)
				b.pressed.connect(func() -> void:
					if Run.transfer_spirit(rh, other, sp):
						Sfx.play("spirit_tame", 0.04, -3.0)
						Run.goto(Run.REST_SCENE))
				column.add_child(b)


func _rest() -> void:
	Sfx.play("heal", 0.04)
	var heal_share: float = Run.rest_percent()
	Run.rest_used = true   # «Чистый бинт» действует только на первый привал
	for rh in Run.party:
		Run.heal_hero(rh, ceili(rh.data.max_hp * heal_share))
	Run.goto(Run.MAP_SCENE)


func _bandage(rh: RunHero) -> void:
	Sfx.play("heal", 0.04)
	Run.bandage(rh)
	Run.goto(Run.MAP_SCENE)


# «Закалка»: окно колод обоих героев → карта → окно с двумя ветками → улучшение и на карту
func _start_forge() -> void:
	var sections: Array[Dictionary] = []
	for rh in Run.party:
		sections.append({"title": rh.data.title, "color": rh.data.color, "cards": rh.deck})
	DeckOverlay.open(self, Loc.t("Какую карту закалить?"), sections,
			Loc.t("Нажми на карту, потом выбери ветку улучшения. Вместо отдыха."),
			_pick_forge_card, func(_section: int) -> bool: return true)


func _pick_forge_card(section: int, index: int) -> void:
	var rh: RunHero = Run.party[section]
	var card: CardData = rh.deck[index]
	if not Run.can_upgrade(card):
		return
	var choice: Array[CardData] = [card.upgrade_1, card.upgrade_2]
	var sections: Array[Dictionary] = [{"title": Loc.t("I «Сила»  ·  II «Приём»"), "color": rh.data.color, "cards": choice}]
	DeckOverlay.open(self, Loc.t("Ветка улучшения: %s") % Loc.t(card.title), sections, Loc.t("Выбор окончательный."),
			func(_s: int, branch_index: int) -> void: _forge(rh, index, branch_index + 1))


func _forge(rh: RunHero, index: int, branch: int) -> void:
	if not Run.can_upgrade(rh.deck[index]):
		return
	Sfx.play("magic", 0.05)
	Run.upgrade_card(rh, index, branch)
	# Показать закалённую карту (около секунды), кнопки привала под ней уже не нажать
	mouse_filter = Control.MOUSE_FILTER_STOP
	for b: Node in find_children("*", "Button", true, false):
		(b as Button).disabled = true
	UiFx.card_toast(self, rh.deck[index], rh.data.color, Loc.t("Закалено"))
	await get_tree().create_timer(FORGE_TOAST_TIME).timeout
	Run.goto(Run.MAP_SCENE)

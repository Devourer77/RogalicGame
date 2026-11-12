extends Control
# Главное меню: ввод сида и старт забега.
# Сид — число, из которого получается вся случайность забега:
# одинаковый сид = одинаковая карта, враги и карты в наградах.

var _seed_input: LineEdit


func _ready() -> void:
	var column: VBoxContainer = UiKit.make_screen(self)
	column.add_theme_constant_override("separation", 12)

	# Герои отряда — два значка над названием
	var heroes := HBoxContainer.new()
	heroes.alignment = BoxContainer.ALIGNMENT_CENTER
	heroes.add_theme_constant_override("separation", 18)
	for hero: HeroData in Run.HEROES:
		heroes.add_child(UiKit.icon_rect(hero.id if UiKit.has_icon(hero.id) else "star", 54, hero.color.lightened(0.35)))
	column.add_child(heroes)

	column.add_child(UiKit.make_title("Пошаговый Рогалик", 58, UiKit.BRASS.lightened(0.25)))
	column.add_child(UiKit.make_text("Сумеречная Марка. Небо расколото, топь ожила —\nа до Шпиля идти двоим: магу и рыцарю.", 17, UiKit.TEXT_DIM))
	column.add_child(UiKit.make_divider(320))

	_seed_input = LineEdit.new()
	_seed_input.placeholder_text = "Сид (пусто — случайный)"
	_seed_input.tooltip_text = "Сид — число, из которого получается вся случайность забега.\nОдинаковый сид — та же карта, враги и награды."
	_seed_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_input.custom_minimum_size = Vector2(300, 42)
	_seed_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_seed_input.text_submitted.connect(func(_text: String) -> void: _on_start())
	column.add_child(_seed_input)

	column.add_child(UiKit.make_button("Начать забег", _on_start, "battle", true))
	column.add_child(UiKit.make_button("Выход", get_tree().quit))


func _on_start() -> void:
	var text: String = _seed_input.text.strip_edges()
	var new_seed: int = int(text) if text.is_valid_int() else 0
	Run.start_new_run(new_seed)
	Run.goto(Run.MAP_SCENE)

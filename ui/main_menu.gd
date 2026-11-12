extends Control
# Главное меню. Игра начинается с хаба — «Заставы Колокола»:
# забег стартует уже оттуда, через Ворота (там же сид «Для проверки»).

var _reset_button: Button


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

	# Первый запуск (сохранения нет) — «Начать», потом — «Продолжить».
	var start_text: String = "Продолжить" if Meta.has_save() else "Начать"
	column.add_child(UiKit.make_button(start_text, _on_start, "bell", true))
	if Meta.has_save():
		_reset_button = UiKit.make_button("Новый прогресс", _on_reset)
		column.add_child(_reset_button)
	column.add_child(UiKit.make_button("Выход", get_tree().quit))


func _on_start() -> void:
	Run.goto(Run.HUB_SCENE)


# «Новый прогресс» стирает все Отзвуки, Звоны и улучшения — спрашиваем второй раз.
var _reset_armed: bool = false

func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "Точно стереть? Нажми ещё раз"
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			_reset_armed = false
			if is_instance_valid(_reset_button):
				_reset_button.text = "Новый прогресс")
		return
	Meta.reset()
	Run.goto(Run.MAIN_MENU_SCENE)

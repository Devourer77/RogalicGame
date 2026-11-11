extends Control
# Главное меню: ввод сида и старт забега.
# Сид — число, из которого получается вся случайность забега:
# одинаковый сид = одинаковая карта, враги и карты в наградах.

var _seed_input: LineEdit


func _ready() -> void:
	var column: VBoxContainer = UiKit.make_screen(self)
	column.add_child(UiKit.make_label("Пошаговый Рогалик", 48))
	column.add_child(UiKit.make_label("Тактика на сетке и заклинания из колоды", 18))

	_seed_input = LineEdit.new()
	_seed_input.placeholder_text = "Сид забега (пусто — случайный)"
	_seed_input.custom_minimum_size = Vector2(260, 40)
	column.add_child(_seed_input)

	column.add_child(UiKit.make_button("Начать забег", _on_start))
	column.add_child(UiKit.make_button("Выход", get_tree().quit))


func _on_start() -> void:
	var text: String = _seed_input.text.strip_edges()
	var new_seed: int = int(text) if text.is_valid_int() else 0
	Run.start_new_run(new_seed)
	Run.goto(Run.MAP_SCENE)

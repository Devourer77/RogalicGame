extends Control
# Конец забега: победа над боссом или гибель героя.


func _ready() -> void:
	var column: VBoxContainer = UiKit.make_screen(self)
	if Run.last_run_won:
		column.add_child(UiKit.make_label("Победа!", 56))
		column.add_child(UiKit.make_label("Огр повержен, дорога свободна.", 22))
	else:
		column.add_child(UiKit.make_label("Поражение…", 56))
		column.add_child(UiKit.make_label("Отряд пал. Но следующий забег будет другим.", 22))
	column.add_child(UiKit.make_label("Сид забега: %d" % Run.seed_value, 18))
	column.add_child(UiKit.make_button("В главное меню", Run.goto.bind(Run.MAIN_MENU_SCENE)))

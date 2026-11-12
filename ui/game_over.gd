extends Control
# Конец забега: победа над боссом или гибель отряда.


func _ready() -> void:
	var column: VBoxContainer = UiKit.make_screen(self)
	if Run.last_run_won:
		var crown: TextureRect = UiKit.icon_rect("boss", 72, UiKit.BRASS.lightened(0.2))
		crown.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(crown)
		column.add_child(UiKit.make_title("Победа!", 64, UiKit.BRASS.lightened(0.3)))
		column.add_child(UiKit.make_text("Огр повержен, гать свободна. Шпиль стал на один переход ближе.", 20))
	else:
		var bell: TextureRect = UiKit.icon_rect("bell", 72, UiKit.TEXT_DIM)
		bell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(bell)
		column.add_child(UiKit.make_title("Поражение", 64, UiKit.TEXT))
		column.add_child(UiKit.make_text("Отряд пал. Где-то звонит Колокол Стражи — и путь начинается снова.", 20, UiKit.TEXT_DIM))
	column.add_child(UiKit.make_divider(300))
	var seed_label: Label = UiKit.make_text("Сид забега: %d" % Run.seed_value, 16, UiKit.TEXT_DIM)
	seed_label.tooltip_text = "Введи это число в главном меню, чтобы пройти тот же забег ещё раз."
	seed_label.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(seed_label)
	column.add_child(UiKit.make_button("В главное меню", Run.goto.bind(Run.MAIN_MENU_SCENE), "", true))

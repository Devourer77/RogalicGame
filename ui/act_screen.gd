extends Control
# Переход в новый акт (Run.next_act): номер и название акта, пара фраз о нём, отряд после передышки.
# Кнопка «В путь» открывает карту пути нового акта.

const ROMAN: Array[String] = ["", "I", "II", "III", "IV"]


func _ready() -> void:
	var column: VBoxContainer = UiKit.make_screen(self)
	column.add_theme_constant_override("separation", 14)
	var a: ActData = Run.act_data()
	column.add_child(UiKit.make_label(Loc.t("Акт %s") % ROMAN[clampi(a.number, 0, ROMAN.size() - 1)], 22, UiKit.TEXT_DIM))
	column.add_child(UiKit.make_title(a.title, 56, UiKit.BRASS.lightened(0.3)))
	column.add_child(UiKit.make_text(a.intro, 19))
	column.add_child(UiKit.make_divider(300))
	column.add_child(UiKit.make_text(Loc.t("Отряд перевёл дух: раны затянулись. Колоды, духи, золото и реликвии — с собой."), 17, UiKit.TEXT_DIM))
	column.add_child(UiKit.party_bar())
	if a.is_placeholder():
		# Пока у акта нет своих врагов и арен — честно говорим об этом игроку
		column.add_child(UiKit.make_text(Loc.t("Акт ещё строится: здесь пока враги и арены Гнилых топей, только крепче."), 15, UiKit.TEXT_DIM))
	column.add_child(UiKit.make_button(Loc.t("В путь"), Run.goto.bind(Run.MAP_SCENE), "", true))

extends SceneTree
# Проверка Meta: godot --headless --path . -s tests/meta.gd
# Пишет в отдельный файл user://progress_test.cfg и настоящее сохранение не трогает.

const MetaScript = preload("res://scripts/autoload/meta.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("ПРОВАЛ: ", what)


func _fresh() -> Node:
	var meta: Node = MetaScript.new()
	meta.save_path = "user://progress_test.cfg"
	meta.reset()
	return meta


func _init() -> void:
	var meta: Node = _fresh()

	# Формула Отзвуков: 4 ряда, Звон 0 — 8; со Звоном 2 и событием 4: (5*2 + 8 + 4) = 22, ×1,5 = 33
	_check(meta.calc_echoes(4, 0, 0, 0, 0) == 8, "4 ряда на Звоне 0 = 8")
	_check(meta.calc_echoes(5, 1, 0, 4, 2) == 33, "множитель Звона действует и на события")
	_check(meta.calc_echoes(0, 0, 0, 0, 5) == 0, "нулевой забег даёт 0")
	_check(meta.calc_echoes(3, 0, 0, 0, 1) == 8, "округление вверх: 6 × 1,25 = 7,5 → 8")

	# Проигранный забег даёт Отзвуки, но Звон не открывает
	meta.add_run_result({"rows": 4, "elites": 0, "bosses": 0, "event_echoes": 0, "bell": 0, "complete": false})
	_check(meta.echoes == 8, "Отзвуки за проигранный забег")
	_check(meta.bell_max == 0, "проигрыш не открывает Звон")
	# Победа на высшем открытом Звоне открывает следующий
	meta.add_run_result({"rows": 8, "elites": 1, "bosses": 1, "event_echoes": 0, "bell": 0, "complete": true})
	_check(meta.bell_max == 1, "победа открывает Звон 1")
	_check(meta.first_boss_killed, "первый босс отмечен")
	# Победа на более низком Звоне новый не открывает
	meta.add_run_result({"rows": 8, "elites": 1, "bosses": 1, "event_echoes": 0, "bell": 0, "complete": true})
	_check(meta.bell_max == 1, "победа на низком Звоне не открывает новый")
	# Босс убит, но забег не «до конца» (будущие три акта)
	meta.add_run_result({"rows": 8, "elites": 1, "bosses": 1, "event_echoes": 0, "bell": 1, "complete": false})
	_check(meta.bell_max == 1, "убит босс акта 1 из 3 — Звон не открывается")

	# Выбор закрытого Звона игнорируется
	meta.choose_bell(4)
	_check(meta.bell_chosen == 0, "закрытый Звон выбрать нельзя")
	meta.choose_bell(1)
	_check(meta.bell_chosen == 1, "открытый Звон выбирается")

	# Улучшения: нельзя без Отзвуков; по ступеням; на последней не покупается
	var m2: Node = _fresh()
	_check(not m2.can_buy("treasury"), "без Отзвуков купить нельзя")
	m2.echoes = 1000
	_check(m2.buy("treasury") and m2.level("treasury") == 1, "первая ступень")
	_check(m2.echoes == 1000 - 15, "цена первой ступени")
	_check(m2.effect_total("start_gold") == 20, "Казна I: +20 золота")
	m2.buy("treasury")
	m2.buy("treasury")
	_check(m2.level("treasury") == 3 and m2.is_maxed("treasury"), "три ступени куплены")
	_check(not m2.buy("treasury"), "на последней ступени купить нельзя")
	_check(m2.effect_total("start_gold") == 60, "Казна III: +60 золота")
	m2.buy("mage_hardening")
	_check(m2.effect_total("hero_hp", "mage") == 4 and m2.effect_total("hero_hp", "knight") == 0, "Закалка Мага не трогает Рыцаря")
	_check(m2.deck_changes("mage") == 2 and m2.deck_changes("knight") == 2, "базово 2 изменения колоды")
	m2.buy("mage_loadout")
	_check(m2.deck_changes("mage") == 3 and m2.deck_changes("knight") == 2, "Своя выкладка Мага: +1 только Магу")
	_check(m2.steps_total() == 23, "всего 23 ступени улучшений (21 + две у Святилища)")

	# Закрытые карты: пока не куплены «Забытые формулы»
	var m3: Node = _fresh()
	m3.echoes = 1000
	_check(m3.is_card_locked("mb_echo") and m3.is_card_locked("mb_overload"), "редкие карты Мага закрыты")
	_check(not m3.is_card_locked("mb_staff"), "обычные карты открыты сразу")
	m3.buy("mage_formulas")
	_check(not m3.is_card_locked("mb_echo") and m3.is_card_locked("mb_overload"), "ступень I открывает первую редкую карту")
	m3.buy("mage_formulas")
	_check(not m3.is_card_locked("meteor"), "ступень II открывает остальные")

	# Обереги: покупка, «только из пути», места
	var m4: Node = _fresh()
	_check(m4.is_charm_open("charm_purse") and not m4.is_charm_open("charm_bell"), "два оберега открыты с начала")
	_check(not m4.can_buy_charm("charm_bell"), "нет Отзвуков — купить нельзя")
	_check(not m4.can_buy_charm("charm_horn"), "«только из пути» не покупается")
	m4.echoes = 500
	_check(m4.buy_charm("charm_bell") and m4.is_charm_open("charm_bell"), "покупка оберега")
	_check(not m4.buy_charm("charm_horn"), "купить «только из пути» нельзя даже с Отзвуками")
	m4.unlock_charm("charm_horn")
	_check(m4.is_charm_open("charm_horn"), "трофей/тайник открывают оберег")
	_check(m4.charm_slots() == 1, "одно место без «Второго оберега»")
	m4.toggle_charm("charm_purse")
	_check(not m4.toggle_charm("charm_bell"), "второй оберег без второго места не берётся")
	m4.buy("second_charm")
	_check(m4.toggle_charm("charm_bell") and m4.valid_chosen().size() == 2, "второе место")
	_check(m4.closed_charms().size() == 10 - 4, "закрытых обереги считаются верно")

	# Запас карт: записывается один раз
	_check(m4.record_card("mage", "fireball"), "новая карта в Запас")
	_check(not m4.record_card("mage", "fireball"), "повтор в Запас не пишется")

	# Сохранение → загрузка даёт те же данные; reset обнуляет
	m4.save()
	var m5: Node = MetaScript.new()
	m5.save_path = "user://progress_test.cfg"
	m5.load_progress()
	_check(m5.echoes == m4.echoes and m5.is_charm_open("charm_horn") and m5.level("second_charm") == 1, "загрузка совпадает с сохранением")
	_check(m5.in_stock("mage", "fireball"), "Запас пережил сохранение")
	m5.reset()
	_check(m5.echoes == 0 and m5.charms.is_empty() and m5.upgrades.is_empty() and m5.card_stock.is_empty(), "reset обнуляет всё")

	# Духи: встреча, покорение, «Приманка», сохранение, чистка Запаса
	var m6: Node = _fresh()
	m6.echoes = 1000
	m6.mark_spirit_seen("storm")
	_check(m6.is_spirit_seen("storm") and not m6.is_spirit_tamed("storm"), "встреченный дух ещё не покорён")
	m6.record_spirit_tamed("tide")
	m6.record_spirit_tamed("tide")
	_check(m6.is_spirit_seen("tide") and m6.tamed_count("tide") == 2, "покорение считается и делает духа встреченным")
	_check(not m6.choose_bait("tide"), "без «Приманки» выбрать духа для логова нельзя")
	m6.buy("spirit_bait")
	_check(not m6.choose_bait("storm"), "непокорённого духа в логово не позвать")
	_check(m6.choose_bait("tide") and m6.bait_spirit() == "tide", "«Приманка» зовёт покорённого духа")
	m6.choose_bait("tide")
	_check(m6.bait_spirit() == "", "повторное нажатие снимает выбор")
	m6.choose_bait("tide")
	m6.buy("spirit_bond")
	_check(m6.effect_total("spirit_start_cards") == 1, "«Старая узда»: +1 карта духа")
	m6.card_stock = {"mage": ["mb_spark", "tide_m4", "mix_tide_storm_m1", "m_flood_old"]}
	var heroes: Array[HeroData] = [load("res://resources/heroes/mage.tres") as HeroData]
	m6.prune_stock(heroes)
	_check(m6.stock_ids("mage").size() == 1 and m6.stock_ids("mage")[0] == "mb_spark", "из Запаса уходят карты духов и пропавшие карты (%s)" % [m6.stock_ids("mage")])
	m6.save()
	var m7: Node = MetaScript.new()
	m7.save_path = "user://progress_test.cfg"
	m7.load_progress()
	_check(m7.tamed_count("tide") == 2 and m7.is_spirit_seen("storm") and m7.bait_spirit() == "tide", "духи пережили сохранение")
	m7.reset()
	_check(m7.spirits_seen.is_empty() and m7.spirits_tamed.is_empty() and m7.lair_bait == "", "reset забывает духов")

	# Чистим тестовый файл
	if FileAccess.file_exists("user://progress_test.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://progress_test.cfg"))
	print("Тесты Meta: ", "всё хорошо" if _fails == 0 else "провалов: %d" % _fails)
	quit(_fails)

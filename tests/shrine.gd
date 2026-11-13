extends SceneTree

# Духи между забегами: Святилище помнит встреченных и покорённых, «Приманка», «Старая узда»,
# карты духов не попадают в Запас Караульни, итог забега знает своих духов.
# Запуск: godot --headless --path . -s tests/shrine.gd
# Пишет в отдельное сохранение user://progress_shrine.cfg — настоящий прогресс не трогает.

var fails := 0


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


func _initialize() -> void:
	var meta: Node = root.get_node("Meta")
	var run: Node = root.get_node("Run")
	meta.save_path = "user://progress_shrine.cfg"
	meta.reset()

	# Логово без «Приманки»: случайный дух, и Святилище его запоминает
	run.start_new_run(11)
	var rolled: SpiritData = run._roll_lair_spirit()
	check("логово выбрало духа", rolled != null)
	check("дух из логова записан как встреченный", rolled != null and meta.is_spirit_seen(rolled.id))
	check("но ещё не покорён", rolled != null and not meta.is_spirit_tamed(rolled.id))

	# Покорение: 3 карты сразу, запись в Meta и в забег
	var mage: RunHero = run.party[0]
	var tide: SpiritData = run.spirit_data("tide")
	var before: int = mage.deck.size()
	check("Омутник приходит к магу", run.add_spirit(mage, tide))
	check("без «Старой узды» — 3 карты", mage.deck.size() == before + 3)
	check("Омутник покорён в Meta", meta.tamed_count("tide") == 1)
	check("забег помнит покорённого духа", run.run_spirits.size() == 1 and run.run_spirits[0] == "tide")

	# Карта духа из награды не пишется в Запас; обычная — пишется
	var spirit_card: CardData = tide.mage_cards[3]
	check("карта духа не записана в Караульню", not run.add_card(mage, spirit_card))
	check("карты духа нет в Запасе", not meta.in_stock("mage", spirit_card.id))
	var plain: CardData = null
	for c in mage.data.card_pool:
		if not c.is_rare and c.card_set != "" and not mage.data.starter_deck.has(c):
			plain = c
			break
	if plain != null:
		check("обычная карта записана в Караульню", run.add_card(mage, plain) and meta.in_stock("mage", plain.id))

	# Итог забега с духами (сам game_over меняет сцену — он проверяется в smoke_hub)
	meta.add_run_result({"rows": 3, "spirits": run.run_spirits.duplicate()})
	check("в итоге забега есть духи", meta.last_result.get("spirits", []) == ["tide"])
	check("и в Летописи", meta.history[-1].get("spirits", []) == ["tide"])

	# «Приманка»: логово зовёт выбранного покорённого духа
	meta.echoes = 1000
	meta.buy("spirit_bait")
	check("«Приманка» выбирает Омутника", meta.choose_bait("tide"))
	var all_tide: bool = true
	for s in [3, 4, 5, 6, 7]:
		run.start_new_run(s)
		var picked: SpiritData = run._roll_lair_spirit()
		all_tide = all_tide and picked != null and picked.id == "tide"
	check("с «Приманкой» в логове всегда Омутник", all_tide)
	# Если Омутник уже в отряде — снова случайный, но не он
	run.start_new_run(8)
	run.add_spirit(run.party[0], tide)
	var other: SpiritData = run._roll_lair_spirit()
	check("Омутник уже в отряде — логово зовёт другого", other != null and other.id != "tide")

	# «Старая узда»: знакомый дух даёт 4 карты, новый — 3; награды начинаются после них
	meta.buy("spirit_bond")
	run.start_new_run(9)
	var m: RunHero = run.party[0]
	var k: RunHero = run.party[1]
	var n0: int = m.deck.size()
	run.add_spirit(m, tide)
	check("знакомый Омутник приносит 4 карты", m.deck.size() == n0 + 4)
	var rewards: Array[CardData] = run.spirit_reward_cards(m)
	check("в наградах остались 2 карты Омутника", rewards.size() == 2 and not rewards.has(tide.mage_cards[3]))
	var wind: SpiritData = run.spirit_data("wind")
	var n1: int = k.deck.size()
	run.add_spirit(k, wind)
	check("незнакомый Вихорь приносит 3 карты", k.deck.size() == n1 + 3)

	meta.reset()
	if FileAccess.file_exists(meta.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(meta.save_path))
	print("FAILS: ", fails)
	quit(fails)

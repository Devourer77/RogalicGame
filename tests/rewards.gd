extends SceneTree

# Награды, улучшения и лавка новой системы карт (тз-карты.md, разделы 4 и 10).
# Запуск: godot --headless --path . -s tests/rewards.gd

var fails := 0


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	run.start_new_run(21)
	var mage: RunHero = run.party[0]
	var n: int = run.upgradable(mage).size()
	check("Вся стартовая колода Мага улучшаема", n == mage.deck.size())
	var first: CardData = mage.deck[0]
	run.upgrade_card(mage, 0, 1)
	check("Ветка I заменила карту", mage.deck[0] == first.upgrade_1 and mage.deck[0].upgrade_level == 1)
	run.upgrade_card(mage, 0, 2)
	check("Улучшенную карту второй раз не улучшить", mage.deck[0] == first.upgrade_1)
	check("Улучшенная пропала из списка", run.upgradable(mage).size() == n - 1)
	var ups: Array[Dictionary] = run.roll_upgrades(3)
	check("Предложено 3 улучшения", ups.size() == 3)
	var ok := true
	for u in ups:
		ok = ok and run.can_upgrade((u["hero"] as RunHero).deck[int(u["index"])])
	check("Все предложенные можно улучшить", ok)
	var rares: Array[CardData] = run.roll_rare_cards(mage, 3)
	var all_rare := true
	for c in rares: all_rare = all_rare and c.is_rare
	check("Редкие для элиты — только ★", all_rare)
	check("Удаление дешевле: 40", run.REMOVE_CARD_PRICE == 40)
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)

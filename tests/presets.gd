extends SceneTree

# Пресеты стартовых колод: по 3 на героя, третий закрыт до победы над боссом акта 2,
# у каждого пресета свои изменения, забег начинается с колоды пресета.
# Запуск: godot --headless --path . -s tests/presets.gd

var fails := 0


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	var meta = root.get_node("Meta")
	meta.save_path = "user://test_presets.cfg"
	meta.reset()
	for hero: HeroData in run.HEROES:
		var t: String = hero.title
		check("%s: 3 пресета" % t, hero.presets.size() == 3)
		check("%s: первый пресет = прежняя базовая колода" % t, Loadout.ids_of(hero.presets[0].cards) == Loadout.ids_of(hero.starter_deck))
		for p: DeckPreset in hero.presets:
			check("%s/%s: 8 карт, все карты героя" % [t, p.title], p.cards.size() == 8 and Loadout.resolve(hero, Loadout.ids_of(p.cards)).size() == 8)
			var counts: Dictionary = {}
			for c: CardData in p.cards:
				counts[c.id] = counts.get(c.id, 0) + 1
			check("%s/%s: не больше 2 копий" % [t, p.title], counts.values().max() <= 2)
		check("%s: третий закрыт" % t, not meta.preset_unlocked(hero.presets[2]))
		check("%s: второй открыт" % t, meta.preset_unlocked(hero.presets[1]))
		meta.choose_preset(hero, hero.presets[2].id)
		check("%s: закрытый не выбирается" % t, meta.current_preset(hero) == hero.presets[0])
		meta.choose_preset(hero, hero.presets[1].id)
		check("%s: второй выбран" % t, meta.current_preset(hero) == hero.presets[1])
		check("%s: база = карты второго" % t, meta.current_deck_ids(hero) == Loadout.ids_of(hero.presets[1].cards))
		# своя правка у второго пресета не трогает первый
		var edited: Array[String] = meta.current_deck_ids(hero)
		edited.append(edited[0])
		meta.decks[meta.deck_key(hero)] = edited
		check("%s: правка второго держится" % t, meta.current_deck_ids(hero).size() == 9)
		meta.choose_preset(hero, hero.presets[0].id)
		check("%s: у первого своя колода" % t, meta.current_deck_ids(hero) == Loadout.ids_of(hero.starter_deck))
		meta.choose_preset(hero, hero.presets[1].id)
	run.start_new_run(3)
	for rh: RunHero in run.party:
		check("%s: забег начат с колоды второго пресета" % rh.data.title, rh.deck.size() == 9 and rh.start_deck.size() == 9)
		check("%s: веса наборов на старте пустые" % rh.data.title, run.set_weights(rh).is_empty())
	# Открытие: босс акта 2
	check("Открытие сработало один раз", meta.note_act2_boss() and not meta.note_act2_boss())
	for hero: HeroData in run.HEROES:
		check("%s: третий открыт" % hero.title, meta.preset_unlocked(hero.presets[2]))
		meta.choose_preset(hero, hero.presets[2].id)
		check("%s: третий выбран, в колоде ★" % hero.title, Loadout.resolve(hero, meta.current_deck_ids(hero)).any(func(c: CardData) -> bool: return c.is_rare))
	meta.save()
	meta.act2_boss_killed = false
	meta.deck_presets = {}
	meta.load_progress()
	check("Сохранение: открытие и выбор пресета", meta.act2_boss_killed and meta.current_preset(run.HEROES[0]) == run.HEROES[0].presets[2])
	meta.reset()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)

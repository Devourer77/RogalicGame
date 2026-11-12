extends SceneTree
# Правила стартовой колоды (Караульня): godot --headless --path . -s tests/loadout.gd

var _fails: int = 0
const BASE: Array[String] = ["strike", "strike", "guard", "guard", "shove", "spark"]
const STOCK: Array[String] = ["fireball", "wave", "gust", "ice_lance"]
const RARES: Array[String] = ["meteor"]


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("ПРОВАЛ: ", what)


func _init() -> void:
	var base: Array[String] = BASE.duplicate()
	var stock: Array[String] = STOCK.duplicate()
	var rares: Array[String] = RARES.duplicate()

	# добавить можно до лимита изменений, сверх — нельзя
	var deck: Array[String] = base.duplicate()
	_check(Loadout.can_add(base, deck, "fireball", stock, rares, 2), "первое добавление")
	deck.append("fireball")
	_check(Loadout.can_add(base, deck, "wave", stock, rares, 2), "второе добавление")
	deck.append("wave")
	_check(not Loadout.can_add(base, deck, "gust", stock, rares, 2), "третье добавление сверх лимита")

	# убрать добавленную — можно, изменение освобождается
	_check(Loadout.can_remove(base, deck, deck.size() - 1), "убрать добавленную")
	deck.pop_back()
	_check(Loadout.can_add(base, deck, "gust", stock, rares, 2), "изменение освободилось")

	# на минимуме убрать нельзя
	var minimal: Array[String] = base.duplicate()
	_check(not Loadout.can_remove(base, minimal, 0), "убрать на минимуме")
	# добавил одну карту — теперь можно убрать любую, включая базовую
	minimal.append("fireball")
	_check(Loadout.can_remove(base, minimal, 0), "убрать базовую после добавления")

	# замена на минимуме работает, размер не меняется
	var m2: Array[String] = base.duplicate()
	_check(Loadout.can_replace(base, m2, 0, "fireball", stock, rares, 2), "замена на минимуме")

	# редкую, третью копию и карту не из Запаса положить нельзя
	_check(not Loadout.can_add(base, base, "meteor", ["meteor"], rares, 4), "редкая карта")
	_check(not Loadout.can_add(base, base, "strike", stock, rares, 4), "третья копия")
	_check(not Loadout.can_add(base, base, "lightning", stock, rares, 4), "карта не из Запаса")

	# validate: любое нарушение — базовая колода
	_check(Loadout.validate(base, base.duplicate(), stock, rares, 2) == base, "базовая проходит")
	var small: Array[String] = ["strike", "guard"]
	_check(Loadout.validate(base, small, stock, rares, 2) == base, "колода меньше базовой")
	var big: Array[String] = base.duplicate()
	big.append_array(["fireball", "wave", "gust"])
	_check(Loadout.validate(base, big, stock, rares, 2) == base, "изменений больше лимита")
	var rare_deck: Array[String] = base.duplicate()
	rare_deck.append("meteor")
	_check(Loadout.validate(base, rare_deck, stock, rares, 2) == base, "редкая в колоде")
	var foreign: Array[String] = base.duplicate()
	foreign.append("lightning")
	_check(Loadout.validate(base, foreign, stock, rares, 2) == base, "карта не из Запаса в колоде")
	var good: Array[String] = base.duplicate()
	good.append("fireball")
	_check(Loadout.validate(base, good, stock, rares, 2) == good, "хорошая своя колода принимается")

	# 1000 случайных цепочек действий: колода никогда не меньше базовой и не нарушает правил
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var pool: Array[String] = ["strike", "guard", "shove", "spark", "fireball", "wave", "gust", "ice_lance", "meteor", "other"]
	for chain in 1000:
		var d: Array[String] = base.duplicate()
		for step in 12:
			var action: int = rng.randi_range(0, 2)
			var card: String = pool[rng.randi_range(0, pool.size() - 1)]
			var idx: int = rng.randi_range(0, d.size() - 1)
			if action == 0 and Loadout.can_add(base, d, card, stock, rares, 4):
				d.append(card)
			elif action == 1 and Loadout.can_remove(base, d, idx):
				d.remove_at(idx)
			elif action == 2 and Loadout.can_replace(base, d, idx, card, stock, rares, 4):
				d.remove_at(idx)
				d.insert(idx, card)
			if d.size() < base.size() or Loadout.extras(base, d).size() > 4:
				_check(false, "цепочка %d нарушила правила" % chain)
				break
		_check(Loadout.validate(base, d, stock, rares, 4) == d, "цепочка %d: validate отверг законную колоду" % chain)

	print("Тесты Loadout: ", "всё хорошо" if _fails == 0 else "провалов: %d" % _fails)
	quit(_fails)

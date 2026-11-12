class_name Loadout
extends RefCounted
# Правила стартовой колоды (Караульня). Только статические функции, без узлов:
# так их легко проверять тестами (tests/loadout.gd).
# base — базовая колода героя (id карт), deck — текущая стартовая колода,
# stock — Запас героя (id карт, которые он брал в забегах).
# Изменение — карта в колоде сверх базовой; считается по количеству копий.
# Здесь нельзя обращаться к Meta и Run: в тестах (-s) автозагрузок нет,
# поэтому «текущая колода героя» живёт в Meta (current_deck_ids, start_deck).

const MAX_COPIES: int = 2   # не больше стольких копий одной карты в стартовой колоде


# Карты колоды сверх базовой («изменения»)
static func extras(base: Array[String], deck: Array[String]) -> Array[String]:
	var left: Dictionary = {}
	for id in base:
		left[id] = left.get(id, 0) + 1
	var result: Array[String] = []
	for id in deck:
		if left.get(id, 0) > 0:
			left[id] -= 1
		else:
			result.append(id)
	return result


static func copies(deck: Array[String], card_id: String) -> int:
	return deck.count(card_id)


# Можно ли вообще класть эту карту: базовая или из Запаса, и не редкая
static func is_allowed_card(card_id: String, base: Array[String], stock: Array[String], rares: Array[String]) -> bool:
	if rares.has(card_id):
		return false
	return base.has(card_id) or stock.has(card_id)


static func can_add(base: Array[String], deck: Array[String], card_id: String,
		stock: Array[String], rares: Array[String], limit: int) -> bool:
	if not is_allowed_card(card_id, base, stock, rares):
		return false
	if copies(deck, card_id) >= MAX_COPIES:
		return false
	var with_card: Array[String] = deck.duplicate()
	with_card.append(card_id)
	return extras(base, with_card).size() <= limit


static func can_remove(base: Array[String], deck: Array[String], index: int) -> bool:
	return index >= 0 and index < deck.size() and deck.size() - 1 >= base.size()


static func can_replace(base: Array[String], deck: Array[String], index: int, card_id: String,
		stock: Array[String], rares: Array[String], limit: int) -> bool:
	if index < 0 or index >= deck.size():
		return false
	if not is_allowed_card(card_id, base, stock, rares):
		return false
	var next: Array[String] = deck.duplicate()
	next.remove_at(index)
	if copies(next, card_id) >= MAX_COPIES:
		return false
	next.append(card_id)
	return extras(base, next).size() <= limit


# Проверка всей колоды. Любое нарушение — возвращаем базовую колоду.
static func validate(base: Array[String], deck: Array[String], stock: Array[String],
		rares: Array[String], limit: int) -> Array[String]:
	if deck.is_empty() or deck.size() < base.size():
		return base.duplicate()
	var counts: Dictionary = {}
	for id in deck:
		counts[id] = counts.get(id, 0) + 1
		if counts[id] > MAX_COPIES:
			return base.duplicate()
	var added: Array[String] = extras(base, deck)
	if added.size() > limit:
		return base.duplicate()
	for id in added:
		if not is_allowed_card(id, base, stock, rares):
			return base.duplicate()
	# базовые карты не должны исчезнуть сверх разрешённого: размер колоды уже не меньше базовой,
	# а «потерянных» базовых при этом не больше, чем добавленных (замена)
	var lost: int = 0
	var left: Dictionary = {}
	for id in deck:
		left[id] = left.get(id, 0) + 1
	for id in base:
		if left.get(id, 0) > 0:
			left[id] -= 1
		else:
			lost += 1
	if lost > added.size():
		return base.duplicate()
	return deck.duplicate()


# ---------- Помощники для игры (не для тестов правил) ----------

static func ids_of(cards: Array[CardData]) -> Array[String]:
	var result: Array[String] = []
	for c in cards:
		result.append(c.id)
	return result


# id редких карт героя
static func rare_ids(hero: HeroData) -> Array[String]:
	var result: Array[String] = []
	for c in hero.card_pool:
		if c.is_rare:
			result.append(c.id)
	for c in hero.starter_deck:
		if c.is_rare and not result.has(c.id):
			result.append(c.id)
	return result


# Карта по id среди карт героя (стартовые + пул)
static func find_card(hero: HeroData, card_id: String) -> CardData:
	for c in hero.starter_deck:
		if c.id == card_id:
			return c
	for c in hero.card_pool:
		if c.id == card_id:
			return c
	return null


static func resolve(hero: HeroData, ids: Array[String]) -> Array[CardData]:
	var result: Array[CardData] = []
	for id in ids:
		var c: CardData = find_card(hero, id)
		if c != null:
			result.append(c)
	return result

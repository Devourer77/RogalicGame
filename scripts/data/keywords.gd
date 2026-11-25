class_name Keywords
extends RefCounted
# Словарь ключевых слов боя: состояния, клетки, реакции, особенности врагов.
# Используется для пояснений рядом с картой в руке и в карточке врага (ui/keyword_tips.gd).
# Новое правило в игре — сразу строчку сюда, иначе игрок не узнает, что оно значит.
#
# Каждая запись:
#   id      — короткое имя;
#   word    — как слово показывается в пояснении;
#   pattern — какие формы слова искать в тексте (регулярное выражение без границ слова:
#             граница добавляется сама, «мокр[а-яё]*» найдёт «мокрый», «мокрого», «мокрым»);
#   icon    — значок из assets/icons ("" — без значка);
#   text    — правило в 1–2 строки. Слова из словаря внутри пояснения тоже получат свои пояснения.

const LETTERS: String = "А-Яа-яЁё"

const LIST: Array[Dictionary] = [
	{"id": "wet", "word": "Мокрый", "pattern": "мокр[а-яё]*|мокн[а-яё]*", "icon": "drop",
		"text": "Вошёл в лужу или под ним появилась вода. Держится в луже и ещё 2 раунда после. Молния по мокрому бьёт сильнее, огонь сушит."},
	{"id": "poison", "word": "Яд", "pattern": "яд|яда|ядом|яду|ядов[а-яё]*|отрав[а-яё]*", "icon": "poison",
		"text": "2 урона в конце раунда мимо блока, 3 раунда. Новый яд обновляет срок."},
	{"id": "entangled", "word": "Опутан", "pattern": "опута[а-яё]*|опутыва[а-яё]*", "icon": "entangled",
		"text": "В свой ход не может идти, но карты играть и бить может."},
	{"id": "taunt", "word": "Провокация", "pattern": "провокац[а-яё]*", "icon": "taunt",
		"text": "Враги, которые могут достать героя с провокацией, бьют только его."},
	{"id": "pincer", "word": "Клещи", "pattern": "клещ[а-яё]*", "icon": "pincer",
		"text": "Враг между двумя героями на одной прямой получает от карт +50%. Огонь, яд и взрывы не усиливаются."},
	{"id": "push", "word": "Толчок", "pattern": "толк[а-яё]*|толч[а-яё]*|отбра[а-яё]*|отброс[а-яё]*", "icon": "push",
		"text": "Сдвигает по прямой. Врезался в преграду, край поля или другого — 4 урона обоим (в частокол — 6)."},
	{"id": "block", "word": "Блок", "pattern": "блок[а-яё]*", "icon": "shield",
		"text": "Принимает урон на себя, пока не кончится. Блок врагов сгорает в начале их хода."},
	{"id": "fire", "word": "Огонь", "pattern": "огонь|огня|огнём|огнем|огню|огне|поджиг[а-яё]*|подожж[а-яё]*|поджеч[а-яё]*|горит|горящ[а-яё]*", "icon": "fire",
		"text": "3 урона в конце раунда тому, кто стоит в огне; горит 3 раунда. Испаряет лужу, топит лёд, поджигает деревья, бочки и камыш."},
	{"id": "puddle", "word": "Лужа", "pattern": "луж[а-яё]*|вод[аеуыо]|водой", "icon": "drop",
		"text": "Кто вошёл — мокрый. Молния бьёт по всей связной луже. Тушит огонь."},
	{"id": "ice", "word": "Лёд", "pattern": "л[её]д|льд[а-яё]*|ледян[а-яё]*", "icon": "ice",
		"text": "При толчке по льду скользят дальше. Лёд на луже — заморозка."},
	{"id": "freeze", "word": "Заморозка", "pattern": "замороз[а-яё]*|заморож[а-яё]*|вмерза[а-яё]*", "icon": "snow",
		"text": "Лёд на луже: кто стоял в ней — опутан на 1 ход. Тяжёлые не вмерзают."},
	{"id": "steam", "word": "Пар", "pattern": "пар|паром|паров[а-яё]*", "icon": "wind",
		"text": "Огонь на луже: паровой взрыв — 3 урона, отброс на 1, лужа исчезает."},
	{"id": "lightning", "word": "Молния", "pattern": "молни[а-яё]*", "icon": "bolt",
		"text": "Бьёт по всей связной луже и проводится через топь. По мокрому — сильнее."},
	{"id": "swamp_tile", "word": "Топь", "pattern": "топь|топью", "icon": "drop",
		"text": "Вход в топь отнимает 1 шаг. Проводит молнию."},
	{"id": "mire", "word": "Трясина", "pattern": "трясин[а-яё]*", "icon": "maw",
		"text": "Не пройти. Обычный враг, толкнутый в неё, тонет; герой получает 4 урона и остаётся на краю, тяжёлые — урон."},
	{"id": "gas", "word": "Газ", "pattern": "газ|газа|газом|газе|газов[а-яё]*", "icon": "poison",
		"text": "3 урона и яд тому, кто вошёл, протащен или стоит в газе в конце раунда. Огонь его взрывает."},
	{"id": "lava", "word": "Лава", "pattern": "лава|лавы|лаву|лаве|лавой", "icon": "fire",
		"text": "Огонь на трясине. Стена на 3 раунда. Толкнули в лаву — 6 урона; кто стоит в ней в конце раунда — 6."},
	{"id": "crust", "word": "Корка", "pattern": "корк[а-яё]*", "icon": "planks",
		"text": "Вода или лёд на лаве. Проходима, но ход на ней заканчивается. Через 2 раунда — сухая земля."},
	{"id": "chain", "word": "Цепь", "pattern": "цепь|цепи|цепью", "icon": "chain",
		"text": "Сколько карт отряд сыграл за ход. Карты с «Цепь N» и «+X за звено» от неё сильнее."},
	{"id": "keep", "word": "Удержание", "pattern": "удерж[а-яё]*", "icon": "lock",
		"text": "ПКМ по карте в руке — она останется на следующий ход."},
	{"id": "rune", "word": "Руна на оружии", "pattern": "рун[аыуео]|руной", "icon": "rune_storm",
		"text": "Одна на оружии, на 3 удара: каждая карта с уроном, задевшая врага, тратит один."},
	{"id": "shell", "word": "Панцирь", "pattern": "панцир[а-яё]*", "icon": "shield",
		"text": "Урон от карт вдвое меньше, кроме удара в клещах."},
	{"id": "absorb", "word": "Поглощение магии", "pattern": "поглощ[а-яё]*", "icon": "drain",
		"text": "На каждое второе Заклинание героев за ход — врагам +3 здоровья, себе +3 блока."},
	{"id": "summon", "word": "Призыв", "pattern": "призыв[а-яё]*|призва[а-яё]*", "icon": "horn",
		"text": "Новые враги появляются на свободных клетках рядом. На поле не больше 10 врагов."},
	{"id": "short", "word": "Замыкание", "pattern": "замыкан[а-яё]*", "icon": "bolt",
		"text": "Механизм стоит и искрит — пропускает свой ход."},
]

# Объекты поля и клетки — пояснение при наведении на клетку (подсказка клетки в бою).
# Где правило уже есть в LIST (трясина, лава, корка, огонь…) — ссылка на его id.
const OBJECTS: Dictionary = {
	BattleLogic.Obj.BOG: "mire",
	BattleLogic.Obj.LAVA: "lava",
	BattleLogic.Obj.CRUST: "crust",
	BattleLogic.Obj.TREE: {"word": "Мёртвое дерево", "icon": "tree",
		"text": "Преграда. Удар, огонь или врезавшийся — падает на 3 клетки: 7 урона всем на линии, выживших сбивает с ног."},
	BattleLogic.Obj.BARREL: {"word": "Бочка с газом", "icon": "barrel",
		"text": "Преграда. Удар или огонь — взрыв по клетке и 6 соседям: 6 урона и поджог."},
	BattleLogic.Obj.PLANKS: {"word": "Гнилые мостки", "icon": "planks",
		"text": "Проходимы, но ломаются в трясину, когда с них уходят."},
	BattleLogic.Obj.REEDS: {"word": "Камыш", "icon": "reeds",
		"text": "Проходим, закрывает удары по линии. Горит весь сразу."},
	BattleLogic.Obj.ICE_BLOCK: {"word": "Ледяная глыба", "icon": "ice_wall",
		"text": "Преграда. От огня — ледяные осколки: 4 урона соседям, на месте лужа. Сама тает через 3 раунда."},
	BattleLogic.Obj.STAKES: {"word": "Частокол", "icon": "stakes",
		"text": "Преграда. Толкнутый в него получает 6 урона вместо 4. Горит."},
	BattleLogic.Obj.BRIDGE: {"word": "Крепкий настил", "icon": "planks",
		"text": "Проходим поверх трясины и не ломается."},
	BattleLogic.Obj.RUNE: {"word": "Сторожевая руна", "icon": "rune_trap",
		"text": "Проходима. Взрывается, когда на неё наступил враг или по ней ударили."},
	BattleLogic.Obj.LIVE_TREE: {"word": "Живое дерево", "icon": "tree",
		"text": "Преграда, закрывает удары по линии, не падает. Огонь — крона горит, потом дерево сухое."},
	BattleLogic.Obj.BURNING_TREE: {"word": "Горящее дерево", "icon": "fire",
		"text": "Преграда. В конце раунда обжигает соседей на 2, потом сгорает в мёртвое дерево."},
	BattleLogic.Obj.VINE: {"word": "Лоза", "icon": "entangled",
		"text": "Проходима, но кто вошёл — опутан и дальше не идёт. Горит цепью, удар картой срубает."},
	BattleLogic.Obj.BUSH: {"word": "Подлесок", "icon": "reeds",
		"text": "Как камыш: закрывает удары по линии, прячет засаду, горит."},
	BattleLogic.Obj.HIVE: {"word": "Дикий улей", "icon": "poison",
		"text": "Преграда. Удар или огонь — рой жалит клетку и 6 соседей: 2 урона и яд."},
	BattleLogic.Obj.VALVE: {"word": "Паровой клапан", "icon": "wind",
		"text": "Преграда. Удар — выброс пара по 6 соседям, клапан ломается в лужу."},
	BattleLogic.Obj.STONE_WALL: {"word": "Камни", "icon": "cover",
		"text": "Преграда, закрывает удары по линии. Через 3 раунда осыпается."},
	BattleLogic.Obj.CART: {"word": "Вагонетка", "icon": "ram",
		"text": "Преграда. Удар — катится по прямой и сбивает первого на пути."},
	BattleLogic.Obj.BASIN: {"word": "Купель", "icon": "drop",
		"text": "Преграда. Удар — вода плещет на соседей: огонь гаснет, все мокрые."},
	BattleLogic.Obj.SPHERE_STORM: {"word": "Грозовая сфера", "icon": "orb",
		"text": "Преграда. Удар — разряд по соседям и по всей воде рядом."},
}
const TILES: Dictionary = {
	BattleLogic.Tile.FIRE: "fire",
	BattleLogic.Tile.WATER: "puddle",
	BattleLogic.Tile.ICE: "ice",
	BattleLogic.Tile.SWAMP: "swamp_tile",
	BattleLogic.Tile.GAS: "gas",
	BattleLogic.Tile.SMOKE: {"word": "Дым", "icon": "wind",
		"text": "Закрывает удары по линии. Рассеивается через 2 раунда."},
}

static var _regex: Dictionary[String, RegEx] = {}


# Пояснения для клетки: объект на ней и то, что на клетке (огонь, лужа, лёд…). Пусто — обычная земля.
static func for_cell(obj: int, tile: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Variant in [OBJECTS.get(obj, null), TILES.get(tile, null)]:
		if item is String:
			var entry: Dictionary = by_id(item)
			if not entry.is_empty():
				result.append(entry)
		elif item is Dictionary:
			result.append(item)
	return result


static func by_id(id: String) -> Dictionary:
	for entry: Dictionary in LIST:
		if entry["id"] == id:
			return entry
	return {}


# Записи словаря, чьи слова встречаются в тексте, — в порядке первого появления.
# with_nested — добавить в конец и те слова, что встречаются в пояснениях найденных (подсказка в подсказке).
static func find(text: String, with_nested: bool = true) -> Array[Dictionary]:
	var found: Array[Dictionary] = _find_direct(text)
	if with_nested:
		var i: int = 0
		while i < found.size():
			for entry: Dictionary in _find_direct(Loc.t(found[i]["text"])):
				if not _has(found, entry["id"]):
					found.append(entry)
			i += 1
	return found


static func _find_direct(text: String) -> Array[Dictionary]:
	var hits: Array[Array] = []   # [позиция, запись]
	for entry: Dictionary in LIST:
		var m: RegExMatch = _get_regex(entry).search(text)
		if m != null:
			hits.append([m.get_start(), entry])
	hits.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var result: Array[Dictionary] = []
	for hit: Array in hits:
		result.append(hit[1])
	return result


static func _has(list: Array[Dictionary], id: String) -> bool:
	for entry: Dictionary in list:
		if entry["id"] == id:
			return true
	return false


# Регулярное выражение для записи: формы слова, без учёта регистра, только целое слово
static func _get_regex(entry: Dictionary) -> RegEx:
	var id: String = entry["id"]
	if not _regex.has(id):
		var r := RegEx.new()
		r.compile("(?i)(?<![%s])(?:%s)(?![%s])" % [LETTERS, entry["pattern"], LETTERS])
		_regex[id] = r
	return _regex[id]

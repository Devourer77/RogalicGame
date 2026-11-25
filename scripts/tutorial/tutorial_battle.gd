class_name TutorialBattle
extends RefCounted
# Учебный бой: поле, враги и колоды заданы заранее, а первые шаги игрок делает «за руку» —
# можно нажать только то, о чём говорит подсказка. После «Конца хода» играешь сам.
#
# Здесь только данные и счётчик шагов. Сцена боя (scripts/battle.gd) спрашивает
# allows_*(), можно ли действие, и после действия зовёт action_done().
# Клетки записаны как Vector2i(столбец, ряд): столбец 0–11 слева направо, ряд 0 — дальний от героев.

const ARENA: String = "tutorial"
const SEED: int = 2611   # постоянный сид: бой всегда одинаковый

# Поле (см. BattleLogic._arena_tutorial)
const ROCKS: Array[Vector2i] = [Vector2i(2, 6), Vector2i(9, 6), Vector2i(4, 3), Vector2i(10, 2)]
const WATER: Array[Vector2i] = [Vector2i(8, 2), Vector2i(9, 3), Vector2i(8, 3)]

# Враги по порядку и их клетки
const ENEMIES: Array[String] = ["goblin", "goblin_slinger", "goblin"]
const ENEMY_CELLS: Array[Vector2i] = [Vector2i(6, 7), Vector2i(8, 4), Vector2i(3, 3)]

# Колоды: карты приходят именно в этом порядке (первые пять — стартовая рука)
const DECKS: Dictionary[String, Array] = {
	"mage": ["mb_spark", "mb_discharge", "mb_staff", "mb_shield", "mb_shove", "mb_focus", "mb_spark", "mb_dash"],
	"knight": ["kb_sword", "kb_shield", "kb_lunge", "kb_runup", "kb_sword", "kb_taunt", "kb_execute", "kb_ram"],
}

# Шаги. do: "next" — кнопка «Дальше»; "move" — герой hero идёт на клетку cell;
# "hero" — выбрать героя; "card" — сыграть карту card (по клетке cell, если она есть);
# "end_turn" — нажать «Конец хода»; "free" — дальше без ограничений.
const STEPS: Array[Dictionary] = [
	{"do": "next", "title": "Учебный бой",
		"text": "Ты ведёшь двоих: Мага и Рыцаря. У каждого свои карты, мана и шаги. Герои ходят в любом порядке, «Конец хода» — общий."},
	{"do": "next", "title": "Враги показывают ход заранее",
		"text": "Число над врагом — сколько урона он нанесёт в этом раунде. Красные клетки — куда ударит. Наведи мышь на врага — появится его карточка, а следы на полу покажут, куда он пойдёт."},
	{"do": "move", "hero": "knight", "cell": Vector2i(6, 8), "title": "Шаги",
		"text": "Светлые клетки — куда Рыцарь дойдёт в этот ход. Кликни по клетке с меткой: Рыцарь встанет вплотную к гоблину."},
	{"do": "card", "hero": "knight", "card": "kb_sword", "cell": Vector2i(6, 7), "title": "Карты",
		"text": "Внизу — рука Рыцаря. Кликни «Удар мечом» (или нажми цифру на карте), потом гоблина. Карта стоит 1 ману — синие кружки на панели героя слева."},
	{"do": "hero", "hero": "mage", "title": "Второй герой",
		"text": "Гоблин ранен. Теперь Маг: нажми Tab или кликни по Магу."},
	{"do": "card", "hero": "mage", "card": "mb_spark", "cell": Vector2i(6, 7), "title": "Заряд",
		"text": "«Искра осколка» бьёт издалека, ничего не стоит и даёт Магу заряд. Ударь ею того же гоблина."},
	{"do": "card", "hero": "mage", "card": "mb_discharge", "cell": Vector2i(6, 7), "title": "Добивание",
		"text": "«Разрядка» тратит заряд: 4 урона и ещё 2 за каждый заряд. Наведи на гоблина — плашка покажет, что он погибнет. Добей его."},
	{"do": "next", "title": "Прогноз меняется",
		"text": "Гоблин погиб — его удара больше нет. Красные клетки пересчитываются после каждого действия: смотри на них, прежде чем закончить ход."},
	{"do": "hero", "hero": "knight", "title": "Защита",
		"text": "Пращник целится в Рыцаря. Выбери Рыцаря: Tab или клик по нему."},
	{"do": "card", "hero": "knight", "card": "kb_shield", "title": "Блок",
		"text": "Сыграй «Поднять щит». Блок поглощает урон до начала твоего следующего хода."},
	{"do": "end_turn", "title": "Конец хода",
		"text": "Неразыгранные карты уйдут в сброс, в новом ходу рука пополнится. Нажми «Конец хода» — враги сделают ровно то, что показано на поле."},
	{"do": "free", "title": "Дальше сам",
		"text": "Добей остальных. Ошибся — Z отменяет действие, пока ход не закончен. F1 — справка по управлению."},
]

var step: int = 0


# Отряд для учебного боя: полное здоровье, колоды в заданном порядке
static func make_party(heroes: Array[HeroData]) -> Array[RunHero]:
	var party: Array[RunHero] = []
	for hd: HeroData in heroes:
		var rh := RunHero.new(hd.duplicate() as HeroData)
		var deck: Array[CardData] = []
		for id: String in DECKS.get(hd.id, []):
			deck.append(load("res://resources/cards/base/%s.tres" % id) as CardData)
		deck.reverse()   # карты берутся с конца колоды
		rh.deck = deck
		party.append(rh)
	return party


static func enemy_list() -> Array[EnemyData]:
	var list: Array[EnemyData] = []
	for id: String in ENEMIES:
		list.append(load("res://resources/enemies/%s.tres" % id) as EnemyData)
	return list


# Ставит врагов на заданные клетки (вызывать сразу после logic.setup)
static func place_enemies(logic: BattleLogic) -> void:
	for i in mini(logic.enemies.size(), ENEMY_CELLS.size()):
		logic.enemies[i].cell = cell(ENEMY_CELLS[i])


# Столбец и ряд → клетка сетки
static func cell(xy: Vector2i) -> Vector2i:
	return HexMath.from_column(xy.x, xy.y)


func current() -> Dictionary:
	return STEPS[mini(step, STEPS.size() - 1)]


# Ведём за руку, пока не дошли до шага "free"
func guided() -> bool:
	return current()["do"] != "free"


func number_text() -> String:
	return "%d / %d" % [mini(step + 1, STEPS.size()), STEPS.size()]


# Клетка, которую подсвечиваем на поле (или (-1,-1))
func target_cell() -> Vector2i:
	var s: Dictionary = current()
	return cell(s["cell"]) if s.has("cell") else Vector2i(-1, -1)


func allows_move(hero_id: String, c: Vector2i) -> bool:
	if not guided():
		return true
	var s: Dictionary = current()
	return s["do"] == "move" and s["hero"] == hero_id and cell(s["cell"]) == c


func allows_hero(hero_id: String) -> bool:
	if not guided():
		return true
	var s: Dictionary = current()
	return s.has("hero") and s["hero"] == hero_id and s["do"] != "next"


func allows_card(hero_id: String, card_id: String) -> bool:
	if not guided():
		return true
	var s: Dictionary = current()
	return s["do"] == "card" and s["hero"] == hero_id and s["card"] == card_id


func allows_target(c: Vector2i) -> bool:
	if not guided():
		return true
	var s: Dictionary = current()
	return s["do"] == "card" and (not s.has("cell") or cell(s["cell"]) == c)


func allows_end_turn() -> bool:
	return not guided() or current()["do"] == "end_turn"


# Отмена, удержание, сброс — только когда ведение закончилось
func allows_extra() -> bool:
	return not guided()


# Действие выполнено: kind — "move", "hero", "card", "end_turn", "next".
# Возвращает true, если шаг засчитан и пора показать следующий.
func action_done(kind: String, hero_id: String = "", card_id: String = "") -> bool:
	if not guided():
		return false
	var s: Dictionary = current()
	if s["do"] != kind:
		return false
	if s.has("hero") and hero_id != "" and s["hero"] != hero_id:
		return false
	if kind == "card" and s["card"] != card_id:
		return false
	step += 1
	return true

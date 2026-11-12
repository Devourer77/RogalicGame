extends Node
# Прогресс «между забегами»: Отзвуки, Звоны (сложность), улучшения, обереги, Запас карт, история.
# Это autoload (синглтон): доступен из любого скрипта по имени Meta.
# Сохраняется в файл user://progress.cfg (Проект → Открыть папку данных проекта).
# Важно: Meta должна стоять в списке автозагрузки ВЫШЕ Run.

signal changed   # что-то изменилось (Отзвуки, Звон, покупка...) — панели хаба обновляются

const SAVE_VERSION: int = 1

const MAX_BELL: int = 5                 # Звоны 0..5
const BELL_ECHO_BONUS: float = 0.25     # +25% Отзвуков за каждый Звон (ко всей сумме)
const ECHO_PER_ROW: int = 2             # за каждый пройденный ряд карты
const ECHO_ELITE: int = 8               # за убитую элиту
const ECHO_BOSS: int = 20               # за убитого босса
const TROPHY_FALLBACK_ECHOES: int = 15  # вместо трофея, если все обереги уже открыты
const HISTORY_LIMIT: int = 20
const BASE_DECK_CHANGES: int = 2        # изменений стартовой колоды в Караульне без улучшений

# Для проверки: true — все Звоны открыты сразу. В релизе — false.
const DEBUG_ALL_BELLS: bool = false

const UPGRADES: Array[MetaUpgradeData] = [
	preload("res://resources/meta_upgrades/treasury.tres"),
	preload("res://resources/meta_upgrades/medic.tres"),
	preload("res://resources/meta_upgrades/known_path.tres"),
	preload("res://resources/meta_upgrades/second_charm.tres"),
	preload("res://resources/meta_upgrades/mage_hardening.tres"),
	preload("res://resources/meta_upgrades/mage_formulas.tres"),
	preload("res://resources/meta_upgrades/mage_prep.tres"),
	preload("res://resources/meta_upgrades/mage_loadout.tres"),
	preload("res://resources/meta_upgrades/knight_hardening.tres"),
	preload("res://resources/meta_upgrades/knight_techniques.tres"),
	preload("res://resources/meta_upgrades/knight_prep.tres"),
	preload("res://resources/meta_upgrades/knight_loadout.tres"),
]

const CHARMS: Array[RelicData] = [
	preload("res://resources/relics/charm_purse.tres"),
	preload("res://resources/relics/charm_bandage.tres"),
	preload("res://resources/relics/charm_bell.tres"),
	preload("res://resources/relics/charm_shard.tres"),
	preload("res://resources/relics/charm_whetstone.tres"),
	preload("res://resources/relics/charm_candle.tres"),
	preload("res://resources/relics/charm_amulet.tres"),
	preload("res://resources/relics/charm_horn.tres"),
	preload("res://resources/relics/charm_flint.tres"),
	preload("res://resources/relics/charm_decree.tres"),
]

# Что делает каждый Звон (для панели Колокола). Звоны накапливаются.
const BELL_RULES: Array[String] = [
	"Обычная игра.",
	"В каждом обычном бою на 1 врага больше.",
	"Модификатор у одного лишнего врага в каждом бою. (Пока не работает: модификаторов врагов ещё нет.)",
	"Привал лечит 20% вместо 30%.",
	"В каждой волне на 1 врага больше. (Пока не работает: волн ещё нет.)",
	"Элита и босс: +25% HP.",
]

var save_path: String = "user://progress.cfg"   # var, чтобы тесты могли подменить файл

var echoes: int = 0
var bell_max: int = 0          # самый высокий открытый Звон
var bell_chosen: int = 0       # Звон, выбранный на следующий забег
var upgrades: Dictionary = {}  # id улучшения -> купленные ступени
var charms: Array[String] = [] # id открытых оберегов (кроме тех, что открыты с начала)
var charms_chosen: Array[String] = []  # обереги, взятые на следующий забег
var first_boss_killed: bool = false
var card_stock: Dictionary = {}  # id героя -> Array[String] id карт («Запас» Караульни)
var decks: Dictionary = {}       # id героя -> Array[String] id карт своей стартовой колоды
var history: Array[Dictionary] = []  # последние забеги (новые — в конце)
var last_result: Dictionary = {}     # итог только что закончившегося забега


func _ready() -> void:
	load_progress()


# ---------- Отзвуки ----------

# Сколько Отзвуков дать за забег. Звон умножает сумму целиком, включая Отзвуки из событий.
func calc_echoes(rows: int, elites: int, bosses: int, event_echoes: int, bell: int) -> int:
	var base: int = rows * ECHO_PER_ROW + elites * ECHO_ELITE + bosses * ECHO_BOSS + event_echoes
	return ceili(base * (1.0 + BELL_ECHO_BONUS * bell))


func spend(amount: int) -> bool:
	if amount > echoes:
		return false
	echoes -= amount
	save()
	changed.emit()
	return true


func add_echoes(amount: int) -> void:
	echoes += amount
	save()
	changed.emit()


# Зовётся из Run.game_over. summary: rows, elites, bosses, event_echoes, trophy_echoes, bell, complete, victory, seed.
# Возвращает, сколько Отзвуков получено.
func add_run_result(summary: Dictionary) -> int:
	var bell: int = summary.get("bell", 0)
	var event_part: int = summary.get("event_echoes", 0) + summary.get("trophy_echoes", 0)
	var gained: int = calc_echoes(summary.get("rows", 0), summary.get("elites", 0),
			summary.get("bosses", 0), event_part, bell)
	echoes += gained
	var bell_opened: int = -1
	# Новый Звон открывается только за прохождение до конца на самом высоком открытом Звоне
	if summary.get("complete", false) and bell == bell_max and bell_max < MAX_BELL:
		bell_max += 1
		bell_opened = bell_max
	if summary.get("bosses", 0) > 0:
		first_boss_killed = true
	var entry: Dictionary = summary.duplicate()
	entry["echoes"] = gained
	history.append(entry)
	while history.size() > HISTORY_LIMIT:
		history.pop_front()
	last_result = entry.duplicate()
	last_result["bell_opened"] = bell_opened
	save()
	changed.emit()
	return gained


# ---------- Звоны ----------

func is_bell_open(bell: int) -> bool:
	return DEBUG_ALL_BELLS or bell <= bell_max


func choose_bell(bell: int) -> void:
	if is_bell_open(bell):
		bell_chosen = clampi(bell, 0, MAX_BELL)
		save()
		changed.emit()


# ---------- Улучшения ----------

func upgrade_data(id: String) -> MetaUpgradeData:
	for u in UPGRADES:
		if u.id == id:
			return u
	return null


func level(id: String) -> int:
	return upgrades.get(id, 0)


func is_maxed(id: String) -> bool:
	var u: MetaUpgradeData = upgrade_data(id)
	return u == null or level(id) >= u.costs.size()


# Цена следующей ступени; -1, если улучшение куплено до конца
func next_cost(id: String) -> int:
	var u: MetaUpgradeData = upgrade_data(id)
	if u == null or level(id) >= u.costs.size():
		return -1
	return u.costs[level(id)]


func can_buy(id: String) -> bool:
	var cost: int = next_cost(id)
	return cost >= 0 and echoes >= cost


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	echoes -= next_cost(id)
	upgrades[id] = level(id) + 1
	save()
	changed.emit()
	return true


# Сумма эффекта по всем купленным ступеням. hero_id пусто — только улучшения всего отряда.
func effect_total(effect: String, hero_id: String = "") -> int:
	var total: int = 0
	for u in UPGRADES:
		if u.effect == effect and (u.hero_id == "" or u.hero_id == hero_id):
			total += u.value * level(u.id)
	return total


# Сколько ступеней куплено всего (из 21) — по ним зажигаются фонари хаба
func steps_bought() -> int:
	var n: int = 0
	for u in UPGRADES:
		n += mini(level(u.id), u.costs.size())
	return n


func steps_total() -> int:
	var n: int = 0
	for u in UPGRADES:
		n += u.costs.size()
	return n


# Сколько изменений стартовой колоды можно сделать в Караульне
func deck_changes(hero_id: String) -> int:
	return BASE_DECK_CHANGES + effect_total("deck_changes", hero_id)


# id карт, закрытых до покупки «Забытых формул / приёмов». Редкие, которых тут нет, открыты всегда.
func locked_card_ids() -> Dictionary:
	var locked: Dictionary = {}
	for u in UPGRADES:
		if u.effect != "unlock_cards":
			continue
		for step in u.unlock_card_ids.size():
			if step >= level(u.id):
				for card_id in u.unlock_card_ids[step].split(","):
					locked[card_id] = true
	return locked


func is_card_locked(card_id: String) -> bool:
	return locked_card_ids().has(card_id)


# ---------- Обереги ----------

func charm_data(id: String) -> RelicData:
	for c in CHARMS:
		if c.id == id:
			return c
	return null


func is_charm_open(id: String) -> bool:
	var c: RelicData = charm_data(id)
	return c != null and (c.start_open or charms.has(id))


func closed_charms() -> Array[RelicData]:
	var result: Array[RelicData] = []
	for c in CHARMS:
		if not is_charm_open(c.id):
			result.append(c)
	return result


func opened_count() -> int:
	return CHARMS.size() - closed_charms().size()


func charm_slots() -> int:
	return 1 + effect_total("charm_slots")


func can_buy_charm(id: String) -> bool:
	var c: RelicData = charm_data(id)
	return c != null and c.buyable and not is_charm_open(id) and echoes >= c.unlock_cost


func buy_charm(id: String) -> bool:
	if not can_buy_charm(id):
		return false
	echoes -= charm_data(id).unlock_cost
	unlock_charm(id)
	return true


# Общая для всех трёх путей (трофей, тайник, покупка). Сохраняет сразу.
func unlock_charm(id: String) -> void:
	if charm_data(id) != null and not charms.has(id):
		charms.append(id)
	save()
	changed.emit()


# Положить оберег в свободное место или снять. Возвращает true, если что-то изменилось.
func toggle_charm(id: String) -> bool:
	if charms_chosen.has(id):
		charms_chosen.erase(id)
	elif is_charm_open(id) and charms_chosen.size() < charm_slots():
		charms_chosen.append(id)
	else:
		return false
	save()
	changed.emit()
	return true


# Выбранные обереги, которые действительно можно взять (открыты и влезают в места)
func valid_chosen() -> Array[String]:
	var result: Array[String] = []
	for id in charms_chosen:
		if is_charm_open(id) and result.size() < charm_slots():
			result.append(id)
	return result


# ---------- Запас карт (Караульня) ----------

# Записывает обычную карту в Запас героя. Возвращает true, если она записана впервые.
func record_card(hero_id: String, card_id: String) -> bool:
	var list: Array = card_stock.get(hero_id, [])
	if list.has(card_id):
		return false
	list.append(card_id)
	card_stock[hero_id] = list
	save()
	changed.emit()
	return true


func in_stock(hero_id: String, card_id: String) -> bool:
	return card_stock.get(hero_id, []).has(card_id)


func stock_ids(hero_id: String) -> Array[String]:
	var result: Array[String] = []
	result.assign(card_stock.get(hero_id, []))
	return result


# ---------- Сохранение ----------

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.set_value("meta", "echoes", echoes)
	cfg.set_value("meta", "bell_max", bell_max)
	cfg.set_value("meta", "bell_chosen", bell_chosen)
	cfg.set_value("meta", "upgrades", upgrades)
	cfg.set_value("meta", "charms", charms)
	cfg.set_value("meta", "charms_chosen", charms_chosen)
	cfg.set_value("meta", "first_boss_killed", first_boss_killed)
	cfg.set_value("meta", "card_stock", card_stock)
	cfg.set_value("meta", "decks", decks)
	cfg.set_value("meta", "history", history)
	var err: Error = cfg.save(save_path)
	if err != OK:
		push_warning("Не удалось сохранить прогресс: %s" % error_string(err))


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return   # сохранения нет — начинаем с нуля
	if cfg.get_value("meta", "version", 0) > SAVE_VERSION:
		push_warning("Сохранение из более новой версии игры — читаем что получится.")
	echoes = maxi(0, int(cfg.get_value("meta", "echoes", 0)))
	bell_max = clampi(int(cfg.get_value("meta", "bell_max", 0)), 0, MAX_BELL)
	bell_chosen = clampi(int(cfg.get_value("meta", "bell_chosen", 0)), 0, MAX_BELL)
	upgrades = cfg.get_value("meta", "upgrades", {})
	charms.assign(cfg.get_value("meta", "charms", []))
	charms_chosen.assign(cfg.get_value("meta", "charms_chosen", []))
	first_boss_killed = cfg.get_value("meta", "first_boss_killed", false)
	card_stock = cfg.get_value("meta", "card_stock", {})
	decks = cfg.get_value("meta", "decks", {})
	history.assign(cfg.get_value("meta", "history", []))
	if not is_bell_open(bell_chosen):
		bell_chosen = 0


# «Новый прогресс»: стирает всё и сохраняет чистое состояние.
func reset() -> void:
	echoes = 0
	bell_max = 0
	bell_chosen = 0
	upgrades = {}
	charms.clear()
	charms_chosen.clear()
	first_boss_killed = false
	card_stock = {}
	decks = {}
	history.clear()
	last_result = {}
	# Файл сохранения стираем: меню снова покажет «Начать», как при первом запуске
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	changed.emit()


# ---------- Стартовая колода героя (Караульня) ----------

# Текущая стартовая колода героя (id): сохранённая правка или базовая
func current_deck_ids(hero: HeroData) -> Array[String]:
	var base: Array[String] = Loadout.ids_of(hero.starter_deck)
	var saved: Array[String] = []
	saved.assign(decks.get(hero.id, []))
	if saved.is_empty():
		return base
	return Loadout.validate(base, saved, stock_ids(hero.id), Loadout.rare_ids(hero), deck_changes(hero.id))


# Стартовая колода героя для нового забега
func start_deck(hero: HeroData) -> Array[CardData]:
	var ids: Array[String] = current_deck_ids(hero)
	var cards: Array[CardData] = Loadout.resolve(hero, ids)
	if cards.size() != ids.size():
		return hero.starter_deck.duplicate()   # какой-то карты больше нет в игре — базовая
	return cards

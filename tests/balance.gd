extends SceneTree
# Замер баланса ботом: играет бои без 3D-сцены, через BattleLogic, и считает,
# сколько побед, сколько раундов длится бой и сколько здоровья теряют герои.
# Нужен после каждого этапа правок: «до» и «после» сравниваются по этой таблице.
#
# Запуск (из папки проекта):
#   godot --headless --path . -s tests/balance.gd            — 200 боёв на каждую строку
#   godot --headless --path . -s tests/balance.gd -- 50      — быстрый прогон, 50 боёв
#   godot --headless --path . -s tests/balance.gd -- 40 big    — только элиты и боссы
#   godot --headless --path . -s tests/balance.gd -- 100 relics — ряд 3 без реликвий и с каждой по очереди
# Результат печатается в окно Output / консоль и пишется в user://balance.txt
# (в Godot: Проект → Открыть папку данных проекта).
#
# Как играет бот (простая жадная тактика, он не гений, зато одинаков до и после правок):
# - пробует каждую карту в руке на копии боя и выбирает ту, что даст больше всего:
#   урон врагам, убийства, блок (если по герою будет удар) минус потери своих;
# - если ничего полезного сыграть нельзя и герой стоит в зоне взрыва жабы — отходит
#   из неё (иначе бот вечно стоит рядом с жабой на 1 HP и не решается её добить);
# - иначе подходит ближе к врагам (маг останавливается в 4 клетках, рыцарь идёт вплотную);
# - потом «Конец хода».

const FIRST_ROWS: int = 5          # обычные бои на рядах карты 0–4
const ELITE_ROW: int = 5           # ряд элитного боя (Run.MAP_ROWS - 3)
const BOSS_ROW: int = 7            # ряд босса
const DEFAULT_BATTLES: int = 200   # боёв на каждую строку таблицы
const MAX_TURNS: int = 40          # дольше — считаем бой «зависшим»
const MAX_ACTIONS_PER_TURN: int = 14   # предохранитель от бесконечного цикла у героя
const MAX_CANDIDATES: int = 12     # сколько целей одной карты пробуем на копии
const MIN_GAIN: float = 0.5        # карта не стоит того, если выигрыш меньше
const MAGE_KEEP_DISTANCE: int = 4  # маг не подходит ближе этого расстояния

var bot_rng := RandomNumberGenerator.new()   # свой генератор бота: игровой не трогаем


func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	var battles: int = DEFAULT_BATTLES
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		battles = maxi(1, args[0].to_int())

	# Строки таблицы: название, ряд карты, босс, элита
	var configs: Array[Dictionary] = []
	for r in FIRST_ROWS:
		configs.append({"name": "ряд %d" % r, "row": r, "boss": false, "elite": false})
	# Каждая элита и каждый босс из пулов акта — своей строкой
	for enc: EncounterData in run.ELITE_POOL:
		configs.append({"name": enc.title.left(9), "row": ELITE_ROW, "boss": false, "elite": true, "encounter": enc})
	for enc: EncounterData in run.BOSS_POOL:
		configs.append({"name": enc.title.left(9), "row": BOSS_ROW, "boss": true, "elite": false, "encounter": enc})
	# Бои с особой целью (ряд 3). Бот целей не понимает и просто дерётся — строка показывает,
	# насколько цель усложняет обычную драку (ритуал призывает, вода замедляет и т. д.)
	configs.append({"name": "ритуал", "row": 3, "boss": false, "elite": false, "objective": BattleLogic.Objective.RITUAL})
	configs.append({"name": "прорыв", "row": 3, "boss": false, "elite": false, "objective": BattleLogic.Objective.BREAKTHROUGH})
	configs.append({"name": "вода", "row": 3, "boss": false, "elite": false, "objective": BattleLogic.Objective.RISING_WATER})
	if args.has("big"):   # только элиты и боссы: -- 40 big
		configs = configs.filter(func(c: Dictionary) -> bool: return c.has("encounter"))
	if args.has("relics"):
		configs.clear()
		configs.append({"name": "без", "row": 3, "boss": false, "elite": false})
		for r: RelicData in run.all_relics():
			configs.append({"name": r.id.left(7), "row": 3, "boss": false, "elite": false, "relics": [r]})

	var started: int = Time.get_ticks_msec()
	var lines: PackedStringArray = []
	lines.append("Замер баланса: %d боёв на строку, стартовые колоды, полное HP" % battles)
	lines.append("%-7s | %7s | %-22s | %9s | %11s | %s" % ["бой", "побед %", "раундов ср (мин–макс)",
			"HP мага", "HP рыцаря", "завис"])
	for ci in configs.size():
		var cfg: Dictionary = configs[ci]
		var wins: int = 0
		var stuck: int = 0
		var rounds_sum: int = 0
		var rounds_min: int = 9999
		var rounds_max: int = 0
		var loss_mage: int = 0
		var loss_knight: int = 0
		for i in battles:
			var res: Dictionary = _play_battle(run, 1000 * (ci + 1) + i + 1, cfg)
			if res["won"]: wins += 1
			if res["stuck"]: stuck += 1
			rounds_sum += res["rounds"]
			rounds_min = mini(rounds_min, res["rounds"])
			rounds_max = maxi(rounds_max, res["rounds"])
			loss_mage += res["loss_mage"]
			loss_knight += res["loss_knight"]
		var n: float = float(battles)
		var rounds_text: String = "%.1f (%d–%d)" % [rounds_sum / n, rounds_min, rounds_max]
		lines.append("%-7s | %6.1f%% | %-22s | %9.1f | %11.1f | %d" % [cfg["name"],
				100.0 * wins / n, rounds_text, loss_mage / n, loss_knight / n, stuck])
	lines.append("Время замера: %.1f с" % ((Time.get_ticks_msec() - started) / 1000.0))

	var text: String = "\n".join(lines)
	print("\n===== БАЛАНС =====\n" + text + "\n==================")
	var f := FileAccess.open("user://balance.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(text + "\n")
		f.close()
		print("Таблица записана в ", ProjectSettings.globalize_path("user://balance.txt"))
	quit(0)


# Один бой от начала до конца. Возвращает {won, stuck, rounds, loss_mage, loss_knight}
func _play_battle(run: Node, seed_value: int, cfg: Dictionary) -> Dictionary:
	run.start_new_run(seed_value)
	bot_rng.seed = seed_value
	if cfg.has("encounter"):
		# Строка про конкретную элиту или босса: подменяем выбор забега
		if cfg["boss"]:
			run.run_boss = cfg["encounter"]
		else:
			run.run_elites = [cfg["encounter"], cfg["encounter"]] as Array[EncounterData]
	var enemies: Array[EnemyData] = run._make_encounter(cfg["row"], cfg["boss"], cfg["elite"])
	var arena: String = run._encounter_arena(cfg["boss"])
	var objective: int = cfg.get("objective", BattleLogic.Objective.KILL_ALL)
	if objective == BattleLogic.Objective.RITUAL:
		var has_caster: bool = false
		for e in enemies:
			has_caster = has_caster or BattleLogic.RITUAL_CASTERS.has(e.id)
		if not has_caster:
			enemies.append(load("res://resources/enemies/goblin_shaman.tres"))
	if objective == BattleLogic.Objective.BREAKTHROUGH and arena == "gat":
		arena = "grove"   # на гати прорыва не бывает
	var relic_list: Array[String] = []
	for r: RelicData in cfg.get("relics", []):
		relic_list.append(r.id)
	var b := BattleLogic.new()
	b.setup(12, 12, run.rng, run.party, enemies, arena, objective, relic_list)
	b.start()
	var stuck: bool = false
	while not b.is_over:
		if b.turn >= MAX_TURNS:
			stuck = true
			break
		# Сначала все, кто стоит у жабы, отходят — иначе первый герой не решится
		# добить её, пока рядом второй, а второй отойдёт, когда уже поздно
		for h in b.living_heroes():
			_leave_blast_zone(b, h)
		for h in b.living_heroes():
			_play_hero(b, h)
			if b.is_over:
				break
		if b.is_over:
			break
		for h in b.living_heroes():
			_keep_best(b, h)
		b.end_turn()
	var result: Dictionary = {"won": b.won, "stuck": stuck, "rounds": b.turn,
			"loss_mage": 0, "loss_knight": 0}
	for h in b.heroes:
		var lost: int = h.max_hp - maxi(0, h.hp)
		if h.hero_data.gains_rage:   # рыцарь — тот, у кого ярость
			result["loss_knight"] = lost
		else:
			result["loss_mage"] = lost
	return result


# Ход одного героя: играем лучшие карты, пока есть смысл, потом подходим к врагам
func _play_hero(b: BattleLogic, h: BattleUnit) -> void:
	for step in MAX_ACTIONS_PER_TURN:
		if b.is_over or not h.is_alive():
			return
		var threat: Dictionary = _threat(b)
		var base: float = _score(b, threat)
		var best_gain: float = MIN_GAIN
		var best_idx: int = -1
		var best_target: Vector2i = Vector2i.ZERO
		for idx in h.hand.size():
			if not b.can_play(h, idx):
				continue
			for t in _candidates(b, h, idx):
				var sim: BattleLogic = _sim_with_hand(b, h)
				var sh: BattleUnit = _same_unit(sim, h)
				if not sim.play_card(sh, idx, t):
					continue
				var gain: float = _score(sim, threat) - base - 0.05 * b.card_cost(h, idx)
				if gain > best_gain:
					best_gain = gain
					best_idx = idx
					best_target = t
		if best_idx >= 0:
			b.play_card(h, best_idx, best_target)
			continue
		if _leave_blast_zone(b, h):
			continue
		if not _approach(b, h):
			return


# Радиус взрыва жабы: 1, а с 2+ стаками «Раздувания» — 2
func _blast_radius(e: BattleUnit) -> int:
	return 2 if e.inflation >= 2 else 1


func _in_blast_zone(b: BattleLogic, c: Vector2i) -> bool:
	for e in b.living_enemies():
		if e.data.inflation and HexMath.distance(e.cell, c) <= _blast_radius(e):
			return true
	return false


# Герой в зоне будущего взрыва жабы — шаг на ближайшую к врагам клетку вне всех зон.
# true — сдвинулся (можно снова пробовать карты, например добить жабу издалека).
func _leave_blast_zone(b: BattleLogic, h: BattleUnit) -> bool:
	if not _in_blast_zone(b, h.cell):
		return false
	var moves: Dictionary = b.get_move_targets(h)
	var best_cell: Vector2i = h.cell
	var best_dist: int = 9999
	for c: Vector2i in moves.keys():
		if _in_blast_zone(b, c):
			continue
		var d: int = _dist_to_enemy(b, c)
		if d < best_dist:
			best_dist = d
			best_cell = c
	if best_cell == h.cell:
		return false
	return b.move_hero(h, best_cell)


# Копия боя вместе с рукой и колодой героя (clone() их не копирует)
func _sim_with_hand(b: BattleLogic, h: BattleUnit) -> BattleLogic:
	var sim: BattleLogic = b.clone()
	var sh: BattleUnit = _same_unit(sim, h)
	sh.hand.assign(h.hand)
	sh.draw_pile.assign(h.draw_pile)
	sh.discard_pile.assign(h.discard_pile)
	return sim


func _same_unit(sim: BattleLogic, u: BattleUnit) -> BattleUnit:
	for x: BattleUnit in sim.heroes + sim.enemies:
		if x.id == u.id:
			return x
	return null


# Куда стоит целиться картой. SELF — на себя; иначе цели, где область задевает врага
# (до MAX_CANDIDATES), а если таких нет — пара случайных (стена, трясина, лёд и т. п.)
func _candidates(b: BattleLogic, h: BattleUnit, idx: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var card: CardData = h.hand[idx]
	if card.shape == CardData.Shape.SELF:
		result.append(h.cell)
		return result
	var targets: Array[Vector2i] = b.get_card_targets(h, idx)
	if targets.is_empty():
		return result
	var hits: Array[Vector2i] = []
	var others: Array[Vector2i] = []
	for t in targets:
		var hit: bool = false
		for c in b.get_card_area(h, idx, t):
			var u: BattleUnit = b.unit_at(c)
			if u != null and not u.is_hero:
				hit = true
				break
		if hit:
			hits.append(t)
		else:
			others.append(t)
	_shuffle(hits)
	_shuffle(others)
	for t in hits.slice(0, MAX_CANDIDATES):
		result.append(t)
	if result.is_empty():
		for t in others.slice(0, 3):
			result.append(t)
	return result


# Оценка положения: чем меньше врагов и их здоровья и чем здоровее герои, тем больше.
# Блок ценен, пока по герою ждут удар (threat), сверх этого почти ничего не стоит.
func _score(b: BattleLogic, threat: Dictionary) -> float:
	var s: float = 0.0
	for e in b.enemies:
		if e.is_alive():
			s -= e.hp + 0.3 * e.block + 4.0
	for h in b.heroes:
		if h.is_alive():
			s += h.hp + minf(h.block, threat.get(h.id, 0)) * 0.8 + 0.05 * h.block
		else:
			s -= 10.0
	return s


# Сколько урона по каждому герою ждёт в ход врагов (по прогнозу игры), id героя → урон
func _threat(b: BattleLogic) -> Dictionary:
	var threat: Dictionary = {}
	for f in b.forecast_enemies():
		var e: BattleUnit = f["enemy"]
		var cells: Array = f["attack"]
		if cells.is_empty():
			continue
		var dmg: int = b.enemy_attack(e).damage + e.bonus_damage
		for h in b.living_heroes():
			if cells.has(h.cell):
				threat[h.id] = threat.get(h.id, 0) + dmg
	return threat


# Шаг к ближайшему врагу. true — герой сдвинулся (можно пробовать карты ещё раз)
func _approach(b: BattleLogic, h: BattleUnit) -> bool:
	var now: int = _dist_to_enemy(b, h.cell)
	if now == 9999:
		return false
	if not h.hero_data.gains_rage and now <= MAGE_KEEP_DISTANCE:
		return false   # маг держится на расстоянии
	var moves: Dictionary = b.get_move_targets(h)
	var best_cell: Vector2i = h.cell
	var best_dist: int = now
	for c: Vector2i in moves.keys():
		if _in_blast_zone(b, c) and not _in_blast_zone(b, h.cell):
			continue   # в зону взрыва жабы не заходим
		var d: int = _dist_to_enemy(b, c)
		if d < best_dist:
			best_dist = d
			best_cell = c
	if best_cell == h.cell:
		return false
	return b.move_hero(h, best_cell)


func _dist_to_enemy(b: BattleLogic, c: Vector2i) -> int:
	var best: int = 9999
	for e in b.living_enemies():
		best = mini(best, HexMath.distance(e.cell, c))   # шаги по сотам, а не |dx| + |dy|
	return best


# Перемешивание своим генератором (игровой не трогаем)
func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j: int = bot_rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp


# Режим KEEP_2: бот удерживает самые дорогие несыгранные карты (до KEEP_LIMIT)
func _keep_best(b: BattleLogic, h: BattleUnit) -> void:
	if BattleLogic.DRAW_MODE != BattleLogic.DrawMode.KEEP_2:
		return
	var order: Array[int] = []
	for i in h.hand.size():
		order.append(i)
	order.sort_custom(func(x: int, y: int) -> bool: return h.hand[x].cost > h.hand[y].cost)
	for i in mini(BattleLogic.KEEP_LIMIT, order.size()):
		b.toggle_keep(h, order[i])

class_name EnemyAI
extends RefCounted
# ИИ врагов. Решает три вещи: в каком порядке враги ходят, куда встать и как ударить.
#
# Принцип: враг не «ищет ближайшую клетку, откуда достанет», а оценивает удар по тому,
# что он сделает. Оценка считается на копии боя (BattleLogic.clone()) — копия сама знает
# про толчки, взрывы бочек, блок и «Живой бастион», заново писать эти правила не нужно.
#
# Случайности здесь нет: при равных очках побеждает тот вариант, который перебирается раньше
# (клетки — в порядке поиска пути, стороны — в порядке HexMath.DIRS). Поэтому прогноз хода
# врагов (forecast_enemies) остаётся точным.
#
# Очки: больше — лучше. Все числа — константами, чтобы крутить баланс без правки логики.

const AI_STEP: int = 4            # цена одного шага
const AI_HERO_HP: int = 3         # за каждый HP, снятый с героев (после блока)
const AI_HERO_BLOCK: int = 1      # за каждую единицу сбитого блока героев
const AI_KILL: int = 60           # герой падает
const AI_BOTH_HEROES: int = 10    # ранены оба героя
const AI_HAZARD: int = 12         # герой после удара стоит в огне, газе или лаве
const AI_ALLY_HP: int = 4         # штраф за каждый HP своих
const AI_SELF_HP: int = 1         # штраф за каждый HP самого врага: рискует собой ради удара (руна под героем,
                                  # бочка рядом), но не бежит на верную смерть — см. AI_ALLY_KILL
const AI_ALLY_KILL: int = 40      # штраф, если погибает свой (или сам враг)
const AI_FIRE_UNDER: int = 80     # штраф, если сам стоит в огне
const AI_TOO_CLOSE: int = 40      # штраф стрелку, который встал ближе своей дистанции
const AI_SIM_CANDIDATES: int = 10 # сколько лучших по предварительной оценке ударов проверять на копии боя
const AI_PRE_HERO: int = 25       # предварительная оценка: за каждого героя в клетках удара
const AI_NEAR_BARREL: int = 6     # штраф за клетку в радиусе взрыва бочки
const AI_NEAR_TOAD: int = 6       # штраф за клетку рядом с раздутой жабой
const AI_ON_GAS: int = 30         # штраф за клетку с газом
const AI_HUNTER_PREY: int = 20    # охотник: бонус, если удар ранит его добычу
const AI_GUARD_NEAR: int = 25     # телохранитель: бонус за клетку вплотную к подопечному
const AI_FLANK: int = 6           # клещи: встал вплотную к герою с другой стороны, чем свой
const GUARD_RANGE: int = 3        # дальше этого подопечного телохранитель не замечает
const ALLY_BUFF_NEXT_ATTACK: int = 100  # «зов»: за своего, который в следующем раунде ударит
const ALLY_BUFF_NEXT_AURA: int = 30     # …и за своего, у которого в следующем раунде тоже «зов»


# ---------- Порядок ходов ----------

# Сначала ходят враги, ближние к героям (по реальному пути), потом дальние. Те, у кого в этом
# раунде «зов», — последними: они считают место по тому, где остальные уже встали.
# При равенстве — порядок списка врагов.
static func turn_order(l: BattleLogic) -> Array[BattleUnit]:
	var dist: Dictionary[Vector2i, int] = l._distance_map(l.living_heroes(), null)
	var rows: Array[Dictionary] = []
	for i in l.enemies.size():
		var e: BattleUnit = l.enemies[i]
		if not e.is_alive():
			continue
		var aura: int = 1 if l.enemy_attack(e).shape == EnemyData.Attack.AURA else 0
		rows.append({"e": e, "aura": aura, "d": dist.get(e.cell, 999), "i": i})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["aura"] != b["aura"]:
			return a["aura"] < b["aura"]
		if a["d"] != b["d"]:
			return a["d"] < b["d"]
		return a["i"] < b["i"])
	var order: Array[BattleUnit] = []
	for r: Dictionary in rows:
		order.append(r["e"])
	return order


# ---------- Главный выбор ----------

# Решение врага e на этот ход. Возвращает:
#   cell — куда встать, dir — куда бить (ZERO — ударить не получится),
#   path — путь до клетки, reason — причина для игрока («Добьёт Мага»),
#   notable — стоит ли писать её в журнал.
static func choose(l: BattleLogic, e: BattleUnit, atk: EnemyAttackData) -> Dictionary:
	# Опутанный враг стоит на месте, но ударить может
	var options: Dictionary[Vector2i, Array] = l.reachable_cells(e, 0 if e.entangled > 0 else l.enemy_move_range(e))
	var result: Dictionary = _decide(l, e, atk, options)
	result["path"] = options[result["cell"]]
	return result


static func _decide(l: BattleLogic, e: BattleUnit, atk: EnemyAttackData,
		options: Dictionary[Vector2i, Array]) -> Dictionary:
	var ctx: Dictionary = _context(l, e)
	var result: Dictionary = {"cell": e.cell, "dir": Vector2i.ZERO, "reason": "", "notable": false}

	if atk.shape == EnemyData.Attack.AURA and atk.is_summon_only():
		# Призыв: подходим к героям как обычно, подмога встанет вокруг на новом месте
		var approach: Dictionary = _best_approach(l, e, options, [] as Array[BattleUnit], l.living_heroes(), ctx)
		result["cell"] = approach["cell"]
		result["reason"] = "Призовёт: %s ×%d" % [atk.summon.title.to_lower(), atk.summon_count]
		return result

	if atk.shape == EnemyData.Attack.AURA:
		var aura: Dictionary = _best_aura(l, e, atk, options, ctx)
		result["cell"] = aura["cell"]
		result["reason"] = "Зов: усилит %s" % _count_allies(aura["allies"]) if aura["allies"] > 0 else "Зов: некого усилить"
		return result

	var heroes: Array[BattleUnit] = l.living_heroes()
	var taunters: Array[BattleUnit] = []
	for h in heroes:
		if h.taunt:
			taunters.append(h)

	# Провокация: если можно достать героя с провокацией — выбираем только из ударов по нему
	var provoked: bool = false
	var best: Dictionary = {}
	if not taunters.is_empty():
		best = _best_strike(l, e, atk, options, taunters, false, ctx)
		provoked = best["dir"] != Vector2i.ZERO
	if not provoked:
		best = _best_strike(l, e, atk, options, heroes, true, ctx)

	if best["dir"] != Vector2i.ZERO:
		result["cell"] = best["cell"]
		result["dir"] = best["dir"]
		# Круговой удар бьёт во все стороны сразу — просто поворачиваем врага лицом к ближайшей цели
		if atk.shape == EnemyData.Attack.AROUND:
			result["dir"] = _face_dir(best["cell"], heroes)
		var info: Dictionary = best["info"]
		result["reason"] = _strike_reason(info, provoked, ctx)
		result["notable"] = info["kill"] != "" or info["push"] != "" or info["obj"] != "" \
				or (ctx["prey"] != null and info["prey_hurt"])
		return result

	# Ударить некого — подходим
	var move: Dictionary = _best_approach(l, e, options, taunters, heroes, ctx)
	result["cell"] = move["cell"]
	result["reason"] = move["reason"]
	return result


# Всё, что нужно знать об обстановке, считается один раз на врага
static func _context(l: BattleLogic, e: BattleUnit) -> Dictionary:
	var barrel: Dictionary[Vector2i, bool] = {}
	for c: Vector2i in l.objects.keys():
		if l.object_at(c) == BattleLogic.Obj.BARREL:
			for t in HexMath.cluster(c):
				barrel[t] = true
	var toad: Dictionary[Vector2i, bool] = {}
	for other in l.living_enemies():
		if other == e or not other.data.inflation:
			continue
		# Жаба, которая вот-вот лопнет: раздутая, тлеющая или с горящим фитилём (взрыв — кольцо 1, при 2+ стаках — 2)
		var burst_soon: bool = other.inflation >= 2 or other.fuse > 0 or l.is_smoldering(other)
		if burst_soon:
			for t in HexMath.in_range(other.cell, 2 if other.inflation >= 2 else 1):
				toad[t] = true
	return {"barrel": barrel, "toad": toad, "ward": _ward(l, e), "prey": _prey(l, e)}


# Подопечный телохранителя: ближайший свой стрелок или зовущий не дальше GUARD_RANGE
static func _ward(l: BattleLogic, e: BattleUnit) -> BattleUnit:
	if e.data.ai_style != EnemyData.AiStyle.GUARD:
		return null
	var ward: BattleUnit = null
	for other in l.living_enemies():
		if other == e or not (other.data.keep_distance > 0 or _has_aura(other.data)):
			continue
		var d: int = HexMath.distance(e.cell, other.cell)
		if d > GUARD_RANGE:
			continue
		if ward == null or d < HexMath.distance(e.cell, ward.cell):
			ward = other
	return ward


static func _has_aura(d: EnemyData) -> bool:
	for a in d.cycle:
		if a.shape == EnemyData.Attack.AURA:
			return true
	return false


# Добыча охотника: самый раненый герой (по доле HP); если все ранены одинаково — ближайший
static func _prey(l: BattleLogic, e: BattleUnit) -> BattleUnit:
	if e.data.ai_style != EnemyData.AiStyle.HUNTER:
		return null
	var prey: BattleUnit = null
	for h in l.living_heroes():
		if prey == null:
			prey = h
			continue
		var a: int = h.hp * prey.max_hp       # доли hp/max_hp сравниваем без дробей
		var b: int = prey.hp * h.max_hp
		if a < b or (a == b and HexMath.distance(e.cell, h.cell) < HexMath.distance(e.cell, prey.cell)):
			prey = h
	return prey


# Цена клетки как места (не считая шагов): огонь, газ, бочки и жабы рядом, подопечный рядом
static func _place_value(l: BattleLogic, c: Vector2i, ctx: Dictionary) -> int:
	var v: int = 0
	var tile: int = l.tile_at(c)
	if tile == BattleLogic.Tile.FIRE:
		v -= AI_FIRE_UNDER
	elif tile == BattleLogic.Tile.GAS:
		v -= AI_ON_GAS
	if ctx["barrel"].has(c):
		v -= AI_NEAR_BARREL
	if ctx["toad"].has(c):
		v -= AI_NEAR_TOAD
	var ward: BattleUnit = ctx["ward"]
	if ward != null and HexMath.distance(c, ward.cell) == 1:
		v += AI_GUARD_NEAR
	return v


# ---------- Удар ----------

# Лучший удар из всех (клетка, сторона), задевающих кого-то из targets.
# include_objects — рассматривать и удары по бочке или дереву, даже если героя в клетках нет
# (взрыв или падение дерева заденет героя рядом).
# Возвращает {"cell", "dir", "info"}; dir == ZERO, если бить невыгодно или некого.
static func _best_strike(l: BattleLogic, e: BattleUnit, atk: EnemyAttackData,
		options: Dictionary[Vector2i, Array], targets: Array[BattleUnit], include_objects: bool,
		ctx: Dictionary) -> Dictionary:
	var none: Dictionary = {"cell": e.cell, "dir": Vector2i.ZERO, "info": {}}
	if targets.is_empty():
		return none
	var dirs: Array[Vector2i] = []
	if atk.shape == EnemyData.Attack.AROUND:
		dirs.append(HexMath.DIRS[0])   # кругу всё равно, куда смотреть — не перебираем шесть одинаковых
	else:
		dirs.assign(HexMath.DIRS)

	# 1. Предварительная оценка (дёшево): шаги, место, число героев в клетках удара
	var candidates: Array[Dictionary] = []
	var order: int = 0
	var heroes: Array[BattleUnit] = l.living_heroes()
	for c: Vector2i in options:
		var base: int = -(options[c].size() - 1) * AI_STEP + _place_value(l, c, ctx)
		if e.data.keep_distance > 0:
			var near: int = 999
			for h in heroes:
				near = mini(near, HexMath.distance(c, h.cell))
			if near < e.data.keep_distance:
				base -= AI_TOO_CLOSE
			base += mini(near, atk.attack_range)   # при прочих равных — подальше
		for d: Vector2i in dirs:
			var cells: Array[Vector2i] = l._attack_cells(e, atk, c, d)
			var hits: int = 0
			var hits_target: bool = false
			for h in heroes:
				if cells.has(h.cell):
					hits += 1
			for t in targets:
				if cells.has(t.cell):
					hits_target = true
			var has_object: bool = false
			if include_objects and not hits_target:
				for t in cells:
					if l._is_breakable(t):
						has_object = true
						break
			if not hits_target and not has_object:
				order += 1
				continue
			candidates.append({"cell": c, "dir": d, "pre": base + hits * AI_PRE_HERO, "base": base, "order": order,
					"cells": cells})
			order += 1
	if candidates.is_empty():
		return none
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["pre"] != b["pre"]:
			return a["pre"] > b["pre"]
		return a["order"] < b["order"])

	# 2. Лучшие проверяем на копии боя
	var best: Dictionary = none
	var best_total: int = -1000000
	var best_front: bool = false
	for i in mini(AI_SIM_CANDIDATES, candidates.size()):
		var cand: Dictionary = candidates[i]
		var c: Vector2i = cand["cell"]
		var d: Vector2i = cand["dir"]
		var info: Dictionary = _evaluate(l, e, atk, c, d, ctx["prey"])
		if info["value"] <= 0:
			continue   # удар никому не выгоден (бьёт своих сильнее, чем героев) — не бьём
		var total: int = info["value"] + cand["base"] + _flank(l, e, atk, c, cand["cells"])
		# Дуга: при равных вариантах замахиваемся так, чтобы цель была прямо перед врагом,
		# а не на краю дуги — иначе героя отбрасывает вбок, а не от врага
		var front: bool = false
		if atk.shape == EnemyData.Attack.SWEEP:
			for t in targets:
				front = front or t.cell == c + d
		if total > best_total or (total == best_total and front and not best_front):
			best_total = total
			best_front = front
			info["ward_near"] = ctx["ward"] != null and HexMath.distance(c, ctx["ward"].cell) == 1
			best = {"cell": c, "dir": d, "info": info}
	return best


# Клещи: враг встал вплотную к герою, а свой уже стоит рядом с ним с другой стороны
static func _flank(l: BattleLogic, e: BattleUnit, atk: EnemyAttackData, c: Vector2i,
		cells: Array[Vector2i]) -> int:
	if atk.shape != EnemyData.Attack.MELEE and atk.shape != EnemyData.Attack.SWEEP:
		return 0
	for h in l.living_heroes():
		if not cells.has(h.cell) or HexMath.distance(c, h.cell) != 1:
			continue
		for other in l.living_enemies():
			if other != e and HexMath.distance(other.cell, h.cell) == 1 and HexMath.distance(other.cell, c) >= 2:
				return AI_FLANK
	return 0


# Что сделает удар: проигрываем его на копии боя и сравниваем с настоящим.
# Возвращает {"value": очки удара (без шагов и места), "kill": имя павшего героя,
# "push": текст про толчок в беду, "obj": текст про бочку или дерево, "both": ранены оба,
# "hurt": имя героя, которому больнее всего, "prey_hurt": ранена ли добыча охотника}.
static func _evaluate(l: BattleLogic, e: BattleUnit, atk: EnemyAttackData, cell: Vector2i,
		dir: Vector2i, prey: BattleUnit) -> Dictionary:
	var sim: BattleLogic = l.clone()
	var sim_e: BattleUnit = sim.enemies[l.enemies.find(e)]
	sim_e.cell = cell
	sim._enemy_strike(sim_e, atk, dir)

	var info: Dictionary = {"value": 0, "kill": "", "push": "", "obj": "", "both": false,
			"hurt": "", "prey_hurt": false}
	var value: int = 0
	var wounded: int = 0
	var worst: int = 0
	var direct: int = atk.damage + e.bonus_damage
	for i in l.heroes.size():
		var h: BattleUnit = l.heroes[i]
		var sh: BattleUnit = sim.heroes[i]
		if not h.is_alive():
			continue
		var lost: int = h.hp - maxi(sh.hp, 0)
		var block_lost: int = maxi(h.block - sh.block, 0)
		value += lost * AI_HERO_HP + block_lost * AI_HERO_BLOCK
		if lost > 0:
			wounded += 1
			if lost > worst:
				worst = lost
				info["hurt"] = h.title
			if prey != null and h == prey:
				info["prey_hurt"] = true
		if not sh.is_alive():
			value += AI_KILL
			if info["kill"] == "":
				info["kill"] = h.title
			continue
		# Героя отбросило или притянуло: не в беду ли?
		var hazard: String = _hazard_name(sim, sh.cell)
		if hazard != "" and hazard != _hazard_name(l, h.cell):
			value += AI_HAZARD
		var pushed: bool = atk.push > 0 or atk.pull > 0
		var extra: bool = lost + block_lost > direct   # больше удара — значит, ещё и врезался или влетел в трясину
		if pushed and (sh.cell != h.cell or extra) and info["push"] == "":
			var verb: String = "Притянет" if atk.pull > 0 else "Толкнёт"
			if hazard != "":
				info["push"] = "%s %s %s" % [verb, _acc(h.title), hazard]
			elif extra:
				var step: Vector2i = dir if atk.push > 0 else -dir
				var next: Vector2i = sh.cell + step
				var where: String = "в трясину" if sim.object_at(next) == BattleLogic.Obj.BOG else "о преграду"
				info["push"] = "%s %s %s" % [verb, _acc(h.title), where]
	if wounded >= 2:
		value += AI_BOTH_HEROES
		info["both"] = true
	if prey != null and info["prey_hurt"]:
		value += AI_HUNTER_PREY

	# Бочка или дерево, которых после удара нет
	var obj_kind: int = BattleLogic.Obj.NONE
	for c: Vector2i in l.objects.keys():
		var kind: int = l.object_at(c)
		if (kind == BattleLogic.Obj.BARREL or kind == BattleLogic.Obj.TREE) and sim.object_at(c) != kind:
			obj_kind = kind
			break
	if obj_kind != BattleLogic.Obj.NONE and info["hurt"] != "":
		var victim: String = info["hurt"]
		if obj_kind == BattleLogic.Obj.BARREL:
			info["obj"] = "Подорвёт бочку у %s" % _gen(victim)
		else:
			info["obj"] = "Повалит дерево на %s" % _acc(victim)

	# Свои и сам враг: штраф за потери
	for i in l.enemies.size():
		var u: BattleUnit = l.enemies[i]
		var su: BattleUnit = sim.enemies[i]
		if not u.is_alive():
			continue
		value -= (u.hp - maxi(su.hp, 0)) * (AI_SELF_HP if u == e else AI_ALLY_HP)
		if not su.is_alive():
			value -= AI_ALLY_KILL
	info["value"] = value
	return info


# «в огонь», «в газ», «в лаву» — если клетка опасна; иначе пусто
static func _hazard_name(l: BattleLogic, c: Vector2i) -> String:
	if l.tile_at(c) == BattleLogic.Tile.FIRE:
		return "в огонь"
	if l.tile_at(c) == BattleLogic.Tile.GAS:
		return "в газ"
	if l.object_at(c) == BattleLogic.Obj.LAVA:
		return "в лаву"
	return ""


# ---------- Подход и «зов» ----------

# Ударить некого: идём к цели. Цель — герой с провокацией, иначе добыча охотника, иначе
# ближайший герой. Телохранитель держится у подопечного. Огня, газа, бочек избегаем.
static func _best_approach(l: BattleLogic, e: BattleUnit, options: Dictionary[Vector2i, Array],
		taunters: Array[BattleUnit], heroes: Array[BattleUnit], ctx: Dictionary) -> Dictionary:
	var chase: Array[BattleUnit] = taunters if not taunters.is_empty() else heroes
	var prey: BattleUnit = ctx["prey"]
	var hunting: bool = taunters.is_empty() and prey != null
	if hunting:
		chase = [prey]
	var ward: BattleUnit = ctx["ward"]
	var guarding: bool = taunters.is_empty() and ward != null
	var dist_map: Dictionary[Vector2i, int] = l._distance_map(chase, e)
	var ward_map: Dictionary[Vector2i, int] = {}
	if guarding:
		var wl: Array[BattleUnit] = [ward]
		ward_map = l._distance_map(wl, e)
	var best_cell: Vector2i = e.cell
	var best_cost: int = 1000000
	for c: Vector2i in options:
		var dist: int = dist_map.get(c, 999)
		var cost: int = dist * 10 + options[c].size() - _place_value(l, c, ctx)
		if guarding:
			# Подопечный важнее: клетка вплотную к нему, а из таких — ближайшая к героям
			cost = ward_map.get(c, 999) * 30 + dist * 10 + options[c].size() - _place_value(l, c, ctx)
		if dist < e.data.keep_distance:
			cost += 50   # стрелок вплотную не лезет
		if cost < best_cost:
			best_cost = cost
			best_cell = c
	var reason: String = ""
	var near: BattleUnit = _nearest(chase, best_cell)
	if not taunters.is_empty():
		reason = "Провокация: идёт к %s" % _dat(near.title)
	elif guarding:
		reason = "Телохранитель: прикрывает %s" % _acc(ward.title)
	elif hunting:
		reason = "Охотник: к раненому %s" % _dat(prey.title)
	elif near != null:
		reason = "Не достаёт — идёт к %s" % _dat(near.title)
	return {"cell": best_cell, "reason": reason}


# Клетка для «зова»: откуда круг накроет больше своих, которые ударят в следующем раунде
static func _best_aura(l: BattleLogic, e: BattleUnit, atk: EnemyAttackData,
		options: Dictionary[Vector2i, Array], ctx: Dictionary) -> Dictionary:
	var best_cell: Vector2i = e.cell
	var best_score: int = -1000000
	var best_allies: int = 0
	for c: Vector2i in options:
		var allies: int = 0
		var score: int = 0
		for other in l.living_enemies():
			if other == e or HexMath.distance(other.cell, c) > atk.attack_range:
				continue
			allies += 1
			var next_attack: EnemyAttackData = other.data.attack_on_turn(l.turn + 1)
			score += ALLY_BUFF_NEXT_AURA if next_attack.shape == EnemyData.Attack.AURA else ALLY_BUFF_NEXT_ATTACK
		score += _place_value(l, c, ctx) - (options[c].size() - 1)
		if score > best_score:
			best_score = score
			best_cell = c
			best_allies = allies
	return {"cell": best_cell, "allies": best_allies}


# ---------- Мелочи ----------

# В какую из шести сторон смотреть с клетки from, чтобы стоять лицом к ближайшей цели
static func _face_dir(from: Vector2i, targets: Array[BattleUnit]) -> Vector2i:
	var nearest: BattleUnit = targets[0]
	for t in targets:
		if HexMath.distance(from, t.cell) < HexMath.distance(from, nearest.cell):
			nearest = t
	return HexMath.direction_to(from, nearest.cell)


static func _nearest(units: Array[BattleUnit], from: Vector2i) -> BattleUnit:
	var best: BattleUnit = null
	for u in units:
		if best == null or HexMath.distance(from, u.cell) < HexMath.distance(from, best.cell):
			best = u
	return best


# Причина удара для игрока. Одна, самая крупная:
# добивание > толчок в беду > бочка или дерево > оба героя > охотник > телохранитель > провокация > обычный удар
static func _strike_reason(info: Dictionary, provoked: bool, ctx: Dictionary) -> String:
	if info["kill"] != "":
		return "Добьёт %s" % _acc(info["kill"])
	if info["push"] != "":
		return info["push"]
	if info["obj"] != "":
		return info["obj"]
	if info["both"]:
		return "Заденет обоих"
	var prey: BattleUnit = ctx["prey"]
	if prey != null and info["prey_hurt"]:
		return "Охотник: бьёт раненого %s" % _acc(prey.title)
	if info.get("ward_near", false) and ctx["ward"] != null:
		return "Телохранитель: прикрывает %s" % _acc(ctx["ward"].title)
	if provoked:
		return "Провокация: бьёт %s" % _acc(info["hurt"])
	if info["hurt"] != "":
		return "Бьёт %s" % _acc(info["hurt"])
	return "Бьёт по блоку"


static func _count_allies(n: int) -> String:
	if n == 1:
		return "1 союзника"
	return "%d союзников" % n


# Имена героев и врагов в падежах (хватает для «Маг», «Рыцарь», «Корягач», «Гоблин-шаман»)
static func _acc(t: String) -> String:
	if t.ends_with("ь"):
		return t.left(t.length() - 1) + "я"
	if t.ends_with("а"):
		return t.left(t.length() - 1) + "у"
	return t + "а"


static func _gen(t: String) -> String:
	if t.ends_with("а"):
		return t.left(t.length() - 1) + "ы"
	return _acc(t)


static func _dat(t: String) -> String:
	if t.ends_with("ь"):
		return t.left(t.length() - 1) + "ю"
	if t.ends_with("а"):
		return t.left(t.length() - 1) + "е"
	return t + "у"

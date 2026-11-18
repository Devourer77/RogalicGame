extends SceneTree

# Хранители Рощи — тактики: укрытия, не толпятся, связки ударов, берегут своих.
# Запуск: godot --headless --path . -s tests/keepers_ai.gd

func C(col: int, row: int) -> Vector2i:
	return HexMath.from_column(col, row)

var fails := 0
var run
const O := BattleLogic.Obj


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


func fresh(enemy_ids: Array) -> BattleLogic:
	var list: Array[EnemyData] = []
	for id in enemy_ids: list.append(load("res://resources/enemies/%s.tres" % id))
	var l := BattleLogic.new()
	l.setup(12, 12, run.rng, run.party, list)
	l.rocks.clear(); l.tiles.clear(); l.objects.clear(); l.fire_timers.clear(); l.obj_timers.clear()
	l.start()
	l.heroes[0].cell = C(2, 10); l.heroes[1].cell = C(9, 10)
	for i in l.enemies.size():
		l.enemies[i].cell = C(i * 2, 1)
	return l


func _initialize() -> void:
	await process_frame
	run = root.get_node("Run")
	run.start_new_run(3)
	_cover()
	_crowd()
	_combo()
	_care()
	_others_unchanged()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _cover() -> void:
	print("--- Укрытие ---")
	var l := fresh(["grove_huntress"])
	var m: BattleUnit = l.heroes[0]
	m.cell = C(5, 9); l.heroes[1].cell = C(11, 11)
	var spot: Vector2i = C(5, 5)
	check("Открытая клетка — не укрытие", not EnemyAI._covered(l, spot))
	l.objects[C(5, 7)] = O.LIVE_TREE
	check("Дерево между героем и клеткой — укрытие", EnemyAI._covered(l, spot))
	l.objects.clear(); l.objects[spot] = O.BUSH
	check("Подлесок — укрытие", EnemyAI._covered(l, spot))
	var e: BattleUnit = l.enemies[0]
	var ctx: Dictionary = EnemyAI._context(l, e)
	l.objects.clear()
	var open_v: int = EnemyAI._place_value(l, spot, ctx)
	l.objects[C(5, 7)] = O.LIVE_TREE
	var cover_v: int = EnemyAI._place_value(l, spot, ctx)
	check("Стрелку клетка за деревом дороже открытой", cover_v - open_v >= EnemyAI.AI_COVER_RANGED)
	var g := fresh(["goblin"])
	g.heroes[0].cell = C(5, 9); g.objects[C(5, 7)] = O.LIVE_TREE
	var gctx: Dictionary = EnemyAI._context(g, g.enemies[0])
	var gv1: int = EnemyAI._place_value(g, spot, gctx)
	g.objects.clear()
	check("Гоблину укрытие безразлично", gv1 == EnemyAI._place_value(g, spot, gctx))


func _crowd() -> void:
	print("--- Не толпятся ---")
	var l := fresh(["grove_warden", "grove_warden"])
	var a: BattleUnit = l.enemies[0]; var b: BattleUnit = l.enemies[1]
	b.cell = C(6, 4)
	var ctx: Dictionary = EnemyAI._context(l, a)
	var next_to: Vector2i = C(6, 4) + HexMath.DIRS[0]
	var apart: Vector2i = C(2, 4)
	check("Клетка вплотную к своему дешевле", EnemyAI._place_value(l, next_to, ctx) < EnemyAI._place_value(l, apart, ctx))


func _combo() -> void:
	print("--- Связки ---")
	var l := fresh(["grove_huntress"])
	var e: BattleUnit = l.enemies[0]
	var m: BattleUnit = l.heroes[0]; var k: BattleUnit = l.heroes[1]
	m.cell = C(3, 8); k.cell = C(8, 8)
	m.hp = m.max_hp; k.hp = k.max_hp
	var atk: EnemyAttackData = l.enemy_attack(e)
	var up: Vector2i = HexMath.DIRS[0]
	for d: Vector2i in HexMath.DIRS:
		if HexMath.axial_to_world(m.cell + d).z < HexMath.axial_to_world(m.cell).z - 0.5:
			up = d   # сторона «вверх по полю»
	var spot_m: Vector2i = m.cell + up * 3
	var dir: Vector2i = -up
	var ctx: Dictionary = EnemyAI._context(l, e)
	var plain: Dictionary = EnemyAI._evaluate(l, e, atk, spot_m, dir, null, ctx)
	m.entangled = 1
	ctx = EnemyAI._context(l, e)
	var tangled: Dictionary = EnemyAI._evaluate(l, e, atk, spot_m, dir, null, ctx)
	check("По опутанному удар ценнее", tangled["value"] > plain["value"])
	check("Причина: связка", EnemyAI._strike_reason(tangled, false, ctx).begins_with("Связка"))
	m.entangled = 0
	# Фокус: раненый герой — общая цель
	m.hp = 10
	e.cell = C(5, 5)
	ctx = EnemyAI._context(l, e)
	check("Общая цель — самый раненый", ctx["focus"] == m)
	var res: Dictionary = EnemyAI.choose(l, e, atk)
	var hits_m: bool = l._attack_cells(e, atk, res["cell"], res["dir"]).has(m.cell)
	print("  ловчая: ", res["cell"], " ", res["reason"])
	check("Ловчая бьёт раненого Мага, а не целого Рыцаря", hits_m)


func _care() -> void:
	print("--- Берегут своих ---")
	var l := fresh(["grove_shieldbearer", "grove_huntress", "grove_warden"])
	var shield: BattleUnit = l.enemies[0]; var hunt: BattleUnit = l.enemies[1]; var war: BattleUnit = l.enemies[2]
	shield.cell = C(5, 3); hunt.cell = C(4, 2); war.cell = C(8, 2)
	l.heroes[0].cell = C(4, 8)
	var sctx: Dictionary = EnemyAI._context(l, shield)
	check("Щит прикрывает стрелка", sctx["ward"] == hunt)
	war.hp = 3; war.cell = C(6, 3)
	sctx = EnemyAI._context(l, shield)
	check("…а раненого бойца — прежде всего", sctx["ward"] == war)
	# Перед подопечным, со стороны героев
	var front: Vector2i = Vector2i.ZERO
	var back: Vector2i = Vector2i.ZERO
	var nh: BattleUnit = EnemyAI._nearest(l.living_heroes(), war.cell)
	for n: Vector2i in HexMath.neighbors(war.cell):
		if HexMath.distance(n, nh.cell) < HexMath.distance(war.cell, nh.cell): front = n
		if HexMath.distance(n, nh.cell) > HexMath.distance(war.cell, nh.cell): back = n
	check("Щиту клетка перед подопечным дороже, чем за ним",
			EnemyAI._place_value(l, front, sctx) > EnemyAI._place_value(l, back, sctx))
	# Раненый отходит к Щиту
	var wctx: Dictionary = EnemyAI._context(l, war)
	check("Боец с 3 HP считает себя раненым", wctx["wounded"])
	var by_shield: Vector2i = shield.cell + HexMath.DIRS[5]
	var far_from: Vector2i = C(10, 4)
	check("Раненому клетка у Щита дороже", EnemyAI._place_value(l, by_shield, wctx) > EnemyAI._place_value(l, far_from, wctx))


func _others_unchanged() -> void:
	print("--- Остальные враги по-старому ---")
	var l := fresh(["goblin", "goblin"])
	var ctx: Dictionary = EnemyAI._context(l, l.enemies[0])
	check("Гоблин не тактик", not ctx["tactic"] and ctx["focus"] == null)
	var sap := fresh(["grove_sapling"])
	check("Саженец — не тактик (кукла из веток)", not EnemyAI._context(sap, sap.enemies[0])["tactic"])

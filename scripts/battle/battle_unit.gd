class_name BattleUnit
extends RefCounted
# Участник боя в «логике» — без графики. Только числа и клетка.
# 3D-фигурку для него создаёт сцена боя (scripts/unit.gd).

var id: int = 0              # номер юнита в бою (по нему копия боя узнаёт «своих»)
var title: String = ""
var is_hero: bool = false
var data: EnemyData = null    # у врагов — их описание, у героев null
var hp: int = 0
var max_hp: int = 0
var block: int = 0            # поглощает урон; у героев сгорает в начале их хода, у врагов — в начале хода врагов
var cell: Vector2i = Vector2i.ZERO

# --- Только для героев ---
var hero_data: HeroData = null
var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []
var mana: int = 0           # мана героя; может уходить в минус (перегрев)
var moves_left: int = 0
var rage: int = 0             # ярость рыцаря: +1 за каждый полученный удар
var taunt: bool = false       # провокация до начала следующего хода
var holding_line: bool = false  # «Стойка стража» до начала следующего хода: соседние враги делают максимум 1 шаг
var charge: int = 0           # заряд мага: копится между ходами, тратится «разрядками»
var momentum: int = 0         # натиск рыцаря: +1 за каждую пройденную клетку, сгорает после удара
var discount: int = 0         # следующая карта дешевле на столько маны
var overloaded: bool = false  # «Перегрузка»: не потратил заряд до конца хода — урон себе
var swamp_free: bool = false        # «Кочка»: топь в этот ход не отнимает шагов
var root_guard: bool = false        # «Корни под ногами»: подошедший вплотную враг опутан
var gust_guard: int = 0             # «Вихрь вокруг»: подошедший вплотную враг отлетает на столько
var spirits: Array[String] = []      # id прирученных духов героя (пассивы)
var next_lightning: bool = false    # «Буревой разбег»: следующий удар — молния
var lightning_bonus: int = 0        # «Грозовой заряд»: +урон следующей карте молнии
var unstoppable_chain: bool = false  # «Неудержимый» II: убийства ещё и добавляют звенья Цепи
var unstoppable: bool = false # «Неудержимый»: убийства в этот ход возвращают ману и шаги
var outpost: bool = false     # «Застава»: враги, подошедшие вплотную, получают урон
var entangled: int = 0        # «Опутан»: сколько ходов ещё действует (нет шагов; бить и играть карты можно)
var wet: int = 0              # «Мокрый»: сколько раундов ещё держится (молния бьёт сильнее)
var poison: int = 0           # «Яд»: сколько раундов ещё ранит в конце раунда (мимо блока)
var rune: String = ""         # руна на оружии рыцаря: "fire", "storm", "rot" или пусто
var rune_hits: int = 0        # на сколько ударов её ещё хватит
var kept: Array[int] = []     # номера карт в руке, отмеченных «удержать» (режим KEEP_2)

# --- Только для врагов ---
var inflation: int = 0        # стаки «Раздувания» (жаба)
var fuse: int = 0             # фитиль тлеющей жабы: > 0 — взорвётся в начале следующего хода врагов
var armor_burnt: bool = false # «Древесная броня» сожжена огнём
var guarding: bool = false    # «Живой бастион»: до следующего хода принимает половину урона за соседнего напарника
var prism: bool = false       # «Магическая призма»: следующее Заклинание Мага разойдётся тремя лучами от этого героя
var vulnerable: int = 0       # «Уязвимость к магии»: следующее Заклинание бьёт сильнее на столько
var retain_turns: Dictionary = {}  # карта -> сколько ходов пролежала в руке (OnRetain), у героев
var bonus_damage: int = 0     # «Зов Раскола»: следующий удар сильнее на столько
var crown_power: int = 0      # «Наследие венца»: все удары сильнее на столько (до конца боя)
var ai_reason: String = ""    # почему враг так ходит («Добьёт Мага»); считает EnemyAI, показывает карточка врага


func is_alive() -> bool:
	return hp > 0


# Копия юнита для прогноза. Колоды не копируем — враги их не трогают.
func copy() -> BattleUnit:
	var u := BattleUnit.new()
	u.id = id
	u.title = title
	u.is_hero = is_hero
	u.data = data
	u.hp = hp
	u.max_hp = max_hp
	u.block = block
	u.cell = cell
	u.hero_data = hero_data
	u.mana = mana
	u.moves_left = moves_left
	u.rage = rage
	u.taunt = taunt
	u.holding_line = holding_line
	u.charge = charge
	u.momentum = momentum
	u.discount = discount
	u.overloaded = overloaded
	u.unstoppable = unstoppable
	u.unstoppable_chain = unstoppable_chain
	u.spirits = spirits.duplicate()
	u.swamp_free = swamp_free
	u.root_guard = root_guard
	u.gust_guard = gust_guard
	u.next_lightning = next_lightning
	u.lightning_bonus = lightning_bonus
	u.outpost = outpost
	u.entangled = entangled
	u.wet = wet
	u.poison = poison
	u.crown_power = crown_power
	u.rune = rune
	u.rune_hits = rune_hits
	u.inflation = inflation
	u.fuse = fuse
	u.armor_burnt = armor_burnt
	u.guarding = guarding
	u.prism = prism
	u.vulnerable = vulnerable
	u.bonus_damage = bonus_damage
	u.ai_reason = ai_reason
	return u

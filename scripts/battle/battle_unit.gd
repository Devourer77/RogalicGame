class_name BattleUnit
extends RefCounted
# Участник боя в «логике» — без графики. Только числа и клетка.
# 3D-фигурку для него создаёт сцена боя (scripts/unit.gd).

var rust: int = 0
var burst_done: bool = false                       # Колосс: сфера на половине здоровья уже лопнула
var lost_attacks: Array[EnemyAttackData] = []      # удары лопнувших сфер (выпали из круга)
var stunned: int = 0          # «Замыкание» механизма: столько ходов врагов пропускает
var asleep: bool = false      # Спящая сфера ещё спит
var brand: int = 0            # клеймо Культа на герое: следующий удар врага по нему сильнее
var shell_hits: int = 0       # сколько ударов ещё держит сфера Полусвободного духа
var moved_cells: int = 0      # сколько клеток герой прошёл за свой ход (на шум идёт слепыш)   # «Ржавчина» (дух железа): столько раундов удары врага слабее на RUST_WEAKEN
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
var ember_guard: bool = false       # «Щит углей»: под подошедшим вплотную врагом загорается клетка
var temper: int = 0                 # «Закалка в пару»: +урон следующей карте с уроном в этот ход
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
# Модификатор врага (data.modifier): что уже сработало
var mod_on: bool = false      # «Бешенство» включилось
var mod_used: bool = false    # «Цепкий» уже вставал; «Злопамятный» уже ответил в этот ход героев
var mod_stacks: int = 0       # «Вера в Венец»: сколько раз сработала
var mod_step: int = 0         # «Отклик на зов»: лишний шаг в этот ход врагов
var mod_step_next: bool = false   # «Отклик на зов»: лишний шаг на следующий ход врагов
var ai_reason: String = ""    # почему враг так ходит («Добьёт Мага»); считает EnemyAI, показывает карточка врага


func is_alive() -> bool:
	return hp > 0


# Полная копия юнита (для копии боя: прогноз врагов, предпросмотр карты).
# Поля берутся списком свойств (StateCopy) — новое поле скопируется само.
func copy() -> BattleUnit:
	var u := BattleUnit.new()
	StateCopy.copy_fields(self, u)
	return u

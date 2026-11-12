class_name EnemyData
extends Resource
# Описание вида врага. Сами враги лежат в resources/enemies/*.tres.

# Как враг бьёт (направление он выбирает сам — в сторону героя)
enum Attack {
	MELEE,  # одна клетка перед собой
	LINE,   # линия перед собой длиной attack_range (камни её останавливают)
	SWEEP,  # три клетки перед собой: прямо и по бокам
	AURA,   # не удар, а «зов»: усиливает врагов в круге вокруг себя
	AROUND, # круговой удар: все 6 клеток вокруг себя
}

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""   # одна строка лора, видна при наведении на врага
@export var max_hp: int = 8
@export var move_range: int = 3    # сколько клеток проходит за ход
@export var damage: int = 3
@export var attack: Attack = Attack.MELEE
@export var attack_range: int = 1  # нужна только для LINE
@export var color: Color = Color(0.4, 0.7, 0.3)  # цвет фигурки-заглушки
@export var model: PackedScene      # 3D-модель (.glb). Если пусто — рисуем капсулу-заглушку
@export var size: float = 1.0      # во сколько раз фигурка больше обычной
@export var is_boss: bool = false
@export var is_elite: bool = false

@export_group("Удар")
@export var attack_title: String = "Удар"   # как удар называется в журнале и подсказке
@export var push: int = 0            # удар отталкивает цель на столько клеток
@export var pull: int = 0            # удар притягивает цель на столько клеток
@export var first_only: bool = false # линия останавливается на первом, в кого попала
# Цикл ударов: если список не пуст, удары чередуются по раундам,
# а поля damage/attack/attack_range/push/pull выше не используются
@export var cycle: Array[EnemyAttackData] = []

@export_group("Поведение")
@export var keep_distance: int = 0   # старается не подходить к героям ближе, чем на столько клеток
@export var max_per_battle: int = 0  # не больше стольких в одном бою (0 — без ограничения)

@export_group("Особенности")
@export var bog_walker: bool = false  # ходит по трясине и не тонет в ней
@export var wet_trail: bool = false   # клетка, с которой ушёл, становится лужей
@export var aquatic: bool = false     # молния по соседней луже бьёт и его
@export var always_wet: bool = false  # всегда «Мокрый»: молния бьёт по нему сильнее
@export var death_blast: int = 0      # погибая не в трясине, взрывается: столько урона 4 соседям
@export var start_block: int = 0      # блок в начале боя
@export var turn_block: int = 0       # блок в начале каждого хода врагов
@export var bog_damage: int = 0       # не тонет: трясина для него как стена с таким уроном
@export var inflation: bool = false   # «Раздувание» (жаба): каждый удар картой-Атакой +1 стак; на 3 стаках или при смерти взрыв
@export var absorbs_magic: bool = false  # «Поглощение магии» (шаман): за каждое Заклинание лечит всех врагов и даёт себе блок
@export var wood_armor: bool = false  # «Древесная броня» (корягач): −50% от одиночной физической атаки; огонь сжигает её навсегда
@export var feeds_toad: bool = false  # пращник: если жаба далеко от героев — бьёт по ней (+1 раздувание) и толкает к героям
@export var swamp_on_hit: bool = false  # топляк: удар превращает клетки вокруг него в трясину и подмешивает в руку «Болотную тину»
@export var living_shield: bool = false # корягач: перехватывает одиночные дальние атаки и заклинания по врагам рядом с ним
@export var fire_weak: bool = false   # в огне теряет блок и получает двойной урон от огня

var _basic: EnemyAttackData   # удар простого врага, собранный из полей выше


# Какой удар враг нанесёт в раунде номер turn (раунды считаются с 1)
func attack_on_turn(turn: int) -> EnemyAttackData:
	if not cycle.is_empty():
		return cycle[posmod(turn - 1, cycle.size())]
	if _basic == null:
		_basic = EnemyAttackData.new()
		_basic.title = attack_title
		_basic.shape = attack
		_basic.attack_range = attack_range
		_basic.damage = damage
		_basic.push = push
		_basic.pull = pull
		_basic.first_only = first_only
	return _basic


# Короткий список особенностей — для подсказки при наведении
func traits() -> PackedStringArray:
	var t: PackedStringArray = []
	if keep_distance > 0:
		t.append("держит дистанцию")
	if bog_walker:
		t.append("ходит по трясине")
	if wet_trail:
		t.append("оставляет лужи")
	if aquatic:
		t.append("молния по соседней луже бьёт и его")
	if always_wet:
		t.append("всегда мокрый: молния бьёт сильнее")
	if death_blast > 0:
		t.append("погибая, взрывается (%d урона соседям); в трясине — нет" % death_blast)
	if start_block > 0:
		t.append("начинает с блоком %d" % start_block)
	if turn_block > 0:
		t.append("каждый ход +%d блока" % turn_block)
	if bog_damage > 0:
		t.append("не тонет: трясина ранит на %d" % bog_damage)
	if fire_weak:
		t.append("боится огня: в огне нет блока, урон от огня ×2")
	return t

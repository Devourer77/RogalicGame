class_name CardData
extends Resource
# Описание одной карты-заклинания.
# Сами карты лежат в resources/cards/*.tres — новую карту можно сделать
# в редакторе (ПКМ по папке → Создать → Ресурс → CardData), не трогая код.

# Форма области, по которой бьёт заклинание
enum Shape {
	SELF,    # на себя, цель выбирать не нужно
	SINGLE,  # одна клетка
	LINE,    # линия от героя в выбранную сторону
	CROSS,   # крест: клетка и 4 соседа
	SQUARE,  # квадрат 3×3 вокруг клетки
	ARC,     # дуга: соседняя клетка и две по бокам от неё (размах оружием)
	CHARGE,  # таран: герой бежит по прямой до первого препятствия и бьёт его
	ALLY,    # на героя-союзника (или на себя) в пределах дальности
	WALL,    # стена из 3 клеток поперёк направления от героя
	LEAP,    # прыжок на клетку (через преграды) и удар крестом вокруг неё
	AROUND,  # все 8 клеток вокруг героя, цель выбирать не нужно
	FELL,    # свалить соседнее дерево: выбираешь клетку, в сторону которой оно упадёт
}

# Стихия: что заклинание делает с клетками поля
enum Element {
	NONE,
	FIRE,       # поджигает клетки, испаряет лужи, растапливает лёд
	WATER,      # разливает лужи, тушит огонь
	ICE,        # превращает клетки в лёд, тушит огонь
	LIGHTNING,  # попав в лужу, бьёт по всей луже целиком
}

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var cost: int = 1              # сколько маны стоит
@export var shape: Shape = Shape.SINGLE
@export var cast_range: int = 1        # дальность в клетках
@export var damage: int = 0
@export var push: int = 0              # на сколько клеток толкает врагов (от героя)
@export var block: int = 0             # блок герою: поглощает урон до следующего хода
@export var bonus_moves: int = 0       # дополнительные шаги в этот ход
@export var draw: int = 0              # сколько карт добрать
@export var element: Element = Element.NONE
@export var is_rare: bool = false      # редкие реже попадаются в наградах и дороже в лавке
# Набор карты: "storm" (Буря Раскола), "elements" (Повелитель стихий),
# "onslaught" (Натиск), "warden" (Страж топей). Пусто — базовая карта.
@export var card_set: String = ""

@export_group("Рыцарь")
@export var taunt: bool = false        # провокация: враги, которые дотягиваются до героя, бьют только его
@export var rage_gain: int = 0         # сколько ярости даёт карта
@export var rage_bonus: int = 0        # +урон за каждое очко ярости (ярость при этом тратится вся)
@export var momentum_gain: int = 0     # сколько натиска даёт карта

@export_group("Маг")
@export var charge_gain: int = 0       # сколько заряда даёт карта
@export var charge_bonus: int = 0      # +урон за каждый заряд (заряд при этом тратится весь)

@export_group("Особое")
@export var pierce_block: bool = false # урон проходит сквозь блок
# Особое действие, которое не описать числами выше. Список — в BattleLogic._resolve_special().
@export var special: String = ""

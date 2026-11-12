class_name CardData
extends Resource
# Описание одной карты-заклинания.
# Сами карты лежат в resources/cards/*.tres — новую карту можно сделать
# в редакторе (ПКМ по папке → Создать → Ресурс → CardData), не трогая код.

# Форма области, по которой бьёт заклинание (сетка — соты, у клетки 6 соседей)
enum Shape {
	SELF,    # на себя, цель выбирать не нужно
	SINGLE,  # одна клетка
	LINE,    # линия от героя в выбранную сторону
	CROSS,   # кластер: клетка и 6 соседей (7 клеток)
	SQUARE,  # то же, что CROSS: клетка и 6 соседей (в сотах квадрата 3×3 нет)
	ARC,     # дуга: клетка вплотную к герою и две соседние с ней (размах оружием)
	CHARGE,  # таран: герой бежит по прямой до первого препятствия и бьёт его
	ALLY,    # на героя-союзника (или на себя) в пределах дальности
	WALL,    # стена из 3 клеток в ряд поперёк направления от героя
	LEAP,    # прыжок на клетку (через преграды) и удар по 6 клеткам вокруг неё
	AROUND,  # все 6 клеток вокруг героя, цель выбирать не нужно
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
# Рисунок карты: имя файла из assets/icons без «.svg» (например "fire", "shield").
# Пусто — игра подберёт рисунок сама по стихии и действию карты (см. CardView.icon_name).
@export var icon: String = ""
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
# "onslaught" (Натиск), "warden" (Страж топей), "runes" (Руны Стражи). Пусто — базовая карта.
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

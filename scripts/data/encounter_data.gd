class_name EncounterData
extends Resource
# Отряд врагов — заранее придуманный состав боя со своей темой («Стая», «Газовая засада»).
# Ядро (core) ставится всегда целиком, остальные места до нужного числа врагов
# докладываются из добора (filler) через общий генератор забега.
# Элиты и боссы — тоже отряды: сам сильный враг первым в ядре, за ним свита.

enum Kind { NORMAL, ELITE, BOSS }

@export var id: String = ""
@export var title: String = ""             # показывается в начале боя рядом с ареной
@export var kind: Kind = Kind.NORMAL
@export var core: Array[EnemyData] = []    # всегда в бою
@export var filler: Array[EnemyData] = []  # из кого добирать до нужного числа (пусто — не добирать)
@export var min_row: int = 0               # с какого ряда карты встречается (для обычных)
@export var max_row: int = 99              # по какой ряд включительно
@export var arena: String = ""             # своя арена (ключ BattleLogic.ARENAS); пусто — любая


# Встречается ли обычный отряд на этом ряду карты
func fits_row(row: int) -> bool:
	return kind == Kind.NORMAL and row >= min_row and row <= max_row

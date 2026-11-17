class_name EncounterData
extends Resource
# Отряд врагов — заранее придуманный состав боя со своей темой («Стая», «Газовая засада»).
# Ядро (core) ставится всегда целиком, остальные места до нужного числа врагов
# докладываются из добора (filler) через общий генератор забега.
# Элиты и боссы — тоже отряды: сам сильный враг первым в ядре, за ним свита.

enum Kind { NORMAL, ELITE, BOSS }
# В какой ветке карты встречается отряд: любая (общие враги — гоблины, волки, Культ), Болота или Лес.
enum Branch { ANY, BOG, FOREST }

@export var id: String = ""
@export var title: String = ""             # показывается в начале боя рядом с ареной
@export var kind: Kind = Kind.NORMAL
@export var core: Array[EnemyData] = []    # всегда в бою
@export var filler: Array[EnemyData] = []  # из кого добирать до нужного числа (пусто — не добирать)
@export var min_row: int = 0               # с какого ряда карты встречается (для обычных)
@export var max_row: int = 99              # по какой ряд включительно
@export var arena: String = ""             # своя арена (ключ BattleLogic.ARENAS); пусто — любая
@export var waves: Array[WaveData] = []    # подкрепления по ходу боя (пусто — без волн)
@export var formation: BattleLogic.Formation = BattleLogic.Formation.FREE   # строй: как враги стоят в начале боя
@export var branch: Branch = Branch.ANY    # ветка карты акта (мир.md, раздел 2)


# Встречается ли обычный отряд на этом ряду карты
func fits_row(row: int) -> bool:
	return kind == Kind.NORMAL and row >= min_row and row <= max_row


# Подходит ли отряд ветке карты (MapNode.BOG / MapNode.FOREST; -1 — общий ряд, подходит любой)
func fits_branch(map_branch: int) -> bool:
	if branch == Branch.ANY or map_branch < 0:
		return true
	return (branch == Branch.BOG and map_branch == MapNode.BOG) or (branch == Branch.FOREST and map_branch == MapNode.FOREST)

class_name EnemyModifier
extends Resource
# Модификатор («характер») врага: ничего не делает, пока не случится его условие
# (мало HP, получил удар, рядом погиб свой, зов шамана…). Выдаётся при создании боя
# (Run._apply_modifiers), сам эффект считает BattleLogic. Подробно — claude/тз-сложность-боя.md.

enum Kind {
	FRENZY,     # «Бешенство»: HP ≤ половины — удары +value, +1 шаг до конца боя
	RALLY,      # «Отклик на зов»: на него подействовал зов — ещё +value к удару и +1 шаг на следующий ход
	SPITE,      # «Злопамятный»: ударили вплотную — бьёт в ответ на value (раз за ход героев)
	FAITH,      # «Вера в Венец»: рядом (2 клетки) погиб союзник — +3 блока и удары +1, до value раз
	TENACIOUS,  # «Цепкий»: первый раз упал до 0 HP — встаёт с value HP
	ROTTEN,     # «Гнилое нутро»: погибая, лопается — value урона всем соседям, своим тоже
}

@export var id: String = ""
@export var title: String = ""
@export var kind: Kind = Kind.FRENZY
@export var value: int = 2
@export var icon: String = ""            # значок над плашкой врага (assets/icons/<icon>.svg)
@export_multiline var description: String = ""   # строка в карточке врага
@export var only_for: Array[String] = []  # id врагов, кому подходит (пусто — всем)
@export var not_for: Array[String] = []   # id врагов, кому не подходит
@export var needs_caller: bool = false    # только если в бою есть, кто зовёт (зов шамана, Певчей, вожака)


func fits(e: EnemyData) -> bool:
	if not only_for.is_empty() and not only_for.has(e.id):
		return false
	return not not_for.has(e.id)

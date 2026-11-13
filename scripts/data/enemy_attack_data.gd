class_name EnemyAttackData
extends Resource
# Один удар врага: форма, урон и что он делает с целью.
# У простых врагов удар один — он собирается из полей EnemyData.
# У врагов с «циклом» ударов несколько, и они чередуются по раундам
# (список cycle в EnemyData): раунд 1 — первый, раунд 2 — второй и так по кругу.

@export var title: String = "Удар"
@export var anim: String = "Attack"   # какую анимацию модели играть (если такой нет — играется Attack)
# Форма удара: число из EnemyData.Attack (0 — вплотную, 1 — линия, 2 — три клетки, 3 — зов, 4 — вокруг себя)
@export_enum("MELEE", "LINE", "SWEEP", "AURA", "AROUND") var shape: int = 0
@export var attack_range: int = 1   # длина линии или радиус зова
@export var damage: int = 3
@export var push: int = 0           # отталкивает цель на столько клеток
@export var pull: int = 0           # притягивает цель к себе на столько клеток
@export var first_only: bool = false  # линия останавливается на первом, в кого попала (камень из пращи)
@export var pierce: bool = false    # линия идёт сквозь преграды и не ломает их (корни)
@export var entangle: int = 0       # опутывает цель на столько ходов (нет шагов, карты играть можно)
@export var puddle: bool = false    # клетка под целью становится лужей
@export var ally_block: int = 0     # зов: столько блока получают враги рядом
@export var ally_damage: int = 0    # зов: на столько сильнее их следующий удар
@export var poison: int = 0         # отравляет цель на столько раундов (яд ранит в конце раунда мимо блока)
@export var gas_cloud: bool = false  # клетки удара становятся ядовитым газом (там, где сухо или лужа)
@export var ignite: bool = false     # поджигает клетки удара: горят земля, бочки, деревья и камыш
@export var summon: EnemyData       # призыв: кто появляется на свободных клетках рядом (удар формы «зов»)
@export var summon_count: int = 0   # сколько их появляется (меньше, если рядом нет места)


# Удар-призыв: не бьёт и не усиливает, только зовёт подмогу
func is_summon_only() -> bool:
	return summon != null and summon_count > 0 and ally_block <= 0 and ally_damage <= 0


# Описание удара одной строкой — для подсказки при наведении на врага
func describe() -> String:
	var parts: PackedStringArray = []
	match shape:
		0:
			parts.append("%d урона вплотную" % damage)
		1:
			parts.append("%d урона, линия на %d" % [damage, attack_range])
		2:
			parts.append("%d урона по трём клеткам перед собой" % damage)
		3:
			if ally_block > 0 and ally_damage > 0:
				parts.append("врагам в %d клетках: +%d блока, следующий удар +%d" % [attack_range, ally_block, ally_damage])
			elif ally_damage > 0:
				parts.append("врагам в %d клетках: следующий удар +%d" % [attack_range, ally_damage])
			elif ally_block > 0:
				parts.append("врагам в %d клетках: +%d блока" % [attack_range, ally_block])
			if summon != null and summon_count > 0:
				parts.append("зовёт: %s ×%d рядом" % [summon.title.to_lower(), summon_count])
		4:
			parts.append("%d урона по 6 клеткам вокруг себя" % damage)
	if first_only:
		parts.append("до первой цели")
	if pierce:
		parts.append("сквозь преграды")
	if push > 0:
		parts.append("отталкивает на %d" % push)
	if pull > 0:
		parts.append("притягивает на %d" % pull)
	if entangle > 0:
		parts.append("опутывает (ход без шагов)")
	if puddle:
		parts.append("оставляет лужу под целью")
	if poison > 0:
		parts.append("яд на %d раунда" % poison)
	if gas_cloud:
		parts.append("клетки удара становятся газом")
	if ignite:
		parts.append("поджигает клетки удара (бочки, деревья, камыш)")
	return "%s: %s" % [title, ", ".join(parts)]

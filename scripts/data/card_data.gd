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
# Эффект карты на поле (VfxPlayer.play_card). Пусто — подбирается сам по форме, стихии и набору.
# Можно задать «форму» и «цвет» через двоеточие, например "area:fire" или "bolt".
# Формы: melee, bash, staff, dash, guard, buff, bolt, chain, wave, area.
# Цвета: steel, rage, arcane, water, lightning, wind, bog, fire, steam.
@export var vfx: String = ""

@export_group("Рыцарь")
@export var taunt: bool = false        # провокация: враги, которые дотягиваются до героя, бьют только его
@export var hold_line: bool = false    # «Стойка стража»: враги, начавшие ход рядом с рыцарем, делают не больше 1 шага
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

# --- Редизайн боя: владелец, теги, сброс «в ноги» ---
@export var owner_hero: String = ""     # "mage", "knight" или пусто (нейтральная); пока не задано — владелец тот, у кого карта в руке
@export var is_attack: bool = false     # тег «Атака» (считается в TurnContext и в пассивках врагов)
@export var is_spell: bool = false      # тег «Заклинание»
@export var scrap_moves: int = 1        # сброс «в ноги»: сколько шагов даёт (0 — не даёт)
@export var scrap_block: int = 0        # сброс «в ноги»: сколько блока даёт
@export var scrap_mana: int = 0         # сброс «в ноги»: сколько маны возвращает (манипуляция маной мага)

# --- Новая система карт (тз-карты.md): роль, Цепь, архетип, духи, улучшения ---
# Роль карты — значок в углу: Ход, Заготовка, Связка, Развязка
enum Role { NONE, MOVE, SETUP, LINK, FINISH }

@export_group("Цепь")
@export var role: Role = Role.NONE
# «Цепь N: …» — бонус, если до этой карты отряд уже сыграл в этот ход N карт (0 — бонуса нет)
@export var chain_need: int = 0
@export var chain_damage: int = 0       # +урон при выполненной Цепи
@export var chain_cost: int = -1        # цена при выполненной Цепи (-1 — цена не меняется)
@export var chain_push: int = 0         # +толчок при выполненной Цепи
@export var chain_draw: int = 0         # +добор при выполненной Цепи
@export var chain_charge: int = 0       # +заряд при выполненной Цепи
@export var chain_range: int = 0        # +дальность при выполненной Цепи
@export var per_link_damage: int = 0    # +урон за каждое звено Цепи
@export var chain_add: int = 0          # сколько карта добавляет к Цепи сверх обычной единицы
@export var pull: int = 0               # притягивает задетых врагов к герою на столько клеток
@export var execute_damage: int = 12    # «Добивание»: урон по раненому врагу
@export var kill_mana: int = 0          # убил этой картой — столько маны обратно

@export_group("Происхождение")
# Архетип базовой карты: "charge", "kinetic", "flow" (Маг), "onslaught", "warden", "rage" (Рыцарь)
@export var archetype: String = ""
# Духи карты: один — карта духа, два — смешанная карта пары, пусто — базовая
@export var spirit_ids: Array[String] = []
@export var spirit_slot: int = 0        # Д1–Д6 у карт духа: по нему карта меняется при передаче духа

@export_group("Улучшения")
# Улучшенные версии этой карты (ветка I «Сила» и ветка II «Приём»). У самих улучшенных — пусто.
@export var upgrade_1: CardData
@export var upgrade_2: CardData
@export var upgrade_level: int = 0      # 0 — обычная карта, 1 или 2 — какая ветка улучшения

@export_group("Особое (новые карты)")
@export var ally_block: int = 0         # второй герой получает столько блока
@export var move_distance: int = 0      # на сколько клеток «Перенос» сдвигает стихию или бочку
@export var discount_next: int = 0      # следующая карта героя дешевле на столько

@export_group("Духи (этап 3)")
@export var chain_pull: int = 0         # +притягивание при выполненной Цепи
@export var rune_charges: int = 0       # на сколько ударов руна (0 — обычное число)
@export var bonus_amount: int = 0       # число для особого действия (блок, радиус…)
@export var block_per_hit: int = 3      # «блок за каждого задетого»
@export var chain_jumps: bool = false   # перескоки молнии: +1 за каждые 2 звена Цепи
@export var no_falloff: bool = false    # перескоки молнии не слабеют
@export var is_call: bool = false       # Зов духа: раз в бой, не уходит в сброс, в Цепь не идёт

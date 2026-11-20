class_name ActData
extends Resource
# Один акт забега (мир.md, раздел 2): его название, две ветки карты, отряды, элиты, боссы и арены.
# Забег — три акта подряд (Run.ACTS). Файлы актов лежат в resources/acts/act_N.tres.
#
# Пока у акта нет своих врагов или арен (акты 2 и 3 в работе), он берёт их у акта borrow_from
# и делает врагов крепче (enemy_hp_mult, enemy_damage_add) — так забег проходится до конца уже сейчас.
# Когда появятся свои отряды — заполнить списки, и заимствование перестанет действовать само.

@export var number: int = 1
@export var title: String = ""                       # «Гнилые топи», «Пепельный тракт», «Ледяной Шпиль»
@export_multiline var intro: String = ""             # пара фраз на экране перехода в акт
@export var branch_titles: Array[String] = ["", ""]  # две ветки карты: левая и правая
@export var fork_title: String = ""                  # заголовок карты до первого шага («Развилка: …»)
@export var common_title: String = ""                # заголовок на общем привале и у босса
@export var map_bg: String = ""                      # рисунок карты пути (пусто или нет файла — рисунок акта 1)

@export var encounters: Array[EncounterData] = []    # обычные отряды
@export var elite_pool: Array[EncounterData] = []
@export var boss_pool: Array[EncounterData] = []
@export var arenas_left: Array[String] = []          # арены обычных боёв левой ветки (ключи BattleLogic.ARENAS)
@export var arenas_right: Array[String] = []         # арены правой ветки
@export var boss_arena: String = ""                  # арена босса, если у его отряда нет своей
@export var lair_spirits: Array[String] = []         # кто ждёт в логове этого акта (Run.SPIRIT_IDS)
@export var bridge_point: Vector2 = Vector2.ZERO   # где на рисунке карты мост (доли ширины и высоты); 0 — тропа-переход по своей кривой

@export var borrow_from: int = 0                     # чего нет — брать у этого акта (0 — ничего не брать)
@export var enemy_hp_mult: float = 1.0               # во сколько раз крепче враги акта (пока он на чужих врагах)
@export var enemy_damage_add: int = 0                # на сколько сильнее их удары


# Акт ещё собран из чужих врагов и арен (в работе)
func is_placeholder() -> bool:
	return encounters.is_empty() or boss_pool.is_empty()

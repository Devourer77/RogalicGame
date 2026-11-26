class_name DeckPreset
extends Resource
# Готовая стартовая колода героя (пресет). Выбирается в Караульне перед забегом,
# поверх неё действуют «изменения» из Запаса. Пресеты лежат в resources/presets/,
# список у героя — HeroData.presets (первый — базовый, открыт всегда).

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""   # одна-две строки: как играет колода
@export var cards: Array[CardData] = []
@export var unlock: String = ""   # "" — открыт сразу; "act2_boss" — после победы над боссом акта 2

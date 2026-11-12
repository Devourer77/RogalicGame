class_name RelicData
extends Resource
# Оберег (артефакт Стражи) или порченая реликвия. Обереги лежат в resources/relics/charm_*.tres.

enum Kind { CORRUPTED, CHARM }

@export var id: String = ""
@export var title: String = ""
@export_multiline var desc: String = ""
@export var icon: String = ""
@export var hero_id: String = ""      # пусто — действует на отряд
@export var kind: Kind = Kind.CHARM
@export var start_open: bool = false  # открыт с начала игры
@export var buyable: bool = false     # можно купить за Отзвуки на Полке трофеев
@export var unlock_cost: int = 0      # цена в Отзвуках, если buyable
# Только у порченых реликвий (Kind.CORRUPTED): сила и цена отдельными строками
@export_multiline var plus_text: String = ""
@export_multiline var minus_text: String = ""


# Текст подсказки: название и описание (у реликвий — плюс и минус)
func full_text() -> String:
	if kind == Kind.CORRUPTED and plus_text != "":
		return "%s\n+ %s\n− %s" % [title, plus_text, minus_text]
	return "%s\n%s" % [title, desc]

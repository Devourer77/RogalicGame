class_name RelicData
extends Resource
# Порченая реликвия: действует весь забег, даёт сильный плюс и ощутимый минус.
# Сами эффекты — проверки BattleLogic.has_relic("id") / Run.has_relic("id") в нужных местах кода.

@export var id: String = ""
@export var title: String = ""
@export var icon: String = "relic"       # иконка из assets/icons
@export_multiline var plus_text: String = ""    # что даёт
@export_multiline var minus_text: String = ""   # чем платишь
@export var hero_id: String = ""         # "mage", "knight" или пусто — на весь отряд


func full_text() -> String:
	return "%s\n+ %s\n− %s" % [title, plus_text, minus_text]

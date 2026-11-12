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

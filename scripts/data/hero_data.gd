class_name HeroData
extends Resource
# Описание героя: здоровье, шаги, стартовая колода и карты, которые ему
# могут выпасть в наградах. Герои лежат в resources/heroes/*.tres.

@export var id: String = ""
@export var title: String = ""
@export var max_hp: int = 30
@export var moves_per_turn: int = 3      # бесплатные шаги за ход
@export var mana_per_turn: int = 3
@export var gains_rage: bool = false     # копит ярость, когда по нему бьют (рыцарь)
@export var gains_momentum: bool = false # копит натиск от пройденных клеток (рыцарь)
@export var uses_charge: bool = false    # копит заряд от заклинаний (маг)
@export var color: Color = Color(0.3, 0.4, 0.9)   # цвет рамки его карт и кольца выбора
@export var model: PackedScene           # 3D-модель; если пусто — капсула-заглушка его цвета
@export var starter_deck: Array[CardData] = []
@export var card_pool: Array[CardData] = []   # карты для наград и лавки

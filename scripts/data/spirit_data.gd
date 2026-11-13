class_name SpiritData
extends Resource
# Дух стихии (тз-духи.md): пассивный эффект, Зов (раз в бой) и по 6 карт каждому герою.
# Духи лежат в resources/spirits/*.tres. Первые 3 карты героя приходят сразу, остальные — в наградах.

@export var id: String = ""             # "tide" (Омутник), "storm" (Грозовик)…
@export var title: String = ""
@export_multiline var description: String = ""   # строка лора
@export var passive_text: String = ""   # что делает пассив (для подсказки)
@export var color: Color = Color(0.5, 0.7, 0.9)
@export var icon: String = "orb"
@export var is_unique: bool = false
@export var call_card: CardData         # Зов духа: эта карта в начале боя появляется в руке
@export var mage_cards: Array[CardData] = []
@export var knight_cards: Array[CardData] = []
@export var mixed_cards: Array[CardData] = []   # смешанные карты пар, где этот дух первый
@export var enemy: EnemyData            # каким врагом дух выходит в логове


# Карты духа для героя по id героя
func cards_for(hero_id: String) -> Array[CardData]:
	return mage_cards if hero_id == "mage" else knight_cards

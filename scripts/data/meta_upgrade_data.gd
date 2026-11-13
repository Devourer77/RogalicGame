class_name MetaUpgradeData
extends Resource
# Постоянное улучшение за Отзвуки (Доска дозора, Круг ордена, Оружейная, Святилище духов).
# Файлы лежат в resources/meta_upgrades/*.tres — цены и числа правятся там, без кода.

enum Desk { PARTY, MAGE, KNIGHT, SPIRIT }   # на какой доске лежит улучшение (не «Board»: так зовётся поле боя)

@export var id: String = ""
@export var title: String = ""
@export_multiline var desc: String = ""
@export var icon: String = ""                 # имя значка из assets/icons (нет такого — «star»)
@export var board: Desk = Desk.PARTY
@export var hero_id: String = ""              # "mage" / "knight"; пусто — относится ко всему отряду
@export var costs: Array[int] = []            # цена каждой ступени; число ступеней = размер массива
@export var effect: String = ""               # ключ эффекта (его читает Run / Meta)
@export var value: int = 0                    # сколько даёт одна ступень
# Только для эффекта unlock_cards: на каждую ступень — id карт через запятую («m_overload,m_bog_maw»)
@export var unlock_card_ids: Array[String] = []

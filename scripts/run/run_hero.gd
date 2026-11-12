class_name RunHero
extends RefCounted
# Герой в текущем забеге: его здоровье и колода меняются от боя к бою.

var data: HeroData
var hp: int = 0
var deck: Array[CardData] = []


func _init(hero_data: HeroData) -> void:
	data = hero_data
	hp = hero_data.max_hp
	deck = hero_data.starter_deck.duplicate()


# Лечение в обход реликвий. Экраны забега лечат через Run.heal_hero() — там учитывается «Клеймо стража».
func heal(amount: int) -> void:
	hp = mini(data.max_hp, hp + amount)


func lose_hp(amount: int) -> void:
	hp = maxi(1, hp - amount)   # события не убивают, оставляют 1 HP

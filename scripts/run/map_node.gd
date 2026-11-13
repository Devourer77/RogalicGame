class_name MapNode
extends RefCounted
# Одна точка на карте забега: бой, событие, лавка, привал, элитный бой или босс.

enum Type { BATTLE, EVENT, SHOP, REST, BOSS, ELITE, LAIR }

var type: Type = Type.BATTLE
var row: int = 0              # ряд снизу вверх: 0 — старт, последний — босс
var col: int = 0              # колонка в ряду
var next: Array[int] = []     # колонки следующего ряда, куда отсюда ведут дорожки
var visited: bool = false


func type_name() -> String:
	match type:
		Type.BATTLE:
			return "Бой"
		Type.EVENT:
			return "Событие"
		Type.SHOP:
			return "Лавка"
		Type.REST:
			return "Привал"
		Type.BOSS:
			return "БОСС"
		Type.ELITE:
			return "Элита"
		Type.LAIR:
			return "Логово духа"
	return "?"

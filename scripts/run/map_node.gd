class_name MapNode
extends RefCounted
# Одна точка на карте забега: бой, событие, лавка, привал, элитный бой или босс.

enum Type { BATTLE, EVENT, SHOP, REST, BOSS, ELITE, LAIR }

# Ветки карты акта: две дороги рядом, сходятся на привале перед боссом (мир.md, раздел 2)
const BOG: int = 0
const FOREST: int = 1
const COMMON: int = -1      # общий ряд (привал, босс)

var type: Type = Type.BATTLE
var row: int = 0              # ряд снизу вверх: 0 — старт, последний — босс
var col: int = 0              # колонка в ряду (0–2 — Болота, 3–5 — Лес; у привала и босса — 0)
var branch: int = BOG         # ветка: BOG, FOREST или COMMON
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

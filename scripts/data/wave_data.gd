class_name WaveData
extends Resource
# Волна подкрепления: враги приходят в конце раунда с края поля, пока жив главный
# враг боя (первый в ядре отряда — вожак, Певчая, огр). Перебили всех до волны —
# бой выигран, волна не приходит. Случайности нет: клетки прихода видны заранее.

enum From { TOP, SIDES }   # откуда приходят: верхний ряд или боковые края

@export var enemy: EnemyData                # кто приходит
@export var first_round: int = 2            # в конце какого раунда первая волна
@export var count: int = 1                  # сколько врагов в первой волне
@export var every: int = 0                  # повтор через столько раундов (0 — один раз)
@export var repeat_count: int = 0           # сколько в повторных волнах (0 — как в первой)
@export var from: From = From.TOP
@export var text: String = ""               # для подсказки: «вой собирает стаю»


# Приходит ли волна в конце раунда round_no
func arrives_on(round_no: int) -> bool:
	if round_no == first_round:
		return true
	return every > 0 and round_no > first_round and (round_no - first_round) % every == 0


# Сколько врагов придёт в конце раунда round_no (без добавки Звона)
func count_on(round_no: int) -> int:
	if round_no != first_round and repeat_count > 0:
		return repeat_count
	return count


# Ближайший раунд (начиная с from_round), в конце которого придёт волна; -1 — больше не придёт
func next_round(from_round: int) -> int:
	if from_round <= first_round:
		return first_round
	if every <= 0:
		return -1
	var passed: int = from_round - first_round
	return first_round + ceili(passed / float(every)) * every

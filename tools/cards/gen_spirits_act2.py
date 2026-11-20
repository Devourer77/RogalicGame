# Генератор духов акта 2 «Пепельный тракт» (claude/тз-духи-акт-2.md):
#   Пепельник (ash, дым), Каменник (stone, камни), Котловик (steam, пар) — обычные и секретный;
#   Сердце Жерла (magma, лава) и Ржавник (rust, железо) — уникальные.
# У каждого: пассив (код — battle_logic.gd, раздел «Духи акта 2»), Зов, 6 карт Магу, 6 Рыцарю.
# Пары (по 4 смешанные карты): Пепел + ветер, Камень + огонь, Лава + вода, Пар + молния, Железо + вода.
# Враги для логова и секретного боя — spirit_ash, spirit_stone, spirit_steam.
# Запуск из папки проекта: python tools/cards/gen_spirits_act2.py
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from gen_base_cards import gd  # noqa: E402
from gen_spirit_cards import card, write_card, write_set  # noqa: E402

A, ST, SM, MG, RU = "ash", "stone", "steam", "magma", "rust"
W, F, T, S = "wind", "fire", "tide", "storm"

# ---------- Пепельник: дым закрывает линии, огонь и дым рядом дают блок ----------
ASH_M = [
    card("ash_m1", "mage", "SETUP", "Дымовая завеса", "wind", "Круг 1 до 4: дым на 2 раунда — сквозь него не бьют по линии.",
         dict(cost=1, shape="CROSS", cast_range=4, special="smoke"),
         (dict(cast_range=6), "Круг 1 до 6: дым на 2 раунда — сквозь него не бьют по линии."),
         (dict(bonus_amount=3), "Круг 1 до 4: дым на 3 раунда — сквозь него не бьют по линии.")),
    card("ash_m2", "mage", "LINK", "Пепельный укол", "spark", "2 урона огнём до 4, клетка цели загорается.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=4, damage=2, element="FIRE", chain_need=2, chain_damage=2),
         (dict(damage=3), "3 урона огнём до 4, клетка цели загорается.\nЦепь 2: +2."),
         (dict(cast_range=6), "2 урона огнём до 6, клетка цели загорается.\nЦепь 2: +2.")),
    card("ash_m3", "mage", "FINISH", "Пепельный шквал", "fire", "Линия 5: 4 урона огнём +1 за звено Цепи, клетки горят.",
         dict(cost=2, shape="LINE", cast_range=5, damage=4, per_link_damage=1, element="FIRE"),
         (dict(damage=5), "Линия 5: 5 урона огнём +1 за звено, клетки горят."),
         (dict(chain_need=3, chain_cost=1), "Линия 5: 4 урона огнём +1 за звено, клетки горят.\nЦепь 3: стоит 1.")),
    card("ash_m4", "mage", "MOVE", "Шаг сквозь дым", "dash", "Маг переносится на клетку с дымом или огнём до 5. +1 шаг.",
         dict(cost=0, shape="SINGLE", cast_range=5, special="fire_step", bonus_moves=1),
         (dict(cast_range=7), "Маг переносится на клетку с дымом или огнём до 7. +1 шаг."),
         (dict(bonus_moves=2), "Маг переносится на клетку с дымом или огнём до 5. +2 шага.")),
    card("ash_m5", "mage", "SETUP", "Тлеющий покров", "shield", "6 клеток вокруг мага: дым на 2 раунда. Блок 3.",
         dict(cost=1, shape="AROUND", cast_range=0, special="smoke", block=3),
         (dict(block=6), "6 клеток вокруг мага: дым на 2 раунда. Блок 6."),
         (dict(cost=0), "6 клеток вокруг мага: дым на 2 раунда. Блок 3.")),
    card("ash_m6", "mage", "FINISH", "Пепельная буря", "fire", "Круг 1 до 5: 6 урона огнём +1 за звено, потом всё затягивает дымом.\nЦепь 4: стоит 2.",
         dict(cost=3, shape="CROSS", cast_range=5, damage=6, per_link_damage=1, element="FIRE", special="smoke_after", chain_need=4, chain_cost=2),
         (dict(damage=8), "Круг 1 до 5: 8 урона огнём +1 за звено, потом дым.\nЦепь 4: стоит 2."),
         (dict(cost=2, chain_need=0, chain_cost=-1), "Круг 1 до 5: 6 урона огнём +1 за звено, потом дым."), rare=True),
]
ASH_K = [
    card("ash_k1", "knight", "SETUP", "Пепельный плащ", "shield", "Блок 5; 6 клеток вокруг рыцаря — дым на 2 раунда.",
         dict(cost=1, shape="AROUND", cast_range=0, block=5, special="smoke"),
         (dict(block=8), "Блок 8; 6 клеток вокруг рыцаря — дым на 2 раунда."),
         (dict(cost=0), "Блок 5; 6 клеток вокруг рыцаря — дым на 2 раунда.")),
    card("ash_k2", "knight", "LINK", "Удар из дыма", "sword", "3 урона вплотную; рыцарь в дыму или огне, или дым рядом — ещё +3.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=1, damage=3, special="smoke_strike", bonus_amount=3, chain_need=2, chain_damage=2),
         (dict(damage=4), "4 урона вплотную; из дыма или огня — ещё +3.\nЦепь 2: +2."),
         (dict(bonus_amount=5), "3 урона вплотную; из дыма или огня — ещё +5.\nЦепь 2: +2.")),
    card("ash_k3", "knight", "FINISH", "Тлеющий таран", "ram", "Таран до 4, путь горит. Врезавшись: 5 урона +1 за звено Цепи, под целью огонь.",
         dict(cost=2, shape="CHARGE", cast_range=4, damage=5, per_link_damage=1, special="fire_trail"),
         (dict(damage=6), "Таран до 4, путь горит. Врезавшись: 6 урона +1 за звено, под целью огонь."),
         (dict(cast_range=6), "Таран до 6, путь горит. Врезавшись: 5 урона +1 за звено, под целью огонь.")),
    card("ash_k4", "knight", "MOVE", "Сквозь пепел", "dash", "+3 шага; +1 натиск за каждую горящую клетку в 2 клетках (до 3).",
         dict(cost=0, shape="SELF", cast_range=0, bonus_moves=3, special="flame_count"),
         (dict(bonus_moves=4), "+4 шага; +1 натиск за каждую горящую клетку в 2 клетках (до 3)."),
         (dict(block=3), "+3 шага, блок 3; +1 натиск за каждую горящую клетку рядом (до 3).")),
    card("ash_k5", "knight", "SETUP", "Стена дыма", "wind", "Стена из 3 клеток дыма до 3 на 2 раунда. Блок 3.",
         dict(cost=1, shape="WALL", cast_range=3, special="smoke", block=3),
         (dict(block=6), "Стена из 3 клеток дыма до 3 на 2 раунда. Блок 6."),
         (dict(bonus_amount=3, cast_range=4), "Стена из 3 клеток дыма до 4 на 3 раунда. Блок 3.")),
    card("ash_k6", "knight", "FINISH", "Пепельный вихрь", "whirl", "6 клеток вокруг: 5 урона огнём +1 ярость за задетого, потом дым.\nЦепь 4: стоит 1.",
         dict(cost=2, shape="AROUND", cast_range=0, damage=5, element="FIRE", special="smoke_after", chain_need=4, chain_cost=1, rage_gain=1),
         (dict(damage=6), "6 клеток вокруг: 6 урона огнём, +1 ярость, потом дым.\nЦепь 4: стоит 1."),
         (dict(block=5), "6 клеток вокруг: 5 урона огнём, +1 ярость, потом дым. Блок 5.\nЦепь 4: стоит 1."), rare=True),
]

# ---------- Каменник: камни-преграды, толчки в преграды, блок от стен ----------
STONE_M = [
    card("stone_m1", "mage", "SETUP", "Каменная стена", "shield", "Стена из 3 камней до 4: преграды на 3 раунда, закрывают линии.",
         dict(cost=1, shape="WALL", cast_range=4, special="stone_wall"),
         (dict(cost=0), "Стена из 3 камней до 4: преграды на 3 раунда, закрывают линии."),
         (dict(bonus_amount=5), "Стена из 3 камней до 4: преграды на 5 раундов, закрывают линии.")),
    card("stone_m2", "mage", "LINK", "Метнуть камень", "spark", "3 урона до 4, толчок 1.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=4, damage=3, push=1, chain_need=2, chain_damage=2),
         (dict(damage=4), "4 урона до 4, толчок 1.\nЦепь 2: +2."),
         (dict(push=2), "3 урона до 4, толчок 2.\nЦепь 2: +2.")),
    card("stone_m3", "mage", "FINISH", "Камнепад", "meteor", "Круг 1 до 5: 4 урона +1 за звено Цепи.",
         dict(cost=2, shape="CROSS", cast_range=5, damage=4, per_link_damage=1),
         (dict(damage=5), "Круг 1 до 5: 5 урона +1 за звено."),
         (dict(chain_need=3, chain_cost=1), "Круг 1 до 5: 4 урона +1 за звено.\nЦепь 3: стоит 1.")),
    card("stone_m4", "mage", "MOVE", "Опора", "dash", "+2 шага, блок 3.",
         dict(cost=0, shape="SELF", cast_range=0, bonus_moves=2, block=3),
         (dict(bonus_moves=3), "+3 шага, блок 3."),
         (dict(block=5), "+2 шага, блок 5.")),
    card("stone_m5", "mage", "SETUP", "Глыба", "shield", "Камень-преграда на клетке до 5 на 3 раунда. Блок 3.",
         dict(cost=0, shape="SINGLE", cast_range=5, special="stone_wall", block=3),
         (dict(cast_range=7), "Камень-преграда на клетке до 7 на 3 раунда. Блок 3."),
         (dict(block=5), "Камень-преграда на клетке до 5 на 3 раунда. Блок 5.")),
    card("stone_m6", "mage", "FINISH", "Сокрушение", "hammer", "Линия 5: 6 урона +1 за звено, толчок 1.\nЦепь 4: стоит 2.",
         dict(cost=3, shape="LINE", cast_range=5, damage=6, push=1, per_link_damage=1, chain_need=4, chain_cost=2),
         (dict(damage=8), "Линия 5: 8 урона +1 за звено, толчок 1.\nЦепь 4: стоит 2."),
         (dict(push=2), "Линия 5: 6 урона +1 за звено, толчок 2.\nЦепь 4: стоит 2."), rare=True),
]
STONE_K = [
    card("stone_k1", "knight", "SETUP", "Каменная кожа", "shield", "Блок 8.",
         dict(cost=1, shape="SELF", cast_range=0, block=8),
         (dict(block=11), "Блок 11."),
         (dict(ally_block=4), "Блок 8; напарнику блок 4.")),
    card("stone_k2", "knight", "LINK", "Удар о камень", "sword", "3 урона вплотную, толчок 2.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=1, damage=3, push=2, chain_need=2, chain_damage=2),
         (dict(damage=4), "4 урона вплотную, толчок 2.\nЦепь 2: +2."),
         (dict(push=3), "3 урона вплотную, толчок 3.\nЦепь 2: +2.")),
    card("stone_k3", "knight", "FINISH", "Обвал щитом", "hammer", "Соседний враг: 5 урона +1 за звено Цепи, толчок 3.",
         dict(cost=2, shape="SINGLE", cast_range=1, damage=5, push=3, per_link_damage=1),
         (dict(damage=7), "Соседний враг: 7 урона +1 за звено, толчок 3."),
         (dict(cost=1), "Соседний враг: 5 урона +1 за звено, толчок 3.")),
    card("stone_k4", "knight", "MOVE", "Скальный шаг", "dash", "+3 шага, блок 2.",
         dict(cost=0, shape="SELF", cast_range=0, bonus_moves=3, block=2),
         (dict(bonus_moves=4), "+4 шага, блок 2."),
         (dict(block=5), "+3 шага, блок 5.")),
    card("stone_k5", "knight", "SETUP", "Вбить камни", "stakes", "Стена из 3 камней до 2 на 3 раунда. Блок 4.",
         dict(cost=1, shape="WALL", cast_range=2, special="stone_wall", block=4),
         (dict(block=7), "Стена из 3 камней до 2 на 3 раунда. Блок 7."),
         (dict(cost=0), "Стена из 3 камней до 2 на 3 раунда. Блок 4.")),
    card("stone_k6", "knight", "FINISH", "Землетрясение", "whirl", "6 клеток вокруг: 5 урона, толчок 1.\nЦепь 4: стоит 1.",
         dict(cost=2, shape="AROUND", cast_range=0, damage=5, push=1, chain_need=4, chain_cost=1),
         (dict(damage=7), "6 клеток вокруг: 7 урона, толчок 1.\nЦепь 4: стоит 1."),
         (dict(push=2), "6 клеток вокруг: 5 урона, толчок 2.\nЦепь 4: стоит 1."), rare=True),
]

# ---------- Котловик: лужи, пар (героя не ранит), мокрый — блок ----------
STEAM_M = [
    card("steam_m1", "mage", "SETUP", "Горячий ключ", "flood", "Круг 1 до 4: лужи, все там мокнут.",
         dict(cost=1, shape="CROSS", cast_range=4, element="WATER"),
         (dict(cast_range=6), "Круг 1 до 6: лужи, все там мокнут."),
         (dict(chain_need=2, chain_cost=0), "Круг 1 до 4: лужи, все мокнут.\nЦепь 2: стоит 0.")),
    card("steam_m2", "mage", "LINK", "Ошпарить", "drop", "Мокрый враг или враг в луже до 4: 2 урона паром, отброс 1.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=4, damage=2, push=1, special="scald", chain_need=2, chain_damage=2),
         (dict(damage=3), "Мокрый враг или враг в луже до 4: 3 урона паром, отброс 1.\nЦепь 2: +2."),
         (dict(cast_range=6), "Мокрый враг или враг в луже до 6: 2 урона паром, отброс 1.\nЦепь 2: +2.")),
    card("steam_m3", "mage", "FINISH", "Паровой столб", "wave", "Линия 4: 4 урона водой +1 за звено, все мокнут, лужи.",
         dict(cost=2, shape="LINE", cast_range=4, damage=4, per_link_damage=1, element="WATER"),
         (dict(damage=5), "Линия 4: 5 урона водой +1 за звено, все мокнут, лужи."),
         (dict(cast_range=6), "Линия 6: 4 урона водой +1 за звено, все мокнут, лужи.")),
    card("steam_m4", "mage", "MOVE", "Струя пара", "dash", "+2 шага, блок 2.",
         dict(cost=0, shape="SELF", cast_range=0, bonus_moves=2, block=2),
         (dict(bonus_moves=3), "+3 шага, блок 2."),
         (dict(draw=1), "+2 шага, блок 2, добор 1.")),
    card("steam_m5", "mage", "SETUP", "Паровая завеса", "wind", "Круг 1 до 3: пар стоит стеной 2 раунда — сквозь него не бьют по линии.",
         dict(cost=1, shape="CROSS", cast_range=3, special="smoke"),
         (dict(cast_range=5), "Круг 1 до 5: пар стоит стеной 2 раунда — сквозь него не бьют по линии."),
         (dict(block=4), "Круг 1 до 3: пар стоит стеной 2 раунда. Блок 4.")),
    card("steam_m6", "mage", "FINISH", "Кипящий котёл", "wave", "Все лужи в 4 клетках вскипают: стоящим в них 5 урона +1 за звено, отброс 1. Лужи исчезают.",
         dict(cost=3, shape="SELF", cast_range=0, special="steam_boil", bonus_amount=5, per_link_damage=1),
         (dict(bonus_amount=7), "Все лужи в 4 клетках вскипают: 7 урона +1 за звено, отброс 1. Лужи исчезают."),
         (dict(cost=2), "Все лужи в 4 клетках вскипают: 5 урона +1 за звено, отброс 1. Лужи исчезают."), rare=True),
]
STEAM_K = [
    card("steam_k1", "knight", "SETUP", "Мокрый щит", "shield", "Блок 6; рыцарь мокнет (с Котловиком мокрый — ещё +2 блока каждый ход).",
         dict(cost=1, shape="SELF", cast_range=0, block=6, special="self_wet"),
         (dict(block=9), "Блок 9; рыцарь мокнет."),
         (dict(ally_block=3), "Блок 6, напарнику 3; рыцарь мокнет.")),
    card("steam_k2", "knight", "LINK", "Обварить", "sword", "3 урона вплотную, цель мокнет.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=1, damage=3, element="WATER", chain_need=2, chain_damage=2),
         (dict(damage=4), "4 урона вплотную, цель мокнет.\nЦепь 2: +2."),
         (dict(push=1), "3 урона вплотную, цель мокнет, толчок 1.\nЦепь 2: +2.")),
    card("steam_k3", "knight", "FINISH", "Паровой таран", "ram", "Таран до 4, за рыцарем лужи. Врезавшись: 5 урона +1 за звено Цепи.",
         dict(cost=2, shape="CHARGE", cast_range=4, damage=5, per_link_damage=1, special="tide_trail"),
         (dict(damage=6), "Таран до 4, за рыцарем лужи. Врезавшись: 6 урона +1 за звено."),
         (dict(cast_range=6), "Таран до 6, за рыцарем лужи. Врезавшись: 5 урона +1 за звено.")),
    card("steam_k4", "knight", "MOVE", "Скользкий шаг", "dash", "+3 шага.",
         dict(cost=0, shape="SELF", cast_range=0, bonus_moves=3),
         (dict(bonus_moves=4), "+4 шага."),
         (dict(block=3), "+3 шага, блок 3.")),
    card("steam_k5", "knight", "SETUP", "Пар из щели", "flood", "6 клеток вокруг: лужи, враги мокнут. Блок 3.",
         dict(cost=1, shape="AROUND", cast_range=0, element="WATER", block=3),
         (dict(block=6), "6 клеток вокруг: лужи, враги мокнут. Блок 6."),
         (dict(cost=0), "6 клеток вокруг: лужи, враги мокнут. Блок 3.")),
    card("steam_k6", "knight", "FINISH", "Взрыв котла", "whirl", "6 клеток вокруг: 5 урона водой, толчок 1, все мокнут.\nЦепь 4: стоит 1.",
         dict(cost=2, shape="AROUND", cast_range=0, damage=5, push=1, element="WATER", chain_need=4, chain_cost=1),
         (dict(damage=7), "6 клеток вокруг: 7 урона водой, толчок 1, все мокнут.\nЦепь 4: стоит 1."),
         (dict(push=2), "6 клеток вокруг: 5 урона водой, толчок 2, все мокнут.\nЦепь 4: стоит 1."), rare=True),
]

# ---------- Сердце Жерла: лава по желанию, по лаве герой идёт (она застывает) ----------
MAGMA_M = [
    card("magma_m1", "mage", "SETUP", "Прорыв лавы", "fire", "Клетка до 4 — лава на 2 раунда: стена, обжигает того, кто там стоит.",
         dict(cost=1, shape="SINGLE", cast_range=4, special="eruption"),
         (dict(cast_range=6), "Клетка до 6 — лава на 2 раунда: стена, обжигает того, кто там стоит."),
         (dict(cost=0), "Клетка до 4 — лава на 2 раунда.")),
    card("magma_m2", "mage", "LINK", "Капля магмы", "spark", "3 урона огнём до 4, клетка цели загорается.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=4, damage=3, element="FIRE", chain_need=2, chain_damage=2),
         (dict(damage=4), "4 урона огнём до 4, поджог.\nЦепь 2: +2."),
         (dict(cast_range=6), "3 урона огнём до 6, поджог.\nЦепь 2: +2.")),
    card("magma_m3", "mage", "FINISH", "Огненная река", "fire", "Линия 5: 4 урона огнём +1 за звено Цепи, клетки горят.",
         dict(cost=2, shape="LINE", cast_range=5, damage=4, per_link_damage=1, element="FIRE"),
         (dict(damage=5), "Линия 5: 5 урона огнём +1 за звено, клетки горят."),
         (dict(chain_need=3, chain_cost=1), "Линия 5: 4 урона огнём +1 за звено, клетки горят.\nЦепь 3: стоит 1.")),
    card("magma_m4", "mage", "MOVE", "Жар недр", "dash", "+2 шага, +1 заряд.",
         dict(cost=0, shape="SELF", cast_range=0, bonus_moves=2, charge_gain=1),
         (dict(bonus_moves=3), "+3 шага, +1 заряд."),
         (dict(charge_gain=2), "+2 шага, +2 заряда.")),
    card("magma_m5", "mage", "SETUP", "Лавовое кольцо", "fire", "Круг 1 до 5 — лава на 2 раунда (под героями не поднимается).",
         dict(cost=2, shape="CROSS", cast_range=5, special="eruption"),
         (dict(cost=1), "Круг 1 до 5 — лава на 2 раунда."),
         (dict(bonus_amount=3), "Круг 1 до 5 — лава на 3 раунда.")),
    card("magma_m6", "mage", "FINISH", "Извержение", "meteor", "Круг 1 до 6: 7 урона огнём +1 за звено, всё горит.\nЦепь 4: стоит 2.",
         dict(cost=3, shape="CROSS", cast_range=6, damage=7, per_link_damage=1, element="FIRE", chain_need=4, chain_cost=2),
         (dict(damage=9), "Круг 1 до 6: 9 урона огнём +1 за звено, всё горит.\nЦепь 4: стоит 2."),
         (dict(special="eruption", bonus_amount=2), "Круг 1 до 6: 7 урона огнём +1 за звено, потом лава на 2 раунда.\nЦепь 4: стоит 2."), rare=True),
]
MAGMA_K = [
    card("magma_k1", "knight", "SETUP", "Раскалённая броня", "shield", "Блок 6; до следующего хода под врагом, подошедшим вплотную, загорается клетка.",
         dict(cost=1, shape="SELF", cast_range=0, block=6, special="ember_guard"),
         (dict(block=9), "Блок 9; под врагом, подошедшим вплотную, загорается клетка."),
         (dict(cost=0), "Блок 6; под врагом, подошедшим вплотную, загорается клетка.")),
    card("magma_k2", "knight", "LINK", "Раскалённый удар", "sword", "3 урона вплотную; по врагу в огне ещё +3.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=1, damage=3, special="hot_blade", bonus_amount=3, chain_need=2, chain_damage=2),
         (dict(damage=4), "4 урона вплотную; по врагу в огне ещё +3.\nЦепь 2: +2."),
         (dict(element="FIRE"), "3 урона вплотную (в огне +3), клетка цели загорается.\nЦепь 2: +2.")),
    card("magma_k3", "knight", "FINISH", "Вдавить в магму", "hammer", "Соседний враг: 2 урона, толчок 3. Упёрся в лаву или стоит в огне — ещё 6 +2 за звено.",
         dict(cost=2, shape="SINGLE", cast_range=1, damage=2, push=3, special="lava_shove", bonus_amount=6),
         (dict(push=4), "Соседний враг: 2 урона, толчок 4. В лаву или в огне — ещё 6 +2 за звено."),
         (dict(cost=1), "Соседний враг: 2 урона, толчок 3. В лаву или в огне — ещё 6 +2 за звено.")),
    card("magma_k4", "knight", "MOVE", "По лаве", "dash", "+3 шага (с Сердцем Жерла лава под ногами застывает коркой).",
         dict(cost=0, shape="SELF", cast_range=0, bonus_moves=3),
         (dict(bonus_moves=4), "+4 шага."),
         (dict(momentum_gain=2), "+3 шага, +2 натиска.")),
    card("magma_k5", "knight", "SETUP", "Стена магмы", "fire", "Стена из 3 клеток лавы до 3 на 2 раунда.",
         dict(cost=1, shape="WALL", cast_range=3, special="eruption"),
         (dict(cost=0), "Стена из 3 клеток лавы до 3 на 2 раунда."),
         (dict(block=5), "Стена из 3 клеток лавы до 3 на 2 раунда. Блок 5.")),
    card("magma_k6", "knight", "FINISH", "Сердце вулкана", "whirl", "6 клеток вокруг: 6 урона огнём, клетки горят.\nЦепь 4: стоит 1.",
         dict(cost=2, shape="AROUND", cast_range=0, damage=6, element="FIRE", chain_need=4, chain_cost=1),
         (dict(damage=8), "6 клеток вокруг: 8 урона огнём, клетки горят.\nЦепь 4: стоит 1."),
         (dict(rage_gain=2), "6 клеток вокруг: 6 урона огнём, +2 ярости.\nЦепь 4: стоит 1."), rare=True),
]

# ---------- Ржавник: снимает блок и ослабляет удары врагов, блок героя частично копится ----------
RUST_M = [
    card("rust_m1", "mage", "SETUP", "Ржавая пыль", "poison", "Круг 1 до 4: враги теряют блок, их удары −2 до конца раунда.",
         dict(cost=1, shape="CROSS", cast_range=4, special="rust_area"),
         (dict(cast_range=6), "Круг 1 до 6: враги теряют блок, их удары −2 до конца раунда."),
         (dict(cost=0), "Круг 1 до 4: враги теряют блок, удары −2.")),
    card("rust_m2", "mage", "LINK", "Ржавый шип", "spark", "3 урона до 4 сквозь блок.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=4, damage=3, pierce_block=True, chain_need=2, chain_damage=2),
         (dict(damage=4), "4 урона до 4 сквозь блок.\nЦепь 2: +2."),
         (dict(cast_range=6), "3 урона до 6 сквозь блок.\nЦепь 2: +2.")),
    card("rust_m3", "mage", "FINISH", "Железный ливень", "meteor", "Круг 1 до 5: 4 урона сквозь блок +1 за звено Цепи.",
         dict(cost=2, shape="CROSS", cast_range=5, damage=4, per_link_damage=1, pierce_block=True),
         (dict(damage=5), "Круг 1 до 5: 5 урона сквозь блок +1 за звено."),
         (dict(chain_need=3, chain_cost=1), "Круг 1 до 5: 4 урона сквозь блок +1 за звено.\nЦепь 3: стоит 1.")),
    card("rust_m4", "mage", "MOVE", "Магнитный шаг", "dash", "+2 шага, добор 1.",
         dict(cost=0, shape="SELF", cast_range=0, bonus_moves=2, draw=1),
         (dict(bonus_moves=3), "+3 шага, добор 1."),
         (dict(block=3), "+2 шага, добор 1, блок 3.")),
    card("rust_m5", "mage", "SETUP", "Окалина", "shield", "Блок 5; напарнику блок 3.",
         dict(cost=1, shape="SELF", cast_range=0, block=5, ally_block=3),
         (dict(block=8), "Блок 8; напарнику блок 3."),
         (dict(ally_block=6), "Блок 5; напарнику блок 6.")),
    card("rust_m6", "mage", "FINISH", "Распад", "poison", "Враг до 5: 8 урона сквозь блок +1 за звено; ржавеет (удары −2).\nЦепь 4: стоит 2.",
         dict(cost=3, shape="SINGLE", cast_range=5, damage=8, per_link_damage=1, pierce_block=True, special="rust_hit", chain_need=4, chain_cost=2),
         (dict(damage=11), "Враг до 5: 11 урона сквозь блок +1 за звено; ржавеет.\nЦепь 4: стоит 2."),
         (dict(cost=2, chain_need=0, chain_cost=-1), "Враг до 5: 8 урона сквозь блок +1 за звено; ржавеет."), rare=True),
]
RUST_K = [
    card("rust_k1", "knight", "SETUP", "Железная стойка", "shield", "Блок 7 (с Ржавником до 3 блока переходят на следующий ход).",
         dict(cost=1, shape="SELF", cast_range=0, block=7),
         (dict(block=10), "Блок 10."),
         (dict(taunt=True), "Блок 7; провокация.")),
    card("rust_k2", "knight", "LINK", "Ржавый клинок", "sword", "3 урона вплотную; цель теряет блок, её удары −2 до конца раунда.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=1, damage=3, special="rust_hit", chain_need=2, chain_damage=2),
         (dict(damage=4), "4 урона вплотную; цель ржавеет.\nЦепь 2: +2."),
         (dict(cast_range=2), "3 урона до 2; цель ржавеет.\nЦепь 2: +2.")),
    card("rust_k3", "knight", "FINISH", "Сломать броню", "hammer", "Соседний враг: 5 урона сквозь блок +1 за звено Цепи.",
         dict(cost=2, shape="SINGLE", cast_range=1, damage=5, per_link_damage=1, pierce_block=True),
         (dict(damage=7), "Соседний враг: 7 урона сквозь блок +1 за звено."),
         (dict(push=2), "Соседний враг: 5 урона сквозь блок +1 за звено, толчок 2.")),
    card("rust_k4", "knight", "MOVE", "Тяжёлый шаг", "dash", "+2 шага, блок 3.",
         dict(cost=0, shape="SELF", cast_range=0, bonus_moves=2, block=3),
         (dict(bonus_moves=3), "+3 шага, блок 3."),
         (dict(block=6), "+2 шага, блок 6.")),
    card("rust_k5", "knight", "SETUP", "Ржавчина вокруг", "poison", "Враги на 6 клетках вокруг теряют блок, удары −2. Блок 3.",
         dict(cost=1, shape="AROUND", cast_range=0, special="rust_area", block=3),
         (dict(block=6), "Враги вокруг теряют блок, удары −2. Блок 6."),
         (dict(cost=0), "Враги вокруг теряют блок, удары −2. Блок 3.")),
    card("rust_k6", "knight", "FINISH", "Лом", "slash", "Дуга: 5 урона сквозь блок, толчок 1.\nЦепь 4: стоит 1.",
         dict(cost=2, shape="ARC", cast_range=1, damage=5, push=1, pierce_block=True, chain_need=4, chain_cost=1),
         (dict(damage=7), "Дуга: 7 урона сквозь блок, толчок 1.\nЦепь 4: стоит 1."),
         (dict(push=2), "Дуга: 5 урона сквозь блок, толчок 2.\nЦепь 4: стоит 1."), rare=True),
]


def pair(a, b, rows):
    return [card(f"mix_{a}_{b}_{'m' if h == 'mage' else 'k'}{i}", h, role, title, icon, text, f, up1, up2)
            for (h, role, title, icon, text, f, up1, up2), i in zip(rows, (1, 2, 1, 2))]


PAIRS = {
    (A, W): pair(A, W, [   # «Пепельная буря»
        ("mage", "SETUP", "Задуть дым", "wind", "Линия 4: толчок 2, клетки затягивает дымом на 2 раунда.",
         dict(cost=1, shape="LINE", cast_range=4, push=2, special="smoke_after"),
         (dict(cast_range=6), "Линия 6: толчок 2, клетки затягивает дымом на 2 раунда."),
         (dict(push=3), "Линия 4: толчок 3, клетки затягивает дымом.")),
        ("mage", "FINISH", "Пепельный смерч", "whirl", "Клетка до 5: враги в 2 клетках стягиваются к ней на 1, 2 урона +1 за звено; круг 1 горит.",
         dict(cost=2, shape="SINGLE", cast_range=5, special="fire_vortex", bonus_amount=2, per_link_damage=1),
         (dict(bonus_amount=3), "Клетка до 5: враги в 2 клетках стягиваются на 1, 3 урона +1 за звено; круг 1 горит."),
         (dict(cost=1), "Клетка до 5: стягивает на 1, 2 урона +1 за звено; круг 1 горит.")),
        ("knight", "LINK", "Пыльный порыв", "slash", "Линия 3: 2 урона, толчок 1, потом дым.",
         dict(cost=0, shape="LINE", cast_range=3, damage=2, push=1, special="smoke_after"),
         (dict(damage=3), "Линия 3: 3 урона, толчок 1, потом дым."),
         (dict(push=2), "Линия 3: 2 урона, толчок 2, потом дым.")),
        ("knight", "FINISH", "Буря сквозь пепел", "ram", "Сквозной таран до 5: каждому 3 урона +1 за звено и отлёт вбок, путь горит.",
         dict(cost=2, shape="CHARGE", cast_range=5, damage=3, per_link_damage=1, special="fire_pass"),
         (dict(damage=4), "Сквозной таран до 5: каждому 4 урона +1 за звено, путь горит."),
         (dict(cast_range=7), "Сквозной таран до 7: каждому 3 урона +1 за звено, путь горит.")),
    ]),
    (ST, F): pair(ST, F, [   # «Шлак»
        ("mage", "LINK", "Раскалённый камень", "spark", "3 урона огнём до 4, толчок 1, поджог.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=4, damage=3, push=1, element="FIRE", chain_need=2, chain_damage=2),
         (dict(damage=4), "4 урона огнём до 4, толчок 1, поджог.\nЦепь 2: +2."),
         (dict(push=2), "3 урона огнём до 4, толчок 2, поджог.\nЦепь 2: +2.")),
        ("mage", "FINISH", "Шлаковый обвал", "meteor", "Круг 1 до 5: 5 урона огнём +1 за звено, всё горит.",
         dict(cost=2, shape="CROSS", cast_range=5, damage=5, per_link_damage=1, element="FIRE"),
         (dict(damage=6), "Круг 1 до 5: 6 урона огнём +1 за звено, всё горит."),
         (dict(chain_need=3, chain_cost=1), "Круг 1 до 5: 5 урона огнём +1 за звено.\nЦепь 3: стоит 1.")),
        ("knight", "LINK", "Шлаковый удар", "sword", "3 урона огнём вплотную, толчок 2.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=1, damage=3, push=2, element="FIRE", chain_need=2, chain_damage=2),
         (dict(damage=4), "4 урона огнём вплотную, толчок 2.\nЦепь 2: +2."),
         (dict(push=3), "3 урона огнём вплотную, толчок 3.\nЦепь 2: +2.")),
        ("knight", "FINISH", "Обжигающая глыба", "ram", "Таран до 4, путь горит. Врезавшись: 6 урона +1 за звено, под целью огонь.",
         dict(cost=2, shape="CHARGE", cast_range=4, damage=6, per_link_damage=1, special="fire_trail"),
         (dict(damage=8), "Таран до 4, путь горит. Врезавшись: 8 урона +1 за звено."),
         (dict(cast_range=6), "Таран до 6, путь горит. Врезавшись: 6 урона +1 за звено.")),
    ]),
    (MG, T): pair(MG, T, [   # «Обсидиан»
        ("mage", "SETUP", "Остудить", "flood", "Круг 1 до 4: лужи; лава застывает коркой, все там мокнут.",
         dict(cost=1, shape="CROSS", cast_range=4, element="WATER"),
         (dict(cast_range=6), "Круг 1 до 6: лужи; лава застывает коркой."),
         (dict(cost=0), "Круг 1 до 4: лужи; лава застывает коркой.")),
        ("mage", "FINISH", "Обсидиановый осколок", "spark", "Линия 5: 5 урона сквозь блок +1 за звено Цепи.",
         dict(cost=2, shape="LINE", cast_range=5, damage=5, per_link_damage=1, pierce_block=True),
         (dict(damage=6), "Линия 5: 6 урона сквозь блок +1 за звено."),
         (dict(chain_need=3, chain_cost=1), "Линия 5: 5 урона сквозь блок +1 за звено.\nЦепь 3: стоит 1.")),
        ("knight", "SETUP", "Обсидиановый щит", "shield", "Блок 9.",
         dict(cost=1, shape="SELF", cast_range=0, block=9),
         (dict(block=12), "Блок 12."),
         (dict(ally_block=4), "Блок 9; напарнику 4.")),
        ("knight", "LINK", "Застывший удар", "sword", "4 урона водой вплотную; цель мокнет, лава под ней застывает.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=1, damage=4, element="WATER", chain_need=2, chain_damage=2),
         (dict(damage=5), "5 урона водой вплотную, цель мокнет.\nЦепь 2: +2."),
         (dict(push=1), "4 урона водой вплотную, цель мокнет, толчок 1.\nЦепь 2: +2.")),
    ]),
    (SM, S): pair(SM, S, [   # «Паровой разряд»
        ("mage", "LINK", "Грозовой пар", "bolt", "2 урона молнией до 4; в луже — по всей луже.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=4, damage=2, element="LIGHTNING", chain_need=2, chain_damage=2),
         (dict(damage=3), "3 урона молнией до 4; в луже — по всей луже.\nЦепь 2: +2."),
         (dict(cast_range=6), "2 урона молнией до 6; в луже — по всей луже.\nЦепь 2: +2.")),
        ("mage", "FINISH", "Паровой разряд", "bolt", "Круг 1 до 5: 4 урона молнией +1 за звено; лужи проводят разряд.",
         dict(cost=2, shape="CROSS", cast_range=5, damage=4, per_link_damage=1, element="LIGHTNING"),
         (dict(damage=5), "Круг 1 до 5: 5 урона молнией +1 за звено; лужи проводят разряд."),
         (dict(chain_need=3, chain_cost=1), "Круг 1 до 5: 4 урона молнией +1 за звено.\nЦепь 3: стоит 1.")),
        ("knight", "LINK", "Мокрая сталь", "sword", "3 урона вплотную; по мокрому — молнией (сильнее).\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=1, damage=3, special="wet_steel", chain_need=2, chain_damage=2),
         (dict(damage=4), "4 урона вплотную; по мокрому — молнией.\nЦепь 2: +2."),
         (dict(cast_range=2), "3 урона до 2; по мокрому — молнией.\nЦепь 2: +2.")),
        ("knight", "FINISH", "Грозовой котёл", "whirl", "6 клеток вокруг: 4 урона молнией +1 за звено; лужи проводят разряд.",
         dict(cost=2, shape="AROUND", cast_range=0, damage=4, per_link_damage=1, element="LIGHTNING"),
         (dict(damage=5), "6 клеток вокруг: 5 урона молнией +1 за звено."),
         (dict(block=4), "6 клеток вокруг: 4 урона молнией +1 за звено. Блок 4.")),
    ]),
    (RU, T): pair(RU, T, [   # «Ржа»
        ("mage", "SETUP", "Ржавая вода", "flood", "Круг 1 до 4: лужи, враги мокнут и ржавеют (без блока, удары −2).",
         dict(cost=1, shape="CROSS", cast_range=4, element="WATER", special="rust_area"),
         (dict(cast_range=6), "Круг 1 до 6: лужи, враги мокнут и ржавеют."),
         (dict(cost=0), "Круг 1 до 4: лужи, враги мокнут и ржавеют.")),
        ("mage", "FINISH", "Разъесть", "poison", "Враг до 5: 6 урона сквозь блок +1 за звено; цель ржавеет (удары −2).",
         dict(cost=2, shape="SINGLE", cast_range=5, damage=6, per_link_damage=1, pierce_block=True, special="rust_hit"),
         (dict(damage=8), "Враг до 5: 8 урона сквозь блок +1 за звено; ржавеет."),
         (dict(chain_need=3, chain_cost=1), "Враг до 5: 6 урона сквозь блок +1 за звено; ржавеет.\nЦепь 3: стоит 1.")),
        ("knight", "LINK", "Мокрая ржавчина", "sword", "3 урона водой вплотную; цель мокнет и ржавеет.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=1, damage=3, element="WATER", special="rust_hit", chain_need=2, chain_damage=2),
         (dict(damage=4), "4 урона водой вплотную; цель мокнет и ржавеет.\nЦепь 2: +2."),
         (dict(push=1), "3 урона водой вплотную, толчок 1; цель мокнет и ржавеет.\nЦепь 2: +2.")),
        ("knight", "FINISH", "Ржавый вал", "ram", "Таран до 4, за рыцарем лужи. Врезавшись: 5 урона сквозь блок +1 за звено.",
         dict(cost=2, shape="CHARGE", cast_range=4, damage=5, per_link_damage=1, pierce_block=True, special="tide_trail"),
         (dict(damage=7), "Таран до 4, за рыцарем лужи. Врезавшись: 7 урона сквозь блок +1 за звено."),
         (dict(cast_range=6), "Таран до 6, за рыцарем лужи. Врезавшись: 5 урона сквозь блок +1 за звено.")),
    ]),
}

SPIRITS = [
    dict(sid=A, title="Пепельник", color="0.62, 0.6, 0.56, 1", icon="wind", unique=False,
         desc="Дым над выжженным трактом. Он прячет тех, кто ему нравится.",
         passive="рядом огонь или дым — в начале хода +2 блока.", m=ASH_M, k=ASH_K,
         call=("Зов: Завеса", "wind", "Зов духа (раз в бой): круг 1 до 3 — дым на 2 раунда, закрывает линии.",
               dict(cost=0, shape="CROSS", cast_range=3, special="smoke", is_call=True, chain_add=-1, scrap_moves=0)),
         enemy="spirit_ash"),
    dict(sid=ST, title="Каменник", color="0.5, 0.52, 0.55, 1", icon="shield", unique=False,
         desc="Камни подземья помнят, где стояли стены. Он ставит их снова.",
         passive="+1 блок в начале хода за каждую соседнюю преграду (до +3).", m=STONE_M, k=STONE_K,
         call=("Зов: Обвал", "shield", "Зов духа (раз в бой): стена из 3 камней-преград до 4 на 3 раунда.",
               dict(cost=0, shape="WALL", cast_range=4, special="stone_wall", is_call=True, chain_add=-1, scrap_moves=0)),
         enemy="spirit_stone"),
    dict(sid=SM, title="Котловик", color="0.82, 0.86, 0.88, 1", icon="wave", unique=True,
         desc="Кипит в ключах у тракта. Кто не боится обжечься, тому он тёплый.",
         passive="пар не ранит героя; мокрый — в начале хода +2 блока.", m=STEAM_M, k=STEAM_K,
         call=("Зов: Гейзер", "wave", "Зов духа (раз в бой): все лужи в 4 клетках вскипают — стоящим в них 3 урона, отброс 1.",
               dict(cost=0, shape="SELF", cast_range=0, special="steam_boil", bonus_amount=3, is_call=True, chain_add=-1, scrap_moves=0)),
         enemy="spirit_steam"),
    dict(sid=MG, title="Сердце Жерла", color="1, 0.45, 0.12, 1", icon="fire", unique=True,
         desc="Пленник Сосуда Венца. Вулкан помнит, кто его выпустил.",
         passive="лава под героем застывает коркой: по ней можно пройти, толкнули в лаву — без урона.", m=MAGMA_M, k=MAGMA_K,
         call=("Зов: Извержение", "fire", "Зов духа (раз в бой): круг 1 до 4 — лава на 2 раунда (под героями не поднимается).",
               dict(cost=0, shape="CROSS", cast_range=4, special="eruption", is_call=True, chain_add=-1, scrap_moves=0)),
         enemy=None),
    dict(sid=RU, title="Ржавник", color="0.55, 0.38, 0.26, 1", icon="poison", unique=True,
         desc="Сердце Колосса. Железо, которое устало служить.",
         passive="до 3 блока переходят на следующий ход.", m=RUST_M, k=RUST_K,
         call=("Зов: Ржавчина", "poison", "Зов духа (раз в бой): враги в 2 клетках теряют блок, их удары −2 до конца раунда.",
               dict(cost=0, shape="SELF", cast_range=0, special="rust", bonus_amount=2, is_call=True, chain_add=-1, scrap_moves=0)),
         enemy=None),
]


def write_spirit_enemy(sid, title, desc, hp, color, size, extra, attacks):
    lines = ['[gd_resource type="Resource" script_class="EnemyData" load_steps=5 format=3]', "",
             '[ext_resource type="Script" path="res://scripts/data/enemy_data.gd" id="1_enemy"]',
             '[ext_resource type="Script" path="res://scripts/data/enemy_attack_data.gd" id="2_attack"]',
             f'[ext_resource type="PackedScene" path="res://assets/models/{sid}.glb" id="9_model"]', ""]
    ids = []
    for i, a in enumerate(attacks):
        lines += [f'[sub_resource type="Resource" id="atk{i}"]', 'script = ExtResource("2_attack")']
        lines += [f"{k} = {gd(v)}" for k, v in a.items()]
        lines.append("")
        ids.append(f'SubResource("atk{i}")')
    lines += ["[resource]", 'script = ExtResource("1_enemy")', f"id = {gd(sid)}", f"title = {gd(title)}",
              f"description = {gd(desc)}", f"max_hp = {hp}", "move_range = 2", f"damage = {attacks[0].get('damage', 3)}",
              f"color = Color({color})", f"size = {size}", "tamable = true"] + extra + \
             ['cycle = Array[ExtResource("2_attack")]([' + ", ".join(ids) + "])", 'model = ExtResource("9_model")']
    with open(f"resources/enemies/{sid}.tres", "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


def write_spirit_res(sp, call_path, mage, knight, mixed):
    refs = {}

    def ref(p):
        if p not in refs:
            refs[p] = f"c{len(refs) + 1}"
        return f'ExtResource("{refs[p]}")'
    body = ["[resource]", 'script = ExtResource("1_spirit")', f"id = {gd(sp['sid'])}", f"title = {gd(sp['title'])}",
            f"description = {gd(sp['desc'])}", f"passive_text = {gd(sp['passive'])}", f"color = Color({sp['color']})",
            f"icon = {gd(sp['icon'])}"]
    if sp["unique"]:
        body.append("is_unique = true")
    body += [f"call_card = {ref(call_path)}",
             'mage_cards = Array[ExtResource("2_card")]([' + ", ".join(ref(p) for p in mage) + "])",
             'knight_cards = Array[ExtResource("2_card")]([' + ", ".join(ref(p) for p in knight) + "])",
             'mixed_cards = Array[ExtResource("2_card")]([' + ", ".join(ref(p) for p in mixed) + "])"]
    if sp["enemy"]:
        body.append(f'enemy = {ref("res://resources/enemies/" + sp["enemy"] + ".tres")}')
    head = [f'[gd_resource type="Resource" script_class="SpiritData" load_steps={len(refs) + 3} format=3]', "",
            '[ext_resource type="Script" path="res://scripts/data/spirit_data.gd" id="1_spirit"]',
            '[ext_resource type="Script" path="res://scripts/data/card_data.gd" id="2_card"]']
    head += [f'[ext_resource type="Resource" path="{p}" id="{i}"]' for p, i in refs.items()]
    with open(f"resources/spirits/{sp['sid']}.tres", "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(head + [""] + body) + "\n")


if __name__ == "__main__":
    write_spirit_enemy("spirit_ash", "Пепельник", "Дым над выжженным трактом. Он прячет тех, кто ему нравится.", 26,
                       "0.6, 0.58, 0.55, 1", 1.0, ["is_elite = true", "fire_walker = true"],
                       [dict(title="Пепельный хлыст", shape=1, attack_range=3, damage=3, first_only=True, ignite=True),
                        dict(title="Тлеющий вихрь", anim="Attack2", shape=4, damage=3, push=1, ignite=True)])
    write_spirit_enemy("spirit_stone", "Каменник", "Камни подземья помнят, где стояли стены. Он ставит их снова.", 30,
                       "0.5, 0.52, 0.55, 1", 1.0, ["is_elite = true", "turn_block = 2", "bog_damage = 6"],
                       [dict(title="Каменный кулак", shape=0, damage=4, push=1),
                        dict(title="Обвал", anim="Attack2", shape=4, damage=3, push=1)])
    write_spirit_enemy("spirit_steam", "Котловик", "Кипит в ключах у тракта. Кто не боится обжечься, тому он тёплый.", 60,
                       "0.82, 0.86, 0.88, 1", 1.1, ["is_boss = true", "turn_block = 3", "bog_damage = 8", "always_wet = true"],
                       [dict(title="Струя кипятка", shape=1, attack_range=4, damage=4, first_only=True, puddle=True),
                        dict(title="Гейзер", anim="Attack2", shape=4, damage=5, push=1),
                        dict(title="Пар клубами", anim="Attack", shape=3, attack_range=2, damage=0, ally_block=3, ally_damage=1)])
    total = 0
    for sp in SPIRITS:
        d = f"resources/cards/spirits/{sp['sid']}"
        m = write_set(sp["m"], d, [sp["sid"]], f"s_{sp['sid']}")
        k = write_set(sp["k"], d, [sp["sid"]], f"s_{sp['sid']}")
        mixed = []
        for (a, b), cards in PAIRS.items():
            if a == sp["sid"]:
                mixed += write_set(cards, "resources/cards/mixed", [a, b], f"x_{a}_{b}")
        title, icon, text, f = sp["call"]
        call = card(f"{sp['sid']}_call", "", "", title, icon, text, f, None, None, cset=f"s_{sp['sid']}")
        call_path = write_card(call, d)
        write_spirit_res(sp, call_path, m, k, mixed)
        total += len(m) + len(k) + len(mixed) + 1
    print("духи акта 2: карт", total)

# Генератор духов этапа 4 (тз-карты.md 7.3, 7.4, 8): Вихорь, Хозяин трясины ★ и 5 смешанных пар.
# Запуск из папки проекта: python tools/cards/gen_spirit_cards_2.py
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from gen_spirit_cards import card, write_set, write_card, write_enemy, write_spirit  # noqa: E402

W, B, T, S = "wind", "bog", "tide", "storm"

WIND_M = [
    card("wind_m1", "mage", "SETUP", "Порыв", "wind", "Линия 5: всех толкает на 2 от мага.",
         dict(cost=1, shape="LINE", cast_range=5, push=2),
         (dict(cast_range=7), "Линия 7: всех толкает на 2 от мага."),
         (dict(chain_need=2, chain_cost=0), "Линия 5: всех толкает на 2 от мага.\nЦепь 2: стоит 0.")),
    card("wind_m2", "mage", "LINK", "Свист", "wind", "Враг до 4: толчок 1 от мага.\nЦепь 2: толчок 2.",
         dict(cost=0, shape="SINGLE", cast_range=4, push=1, chain_need=2, chain_push=1),
         (dict(damage=2), "Враг до 4: 2 урона, толчок 1 от мага.\nЦепь 2: толчок 2."),
         (dict(draw=1), "Враг до 4: толчок 1 от мага, добор 1.\nЦепь 2: толчок 2.")),
    card("wind_m3", "mage", "FINISH", "Смерч", "whirl", "Клетка до 5: враги в 2 клетках стягиваются к ней на 1 (столкновения); каждому 1 урон +1 за звено.",
         dict(cost=2, shape="SINGLE", cast_range=5, special="vortex", bonus_amount=1, per_link_damage=1),
         (dict(), "Клетка до 5: враги в 2 клетках стягиваются к ней на 2; каждому 1 урон +1 за звено."),
         (dict(chain_need=4, chain_cost=1), "Клетка до 5: враги в 2 клетках стягиваются на 1; 1 урон +1 за звено.\nЦепь 4: стоит 1.")),
    card("wind_m4", "mage", "MOVE", "Невесомость", "leap", "Маг перелетает до 4 через преграды и трясину, +1 шаг.",
         dict(cost=1, shape="LEAP", cast_range=4, bonus_moves=1),
         (dict(cost=0), "Маг перелетает до 4 через преграды и трясину, +1 шаг."),
         (dict(cast_range=6), "Маг перелетает до 6 через преграды и трясину, +1 шаг.")),
    card("wind_m5", "mage", "SETUP", "Сдуть", "wind", "Огонь и газ в 3 клетках от клетки до 5 сносит на 2 от мага.",
         dict(cost=1, shape="SINGLE", cast_range=5, special="blow"),
         (dict(cost=0), "Огонь и газ в 3 клетках от клетки до 5 сносит на 2 от мага."),
         (dict(), "Огонь, газ и врагов в 3 клетках от клетки до 5 сносит на 2 от мага.")),
    card("wind_m6", "mage", "FINISH", "Буря", "wind", "Все враги в 4 клетках отлетают на 2 от мага, столкновения вдвое сильнее (8).\nЦепь 4: стоит 2.",
         dict(cost=3, shape="SELF", cast_range=0, special="storm_push", bonus_amount=2, chain_need=4, chain_cost=2),
         (dict(cost=2), "Все враги в 4 клетках отлетают на 2 от мага, столкновения вдвое сильнее (8)."),
         (dict(bonus_amount=3), "Все враги в 4 клетках отлетают на 3 от мага, столкновения вдвое (8).\nЦепь 4: стоит 2."), rare=True),
]
WIND_K = [
    card("wind_k1", "knight", "SETUP", "Ветер в спину", "dash", "+3 шага, +1 натиск.",
         dict(cost=0, shape="SELF", cast_range=0, bonus_moves=3, momentum_gain=1),
         (dict(bonus_moves=4), "+4 шага, +1 натиск."),
         (dict(momentum_gain=3), "+3 шага, +3 натиска.")),
    card("wind_k2", "knight", "LINK", "Режущий ветер", "slash", "Линия 3: 2 урона каждому, толчок 1.\nЦепь 2: +2.",
         dict(cost=0, shape="LINE", cast_range=3, damage=2, push=1, chain_need=2, chain_damage=2),
         (dict(damage=3), "Линия 3: 3 урона каждому, толчок 1.\nЦепь 2: +2."),
         (dict(push=2), "Линия 3: 2 урона каждому, толчок 2.\nЦепь 2: +2.")),
    card("wind_k3", "knight", "FINISH", "Ураганный размах", "whirl", "Дуга: 4 урона, толчок 2.\nЦепь 3: толчок 3.",
         dict(cost=2, shape="ARC", cast_range=1, damage=4, push=2, chain_need=3, chain_push=1),
         (dict(damage=6), "Дуга: 6 урона, толчок 2.\nЦепь 3: толчок 3."),
         (dict(shape="AROUND", cast_range=0), "6 клеток вокруг: 4 урона, толчок 2.\nЦепь 3: толчок 3.")),
    card("wind_k4", "knight", "LINK", "Отбросить", "boot", "Соседний враг: 2 урона, толчок 3.",
         dict(cost=1, shape="SINGLE", cast_range=1, damage=2, push=3),
         (dict(cost=0), "Соседний враг: 2 урона, толчок 3."),
         (dict(push=4), "Соседний враг: 2 урона, толчок 4.")),
    card("wind_k5", "knight", "SETUP", "Вихрь вокруг", "wind", "Блок 4; до следующего хода враг, подошедший вплотную, отлетает на 2.",
         dict(cost=1, shape="SELF", cast_range=0, block=4, special="gust_guard", bonus_amount=2),
         (dict(block=7), "Блок 7; до следующего хода враг, подошедший вплотную, отлетает на 2."),
         (dict(bonus_amount=3), "Блок 4; до следующего хода враг, подошедший вплотную, отлетает на 3.")),
    card("wind_k6", "knight", "FINISH", "Небесный таран", "leap", "Прыжок до 4: соседям 3 урона + натиск, толчок 2.\nЦепь 3: толчок 3.",
         dict(cost=2, shape="LEAP", cast_range=4, damage=3, push=2, special="leap_push", chain_need=3, chain_push=1),
         (dict(damage=5), "Прыжок до 4: соседям 5 урона + натиск, толчок 2.\nЦепь 3: толчок 3."),
         (dict(cast_range=6), "Прыжок до 6: соседям 3 урона + натиск, толчок 2.\nЦепь 3: толчок 3."), rare=True),
]
BOG_M = [
    card("bog_m1", "mage", "SETUP", "Топь", "maw", "Круг 1 до 4: клетки становятся топью.",
         dict(cost=1, shape="CROSS", cast_range=4, special="swamp_area"),
         (dict(cast_range=6), "Круг 1 до 6: клетки становятся топью."),
         (dict(bonus_amount=1), "Круг 1 до 4: клетки становятся топью, враг в центре опутан.")),
    card("bog_m2", "mage", "LINK", "Хватка тины", "entangled", "Враг до 4 опутан на 1 ход.\nЦепь 2: стоит 0.",
         dict(cost=1, shape="SINGLE", cast_range=4, special="entangle", chain_need=2, chain_cost=0),
         (dict(cast_range=6), "Враг до 6 опутан на 1 ход.\nЦепь 2: стоит 0."),
         (dict(damage=3), "Враг до 4: 3 урона, опутан на 1 ход.\nЦепь 2: стоит 0.")),
    card("bog_m3", "mage", "FINISH", "Засасывание", "maw", "Враги в 5 клетках в топи, луже или у трясины: 3 урона +1 за звено, опутаны.",
         dict(cost=2, shape="SELF", cast_range=0, special="suck", bonus_amount=3, per_link_damage=1),
         (dict(bonus_amount=4), "Враги в 5 клетках в топи, луже или у трясины: 4 урона +1 за звено, опутаны."),
         (dict(chain_need=4, chain_cost=1), "Враги в топи, луже или у трясины: 3 урона +1 за звено, опутаны.\nЦепь 4: стоит 1.")),
    card("bog_m4", "mage", "MOVE", "Кочка", "planks", "+1 шаг; в этот ход топь не отнимает шагов у обоих героев.",
         dict(cost=0, shape="SELF", cast_range=0, bonus_moves=1, special="swamp_walk"),
         (dict(bonus_moves=2), "+2 шага; в этот ход топь не отнимает шагов у обоих героев."),
         (dict(draw=1), "+1 шаг, добор 1; в этот ход топь не отнимает шагов у героев.")),
    card("bog_m5", "mage", "SETUP", "Болотный газ", "poison", "Топь в клетке до 5 и соседние клетки топи становятся газом.",
         dict(cost=1, shape="SINGLE", cast_range=5, special="swamp_gas"),
         (dict(cost=0), "Топь в клетке до 5 и соседние клетки топи становятся газом."),
         (dict(), "Вся топь в 3 клетках от клетки до 5 становится газом.")),
    card("bog_m6", "mage", "FINISH", "Пасть топей", "maw", "Круг 1 до 5: трясина на 2 раунда, враги внутри опутаны; толкнутый в неё тонет.",
         dict(cost=2, shape="CROSS", cast_range=5, special="bog_maw"),
         (dict(cost=1), "Круг 1 до 5: трясина на 2 раунда, враги внутри опутаны; толкнутый в неё тонет."),
         (dict(chain_need=3, chain_cost=1), "Круг 1 до 5: трясина на 2 раунда, враги опутаны.\nЦепь 3: стоит 1."), rare=True),
]
BOG_K = [
    card("bog_k1", "knight", "SETUP", "Тяжёлая поступь", "maw", "6 клеток вокруг рыцаря становятся топью; блок 4.",
         dict(cost=1, shape="SELF", cast_range=0, block=4, special="stomp"),
         (dict(block=7), "6 клеток вокруг рыцаря становятся топью; блок 7."),
         (dict(cost=0), "6 клеток вокруг рыцаря становятся топью; блок 4.")),
    card("bog_k2", "knight", "LINK", "Вдавить", "hammer", "3 урона вплотную; цель в топи или луже — опутана.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=1, damage=3, special="press", chain_need=2, chain_damage=2),
         (dict(damage=4), "4 урона вплотную; цель в топи или луже — опутана.\nЦепь 2: +2."),
         (dict(), "3 урона вплотную, цель опутана.\nЦепь 2: +2.")),
    card("bog_k3", "knight", "FINISH", "Утопить", "hammer", "6 урона вплотную +1 за звено, толчок 2 (в трясину — тонет, в топь — опутан).",
         dict(cost=2, shape="SINGLE", cast_range=1, damage=6, per_link_damage=1, push=2, special="mire_push"),
         (dict(push=3), "6 урона вплотную +1 за звено, толчок 3 (в трясину — тонет, в топь — опутан)."),
         (dict(per_link_damage=2), "6 урона вплотную +2 за звено, толчок 2 (в трясину — тонет, в топь — опутан).")),
    card("bog_k4", "knight", "SETUP", "Корни под ногами", "entangled", "Провокация; до следующего хода враги, подошедшие вплотную, опутаны.",
         dict(cost=1, shape="SELF", cast_range=0, taunt=True, special="root_guard"),
         (dict(block=5), "Провокация, блок 5; враги, подошедшие вплотную, опутаны."),
         (dict(cost=0), "Провокация; до следующего хода враги, подошедшие вплотную, опутаны.")),
    card("bog_k5", "knight", "SETUP", "Болотный панцирь", "shield", "Блок 4 +2 за каждую клетку топи, лужи или трясины вокруг.",
         dict(cost=1, shape="SELF", cast_range=0, block=4, special="bog_shell", bonus_amount=2),
         (dict(bonus_amount=3), "Блок 4 +3 за каждую клетку топи, лужи или трясины вокруг."),
         (dict(), "Блок 4 +2 за топкую клетку вокруг — и союзнику столько же.")),
    card("bog_k6", "knight", "FINISH", "Трясина под ним", "maw", "Соседний враг: под ним трясина на 2 раунда. Обычный тонет; тяжёлый — 8 урона и опутан.\nЦепь 4: стоит 1.",
         dict(cost=2, shape="SINGLE", cast_range=1, special="sink", bonus_amount=8, chain_need=4, chain_cost=1),
         (dict(bonus_amount=12), "Соседний враг: под ним трясина. Обычный тонет; тяжёлый — 12 урона и опутан.\nЦепь 4: стоит 1."),
         (dict(cast_range=3), "Враг до 3: под ним трясина. Обычный тонет; тяжёлый — 8 урона и опутан.\nЦепь 4: стоит 1."), rare=True),
]


def pair(a, b, rows):
    out = []
    for i, (hero, role, title, icon, text, f, up1, up2) in enumerate(rows):
        n = "m" if hero == "mage" else "k"
        idx = sum(1 for r in rows[:i] if r[0] == hero) + 1
        out.append(card(f"mix_{a}_{b}_{n}{idx}", hero, role, title, icon, text, f, up1, up2))
    return out


PAIRS = {
    (T, B): ("Чёрная вода", pair(T, B, [
        ("mage", "SETUP", "Зыбун", "maw", "Все лужи в 4 клетках от мага становятся топью, враги на них опутаны.",
         dict(cost=1, shape="SELF", cast_range=0, special="mire", bonus_amount=4),
         (dict(bonus_amount=5), "Все лужи в 5 клетках от мага становятся топью, враги на них опутаны."),
         (dict(cost=0), "Все лужи в 4 клетках от мага становятся топью, враги на них опутаны.")),
        ("mage", "FINISH", "Утянуть на дно", "drop", "Враг в топи или луже до 5: 5 урона +2 за звено; опутанному — вдвое.",
         dict(cost=2, shape="SINGLE", cast_range=5, damage=5, per_link_damage=2, special="drag_down"),
         (dict(damage=6), "Враг в топи или луже до 5: 6 урона +2 за звено; опутанному — вдвое."),
         (dict(chain_need=4, chain_cost=1), "Враг в топи или луже до 5: 5 урона +2 за звено; опутанному вдвое.\nЦепь 4: стоит 1.")),
        ("knight", "LINK", "Тянущее дно", "hammer", "Соседний враг: 3 урона; в луже или топи — ещё 3 и опутан.",
         dict(cost=1, shape="SINGLE", cast_range=1, damage=3, special="undertow", bonus_amount=3),
         (dict(bonus_amount=5), "Соседний враг: 3 урона; в луже или топи — ещё 5 и опутан."),
         (dict(cost=0), "Соседний враг: 3 урона; в луже или топи — ещё 3 и опутан.")),
        ("knight", "SETUP", "Илистая стена", "shield", "Блок 6, клетки вокруг рыцаря — лужи, враги в них опутаны.",
         dict(cost=1, shape="SELF", cast_range=0, block=6, special="silt_wall"),
         (dict(block=9), "Блок 9, клетки вокруг рыцаря — лужи, враги в них опутаны."),
         (dict(cost=0, block=3), "Блок 3, клетки вокруг рыцаря — лужи, враги в них опутаны.")),
    ])),
    (T, W): ("Шторм", pair(T, W, [
        ("mage", "SETUP", "Ливень", "flood", "Линия 6: толчок 2, вся линия — лужи, задетые мокнут.",
         dict(cost=1, shape="LINE", cast_range=6, push=2, element="WATER"),
         (dict(push=3), "Линия 6: толчок 3, вся линия — лужи, задетые мокнут."),
         (dict(chain_need=2, chain_cost=0), "Линия 6: толчок 2, вся линия — лужи.\nЦепь 2: стоит 0.")),
        ("mage", "FINISH", "Водяной смерч", "whirl", "Клетка до 5: враги в 2 клетках стягиваются на 1 и мокнут, вокруг — лужи; 2 урона +1 за звено.",
         dict(cost=2, shape="SINGLE", cast_range=5, special="water_vortex", bonus_amount=2, per_link_damage=1),
         (dict(bonus_amount=3), "Клетка до 5: враги в 2 клетках стягиваются и мокнут, вокруг лужи; 3 урона +1 за звено."),
         (dict(chain_need=3, chain_cost=1), "Клетка до 5: враги стягиваются и мокнут, лужи; 2 урона +1 за звено.\nЦепь 3: стоит 1.")),
        ("knight", "FINISH", "Пенный вал", "ram", "Таран до 5, позади лужи. Врезавшись: 3 урона +1 за звено, толчок 2, цель мокнет.",
         dict(cost=2, shape="CHARGE", cast_range=5, damage=3, per_link_damage=1, push=2, special="tide_trail"),
         (dict(damage=4), "Таран до 5, позади лужи. Врезавшись: 4 урона +1 за звено, толчок 2, мокнет."),
         (dict(cast_range=7), "Таран до 7, позади лужи. Врезавшись: 3 урона +1 за звено, толчок 2, мокнет.")),
        ("knight", "LINK", "Брызги в лицо", "drop", "Враг до 3: 1 урон, мокнет, толчок 1.\nЦепь 2: толчок 2.",
         dict(cost=0, shape="SINGLE", cast_range=3, damage=1, push=1, element="WATER", chain_need=2, chain_push=1),
         (dict(damage=2), "Враг до 3: 2 урона, мокнет, толчок 1.\nЦепь 2: толчок 2."),
         (dict(cast_range=5), "Враг до 5: 1 урон, мокнет, толчок 1.\nЦепь 2: толчок 2.")),
    ])),
    (S, B): ("Болотные огни", pair(S, B, [
        ("mage", "LINK", "Блуждающий огонёк", "spark", "3 урона молнией до 5; молния бежит по воде и топи вокруг цели (мокрым +3).",
         dict(cost=1, shape="SINGLE", cast_range=5, damage=3, element="LIGHTNING"),
         (dict(damage=4), "4 урона молнией до 5; молния бежит по воде и топи вокруг цели."),
         (dict(chain_need=2, chain_cost=0), "3 урона молнией до 5 по воде и топи.\nЦепь 2: стоит 0.")),
        ("mage", "SETUP", "Гнилая гроза", "entangled", "Враг до 5 опутан; до конца хода молния по опутанным — вдвое.",
         dict(cost=1, shape="SINGLE", cast_range=5, special="rot_storm"),
         (dict(cost=0), "Враг до 5 опутан; до конца хода молния по опутанным — вдвое."),
         (dict(cast_range=7), "Враг до 7 опутан; до конца хода молния по опутанным — вдвое.")),
        ("knight", "FINISH", "Громовая трясина", "bolt", "6 клеток вокруг: 3 урона молнией +1 за звено, потом они становятся топью.",
         dict(cost=2, shape="AROUND", cast_range=0, damage=3, per_link_damage=1, element="LIGHTNING", special="stomp"),
         (dict(damage=4), "6 клеток вокруг: 4 урона молнией +1 за звено, потом топь."),
         (dict(block=4), "6 клеток вокруг: 3 молнией +1 за звено, потом топь. Блок 4.")),
        ("knight", "LINK", "Разряд по корням", "bolt", "Враг до 3: 2 урона молнией; опутанному или в топи — ещё 2.",
         dict(cost=0, shape="SINGLE", cast_range=3, damage=2, element="LIGHTNING", special="root_shock", bonus_amount=2),
         (dict(damage=3, bonus_amount=3), "Враг до 3: 3 урона молнией; опутанному или в топи — ещё 3."),
         (dict(), "Враг до 3: 2 урона молнией (+2 опутанному или в топи), потом он опутан.")),
    ])),
    (S, W): ("Буревестник", pair(S, W, [
        ("mage", "FINISH", "Шаровая молния", "orb", "Линия 6: 3 урона молнией каждому +1 за звено (мокрым +3).",
         dict(cost=2, shape="LINE", cast_range=6, damage=3, per_link_damage=1, element="LIGHTNING"),
         (dict(damage=4), "Линия 6: 4 урона молнией каждому +1 за звено (мокрым +3)."),
         (dict(push=1), "Линия 6: 3 урона молнией +1 за звено, толчок 1.")),
        ("mage", "SETUP", "Грозовой фронт", "wind", "Линия 5: толчок 1, +2 заряда за каждого задетого.",
         dict(cost=1, shape="LINE", cast_range=5, push=1, special="front"),
         (dict(push=2), "Линия 5: толчок 2, +2 заряда за каждого задетого."),
         (dict(cost=0), "Линия 5: толчок 1, +2 заряда за каждого задетого.")),
        ("knight", "MOVE", "Гром в спину", "dash", "+2 шага; следующий удар рыцаря в этот ход — молния.",
         dict(cost=0, shape="SELF", cast_range=0, bonus_moves=2, special="next_lightning"),
         (dict(bonus_moves=3), "+3 шага; следующий удар рыцаря в этот ход — молния."),
         (dict(momentum_gain=2), "+2 шага, +2 натиска; следующий удар — молния.")),
        ("knight", "FINISH", "Громовой рывок", "ram", "Бег по прямой до 5 насквозь: каждому на пути 4 урона молнией и отлёт вбок.",
         dict(cost=2, shape="CHARGE", cast_range=5, damage=4, element="LIGHTNING", special="pass_through"),
         (dict(damage=5), "Бег по прямой до 5 насквозь: каждому 5 урона молнией и отлёт вбок."),
         (dict(cast_range=7), "Бег по прямой до 7 насквозь: каждому 4 урона молнией и отлёт вбок.")),
    ])),
    (B, W): ("Болотный туман", pair(B, W, [
        ("mage", "LINK", "Затянуть в топь", "wind", "Враг до 5: толчок 2 от мага; остановился в топи или луже — опутан.",
         dict(cost=1, shape="SINGLE", cast_range=5, push=2, special="mire_push"),
         (dict(cost=0), "Враг до 5: толчок 2 от мага; остановился в топи или луже — опутан."),
         (dict(push=3), "Враг до 5: толчок 3 от мага; остановился в топи или луже — опутан.")),
        ("mage", "FINISH", "Гнилой ветер", "poison", "Газ в 5 клетках растекается на соседние; враги в газе: 2 урона +1 за звено и яд.",
         dict(cost=2, shape="SELF", cast_range=0, special="rot_wind", bonus_amount=2, per_link_damage=1),
         (dict(bonus_amount=3), "Газ в 5 клетках растекается; враги в газе: 3 урона +1 за звено и яд."),
         (dict(chain_need=3, chain_cost=1), "Газ растекается; враги в газе: 2 урона +1 за звено и яд.\nЦепь 3: стоит 1.")),
        ("knight", "FINISH", "Удар в трясину", "hammer", "Соседний враг: 5 урона +1 за звено, толчок 4 (в трясине тонет, в топи опутан).",
         dict(cost=2, shape="SINGLE", cast_range=1, damage=5, per_link_damage=1, push=4, special="mire_push"),
         (dict(push=6), "Соседний враг: 5 урона +1 за звено, толчок 6 (в трясине тонет, в топи опутан)."),
         (dict(damage=6, per_link_damage=2), "Соседний враг: 6 урона +2 за звено, толчок 4 (тонет или опутан).")),
        ("knight", "SETUP", "Болотный вихрь", "whirl", "6 клеток вокруг: враги отлетают на 1, клетки становятся топью.",
         dict(cost=1, shape="AROUND", cast_range=0, push=1, special="stomp"),
         (dict(block=4), "6 клеток вокруг: враги отлетают на 1, клетки — топь. Блок 4."),
         (dict(cost=0), "6 клеток вокруг: враги отлетают на 1, клетки становятся топью.")),
    ])),
}


if __name__ == "__main__":
    wm = write_set(WIND_M, "resources/cards/spirits/wind", [W], "s_wind")
    wk = write_set(WIND_K, "resources/cards/spirits/wind", [W], "s_wind")
    bm = write_set(BOG_M, "resources/cards/spirits/bog", [B], "s_bog")
    bk = write_set(BOG_K, "resources/cards/spirits/bog", [B], "s_bog")
    mixed = {T: [], S: [], B: [], W: []}
    for (a, b), (_name, cards) in PAIRS.items():
        mixed[a] += write_set(cards, "resources/cards/mixed", [a, b], f"x_{a}_{b}")
    call_wind = card("wind_call", "", "", "Зов: Порыв", "wind", "Зов духа (раз в бой): все враги в 2 клетках отлетают на 2.",
                     dict(cost=0, shape="SELF", cast_range=0, special="storm_push", bonus_amount=2, is_call=True, chain_add=-1, scrap_moves=0), None, None, cset="s_wind")
    call_bog = card("bog_call", "", "", "Зов: Зыбь", "maw", "Зов духа (раз в бой): клетка до 3 на 2 раунда становится трясиной.",
                    dict(cost=0, shape="SINGLE", cast_range=3, special="sink", bonus_amount=0, is_call=True, chain_add=-1, scrap_moves=0), None, None, cset="s_bog")
    write_enemy("resources/enemies/spirit_wind.tres", "wind", "Вихорь", "Выл в пустых залах ордена. Теперь воет над топью.",
                22, "0.7, 0.82, 0.74, 1",
                [dict(title="Порыв", shape=1, attack_range=4, damage=3, push=2),
                 dict(title="Круговерть", shape=4, damage=3, push=1)])
    # Хозяин трясины в логове не встречается — его получают в элите с корягачом; враг нужен только для данных
    write_enemy("resources/enemies/spirit_bog.tres", "bog", "Хозяин трясины", "Топь была его домом задолго до людей. Он не рад гостям.",
                30, "0.25, 0.4, 0.3, 1",
                [dict(title="Хватка корней", shape=0, damage=4, entangle=1)])
    write_spirit("wind", "Вихорь", "Выл в пустых залах ордена. Теперь воет над топью.",
                 "+1 шаг каждый ход.", "0.72, 0.85, 0.76, 1", "wind",
                 call_wind, wm, wk, mixed[W], "res://resources/enemies/spirit_wind.tres")
    write_spirit("bog", "Хозяин трясины", "Топь была его домом задолго до людей. Он не рад гостям.",
                 "топь не отнимает шагов у героя, опутывание на него не действует.", "0.3, 0.48, 0.34, 1", "maw",
                 call_bog, bm, bk, mixed[B], "res://resources/enemies/spirit_bog.tres")
    # смешанные карты лежат у первого духа пары: Омутника и Грозовика пересобираем с новыми парами
    from gen_spirit_cards import build  # noqa: E402
    build({"tide": mixed[T], "storm": mixed[S]})
    print("этап 4: карт", len(wm) + len(wk) + len(bm) + len(bk) + sum(len(v) for v in mixed.values()))

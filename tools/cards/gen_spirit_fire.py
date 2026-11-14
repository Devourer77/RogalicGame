# Генератор духа огня (claude/тз-дух-огня.md): Жаровик — 6 карт Магу, 6 Рыцарю, Зов,
# враг для Тлеющей пещеры и 12 смешанных карт пар «Пал» (огонь + ветер), «Пар» (огонь + вода),
# «Лава» (огонь + топь). Других духов не трогает.
# Запуск из папки проекта: python tools/cards/gen_spirit_fire.py
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from gen_base_cards import gd  # noqa: E402
from gen_spirit_cards import card, write_card, write_set  # noqa: E402

F, W, T, B = "fire", "wind", "tide", "bog"

FIRE_M = [
    card("fire_m1", "mage", "SETUP", "Поджог", "fire", "Клетка до 5 загорается: бочка взрывается, камыш, дерево и торф горят.",
         dict(cost=0, shape="SINGLE", cast_range=5, element="FIRE"),
         (dict(cast_range=7), "Клетка до 7 загорается: бочка взрывается, камыш, дерево и торф горят."),
         (dict(special="ignite_burst", chain_need=2), "Клетка до 5 загорается.\nЦепь 2: горит весь круг 1.")),
    card("fire_m2", "mage", "LINK", "Искра жара", "spark", "2 урона огнём до 4, клетка цели загорается.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=4, damage=2, element="FIRE", chain_need=2, chain_damage=2),
         (dict(damage=3), "3 урона огнём до 4, клетка цели загорается.\nЦепь 2: +2."),
         (dict(special="fire_jump"), "2 урона огнём до 4, поджог. Перескок на соседнего врага в огне.\nЦепь 2: +2.")),
    card("fire_m3", "mage", "FINISH", "Огненный шар", "fire", "Круг 1 до 5: 4 урона +1 за звено Цепи, всё загорается.",
         dict(cost=2, shape="CROSS", cast_range=5, damage=4, per_link_damage=1, element="FIRE"),
         (dict(damage=5), "Круг 1 до 5: 5 урона +1 за звено, всё загорается."),
         (dict(chain_need=3, chain_cost=1), "Круг 1 до 5: 4 урона +1 за звено, поджог.\nЦепь 3: стоит 1.")),
    card("fire_m4", "mage", "MOVE", "Тяга", "dash", "Маг переносится на горящую клетку до 5. +1 шаг.",
         dict(cost=0, shape="SINGLE", cast_range=5, special="fire_step", bonus_moves=1),
         (dict(cast_range=7), "Маг переносится на горящую клетку до 7. +1 шаг."),
         (dict(bonus_amount=1), "Маг переносится на горящую клетку до 5, откуда ушёл — загорается. +1 шаг.")),
    card("fire_m5", "mage", "SETUP", "Жаровая завеса", "fire", "Стена из 3 клеток огня до 4.",
         dict(cost=1, shape="WALL", cast_range=4, element="FIRE"),
         (dict(cost=0), "Стена из 3 клеток огня до 4."),
         (dict(block=4), "Стена из 3 клеток огня до 4. Блок 4 магу.")),
    card("fire_m6", "mage", "FINISH", "Метеор", "meteor", "Круг 1 до 6: 8 урона, поджог; бочки в 2 клетках взрываются.\nЦепь 4: стоит 2.",
         dict(cost=3, shape="CROSS", cast_range=6, damage=8, element="FIRE", special="meteor", chain_need=4, chain_cost=2),
         (dict(cost=2, chain_need=0, chain_cost=-1), "Круг 1 до 6: 8 урона, поджог; бочки в 2 клетках взрываются."),
         (dict(special="meteor2", damage=5), "Круг 2 до 6: 5 урона, поджог; бочки в 2 клетках взрываются.\nЦепь 4: стоит 2."), rare=True),
]
FIRE_K = [
    card("fire_k1", "knight", "SETUP", "Руна огня", "fire", "Руна на 3 удара: под каждым задетым врагом загорается клетка.",
         dict(cost=1, shape="SELF", cast_range=0, special="rune_fire"),
         (dict(cost=0), "Руна на 3 удара: под каждым задетым врагом загорается клетка."),
         (dict(rune_charges=5), "Руна на 5 ударов: под каждым задетым врагом загорается клетка.")),
    card("fire_k2", "knight", "LINK", "Раскалённый клинок", "sword", "3 урона вплотную; по врагу в огне ещё +3.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=1, damage=3, special="hot_blade", bonus_amount=3, chain_need=2, chain_damage=2),
         (dict(damage=4), "4 урона вплотную; по врагу в огне ещё +3.\nЦепь 2: +2."),
         (dict(element="FIRE"), "3 урона вплотную (в огне +3), клетка цели загорается.\nЦепь 2: +2.")),
    card("fire_k3", "knight", "FINISH", "Огненный таран", "ram", "Таран до 4, путь горит. Врезавшись: 5 урона +1 за звено Цепи, под целью огонь.",
         dict(cost=2, shape="CHARGE", cast_range=4, damage=5, per_link_damage=1, special="fire_trail"),
         (dict(cast_range=6), "Таран до 6, путь горит. Врезавшись: 5 урона +1 за звено, под целью огонь."),
         (dict(special="fire_pass", damage=4), "Сквозной таран до 4: каждому 4 урона +1 за звено, отлёт вбок, путь горит.")),
    card("fire_k4", "knight", "MOVE", "Сквозь пламя", "dash", "+3 шага; +1 натиск за каждую горящую клетку в 2 клетках (до 3).",
         dict(cost=0, shape="SELF", cast_range=0, bonus_moves=3, special="flame_count"),
         (dict(bonus_moves=4), "+4 шага; +1 натиск за каждую горящую клетку в 2 клетках (до 3)."),
         (dict(momentum_gain=2), "+3 шага, +2 натиска; ещё +1 за каждую горящую клетку рядом (до 3).")),
    card("fire_k5", "knight", "SETUP", "Щит углей", "shield", "Блок 6; до следующего хода под врагом, подошедшим вплотную, загорается клетка.",
         dict(cost=1, shape="SELF", cast_range=0, block=6, special="ember_guard"),
         (dict(block=9), "Блок 9; до следующего хода под врагом, подошедшим вплотную, загорается клетка."),
         (dict(), "Блок 6; до следующего хода под врагом, подошедшим вплотную к любому герою, огонь.")),
    card("fire_k6", "knight", "FINISH", "Пламенный вихрь", "whirl", "6 клеток вокруг: 5 урона огнём, клетки горят, +1 ярость за задетого.\nЦепь 4: стоит 1.",
         dict(cost=2, shape="AROUND", cast_range=0, damage=5, element="FIRE", special="whirl_rage", chain_need=4, chain_cost=1),
         (dict(damage=6), "6 клеток вокруг: 6 урона огнём, клетки горят, +1 ярость за задетого.\nЦепь 4: стоит 1."),
         (dict(special="whirl_rage2"), "Круг 2 вокруг: 5 урона огнём, клетки горят, +1 ярость за задетого.\nЦепь 4: стоит 1."), rare=True),
]


def pair(a, b, rows):
    return [card(f"mix_{a}_{b}_{'m' if h == 'mage' else 'k'}{i}", h, role, title, icon, text, f, up1, up2)
            for (h, role, title, icon, text, f, up1, up2), i in zip(rows, (1, 2, 1, 2))]


PAIRS = {
    (F, W): pair(F, W, [
        ("mage", "SETUP", "Раздуть пламя", "wind", "Выбери сторону: каждая горящая клетка в 4 клетках поджигает соседнюю в эту сторону.",
         dict(cost=1, shape="SINGLE", cast_range=1, special="fan_all", bonus_amount=4),
         (dict(bonus_amount=6), "Выбери сторону: каждая горящая клетка в 6 клетках поджигает соседнюю в эту сторону."),
         (dict(chain_need=2, chain_cost=0), "Каждая горящая клетка в 4 клетках поджигает соседнюю в выбранную сторону.\nЦепь 2: стоит 0.")),
        ("mage", "FINISH", "Огненный смерч", "whirl", "Клетка до 5: враги в 2 клетках стягиваются к ней на 1, 2 урона +1 за звено; круг 1 загорается.",
         dict(cost=2, shape="SINGLE", cast_range=5, special="fire_vortex", bonus_amount=2, per_link_damage=1),
         (dict(bonus_amount=3), "Клетка до 5: враги в 2 клетках стягиваются на 1, 3 урона +1 за звено; круг 1 горит."),
         (dict(), "Клетка до 5: враги в 2 клетках стягиваются на 2, 2 урона +1 за звено; круг 1 горит.")),
        ("knight", "LINK", "Горящий порыв", "slash", "Линия 3: 2 урона, толчок 1, клетки загораются.",
         dict(cost=0, shape="LINE", cast_range=3, damage=2, push=1, element="FIRE"),
         (dict(damage=3), "Линия 3: 3 урона, толчок 1, клетки загораются."),
         (dict(push=2), "Линия 3: 2 урона, толчок 2, клетки загораются.")),
        ("knight", "FINISH", "Огненный вал", "ram", "Сквозной таран до 5: каждому 3 урона +1 за звено и отлёт вбок, путь горит.",
         dict(cost=2, shape="CHARGE", cast_range=5, damage=3, per_link_damage=1, special="fire_pass"),
         (dict(damage=4), "Сквозной таран до 5: каждому 4 урона +1 за звено и отлёт вбок, путь горит."),
         (dict(cast_range=7), "Сквозной таран до 7: каждому 3 урона +1 за звено и отлёт вбок, путь горит.")),
    ]),
    (F, T): pair(F, T, [
        ("mage", "FINISH", "Паровой котёл", "wave", "Все лужи в 4 клетках вскипают: стоящим в них 3 урона +1 за звено, отброс 1. Лужи исчезают.",
         dict(cost=2, shape="SELF", cast_range=0, special="steam_boil", bonus_amount=3, per_link_damage=1),
         (dict(bonus_amount=4), "Все лужи в 4 клетках вскипают: 4 урона +1 за звено, отброс 1. Лужи исчезают."),
         (dict(chain_need=3, chain_cost=1), "Лужи в 4 клетках вскипают: 3 урона +1 за звено, отброс 1.\nЦепь 3: стоит 1.")),
        ("mage", "LINK", "Кипяток", "drop", "Мокрый враг или враг в луже до 5: 3 урона паром, отброс 1.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=5, damage=3, push=1, special="scald", chain_need=2, chain_damage=2),
         (dict(damage=4), "Мокрый враг или враг в луже до 5: 4 урона паром, отброс 1.\nЦепь 2: +2."),
         (dict(cast_range=7), "Мокрый враг или враг в луже до 7: 3 урона паром, отброс 1.\nЦепь 2: +2.")),
        ("knight", "SETUP", "Закалка в пару", "shield", "Блок 6; если рыцарь в луже — следующая карта с уроном в этот ход +4.",
         dict(cost=1, shape="SELF", cast_range=0, block=6, special="temper", bonus_amount=4),
         (dict(block=9), "Блок 9; если рыцарь в луже — следующая карта с уроном в этот ход +4."),
         (dict(), "Под рыцарем появляется лужа. Блок 6, следующая карта с уроном в этот ход +4.")),
        ("knight", "LINK", "Паровой удар", "sword", "3 урона вплотную; если цель мокрая — паровой взрыв: 3 урона врагам вокруг неё.",
         dict(cost=0, shape="SINGLE", cast_range=1, damage=3, special="steam_strike"),
         (dict(damage=4), "4 урона вплотную; если цель мокрая — паровой взрыв: 3 урона врагам вокруг."),
         (dict(cast_range=2), "3 урона до 2; если цель мокрая — паровой взрыв: 3 урона врагам вокруг.")),
    ]),
    (F, B): pair(F, B, [
        ("mage", "SETUP", "Разбудить недра", "maw", "Круг 1 до 5: топь и трясина становятся лавой на 2 раунда.",
         dict(cost=1, shape="CROSS", cast_range=5, special="lava_wake", bonus_amount=2),
         (dict(cast_range=7), "Круг 1 до 7: топь и трясина становятся лавой на 2 раунда."),
         (dict(bonus_amount=3), "Круг 1 до 5: топь и трясина становятся лавой на 3 раунда.")),
        ("mage", "FINISH", "Лавовый поток", "fire", "Линия 5: 4 урона +1 за звено; топь и трясина на линии — лава на 2 раунда.",
         dict(cost=2, shape="LINE", cast_range=5, damage=4, per_link_damage=1, special="lava_line", bonus_amount=2),
         (dict(damage=5), "Линия 5: 5 урона +1 за звено; топь и трясина на линии — лава на 2 раунда."),
         (dict(chain_need=3, chain_cost=1), "Линия 5: 4 урона +1 за звено; топь и трясина — лава.\nЦепь 3: стоит 1.")),
        ("knight", "FINISH", "Вдавить в лаву", "hammer", "Соседний враг: 2 урона, толчок 3. Упёрся в лаву или стоит в огне — ещё 6 +2 за звено.",
         dict(cost=2, shape="SINGLE", cast_range=1, damage=2, push=3, special="lava_shove", bonus_amount=6),
         (dict(push=4), "Соседний враг: 2 урона, толчок 4. Упёрся в лаву или стоит в огне — ещё 6 +2 за звено."),
         (dict(cost=1), "Соседний враг: 2 урона, толчок 3. Упёрся в лаву или в огне — ещё 6 +2 за звено.")),
        ("knight", "SETUP", "Горячая трясина", "whirl", "6 клеток вокруг загораются; трясина рядом становится лавой.",
         dict(cost=1, shape="AROUND", cast_range=0, element="FIRE"),
         (dict(block=4), "6 клеток вокруг загораются; трясина рядом становится лавой. Блок 4."),
         (dict(cost=0), "6 клеток вокруг загораются; трясина рядом становится лавой.")),
    ]),
}


def write_enemy_fire():
    lines = ['[gd_resource type="Resource" script_class="EnemyData" load_steps=6 format=3]', "",
             '[ext_resource type="Script" path="res://scripts/data/enemy_data.gd" id="1_enemy"]',
             '[ext_resource type="Script" path="res://scripts/data/enemy_attack_data.gd" id="2_attack"]',
             '[ext_resource type="PackedScene" path="res://assets/models/spirit_fire.glb" id="9_model"]', ""]
    attacks = [
        dict(title="Плевок жаром", shape=1, attack_range=4, damage=4, first_only=True, ignite=True),
        dict(title="Вспышка", anim="Attack2", shape=4, damage=5, push=1, ignite=True),
        dict(title="Раздуть угли", anim="Attack3", shape=3, attack_range=2, damage=0, ally_block=3, ally_damage=2, stoke=2),
    ]
    ids = []
    for i, a in enumerate(attacks):
        lines += [f'[sub_resource type="Resource" id="atk{i}"]', 'script = ExtResource("2_attack")']
        lines += [f"{k} = {gd(v)}" for k, v in a.items()]
        lines.append("")
        ids.append(f'SubResource("atk{i}")')
    lines += ["[resource]", 'script = ExtResource("1_enemy")', 'id = "spirit_fire"', 'title = "Жаровик"',
              'description = "Под топью горит тридцать лет. Наверх выходит только дым — и тот, кто его ищет."',
              "max_hp = 70", "move_range = 2", "damage = 4", "color = Color(1, 0.5, 0.15, 1)", "size = 1.15",
              "is_boss = true", "tamable = true", "turn_block = 4", "bog_damage = 8",
              "fire_walker = true", "water_weak = true",
              'cycle = Array[ExtResource("2_attack")]([' + ", ".join(ids) + "])",
              'model = ExtResource("9_model")']
    with open("resources/enemies/spirit_fire.tres", "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


def write_spirit_fire(call_path, mage, knight, mixed):
    refs = {}

    def ref(p):
        if p not in refs:
            refs[p] = f"c{len(refs) + 1}"
        return f'ExtResource("{refs[p]}")'
    body = ["[resource]", 'script = ExtResource("1_spirit")', 'id = "fire"', 'title = "Жаровик"',
            f'description = {gd("Под топью горит тридцать лет. Наверх выходит только дым — и тот, кто его ищет.")}',
            f'passive_text = {gd("огонь и лава не ранят героя.")}', "color = Color(1, 0.55, 0.2, 1)", 'icon = "fire"',
            "is_unique = true", f"call_card = {ref(call_path)}",
            'mage_cards = Array[ExtResource("2_card")]([' + ", ".join(ref(p) for p in mage) + "])",
            'knight_cards = Array[ExtResource("2_card")]([' + ", ".join(ref(p) for p in knight) + "])",
            'mixed_cards = Array[ExtResource("2_card")]([' + ", ".join(ref(p) for p in mixed) + "])",
            f'enemy = {ref("res://resources/enemies/spirit_fire.tres")}']
    head = [f'[gd_resource type="Resource" script_class="SpiritData" load_steps={len(refs) + 3} format=3]', "",
            '[ext_resource type="Script" path="res://scripts/data/spirit_data.gd" id="1_spirit"]',
            '[ext_resource type="Script" path="res://scripts/data/card_data.gd" id="2_card"]']
    head += [f'[ext_resource type="Resource" path="{p}" id="{i}"]' for p, i in refs.items()]
    with open("resources/spirits/fire.tres", "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(head + [""] + body) + "\n")


if __name__ == "__main__":
    fm = write_set(FIRE_M, "resources/cards/spirits/fire", [F], "s_fire")
    fk = write_set(FIRE_K, "resources/cards/spirits/fire", [F], "s_fire")
    mixed = []
    for (a, b), cards in PAIRS.items():
        mixed += write_set(cards, "resources/cards/mixed", [a, b], f"x_{a}_{b}")
    call = card("fire_call", "", "", "Зов: Вспышка", "fire", "Зов духа (раз в бой): круг 1 до 4 загорается (бочки там взрываются).",
                dict(cost=0, shape="CROSS", cast_range=4, element="FIRE", is_call=True, chain_add=-1, scrap_moves=0), None, None, cset="s_fire")
    call_path = write_card(call, "resources/cards/spirits/fire")
    write_enemy_fire()
    write_spirit_fire(call_path, fm, fk, mixed)
    print("дух огня: карт", len(fm) + len(fk) + len(mixed) + 1)

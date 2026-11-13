# Генератор духов этапа 3 (тз-карты.md 7.1, 7.2, 8; тз-духи.md): Омутник и Грозовик,
# по 6 карт каждому герою, Зов, враг для логова и 4 смешанные карты пары «Гроза над омутом».
# Запуск из папки проекта: python tools/cards/gen_spirit_cards.py
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from gen_base_cards import SHAPE, ROLE, DEFAULTS, gd  # noqa: E402

ELEM = dict(NONE=0, FIRE=1, WATER=2, ICE=3, LIGHTNING=4)
DEFAULTS = dict(DEFAULTS, element="NONE", chain_pull=0, rune_charges=0, bonus_amount=0, block_per_hit=3,
                chain_jumps=False, no_falloff=False, is_call=False, owner="")


def card(cid, hero, role, title, icon, text, f, up1, up2, rare=False, cset="", spirits=(), slot=0):
    return dict(id=cid, hero=hero, role=role, title=title, icon=icon, text=text, f=f, up1=up1, up2=up2,
                rare=rare, cset=cset, spirits=list(spirits), slot=slot)


def body(c, fields, text, level, ident, title):
    lines = ['script = ExtResource("1_card")']
    for k, v in dict(id=ident, icon=c["icon"], title=title, description=text).items():
        lines.append(f"{k} = {gd(v)}")
    merged = dict(fields)
    lines.append(f"shape = {SHAPE[merged.pop('shape')]}")
    el = merged.pop("element", "NONE")
    if el != "NONE":
        lines.append(f"element = {ELEM[el]}")
    for k, v in merged.items():
        if DEFAULTS.get(k) != v:
            lines.append(f"{k} = {gd(v)}")
    if c["rare"]:
        lines.append("is_rare = true")
    lines.append(f"card_set = {gd(c['cset'])}")
    if c["hero"]:
        lines.append(f"owner_hero = {gd(c['hero'])}")
    if c["role"]:
        lines.append(f"role = {ROLE[c['role']]}")
    if c["spirits"]:
        lines.append("spirit_ids = Array[String]([" + ", ".join(gd(s) for s in c["spirits"]) + "])")
    if c["slot"]:
        lines.append(f"spirit_slot = {c['slot']}")
    if level:
        lines.append(f"upgrade_level = {level}")
    return lines


def write_card(c, out_dir):
    parts = ['[gd_resource type="Resource" script_class="CardData" load_steps=4 format=3]', "",
             '[ext_resource type="Script" path="res://scripts/data/card_data.gd" id="1_card"]', ""]
    has_up = c["up1"] is not None
    if has_up:
        for n in (1, 2):
            over, text = c[f"up{n}"]
            fields = dict(c["f"])
            fields.update(over)
            parts.append(f'[sub_resource type="Resource" id="up{n}"]')
            parts += body(c, fields, text, n, f'{c["id"]}+{n}', c["title"] + "+" + ("I" if n == 1 else "II"))
            parts.append("")
    parts.append("[resource]")
    parts += body(c, c["f"], c["text"], 0, c["id"], c["title"])
    if has_up:
        parts += ['upgrade_1 = SubResource("up1")', 'upgrade_2 = SubResource("up2")']
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, c["id"] + ".tres"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(parts) + "\n")
    return f"res://{out_dir}/{c['id']}.tres"


T, S = "tide", "storm"
TIDE_M = [
    card("tide_m1", "mage", "SETUP", "Разлив", "flood", "Круг 1 до 4: лужи, все там мокнут. Старая лужа становится топью.",
         dict(cost=1, shape="CROSS", cast_range=4, special="flood_swamp"),
         (dict(cast_range=6), "Круг 1 до 6: лужи, все там мокнут. Старая лужа становится топью."),
         (dict(chain_need=2, chain_cost=0), "Круг 1 до 4: лужи, все мокнут. Старая лужа — топь.\nЦепь 2: стоит 0.")),
    card("tide_m2", "mage", "LINK", "Водяная плеть", "drop", "3 урона до 3, цель мокнет.\nЦепь 2: притягивает на 1.",
         dict(cost=0, shape="SINGLE", cast_range=3, damage=3, element="WATER", chain_need=2, chain_pull=1),
         (dict(damage=4, cast_range=4), "4 урона до 4, цель мокнет.\nЦепь 2: притягивает на 1."),
         (dict(chain_pull=0, chain_push=2), "3 урона до 3, цель мокнет.\nЦепь 2: толчок 2.")),
    card("tide_m3", "mage", "FINISH", "Волна", "wave", "Все враги в лужах в 5 клетках: 2 урона +1 за звено Цепи, толчок 1 от мага.",
         dict(cost=2, shape="SELF", cast_range=0, special="wave_wet", bonus_amount=2, per_link_damage=1, block_per_hit=2),
         (dict(bonus_amount=3), "Все враги в лужах в 5 клетках: 3 урона +1 за звено, толчок 1 от мага."),
         (dict(), "Все враги в лужах в 5 клетках: 2 урона +1 за звено, толчок 1. Блок 2 за каждого.")),
    card("tide_m4", "mage", "MOVE", "Течение", "tide", "+1 шаг за каждую лужу в 2 клетках (до 3).",
         dict(cost=0, shape="SELF", cast_range=0, special="flow_steps"),
         (dict(bonus_moves=1), "+1 шаг, и ещё +1 за каждую лужу в 2 клетках (до 3)."),
         (dict(bonus_amount=1), "+1 шаг за каждую лужу в 2 клетках (до 3) — обоим героям.")),
    card("tide_m5", "mage", "SETUP", "Пузырь", "shield", "Блок 5 магу или союзнику до 4; если цель в луже — ещё 4.",
         dict(cost=1, shape="ALLY", cast_range=4, block=5, special="bubble", bonus_amount=4),
         (dict(cost=0), "Блок 5 магу или союзнику до 4; если цель в луже — ещё 4."),
         (dict(), "Блок 5 магу или союзнику до 4 (в луже ещё 4). Снимает яд и огонь.")),
    card("tide_m6", "mage", "FINISH", "Водоворот", "flood", "Клетка до 5: враги в 2 клетках тянутся к ней на 2 и мокнут. Центр — трясина на 2 раунда.",
         dict(cost=2, shape="SINGLE", cast_range=5, special="whirlpool"),
         (dict(bonus_amount=3), "Клетка до 5: враги в 2 клетках — 3 урона, тянутся к ней на 2 и мокнут. Центр — трясина."),
         (dict(chain_need=3, chain_cost=1), "Клетка до 5: враги в 2 клетках тянутся к ней на 2 и мокнут. Центр — трясина.\nЦепь 3: стоит 1."), rare=True),
]
TIDE_K = [
    card("tide_k1", "knight", "SETUP", "Клинок омута", "drop", "Руна воды на 3 удара: задетые мокнут и отлетают на 1.",
         dict(cost=1, shape="SELF", cast_range=0, special="rune_tide"),
         (dict(rune_charges=4), "Руна воды на 4 удара: задетые мокнут и отлетают на 1."),
         (dict(cost=0), "Руна воды на 3 удара: задетые мокнут и отлетают на 1.")),
    card("tide_k2", "knight", "LINK", "Брызги", "slash", "Дуга: 2 урона, клетки дуги становятся лужами.\nЦепь 2: +2.",
         dict(cost=0, shape="ARC", cast_range=1, damage=2, element="WATER", chain_need=2, chain_damage=2),
         (dict(damage=3), "Дуга: 3 урона, клетки дуги становятся лужами.\nЦепь 2: +2."),
         (dict(special="block_per_enemy", block_per_hit=2), "Дуга: 2 урона, лужи. Блок 2 за каждого задетого.\nЦепь 2: +2.")),
    card("tide_k3", "knight", "FINISH", "Удар прилива", "ram", "Таран до 4, позади лужи. Врезавшись: 5 урона +1 за звено Цепи, цель мокнет.",
         dict(cost=2, shape="CHARGE", cast_range=4, damage=5, per_link_damage=1, special="tide_trail"),
         (dict(cast_range=6), "Таран до 6, позади лужи. Врезавшись: 5 урона +1 за звено, цель мокнет."),
         (dict(special="pass_through", damage=4), "Сквозной таран до 4: каждому 4 урона +1 за звено и отлёт вбок.")),
    card("tide_k4", "knight", "SETUP", "Стоять в воде", "shield", "Блок 6; если рыцарь в луже — ещё 6 и провокация.",
         dict(cost=1, shape="SELF", cast_range=0, block=6, special="stand_water", bonus_amount=6),
         (dict(block=8, bonus_amount=8), "Блок 8; если рыцарь в луже — ещё 8 и провокация."),
         (dict(), "Под рыцарем появляется лужа. Блок 6, ещё 6 и провокация.")),
    card("tide_k5", "knight", "LINK", "Тянущая вода", "chain", "Враг до 4 притягивается к рыцарю на 3 и мокнет.\nЦепь 2: ещё 4 урона.",
         dict(cost=1, shape="SINGLE", cast_range=4, pull=3, element="WATER", chain_need=2, chain_damage=4),
         (dict(cost=0), "Враг до 4 притягивается к рыцарю на 3 и мокнет.\nЦепь 2: ещё 4 урона."),
         (dict(cast_range=6), "Враг до 6 притягивается к рыцарю на 3 и мокнет.\nЦепь 2: ещё 4 урона.")),
    card("tide_k6", "knight", "FINISH", "Девятый вал", "wave", "Все враги в 2 клетках: 4 урона, толчок 2, мокнут.\nЦепь 4: толчок 3.",
         dict(cost=2, shape="SELF", cast_range=0, special="ninth_wave", bonus_amount=4, push=2, chain_need=4, chain_push=1),
         (dict(bonus_amount=6), "Все враги в 2 клетках: 6 урона, толчок 2, мокнут.\nЦепь 4: толчок 3."),
         (dict(), "Все в 2 клетках: 4 урона, толчок 2, мокнут, под ними лужи.\nЦепь 4: толчок 3."), rare=True),
]
STORM_M = [
    card("storm_m1", "mage", "SETUP", "Грозовой заряд", "bolt", "+2 заряда; следующая карта молнии в этот ход +2 урона.",
         dict(cost=0, shape="SELF", cast_range=0, charge_gain=2, special="storm_prime"),
         (dict(charge_gain=3), "+3 заряда; следующая карта молнии в этот ход +2 урона."),
         (dict(draw=1), "+2 заряда, добор 1; следующая карта молнии +2 урона.")),
    card("storm_m2", "mage", "LINK", "Искра молнии", "spark", "2 урона молнией до 5 (мокрым +3), +1 заряд.",
         dict(cost=0, shape="SINGLE", cast_range=5, damage=2, element="LIGHTNING", charge_gain=1),
         (dict(damage=3, cast_range=6), "3 урона молнией до 6 (мокрым +3), +1 заряд."),
         (dict(special="chain"), "2 урона молнией до 5, перескок на соседних врагов. +1 заряд.")),
    card("storm_m3", "mage", "FINISH", "Цепная молния", "chain", "5 урона до 5, перескок на ближайших в 2 клетках: 2 прыжка +1 за каждые 2 звена Цепи, каждый −1. Мокрым +3.",
         dict(cost=2, shape="SINGLE", cast_range=5, damage=5, element="LIGHTNING", special="chain", chain_jumps=True),
         (dict(no_falloff=True), "5 урона до 5, перескок: 2 прыжка +1 за каждые 2 звена, без ослабления. Мокрым +3."),
         (dict(charge_bonus=1), "5 урона +1 за заряд каждой цели, перескок: 2 прыжка +1 за 2 звена. Тратит заряд.")),
    card("storm_m4", "mage", "MOVE", "Шаг молнии", "bolt", "Линия 4: 3 урона молнией каждому, маг встаёт в конец линии.",
         dict(cost=1, shape="LINE", cast_range=4, damage=3, element="LIGHTNING", special="bolt_step"),
         (dict(cost=0), "Линия 4: 3 урона молнией каждому, маг встаёт в конец линии."),
         (dict(cast_range=6), "Линия 6: 3 урона молнией каждому, маг встаёт в конец линии.")),
    card("storm_m5", "mage", "LINK", "Разряд в воду", "bolt", "Лужа или топь до 6: молния по всей воде, 3 урона каждому в ней (мокрым +3).",
         dict(cost=1, shape="SINGLE", cast_range=6, damage=3, element="LIGHTNING", special="water_target"),
         (dict(damage=4), "Лужа или топь до 6: молния по всей воде, 4 урона каждому (мокрым +3)."),
         (dict(chain_need=2, chain_cost=0), "Лужа или топь до 6: молния по всей воде, 3 урона.\nЦепь 2: стоит 0.")),
    card("storm_m6", "mage", "FINISH", "Разлом неба", "rift", "Линия 6: 6 урона +3 за заряд, сквозь блок. Тратит заряд.\nЦепь 4: стоит 2.",
         dict(cost=3, shape="LINE", cast_range=6, damage=6, charge_bonus=3, pierce_block=True, chain_need=4, chain_cost=2),
         (dict(cost=2), "Линия 6: 6 урона +3 за заряд, сквозь блок. Тратит заряд."),
         (dict(element="LIGHTNING"), "Линия 6 молнией: 6 урона +3 за заряд, сквозь блок, лужи бьются целиком.\nЦепь 4: стоит 2."), rare=True),
]
STORM_K = [
    card("storm_k1", "knight", "SETUP", "Руна бури", "rune_storm", "Руна на 3 удара: удары рыцаря — молния (мокрым +3).",
         dict(cost=1, shape="SELF", cast_range=0, special="rune_storm"),
         (dict(cost=0), "Руна на 3 удара: удары рыцаря — молния (мокрым +3)."),
         (dict(rune_charges=5), "Руна на 5 ударов: удары рыцаря — молния (мокрым +3).")),
    card("storm_k2", "knight", "LINK", "Громовой удар", "bolt", "3 урона молнией вплотную.\nЦепь 2: +2.",
         dict(cost=0, shape="SINGLE", cast_range=1, damage=3, element="LIGHTNING", chain_need=2, chain_damage=2),
         (dict(damage=4), "4 урона молнией вплотную.\nЦепь 2: +2."),
         (dict(special="chain"), "3 урона молнией вплотную, перескок на соседних.\nЦепь 2: +2.")),
    card("storm_k3", "knight", "FINISH", "Гром и сталь", "whirl", "6 клеток вокруг: 3 урона молнией +1 за звено Цепи (мокрым +3).",
         dict(cost=2, shape="AROUND", cast_range=0, damage=3, per_link_damage=1, element="LIGHTNING"),
         (dict(damage=4), "6 клеток вокруг: 4 урона молнией +1 за звено (мокрым +3)."),
         (dict(bonus_moves=2, momentum_gain=2), "6 клеток вокруг: 3 молнией +1 за звено. Потом +2 шага и +2 натиска.")),
    card("storm_k4", "knight", "MOVE", "Буревой разбег", "dash", "+3 шага; следующий удар рыцаря в этот ход — молния.",
         dict(cost=0, shape="SELF", cast_range=0, bonus_moves=3, special="next_lightning"),
         (dict(bonus_moves=4), "+4 шага; следующий удар рыцаря в этот ход — молния."),
         (dict(momentum_gain=2), "+3 шага, +2 натиска; следующий удар — молния.")),
    card("storm_k5", "knight", "SETUP", "Щит-громоотвод", "outpost", "Блок 6; до следующего хода враг, подошедший вплотную, получает 4 урона.",
         dict(cost=1, shape="SELF", cast_range=0, block=6, special="outpost"),
         (dict(block=9), "Блок 9; до следующего хода враг, подошедший вплотную, получает 4 урона."),
         (dict(taunt=True), "Блок 6 и провокация; враг, подошедший вплотную, получает 4 урона.")),
    card("storm_k6", "knight", "FINISH", "Небесный клинок", "leap", "Прыжок до 3: 8 урона молнией +2 за звено Цепи по соседям.",
         dict(cost=2, shape="LEAP", cast_range=3, damage=8, per_link_damage=2, element="LIGHTNING"),
         (dict(damage=10), "Прыжок до 3: 10 урона молнией +2 за звено по соседям."),
         (dict(chain_need=4, chain_cost=1), "Прыжок до 3: 8 урона молнией +2 за звено по соседям.\nЦепь 4: стоит 1."), rare=True),
]
MIXED = [
    card("mix_tide_storm_m1", "mage", "FINISH", "Половодье с грозой", "flood", "Круг 1 до 5 — лужи, сразу молния по всей воде: 3 урона +1 за звено (мокрым +3).",
         dict(cost=2, shape="CROSS", cast_range=5, special="storm_flood", bonus_amount=3, per_link_damage=1),
         (dict(bonus_amount=4), "Круг 1 до 5 — лужи, сразу молния по всей воде: 4 урона +1 за звено."),
         (dict(chain_need=3, chain_cost=1), "Круг 1 до 5 — лужи и молния по воде: 3 урона +1 за звено.\nЦепь 3: стоит 1.")),
    card("mix_tide_storm_m2", "mage", "LINK", "Грозовая капель", "spark", "1 урон молнией каждому мокрому врагу в 5 клетках (с бонусом мокрым — 4).",
         dict(cost=0, shape="SELF", cast_range=0, special="drizzle", bonus_amount=1),
         (dict(bonus_amount=2), "2 урона молнией каждому мокрому врагу в 5 клетках (+3 мокрым)."),
         (dict(), "1 урон молнией каждому мокрому врагу в 5 клетках (+3). +1 заряд за каждого.")),
    card("mix_tide_storm_k1", "knight", "FINISH", "Шоковая волна", "wave", "Враги в лужах в 3 клетках: 4 урона молнией +1 за звено (мокрым +3).",
         dict(cost=2, shape="SELF", cast_range=0, special="shock_wave", bonus_amount=4, per_link_damage=1),
         (dict(), "Враги в лужах в 4 клетках: 4 урона молнией +1 за звено (мокрым +3)."),
         (dict(), "Враги в лужах в 3 клетках: 4 урона молнией +1 за звено, толчок 1.")),
    card("mix_tide_storm_k2", "knight", "LINK", "Мокрая сталь", "sword", "3 урона вплотную, цель мокнет; по уже мокрой — молнией (+3).",
         dict(cost=0, shape="SINGLE", cast_range=1, damage=3, element="WATER", special="wet_steel"),
         (dict(damage=4), "4 урона вплотную, цель мокнет; по уже мокрой — молнией (+3)."),
         (dict(cast_range=2), "3 урона до 2, цель мокнет; по уже мокрой — молнией (+3).")),
]


def write_set(cards, spirit_dir, spirits, cset):
    paths = []
    for i, c in enumerate(cards):
        c["cset"] = cset
        c["spirits"] = spirits
        c["slot"] = (i % 6) + 1 if len(spirits) == 1 else 0
        paths.append(write_card(c, spirit_dir))
    return paths


def write_enemy(path, sid, title, desc, hp, color, attacks):
    lines = ['[gd_resource type="Resource" script_class="EnemyData" load_steps=3 format=3]', "",
             '[ext_resource type="Script" path="res://scripts/data/enemy_data.gd" id="1_enemy"]',
             '[ext_resource type="Script" path="res://scripts/data/enemy_attack_data.gd" id="2_attack"]', ""]
    ids = []
    for i, a in enumerate(attacks):
        lines.append(f'[sub_resource type="Resource" id="atk{i}"]')
        lines.append('script = ExtResource("2_attack")')
        for k, v in a.items():
            lines.append(f"{k} = {gd(v)}")
        lines.append("")
        ids.append(f'SubResource("atk{i}")')
    lines += ["[resource]", 'script = ExtResource("1_enemy")', f"id = {gd('spirit_' + sid)}", f"title = {gd(title)}",
              f"description = {gd(desc)}", f"max_hp = {hp}", "move_range = 2", "damage = 3",
              f"color = Color({color})", "tamable = true", "is_elite = true",
              'cycle = Array[ExtResource("2_attack")]([' + ", ".join(ids) + "])"]
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


def write_spirit(sid, title, desc, passive, color, icon, call, mage, knight, mixed, enemy_path):
    call_path = write_card(call, f"resources/cards/spirits/{sid}")
    refs = {}
    n = [0]

    def ref(p):
        if p not in refs:
            n[0] += 1
            refs[p] = f"c{n[0]}"
        return f'ExtResource("{refs[p]}")'
    body_lines = ["[resource]", 'script = ExtResource("1_spirit")', f"id = {gd(sid)}", f"title = {gd(title)}",
                  f"description = {gd(desc)}", f"passive_text = {gd(passive)}", f"color = Color({color})",
                  f"icon = {gd(icon)}", f"call_card = {ref(call_path)}",
                  'mage_cards = Array[ExtResource("2_card")]([' + ", ".join(ref(p) for p in mage) + "])",
                  'knight_cards = Array[ExtResource("2_card")]([' + ", ".join(ref(p) for p in knight) + "])",
                  'mixed_cards = Array[ExtResource("2_card")]([' + ", ".join(ref(p) for p in mixed) + "])",
                  f"enemy = {ref(enemy_path)}"]
    head = [f'[gd_resource type="Resource" script_class="SpiritData" load_steps={len(refs) + 3} format=3]', "",
            '[ext_resource type="Script" path="res://scripts/data/spirit_data.gd" id="1_spirit"]',
            '[ext_resource type="Script" path="res://scripts/data/card_data.gd" id="2_card"]']
    for p, i in refs.items():
        kind = "Resource"
        head.append(f'[ext_resource type="{kind}" path="{p}" id="{i}"]')
    os.makedirs("resources/spirits", exist_ok=True)
    with open(f"resources/spirits/{sid}.tres", "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(head + [""] + body_lines) + "\n")


if __name__ == "__main__":
    tm = write_set(TIDE_M, "resources/cards/spirits/tide", [T], "s_tide")
    tk = write_set(TIDE_K, "resources/cards/spirits/tide", [T], "s_tide")
    sm = write_set(STORM_M, "resources/cards/spirits/storm", [S], "s_storm")
    sk = write_set(STORM_K, "resources/cards/spirits/storm", [S], "s_storm")
    mx = write_set(MIXED, "resources/cards/mixed", [T, S], "x_tide_storm")
    call_tide = card("tide_call", "", "", "Зов: Омут", "flood", "Зов духа (раз в бой): круг 1 до 4 становится лужами.",
                     dict(cost=0, shape="CROSS", cast_range=4, element="WATER", is_call=True, chain_add=-1, scrap_moves=0), None, None, cset="s_tide")
    call_storm = card("storm_call", "", "", "Зов: Удар грома", "bolt", "Зов духа (раз в бой): 4 урона молнией до 5; в луже — по всей луже.",
                      dict(cost=0, shape="SINGLE", cast_range=5, damage=4, element="LIGHTNING", is_call=True, chain_add=-1, scrap_moves=0), None, None, cset="s_storm")
    os.makedirs("resources/enemies", exist_ok=True)
    write_enemy("resources/enemies/spirit_tide.tres", "tide", "Омутник", "Тонул в каждом омуте Марки. Теперь сам решает, кого утопить.",
                26, "0.35, 0.6, 0.85, 1",
                [dict(title="Струя", shape=1, attack_range=3, damage=3, puddle=True),
                 dict(title="Водяные руки", shape=0, damage=4, pull=1, puddle=True)])
    write_enemy("resources/enemies/spirit_storm.tres", "storm", "Грозовик", "Гроза без неба. Злится, что ей некуда упасть.",
                22, "0.85, 0.82, 0.5, 1",
                [dict(title="Разряд", shape=1, attack_range=4, damage=4),
                 dict(title="Гром вокруг", shape=4, damage=3, push=1)])
    write_spirit("tide", "Омутник", "Тонул в каждом омуте Марки. Теперь сам решает, кого утопить.",
                 "в начале хода, если герой стоит в луже, +3 блока.", "0.45, 0.72, 0.95, 1", "drop",
                 call_tide, tm, tk, mx, "res://resources/enemies/spirit_tide.tres")
    write_spirit("storm", "Грозовик", "Гроза без неба. Злится, что ей некуда упасть.",
                 "удары героя по врагу в луже +2 урона.", "0.9, 0.86, 0.55, 1", "bolt",
                 call_storm, sm, sk, [], "res://resources/enemies/spirit_storm.tres")
    print("готово:", len(tm) + len(tk) + len(sm) + len(sk) + len(mx), "карт")

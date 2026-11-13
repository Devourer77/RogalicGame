# Генератор базовых карт Мага и Рыцаря (тз-карты.md, разделы 5 и 6).
# Каждая карта — один файл resources/cards/base/<id>.tres, обе ветки улучшения вложены в него.
# Запуск из папки проекта: python tools/cards/gen_base_cards.py
import os

SHAPE = dict(SELF=0, SINGLE=1, LINE=2, CROSS=3, SQUARE=4, ARC=5, CHARGE=6, ALLY=7, WALL=8, LEAP=9, AROUND=10, FELL=11)
ROLE = dict(MOVE=1, SETUP=2, LINK=3, FINISH=4)

# Поля по умолчанию у CardData — их в файл не пишем
DEFAULTS = dict(cost=1, cast_range=1, damage=0, push=0, block=0, bonus_moves=0, draw=0, is_rare=False,
                taunt=False, rage_gain=0, rage_bonus=0, momentum_gain=0, charge_gain=0, charge_bonus=0,
                pierce_block=False, special="", chain_need=0, chain_damage=0, chain_cost=-1, chain_push=0,
                chain_draw=0, chain_charge=0, chain_range=0, per_link_damage=0, chain_add=0, pull=0,
                execute_damage=12, kill_mana=0, ally_block=0, move_distance=0, discount_next=0, scrap_moves=1)

# Карта: id, герой, архетип, роль, название, рисунок, текст, поля; I и II — (поля-изменения, текст)
CARDS = [
    # ---------------- МАГ ----------------
    dict(id="mb_staff", hero="mage", arch="kinetic", role="LINK", title="Удар посохом", icon="staff",
         text="3 урона вплотную, толчок 1.\nЦепь 2: +3 урона.",
         f=dict(cost=0, shape="SINGLE", cast_range=1, damage=3, push=1, chain_need=2, chain_damage=3),
         up1=(dict(damage=5), "5 урона вплотную, толчок 1.\nЦепь 2: +3 урона."),
         up2=(dict(chain_charge=1), "3 урона вплотную, толчок 1.\nЦепь 2: +3 урона и +1 заряд.")),
    dict(id="mb_spark", hero="mage", arch="charge", role="LINK", title="Искра осколка", icon="spark",
         text="2 урона до 4. +1 заряд.",
         f=dict(cost=0, shape="SINGLE", cast_range=4, damage=2, charge_gain=1),
         up1=(dict(damage=3, cast_range=5), "3 урона до 5. +1 заряд."),
         up2=(dict(special="spark_ignite"), "2 урона до 4. +1 заряд.\nПоджигает газ, бочку или камыш в клетке.")),
    dict(id="mb_shove", hero="mage", arch="kinetic", role="SETUP", title="Толчок", icon="push",
         text="2 урона до 2, толчок 2.",
         f=dict(cost=1, shape="SINGLE", cast_range=2, damage=2, push=2),
         up1=(dict(push=3), "2 урона до 2, толчок 3."),
         up2=(dict(chain_need=1, chain_cost=0), "2 урона до 2, толчок 2.\nЦепь 1: стоит 0.")),
    dict(id="mb_dash", hero="mage", arch="kinetic", role="MOVE", title="Рывок", icon="dash",
         text="+2 шага, добор 1.",
         f=dict(cost=0, shape="SELF", cast_range=0, bonus_moves=2, draw=1),
         up1=(dict(bonus_moves=3), "+3 шага, добор 1."),
         up2=(dict(charge_gain=1, chain_need=2, chain_draw=1), "+2 шага, добор 1, +1 заряд.\nЦепь 2: добор 2.")),
    dict(id="mb_shield", hero="mage", arch="flow", role="SETUP", title="Магический щит", icon="shield",
         text="Блок 6 магу или союзнику до 4.",
         f=dict(cost=1, shape="ALLY", cast_range=4, block=6),
         up1=(dict(block=9), "Блок 9 магу или союзнику до 4."),
         up2=(dict(ally_block=4), "Блок 6 магу или союзнику до 4.\nВторой герой — ещё блок 4.")),
    dict(id="mb_focus", hero="mage", arch="charge", role="SETUP", title="Сосредоточение", icon="focus",
         text="+2 заряда.",
         f=dict(cost=0, shape="SELF", cast_range=0, charge_gain=2),
         up1=(dict(charge_gain=3), "+3 заряда."),
         up2=(dict(chain_need=2, chain_draw=1), "+2 заряда.\nЦепь 2: добор 1.")),
    dict(id="mb_discharge", hero="mage", arch="charge", role="FINISH", title="Разрядка", icon="bolt",
         text="Цель до 5: 4 урона +2 за каждый заряд. Тратит весь заряд.",
         f=dict(cost=2, shape="SINGLE", cast_range=5, damage=4, charge_bonus=2),
         up1=(dict(damage=6), "Цель до 5: 6 урона +2 за каждый заряд. Тратит весь заряд."),
         up2=(dict(per_link_damage=1), "Цель до 5: 4 урона +2 за каждый заряд и +1 за звено Цепи. Тратит заряд.")),
    dict(id="mb_pull", hero="mage", arch="kinetic", role="SETUP", title="Притяжение", icon="chain",
         text="Враг до 5 притягивается к магу на 3. По пути срабатывают трясина, газ и огонь.",
         f=dict(cost=1, shape="SINGLE", cast_range=5, pull=3),
         up1=(dict(cost=0), "Враг до 5 притягивается к магу на 3. По пути срабатывают трясина, газ и огонь."),
         up2=(dict(special="pull_to_ally"), "Враг до 5 притягивается к союзнику на 3. По пути срабатывают трясина, газ и огонь.")),
    dict(id="mb_swap", hero="mage", arch="kinetic", role="MOVE", title="Обмен", icon="swap",
         text="Поменяться местами с союзником или врагом до 4 (не с тяжёлым).",
         f=dict(cost=0, shape="SINGLE", cast_range=4, special="swap_any"),
         up1=(dict(cast_range=6), "Поменяться местами с союзником или врагом до 6 (не с тяжёлым)."),
         up2=(dict(damage=3, ally_block=4), "Поменяться местами с союзником или врагом до 4.\nВрагу 3 урона, союзнику блок 4.")),
    dict(id="mb_transfer", hero="mage", arch="flow", role="SETUP", title="Перенос", icon="transfer",
         text="Огонь, лужа, газ, лёд или бочка до 4 сдвигается на 2 клетки дальше от мага.",
         f=dict(cost=1, shape="SINGLE", cast_range=4, special="transfer", move_distance=2),
         up1=(dict(cost=0), "Огонь, лужа, газ, лёд или бочка до 4 сдвигается на 2 клетки дальше от мага."),
         up2=(dict(move_distance=3, charge_gain=1), "Огонь, лужа, газ, лёд или бочка до 4 сдвигается на 3 клетки дальше. +1 заряд.")),
    dict(id="mb_spread", hero="mage", arch="flow", role="SETUP", title="Разнести", icon="wave",
         text="Огонь, лужа, газ или топь в клетке до 5 растекается на 6 соседних клеток.",
         f=dict(cost=1, shape="SINGLE", cast_range=5, special="spread"),
         up1=(dict(charge_gain=1), "Огонь, лужа, газ или топь в клетке до 5 растекается на 6 соседних. +1 заряд."),
         up2=(dict(chain_need=2, chain_cost=0), "Огонь, лужа, газ или топь в клетке до 5 растекается на 6 соседних.\nЦепь 2: стоит 0.")),
    dict(id="mb_crack", hero="mage", arch="flow", role="SETUP", title="Надлом", icon="tree",
         text="Клетка до 5: дерево падает от мага, бочка взрывается, лёд раскалывается. Врагу 3 урона.",
         f=dict(cost=1, shape="SINGLE", cast_range=5, damage=3),
         up1=(dict(cost=0), "Клетка до 5: дерево падает от мага, бочка взрывается, лёд раскалывается. Врагу 3 урона."),
         up2=(dict(charge_gain=2), "Клетка до 5: дерево падает, бочка взрывается, лёд раскалывается. Врагу 3 урона. +2 заряда.")),
    dict(id="mb_blink", hero="mage", arch="kinetic", role="MOVE", title="Скачок", icon="leap",
         text="Маг переносится на клетку до 3 сквозь преграды и трясину.",
         f=dict(cost=1, shape="LEAP", cast_range=3),
         up1=(dict(cost=0), "Маг переносится на клетку до 3 сквозь преграды и трясину."),
         up2=(dict(chain_need=2, chain_range=2, chain_charge=1), "Маг переносится на клетку до 3 сквозь преграды.\nЦепь 2: до 5 и +1 заряд.")),
    dict(id="mb_repulse", hero="mage", arch="kinetic", role="SETUP", title="Отталкивающий круг", icon="wind",
         text="6 клеток вокруг мага: 1 урон, толчок 2.",
         f=dict(cost=1, shape="AROUND", cast_range=0, damage=1, push=2),
         up1=(dict(push=3), "6 клеток вокруг мага: 1 урон, толчок 3."),
         up2=(dict(special="block_per_enemy"), "6 клеток вокруг мага: 1 урон, толчок 2.\nБлок 3 за каждого врага.")),
    dict(id="mb_echo", hero="mage", arch="flow", role="LINK", title="Эхо", icon="echo", rare=True,
         text="Последняя карта мага в этот ход (кроме ★) возвращается в руку и стоит на 1 меньше.",
         f=dict(cost=1, shape="SELF", cast_range=0, special="echo"),
         up1=(dict(cost=0), "Последняя карта мага в этот ход (кроме ★) возвращается в руку и стоит на 1 меньше."),
         up2=(dict(discount_next=2), "Последняя карта мага в этот ход (кроме ★) возвращается в руку и стоит на 2 меньше.")),
    dict(id="mb_lesson", hero="mage", arch="charge", role="FINISH", title="Последний урок", icon="rift", rare=True,
         text="Линия 6: 3 урона +2 за звено Цепи, сквозь блок.",
         f=dict(cost=2, shape="LINE", cast_range=6, damage=3, per_link_damage=2, pierce_block=True),
         up1=(dict(damage=4), "Линия 6: 4 урона +2 за звено Цепи, сквозь блок."),
         up2=(dict(special="charge_to_chain"), "Заряд становится звеньями Цепи. Линия 6: 3 урона +2 за звено, сквозь блок.")),
    dict(id="mb_overload", hero="mage", arch="charge", role="SETUP", title="Перегрузка", icon="overload", rare=True,
         text="Заряд ×2 (до 10). Не потратил до конца хода — маг получает урон, равный заряду.",
         f=dict(cost=1, shape="SELF", cast_range=0, special="overload"),
         up1=(dict(cost=0), "Заряд ×2 (до 10). Не потратил до конца хода — маг получает урон, равный заряду."),
         up2=(dict(chain_add=2), "Заряд ×2 (до 10), +2 к Цепи. Не потратил заряд — маг получает урон, равный заряду.")),
    # ---------------- РЫЦАРЬ ----------------
    dict(id="kb_sword", hero="knight", arch="onslaught", role="LINK", title="Удар мечом", icon="sword",
         text="6 урона вплотную.\nЦепь 2: +2.",
         f=dict(cost=1, shape="SINGLE", cast_range=1, damage=6, chain_need=2, chain_damage=2),
         up1=(dict(damage=8), "8 урона вплотную.\nЦепь 2: +2."),
         up2=(dict(cost=0, damage=4), "4 урона вплотную.\nЦепь 2: +2.")),
    dict(id="kb_lunge", hero="knight", arch="onslaught", role="LINK", title="Выпад", icon="spear",
         text="Линия 2: 3 урона.\nЦепь 2: +2.",
         f=dict(cost=0, shape="LINE", cast_range=2, damage=3, chain_need=2, chain_damage=2),
         up1=(dict(damage=4, cast_range=3), "Линия 3: 4 урона.\nЦепь 2: +2."),
         up2=(dict(momentum_gain=2), "Линия 2: 3 урона, потом +2 натиска.\nЦепь 2: +2.")),
    dict(id="kb_shield", hero="knight", arch="warden", role="SETUP", title="Поднять щит", icon="shield",
         text="Блок 7.",
         f=dict(cost=1, shape="SELF", cast_range=0, block=7),
         up1=(dict(block=10), "Блок 10."),
         up2=(dict(block=5, taunt=True), "Блок 5 и провокация.")),
    dict(id="kb_runup", hero="knight", arch="onslaught", role="MOVE", title="Разбег", icon="dash",
         text="+2 шага, +2 натиска.",
         f=dict(cost=0, shape="SELF", cast_range=0, bonus_moves=2, momentum_gain=2),
         up1=(dict(bonus_moves=3), "+3 шага, +2 натиска."),
         up2=(dict(draw=1), "+2 шага, +2 натиска, добор 1.")),
    dict(id="kb_ram", hero="knight", arch="onslaught", role="MOVE", title="Таран", icon="ram",
         text="Бег по прямой до 4. Врезавшись: 4 урона + натиск, толчок 1. Дерево падает, бочка взрывается.",
         f=dict(cost=1, shape="CHARGE", cast_range=4, damage=4, push=1),
         up1=(dict(cast_range=6), "Бег по прямой до 6. Врезавшись: 4 урона + натиск, толчок 1."),
         up2=(dict(bonus_moves=1), "Бег по прямой до 4. Врезавшись: 4 урона + натиск, толчок 1. Потом +1 шаг.")),
    dict(id="kb_sweep", hero="knight", arch="warden", role="LINK", title="Размах", icon="slash",
         text="Дуга: 4 урона каждому.\nЦепь 2: +2.",
         f=dict(cost=1, shape="ARC", cast_range=1, damage=4, chain_need=2, chain_damage=2),
         up1=(dict(damage=5), "Дуга: 5 урона каждому.\nЦепь 2: +2."),
         up2=(dict(push=1), "Дуга: 4 урона каждому, толчок 1.\nЦепь 2: +2.")),
    dict(id="kb_taunt", hero="knight", arch="warden", role="SETUP", title="Вызов", icon="taunt",
         text="Провокация, блок 5.",
         f=dict(cost=1, shape="SELF", cast_range=0, block=5, taunt=True),
         up1=(dict(block=8), "Провокация, блок 8."),
         up2=(dict(special="pull_near"), "Провокация, блок 5. Враги в 2 клетках подтягиваются на 1.")),
    dict(id="kb_warcry", hero="knight", arch="rage", role="LINK", title="Боевой клич", icon="horn",
         text="+2 ярости, добор 1.",
         f=dict(cost=0, shape="SELF", cast_range=0, rage_gain=2, draw=1),
         up1=(dict(rage_gain=3), "+3 ярости, добор 1."),
         up2=(dict(ally_block=4), "+2 ярости, добор 1. Союзнику блок 4.")),
    dict(id="kb_blood", hero="knight", arch="rage", role="FINISH", title="Кровавый удар", icon="blood",
         text="5 урона вплотную +3 за каждую ярость. Тратит всю ярость.",
         f=dict(cost=2, shape="SINGLE", cast_range=1, damage=5, rage_bonus=3),
         up1=(dict(cost=1), "5 урона вплотную +3 за каждую ярость. Тратит всю ярость."),
         up2=(dict(per_link_damage=1), "5 урона вплотную +3 за ярость и +1 за звено Цепи. Тратит ярость.")),
    dict(id="kb_cover", hero="knight", arch="warden", role="SETUP", title="Прикрыть", icon="cover",
         text="Блок 8 союзнику до 4 (или себе).",
         f=dict(cost=1, shape="ALLY", cast_range=4, block=8),
         up1=(dict(block=11), "Блок 11 союзнику до 4 (или себе)."),
         up2=(dict(special="leap_to_ally"), "Рыцарь встаёт рядом с союзником до 4. Союзнику блок 8.")),
    dict(id="kb_stakes", hero="knight", arch="warden", role="SETUP", title="Вбить колья", icon="stakes",
         text="Частокол на соседнюю пустую клетку.",
         f=dict(cost=1, shape="SINGLE", cast_range=1, special="stakes"),
         up1=(dict(cost=0), "Частокол на соседнюю пустую клетку."),
         up2=(dict(special="stakes2"), "Частокол на соседнюю пустую клетку и ещё на одну рядом.")),
    dict(id="kb_boot", hero="knight", arch="warden", role="LINK", title="Пинок", icon="boot",
         text="Соседний враг: 1 урон, толчок 2. Бочка катится до 4 и взрывается при ударе.",
         f=dict(cost=0, shape="SINGLE", cast_range=1, damage=1, push=2, special="boot"),
         up1=(dict(push=3), "Соседний враг: 1 урон, толчок 3. Бочка катится до 4 и взрывается при ударе."),
         up2=(dict(damage=3), "Соседний враг: 3 урона, толчок 2. Бочка катится до 4 и взрывается при ударе.")),
    dict(id="kb_chop", hero="knight", arch="warden", role="LINK", title="Рубящий удар", icon="axe",
         text="5 урона по соседней клетке. Дерево падает от рыцаря, бочка взрывается.",
         f=dict(cost=1, shape="SINGLE", cast_range=1, damage=5),
         up1=(dict(damage=7), "7 урона по соседней клетке. Дерево падает от рыцаря, бочка взрывается."),
         up2=(dict(cost=0, damage=3), "3 урона по соседней клетке. Дерево падает от рыцаря, бочка взрывается.")),
    dict(id="kb_leap", hero="knight", arch="onslaught", role="MOVE", title="Прыжок с ударом", icon="leap",
         text="Прыжок до 3 через преграды и трясину: 4 урона + натиск по 6 соседям.",
         f=dict(cost=2, shape="LEAP", cast_range=3, damage=4),
         up1=(dict(cost=1), "Прыжок до 3 через преграды и трясину: 4 урона + натиск по 6 соседям."),
         up2=(dict(cast_range=4, damage=6), "Прыжок до 4 через преграды и трясину: 6 урона + натиск по 6 соседям.")),
    dict(id="kb_execute", hero="knight", arch="rage", role="FINISH", title="Добивание", icon="axe",
         text="5 урона вплотную; по врагу с половиной HP или меньше — 12.\nЦепь 4: всегда 12.",
         f=dict(cost=1, shape="SINGLE", cast_range=1, damage=5, special="execute", chain_need=4),
         up1=(dict(execute_damage=14), "5 урона вплотную; по врагу с половиной HP или меньше — 14.\nЦепь 4: всегда 14."),
         up2=(dict(kill_mana=1), "5 урона вплотную; по раненому вдвое — 12. Убил — +1 мана.\nЦепь 4: всегда 12.")),
    dict(id="kb_whirl", hero="knight", arch="rage", role="FINISH", title="Вихрь стали", icon="whirl", rare=True,
         text="6 клеток вокруг: 5 урона, +1 ярость за каждого задетого.\nЦепь 3: +3.",
         f=dict(cost=2, shape="AROUND", cast_range=0, damage=5, special="whirl_rage", chain_need=3, chain_damage=3),
         up1=(dict(damage=6), "6 клеток вокруг: 6 урона, +1 ярость за каждого задетого.\nЦепь 3: +3."),
         up2=(dict(bonus_moves=2), "6 клеток вокруг: 5 урона, +1 ярость за каждого. Потом +2 шага.\nЦепь 3: +3.")),
    dict(id="kb_unstoppable", hero="knight", arch="onslaught", role="LINK", title="Неудержимый", icon="unstoppable", rare=True,
         text="До конца хода каждое убийство рыцаря даёт 1 ману и 2 шага.",
         f=dict(cost=1, shape="SELF", cast_range=0, special="unstoppable"),
         up1=(dict(cost=0), "До конца хода каждое убийство рыцаря даёт 1 ману и 2 шага."),
         up2=(dict(special="unstoppable_chain"), "До конца хода каждое убийство рыцаря даёт 1 ману, 2 шага и +1 к Цепи.")),
    dict(id="kb_bell", hero="knight", arch="warden", role="SETUP", title="Колокол Стражи", icon="bell", rare=True,
         text="Враги в 3 клетках отлетают на 1. Провокация, блок 6.",
         f=dict(cost=2, shape="SELF", cast_range=0, block=6, taunt=True, special="bell", push=1),
         up1=(dict(block=10), "Враги в 3 клетках отлетают на 1. Провокация, блок 10."),
         up2=(dict(push=2), "Враги в 3 клетках отлетают на 2. Провокация, блок 6.")),
]

STARTERS = {
    "mage": ["mb_staff", "mb_spark", "mb_spark", "mb_shove", "mb_dash", "mb_shield", "mb_focus", "mb_discharge"],
    "knight": ["kb_sword", "kb_sword", "kb_lunge", "kb_shield", "kb_runup", "kb_ram", "kb_taunt", "kb_execute"],
}


def gd(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    return '"' + str(v).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def body(c, fields, text, level, ident, title):
    lines = ['script = ExtResource("1_card")']
    vals = dict(id=ident, icon=c["icon"], title=title, description=text)
    for k, v in vals.items():
        lines.append(f"{k} = {gd(v)}")
    merged = dict(fields)
    shape = merged.pop("shape")
    lines.append(f"shape = {SHAPE[shape]}")
    for k, v in merged.items():
        if DEFAULTS.get(k) != v:
            lines.append(f"{k} = {gd(v)}")
    if c.get("rare"):
        lines.append("is_rare = true")
    lines.append(f'card_set = {gd(("m_" if c["hero"] == "mage" else "k_") + c["arch"])}')
    lines.append(f'owner_hero = {gd(c["hero"])}')
    lines.append(f'role = {ROLE[c["role"]]}')
    lines.append(f'archetype = {gd(c["arch"])}')
    if level:
        lines.append(f"upgrade_level = {level}")
    return lines


def write_card(c, out_dir):
    f = c["f"]
    parts = ['[gd_resource type="Resource" script_class="CardData" load_steps=4 format=3]', "",
             '[ext_resource type="Script" path="res://scripts/data/card_data.gd" id="1_card"]', ""]
    for n in (1, 2):
        over, text = c[f"up{n}"]
        fields = dict(f)
        fields.update(over)
        parts.append(f'[sub_resource type="Resource" id="up{n}"]')
        parts += body(c, fields, text, n, f'{c["id"]}+{n}', c["title"] + "+" + ("I" if n == 1 else "II"))
        parts.append("")
    parts.append("[resource]")
    parts += body(c, f, c["text"], 0, c["id"], c["title"])
    parts.append('upgrade_1 = SubResource("up1")')
    parts.append('upgrade_2 = SubResource("up2")')
    with open(os.path.join(out_dir, c["id"] + ".tres"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(parts) + "\n")


def write_hero(path, hero, ids_pool, starters):
    # Меняем в .tres героя только starter_deck и card_pool, остальное не трогаем
    src = open(path, encoding="utf-8").read().split("\n")
    head = [l for l in src if not l.startswith('[ext_resource type="Resource"') and l.strip() != ""]
    out = []
    for l in src:
        if l.startswith('[ext_resource type="Resource" path="res://resources/cards/'):
            continue
        out.append(l)
    text = "\n".join(out)
    ext = "\n".join(f'[ext_resource type="Resource" path="res://resources/cards/base/{i}.tres" id="c_{i}"]' for i in ids_pool)
    text = text.replace('\n[resource]', "\n" + ext + "\n\n[resource]", 1)
    import re
    text = re.sub(r"starter_deck = .*", "starter_deck = Array[ExtResource(\"2_card\")]([" + ", ".join(f'ExtResource("c_{i}")' for i in starters) + "])", text)
    text = re.sub(r"card_pool = .*", "card_pool = Array[ExtResource(\"2_card\")]([" + ", ".join(f'ExtResource("c_{i}")' for i in ids_pool) + "])", text)
    text = re.sub(r"load_steps=\d+", f"load_steps={len(ids_pool) + 4}", text, count=1)
    text = re.sub(r"\n{3,}", "\n\n", text)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)


if __name__ == "__main__":
    out = "resources/cards/base"
    os.makedirs(out, exist_ok=True)
    for c in CARDS:
        write_card(c, out)
    for hero in ("mage", "knight"):
        pool = [c["id"] for c in CARDS if c["hero"] == hero]
        write_hero(f"resources/heroes/{hero}.tres", hero, pool, STARTERS[hero])
    print("карт:", len(CARDS))

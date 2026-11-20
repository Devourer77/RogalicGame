# Люди акта 2 по старым заготовкам (`враги-акт-2.md`): Культ Пустого Венца и павший дозорный Стражи.
# Один скрипт собирает десять моделей на общем теле `act2_human.py`:
#   cult_catcher (Ловец Венца), cult_censer (Кадильщик), cult_executioner (Палач, запас),
#   cult_brander (Угольный Клеймитель), cult_porter (Пеплоход-Носильщик), cult_jailer (Тюремщик),
#   cult_bannerman (Знаменосец), cult_archivist (элита Архивариус Пепла), cult_forgemaster (элита Горновой),
#   burnt_sentry (Обгоревший дозорный — тварь Раскола из павшей Стражи).
# Референсы Gemini для этих врагов в работу не попали — модели собраны по описаниям облика из документов.
# Смотрят в -Y. Анимации: Idle, Walk, Attack, Hit, Death (у Архивариуса и Горнового ещё Attack2, Attack3).
# Запуск: python3 build_cult_act2.py — все; ONLY=cult_jailer python3 build_cult_act2.py — одну.
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2
import act2_human as hu
from act2_human import cult_mats, cult_hood, crown_bone


def chain(prefix, a, b, n, mat, bone, r=0.018):
    """Цепь из коротких звеньев от a до b."""
    for i in range(n):
        f0, f1 = i / n, (i + 0.7) / n
        p0 = tuple(a[j] + (b[j] - a[j]) * f0 for j in range(3))
        p1 = tuple(a[j] + (b[j] - a[j]) * f1 for j in range(3))
        k.limb(f"{prefix}{i}", p0, p1, r, r, mat, bone, segs=4)


def robe_body(B, c, robe_col=None, under=None):
    B.figure(c["skin"], robe_col or c["ash"], under or c["coal"], c["leather"], robe=True, head=False, long_robe=True)


# ---------- Ловец Венца ----------
def m_catcher(B):
    c = cult_mats()
    robe_body(B, c, c["ash_d"], c["coal"])
    cult_hood(B, c)
    hx, hy, hz = B.hand_r
    # Тяжёлая тёмно-бурая цепь с крюком свисает из руки на плиты
    chain("Chain", (hx, hy, hz - 0.04), (hx, hy - 0.3, 0.06), 7, c["leather"], "Weapon", r=0.02)
    k.plate("Hook", [(0, 0), (0.04, 0), (0.08, 0.05), (0.1, 0.13), (0.06, 0.15), (0.06, 0.09), (0.02, 0.05)], 0.03,
            (hx, hy - 0.32, 0.03), (0, -1, 0), (0, 0, 1), c["iron"], "Weapon")
    chain("ChainL", (B.hand_l[0], B.hand_l[1], B.hand_l[2] - 0.04), (B.hand_l[0] + 0.05, B.hand_l[1] + 0.05, 0.5), 4,
          c["leather"], "Hand.L", r=0.02)


# ---------- Кадильщик Венца ----------
def m_censer(B):
    c = cult_mats()
    dust = k.mat("CC_Dust", (0.6, 0.58, 0.54), rough=0.95)
    robe_body(B, c, dust, c["ash_d"])
    cult_hood(B, c)
    hx, hy, hz = B.hand_r
    chain("CenserChain", (hx, hy - 0.02, hz - 0.03), (hx, hy - 0.12, hz - 0.36), 4, c["iron_d"], "Weapon", r=0.01)
    k.sphere("Censer", 0.07, (hx, hy - 0.13, hz - 0.42), c["iron"], "Weapon", scale=(1, 1, 0.85), segs=7, rings=4)
    k.box("CenserCap", (0.06, 0.06, 0.03), (hx, hy - 0.13, hz - 0.36), c["iron_d"], "Weapon")
    k.box("CenserGlow", (0.06, 0.02, 0.02), (hx, hy - 0.2, hz - 0.42), c["coalglow"], "Weapon")
    for i in range(3):   # зеленовато-серый дым
        k.sphere(f"Smoke{i}", 0.05 + 0.015 * i, (hx + 0.03 * i, hy - 0.12, hz - 0.28 + 0.1 * i), c["smoke"], "Weapon",
                 segs=5, rings=3)


# ---------- Палач Венца ----------
def m_executioner(B):
    c = cult_mats()
    robe_body(B, c, c["ash"], c["coal"])
    p = B.p
    k.sphere("Bulk", 0.24 * B.s, p(0, 0, 1.3), c["ash"], "Chest", scale=(1.15, 0.8, 0.9), segs=8, rings=4)
    k.box("Mantle", (0.56 * B.s, 0.3 * B.s, 0.1), p(0, 0, 1.4), c["coal"], "Chest")
    cult_hood(B, c, crowns=0)
    # Венец-корона: кольцо с зубцами
    a2.ring("CrownBand", 0.13 * B.s, 0.018, p(0, 0.01, 1.86), (0, 0, 1), c["bone"], "Crown", seg=14)
    for i in range(6):
        a = math.tau * i / 6
        k.limb(f"Spike{i}", p(0.13 * math.cos(a), 0.01 + 0.13 * math.sin(a), 1.86), p(0.13 * math.cos(a), 0.01 + 0.13 * math.sin(a), 1.95),
               0.018, 0.004, c["bone"], "Crown", segs=4)
    hx, hy, hz = B.hand_r
    k.limb("Haft", (hx, hy + 0.3, hz), (hx, hy - 0.75, hz), 0.025, 0.025, c["wood"], "Weapon", segs=6)
    k.plate("AxeHead", [(0, 0.05), (0.14, 0.12), (0.2, 0.02), (0.2, -0.14), (0.14, -0.2), (0, -0.1)], 0.035,
            (hx, hy - 0.68, hz), (0, -1, 0), (0, 0, 1), c["iron"], "Weapon")


# ---------- Угольный Клеймитель ----------
def m_brander(B):
    c = cult_mats()
    robe_body(B, c, c["ash"], c["coal"])
    p = B.p
    # Кожаная маска-ведро с узкой прорезью вместо капюшона
    k.barrel("Bucket", 0.12 * B.s, 0.11 * B.s, p(0, 0, 1.48)[2], p(0, 0, 1.72)[2], c["leather"], "Head", segs=8)
    k.box("Slit", (0.12 * B.s, 0.02, 0.015), p(0, -0.12, 1.62), c["void"], "Head")
    cult_hood(B, c, hood=False)
    # Корзина с углями на спине
    k.barrel("Basket", 0.12 * B.s, 0.15 * B.s, p(0, 0, 1.08)[2], p(0, 0, 1.36)[2], c["iron_d"], "Chest", segs=8,
             loc=(0, 0.2 * B.s))
    k.sphere("BasketCoals", 0.12 * B.s, p(0, 0.2, 1.36), c["coalglow"], "Chest", scale=(1, 1, 0.4), segs=6, rings=3)
    hx, hy, hz = B.hand_r
    k.limb("Pole", (hx, hy + 0.4, hz), (hx, hy - 0.9, hz), 0.022, 0.022, c["iron_d"], "Weapon", segs=6)
    a2.ring("BrandRing", 0.09, 0.015, (hx, hy - 0.95, hz), (0, 1, 0), c["hot"], "Weapon", seg=12)
    k.box("BrandBarA", (0.16, 0.02, 0.02), (hx, hy - 0.95, hz), c["hot"], "Weapon")
    k.box("BrandBarB", (0.02, 0.02, 0.16), (hx, hy - 0.95, hz), c["hot"], "Weapon")


# ---------- Пеплоход-Носильщик ----------
def m_porter(B):
    c = cult_mats()
    robe_body(B, c, c["ash_d"], c["coal"])
    p = B.p
    k.plate("Apron", [(-0.17, 0), (0.17, 0), (0.18, -0.5), (-0.18, -0.5)], 0.02, p(0, -0.16, 1.28), (B.s, 0, 0),
            (0, -0.08 * B.s, B.s), c["leather"], "Chest")
    k.sphere("Sack", 0.12 * B.s, p(0, -0.01, 1.6), c["ash"], "Head", scale=(0.95, 1.0, 1.15), segs=7, rings=4)
    k.sphere("Face", 0.08 * B.s, p(0, -0.07, 1.58), c["void"], "Head", scale=(0.9, 0.6, 0.9), segs=6, rings=4)
    cult_hood(B, c, hood=False)
    # Огромный треснувший котёл на спине
    k.barrel("Cauldron", 0.24 * B.s, 0.28 * B.s, p(0, 0, 0.98)[2], p(0, 0, 1.46)[2], c["iron_d"], "Chest", segs=10,
             loc=(0, 0.3 * B.s))
    k.barrel("CauldronRim", 0.29 * B.s, 0.29 * B.s, p(0, 0, 1.44)[2], p(0, 0, 1.49)[2], c["iron"], "Chest", segs=10,
             loc=(0, 0.3 * B.s))
    k.sphere("CauldronCoals", 0.24 * B.s, p(0, 0.3, 1.46), c["coalglow"], "Chest", scale=(1, 1, 0.3), segs=7, rings=3)
    for i, (pts, o) in enumerate([([(0, 0), (0.03, -0.08), (0.0, -0.16), (0.04, -0.24)], p(0.1, 0.03, 1.36)),
                                  ([(0, 0), (-0.04, -0.06), (-0.02, -0.14)], p(-0.12, 0.05, 1.3))]):
        k.crack(f"CauldronCrack{i}", pts, o, (1, 0, 0), (0, 0, 1), c["coalglow"], "Chest", width=0.02, depth=0.02)
    k.limb("StrapL", p(0.13, -0.08, 1.4), p(0.15, 0.1, 1.1), 0.02, 0.02, c["leather"], "Chest", segs=4)
    k.limb("StrapR", p(-0.13, -0.08, 1.4), p(-0.15, 0.1, 1.1), 0.02, 0.02, c["leather"], "Chest", segs=4)
    hx, hy, hz = B.hand_r
    k.limb("Shaft", (hx, hy + 0.1, hz), (hx, hy - 0.4, hz), 0.02, 0.02, c["wood"], "Weapon", segs=5)
    k.box("Blade", (0.14, 0.16, 0.02), (hx, hy - 0.47, hz), c["iron"], "Weapon")


# ---------- Тюремщик Венца ----------
def m_jailer(B):
    c = cult_mats()
    robe_body(B, c, c["ash"], c["coal"])
    p = B.p
    k.plate("Apron", [(-0.17, 0), (0.17, 0), (0.18, -0.55), (-0.18, -0.55)], 0.02, p(0, -0.16, 1.28), (B.s, 0, 0),
            (0, -0.08 * B.s, B.s), c["leather"], "Chest")
    cult_hood(B, c)
    a2.ring("KeyRing", 0.05, 0.008, p(0.16, -0.08, 0.92), (0, 1, 0), c["iron"], "Hips", seg=10)
    for i in range(3):
        k.box(f"Key{i}", (0.015, 0.015, 0.08), p(0.15 + 0.02 * i, -0.09, 0.86), c["iron"], "Hips", rot=(0, 0, 10 * i))
    # Клетка-фонарь с огоньком на спине
    k.box("CageBase", (0.22, 0.22, 0.03), p(0, 0.24, 1.08), c["iron_d"], "Chest")
    k.box("CageTop", (0.22, 0.22, 0.03), p(0, 0.24, 1.38), c["iron_d"], "Chest")
    for i, (x, y) in enumerate([(-0.1, 0.14), (0.1, 0.14), (-0.1, 0.34), (0.1, 0.34), (0.0, 0.14)]):
        k.box(f"CageBar{i}", (0.015, 0.015, 0.3), p(x, y, 1.23), c["iron"], "Chest")
    k.sphere("Wisp", 0.08, p(0, 0.24, 1.22), c["hot"], "Chest", scale=(1, 1, 1.3), segs=6, rings=4)
    hx, hy, hz = B.hand_r
    k.limb("Pole", (hx, hy + 0.4, hz), (hx, hy - 0.9, hz), 0.022, 0.022, c["wood"], "Weapon", segs=6)
    a2.ring("Noose", 0.08, 0.012, (hx, hy - 0.98, hz), (1, 0, 0), c["iron"], "Weapon", seg=12)


# ---------- Знаменосец Венца ----------
def m_bannerman(B):
    c = cult_mats()
    robe_body(B, c, c["ash"], c["coal"])
    p = B.p
    k.box("Breastplate", (0.36 * B.s, 0.08, 0.32 * B.s), p(0, -0.13, 1.28), c["iron"], "Chest", rot=(-6, 0, 0))
    cult_hood(B, c)
    hx, hy, hz = B.hand_r
    # Высокое древко (кость Weapon поднята вверх стойкой) и рваное знамя с пустым кругом
    k.limb("Pole", (hx, hy + 0.5, hz), (hx, hy - 1.6, hz), 0.025, 0.025, c["wood"], "Weapon", segs=6)
    k.limb("PoleTip", (hx, hy - 1.6, hz), (hx, hy - 1.7, hz), 0.03, 0.004, c["iron"], "Weapon", segs=5)
    k.plate("Banner", [(0, 0), (0.42, 0), (0.42, -0.5), (0.34, -0.62), (0.22, -0.5), (0.1, -0.64), (0.0, -0.52)], 0.015,
            (hx + 0.02, hy - 1.5, hz), (1, 0, 0), (0, 1, 0), c["ash"], "Weapon")
    a2.ring("BannerCircle", 0.1, 0.014, (hx + 0.23, hy - 1.24, hz + 0.012), (0, 0, 1), c["bone"], "Weapon", seg=12)


# ---------- Архивариус Пепла (элита) ----------
def m_archivist(B):
    c = cult_mats()
    robe_body(B, c, c["ash"], c["coal"])
    p = B.p
    # Многослойная пирамидальная мантия и высокий воротник
    for i, (z0, z1, r0, r1) in enumerate([(0.2, 0.62, 0.34, 0.27), (0.6, 0.98, 0.28, 0.22), (0.96, 1.3, 0.24, 0.2)]):
        k.barrel(f"Mantle{i}", r0 * B.s, r1 * B.s, p(0, 0, z0)[2], p(0, 0, z1)[2], c["ash"] if i % 2 == 0 else c["ash_d"],
                 "Hips" if i < 2 else "Chest", segs=8, sy=0.8)
    k.barrel("Collar", 0.16 * B.s, 0.2 * B.s, p(0, 0, 1.4)[2], p(0, 0, 1.6)[2], c["coal"], "Chest", segs=8, loc=(0, 0.04 * B.s))
    k.sphere("Embers", 0.34 * B.s, p(0, 0, 0.12), c["coalglow"], "Hips", scale=(1, 0.8, 0.12), segs=8, rings=3)
    cult_hood(B, c, crowns=3, crown_r=0.13)
    # Ранец-пюпитр со свитками
    k.box("Lectern", (0.36 * B.s, 0.1, 0.6 * B.s), p(0, 0.22, 1.36), c["wood"], "Chest", rot=(-12, 0, 0))
    for i in range(6):
        x = -0.12 + 0.05 * i
        k.limb(f"Scroll{i}", p(x, 0.28, 1.5 + 0.03 * (i % 2)), p(x, 0.3, 1.78 + 0.05 * (i % 3)), 0.022, 0.022,
               k.mat("CA_Paper", (0.7, 0.66, 0.56), rough=0.9), "Chest", segs=5)
    # Раскрытая книга на цепи в левой руке, страницы тлеют
    lx, ly, lz = B.hand_l
    k.box("BookCover", (0.26, 0.2, 0.025), (lx, ly - 0.12, lz + 0.02), c["leather"], "Hand.L", rot=(20, 0, 0))
    k.box("BookPages", (0.24, 0.18, 0.02), (lx, ly - 0.12, lz + 0.045), k.mat("CA_Pages", (0.72, 0.68, 0.58), rough=0.9),
          "Hand.L", rot=(20, 0, 0))
    k.box("PageGlow", (0.24, 0.02, 0.02), (lx, ly - 0.21, lz + 0.03), c["coalglow"], "Hand.L", rot=(20, 0, 0))
    chain("BookChain", (lx, ly - 0.05, lz), (0.1 * B.s, -0.1, 0.98 * B.s), 4, c["iron_d"], "Hand.L", r=0.01)


# ---------- Горновой Венца (элита) ----------
def m_forgemaster(B):
    c = cult_mats()
    burnt = k.mat("CF_Burnt", (0.5, 0.38, 0.32), rough=0.8)
    B.figure(burnt, c["ash"], c["coal"], c["leather"], robe=True, sleeves=burnt, head=False, long_robe=True)
    p = B.p
    k.sphere("Bulk", 0.22 * B.s, p(0, 0, 1.3), c["ash"], "Chest", scale=(1.15, 0.8, 0.9), segs=8, rings=4)
    k.plate("Apron", [(-0.2, 0), (0.2, 0), (0.21, -0.75), (-0.21, -0.75)], 0.025, p(0, -0.17, 1.32), (B.s, 0, 0),
            (0, -0.1 * B.s, B.s), c["leather"], "Chest")
    cult_hood(B, c, crown_r=0.13)
    # Переносной горн с мехами на спине
    k.box("Forge", (0.38 * B.s, 0.28 * B.s, 0.26 * B.s), p(0, 0.28, 1.3), c["iron_d"], "Chest")
    k.sphere("ForgeCoals", 0.16 * B.s, p(0, 0.28, 1.44), c["coalglow"], "Chest", scale=(1.1, 0.8, 0.4), segs=7, rings=3)
    k.box("Bellows", (0.06, 0.22 * B.s, 0.2 * B.s), p(0.24, 0.28, 1.26), c["leather"], "Chest", rot=(0, 0, 8))
    k.limb("BellowsNozzle", p(0.22, 0.2, 1.26), p(0.16, 0.2, 1.3), 0.025, 0.02, c["iron"], "Chest", segs=5)
    # Клещи с раскалённым концом
    hx, hy, hz = B.hand_r
    for sgn in (-1, 1):
        k.limb(f"Tong{sgn}", (hx + 0.02 * sgn, hy + 0.05, hz), (hx + 0.01 * sgn, hy - 0.55, hz), 0.014, 0.014, c["iron_d"],
               "Weapon", segs=4)
    k.box("TongTip", (0.05, 0.08, 0.04), (hx, hy - 0.6, hz), c["hot"], "Weapon")


# ---------- Обгоревший дозорный (павшая Стража, тварь Раскола) ----------
def m_sentry(B):
    c = cult_mats()
    charred = k.mat("BS_Charred", (0.2, 0.19, 0.19), metallic=0.4, rough=0.6)
    tabard = k.mat("BS_Tabard", (0.42, 0.42, 0.34), rough=0.95)
    rift = k.mat("BS_Rift", (0.30, 0.95, 0.85), rough=0.4, emit=1.8)
    B.figure(charred, charred, charred, charred, robe=False, head=False)
    p = B.p
    k.plate("Tabard", [(-0.15, 0), (0.15, 0), (0.13, -0.62), (0.03, -0.55), (-0.05, -0.66), (-0.14, -0.58)], 0.02,
            p(0, -0.17, 1.36), (B.s, 0, 0), (0, -0.06 * B.s, B.s), tabard, "Chest")
    k.sphere("Bell", 0.05, p(0, -0.19, 1.22), c["iron_d"], "Chest", scale=(1, 0.5, 1.1), segs=6, rings=4)
    k.sphere("Helm", 0.13 * B.s, p(0, 0.0, 1.58), charred, "Head", scale=(0.95, 1.05, 1.1), segs=8, rings=5)
    k.box("HelmSlit", (0.14, 0.02, 0.02), p(0, -0.135, 1.6), rift, "Head")
    for i, (bone, pts, o) in enumerate([("Chest", [(0, 0), (0.04, -0.06), (0.02, -0.12)], p(0.08, -0.155, 1.34)),
                                        ("Spine", [(0, 0), (-0.04, -0.05)], p(-0.06, -0.14, 1.1)),
                                        ("Head", [(0, 0), (0.03, 0.04)], p(0.05, -0.13, 1.66))]):
        k.crack(f"Rift{i}", pts, o, (1, 0, 0), (0, 0, 1), rift, bone, width=0.014, depth=0.014)
    for side, sg in hu.SIDES:
        k.sphere(f"Pauldron.{side}", 0.09 * B.s, p(0.22 * sg, 0, 1.38), charred, "Chest", scale=(1.2, 1.1, 0.7), segs=6, rings=4)
    hx, hy, hz = B.hand_r
    k.box("Stock", (0.06, 0.5, 0.07), (hx, hy - 0.12, hz), charred, "Weapon")
    k.plate("Bow", [(-0.3, 0.05), (0.0, -0.02), (0.3, 0.05), (0.3, 0.09), (0.0, 0.02), (-0.3, 0.09)], 0.03,
            (hx, hy - 0.38, hz), (1, 0, 0), (0, -1, 0), c["iron_d"], "Weapon")


CHARS = {
    # имя: (рост, функция, стиль удара, сутулость, присед, кольца венца, доп. стойка)
    "cult_catcher": (1.7, m_catcher, "thrust", 18, 0.0, 1, {"Weapon": (-10, 0, 0)}),
    "cult_censer": (1.7, m_censer, "thrust", 8, 0.0, 1, {"Weapon": (-20, 0, 0)}),
    "cult_executioner": (2.2, m_executioner, "swing", 6, 0.1, 1, {}),
    "cult_brander": (1.9, m_brander, "thrust", 16, 0.0, 1, {}),
    "cult_porter": (1.5, m_porter, "swing", 30, 0.15, 1, {}),
    "cult_jailer": (1.8, m_jailer, "thrust", 8, 0.0, 1, {}),
    "cult_bannerman": (1.9, m_bannerman, "thrust", 0, 0.0, 1,
                       {"Weapon": (88, 0, 0), "UpperArm.R": (-10, 0, 14), "ForeArm.R": (-60, 0, 0),
                        "UpperArm.L": (-20, 0, -10), "ForeArm.L": (-40, 0, 0)}),
    "cult_archivist": (2.3, m_archivist, "aim", 4, 0.0, 3, {"Weapon": (0, 0, 0)}),
    "cult_forgemaster": (2.2, m_forgemaster, "swing", 12, 0.1, 1, {}),
    "burnt_sentry": (1.7, m_sentry, "aim", 4, 0.2, 0, {}),
}


def build_one(name, glb, blend):
    h, fn, style, hunch, crouch, crowns, extra = CHARS[name]
    B = hu.Body(h)
    extra_bones = crown_bone(B, crowns) if crowns else None
    k.start_scene(name)
    fn(B)
    body = k.join_parts(name + "Mesh")
    rig = k.build_armature(name, B.bones(extra_bones))
    body.parent = rig
    st = dict(extra)
    if crowns:
        st["Crown"] = (0, 0, 0)
    anim = hu.Anim(style, hunch=hunch, crouch=crouch, extra_stance=st)
    extras = []
    if name in ("cult_archivist", "cult_forgemaster"):
        # второй и третий удары цикла: призыв/печать (руки вверх) и вариант основного удара
        def raise_(t, anim=anim):
            p = anim.base()
            up = track(t, [(0, 0), (0.3, 1), (0.7, 1), (1, 0)])
            p.add("UpperArm.R", x=-90 * up, z=20 * up)
            p.add("UpperArm.L", x=-90 * up, z=-20 * up)
            p.add("Chest", x=-10 * up)
            p.add("Head", x=-14 * up)
            return p
        extras = [("Attack2", 30, raise_), ("Attack3", 24, anim.attack)]
    anim.bake_all(rig, extra=extras)
    k.export(rig, body, glb, blend)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    only = os.environ.get("ONLY")
    for name in CHARS:
        if only and name not in only.split(","):
            continue
        build_one(name, os.path.join(here, "..", name + ".glb"), os.path.join(here, name + ".blend"))

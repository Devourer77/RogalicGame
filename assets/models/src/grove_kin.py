# Общее «тело Хранителя Рощи» для всех Хранителей (Страж, Ловчая, Отравительница, Пасечник, Щит Коры,
# Носящий шкуру, Дождевая, Голос Рощи). Облик — claude/мир.md, «Новые враги акта 1»; референсы Gemini
# 17 ноября, выбор — claude/тз-референсы-лес.md (набор «А»: бурая шкура, тёплая маска, капюшон под маской).
#
# Пропорции задаются двумя числами: W — ширина (плечи, торс, руки), H — рост (все высоты).
# Базовый Хранитель (W = H = 1) — Страж, ~1.8 м с капюшоном. Все точки модели и костей считаются через P(),
# поэтому скелет и модель всегда совпадают.
# Здесь же — общие материалы, маска с капюшоном, шкура-накидка, побеги с листьями и общие движения
# ног, корпуса, головы и накидки. Руки и снаряжение каждый скрипт двигает сам.
import math
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse

SIDES = (("R", -1), ("L", 1))
# Детальная версия (для хаба, событий и крупных планов): отдельные пальцы, обод маски, больше листьев.
# Включается переменной окружения GROVE_DETAIL=1 вместе с CHAR_SHAPE=smooth — так собирается *_hd.glb.
import os as _os
DETAIL = _os.environ.get("GROVE_DETAIL") == "1"
W = 1.0
H = 1.0


def setup(width=1.0, height=1.0):
    """Задать пропорции до сборки модели и костей."""
    global W, H
    W, H = width, height


def P(x, y, z):
    """Точка с учётом пропорций: x — по ширине, z — по росту, y (вперёд-назад) — по ширине."""
    return (x * W, y * W, z * H)


def materials(prefix):
    """Общие материалы. Цвета чуть светлее природных, иначе фигура сливается с тёмными моховыми плитами.
    Одежда в основном бурая (лес зелёный — иначе Хранитель в нём растворится), зелёные только побеги."""
    return {
        "fur": k.mat(prefix + "_Fur", (0.40, 0.28, 0.18), rough=0.95),          # бурая шкура
        "fur_d": k.mat(prefix + "_FurDark", (0.30, 0.21, 0.13), rough=0.95),
        "cloth": k.mat(prefix + "_Cloth", (0.40, 0.43, 0.35), rough=0.95),      # приглушённая серо-зелёная шерсть
        "cloth_d": k.mat(prefix + "_ClothDark", (0.31, 0.33, 0.27), rough=0.95),
        "hood": k.mat(prefix + "_Hood", (0.33, 0.27, 0.20), rough=0.95),       # бурый капюшон под маской
        "leather": k.mat(prefix + "_Leather", (0.33, 0.23, 0.15), rough=0.85),
        "wrap": k.mat(prefix + "_Wrap", (0.47, 0.42, 0.34), rough=0.95),       # обмотки (не костяные: темнее)
        "skin": k.mat(prefix + "_Skin", (0.64, 0.50, 0.40), rough=0.8),        # только кисти рук
        "mask": k.mat(prefix + "_Mask", (0.56, 0.35, 0.21), rough=0.6),        # тёплое ореховое дерево
        "mask_d": k.mat(prefix + "_MaskSlit", (0.07, 0.05, 0.04), rough=1.0),  # прорези глаз
        "sign": k.mat(prefix + "_Sign", (0.72, 0.94, 0.80), rough=0.4, emit=1.8),   # знак: бледный серебристо-зелёный
        "leaf": k.mat(prefix + "_Leaf", (0.38, 0.58, 0.27), rough=0.7),        # живые листья
        "vine": k.mat(prefix + "_Vine", (0.30, 0.46, 0.21), rough=0.8),
        "wood": k.mat(prefix + "_Wood", (0.45, 0.32, 0.20), rough=0.85),
        "stone": k.mat(prefix + "_Stone", (0.64, 0.64, 0.61), rough=0.75),
        "feather": k.mat(prefix + "_Feather", (0.2, 0.19, 0.18), rough=0.8),     # тёмные перья (не чисто чёрные)
        "string": k.mat(prefix + "_String", (0.6, 0.56, 0.47), rough=0.8),     # жила тетивы
        "reed": k.mat(prefix + "_Reed", (0.55, 0.5, 0.3), rough=0.7),          # сухой тростник (приглушённый)
        "clay": k.mat(prefix + "_Clay", (0.55, 0.4, 0.29), rough=0.85),       # глиняные пузырьки
        "wicker": k.mat(prefix + "_Wicker", (0.4, 0.3, 0.19), rough=0.9),     # тёмные прутья улья (не светлые: жёлтый занят)
        "bee": k.mat(prefix + "_Bee", (0.12, 0.11, 0.1), rough=0.6),           # пчёлы — тёмные точки
        "cut": k.mat(prefix + "_Cut", (0.58, 0.43, 0.29), rough=0.85),        # срез ствола (темнее светлого дерева)
        "ring": k.mat(prefix + "_Ring", (0.45, 0.32, 0.21), rough=0.85),      # годовые кольца
        "bark": k.mat(prefix + "_Bark", (0.27, 0.2, 0.14), rough=0.95),
        "moss": k.mat(prefix + "_Moss", (0.33, 0.47, 0.24), rough=0.9),
        "pelt": k.mat(prefix + "_Pelt", (0.4, 0.4, 0.38), rough=0.95),        # волчья шкура: серая, не светлее волка
        "pelt_d": k.mat(prefix + "_PeltDark", (0.29, 0.29, 0.28), rough=0.95),
        "ribbon": k.mat(prefix + "_Ribbon", (0.56, 0.72, 0.84), rough=0.7),    # бледно-голубые ленты
        "drop": k.mat(prefix + "_Drop", (0.55, 0.82, 1.0), rough=0.2, emit=1.4),   # светящиеся капли воды
    }


# ---------- Модель ----------

def legs(M):
    """Сапоги, обмотки на голенях (как в наборе «Б»), штаны.
    Суставы закрыты: колено — шар на голени, бедро уходит вверх под таз, голенище заходит в сапог,
    поэтому при сгибе ноги не видно щелей и торцов цилиндров (исправлено 25 ноября)."""
    for side, s in SIDES:
        x = 0.12 * s
        # Сапог: округлая ступня от пятки к носку (на кости стопы) и твёрдая подошва с чёткими рёбрами
        k.limb(f"Boot.{side}", P(x, 0.05, 0.065), P(x, -0.17, 0.045), 0.072 * W, 0.05 * W, M["leather"],
               f"Foot.{side}", segs=6)
        k.box(f"Sole.{side}", (0.12 * W, 0.24 * W, 0.03 * H), P(x, -0.06, 0.015), M["fur_d"], f"Foot.{side}")
        # Голенище сапога: на голени, нижний край уходит внутрь ступни — щиколотка без щели
        k.limb(f"BootTop.{side}", P(x, 0, 0.05), P(x, 0, 0.21), 0.068 * W, 0.074 * W, M["leather"], f"Shin.{side}")
        k.limb(f"BootCuff.{side}", P(x, 0, 0.19), P(x, 0, 0.23), 0.08 * W, 0.08 * W, M["leather"], f"Shin.{side}")
        # Голень в обмотках: сплошная (без колец-пружинок), икра чуть шире, сверху — под коленом
        k.limb(f"Shin.{side}", P(x, 0, 0.21), P(x, -0.005, 0.47), 0.07 * W, 0.08 * W, M["wrap"], f"Shin.{side}")
        for i, (z, tilt) in enumerate(((0.28, 0.01), (0.38, -0.01))):   # две косые завязки поверх обмоток
            k.limb(f"Wrap.{side}{i}", P(x, tilt, z), P(x, -tilt, z + 0.035), 0.08 * W, 0.082 * W,
                   M["leather"], f"Shin.{side}")
        # Колено: шар в точке сгиба закрывает стык бедра и голени при любом угле
        k.sphere(f"Knee.{side}", 0.084 * W, P(x, -0.008, 0.48), M["cloth_d"], f"Shin.{side}",
                 scale=(1.0, 1.08, 1.0), segs=6, rings=4)
        # Бедро: шире сверху, верх спрятан в тазу, низ — внутри колена
        k.limb(f"Thigh.{side}", P(x, -0.008, 0.48), P(x * 0.95, 0, 0.92), 0.082 * W, 0.108 * W,
               M["cloth_d"], f"Thigh.{side}")


def torso(M, skirt=True):
    """Таз, рубаха, пояс, кожаные полы спереди и сзади (свои кости — колышутся)."""
    k.barrel("Pelvis", 0.19 * W, 0.2 * W, 0.8 * H, 0.92 * H, M["cloth_d"], "Hips", sy=0.8)
    k.barrel("Tunic", 0.21 * W, 0.25 * W, 0.9 * H, 1.2 * H, M["cloth"], "Spine", sy=0.74)
    k.barrel("TunicUp", 0.25 * W, 0.2 * W, 1.2 * H, 1.4 * H, M["cloth"], "Chest", sy=0.74)
    k.barrel("Belt", 0.215 * W, 0.215 * W, 0.88 * H, 0.95 * H, M["leather"], "Hips", sy=0.8)
    k.box("Buckle", (0.06 * W, 0.03 * W, 0.05 * H), P(0, -0.17, 0.915), M["wood"], "Hips")
    k.limb("Strap", P(-0.17, -0.15, 1.36), P(0.16, -0.17, 0.95), 0.02 * W, 0.02 * W, M["leather"], "Spine", segs=4)
    if skirt:
        flap = [(-0.15, 0.0), (0.15, 0.0), (0.14, -0.3), (0.07, -0.38), (0.0, -0.32), (-0.08, -0.4), (-0.14, -0.3)]
        k.plate("FlapFront", [(a * W, b * H) for a, b in flap], 0.024 * W, P(0, -0.17, 0.9), (1, 0, 0), (0, -0.1, 1),
                M["leather"], "FlapF")
        k.plate("FlapBack", [(a * W, b * H) for a, b in flap], 0.024 * W, P(0, 0.17, 0.9), (-1, 0, 0), (0, 0.1, 1),
                M["cloth_d"], "FlapB")
        for side, s in SIDES:   # боковые полы рубахи
            side_flap = [(-0.09, 0.0), (0.09, 0.0), (0.08, -0.26), (0.0, -0.3), (-0.08, -0.25)]
            k.plate(f"FlapSide.{side}", [(a * W, b * H) for a, b in side_flap], 0.02 * W, P(0.2 * s, 0, 0.9),
                    (0, 1, 0), (0.12 * s, 0, 1), M["cloth"], "Hips")


def arm_upper(M, side, s, shoulder, elbow):
    """Плечо и рукав до локтя (точки уже с пропорциями)."""
    k.sphere(f"Shoulder.{side}", 0.08 * W, shoulder, M["cloth"], f"UpperArm.{side}", segs=5, rings=3)
    k.limb(f"Sleeve.{side}", shoulder, elbow, 0.066 * W, 0.062 * W, M["cloth"], f"UpperArm.{side}")


def arm_lower(M, side, s, elbow, wrist, fist_dir=(0, -1, 0)):
    """Предплечье с кожаным наручем и кулак (кисть + пальцы спереди + большой палец)."""
    from mathutils import Vector
    e, w_ = Vector(elbow), Vector(wrist)
    k.sphere(f"Elbow.{side}", 0.064 * W, elbow, M["cloth"], f"ForeArm.{side}", segs=5, rings=3)
    mid = e.lerp(w_, 0.35)
    k.limb(f"ForeArm.{side}", elbow, tuple(mid), 0.06 * W, 0.064 * W, M["cloth"], f"ForeArm.{side}")
    k.limb(f"Bracer.{side}", tuple(mid), wrist, 0.07 * W, 0.064 * W, M["leather"], f"ForeArm.{side}")
    d = (w_ - e).normalized()
    f = Vector(fist_dir).normalized()
    c = w_ + d * 0.05 * W
    k.sphere(f"Fist.{side}", 0.058 * W, tuple(c), M["skin"], f"Hand.{side}", scale=(0.9, 1.0, 1.0), segs=6, rings=4)
    if not DETAIL:
        k.box(f"Fingers.{side}", (0.085 * W, 0.045 * W, 0.08 * W), tuple(c + f * 0.04 * W), M["skin"], f"Hand.{side}")
        return
    # Отдельные пальцы: четыре согнутых пальца спереди кулака и большой палец сбоку
    across = d.cross(f).normalized()
    for i in range(4):
        base = c + f * 0.035 * W + d * (0.03 - 0.02 * i) * W
        k.limb(f"Finger.{side}{i}", tuple(base), tuple(base + f * 0.03 * W - d * 0.012 * W), 0.014 * W, 0.012 * W,
               M["skin"], f"Hand.{side}", segs=5)
    tb = c - across * 0.04 * W * s + d * 0.02 * W
    k.limb(f"Thumb.{side}", tuple(tb), tuple(tb + f * 0.04 * W - d * 0.01 * W), 0.016 * W, 0.012 * W,
           M["skin"], f"Hand.{side}", segs=5)


def hood_and_head(M):
    """Капюшон закрывает голову целиком: сбоку и сзади лица не видно — только маска спереди."""
    k.sphere("Hood", 0.14 * W, P(0, 0.03, 1.6), M["hood"], "Head", scale=(1.0, 1.0, 1.12), segs=7, rings=4)
    k.limb("HoodPeak", P(0, 0.09, 1.66), P(0, 0.2, 1.6), 0.07 * W, 0.0, M["hood"], "Head", segs=5)
    k.limb("HoodTail", P(0, 0.1, 1.56), P(0, 0.19, 1.42), 0.08 * W, 0.03 * W, M["hood"], "Head", segs=5)
    k.barrel("Neck", 0.1 * W, 0.09 * W, 1.38 * H, 1.48 * H, M["hood"], "Head", segs=7)


def bird_mask(M, cy=1.6, r=0.14, beak=0.2):
    """Птичья маска Ловчей: овал поуже и длинный загнутый клюв вперёд-вниз."""
    k.sphere("Mask", r * W, P(0, -0.1, cy), M["mask"], "Head", scale=(0.78, 0.4, 1.05), segs=7, rings=5)
    front = -0.1 - r * 0.4
    k.limb("Beak", P(0, front + 0.02, cy - 0.01), P(0, front - beak * 0.8, cy - beak * 0.5), 0.05 * W, 0.012 * W,
           M["mask"], "Head", segs=4)
    k.limb("BeakTip", P(0, front - beak * 0.8, cy - beak * 0.5), P(0, front - beak * 0.86, cy - beak * 0.66),
           0.012 * W, 0.002, M["mask"], "Head", segs=4)
    for s in (-1, 1):
        k.box(f"Eye{s}", (0.035 * W, 0.02 * W, 0.03 * H), P(0.045 * s, front + 0.012, cy + 0.03), M["mask_d"], "Head")
    leaf_sign(M, P(0, front + 0.02, cy + 0.09), size=0.055)


def slice_mask(M, cy=1.6, r=0.17):
    """Маска Голоса Рощи: большой круглый спил ствола — кора по краю, светящиеся годовые кольца.
    Над ней низкий венок из живых побегов (без рогов: рога — у шамана и корягача)."""
    y0 = -0.11
    k.limb("MaskBark", P(0, y0 + 0.03, cy), P(0, y0 - 0.03, cy), r * W, r * W, M["bark"], "Head", segs=10)
    k.limb("Mask", P(0, y0 - 0.025, cy), P(0, y0 - 0.04, cy), r * 0.93 * W, r * 0.93 * W, M["mask"], "Head", segs=10)
    for i, rr in enumerate((0.72, 0.46, 0.2)):   # кольца ступеньками: каждое внутреннее чуть выпуклее
        d = 0.004 * i
        k.limb(f"MaskRing{i}", P(0, y0 - 0.039, cy), P(0, y0 - 0.046 - d, cy), r * rr * W, r * rr * W,
               M["sign"], "Head", segs=9)
        if i < 2:
            k.limb(f"MaskGap{i}", P(0, y0 - 0.04, cy), P(0, y0 - 0.0475 - d, cy), r * (rr - 0.11) * W,
                   r * (rr - 0.11) * W, M["mask"], "Head", segs=9)
    n = 9
    for i in range(n):   # низкий венок побегов вокруг затылка
        a = math.pi * (0.05 + 0.9 * i / (n - 1))
        base = P(math.cos(a) * 0.13, 0.04 + math.sin(a) * 0.05, cy + 0.12)
        tip = P(math.cos(a) * 0.19, 0.06 + math.sin(a) * 0.08, cy + 0.2)
        k.limb(f"Wreath{i}", base, tip, 0.012 * W, 0.004 * W, M["vine"], "Head", segs=4)
        leaf_at(M, f"WreathLeaf{i}", tip, "Head", tilt=i * 37, size=0.07)


def drop_mask(M, cy=1.6, r=0.14):
    """Маска Дождевой: гладкая капля — округлый низ и острая верхушка, узкие прорези, знак на лбу."""
    k.sphere("Mask", r * W, P(0, -0.1, cy - 0.01), M["mask"], "Head", scale=(0.8, 0.33, 0.95), segs=7, rings=5)
    front = -0.1 - r * 0.33
    k.limb("MaskTip", P(0, -0.1 - r * 0.2, cy + 0.07), P(0, -0.1 - r * 0.12, cy + 0.2), 0.09 * W, 0.0,
           M["mask"], "Head", segs=5)
    for s in (-1, 1):
        k.box(f"Slit{s}", (0.04 * W, 0.02 * W, 0.012 * H), P(0.04 * s, front + 0.006, cy), M["mask_d"], "Head")
    leaf_sign(M, P(0, front + 0.014, cy + 0.08), size=0.05)


def robe(M):
    """Длинная ряса до земли вместо штанов и пол: нижняя часть на тазу, полы спереди и сзади колышутся."""
    k.barrel("RobeLow", 0.3 * W, 0.22 * W, 0.03 * H, 0.9 * H, M["cloth_d"], "Hips", segs=9, sy=0.85)
    panel = [(-0.2, 0.0), (0.2, 0.0), (0.24, -0.72), (0.12, -0.84), (0.0, -0.76), (-0.12, -0.86), (-0.24, -0.74)]
    k.plate("RobeFront", [(a * W, b * H) for a, b in panel], 0.03 * W, P(0, -0.2, 0.9), (1, 0, 0), (0, -0.12, 1),
            M["fur"], "FlapF")
    k.plate("RobeBack", [(a * W, b * H) for a, b in panel], 0.03 * W, P(0, 0.2, 0.9), (-1, 0, 0), (0, 0.12, 1),
            M["cloth"], "FlapB")


def ribbons(M, at_list, bone, length=0.3):
    """Голубые ленты (цвет воды) — свисают плоскими полосками."""
    for i, at in enumerate(at_list):
        pts = [(-0.018, 0.0), (0.018, 0.0), (0.02, -length), (0.0, -length * 0.9), (-0.02, -length)]
        k.plate(f"Ribbon{bone}{i}", [(a * W, b * H) for a, b in pts], 0.006, at, (1, 0, 0.2 * (i % 2)), (0, 0.15, 1),
                M["ribbon"], bone)


def wolf_mask(M, cy=1.6, r=0.14):
    """Резная волчья маска: вытянутая морда вперёд, острые уши, косые прорези глаз, знак на лбу."""
    k.sphere("Mask", r * W, P(0, -0.09, cy + 0.01), M["mask"], "Head", scale=(0.95, 0.5, 1.0), segs=7, rings=5)
    front = -0.09 - r * 0.5
    k.limb("Muzzle", P(0, front + 0.04, cy - 0.03), P(0, front - 0.13, cy - 0.07), 0.07 * W, 0.035 * W,
           M["mask"], "Head", segs=5)
    k.box("Nose", (0.04 * W, 0.03 * W, 0.03 * H), P(0, front - 0.13, cy - 0.06), M["mask_d"], "Head")
    for s in (-1, 1):
        k.limb(f"Ear{s}", P(0.07 * s, -0.06, cy + 0.1), P(0.1 * s, -0.04, cy + 0.22), 0.045 * W, 0.0,
               M["mask"], "Head", segs=3)
        k.box(f"Eye{s}", (0.045 * W, 0.02 * W, 0.014 * H), P(0.045 * s, front + 0.012, cy + 0.03), M["mask_d"], "Head",
              rot=(0, 18 * s, 0))
    leaf_sign(M, P(0, front + 0.016, cy + 0.09), size=0.05)


def shield_mask(M, cy=1.6, r=0.16):
    """Маска Щита Коры: широкая и плоская, как маленький щит, с острым низом и двумя прорезями."""
    k.sphere("Mask", r * W, P(0, -0.1, cy + 0.01), M["mask"], "Head", scale=(1.0, 0.26, 0.95), segs=7, rings=5)
    front = -0.1 - r * 0.26
    k.limb("MaskPoint", P(0, front + 0.02, cy - 0.08), P(0, front + 0.005, cy - 0.17), 0.07 * W, 0.0,
           M["mask"], "Head", segs=4)
    for s in (-1, 1):
        k.box(f"Slit{s}", (0.05 * W, 0.02 * W, 0.013 * H), P(0.055 * s, front + 0.006, cy + 0.02), M["mask_d"], "Head")
    leaf_sign(M, P(0, front + 0.014, cy + 0.1), size=0.055)


def comb_mask(M, cy=1.6, r=0.155):
    """Маска Пасечника: широкий овал с выпуклым узором пчелиных сот (тёмные шестиугольные ячейки)."""
    k.sphere("Mask", r * W, P(0, -0.1, cy), M["mask"], "Head", scale=(0.9, 0.33, 1.08), segs=7, rings=5)
    front = -0.1 - r * 0.33
    hexagon = [(0.024 * math.cos(math.pi / 3 * i + math.pi / 6), 0.024 * math.sin(math.pi / 3 * i + math.pi / 6))
               for i in range(6)]
    cells = [(-0.045, -0.035), (0.0, -0.035), (0.045, -0.035), (-0.0225, -0.074), (0.0225, -0.074),
             (-0.068, 0.004), (0.068, 0.004)]
    for i, (x, z) in enumerate(cells):
        depth = math.sqrt(max(0.0, 1 - (x / (r * 0.9)) ** 2 - (z / (r * 1.08)) ** 2))
        k.plate(f"Comb{i}", hexagon, 0.012 * W, P(x, -0.1 - r * 0.33 * depth - 0.002, cy + z), (1, 0, 0), (0, 0.2, 1),
                M["mask_d"], "Head")
    for s in (-1, 1):
        k.box(f"Slit{s}", (0.045 * W, 0.02 * W, 0.013 * H), P(0.045 * s, front + 0.006, cy + 0.03), M["mask_d"], "Head")
    leaf_sign(M, P(0, front + 0.016, cy + 0.09), size=0.055)


def snake_mask(M, cy=1.6, r=0.14):
    """Змеиная маска Отравительницы: узкий вытянутый овал, морда-клин вперёд-вниз, косые прорези глаз."""
    k.sphere("Mask", r * W, P(0, -0.1, cy), M["mask"], "Head", scale=(0.7, 0.42, 1.2), segs=7, rings=5)
    front = -0.1 - r * 0.42
    k.limb("Snout", P(0, front + 0.03, cy - 0.04), P(0, front - 0.09, cy - 0.12), 0.06 * W, 0.025 * W,
           M["mask"], "Head", segs=4)
    for s in (-1, 1):
        k.box(f"Eye{s}", (0.045 * W, 0.02 * W, 0.014 * H), P(0.04 * s, front + 0.01, cy + 0.03), M["mask_d"], "Head",
              rot=(0, -22 * s, 0))
    leaf_sign(M, P(0, front + 0.018, cy + 0.1), size=0.05)


def cape(M):
    """Короткая накидка-капюшон с побегами (без большой шкуры): воротник и плащ до бёдер."""
    k.sphere("Collar", 0.24 * W, P(0, 0.03, 1.35), M["hood"], "Chest", scale=(1.15, 1.0, 0.45), segs=7, rings=4)
    for i in range(9):
        a = math.pi * (-0.05 + 1.1 * i / 8)
        x, y = -math.cos(a) * 0.27, math.sin(a) * 0.21 + 0.03
        k.limb(f"CapeTip{i}", P(x * 0.9, y * 0.9, 1.36), P(x * 1.1, y * 1.15, 1.22), 0.05 * W, 0.0,
               M["hood"] if i % 2 else M["cloth_d"], "Chest", segs=4)
    cloak = [(0.0, 0.0), (0.24, 0.02), (0.26, -0.45), (0.17, -0.6), (0.08, -0.5), (0.0, -0.62)]
    for side, s in SIDES:
        pts = [(a * s * W, b * H) for a, b in cloak]
        k.plate(f"Cloak.{side}", pts, 0.035 * W, P(0, 0.19, 1.33), (1, 0.18 * s, 0), (0, 0.12, 1),
                M["hood"] if s < 0 else M["cloth_d"], "Cloak")


def feather_mantle(M, big=1.0):
    """Тёмные перья на плечах Ловчей: два ряда острых перьев веером по краю, короткая накидка сзади."""
    k.sphere("Collar", 0.23 * W * big, P(0, 0.03, 1.36), M["fur"], "Chest", scale=(1.2, 1.0, 0.42), segs=7, rings=4)
    n = 13
    for row, (rad, z, ln) in enumerate([(0.27, 1.37, 0.22), (0.2, 1.44, 0.15)]):
        cnt = n - 3 * row
        for i in range(cnt):
            a = math.pi * (-0.1 + 1.2 * i / (cnt - 1))
            x, y = -math.cos(a) * rad * big, math.sin(a) * rad * 0.8 * big + 0.03
            r = math.hypot(x, y) or 1.0
            out = (x / r, y / r)
            # перо висит вниз и наружу: ось v смотрит вверх-внутрь, контур идёт по -v
            feather = [(-0.035, 0.0), (0.035, 0.0), (0.018, -ln), (0.0, -ln * 1.15), (-0.018, -ln)]
            k.plate(f"Feather{row}_{i}", [(u * W, v * H) for u, v in feather], 0.012 * W, P(x, y, z),
                    (-out[1], out[0], 0), (-out[0] * 0.8, -out[1] * 0.8, 1), M["feather"], "Chest")
    cloak = [(0.0, 0.0), (0.2, 0.02), (0.22, -0.34), (0.14, -0.46), (0.06, -0.38), (0.0, -0.48)]
    for side, s in SIDES:
        pts = [(a * s * W, b * H) for a, b in cloak]
        k.plate(f"Cloak.{side}", pts, 0.035 * W, P(0, 0.19, 1.33), (1, 0.18 * s, 0), (0, 0.12, 1), M["cloth_d"], "Cloak")


def oval_mask(M, slits=True, sign=True, cy=1.6, r=0.15):
    """Гладкая овальная маска Стража: выпуклый овал, две узкие прорези, на лбу светится вырезанный лист."""
    k.sphere("Mask", r * W, P(0, -0.105, cy), M["mask"], "Head", scale=(0.82, 0.33, 1.12), segs=7, rings=5)
    front = -0.105 - r * 0.33
    if DETAIL:   # тёмный обод маски
        k.sphere("MaskRim", r * 1.04 * W, P(0, -0.095, cy), M["leather"], "Head", scale=(0.82, 0.3, 1.12), segs=8, rings=5)
    if slits:
        for s in (-1, 1):
            k.box(f"Slit{s}", (0.05 * W, 0.02 * W, 0.013 * H), P(0.042 * s, front + 0.006, cy + 0.015), M["mask_d"], "Head",
                  rot=(0, 8 * s, 0))
    if sign:
        leaf_sign(M, P(0, front + 0.016, cy + 0.08), size=0.065)


def leaf_sign(M, at, size=0.05, bone="Head"):
    """Вырезанный знак-лист на маске: острый лист и прожилка, светится (emission)."""
    leaf = [(0.0, size), (size * 0.42, size * 0.25), (size * 0.36, -size * 0.25), (0.0, -size * 0.6),
            (-size * 0.36, -size * 0.25), (-size * 0.42, size * 0.25)]
    k.plate("SignLeaf", [(a * W, b * H) for a, b in leaf], 0.01 * W, at, (1, 0, 0), (0, 0.45, 1), M["sign"], bone)


def fur_mantle(M, big=1.0):
    """Бурая шкура на плечах (главное пятно силуэта сверху) с рваными клочьями по краю,
    и плащ из шкуры за спиной до икр (кость Cloak — колышется)."""
    k.sphere("Mantle", 0.28 * W * big, P(0, 0.035, 1.34), M["fur"], "Chest", scale=(1.2, 1.0, 0.48), segs=8, rings=4)
    k.sphere("MantleTop", 0.2 * W * big, P(0, 0.05, 1.41), M["fur_d"], "Chest", scale=(1.2, 1.0, 0.7), segs=7, rings=4)
    n = 15
    for i in range(n):   # клочья меха по краю — длинные и острые, висят вниз
        a = math.pi * (-0.12 + 1.24 * i / (n - 1))       # от груди справа через спину к груди слева
        x, y = -math.cos(a) * 0.33 * big, math.sin(a) * 0.25 * big + 0.03
        z = 1.3 + 0.03 * math.sin(i * 2.3)
        ln = 0.14 + 0.06 * ((i * 7) % 3) / 2
        k.limb(f"Tuft{i}", P(x * 0.9, y * 0.9, z + 0.03), P(x * 1.12, y * 1.15, z - ln),
               0.065 * W, 0.0, M["fur_d"] if i % 2 else M["fur"], "Chest", segs=4)
    for i, (x, y) in enumerate([(-0.24, 0.0), (0.26, 0.02), (-0.04, 0.2), (0.12, 0.2)]):   # клочья сверху
        k.limb(f"TuftTop{i}", P(x, y, 1.44), P(x * 1.3, y * 1.3, 1.53), 0.05 * W, 0.0, M["fur"], "Chest", segs=4)
    # Плащ: две половины чуть под углом, рваный низ
    cloak = [(0.0, 0.0), (0.27, 0.02), (0.31, -0.5), (0.25, -0.72), (0.18, -0.62), (0.1, -0.8), (0.02, -0.7)]
    for side, s in SIDES:
        pts = [(a * s * W, b * H) for a, b in cloak]
        k.plate(f"Cloak.{side}", pts, 0.045 * W, P(0, 0.2, 1.33), (1, 0.18 * s, 0), (0, 0.12, 1),
                M["fur"] if s < 0 else M["fur_d"], "Cloak")


def vines(M, count=3):
    """Живые побеги вьются по шкуре, на них листья."""
    paths = [
        [(-0.3, 0.02, 1.3), (-0.2, -0.13, 1.4), (-0.05, -0.18, 1.36), (0.08, -0.17, 1.42)],
        [(0.32, 0.0, 1.3), (0.24, 0.12, 1.42), (0.06, 0.2, 1.44), (-0.12, 0.2, 1.38)],
        [(-0.22, 0.2, 1.3), (-0.26, 0.24, 1.0), (-0.2, 0.25, 0.75)],
    ][:count]
    for j, pts in enumerate(paths):
        bone = "Cloak" if j == 2 else "Chest"
        pts = [P(*p) for p in pts]
        for i, (a, b) in enumerate(zip(pts, pts[1:])):
            k.limb(f"Vine{j}_{i}", a, b, 0.013 * W, 0.012 * W, M["vine"], bone, segs=4)
            leaf_at(M, f"Leaf{j}_{i}", b, bone, tilt=(i * 53 + j * 31) % 180)
            if DETAIL:
                mid = tuple((a[q] + b[q]) / 2 for q in range(3))
                leaf_at(M, f"LeafM{j}_{i}", mid, bone, tilt=(i * 71 + j * 17 + 90) % 180, size=0.07)


def leaf_at(M, name, at, bone, tilt=0, size=0.1):
    """Один листок: плоский ромбик, повёрнут на tilt градусов."""
    a = math.radians(tilt)
    u = (math.cos(a), math.sin(a), 0.4)
    v = (-math.sin(a) * 0.4, math.cos(a) * 0.4, 1.0)
    pts = [(0, 0), (size * 0.35, size * 0.5), (0, size), (-size * 0.35, size * 0.5)]
    k.plate(name, pts, 0.006, at, u, v, M["leaf"], bone)


# ---------- Скелет ----------

def bones(shoulder_r, elbow_r, wrist_r, shoulder_l, elbow_l, wrist_l, extra=None):
    """Общий скелет. Точки рук передаёт персонаж (у каждого своя хватка)."""
    def B(h, t, parent):
        return (P(*h), P(*t), parent)
    b = {
        "Root": B((0, 0, 0), (0, 0, 0.15), None),
        "Hips": B((0, 0, 0.86), (0, 0, 0.95), "Root"),
        "Spine": B((0, 0, 0.95), (0, 0, 1.18), "Hips"),
        "Chest": B((0, 0, 1.18), (0, 0, 1.4), "Spine"),
        "Head": B((0, 0, 1.4), (0, 0, 1.72), "Chest"),
        "Cloak": B((0, 0.2, 1.33), (0, 0.24, 0.6), "Chest"),
        "FlapF": B((0, -0.17, 0.9), (0, -0.18, 0.55), "Hips"),
        "FlapB": B((0, 0.17, 0.9), (0, 0.18, 0.55), "Hips"),
    }
    arms = {"R": (shoulder_r, elbow_r, wrist_r), "L": (shoulder_l, elbow_l, wrist_l)}
    for side, s in SIDES:
        sh, el, wr = arms[side]
        from mathutils import Vector
        hand_end = tuple(Vector(wr) + (Vector(wr) - Vector(el)).normalized() * 0.1 * W)
        b.update({
            f"UpperArm.{side}": (sh, el, "Chest"),
            f"ForeArm.{side}": (el, wr, f"UpperArm.{side}"),
            f"Hand.{side}": (wr, hand_end, f"ForeArm.{side}"),
            f"Thigh.{side}": B((0.12 * s, 0, 0.86), (0.12 * s, 0, 0.48), "Hips"),
            f"Shin.{side}": B((0.12 * s, 0, 0.48), (0.12 * s, 0, 0.09), f"Thigh.{side}"),
            f"Foot.{side}": B((0.12 * s, 0, 0.09), (0.12 * s, -0.15, 0.02), f"Shin.{side}"),
        })
    b.update(extra or {})
    return b


# ---------- Общие движения ----------
# Стойка ног: левая нога впереди, колени согнуты, корпус чуть развёрнут.
LEG_STANCE = {
    "Thigh.L": (-22, 0, -6), "Shin.L": (26, 0, 0), "Foot.L": (-2, 0, 0),
    "Thigh.R": (8, 0, 8), "Shin.R": (18, 0, 0), "Foot.R": (-24, 0, 0),
    "FlapF": (-8, 0, 0), "FlapB": (4, 0, 0), "Cloak": (6, 0, 0),
}
STANCE_LOC = {"Hips": (0, 0, -0.04)}


def idle_body(p, t):
    """Дыхание, перенос веса, накидка и полы. Возвращает (breath, sway) для рук и снаряжения."""
    breath = wave(t, 2)
    sway = wave(t, 1)
    p.move("Hips", x=0.014 * sway, z=-0.01 * (breath * 0.5 + 0.5))
    p.add("Hips", z=1.5 * sway)
    p.add("Thigh.L", z=-1.5 * sway).add("Thigh.R", z=-1.5 * sway)
    p.add("Spine", x=1.5 * breath, z=-1.2 * sway)
    p.add("Chest", x=2.5 * wave(t, 2, -0.06))
    p.add("Cloak", x=2 * wave(t, 1, -0.25), z=2 * wave(t, 1, 0.1))
    p.add("FlapF", x=2 * wave(t, 1, -0.2)).add("FlapB", x=2 * wave(t, 1, -0.3))
    return breath, sway


def walk_body(p, t):
    """Шаг (0.8 сек): ноги, таз, корпус навстречу ногам, накидка запаздывает. Возвращает фазу a."""
    a = wave(t, 1)
    c = wave(t, 1, 0.25)
    bounce = wave(t, 2, 0.08)
    p.move("Hips", z=-0.03 + 0.02 * bounce, x=0.014 * a)
    p.add("Hips", y=7 * a, z=3 * a)
    p.set("Thigh.R", -8 - 30 * a, 0, 4)
    p.set("Thigh.L", -8 + 30 * a, 0, -4)
    p.set("Shin.R", 16 + 34 * max(0.0, c) + 6 * a, 0, 0)
    p.set("Shin.L", 16 + 34 * max(0.0, -c) - 6 * a, 0, 0)
    p.set("Foot.R", 6 - 16 * a, 0, 0)
    p.set("Foot.L", 6 + 16 * a, 0, 0)
    p.add("Spine", x=5, y=-6 * a)
    p.add("Chest", y=-3 * a)
    p.add("Head", x=-2 * bounce, y=8 * a)
    p.set("FlapF", -8 - 14 * abs(a), 0, 0)
    p.set("FlapB", 12 + 8 * wave(t, 2, -0.12), 0, 0)
    p.set("Cloak", 14 + 6 * wave(t, 2, -0.15), 0, 5 * a)
    return a


def hit_body(p, t):
    """Получил удар (0.5 сек): корпус отбрасывает сразу, голова мотается позже, накидка взлетает."""
    snap = track(t, [(0, 0), (0.18, 1), (0.5, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.3), (0.34, 1), (0.6, -0.3), (0.82, 0.08), (1, 0)])
    p.move("Root", y=0.1 * snap)
    p.move("Hips", z=-0.03 * snap)
    p.add("Spine", x=-18 * snap, y=12 * snap)
    p.add("Chest", x=-10 * snap)
    p.add("Head", x=-24 * whip, y=-14 * snap, z=8 * whip)
    p.add("Thigh.L", x=16 * snap).add("Shin.L", x=-8 * snap)
    p.add("Thigh.R", x=-14 * snap).add("Shin.R", x=16 * snap)
    p.add("FlapF", x=-24 * whip).add("FlapB", x=-14 * whip)
    p.add("Cloak", x=-30 * whip)
    return snap, whip

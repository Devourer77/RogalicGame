# Собирает все иконки интерфейса в assets/icons/*.svg.
# Запуск:  python build_icons.py            (пишет в папку ..)
#          python build_icons.py out_dir    (пишет в out_dir)
#
# Правила набора:
#  - холст 64x64, файл рисуется 128x128 (чтобы не мылился при увеличении);
#  - иконка белая: цвет ей задаёт игра (UiKit.icon_rect(..., цвет));
#  - чёрным (K) рисуются «прорези» — на тёмных панелях они читаются как вырез;
#  - без текста, без градиентов и фильтров — только простые фигуры.
# Новая иконка: добавь строку в ICONS и запусти скрипт. Имя — это имя файла.
import math
import os
import sys

W = "#fff"
K = "#000"


def p(d, fill=W, op=1.0):
	return '<path d="%s" fill="%s"%s/>' % (d, fill, ' fill-opacity="%s"' % op if op < 1 else "")


def s(d, w=5, col=W, op=1.0):
	return ('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"%s/>'
			% (d, col, w, ' stroke-opacity="%s"' % op if op < 1 else ""))


def c(cx, cy, r, fill=W, op=1.0):
	return '<circle cx="%s" cy="%s" r="%s" fill="%s"%s/>' % (cx, cy, r, fill, ' fill-opacity="%s"' % op if op < 1 else "")


def ring(cx, cy, r, w=5, col=W):
	return '<circle cx="%s" cy="%s" r="%s" fill="none" stroke="%s" stroke-width="%s"/>' % (cx, cy, r, col, w)


def r(x, y, w, h, rx=0, fill=W, op=1.0):
	return '<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="%s"%s/>' % (
		x, y, w, h, rx, fill, ' fill-opacity="%s"' % op if op < 1 else "")


def poly(pts, fill=W, op=1.0):
	return '<polygon points="%s" fill="%s"%s/>' % (
		" ".join("%s,%s" % (round(x, 1), round(y, 1)) for x, y in pts), fill, ' fill-opacity="%s"' % op if op < 1 else "")


def g(inner, tf):
	return '<g transform="%s">%s</g>' % (tf, inner)


def mirror(inner):
	return g(inner, "translate(64 0) scale(-1 1)")


def star(cx, cy, r_out, r_in, n, rot=-90.0):
	pts = []
	for i in range(n * 2):
		a = math.radians(rot + i * 180.0 / n)
		rad = r_out if i % 2 == 0 else r_in
		pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
	return pts


# ---------- заготовки, из которых собираются несколько иконок ----------

SHIELD = "M32 5 L54 12 V30 C54 44 44 54 32 59 C20 54 10 44 10 30 V12Z"
DROP = "M32 5 C41 19 48 28 48 38 a16 16 0 0 1 -32 0 C16 28 23 19 32 5Z"
FLAME = "M32 4 C36 16 50 22 50 38 C50 50 42 60 32 60 C22 60 14 50 14 38 C14 30 18 26 22 20 C23 26 26 28 28 28 C26 18 28 10 32 4Z"
FLAME_IN = "M32 34 C36 40 40 43 40 49 C40 54 36 57 32 57 C28 57 24 54 24 49 C24 44 29 41 32 34Z"
BOOT = "M22 6 H40 V32 C46 34 56 38 56 48 V52 H14 V44 C18 40 22 36 22 30Z"
BOLT = [(38, 4), (14, 36), (29, 36), (24, 60), (50, 26), (35, 26)]
SWORD = (poly([(54, 4), (60, 4), (60, 10), (29, 41), (23, 35)]) + s("M16 30 L34 48", 6)
		+ s("M22 42 L11 53", 6) + c(9, 55, 4.5))
AXE = s("M16 57 L41 9", 5) + p("M37 10 C44 10 50 8 55 3 C63 12 63 24 58 33 C54 27 49 24 44 24Z")
ARROW_R = [(4, 24), (24, 24), (24, 12), (46, 32), (24, 52), (24, 40), (4, 40)]

ICONS = {}

# ---------- числа героя ----------
ICONS["heart"] = p("M32 56 C10 40 5 28 5 20 C5 11 12 6 20 6 C25 6 30 9 32 14 C34 9 39 6 44 6 C52 6 59 11 59 20 C59 28 54 40 32 56Z")
ICONS["shield"] = p(SHIELD) + p("M32 11 L48 16 V30 C48 40 41 48 32 52Z", K, 0.28)
ICONS["mana"] = poly([(32, 3), (51, 24), (32, 61), (13, 24)]) + s("M13 24 H51 M32 3 L24 24 L32 61 L40 24Z", 2, K, 0.55)
ICONS["boot"] = p(BOOT) + r(12, 54, 46, 6, 2)
ICONS["deck"] = s("M24 9 H48 a5 5 0 0 1 5 5 V48", 4) + r(10, 16, 34, 42, 5) + s("M18 26 H36 M18 34 H30", 3, K, 0.5)
ICONS["discard"] = r(16, 4, 32, 30, 4) + poly([(32, 60), (16, 42), (26, 42), (26, 36), (38, 36), (38, 42), (48, 42)])
ICONS["coin"] = c(32, 32, 26) + ring(32, 32, 18, 3, K) + poly([(32, 21), (40, 32), (32, 43), (24, 32)], K)
ICONS["rage"] = s("M24 7 C24 18 18 24 7 24 M40 7 C40 18 46 24 57 24 M24 57 C24 46 18 40 7 40 M40 57 C40 46 46 40 57 40", 6.5)
ICONS["momentum"] = "".join(
	poly([(x, 10), (x + 10, 10), (x + 22, 32), (x + 10, 54), (x, 54), (x + 12, 32)]) for x in (4, 20, 36))
ICONS["bolt"] = poly(BOLT)
ICONS["entangled"] = s("M12 58 C10 38 30 44 28 28 C27 18 16 18 18 27 M52 58 C54 40 36 46 38 30 C39 16 52 15 49 27 M32 58 V42", 5)
ICONS["discount"] = poly([(6, 34), (30, 10), (56, 10), (56, 36), (32, 60)]) + c(46, 20, 4.5, K) + s("M22 38 L36 38", 5, K)
ICONS["hourglass"] = (r(12, 4, 40, 7, 2) + r(12, 53, 40, 7, 2)
		+ s("M18 11 C18 24 29 27 29 32 C29 37 18 40 18 53 M46 11 C46 24 35 27 35 32 C35 37 46 40 46 53", 4)
		+ p("M22 53 C22 46 32 43 32 37 C32 43 42 46 42 53Z") + p("M24 16 H40 C38 22 34 24 32 27 C30 24 26 22 24 16Z"))
ICONS["taunt"] = p(SHIELD) + ring(32, 29, 12, 4, K) + c(32, 29, 4, K)
ICONS["star"] = poly(star(32, 34, 28, 11.5, 5, -90))
ICONS["target"] = ring(32, 32, 17, 5) + s("M32 4 V17 M32 47 V60 M4 32 H17 M47 32 H60", 5) + c(32, 32, 4)

# ---------- стихии ----------
ICONS["fire"] = p(FLAME) + p(FLAME_IN, K, 0.4)
ICONS["drop"] = p(DROP) + s("M24 38 a8 8 0 0 0 8 9", 3, K, 0.45)
ICONS["snow"] = (s("M32 5 V59 M8.6 18.5 L55.4 45.5 M8.6 45.5 L55.4 18.5", 5)
		+ s("M24 9 L32 16 L40 9 M24 55 L32 48 L40 55", 4))
ICONS["meteor"] = c(42, 42, 16) + s("M6 8 L28 30 M22 6 L37 22 M6 24 L22 38", 5) + c(38, 46, 4, K, 0.4) + c(47, 37, 3, K, 0.4)
ICONS["wave"] = p("M4 44 C12 44 14 30 26 22 C38 14 53 20 55 33 C50 26 42 26 38 32 C34 38 40 46 48 46 H60 V58 H4Z")
ICONS["flood"] = (p("M32 4 C39 15 44 22 44 30 a12 12 0 0 1 -24 0 C20 22 25 15 32 4Z")
		+ p("M6 53 a26 6 0 1 0 52 0 a26 6 0 1 0 -52 0Z") + s("M18 53 a14 3 0 0 0 28 0", 2, K, 0.5))
ICONS["drain"] = p(DROP) + s("M10 56 L54 8", 9, K) + s("M10 56 L54 8", 4)
ICONS["ice"] = poly([(52, 5), (59, 12), (22, 51), (7, 57), (13, 42)]) + s("M55 9 L12 52", 2, K, 0.5)
ICONS["ice_wall"] = (poly([(8, 58), (8, 32), (16, 20), (25, 32), (25, 58)]) + poly([(23, 58), (23, 20), (32, 5), (41, 20), (41, 58)])
		+ poly([(39, 58), (39, 34), (48, 23), (56, 34), (56, 58)])
		+ s("M23 22 V58 M41 22 V58 M32 5 V58 M16 20 V58 M48 23 V58", 1.6, K, 0.5))
ICONS["spark"] = poly([(32, 3), (38, 26), (61, 32), (38, 38), (32, 61), (26, 38), (3, 32), (26, 26)])
ICONS["chain"] = (s("M10 12 L27 23 L21 33 L42 40 L37 50 L54 55", 5) + c(10, 12, 6) + c(54, 55, 6) + ring(46, 18, 6, 4)
		+ ring(14, 48, 6, 4))
ICONS["orb"] = ring(32, 32, 23, 5) + poly([(35, 14), (21, 35), (30, 35), (27, 50), (43, 28), (34, 28)])
ICONS["rift"] = poly([(29, 3), (38, 3), (31, 19), (43, 24), (29, 41), (39, 46), (30, 61), (23, 61), (27, 48), (17, 43), (32, 26),
		(20, 21)]) + s("M10 14 L15 20 M52 44 L47 38 M54 12 L49 16 M10 52 L14 47", 3)
ICONS["focus"] = (p("M3 32 C14 15 24 11 32 11 C40 11 50 15 61 32 C50 49 40 53 32 53 C24 53 14 49 3 32Z") + c(32, 32, 12, K)
		+ c(32, 32, 5.5))
ICONS["overload"] = poly(BOLT) + s("M6 18 L13 23 M58 46 L51 41 M8 48 L15 44 M57 16 L50 21 M12 34 H5 M59 30 H52", 4)

# ---------- карты мага ----------
ICONS["wind"] = s("M5 22 H38 a8 8 0 1 0 -8 -8 M5 34 H50 a8 8 0 1 1 -8 8 M5 46 H26", 5)
ICONS["push"] = r(44, 12, 14, 40, 3) + poly([(4, 25), (20, 25), (20, 14), (40, 32), (20, 50), (20, 39), (4, 39)])
ICONS["dash"] = g(p(BOOT) + r(12, 54, 46, 6, 2), "translate(8 0)") + s("M4 14 H18 M3 28 H16 M4 42 H12", 4)
ICONS["reeds"] = (s("M20 59 V30 M32 59 V20 M44 59 V34", 3) + r(16, 12, 8, 20, 4) + r(28, 2, 8, 20, 4) + r(40, 16, 8, 20, 4)
		+ s("M26 59 C25 46 16 42 8 41 M38 59 C39 48 48 44 56 43", 3))
ICONS["transfer"] = (r(5, 40, 19, 19, 3) + s("M42 42 H56 V56 H42Z", 4) + s("M14 33 C14 10 49 10 49 26", 5)
		+ poly([(39, 24), (59, 24), (49, 37)]))
ICONS["swap"] = (poly([(5, 14), (40, 14), (40, 5), (59, 18), (40, 31), (40, 22), (5, 22)])
		+ poly([(59, 42), (24, 42), (24, 33), (5, 46), (24, 59), (24, 50), (59, 50)]))
_arm = s("M32 32 C30 18 42 8 56 14", 7)
ICONS["maw"] = _arm + g(_arm, "rotate(120 32 32)") + g(_arm, "rotate(240 32 32)") + c(32, 32, 7)
ICONS["staff"] = s("M10 57 L42 22", 5) + poly([(49, 2), (61, 14), (49, 26), (37, 14)]) + s("M49 2 L49 26 M37 14 H61", 1.6, K, 0.5)

# ---------- карты рыцаря ----------
ICONS["sword"] = SWORD
ICONS["swords"] = SWORD + mirror(SWORD)
ICONS["slash"] = p("M7 52 C4 24 26 4 58 7 C35 13 20 28 18 54Z") + s("M30 44 L52 22 M40 50 L56 34", 4)
ICONS["spear"] = s("M8 56 L44 20", 5) + poly([(61, 3), (38, 14), (50, 26)]) + s("M30 28 L36 34", 4)
ICONS["hammer"] = s("M12 55 L38 29", 6) + poly([(38.4, 3), (61, 25.6), (49.6, 37), (27, 14.4)])
ICONS["axe"] = AXE
ICONS["axes"] = AXE + mirror(AXE)
ICONS["blood"] = g(SWORD, "translate(-4 -2)") + p("M49 34 C53 42 58 46 58 51 a9 9 0 0 1 -18 0 C40 46 45 42 49 34Z")
ICONS["horn"] = (p("M6 47 C24 49 38 40 44 20 L60 27 C52 51 30 61 8 58Z") + s("M42 15 L62 24", 6) + c(7, 52.5, 4.5)
		+ s("M52 6 L54 2 M60 12 L63 9", 3))
ICONS["ram"] = r(49, 6, 9, 52, 2) + poly(ARROW_R)
ICONS["ram_through"] = (r(25, 3, 7, 15, 2) + r(25, 46, 7, 15, 2)
		+ poly([(3, 26), (38, 26), (38, 15), (61, 32), (38, 49), (38, 38), (3, 38)]))
ICONS["leap"] = s("M8 48 C10 12 42 8 48 34", 6) + poly([(37, 31), (59, 30), (50, 50)]) + s("M30 58 H60", 4)
ICONS["whirl"] = s("M32 11 A21 21 0 1 0 53 32", 6) + poly([(42, 33), (64, 33), (53, 17)]) + poly(star(32, 32, 10, 4, 4, -90))
ICONS["unstoppable"] = (poly([(19, 22), (38, 22), (38, 9), (61, 32), (38, 55), (38, 42), (19, 42)]) + r(3, 22, 5, 20, 2)
		+ r(11, 22, 5, 20, 2))
ICONS["shield_wall"] = (g(p(SHIELD), "translate(-2 6) scale(0.62)") + g(p(SHIELD), "translate(26 6) scale(0.62)")
		+ g(p(SHIELD) + s(SHIELD, 5, K), "translate(11 16) scale(0.66)"))
ICONS["tower"] = p("M14 59 V25 H9 V6 H19 V13 H27 V6 H37 V13 H45 V6 H55 V25 H50 V59Z") + p("M26 59 V45 a6 6 0 0 1 12 0 V59Z", K)
ICONS["hold"] = p(SHIELD) + s("M21 22 L32 32 L43 22 M21 34 L32 44 L43 34", 4.5, K)
ICONS["cover"] = (c(45, 17, 9) + p("M30 59 C30 41 36 31 45 31 C54 31 60 41 60 59Z")
		+ g(p(SHIELD) + s(SHIELD, 7, K), "translate(0 20) scale(0.62)") + g(p(SHIELD), "translate(0 20) scale(0.62)"))
ICONS["bell"] = (p("M32 4 a5 5 0 0 1 5 5 C47 13 51 25 51 38 L58 49 H6 L13 38 C13 25 17 13 27 9 a5 5 0 0 1 5 -5Z") + c(32, 55, 5.5)
		+ s("M16 40 H48", 2.5, K, 0.5))
ICONS["stakes"] = ("".join(poly([(x, 59), (x, 20), (x + 5.5, 5), (x + 11, 20), (x + 11, 59)]) for x in (6, 26.5, 47))
		+ r(3, 34, 58, 7, 2) + c(11.5, 37.5, 1.6, K) + c(32, 37.5, 1.6, K) + c(52.5, 37.5, 1.6, K))
ICONS["planks"] = ("".join(r(5, y, 54, 13, 2) for y in (8, 25.5, 43))
		+ "".join(c(x, y, 1.8, K) for x in (11, 53) for y in (14.5, 32, 49.5)))
ICONS["tree"] = s("M30 59 L33 28", 7) + s("M33 36 L49 20 M33 28 L22 8 M32 32 L15 27 M43 26 L55 27 M27 17 L35 8", 4)
ICONS["barrel"] = (p("M18 6 H46 C53 19 53 45 46 58 H18 C11 45 11 19 18 6Z") + s("M13 21 H51 M13 43 H51", 3, K)
		+ s("M32 26 V38", 4, K))
ICONS["outpost"] = ("".join(poly([(x, 59), (x, 36), (x + 6, 26), (x + 12, 36), (x + 12, 59)]) for x in (5, 26, 47))
		+ r(3, 43, 58, 6, 2) + s("M32 28 V5", 3) + poly([(32, 4), (50, 10), (32, 16)]))

# ---------- карта пути ----------
_horn = p("M17 27 C8 25 3 14 5 3 C9 12 16 15 24 17Z")
ICONS["elite"] = (p("M15 30 C15 18 23 12 32 12 C41 12 49 18 49 30 V44 L41 56 H23 L15 44Z") + _horn + mirror(_horn)
		+ poly([(21, 31), (30, 35), (22, 39)], K) + poly([(43, 31), (34, 35), (42, 39)], K) + s("M28 47 H36", 3, K))
ICONS["boss"] = p("M8 46 L3 14 L20 29 L32 6 L44 29 L61 14 L56 46Z") + r(8, 50, 48, 9, 2) + c(32, 37, 4, K)
ICONS["shop"] = (p("M22 21 C9 31 7 45 11 53 C15 61 49 61 53 53 C57 45 55 31 42 21Z")
		+ poly([(22, 18), (17, 5), (27, 10), (32, 4), (37, 10), (47, 5), (42, 18)]) + ring(32, 41, 8, 3.5, K))
ICONS["rest"] = (g(p(FLAME) + p(FLAME_IN, K, 0.4), "translate(8 -3) scale(0.75)") + s("M10 58 L54 47 M54 58 L10 47", 6))
ICONS["event"] = s("M19 21 C19 3 45 3 45 20 C45 31 32 30 32 42", 7.5) + c(32, 55, 5)
ICONS["battle"] = ICONS["swords"]

# ---------- намерения врагов и общие значки ----------
ICONS["arrow"] = s("M8 56 L48 16", 5) + poly([(59, 5), (36, 12), (52, 28)]) + s("M9 45 H19 V55 M17 37 H27 V47", 4)
ICONS["buff"] = (poly([(32, 4), (56, 28), (44, 28), (32, 16), (20, 28), (8, 28)])
		+ poly([(32, 30), (56, 54), (44, 54), (32, 42), (20, 54), (8, 54)]))
ICONS["mouse_l"] = s("M18 23 a14 14 0 0 1 28 0 V42 a14 14 0 0 1 -28 0Z", 4) + p("M30 9 C22 10 18 16 18 23 V28 H30Z")
ICONS["mouse_r"] = mirror(ICONS["mouse_l"])
ICONS["zoom"] = ring(27, 27, 17, 5) + s("M40 40 L57 57", 8)
ICONS["close"] = s("M14 14 L50 50 M50 14 L14 50", 8)
ICONS["rotate"] = s("M32 11 A21 21 0 1 0 53 32", 6) + poly([(42, 33), (64, 33), (53, 17)])
ICONS["help"] = ICONS["event"]
ICONS["mage"] = (p("M32 3 C46 9 52 25 52 40 L59 59 H5 L12 40 C12 25 18 9 32 3Z")
		+ p("M32 18 C40 22 43 32 41 44 H23 C21 32 24 22 32 18Z", K) + c(27.5, 32, 2.6) + c(36.5, 32, 2.6))
ICONS["knight"] = (p("M12 55 V28 C12 14 21 5 32 5 C43 5 52 14 52 28 V55 L40 60 H24Z") + r(18, 25, 28, 6, 1, K)
		+ r(30, 31, 4, 23, 1, K) + s("M32 5 V20", 3, K, 0.5))

# ---------- схемы областей (сетка 5x5): яркие клетки — куда попадёт, кружок — герой ----------
def shape(hit, hero=None, trail=(), ally=None):
	out = ""
	for y in range(5):
		for x in range(5):
			px, py = 3 + x * 12, 3 + y * 12
			if (x, y) in hit:
				out += r(px, py, 10, 10, 2)
			elif (x, y) in trail:
				out += r(px, py, 10, 10, 2, W, 0.5)
			else:
				out += r(px, py, 10, 10, 2, W, 0.16)
	for cell, solid in ((hero, False), (ally, True)):
		if cell is not None:
			cx, cy = 8 + cell[0] * 12, 8 + cell[1] * 12
			out += c(cx, cy, 5.5, K) + (c(cx, cy, 4) if solid else ring(cx, cy, 3.2, 2.2))
	return out


ICONS["shape_self"] = shape((), ally=(2, 2))
ICONS["shape_single"] = shape({(2, 1)}, hero=(2, 4))
ICONS["shape_line"] = shape({(2, 0), (2, 1), (2, 2), (2, 3)}, hero=(2, 4))
ICONS["shape_cross"] = shape({(2, 2), (1, 2), (3, 2), (2, 1), (2, 3)})
ICONS["shape_square"] = shape({(x, y) for x in (1, 2, 3) for y in (1, 2, 3)})
ICONS["shape_arc"] = shape({(1, 2), (2, 2), (3, 2)}, hero=(2, 3))
ICONS["shape_charge"] = shape({(2, 0)}, hero=(2, 4), trail={(2, 1), (2, 2), (2, 3)})
ICONS["shape_ally"] = shape((), hero=(1, 3), ally=(3, 1))
ICONS["shape_wall"] = shape({(1, 1), (2, 1), (3, 1)}, hero=(2, 4))
ICONS["shape_leap"] = shape({(2, 1), (1, 1), (3, 1), (2, 0), (2, 2)}, hero=(2, 4), trail={(2, 3)})
ICONS["shape_around"] = shape({(x, y) for x in (1, 2, 3) for y in (1, 2, 3)} - {(2, 2)}, hero=(2, 2))
ICONS["shape_fell"] = shape({(2, 0), (2, 1), (2, 2)}, hero=(2, 4), trail={(2, 3)})


def main():
	out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
	os.makedirs(out_dir, exist_ok=True)
	for name, body in ICONS.items():
		svg = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64">%s</svg>\n' % body
		with open(os.path.join(out_dir, name + ".svg"), "w", encoding="utf-8", newline="\n") as f:
			f.write(svg)
	print("иконок:", len(ICONS))


if __name__ == "__main__":
	main()

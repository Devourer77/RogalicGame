# Текстуры для частиц и эффектов боя (ТЗ: claude/тз-эффекты.md).
# Все картинки белые (цвет частицам задаёт код), прозрачность — в альфа-канале.
# Запуск из корня проекта:  python assets/textures/src/build_vfx_textures.py
# Нужны библиотеки numpy и Pillow (pip install numpy pillow).
import os

import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "vfx")
RNG = np.random.default_rng(7)   # один сид — картинки всегда одинаковые


def save(name: str, alpha: np.ndarray) -> None:
	"""Сохраняет белую картинку с прозрачностью alpha (0..1)."""
	a = (np.clip(alpha, 0.0, 1.0) * 255).astype(np.uint8)
	white = np.full_like(a, 255)
	Image.fromarray(np.dstack([white, white, white, a]), "RGBA").save(os.path.join(OUT, name + ".png"))
	print("saved", name)


def grid(size: int):
	"""Координаты от -1 до 1 по каждой оси."""
	v = (np.arange(size) + 0.5) / size * 2.0 - 1.0
	return np.meshgrid(v, v)


def value_noise(size: int, cells: int, seed: int) -> np.ndarray:
	"""Плавный бесшовный шум: случайная сетка cells×cells, сглаженная между узлами."""
	rng = np.random.default_rng(seed)
	g = rng.random((cells, cells))
	t = np.arange(size) / size * cells
	i0 = np.floor(t).astype(int) % cells
	i1 = (i0 + 1) % cells
	f = t - np.floor(t)
	f = f * f * (3 - 2 * f)
	fy, fx = np.meshgrid(f, f, indexing="ij")
	y0, x0 = np.meshgrid(i0, i0, indexing="ij")
	y1, x1 = np.meshgrid(i1, i1, indexing="ij")
	a = g[y0, x0] * (1 - fx) + g[y0, x1] * fx
	b = g[y1, x0] * (1 - fx) + g[y1, x1] * fx
	return a * (1 - fy) + b * fy


def fbm(size: int, seed: int, octaves: int = 4, base: int = 4) -> np.ndarray:
	"""Несколько слоёв шума разного масштаба — «облачная» текстура."""
	out = np.zeros((size, size))
	amp, total = 1.0, 0.0
	for o in range(octaves):
		out += value_noise(size, base * 2 ** o, seed + o) * amp
		total += amp
		amp *= 0.5
	return out / total


# 1. Мягкое пятно — основа для свечения, огоньков, пыли
def soft_dot() -> None:
	x, y = grid(64)
	r = np.sqrt(x * x + y * y)
	save("soft_dot", np.exp(-r * r * 4.5) * (r < 1.0))


# 2. Искра — вытянутая черта с ярким центром (частица вытягивается по скорости)
def spark() -> None:
	x, y = grid(64)
	core = np.exp(-(x * x) * 60.0) * np.clip(1.0 - np.abs(y), 0.0, 1.0) ** 1.5
	save("spark", core)


# 3. Звёздочка-блик — четыре луча (лечение, блеск, искра кристалла мага)
def glint() -> None:
	x, y = grid(64)
	r = np.sqrt(x * x + y * y)
	rays = np.exp(-np.abs(x) * 28.0) * np.clip(1 - np.abs(y), 0, 1) + np.exp(-np.abs(y) * 28.0) * np.clip(1 - np.abs(x), 0, 1)
	save("glint", np.clip(rays * 0.9 + np.exp(-r * r * 30.0), 0.0, 1.0))


# 4. Кольцо ударной волны — тонкое, мягкие края
def ring() -> None:
	x, y = grid(128)
	r = np.sqrt(x * x + y * y)
	band = np.exp(-((r - 0.82) ** 2) / 0.004)
	inner = np.exp(-((r - 0.82) ** 2) / 0.03) * (r < 0.82) * 0.35   # лёгкий шлейф внутрь
	save("ring", np.clip(band + inner, 0.0, 1.0) * (r < 1.0))


# 5. Клуб дыма / пыли — лист 4×4 кадра: клуб разрастается, рвётся и тает
def smoke_sheet() -> None:
	cell = 128
	sheet = np.zeros((cell * 4, cell * 4))
	x, y = grid(cell)
	r = np.sqrt(x * x + y * y)
	n = fbm(cell, 11, octaves=5, base=3)
	n2 = fbm(cell, 23, octaves=4, base=5)
	for f in range(16):
		t = f / 15.0
		radius = 0.72 + 0.26 * t
		turb = n * 0.65 + n2 * 0.35
		lumpy = r + (turb - 0.45) * 0.55   # шум «мнёт» край клуба
		shape = np.clip(1.0 - (lumpy / radius) ** 2, 0.0, 1.0)
		cut = 0.15 + 0.6 * t   # чем дальше, тем больше «дыр»
		a = np.clip((shape * (0.7 + turb * 0.6) - cut * turb) * 2.0, 0.0, 1.0) * (1.0 - t * 0.5)
		row, col = divmod(f, 4)
		sheet[row * cell:(row + 1) * cell, col * cell:(col + 1) * cell] = a
	save("smoke_sheet", sheet)


# 6. Осколок / щепка — неровный треугольник (каменная крошка, щепки, осколки щита)
def shard() -> None:
	x, y = grid(64)
	# Треугольник с вершиной сверху и неровными краями
	edge = 0.85 - np.abs(x) * 1.6 - (1.0 - (y + 1.0) / 2.0) * 0.0
	tri = (y > -0.8) & (np.abs(x) < (y + 0.8) * 0.55) & (y < 0.85)
	rough = value_noise(64, 8, 5) * 0.3
	a = tri * np.clip(1.0 - rough, 0, 1)
	save("shard", a.astype(float))


# 7. Капля / брызга — вытянутая капля с хвостиком
def drop() -> None:
	x, y = grid(64)
	head = np.exp(-((x * x) / 0.08 + ((y + 0.35) ** 2) / 0.08))
	tail = np.exp(-(x * x) / 0.012) * np.clip((y + 0.35) / 1.2, 0, 1) * (y > -0.35)
	save("drop", np.clip(head + tail * 0.7, 0, 1))


# 8. Хлопья пепла — рваное пятно (смерть культистов)
def ash() -> None:
	x, y = grid(64)
	r = np.sqrt(x * x + y * y)
	n = value_noise(64, 6, 31)
	save("ash", np.clip((0.7 - r) * 3.0 + (n - 0.5) * 1.2, 0, 1) * (r < 0.9))


# 9. Язык пламени — лист 4×4 кадра: язык вытягивается вверх, колышется и тает.
#    Внизу плотнее и ярче, вверху рвётся на отдельные «лоскуты».
def flame_sheet() -> None:
	cell = 128
	sheet = np.zeros((cell * 4, cell * 4))
	x, y = grid(cell)          # y: -1 сверху, 1 снизу
	up = (1.0 - y) / 2.0       # 0 внизу, 1 вверху
	n1 = fbm(cell, 41, octaves=4, base=3)
	n2 = fbm(cell, 57, octaves=4, base=5)
	for f in range(16):
		t = f / 15.0
		# Колыхание: язык гнётся вбок синусом по высоте, фаза меняется от кадра к кадру
		sway = np.sin(up * 3.2 + t * 6.28) * 0.28 * up + (n1 - 0.5) * 0.25 * up
		width = (0.62 - 0.55 * up) * (1.0 - 0.35 * t)   # к верху уже, к концу жизни тоньше
		shape = np.clip(1.0 - np.abs(x - sway) / np.maximum(width, 0.02), 0.0, 1.0)
		base = np.clip((0.98 - y) * 5.0, 0.0, 1.0)       # мягкий низ
		top = np.clip(1.0 - up / (0.95 - 0.3 * t), 0.0, 1.0)
		turb = np.roll(n1, int(t * 40), axis=0) * 0.6 + np.roll(n2, int(t * 70), axis=0) * 0.4
		a = shape ** 0.7 * base * top
		a = np.clip(a * (0.6 + turb) - (up * 0.55 + t * 0.25) * (1.0 - turb), 0.0, 1.0)
		row, col = divmod(f, 4)
		sheet[row * cell:(row + 1) * cell, col * cell:(col + 1) * cell] = np.clip(a * 1.5, 0, 1)
	save("flame_sheet", sheet)


# 10. Выжженное пятно для декали после взрыва — тёмное, с рваным краем (цветная картинка)
def scorch() -> None:
	size = 128
	x, y = grid(size)
	r = np.sqrt(x * x + y * y)
	n = fbm(size, 71, octaves=5, base=4)
	edge = r + (n - 0.5) * 0.45
	a = np.clip((0.85 - edge) * 3.0, 0.0, 1.0) * 0.9
	# Внутри темнее и с бурыми прожилками, к краю — копоть светлеет
	dark = np.clip(0.06 + n * 0.12 + r * 0.08, 0, 1)
	rgb = np.dstack([dark * 1.1, dark * 0.95, dark * 0.8])
	img = np.dstack([(np.clip(rgb, 0, 1) * 255).astype(np.uint8), (a * 255).astype(np.uint8)])
	Image.fromarray(img, "RGBA").save(os.path.join(OUT, "scorch.png"))
	print("saved scorch")


if __name__ == "__main__":
	os.makedirs(OUT, exist_ok=True)
	soft_dot()
	spark()
	glint()
	ring()
	smoke_sheet()
	shard()
	drop()
	ash()
	flame_sheet()
	scorch()

# Текстуры хаба «Застава Колокола».
# Все текстуры бесшовные (повторяются без видимого стыка) и рисуются из шума,
# поэтому их можно перегенерировать с другими цветами одной командой:
#   python build_hub_textures.py <папка_вывода>
# Для каждой текстуры пишется цвет (<имя>.png) и карта нормалей (<имя>_n.png) —
# она даёт рельеф при свете костра и фонарей без лишних полигонов.
# Палитра — из мир.md: тёмно-бурая земля, мох, серый камень, старое дерево. Красного нет.

import sys
from pathlib import Path

import numpy as np
from PIL import Image

RNG = np.random.default_rng(7)


# --- Шум --------------------------------------------------------------------------------

def noise(size: int, scale: float, rng=RNG) -> np.ndarray:
    """Бесшовный плавный шум 0..1. scale — размер пятен в долях текстуры."""
    white = rng.standard_normal((size, size))
    f = np.fft.fftfreq(size)
    fx, fy = np.meshgrid(f, f)
    r = np.sqrt(fx * fx + fy * fy)
    filt = np.exp(-(r * scale * size / 4.0) ** 2 * 4.0)
    return _norm(np.real(np.fft.ifft2(np.fft.fft2(white) * filt)))


def _norm(x: np.ndarray) -> np.ndarray:
    """Приводит шум к 0..1 по разбросу (а не по крайним значениям): так пятна контрастнее."""
    x = (x - x.mean()) / max(x.std(), 1e-9)
    return np.clip(x * 0.2 + 0.5, 0.0, 1.0)


def fbm(size: int, base: float, octaves: int = 4) -> np.ndarray:
    """Несколько слоёв шума: крупные пятна + мелкая зернистость."""
    total = np.zeros((size, size))
    amp, norm, s = 1.0, 0.0, base
    for _ in range(octaves):
        total += noise(size, s) * amp
        norm += amp
        amp *= 0.5
        s *= 0.5
    return _norm(total)


def stretch_noise(size: int, sx: float, sy: float) -> np.ndarray:
    """Вытянутый шум (волокна дерева): sx, sy — размер пятен по осям."""
    white = RNG.standard_normal((size, size))
    f = np.fft.fftfreq(size)
    fx, fy = np.meshgrid(f, f)
    filt = np.exp(-((fx * sx * size) ** 2 + (fy * sy * size) ** 2))
    return _norm(np.real(np.fft.ifft2(np.fft.fft2(white) * filt)))


def cells(size: int, count: int, rng=RNG):
    """Бесшовные ячейки Вороного: расстояние до ближайшей и второй точки, номер ячейки."""
    pts = rng.random((count, 2)) * size
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    d1 = np.full((size, size), 1e9, np.float32)
    d2 = np.full((size, size), 1e9, np.float32)
    idx = np.zeros((size, size), np.int32)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(xx - px)
        dy = np.abs(yy - py)
        dx = np.minimum(dx, size - dx)   # расстояние «через край» — так ячейки бесшовные
        dy = np.minimum(dy, size - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d))
        idx = np.where(closer, i, idx)
        d1 = np.where(closer, d, d1)
    return d1, d2, idx


# --- Цвет и запись ---------------------------------------------------------------------

def c(r: float, g: float, b: float) -> np.ndarray:
    return np.array([r, g, b], np.float32)


def mix(a, b, t):
    t = np.clip(t, 0.0, 1.0)[..., None]
    return a * (1.0 - t) + b * t


def smooth(edge0: float, edge1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def normal_map(height: np.ndarray, strength: float) -> np.ndarray:
    """Карта нормалей из карты высот (бесшовно, через сдвиг массива)."""
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * strength
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * strength
    n = np.stack([-dx, dy, np.ones_like(height)], -1)   # Y вверх, как ждёт Godot
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def save(out: Path, name: str, rgb: np.ndarray, height: np.ndarray, strength: float) -> None:
    img = (np.clip(rgb, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    Image.fromarray(img, "RGB").save(out / f"{name}.png", optimize=True)
    nrm = (normal_map(height, strength) * 255.0 + 0.5).astype(np.uint8)
    Image.fromarray(nrm, "RGB").save(out / f"{name}_n.png", optimize=True)
    print(f"{name}: средний цвет {np.round(rgb.reshape(-1, 3).mean(0), 3)}")


# --- Текстуры --------------------------------------------------------------------------

def ground(out: Path) -> None:
    """Утоптанная земля заставы: бурая, с пятнами мха, камешками и тёмными сырыми местами."""
    s = 1024
    big = fbm(s, 0.5, 5)
    fine = noise(s, 0.008)
    moss_mask = smooth(0.58, 0.7, fbm(s, 0.4, 4) * 0.85 + noise(s, 0.02) * 0.15)
    damp = smooth(0.5, 0.85, noise(s, 0.7))
    earth = mix(c(0.16, 0.135, 0.1), c(0.28, 0.24, 0.17), big * 0.75 + fine * 0.25)
    earth = mix(earth, c(0.12, 0.105, 0.085), damp * 0.45)   # сырые тёмные места
    moss = mix(c(0.14, 0.18, 0.1), c(0.2, 0.25, 0.13), noise(s, 0.015))
    rgb = mix(earth, moss, moss_mask)
    # Камешки: мелкие светлые ячейки, видны только там, где нет мха
    d1, d2, idx = cells(s, 1400)
    keep = RNG.random(1400)[idx] > 0.7
    size = RNG.uniform(2.5, 6.0, 1400)[idx]
    pebble = smooth(size, size * 0.5, d1) * keep * (1.0 - moss_mask)
    shade = (RNG.random(1400)[idx] * 0.1)[..., None]
    rgb = mix(rgb, c(0.3, 0.29, 0.26) + shade, pebble * 0.85)
    height = big * 0.5 + fine * 0.3 + pebble * 0.5 + moss_mask * 0.15
    save(out, "hub_ground", rgb, height, 3.0)


def planks(out: Path) -> None:
    """Доски гати: идут поперёк тропы (вдоль X), серо-бурые, с тёмными щелями и мхом в щелях."""
    s = 512
    yy, xx = np.mgrid[0:s, 0:s]
    # 6 досок на текстуру, у каждой своя ширина, тон и место стыка
    n = 6
    widths = RNG.uniform(0.8, 1.2, n)
    edges = np.concatenate([[0], np.cumsum(widths / widths.sum() * s)])
    board = np.clip(np.searchsorted(edges, yy, side="right") - 1, 0, n - 1)
    edge_dist = np.minimum(yy - edges[board], edges[board + 1] - yy)
    gap = smooth(5.0, 1.5, edge_dist + noise(s, 0.02) * 3.0)
    cut = RNG.uniform(0, s, n)[board]
    cx = np.abs(xx - cut)
    cx = np.minimum(cx, s - cx)
    gap = np.maximum(gap, smooth(3.5, 1.0, cx))
    grain = stretch_noise(s, 0.25, 0.006)          # волокна вдоль доски (по X)
    tone = RNG.uniform(0.0, 1.0, n)[board]
    wood = mix(c(0.19, 0.155, 0.11), c(0.33, 0.29, 0.22), tone * 0.45 + grain * 0.55)
    wood = mix(wood, c(0.14, 0.12, 0.09), smooth(0.5, 0.85, noise(s, 0.5)) * 0.4)    # мокрые пятна
    moss = smooth(12.0, 3.0, edge_dist) * smooth(0.5, 0.65, noise(s, 0.08))
    rgb = mix(wood, c(0.16, 0.22, 0.11), moss * 0.8)
    rgb = mix(rgb, c(0.05, 0.045, 0.035), gap)
    bevel = smooth(14.0, 3.0, edge_dist)
    height = (1.0 - gap) * 0.8 + grain * 0.25 - bevel * 0.2
    save(out, "hub_planks", rgb, height, 4.0)


def stone(out: Path) -> None:
    """Дикий камень (площадка колокола, кольцо костра, стоячие камни): серые грани
    разного тона — как сколы, под low-poly; лишайник и трещины по стыкам граней."""
    s = 512
    d1, d2, idx = cells(s, 32)
    facet = RNG.uniform(0.0, 1.0, 32)[idx]          # у каждой грани свой ровный тон
    big = fbm(s, 0.35, 4)
    grit = noise(s, 0.008)
    rgb = mix(c(0.2, 0.215, 0.215), c(0.34, 0.35, 0.345), facet * 0.35 + big * 0.45 + grit * 0.2)
    seam = smooth(3.0, 0.5, d2 - d1)
    crack = seam * smooth(0.45, 0.6, noise(s, 0.12))
    lichen = smooth(0.62, 0.72, fbm(s, 0.15, 3)) * (1.0 - seam)
    rgb = mix(rgb, c(0.24, 0.28, 0.2), lichen * 0.5)   # серо-зелёный лишайник
    rgb = rgb * (1.0 - seam[..., None] * 0.12)
    rgb = mix(rgb, c(0.13, 0.14, 0.14), crack * 0.85)
    height = facet * 0.5 + big * 0.3 + grit * 0.1 - seam * 0.2 - crack * 0.3
    save(out, "hub_stone", rgb, height, 3.0)


def masonry(out: Path) -> None:
    """Кладка Караульни: ряды неровных серых блоков разной длины, тёмные швы, мох в швах."""
    s = 512
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    rows = 5
    heights = RNG.uniform(0.8, 1.2, rows)
    row_edges = np.concatenate([[0], np.cumsum(heights / heights.sum() * s)])
    row = np.clip(np.searchsorted(row_edges, yy, side="right") - 1, 0, rows - 1)
    vy = np.minimum(yy - row_edges[row], row_edges[row + 1] - yy)
    # В каждом ряду свои стыки блоков (2–4 блока на ряд)
    vx = np.full((s, s), 1e9, np.float32)
    block_id = np.zeros((s, s), np.int32)
    for r in range(rows):
        k = int(RNG.integers(2, 5))
        # Стыки примерно равномерно, со сдвигом — без узких «щепок»
        cuts = (np.arange(k) + RNG.uniform(-0.2, 0.2, k)) * s / k + RNG.uniform(0, s)
        cuts = np.sort(cuts % s)
        m = row == r
        x = xx[m]
        dist = np.full(x.shape, 1e9, np.float32)
        bid = np.zeros(x.shape, np.int32)
        for j, cpos in enumerate(cuts):
            d = np.abs(x - cpos)
            d = np.minimum(d, s - d)
            dist = np.minimum(dist, d)
            bid += (x >= cpos).astype(np.int32)
        vx[m] = dist
        block_id[m] = r * 8 + bid % k
    edge = np.minimum(vx, vy) + noise(s, 0.03) * 6.0 - 3.0   # неровные края
    mortar = smooth(5.0, 2.0, edge)
    tone = RNG.uniform(0.0, 1.0, rows * 8)[block_id]
    surface = fbm(s, 0.2, 4)
    rgb = mix(c(0.23, 0.245, 0.245), c(0.38, 0.39, 0.38), tone * 0.5 + surface * 0.5)
    bevel = smooth(16.0, 4.0, edge)   # края блоков темнее — выглядят объёмнее
    rgb = rgb * (1.0 - bevel[..., None] * 0.2)
    moss = smooth(14.0, 3.0, edge) * smooth(0.5, 0.68, noise(s, 0.1))
    rgb = mix(rgb, c(0.17, 0.23, 0.12), moss * 0.75)
    rgb = mix(rgb, c(0.11, 0.11, 0.1), mortar)
    height = (1.0 - mortar) * 0.7 + surface * 0.25 - bevel * 0.2
    save(out, "hub_masonry", rgb, height, 4.0)


def wood(out: Path) -> None:
    """Тёмное дерево (столбы, рама колокола, скамьи, дверь, полка): волокна вдоль Y и сучки."""
    s = 512
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    warp = noise(s, 0.15) * 30.0
    grain = stretch_noise(s, 0.006, 0.3)                       # длинные волокна вдоль Y
    rings = np.sin((xx + warp) / s * np.pi * 2.0 * 14.0) * 0.5 + 0.5   # годовые слои
    tone = noise(s, 0.3)
    rgb = mix(c(0.17, 0.12, 0.08), c(0.32, 0.235, 0.16), grain * 0.5 + rings * 0.2 + tone * 0.3)
    # Сучки — вытянутые вдоль волокон тёмные пятна
    knot = np.zeros((s, s), np.float32)
    for _ in range(3):
        kx, ky = RNG.uniform(0, s, 2)
        dx = np.abs(xx - kx)
        dx = np.minimum(dx, s - dx)
        dy = np.abs(yy - ky)
        dy = np.minimum(dy, s - dy)
        d = np.sqrt((dx / 1.0) ** 2 + (dy / 2.2) ** 2)
        knot = np.maximum(knot, smooth(14.0, 5.0, d))
    rgb = mix(rgb, c(0.12, 0.075, 0.045), knot * 0.9)
    rgb = mix(rgb, c(0.26, 0.23, 0.19), smooth(0.65, 0.8, noise(s, 0.2)) * 0.3)   # выцветшие места
    height = grain * 0.5 + rings * 0.3 - knot * 0.4
    save(out, "hub_wood", rgb, height, 3.0)


def turf(out: Path) -> None:
    """Дёрн и мох на крыше Караульни: тёмная зелень с бурыми проплешинами."""
    s = 512
    big = fbm(s, 0.3, 4)
    tufts = noise(s, 0.012)
    bare = smooth(0.6, 0.75, noise(s, 0.3))
    rgb = mix(c(0.13, 0.19, 0.1), c(0.26, 0.33, 0.17), big * 0.6 + tufts * 0.4)
    rgb = mix(rgb, c(0.2, 0.17, 0.12), bare * 0.6)
    height = big * 0.4 + tufts * 0.6
    save(out, "hub_turf", rgb, height, 4.0)


def water(out: Path) -> None:
    """Стоячая вода вокруг заставы: почти чёрная бирюзово-серая, с ряской и рябью."""
    s = 512
    ripple = stretch_noise(s, 0.02, 0.006)
    duckweed = smooth(0.74, 0.84, fbm(s, 0.3, 3))
    rgb = mix(c(0.05, 0.085, 0.085), c(0.09, 0.13, 0.12), ripple)
    rgb = mix(rgb, c(0.13, 0.17, 0.09), duckweed * 0.6)
    height = ripple * 0.5 + duckweed * 0.3
    save(out, "hub_water", rgb, height, 1.5)


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    out.mkdir(parents=True, exist_ok=True)
    for build in (ground, planks, stone, masonry, wood, turf, water):
        build(out)


if __name__ == "__main__":
    main()

"""Текстуры «книги» экрана события: пергамент страницы и тёмная кожа обложки.
Запуск: python3 assets/textures/ui/src/build_book.py — пишет parchment.jpg и leather.jpg в assets/textures/ui/."""
import os
import numpy as np
from PIL import Image, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..")
rng = np.random.default_rng(7)


def noise(w, h, scale):
    """Мягкий шум: случайная сетка, растянутая до размера."""
    small = rng.random((max(2, h // scale), max(2, w // scale)))
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255.0


def fbm(w, h):
    return 0.45 * noise(w, h, 160) + 0.3 * noise(w, h, 48) + 0.17 * noise(w, h, 12) + 0.08 * noise(w, h, 3)


def parchment(w=1024, h=1280):
    n = fbm(w, h)
    base = np.array([214, 194, 154], np.float32)   # тёплый пергамент
    dark = np.array([150, 118, 78], np.float32)
    t = np.clip((n - 0.35) * 1.3, 0, 1)[..., None] * 0.45
    img = base * (1 - t) + dark * t
    # пятна
    stains = np.clip(noise(w, h, 90) - 0.72, 0, 1)[..., None] * 1.6
    img = img * (1 - stains * 0.35)
    # потемнение к краям страницы
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.minimum.reduce([xx / w, (w - xx) / w, yy / h, (h - yy) / h])
    edge = np.clip(1 - d / 0.09, 0, 1) ** 2
    img = img * (1 - edge[..., None] * 0.45)
    img += (rng.random((h, w, 1)) - 0.5) * 6   # зерно бумаги
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(os.path.join(OUT, "parchment.jpg"), quality=90)


def leather(w=1024, h=1024):
    n = fbm(w, h)
    grain = np.asarray(Image.fromarray((rng.random((h, w)) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255
    base = np.array([44, 31, 23], np.float32)
    img = base * (0.75 + 0.45 * n[..., None]) * (0.9 + 0.2 * grain[..., None])
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(os.path.join(OUT, "leather.jpg"), quality=90)


parchment()
leather()
print("ok")

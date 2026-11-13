# Генерирует все звуковые эффекты игры в assets/sounds/*.wav.
# Запуск:  python build_sounds.py            (пишет в папку ..)
#          python build_sounds.py out_dir    (пишет в out_dir)
#
# Формат: WAV, 16-бит PCM, моно, 22050 Гц.
# Любой файл в assets/sounds/ можно в любой момент заменить своим .wav или .ogg с тем же именем.
import math
import os
import random
import struct
import sys
import wave

RATE = 22050
TWO_PI = 2.0 * math.pi


def clamp(x, lo=-1.0, hi=1.0):
	return lo if x < lo else (hi if x > hi else x)


def env_ad(t, dur, attack=0.008, decay_pow=1.8):
	"""Огибающая: быстрый вход (attack) и плавное затухание к концу (dur)."""
	if t < 0.0 or t >= dur:
		return 0.0
	if t < attack:
		return t / attack
	rem = 1.0 - (t - attack) / max(dur - attack, 0.0001)
	return max(0.0, rem) ** decay_pow


def lowpass(samples, alpha):
	"""Простой сглаживающий фильтр нижних частот (убирает резкий «песок» из шума)."""
	out = []
	prev = 0.0
	for s in samples:
		prev = prev + alpha * (s - prev)
		out.append(prev)
	return out


def make_noise(n, seed=42):
	rng = random.Random(seed)
	return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def save_wav(path, samples, volume=0.85):
	peak = max((abs(s) for s in samples), default=1.0)
	if peak < 1e-6:
		peak = 1.0
	scale = (volume / peak) * 32767.0
	data = bytearray()
	for s in samples:
		val = int(clamp(s * scale, -32767.0, 32767.0))
		data.extend(struct.pack("<h", val))
	with wave.open(path, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(RATE)
		w.writeframes(bytes(data))


# ---------- Рецепты звуков ----------

def snd_ui_click():
	"""Короткий тёплый щелчок латунной кнопки."""
	dur = 0.055
	n = int(RATE * dur)
	noise = lowpass(make_noise(n, 1), 0.35)
	out = []
	phase = 0.0
	for i in range(n):
		t = i / RATE
		freq = 720.0 - 420.0 * (t / dur)
		phase += TWO_PI * freq / RATE
		tone = math.sin(phase) * 0.75 + math.sin(phase * 2.4) * 0.25
		click = noise[i] * env_ad(t, 0.015, 0.001, 2.5) * 0.5
		out.append((tone * env_ad(t, dur, 0.002, 2.4) + click))
	return out, 0.65


def snd_ui_hover():
	"""Очень тихий мягкий шелест при наведении на карту."""
	dur = 0.04
	n = int(RATE * dur)
	noise = lowpass(make_noise(n, 2), 0.25)
	out = []
	phase = 0.0
	for i in range(n):
		t = i / RATE
		freq = 480.0 + 220.0 * (t / dur)
		phase += TWO_PI * freq / RATE
		s = math.sin(phase) * 0.4 + noise[i] * 0.6
		out.append(s * env_ad(t, dur, 0.005, 2.2))
	return out, 0.32


def snd_card_select():
	"""Взятие карты в руку / прицел: шелест плотной бумаги и лёгкий тон."""
	dur = 0.09
	n = int(RATE * dur)
	noise = lowpass(make_noise(n, 3), 0.38)
	out = []
	phase = 0.0
	for i in range(n):
		t = i / RATE
		freq = 360.0 + 380.0 * (t / dur)
		phase += TWO_PI * freq / RATE
		swish = noise[i] * math.sin(math.pi * t / dur) * 0.65
		tone = math.sin(phase) * env_ad(t, dur, 0.008, 1.8) * 0.55
		out.append(swish + tone)
	return out, 0.6


def snd_card_cancel():
	"""Отмена выбора карты: мягкий нисходящий тон."""
	dur = 0.08
	n = int(RATE * dur)
	out = []
	phase = 0.0
	for i in range(n):
		t = i / RATE
		freq = 520.0 - 240.0 * (t / dur)
		phase += TWO_PI * freq / RATE
		out.append(math.sin(phase) * env_ad(t, dur, 0.005, 2.0))
	return out, 0.48


def snd_card_play():
	"""Розыгрыш карты: плотный взмах и магический акцент."""
	dur = 0.16
	n = int(RATE * dur)
	noise = lowpass(make_noise(n, 4), 0.3)
	out = []
	phase = 0.0
	for i in range(n):
		t = i / RATE
		freq = 280.0 + 460.0 * ((t / dur) ** 0.7)
		phase += TWO_PI * freq / RATE
		whoosh = noise[i] * env_ad(t, dur, 0.015, 1.6) * 0.7
		chime = (math.sin(phase) + 0.4 * math.sin(phase * 1.5)) * env_ad(t, dur, 0.01, 2.0) * 0.6
		out.append(whoosh + chime)
	return out, 0.72


def snd_step():
	"""Один шаг по каменной/деревянной плите."""
	dur = 0.085
	n = int(RATE * dur)
	noise = lowpass(make_noise(n, 5), 0.18)
	out = []
	phase = 0.0
	for i in range(n):
		t = i / RATE
		freq = 145.0 * math.exp(-t * 28.0) + 45.0
		phase += TWO_PI * freq / RATE
		thud = math.sin(phase) * env_ad(t, dur, 0.002, 2.6) * 0.8
		grit = noise[i] * env_ad(t, 0.05, 0.002, 2.2) * 0.55
		out.append(thud + grit)
	return out, 0.58


def snd_hit():
	"""Удар оружием / получение урона: хлёсткий взмах + глухой удар."""
	dur = 0.19
	n = int(RATE * dur)
	noise = lowpass(make_noise(n, 6), 0.28)
	out = []
	phase = 0.0
	for i in range(n):
		t = i / RATE
		freq = 190.0 * math.exp(-t * 18.0) + 48.0
		phase += TWO_PI * freq / RATE
		body = math.tanh(math.sin(phase) * 1.8) * env_ad(t, dur, 0.002, 2.2)
		crunch = noise[i] * env_ad(t, 0.11, 0.001, 2.0) * 0.85
		clang = math.sin(TWO_PI * 980.0 * t) * env_ad(t, 0.045, 0.001, 3.0) * 0.25
		out.append(body * 0.85 + crunch + clang)
	return out, 0.85


def snd_block():
	"""Постановка щита / блока: металлический лязг лат и купола."""
	dur = 0.26
	n = int(RATE * dur)
	noise = lowpass(make_noise(n, 7), 0.4)
	out = []
	freqs = [540.0, 810.0, 1180.0, 1620.0]
	weights = [0.5, 0.35, 0.25, 0.15]
	for i in range(n):
		t = i / RATE
		ring = sum(w * math.sin(TWO_PI * f * t) for f, w in zip(freqs, weights))
		thump = math.sin(TWO_PI * (140.0 * math.exp(-t * 20.0)) * t) * env_ad(t, 0.09, 0.002, 2.5) * 0.6
		hit = noise[i] * env_ad(t, 0.03, 0.001, 3.0) * 0.5
		out.append(ring * env_ad(t, dur, 0.003, 2.1) + thump + hit)
	return out, 0.78


def snd_push():
	"""Толчок / таран: резкий воздушный импульс."""
	dur = 0.17
	n = int(RATE * dur)
	noise = lowpass(make_noise(n, 8), 0.22)
	out = []
	phase = 0.0
	for i in range(n):
		t = i / RATE
		freq = 240.0 * math.exp(-t * 12.0) + 55.0
		phase += TWO_PI * freq / RATE
		out.append((math.sin(phase) * 0.7 + noise[i] * 0.7) * env_ad(t, dur, 0.004, 1.9))
	return out, 0.75


def snd_fire():
	"""Огонь / огненный шар: вспышка и рёв пламени."""
	dur = 0.42
	n = int(RATE * dur)
	raw = make_noise(n, 9)
	roar = lowpass(raw, 0.12)
	crackle = lowpass(raw, 0.55)
	out = []
	phase = 0.0
	for i in range(n):
		t = i / RATE
		freq = 160.0 * math.exp(-t * 6.0) + 55.0
		phase += TWO_PI * freq / RATE
		boom = math.sin(phase) * env_ad(t, 0.22, 0.005, 1.8) * 0.7
		flame = (roar[i] * 0.85 + crackle[i] * 0.35) * env_ad(t, dur, 0.02, 1.4)
		out.append(boom + flame)
	return out, 0.85


def snd_ice():
	"""Лёд / заморозка: кристальный перезвон и хруст."""
	dur = 0.34
	n = int(RATE * dur)
	noise = lowpass(make_noise(n, 10), 0.65)
	out = []
	freqs = [1250.0, 1680.0, 2240.0, 2960.0]
	for i in range(n):
		t = i / RATE
		chime = sum(math.sin(TWO_PI * (f + 40.0 * math.sin(t * 35.0)) * t) * env_ad(t, dur, 0.003, 1.8 + k * 0.4)
					for k, f in enumerate(freqs)) * 0.25
		crack = noise[i] * env_ad(t, 0.12, 0.002, 2.2) * 0.55
		out.append(chime + crack)
	return out, 0.76


def snd_lightning():
	"""Молния / разряд: резкий электрический треск и гул."""
	dur = 0.36
	n = int(RATE * dur)
	noise = make_noise(n, 11)
	out = []
	phase = 0.0
	for i in range(n):
		t = i / RATE
		# Скачущая частота для эффекта электрической дуги
		mod = 1.0 + 0.35 * math.sin(TWO_PI * 65.0 * t)
		freq = (520.0 * math.exp(-t * 7.0) + 95.0) * mod
		phase += TWO_PI * freq / RATE
		zap = math.tanh(math.sin(phase) * 2.5 + noise[i] * 1.4)
		# Двойная вспышка в начале
		pulse = 1.0 if (t < 0.05 or (0.07 < t < 0.13)) else 0.65
		out.append(zap * env_ad(t, dur, 0.001, 1.7) * pulse)
	return out, 0.85


def snd_water():
	"""Волна / вода: плеск и перекат воды."""
	dur = 0.36
	n = int(RATE * dur)
	raw = make_noise(n, 12)
	wash = lowpass(raw, 0.22)
	out = []
	phase = 0.0
	for i in range(n):
		t = i / RATE
		# Булькающая модуляция
		freq = 260.0 + 140.0 * math.sin(TWO_PI * 19.0 * t) + 180.0 * (t / dur)
		phase += TWO_PI * freq / RATE
		bubble = math.sin(phase) * env_ad(t, 0.25, 0.01, 1.8) * 0.35
		splash = wash[i] * env_ad(t, dur, 0.025, 1.5) * 0.85
		out.append(bubble + splash)
	return out, 0.78


def snd_magic():
	"""Заклинание / бафф / руна: мистический аккорд с мерцанием."""
	dur = 0.34
	n = int(RATE * dur)
	out = []
	freqs = [440.0, 554.37, 659.25, 880.0]
	for i in range(n):
		t = i / RATE
		vib = 1.0 + 0.008 * math.sin(TWO_PI * 12.0 * t)
		s = 0.0
		for k, f in enumerate(freqs):
			s += math.sin(TWO_PI * f * vib * t) * (0.4 / (1.0 + k * 0.35))
		out.append(s * env_ad(t, dur, 0.015, 1.7))
	return out, 0.72


def snd_explosion():
	"""Взрыв бочки / падение дерева / метеор: мощный низкий грохот."""
	dur = 0.52
	n = int(RATE * dur)
	raw = make_noise(n, 13)
	rumble = lowpass(raw, 0.09)
	debris = lowpass(raw, 0.35)
	out = []
	phase = 0.0
	for i in range(n):
		t = i / RATE
		freq = 120.0 * math.exp(-t * 9.0) + 32.0
		phase += TWO_PI * freq / RATE
		sub = math.tanh(math.sin(phase) * 2.2) * env_ad(t, 0.38, 0.002, 1.6)
		blast = (rumble[i] * 0.9 + debris[i] * 0.45) * env_ad(t, dur, 0.004, 1.5)
		out.append(sub * 0.8 + blast)
	return out, 0.92


def snd_death():
	"""Гибель юнита: тяжёлый нисходящий выдох и падение."""
	dur = 0.34
	n = int(RATE * dur)
	noise = lowpass(make_noise(n, 14), 0.16)
	out = []
	phase = 0.0
	for i in range(n):
		t = i / RATE
		freq = 240.0 * math.exp(-t * 7.5) + 42.0
		phase += TWO_PI * freq / RATE
		tone = (math.sin(phase) + 0.4 * math.sin(phase * 1.5)) * env_ad(t, dur, 0.005, 1.7)
		fall = noise[i] * env_ad(t, dur, 0.01, 1.8) * 0.6
		out.append(tone * 0.65 + fall)
	return out, 0.78


def snd_turn():
	"""Конец хода / смена раунда: короткий приглушённый удар гонга."""
	dur = 0.30
	n = int(RATE * dur)
	out = []
	freqs = [220.0, 330.0, 462.0]
	for i in range(n):
		t = i / RATE
		s = (0.6 * math.sin(TWO_PI * freqs[0] * t)
			 + 0.3 * math.sin(TWO_PI * freqs[1] * t)
			 + 0.15 * math.sin(TWO_PI * freqs[2] * t))
		out.append(s * env_ad(t, dur, 0.005, 2.0))
	return out, 0.68


def snd_heal():
	"""Лечение (привал, родник): светлое восходящее созвучие."""
	dur = 0.45
	n = int(RATE * dur)
	out = []
	notes = [(0.0, 523.25), (0.09, 659.25), (0.18, 783.99), (0.26, 1046.50)]
	for i in range(n):
		t = i / RATE
		s = 0.0
		for start, f in notes:
			if t >= start:
				dt = t - start
				rem = dur - start
				s += (math.sin(TWO_PI * f * dt) + 0.25 * math.sin(TWO_PI * f * 2.0 * dt)) * env_ad(dt, rem, 0.008, 1.8)
		out.append(s * 0.35)
	return out, 0.75


def snd_coin():
	"""Золото / покупка / оберег: двойной звон монет."""
	dur = 0.32
	n = int(RATE * dur)
	out = []
	hits = [(0.0, 1760.0, 2640.0), (0.075, 2093.0, 3139.0)]
	for i in range(n):
		t = i / RATE
		s = 0.0
		for start, f1, f2 in hits:
			if t >= start:
				dt = t - start
				rem = dur - start
				s += (0.65 * math.sin(TWO_PI * f1 * dt) + 0.35 * math.sin(TWO_PI * f2 * dt)) * env_ad(dt, rem, 0.001, 2.6)
		out.append(s)
	return out, 0.72


def snd_bell():
	"""Колокол Стражи (хаб, смена Звона, карта Колокола): глубокий медный благовест."""
	dur = 1.15
	n = int(RATE * dur)
	out = []
	# Обертоны настоящего колокола (минорная терция и квинта)
	partials = [
		(196.0, 0.55, 1.4),
		(392.0, 0.45, 1.7),
		(466.16, 0.35, 2.1),
		(587.33, 0.28, 2.5),
		(784.0, 0.18, 3.2),
		(1046.5, 0.10, 4.2),
	]
	for i in range(n):
		t = i / RATE
		s = 0.0
		for freq, amp, decay in partials:
			beat = 1.0 + 0.04 * math.sin(TWO_PI * 3.5 * t)
			s += amp * math.sin(TWO_PI * freq * beat * t) * env_ad(t, dur, 0.003, decay)
		strike = math.sin(TWO_PI * 110.0 * t) * env_ad(t, 0.06, 0.001, 3.0) * 0.45
		out.append(s + strike)
	return out, 0.85


def snd_door():
	"""Дверь Караульни / сундук: деревянный скрип и глухой засов."""
	dur = 0.32
	n = int(RATE * dur)
	noise = lowpass(make_noise(n, 15), 0.15)
	out = []
	phase = 0.0
	for i in range(n):
		t = i / RATE
		freq = 115.0 + 35.0 * math.sin(TWO_PI * 14.0 * t)
		phase += TWO_PI * freq / RATE
		creak = math.tanh(math.sin(phase) * 1.6) * env_ad(t, 0.24, 0.015, 1.5) * 0.45
		latch = (math.sin(TWO_PI * 90.0 * t) + noise[i]) * env_ad(t - 0.18, 0.12, 0.002, 2.5) * 0.65 if t > 0.18 else 0.0
		out.append(creak + latch)
	return out, 0.72


def snd_victory():
	"""Победа в бою: торжественный латунный аккорд."""
	dur = 0.85
	n = int(RATE * dur)
	out = []
	notes = [
		(0.0, 293.66, 0.85),    # D4
		(0.11, 369.99, 0.74),   # F#4
		(0.22, 440.00, 0.63),   # A4
		(0.34, 587.33, 0.51),   # D5
	]
	for i in range(n):
		t = i / RATE
		s = 0.0
		for start, f, length in notes:
			if t >= start:
				dt = t - start
				tone = (0.65 * math.sin(TWO_PI * f * dt)
						+ 0.25 * math.sin(TWO_PI * f * 2.0 * dt)
						+ 0.10 * math.sin(TWO_PI * f * 3.0 * dt))
				s += tone * env_ad(dt, length, 0.01, 1.6)
		out.append(s * 0.38)
	return out, 0.82


def snd_defeat():
	"""Поражение: мрачный низкий нисходящий аккорд."""
	dur = 0.90
	n = int(RATE * dur)
	out = []
	notes = [
		(0.0, 220.00, 0.90),    # A3
		(0.18, 196.00, 0.72),   # G3
		(0.36, 164.81, 0.54),   # E3
		(0.36, 110.00, 0.54),   # A2 (бас)
	]
	for i in range(n):
		t = i / RATE
		s = 0.0
		for start, f, length in notes:
			if t >= start:
				dt = t - start
				tone = 0.7 * math.sin(TWO_PI * f * dt) + 0.3 * math.sin(TWO_PI * f * 1.5 * dt)
				s += tone * env_ad(dt, length, 0.015, 1.5)
		out.append(s * 0.4)
	return out, 0.80


SOUNDS = {
	"ui_click": snd_ui_click,
	"ui_hover": snd_ui_hover,
	"card_select": snd_card_select,
	"card_cancel": snd_card_cancel,
	"card_play": snd_card_play,
	"step": snd_step,
	"hit": snd_hit,
	"block": snd_block,
	"push": snd_push,
	"fire": snd_fire,
	"ice": snd_ice,
	"lightning": snd_lightning,
	"water": snd_water,
	"magic": snd_magic,
	"explosion": snd_explosion,
	"death": snd_death,
	"turn": snd_turn,
	"heal": snd_heal,
	"coin": snd_coin,
	"bell": snd_bell,
	"door": snd_door,
	"victory": snd_victory,
	"defeat": snd_defeat,
}


def main():
	out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
	os.makedirs(out_dir, exist_ok=True)
	for name, builder in SOUNDS.items():
		samples, vol = builder()
		save_wav(os.path.join(out_dir, name + ".wav"), samples, vol)
	print("звуков:", len(SOUNDS))


if __name__ == "__main__":
	main()

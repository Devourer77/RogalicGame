# Сборка всех звуковых эффектов игры в assets/sounds/*.wav (44100 Гц, 16-бит PCM).
# Запуск из папки проекта или из assets/sounds/src/:
#   python assets/sounds/src/build_sounds.py
#   python assets/sounds/src/build_sounds.py --all   (также пересобирает музыку и эмбиенты 1 акта)
import math
import os
import random
import sys

SRC_DIR = os.path.dirname(os.path.abspath(__file__))
if SRC_DIR not in sys.path:
	sys.path.insert(0, SRC_DIR)

import dsp
from dsp import (
	RATE,
	TWO_PI,
	biquad,
	biquad_sweep,
	brass_note,
	clamp,
	drum_hit,
	env_ad,
	env_adsr,
	fade_edges,
	flute_note,
	ks_pluck,
	lowpass_1p,
	make_noise,
	mix_into,
	mix_stereo,
	modal_hit,
	pink_noise,
	reverb_stereo,
	saturate,
	save_wav,
)


def _norm(samples):
	peak = max((abs(x) for x in samples), default=1.0)
	if peak < 1e-6:
		return samples
	inv = 1.0 / peak
	return [x * inv for x in samples]


# ==============================================================================
# 1. ИНТЕРФЕЙС И КАРТЫ
# ==============================================================================

def snd_ui_click(variant=1):
	"""Благородный латунно-деревянный щелчок кнопки."""
	dur = 0.055
	n = int(RATE * dur)
	base = 690.0 if variant == 1 else 745.0
	tone = modal_hit([(base, 0.7, 3.2), (base * 2.15, 0.35, 4.5), (190.0, 0.45, 3.6)], dur, 0.25, 1900.0, 10 + variant)
	body = biquad(tone, "lp", 3600.0, 0.8)
	return (fade_edges(body, 1.0, 6.0),), -7.5


def snd_ui_hover():
	"""Деликатный мягкий шелест пергамента при наведении — не утомляет при частом движении мыши."""
	dur = 0.036
	n = int(RATE * dur)
	raw = biquad(pink_noise(n, 21), "bp", 2400.0, 1.3)
	out = [raw[i] * math.sin(math.pi * i / n) ** 1.4 for i in range(n)]
	return (out,), -15.0


def snd_card_select():
	"""Взятие карты в руку: быстрый скользящий свайп плотной бумаги и лёгкий латунный акцент."""
	dur = 0.11
	n = int(RATE * dur)
	paper = biquad_sweep(pink_noise(n, 31), "bp", lambda t: 900.0 + 2600.0 * (t / dur), q=1.5)
	out = [0.0] * n
	phase = 0.0
	for i in range(n):
		t = i / RATE
		freq = 410.0 + 320.0 * (t / dur)
		phase += TWO_PI * freq / RATE
		swish = paper[i] * math.sin(math.pi * t / dur) * 0.9
		bell = math.sin(phase) * env_ad(t, dur, 0.005, 2.4) * 0.28
		out[i] = swish + bell
	return (fade_edges(out, 2.0, 10.0),), -6.0


def snd_card_cancel():
	"""Возврат карты в руку: мягкий короткий нисходящий шелест."""
	dur = 0.085
	n = int(RATE * dur)
	paper = biquad_sweep(pink_noise(n, 32), "bp", lambda t: 2100.0 - 1100.0 * (t / dur), q=1.4)
	out = [0.0] * n
	phase = 0.0
	for i in range(n):
		t = i / RATE
		freq = 460.0 - 190.0 * (t / dur)
		phase += TWO_PI * freq / RATE
		out[i] = (paper[i] * 0.75 + math.sin(phase) * 0.25) * env_ad(t, dur, 0.004, 2.1)
	return (fade_edges(out, 2.0, 8.0),), -8.0


def snd_card_play():
	"""Розыгрыш карты: плотный взмах бумаги + мистическая вспышка."""
	dur = 0.18
	n = int(RATE * dur)
	air = biquad_sweep(pink_noise(n, 33), "bp", lambda t: 550.0 + 2800.0 * ((t / dur) ** 0.7), q=1.4)
	snap = biquad(make_noise(n, 34), "hp", 2200.0, 0.9)
	out = [0.0] * n
	phase = 0.0
	for i in range(n):
		t = i / RATE
		freq = 320.0 + 510.0 * ((t / dur) ** 0.65)
		phase += TWO_PI * freq / RATE
		w = air[i] * env_ad(t, dur, 0.012, 1.7) * 0.85
		c = (math.sin(phase) * 0.65 + math.sin(phase * 1.5) * 0.35) * env_ad(t, dur, 0.006, 2.2) * 0.45
		s = snap[i] * env_ad(t, 0.025, 0.001, 3.0) * 0.45
		out[i] = w + c + s
	l, r = reverb_stereo(out, wet=0.14, room=0.35, damp=0.5)
	return (l, r), -4.5


def snd_card_keep():
	"""Удержание карты: чёткий защёлк латунного замочка."""
	dur = 0.14
	part1 = modal_hit([(920.0, 0.55, 4.2), (1420.0, 0.4, 5.0), (2450.0, 0.25, 6.0)], 0.08, 0.3, 2800.0, 41)
	part2 = modal_hit([(1180.0, 0.65, 3.0), (1770.0, 0.42, 3.8), (2960.0, 0.3, 4.6), (340.0, 0.4, 3.4)], 0.12, 0.35, 3200.0, 42)
	out = [0.0] * int(RATE * dur)
	mix_into(out, part1, 0, 0.7)
	mix_into(out, part2, int(RATE * 0.032), 1.0)
	return (fade_edges(out, 1.0, 12.0),), -6.5


def snd_card_scrap():
	"""Сброс карты «в ноги»: резкий бросок вниз + упругий толчковый импульс шага."""
	dur = 0.16
	n = int(RATE * dur)
	air = biquad_sweep(pink_noise(n, 45), "bp", lambda t: 2200.0 - 1500.0 * (t / dur), q=1.3)
	thump = drum_hit(145.0, 58.0, 0.12, slap=0.3, body_decay=2.8, seed=46)
	out = [air[i] * env_ad(i / RATE, dur, 0.003, 1.9) * 0.75 for i in range(n)]
	mix_into(out, thump, int(RATE * 0.035), 0.75)
	return (fade_edges(out, 2.0, 12.0),), -5.0


def snd_chain_up():
	"""Новое звено «Цепи»: чистый хрустально-латунный отклик (тональность в бою растёт с Цепью)."""
	dur = 0.24
	bell = modal_hit([(880.0, 0.55, 2.6), (1320.0, 0.45, 3.0), (1760.0, 0.32, 3.6), (2640.0, 0.2, 4.4)], dur, 0.18, 3400.0, 50)
	l, r = reverb_stereo(bell, wet=0.22, room=0.45, damp=0.35)
	return (l, r), -8.0


# ==============================================================================
# 2. ШАГИ ПО ПОВЕРХНОСТЯМ И ВОДА/ТРЯСИНА
# ==============================================================================

def snd_step_stone(variant=1):
	"""Шаг сапога по каменной плите."""
	dur = 0.095
	n = int(RATE * dur)
	rng = random.Random(100 + variant)
	pitch_k = 0.94 + 0.06 * variant
	thud = drum_hit(135.0 * pitch_k, 48.0 * pitch_k, 0.075, slap=0.42, body_decay=3.2, seed=110 + variant)
	grit = biquad(make_noise(n, 120 + variant), "bp", 2100.0 + variant * 180.0, 1.6)
	out = [0.0] * n
	mix_into(out, thud, 0, 0.85)
	for i in range(n):
		t = i / RATE
		out[i] += grit[i] * env_ad(t, 0.045, 0.002, 2.5) * 0.36
	l, r = reverb_stereo(out, wet=0.10, room=0.3, damp=0.55, predelay_ms=8.0)
	return (fade_edges(l, 1.0, 8.0), fade_edges(r, 1.0, 8.0)), -7.0


def snd_step_wood(variant=1):
	"""Шаг по деревянным доскам гати или помоста: полый древесный резонанс."""
	dur = 0.11
	n = int(RATE * dur)
	f = (165.0 + variant * 14.0)
	knock = modal_hit([(f, 0.75, 3.6), (f * 1.85, 0.45, 4.4), (f * 3.1, 0.2, 5.2)], dur, 0.35, 1600.0, 130 + variant)
	knock = biquad(knock, "lp", 2400.0, 0.8)
	thud = drum_hit(110.0, 52.0, 0.08, slap=0.25, body_decay=3.0, seed=140 + variant)
	out = [0.0] * n
	mix_into(out, knock, 0, 0.85)
	mix_into(out, thud, 0, 0.45)
	l, r = reverb_stereo(out, wet=0.11, room=0.32, damp=0.5, predelay_ms=7.0)
	return (fade_edges(l, 1.0, 10.0), fade_edges(r, 1.0, 10.0)), -6.5


def snd_step_moss(variant=1):
	"""Мягкий шаг по мху и рыхлой земле."""
	dur = 0.10
	n = int(RATE * dur)
	rustle = biquad_sweep(pink_noise(n, 150 + variant), "bp", lambda t: 1100.0 - 500.0 * (t / dur), q=1.1)
	thud = drum_hit(98.0, 42.0, 0.08, slap=0.12, body_decay=2.8, seed=160 + variant)
	out = [0.0] * n
	mix_into(out, thud, 0, 0.75)
	for i in range(n):
		out[i] += rustle[i] * env_ad(i / RATE, dur, 0.006, 2.0) * 0.55
	return (fade_edges(out, 2.0, 10.0),), -8.0


def snd_step_water(variant=1):
	"""Шаг по луже: шлёпок воды и брызги капель."""
	dur = 0.16
	n = int(RATE * dur)
	rng = random.Random(170 + variant)
	splash = biquad_sweep(pink_noise(n, 175 + variant), "bp", lambda t: 850.0 + 1800.0 * (t / dur), q=1.5)
	thud = drum_hit(115.0, 52.0, 0.07, slap=0.25, body_decay=3.0, seed=180 + variant)
	out = [0.0] * n
	mix_into(out, thud, 0, 0.5)
	for i in range(n):
		out[i] += splash[i] * env_ad(i / RATE, dur, 0.004, 1.9) * 0.85
	# Мелкие капельки
	for k in range(3):
		off = int(RATE * rng.uniform(0.025, 0.09))
		drop_f = rng.uniform(950.0, 1850.0)
		dn = int(RATE * 0.035)
		drop = [math.sin(TWO_PI * (drop_f + 420.0 * (j / dn)) * (j / RATE)) * env_ad(j / RATE, 0.035, 0.001, 2.5) * 0.25 for j in range(dn)]
		mix_into(out, drop, off, 0.6)
	l, r = reverb_stereo(out, wet=0.14, room=0.4, damp=0.4)
	return (fade_edges(l, 1.5, 12.0), fade_edges(r, 1.5, 12.0)), -6.5


def snd_step_swamp(variant=1):
	"""Вязкий шаг по трясине: сочное хлюпанье грязи."""
	dur = 0.18
	n = int(RATE * dur)
	noise = pink_noise(n, 190 + variant)
	# Чмокающий свип фильтра: сначала сдавливание грязи (вверх), потом вытягивание сапога (вниз)
	squelch = biquad_sweep(
		noise,
		"bp",
		lambda t: (340.0 + 620.0 * math.sin(math.pi * clamp(t / 0.11, 0.0, 1.0))) * (0.95 + 0.05 * variant),
		q=3.2,
	)
	mud_pop = biquad_sweep(
		make_noise(n, 195 + variant),
		"bp",
		lambda t: 280.0 + 420.0 * clamp((t - 0.06) / 0.08, 0.0, 1.0),
		q=2.6,
	)
	out = [0.0] * n
	for i in range(n):
		t = i / RATE
		e1 = env_ad(t, 0.11, 0.005, 1.7)
		e2 = env_ad(max(0.0, t - 0.055), 0.12, 0.006, 1.9) if t > 0.055 else 0.0
		out[i] = squelch[i] * e1 * 1.15 + mud_pop[i] * e2 * 0.85
	l, r = reverb_stereo(out, wet=0.12, room=0.35, damp=0.45)
	return (fade_edges(l, 2.0, 12.0), fade_edges(r, 2.0, 12.0)), -6.0


def snd_sink():
	"""Утопление в трясине: тяжёлый бульк вниз + пузыри + затягивающий чавк."""
	dur = 0.72
	n = int(RATE * dur)
	slurp = biquad_sweep(pink_noise(n, 201), "bp", lambda t: 520.0 * math.exp(-t * 2.2) + 140.0, q=2.5)
	out = [slurp[i] * env_ad(i / RATE, dur, 0.02, 1.4) * 0.9 for i in range(n)]
	# 4 тяжёлых пузыря вверх по мере погружения
	bubbles = [(0.04, 150.0, 320.0, 0.11), (0.17, 190.0, 380.0, 0.10), (0.31, 230.0, 440.0, 0.09), (0.46, 260.0, 510.0, 0.08)]
	for start, f0, f1, bdur in bubbles:
		bn = int(RATE * bdur)
		phase = 0.0
		bub = [0.0] * bn
		for j in range(bn):
			bt = j / RATE
			bf = f0 + (f1 - f0) * ((bt / bdur) ** 1.2)
			phase += TWO_PI * bf / RATE
			bub[j] = math.sin(phase) * env_ad(bt, bdur, 0.006, 1.9) * 0.55
		mix_into(out, bub, int(RATE * start), 0.8)
	l, r = reverb_stereo(out, wet=0.22, room=0.5, damp=0.45)
	return (fade_edges(l, 3.0, 30.0), fade_edges(r, 3.0, 30.0)), -3.5


# ==============================================================================
# 3. ОРУЖИЕ, УДАРЫ, ЩИТЫ И ВРАГИ
# ==============================================================================

def snd_sword_swing(variant=1):
	"""Хлёсткий размах клинка в воздухе перед ударом."""
	dur = 0.16
	n = int(RATE * dur)
	pk = 0.94 + 0.08 * variant
	whoosh = biquad_sweep(
		pink_noise(n, 210 + variant),
		"bp",
		lambda t: (320.0 + 1150.0 * math.sin(math.pi * clamp(t / dur, 0.0, 1.0)) ** 1.2) * pk,
		q=1.6,
	)
	air = biquad(pink_noise(n, 215 + variant), "bp", 2200.0, 1.0)
	out = [0.0] * n
	for i in range(n):
		t = i / RATE
		env = math.sin(math.pi * t / dur) ** 1.15
		out[i] = (whoosh[i] * 1.25 + air[i] * 0.25) * env
	l, r = reverb_stereo(out, wet=0.12, room=0.35, damp=0.5)
	return (fade_edges(l, 2.0, 10.0), fade_edges(r, 2.0, 10.0)), -5.0


def snd_sword_hit(variant=1):
	"""Сочный 4-слойный удар мечом: разрез воздуха -> стальной срез -> плотный тумак тела -> звон доспеха."""
	dur = 0.34
	n = int(RATE * dur)
	rng = random.Random(220 + variant)
	pk = 0.95 + 0.05 * variant

	# 1) Короткий свуш разгона в первые 35 мс
	swoosh_n = int(RATE * 0.09)
	swoosh = biquad_sweep(pink_noise(swoosh_n, 225 + variant), "bp", lambda t: 600.0 + 2400.0 * (t / 0.09), q=1.5)

	# 2) Острый стальной срез (высокочастотный чирк + металлические обертоны клинка)
	edge_f = 2280.0 * pk
	steel = modal_hit(
		[(edge_f, 0.5, 4.0), (edge_f * 1.53, 0.35, 4.8), (edge_f * 2.27, 0.22, 5.5), (940.0 * pk, 0.3, 3.4)],
		0.20,
		click_gain=0.45,
		click_fc=3600.0,
		seed=230 + variant,
	)

	# 3) Плотное «мясо» удара: резкий широкополосный хруст + глубокий саб-тумак
	crunch = biquad_sweep(make_noise(int(RATE * 0.14), 235 + variant), "bp", lambda t: 1450.0 * math.exp(-t * 14.0) + 320.0, q=1.1)
	thump = drum_hit(205.0 * pk, 46.0, 0.20, slap=0.55, body_decay=2.3, seed=240 + variant)

	# Собираем в стерео со сдвигом на пик удара (~18 мс после начала свуша)
	out_l = [0.0] * n
	out_r = [0.0] * n
	imp = int(RATE * 0.018)
	mix_stereo(out_l, out_r, [swoosh[i] * env_ad(i / RATE, 0.09, 0.008, 2.0) for i in range(swoosh_n)], 0, 0.75, pan=-0.25 if variant == 1 else 0.2)
	mix_stereo(out_l, out_r, thump, imp, 0.95, pan=0.0)
	mix_stereo(out_l, out_r, [crunch[i] * env_ad(i / RATE, 0.14, 0.001, 2.2) for i in range(len(crunch))], imp, 0.85, pan=0.1)
	mix_stereo(out_l, out_r, steel, imp, 0.65, pan=0.15 if variant == 1 else -0.15)

	out_l = saturate(out_l, 1.35)
	out_r = saturate(out_r, 1.35)
	l, r = reverb_stereo(out_l, out_r, wet=0.16, room=0.42, damp=0.48, predelay_ms=10.0)
	return (fade_edges(l, 1.0, 18.0), fade_edges(r, 1.0, 18.0)), -1.5


def snd_heavy_hit(variant=1):
	"""Тяжёлый сокрушающий удар (босс, крит, добивание): глубокий вес + треск брони + гул."""
	dur = 0.48
	n = int(RATE * dur)
	pk = 0.92 + 0.07 * variant
	whoosh = biquad_sweep(pink_noise(int(RATE * 0.13), 250 + variant), "bp", lambda t: 320.0 + 1400.0 * (t / 0.13), q=1.4)
	sub = drum_hit(155.0 * pk, 34.0, 0.34, slap=0.65, body_decay=1.8, seed=255 + variant)
	crunch = biquad_sweep(make_noise(int(RATE * 0.20), 260 + variant), "bp", lambda t: 1100.0 * math.exp(-t * 10.0) + 220.0, q=1.0)
	clang = modal_hit([(680.0 * pk, 0.45, 3.0), (1120.0 * pk, 0.3, 3.6), (1790.0 * pk, 0.22, 4.2)], 0.26, 0.45, 2900.0, 265 + variant)

	out_l = [0.0] * n
	out_r = [0.0] * n
	imp = int(RATE * 0.032)
	mix_stereo(out_l, out_r, [whoosh[i] * env_ad(i / RATE, 0.13, 0.01, 1.8) for i in range(len(whoosh))], 0, 0.7, pan=-0.2)
	mix_stereo(out_l, out_r, sub, imp, 1.15, pan=0.0)
	mix_stereo(out_l, out_r, [crunch[i] * env_ad(i / RATE, 0.20, 0.001, 2.0) for i in range(len(crunch))], imp, 0.9, pan=-0.12)
	mix_stereo(out_l, out_r, clang, imp, 0.6, pan=0.18)

	out_l = saturate(out_l, 1.55)
	out_r = saturate(out_r, 1.55)
	l, r = reverb_stereo(out_l, out_r, wet=0.22, room=0.52, damp=0.45, predelay_ms=14.0)
	return (fade_edges(l, 1.0, 25.0), fade_edges(r, 1.0, 25.0)), -1.0


def snd_pincer_hit():
	"""Удар в «Клещи»: мощный двойной стальной срез с латунным отзвуком тактического бонуса."""
	l1, r1 = snd_sword_hit(1)[0]
	n = max(len(l1), int(RATE * 0.42))
	out_l = [0.0] * n
	out_r = [0.0] * n
	mix_into(out_l, l1, 0, 0.95)
	mix_into(out_r, r1, 0, 0.95)
	# Второй синхронный срез чуть правее/левее + латунная квинта-искра
	flash = modal_hit([(1046.5, 0.45, 2.6), (1567.98, 0.35, 3.0), (2093.0, 0.25, 3.8)], 0.34, 0.25, 3400.0, 270)
	fl, fr = reverb_stereo(flash, wet=0.24, room=0.45, damp=0.35)
	mix_into(out_l, fl, int(RATE * 0.025), 0.65)
	mix_into(out_r, fr, int(RATE * 0.025), 0.65)
	return (fade_edges(out_l, 1.0, 20.0), fade_edges(out_r, 1.0, 20.0)), -1.2


def snd_staff_hit(variant=1):
	"""Удар посохом Мага: плотный древесный стук с коротким тайным разрядом."""
	dur = 0.25
	wood = modal_hit([(225.0 + variant * 15.0, 0.7, 3.2), (485.0, 0.4, 4.0), (920.0, 0.22, 5.0)], 0.18, 0.35, 1900.0, 275 + variant)
	spark = modal_hit([(740.0, 0.35, 2.8), (1110.0, 0.25, 3.4)], 0.22, 0.1, 3000.0, 278 + variant)
	thump = drum_hit(160.0, 56.0, 0.14, slap=0.3, body_decay=2.8, seed=280 + variant)
	out = [0.0] * int(RATE * dur)
	mix_into(out, thump, 0, 0.85)
	mix_into(out, wood, 0, 0.7)
	mix_into(out, spark, int(RATE * 0.008), 0.45)
	l, r = reverb_stereo(out, wet=0.18, room=0.4, damp=0.45)
	return (fade_edges(l, 1.0, 16.0), fade_edges(r, 1.0, 16.0)), -3.0


def snd_block(variant=1):
	"""Постановка щита / отражение удара: сталь щита + плотный глухой упор."""
	dur = 0.34
	pk = 0.96 + 0.06 * variant
	iron = modal_hit(
		[(480.0 * pk, 0.6, 2.1), (742.0 * pk, 0.45, 2.5), (1135.0 * pk, 0.32, 3.0), (1680.0 * pk, 0.2, 3.6), (2420.0 * pk, 0.12, 4.4)],
		dur,
		click_gain=0.42,
		click_fc=2600.0,
		seed=290 + variant,
	)
	thump = drum_hit(145.0, 52.0, 0.16, slap=0.35, body_decay=2.5, seed=295 + variant)
	out = [0.0] * int(RATE * dur)
	mix_into(out, iron, 0, 0.85)
	mix_into(out, thump, 0, 0.75)
	l, r = reverb_stereo(out, wet=0.20, room=0.48, damp=0.42)
	return (fade_edges(l, 1.0, 20.0), fade_edges(r, 1.0, 20.0)), -2.5


def snd_shield_break():
	"""Щит пробит: хлёсткий металлический раскол и звон осколков вниз."""
	dur = 0.42
	n = int(RATE * dur)
	crack = biquad(make_noise(int(RATE * 0.08), 301), "bp", 2200.0, 1.1)
	shard1 = modal_hit([(1420.0, 0.55, 2.4), (960.0, 0.45, 2.8), (2180.0, 0.35, 3.2)], 0.32, 0.4, 3200.0, 302)
	shard2 = modal_hit([(680.0, 0.45, 2.6), (1150.0, 0.35, 3.2), (1790.0, 0.25, 3.8)], 0.28, 0.3, 2500.0, 303)
	out_l = [0.0] * n
	out_r = [0.0] * n
	mix_stereo(out_l, out_r, [crack[i] * env_ad(i / RATE, 0.08, 0.001, 2.5) for i in range(len(crack))], 0, 1.0, pan=0.0)
	mix_stereo(out_l, out_r, shard1, int(RATE * 0.015), 0.75, pan=-0.35)
	mix_stereo(out_l, out_r, shard2, int(RATE * 0.075), 0.65, pan=0.35)
	l, r = reverb_stereo(out_l, out_r, wet=0.22, room=0.45, damp=0.4)
	return (fade_edges(l, 1.0, 20.0), fade_edges(r, 1.0, 20.0)), -2.5


def snd_push():
	"""Упругий толчок / таран: массивный удар и воздушная волна."""
	dur = 0.24
	n = int(RATE * dur)
	air = biquad_sweep(pink_noise(n, 310), "bp", lambda t: 540.0 * math.exp(-t * 7.0) + 120.0, q=1.2)
	thump = drum_hit(180.0, 48.0, 0.20, slap=0.45, body_decay=2.0, seed=311)
	out = [air[i] * env_ad(i / RATE, dur, 0.005, 1.9) * 0.9 for i in range(n)]
	mix_into(out, thump, 0, 0.9)
	l, r = reverb_stereo(out, wet=0.14, room=0.38, damp=0.5)
	return (fade_edges(l, 1.5, 16.0), fade_edges(r, 1.5, 16.0)), -3.0


def snd_bump():
	"""Врезался в стену или частокол при толчке: тяжёлое жёсткое столкновение."""
	dur = 0.24
	thud = drum_hit(145.0, 40.0, 0.22, slap=0.6, body_decay=2.2, seed=315)
	stone = modal_hit([(240.0, 0.55, 3.0), (410.0, 0.35, 3.8)], 0.16, 0.4, 1400.0, 316)
	out = [0.0] * int(RATE * dur)
	mix_into(out, thud, 0, 1.0)
	mix_into(out, stone, 0, 0.6)
	l, r = reverb_stereo(out, wet=0.16, room=0.4, damp=0.5)
	return (fade_edges(l, 1.0, 16.0), fade_edges(r, 1.0, 16.0)), -2.5


def snd_enemy_bite(variant=1):
	"""Атака зверя (волк, пиявка, паук, матерь): хищный выпад и сухой клац челюстей."""
	dur = 0.26
	n = int(RATE * dur)
	pk = 0.95 + 0.08 * variant
	snarl = biquad_sweep(pink_noise(int(RATE * 0.15), 320 + variant), "bp", lambda t: 480.0 - 200.0 * (t / 0.15), q=2.4)
	snap = modal_hit([(860.0 * pk, 0.55, 4.5), (1540.0 * pk, 0.45, 5.2), (340.0, 0.5, 3.6)], 0.09, 0.5, 2200.0, 322 + variant)
	out = [0.0] * n
	for i in range(len(snarl)):
		t = i / RATE
		# Низкий рычащий модулятор
		growl = math.tanh(math.sin(TWO_PI * (92.0 * pk) * t) * 1.5) * 0.35
		out[i] = (snarl[i] * 0.9 + growl) * env_ad(t, 0.15, 0.008, 1.7)
	mix_into(out, snap, int(RATE * 0.06), 1.0)
	l, r = reverb_stereo(out, wet=0.14, room=0.38, damp=0.45)
	return (fade_edges(l, 2.0, 14.0), fade_edges(r, 2.0, 14.0)), -3.5


def snd_enemy_club(variant=1):
	"""Размах тяжелого врага (огр, корягач, топляк, гоблин): густой воздушный взмах и тяжёлый замах."""
	dur = 0.28
	n = int(RATE * dur)
	pk = 0.93 + 0.07 * variant
	whoosh = biquad_sweep(
		pink_noise(n, 330 + variant),
		"bp",
		lambda t: (220.0 + 760.0 * math.sin(math.pi * clamp(t / dur, 0.0, 1.0)) ** 1.1) * pk,
		q=1.6,
	)
	grunt = drum_hit(115.0 * pk, 46.0, 0.18, slap=0.25, body_decay=2.2, seed=335 + variant)
	out = [whoosh[i] * math.sin(math.pi * i / n) * 1.1 for i in range(n)]
	mix_into(out, grunt, int(RATE * 0.08), 0.75)
	l, r = reverb_stereo(out, wet=0.16, room=0.42, damp=0.5)
	return (fade_edges(l, 2.0, 15.0), fade_edges(r, 2.0, 15.0)), -4.0


def snd_enemy_spit(variant=1):
	"""Плевок или выстрел пращи (паук, споры, пращник, шаман)."""
	dur = 0.20
	n = int(RATE * dur)
	pk = 0.94 + 0.09 * variant
	jet = biquad_sweep(pink_noise(n, 340 + variant), "bp", lambda t: (520.0 + 1800.0 * (t / dur)) * pk, q=2.2)
	pop = drum_hit(240.0 * pk, 95.0, 0.08, slap=0.35, body_decay=3.2, seed=345 + variant)
	out = [jet[i] * env_ad(i / RATE, dur, 0.004, 2.0) * 0.95 for i in range(n)]
	mix_into(out, pop, 0, 0.7)
	l, r = reverb_stereo(out, wet=0.15, room=0.38, damp=0.45)
	return (fade_edges(l, 1.5, 14.0), fade_edges(r, 1.5, 14.0)), -4.5


def snd_enemy_buff():
	"""Зов шамана / усиление врагов: мрачный гулкий хор Раскола с переливом."""
	dur = 0.55
	n = int(RATE * dur)
	n1 = brass_note(146.83, dur, attack=0.12, bright=0.6)   # D3
	n2 = brass_note(220.00, dur, attack=0.14, bright=0.7)   # A3
	chime = modal_hit([(587.33, 0.35, 1.8), (880.0, 0.25, 2.2)], dur, 0.05, 2400.0, 350)
	out = [0.0] * n
	mix_into(out, n1, 0, 0.55)
	mix_into(out, n2, 0, 0.45)
	mix_into(out, chime, int(RATE * 0.04), 0.45)
	l, r = reverb_stereo(out, wet=0.30, room=0.6, damp=0.4)
	return (fade_edges(l, 5.0, 35.0), fade_edges(r, 5.0, 35.0)), -4.5


# ==============================================================================
# 4. ДЕРЕВЬЯ, БОЧКИ, МОСТКИ И ОБЪЕКТЫ ТОПЕЙ
# ==============================================================================

def snd_tree_creak():
	"""Фаза 1 падения дерева (0.36 с): сухой разлом древесины, хруст щепы и разгон падения."""
	dur = 0.38
	n = int(RATE * dur)
	out_l = [0.0] * n
	out_r = [0.0] * n

	# Глубокий стон разрываемого ствола
	groan_raw = [0.0] * n
	phase = 0.0
	for i in range(n):
		t = i / RATE
		f = 92.0 + 48.0 * (t / dur) + 18.0 * math.sin(TWO_PI * 22.0 * t)
		phase = (phase + f / RATE) % 1.0
		groan_raw[i] = math.tanh((phase * 2.0 - 1.0) * 1.4) * env_ad(t, dur, 0.015, 1.3)
	groan = biquad_sweep(groan_raw, "bp", lambda t: 260.0 + 380.0 * (t / dur), q=2.2)
	mix_stereo(out_l, out_r, groan, 0, 0.9, pan=-0.1)

	# Серия хлёстких сухих тресков волокон (нарастают к моменту обрыва!)
	cracks = [(0.008, 1250.0, 0.65, -0.25), (0.065, 1680.0, 0.78, 0.2), (0.125, 980.0, 0.9, -0.15),
			  (0.18, 1950.0, 1.0, 0.3), (0.225, 1340.0, 1.0, -0.2), (0.275, 2240.0, 0.85, 0.1)]
	for start, fc, amp, pan in cracks:
		cn = int(RATE * 0.055)
		snaps = biquad(make_noise(cn, int(fc)), "bp", fc, 2.0)
		snap_sig = [snaps[j] * env_ad(j / RATE, 0.055, 0.0008, 2.8) for j in range(cn)]
		wood = modal_hit([(fc * 0.42, 0.45, 3.8), (fc * 0.78, 0.35, 4.4)], 0.05, 0.25, fc, int(fc) + 1)
		mix_stereo(out_l, out_r, snap_sig, int(RATE * start), amp * 0.95, pan=pan)
		mix_stereo(out_l, out_r, wood, int(RATE * start), amp * 0.45, pan=pan)

	# Нарастающий свист ветвей по дуге падения во второй половине
	whoosh = biquad_sweep(pink_noise(n, 405), "bp", lambda t: 240.0 + 950.0 * (clamp((t - 0.10) / 0.28, 0.0, 1.0) ** 1.6), q=1.5)
	mix_stereo(out_l, out_r, [whoosh[i] * clamp((i / RATE - 0.08) / 0.25, 0.0, 1.0) for i in range(n)], 0, 0.8, pan=0.15)

	l, r = reverb_stereo(out_l, out_r, wet=0.18, room=0.45, damp=0.45)
	return (fade_edges(l, 2.0, 14.0), fade_edges(r, 2.0, 14.0)), -2.0


def snd_tree_crash():
	"""Фаза 2 падения дерева (0.95 с): тяжёлый грохот ствола о землю, отскок, разлёт сучьев и пыль."""
	dur = 0.95
	n = int(RATE * dur)
	out_l = [0.0] * n
	out_r = [0.0] * n

	# Массивный удар ствола: глубокая мембрана + мощный хруст древесного корпуса
	slam_sub = drum_hit(118.0, 32.0, 0.44, slap=0.65, body_decay=1.65, seed=410)
	slam_wood = modal_hit([(145.0, 0.75, 2.1), (265.0, 0.65, 2.4), (480.0, 0.48, 2.8), (790.0, 0.35, 3.3)], 0.38, 0.55, 1300.0, 411)
	mix_stereo(out_l, out_r, slam_sub, 0, 0.95, pan=0.0)
	mix_stereo(out_l, out_r, slam_wood, 0, 1.05, pan=0.0)

	# Ударный взрыв земли и хвороста с богатой серединой
	impact_dust = biquad_sweep(pink_noise(int(RATE * 0.52), 412), "bp", lambda t: 1900.0 * math.exp(-t * 3.8) + 340.0, q=0.85)
	mix_stereo(out_l, out_r, [impact_dust[i] * env_ad(i / RATE, 0.52, 0.002, 1.7) for i in range(len(impact_dust))], 0, 1.15, pan=0.0)

	# Тяжёлый отскок ствола через ~0.16 с
	bounce = drum_hit(92.0, 36.0, 0.28, slap=0.4, body_decay=2.0, seed=413)
	mix_stereo(out_l, out_r, bounce, int(RATE * 0.16), 0.52, pan=-0.1)

	# Разлетающиеся щепки и сухие ветки в стерео (ощутимый хруст)!
	rng = random.Random(415)
	for k in range(13):
		st = rng.uniform(0.01, 0.48)
		fc = rng.uniform(850.0, 2900.0)
		pan = rng.uniform(-0.8, 0.8)
		amp = (1.0 - st * 1.2) * rng.uniform(0.65, 1.05)
		sn = int(RATE * 0.055)
		crack = biquad(make_noise(sn, 420 + k), "bp", fc, 2.1)
		wood = modal_hit([(fc * 0.45, 0.65, 3.6), (fc * 0.85, 0.45, 4.2)], 0.055, 0.3, fc, 440 + k)
		mix_stereo(out_l, out_r, [crack[j] * env_ad(j / RATE, 0.055, 0.001, 2.5) for j in range(sn)], int(RATE * st), amp * 1.15, pan=pan)
		mix_stereo(out_l, out_r, wood, int(RATE * st), amp * 0.7, pan=pan)

	out_l = saturate(out_l, 1.55)
	out_r = saturate(out_r, 1.55)
	l, r = reverb_stereo(out_l, out_r, wet=0.26, room=0.58, damp=0.42, predelay_ms=14.0)
	return (fade_edges(l, 1.0, 40.0), fade_edges(r, 1.0, 40.0)), -1.0


def snd_barrel_creak():
	"""Бочка раздувается перед взрывом (0.20 с): скрип клёпки и натяжение обручей."""
	dur = 0.21
	n = int(RATE * dur)
	out = [0.0] * n
	phase = 0.0
	for i in range(n):
		t = i / RATE
		f = 135.0 + 170.0 * ((t / dur) ** 1.3)
		phase = (phase + f / RATE) % 1.0
		out[i] = math.tanh((phase * 2.0 - 1.0) * 1.5) * env_ad(t, dur, 0.01, 1.1)
	creak = biquad_sweep(out, "bp", lambda t: 380.0 + 950.0 * (t / dur), q=2.5)
	snap = biquad(make_noise(int(RATE * 0.04), 451), "bp", 1800.0, 1.8)
	mix_into(creak, [snap[j] * env_ad(j / RATE, 0.04, 0.001, 2.6) for j in range(len(snap))], int(RATE * 0.16), 0.75)
	return (fade_edges(creak, 2.0, 10.0),), -4.0


def snd_barrel_roll():
	"""Перекатывание деревянной бочки по плитам."""
	dur = 0.34
	n = int(RATE * dur)
	rumble = biquad(pink_noise(n, 455), "bp", 130.0, 1.1)
	out_l = [rumble[i] * math.sin(math.pi * i / n) * 0.75 for i in range(n)]
	out_r = list(out_l)
	for idx, st in enumerate([0.02, 0.095, 0.175, 0.255]):
		tap = modal_hit([(175.0 + idx * 14.0, 0.7, 3.6), (340.0, 0.45, 4.2)], 0.075, 0.3, 1200.0, 460 + idx)
		pan = -0.3 + idx * 0.2
		mix_stereo(out_l, out_r, tap, int(RATE * st), 0.85, pan=pan)
	l, r = reverb_stereo(out_l, out_r, wet=0.14, room=0.35, damp=0.5)
	return (fade_edges(l, 2.0, 16.0), fade_edges(r, 2.0, 16.0)), -5.0


def snd_wood_break():
	"""Поломка мостков или частокола: хрусткий тройной треск досок с телом."""
	dur = 0.34
	n = int(RATE * dur)
	out_l = [0.0] * n
	out_r = [0.0] * n
	thump = drum_hit(140.0, 52.0, 0.14, slap=0.4, body_decay=2.5, seed=469)
	mix_stereo(out_l, out_r, thump, 0, 0.7, pan=0.0)
	for idx, (st, fc, pan) in enumerate([(0.0, 1150.0, -0.2), (0.048, 1750.0, 0.25), (0.105, 860.0, -0.1)]):
		cn = int(RATE * 0.08)
		snaps = biquad(make_noise(cn, 470 + idx), "bp", fc, 1.6)
		wood = modal_hit([(fc * 0.34, 0.75, 3.0), (fc * 0.68, 0.45, 3.6)], 0.11, 0.35, fc, 475 + idx)
		mix_stereo(out_l, out_r, [snaps[j] * env_ad(j / RATE, 0.08, 0.001, 2.2) for j in range(cn)], int(RATE * st), 0.95, pan=pan)
		mix_stereo(out_l, out_r, wood, int(RATE * st), 0.9, pan=pan)
	l, r = reverb_stereo(out_l, out_r, wet=0.18, room=0.42, damp=0.45)
	return (fade_edges(l, 1.0, 18.0), fade_edges(r, 1.0, 18.0)), -2.5


def snd_reeds_burn():
	"""Вспышка и сухое потрескивание сгорающего камыша."""
	dur = 0.42
	n = int(RATE * dur)
	rng = random.Random(480)
	whoosh = biquad_sweep(pink_noise(n, 481), "bp", lambda t: 850.0 + 950.0 * math.exp(-t * 4.0), q=1.0)
	out = [whoosh[i] * env_ad(i / RATE, dur, 0.015, 1.5) * 1.15 for i in range(n)]
	for k in range(14):
		st = rng.uniform(0.01, 0.34)
		cn = int(RATE * 0.022)
		pop = biquad(make_noise(cn, 490 + k), "bp", rng.uniform(1600.0, 3200.0), 1.4)
		mix_into(out, [pop[j] * env_ad(j / RATE, 0.022, 0.0005, 2.8) for j in range(cn)], int(RATE * st), rng.uniform(0.5, 1.0))
	l, r = reverb_stereo(out, wet=0.16, room=0.38, damp=0.45)
	return (fade_edges(l, 2.0, 22.0), fade_edges(r, 2.0, 22.0)), -3.5


def snd_explosion():
	"""Сочный взрыв бочки / метеора: хлёсткий удар + саб-бас + яркий выброс огня и осколков."""
	dur = 0.78
	n = int(RATE * dur)
	sub = drum_hit(132.0, 31.0, 0.46, slap=0.7, body_decay=1.65, seed=501)
	punch_mid = biquad_sweep(pink_noise(n, 502), "bp", lambda t: 1850.0 * math.exp(-t * 4.2) + 280.0, q=0.8)
	blast_low = biquad_sweep(pink_noise(n, 504), "lp", lambda t: 1200.0 * math.exp(-t * 5.0) + 140.0, q=0.7)
	out_l = [0.0] * n
	out_r = [0.0] * n
	mix_stereo(out_l, out_r, sub, 0, 0.82, pan=0.0)
	mix_stereo(out_l, out_r, [blast_low[i] * env_ad(i / RATE, dur, 0.002, 1.8) for i in range(n)], 0, 0.80, pan=0.0)
	mix_stereo(out_l, out_r, [punch_mid[i] * env_ad(i / RATE, dur, 0.002, 1.55) for i in range(n)], 0, 1.35, pan=0.0)

	# Осколки и искры взрыва по бокам
	rng = random.Random(503)
	for k in range(11):
		st = rng.uniform(0.015, 0.36)
		pan = rng.uniform(-0.85, 0.85)
		fc = rng.uniform(1000.0, 3100.0)
		dn = int(RATE * 0.045)
		frag = biquad(make_noise(dn, 510 + k), "bp", fc, 1.6)
		mix_stereo(out_l, out_r, [frag[j] * env_ad(j / RATE, 0.045, 0.001, 2.4) for j in range(dn)], int(RATE * st), 0.95, pan=pan)

	out_l = saturate(out_l, 1.6)
	out_r = saturate(out_r, 1.6)
	l, r = reverb_stereo(out_l, out_r, wet=0.25, room=0.58, damp=0.45, predelay_ms=12.0)
	return (fade_edges(l, 1.0, 35.0), fade_edges(r, 1.0, 35.0)), -1.0


# ==============================================================================
# 5. СТИХИИ, РЕАКЦИИ, РУНЫ И ДУХИ
# ==============================================================================

def snd_fire():
	"""Живая вспышка огня: хлопок воспламенения + густой жар пламени + треск углей."""
	dur = 0.54
	n = int(RATE * dur)
	rng = random.Random(550)
	roar = biquad_sweep(pink_noise(n, 551), "lp", lambda t: 2400.0 * math.exp(-t * 3.8) + 320.0, q=0.9)
	flame = biquad(pink_noise(n, 552), "bp", 920.0, 1.0)
	thump = drum_hit(140.0, 44.0, 0.18, slap=0.35, body_decay=2.0, seed=553)
	out_l = [0.0] * n
	out_r = [0.0] * n
	mix_stereo(out_l, out_r, thump, 0, 0.85, pan=0.0)
	for i in range(n):
		t = i / RATE
		env = env_ad(t, dur, 0.012, 1.4)
		val = (roar[i] * 0.95 + flame[i] * 0.55) * env
		out_l[i] += val
		out_r[i] += val
	for k in range(10):
		st = rng.uniform(0.04, 0.42)
		cn = int(RATE * 0.02)
		pop = biquad(make_noise(cn, 560 + k), "hp", 3100.0, 1.1)
		mix_stereo(out_l, out_r, [pop[j] * env_ad(j / RATE, 0.02, 0.0005, 3.0) for j in range(cn)],
				   int(RATE * st), rng.uniform(0.35, 0.75), pan=rng.uniform(-0.6, 0.6))
	l, r = reverb_stereo(out_l, out_r, wet=0.20, room=0.48, damp=0.45)
	return (fade_edges(l, 2.0, 28.0), fade_edges(r, 2.0, 28.0)), -2.0


def snd_water():
	"""Накатывающая волна воды: сочный перекат + пузыри + брызги."""
	dur = 0.48
	n = int(RATE * dur)
	rng = random.Random(570)
	surge = biquad_sweep(pink_noise(n, 571), "bp", lambda t: 360.0 + 1350.0 * math.sin(math.pi * clamp(t / dur, 0.0, 1.0)) ** 0.9, q=1.2)
	foam = biquad(pink_noise(n, 572), "hp", 1600.0, 0.8)
	out_l = [0.0] * n
	out_r = [0.0] * n
	for i in range(n):
		t = i / RATE
		env = env_ad(t, dur, 0.022, 1.5)
		out_l[i] = (surge[i] * 1.15 + foam[i] * 0.35) * env
		out_r[i] = out_l[i]
	for k in range(8):
		st = rng.uniform(0.03, 0.36)
		bn = int(RATE * 0.045)
		f0 = rng.uniform(260.0, 620.0)
		phase = 0.0
		bub = [0.0] * bn
		for j in range(bn):
			bt = j / RATE
			phase += TWO_PI * (f0 + 360.0 * (bt / 0.045)) / RATE
			bub[j] = math.sin(phase) * env_ad(bt, 0.045, 0.003, 2.2) * 0.45
		mix_stereo(out_l, out_r, bub, int(RATE * st), 0.75, pan=rng.uniform(-0.65, 0.65))
	l, r = reverb_stereo(out_l, out_r, wet=0.22, room=0.5, damp=0.4)
	return (fade_edges(l, 3.0, 26.0), fade_edges(r, 3.0, 26.0)), -3.0


def snd_ice():
	"""Заморозка: звонкий кристальный звон и морозный хруст."""
	dur = 0.45
	chimes = modal_hit(
		[(1174.66, 0.45, 2.0), (1760.0, 0.38, 2.3), (2349.32, 0.3, 2.6), (3135.96, 0.24, 3.0), (4186.0, 0.16, 3.5)],
		dur,
		click_gain=0.25,
		click_fc=4200.0,
		seed=580,
	)
	frost = biquad_sweep(make_noise(int(RATE * 0.22), 581), "hp", lambda t: 2200.0 + 3000.0 * (t / 0.22), q=1.0)
	out = [0.0] * int(RATE * dur)
	mix_into(out, chimes, 0, 0.85)
	mix_into(out, [frost[i] * env_ad(i / RATE, 0.22, 0.004, 2.0) for i in range(len(frost))], 0, 0.55)
	l, r = reverb_stereo(out, wet=0.28, room=0.58, damp=0.25)
	return (fade_edges(l, 2.0, 24.0), fade_edges(r, 2.0, 24.0)), -3.5


def snd_ice_break():
	"""Раскол льда: острый хруст и разлетающиеся хрустальные осколки."""
	dur = 0.42
	n = int(RATE * dur)
	rng = random.Random(585)
	crack = biquad(make_noise(int(RATE * 0.06), 586), "hp", 2600.0, 0.9)
	out_l = [0.0] * n
	out_r = [0.0] * n
	mix_stereo(out_l, out_r, [crack[i] * env_ad(i / RATE, 0.06, 0.0008, 2.5) for i in range(len(crack))], 0, 0.95, pan=0.0)
	for k in range(7):
		st = rng.uniform(0.005, 0.20)
		f = rng.uniform(1350.0, 3600.0)
		shard = modal_hit([(f, 0.55, 3.2), (f * 1.48, 0.35, 3.8)], 0.16, 0.2, 4200.0, 590 + k)
		mix_stereo(out_l, out_r, shard, int(RATE * st), 0.6, pan=rng.uniform(-0.8, 0.8))
	l, r = reverb_stereo(out_l, out_r, wet=0.24, room=0.52, damp=0.28)
	return (fade_edges(l, 1.0, 22.0), fade_edges(r, 1.0, 22.0)), -3.0


def snd_lightning():
	"""Молния: мгновенный электрический кнут-треск + дуговые щелчки + раскат грома."""
	dur = 0.65
	n = int(RATE * dur)
	out_l = [0.0] * n
	out_r = [0.0] * n

	# Хлесткий электрический разряд в начале (два прыжка дуги!)
	arc_n = int(RATE * 0.24)
	noise = make_noise(arc_n, 601)
	arc = [0.0] * arc_n
	phase = 0.0
	for i in range(arc_n):
		t = i / RATE
		# Частотная модуляция для "трескающего" разряда
		f = (780.0 * math.exp(-t * 10.0) + 120.0) * (1.0 + 0.48 * math.sin(TWO_PI * 95.0 * t))
		phase += TWO_PI * f / RATE
		snap = math.tanh(math.sin(phase) * 2.6 + noise[i] * 1.6)
		gate = 1.0 if (t < 0.055 or (0.075 < t < 0.14)) else 0.45
		arc[i] = snap * env_ad(t, 0.24, 0.0008, 1.9) * gate
	arc_filt = biquad(arc, "peaking" if False else "hp", 180.0, 0.7)

	# Глубокий раскат грома следом
	thunder_raw = biquad_sweep(pink_noise(n, 602), "lp", lambda t: 520.0 * math.exp(-t * 2.8) + 95.0, q=0.9)
	thunder_sub = drum_hit(130.0, 32.0, 0.45, slap=0.35, body_decay=1.4, seed=603)

	mix_stereo(out_l, out_r, arc_filt, 0, 0.95, pan=-0.15)
	mix_stereo(out_l, out_r, thunder_sub, int(RATE * 0.015), 0.95, pan=0.0)
	mix_stereo(out_l, out_r, [thunder_raw[i] * env_ad(i / RATE, dur, 0.025, 1.3) for i in range(n)], int(RATE * 0.02), 1.1, pan=0.1)

	out_l = saturate(out_l, 1.4)
	out_r = saturate(out_r, 1.4)
	l, r = reverb_stereo(out_l, out_r, wet=0.28, room=0.68, damp=0.45, predelay_ms=16.0)
	return (fade_edges(l, 1.0, 35.0), fade_edges(r, 1.0, 35.0)), -1.2


def snd_steam():
	"""Пар (огонь на воде): мягкий хлопок и длинное шипящее облако давления."""
	dur = 0.46
	n = int(RATE * dur)
	pop = drum_hit(175.0, 74.0, 0.09, slap=0.25, body_decay=2.8, seed=610)
	hiss = biquad_sweep(pink_noise(n, 611), "bp", lambda t: 2200.0 - 950.0 * (t / dur), q=1.0)
	body = biquad(pink_noise(n, 613), "bp", 1250.0, 1.2)
	air = biquad(make_noise(n, 612), "hp", 3100.0, 0.8)
	out = [0.0] * n
	mix_into(out, pop, 0, 0.48)
	for i in range(n):
		t = i / RATE
		out[i] += (hiss[i] * 1.15 + body[i] * 0.75 + air[i] * 0.25) * env_ad(t, dur, 0.008, 1.45)
	l, r = reverb_stereo(out, wet=0.22, room=0.48, damp=0.35)
	return (fade_edges(l, 2.0, 26.0), fade_edges(r, 2.0, 26.0)), -3.0


def snd_lava():
	"""Лава (огонь на трясине): густое кипение и тяжелые вязкие пузыри магмы."""
	dur = 0.56
	n = int(RATE * dur)
	rumble = biquad(pink_noise(n, 615), "lp", 340.0, 1.0)
	sizzle = biquad(pink_noise(n, 616), "bp", 1500.0, 1.4)
	out = [(rumble[i] * 0.95 + sizzle[i] * 0.4) * env_ad(i / RATE, dur, 0.02, 1.3) for i in range(n)]
	for start, f0 in [(0.04, 110.0), (0.19, 138.0), (0.33, 98.0)]:
		bn = int(RATE * 0.11)
		phase = 0.0
		bub = [0.0] * bn
		for j in range(bn):
			bt = j / RATE
			phase += TWO_PI * (f0 + 180.0 * (bt / 0.11)) / RATE
			bub[j] = math.tanh(math.sin(phase) * 1.4) * env_ad(bt, 0.11, 0.008, 2.0) * 0.55
		mix_into(out, bub, int(RATE * start), 0.8)
	l, r = reverb_stereo(out, wet=0.22, room=0.52, damp=0.55)
	return (fade_edges(l, 3.0, 30.0), fade_edges(r, 3.0, 30.0)), -3.0


def snd_crust():
	"""Корка (вода на лаве): быстрое шипение и каменное застывание с сухим треском."""
	dur = 0.44
	n = int(RATE * dur)
	hiss = biquad_sweep(pink_noise(n, 620), "hp", lambda t: 2400.0 - 1500.0 * (t / dur), q=0.9)
	stone = modal_hit([(310.0, 0.6, 2.5), (540.0, 0.42, 3.0), (890.0, 0.25, 3.8)], 0.24, 0.35, 1900.0, 621)
	out = [hiss[i] * env_ad(i / RATE, 0.26, 0.005, 1.8) * 0.75 for i in range(n)]
	mix_into(out, stone, int(RATE * 0.11), 0.85)
	l, r = reverb_stereo(out, wet=0.20, room=0.45, damp=0.45)
	return (fade_edges(l, 2.0, 22.0), fade_edges(r, 2.0, 22.0)), -3.5


def snd_gas_cloud():
	"""Облако ядовитого газа: вязкое едкое шипение и тихий ядовитый бульк."""
	dur = 0.45
	n = int(RATE * dur)
	hiss = biquad_sweep(pink_noise(n, 625), "bp", lambda t: 680.0 + 520.0 * math.sin(math.pi * clamp(t / dur, 0.0, 1.0)), q=2.2)
	fizz = biquad(make_noise(n, 626), "bp", 2600.0, 1.6)
	out = [(hiss[i] * 1.1 + fizz[i] * 0.3) * env_ad(i / RATE, dur, 0.025, 1.4) for i in range(n)]
	l, r = reverb_stereo(out, wet=0.20, room=0.48, damp=0.42)
	return (fade_edges(l, 4.0, 28.0), fade_edges(r, 4.0, 28.0)), -5.0


def snd_wind_gust():
	"""Порыв ветра (Вихорь): широкий воздушный вихрь с движением слева направо."""
	dur = 0.48
	n = int(RATE * dur)
	w_l = biquad_sweep(pink_noise(n, 630), "bp", lambda t: 380.0 + 1080.0 * math.sin(math.pi * clamp(t / dur, 0.0, 1.0)) ** 0.85, q=1.6)
	w_r = biquad_sweep(pink_noise(n, 631), "bp", lambda t: 440.0 + 1080.0 * math.sin(math.pi * clamp(t / dur, 0.0, 1.0)) ** 0.85, q=1.6)
	body = biquad(pink_noise(n, 632), "bp", 720.0, 1.0)
	out_l = [0.0] * n
	out_r = [0.0] * n
	for i in range(n):
		t = i / RATE
		env = env_ad(t, dur, 0.035, 1.3)
		pan_t = clamp(t / dur, 0.0, 1.0)
		out_l[i] = (w_l[i] * 1.25 + body[i] * 0.55) * env * (1.2 - 0.5 * pan_t)
		out_r[i] = (w_r[i] * 1.25 + body[i] * 0.55) * env * (0.7 + 0.5 * pan_t)
	l, r = reverb_stereo(out_l, out_r, wet=0.22, room=0.5, damp=0.38)
	return (fade_edges(l, 5.0, 30.0), fade_edges(r, 5.0, 30.0)), -2.5


def snd_bog_cast():
	"""Магия Хозяина трясины: хруст переплетающихся корней и вязкая жижа."""
	dur = 0.44
	n = int(RATE * dur)
	sludge = biquad_sweep(pink_noise(n, 635), "bp", lambda t: 280.0 + 380.0 * (t / dur), q=2.6)
	out_l = [sludge[i] * env_ad(i / RATE, dur, 0.02, 1.5) for i in range(n)]
	out_r = list(out_l)
	for idx, (st, fc, pan) in enumerate([(0.02, 740.0, -0.3), (0.09, 980.0, 0.25), (0.16, 620.0, -0.15)]):
		cn = int(RATE * 0.05)
		snap = biquad(make_noise(cn, 638 + idx), "bp", fc, 2.4)
		mix_stereo(out_l, out_r, [snap[j] * env_ad(j / RATE, 0.05, 0.002, 2.4) for j in range(cn)], int(RATE * st), 0.85, pan=pan)
	l, r = reverb_stereo(out_l, out_r, wet=0.20, room=0.45, damp=0.5)
	return (fade_edges(l, 3.0, 26.0), fade_edges(r, 3.0, 26.0)), -4.0


def snd_rune_cast():
	"""Наложение руны на клинок или землю: острый звон гравировки по стали."""
	dur = 0.34
	chime = modal_hit([(784.0, 0.5, 2.2), (1174.66, 0.45, 2.5), (1975.53, 0.3, 3.0), (2637.0, 0.2, 3.8)], dur, 0.2, 3600.0, 640)
	l, r = reverb_stereo(chime, wet=0.24, room=0.5, damp=0.3)
	return (fade_edges(l, 1.5, 22.0), fade_edges(r, 1.5, 22.0)), -4.5


def snd_rune_trap():
	"""Взрыв сторожевой руны: серебристый разряд + плотный хлопок."""
	dur = 0.46
	pop = drum_hit(185.0, 48.0, 0.24, slap=0.5, body_decay=2.1, seed=645)
	ring = modal_hit([(987.77, 0.55, 2.0), (1480.0, 0.45, 2.4), (2489.0, 0.32, 3.0)], dur, 0.3, 3400.0, 646)
	out = [0.0] * int(RATE * dur)
	mix_into(out, pop, 0, 0.9)
	mix_into(out, ring, 0, 0.75)
	l, r = reverb_stereo(out, wet=0.26, room=0.55, damp=0.32)
	return (fade_edges(l, 1.0, 24.0), fade_edges(r, 1.0, 24.0)), -2.5


def snd_magic():
	"""Заклинание / бафф / аркана: тёплый переливчатый аккорд с мерцанием."""
	dur = 0.42
	n = int(RATE * dur)
	notes = [440.0, 554.37, 659.25, 880.0]
	out_l = [0.0] * n
	out_r = [0.0] * n
	for idx, f in enumerate(notes):
		part = modal_hit([(f, 0.45, 1.8), (f * 2.0, 0.16, 2.6)], dur - idx * 0.02, 0.05, 2600.0, 650 + idx)
		mix_stereo(out_l, out_r, part, int(RATE * idx * 0.022), 0.7, pan=-0.35 + idx * 0.23)
	l, r = reverb_stereo(out_l, out_r, wet=0.28, room=0.54, damp=0.32)
	return (fade_edges(l, 3.0, 28.0), fade_edges(r, 3.0, 28.0)), -4.5


def snd_absorb_magic():
	"""Поглощение магии / передача венца: мягкий восходяще-нисходящий переток энергии."""
	dur = 0.38
	n = int(RATE * dur)
	whoosh = biquad_sweep(pink_noise(n, 660), "bp", lambda t: 450.0 + 1300.0 * math.sin(math.pi * t / dur), q=2.6)
	out = [whoosh[i] * env_ad(i / RATE, dur, 0.03, 1.6) * 0.75 for i in range(n)]
	tone = modal_hit([(523.25, 0.35, 2.0), (783.99, 0.3, 2.4)], dur, 0.05, 2000.0, 661)
	mix_into(out, tone, int(RATE * 0.04), 0.6)
	l, r = reverb_stereo(out, wet=0.25, room=0.5, damp=0.35)
	return (fade_edges(l, 4.0, 24.0), fade_edges(r, 4.0, 24.0)), -6.0


def snd_summon():
	"""Появление врага из бирюзового разрыва: нарастающий свип и низкий удар."""
	dur = 0.48
	n = int(RATE * dur)
	riser = biquad_sweep(pink_noise(n, 670), "bp", lambda t: 220.0 + 1600.0 * ((t / dur) ** 1.8), q=2.5)
	thump = drum_hit(140.0, 42.0, 0.24, slap=0.3, body_decay=2.0, seed=671)
	rift = modal_hit([(311.13, 0.4, 2.0), (466.16, 0.35, 2.3), (740.0, 0.25, 2.8)], 0.35, 0.1, 2400.0, 672)
	out = [riser[i] * (clamp((i / RATE) / 0.26, 0.0, 1.0) ** 1.4) * env_ad(i / RATE, dur, 0.01, 1.3) for i in range(n)]
	mix_into(out, thump, int(RATE * 0.16), 0.8)
	mix_into(out, rift, int(RATE * 0.16), 0.7)
	l, r = reverb_stereo(out, wet=0.28, room=0.6, damp=0.38)
	return (fade_edges(l, 4.0, 30.0), fade_edges(r, 4.0, 30.0)), -4.0


def snd_spirit_tame():
	"""Покорение духа: светлое переливчатое созвучие и чистый небесный звон."""
	dur = 0.90
	n = int(RATE * dur)
	notes = [(0.0, 440.0, -0.35), (0.07, 523.25, -0.1), (0.14, 659.25, 0.15), (0.22, 880.0, 0.35), (0.31, 1046.5, 0.0)]
	out_l = [0.0] * n
	out_r = [0.0] * n
	for idx, (st, f, pan) in enumerate(notes):
		part = modal_hit([(f, 0.55, 1.5), (f * 2.0, 0.25, 2.1), (f * 3.0, 0.1, 2.8)], dur - st, 0.06, 2800.0, 680 + idx)
		mix_stereo(out_l, out_r, part, int(RATE * st), 0.75, pan=pan)
	l, r = reverb_stereo(out_l, out_r, wet=0.36, room=0.68, damp=0.28)
	return (fade_edges(l, 3.0, 45.0), fade_edges(r, 3.0, 45.0)), -3.0


# ==============================================================================
# 6. СМЕРТЬ, ЛЕЧЕНИЕ, МОНЕТЫ, ХАБ И ФАНФАРЫ
# ==============================================================================

def snd_death():
	"""Общий звук гибели (совместимость) / растворение врага в пепел и бирюзу."""
	dur = 0.44
	n = int(RATE * dur)
	out = [0.0] * n
	fall = drum_hit(180.0, 42.0, 0.28, slap=0.3, body_decay=1.8, seed=701)
	ash = biquad_sweep(pink_noise(n, 702), "bp", lambda t: 1500.0 * math.exp(-t * 4.5) + 220.0, q=1.3)
	mix_into(out, fall, 0, 0.85)
	for i in range(n):
		out[i] += ash[i] * env_ad(i / RATE, dur, 0.015, 1.5) * 0.75
	l, r = reverb_stereo(out, wet=0.22, room=0.5, damp=0.45)
	return (fade_edges(l, 2.0, 26.0), fade_edges(r, 2.0, 26.0)), -3.5


def snd_death_hero():
	"""Падение героя: тяжёлый стук лат/тела и низкий скорбный отзвук."""
	dur = 0.58
	n = int(RATE * dur)
	thud = drum_hit(140.0, 36.0, 0.34, slap=0.55, body_decay=1.6, seed=705)
	plate = modal_hit([(290.0, 0.4, 2.6), (440.0, 0.28, 3.2), (710.0, 0.16, 4.0)], 0.30, 0.35, 1600.0, 706)
	out = [0.0] * n
	mix_into(out, thud, 0, 1.0)
	mix_into(out, plate, int(RATE * 0.02), 0.55)
	l, r = reverb_stereo(out, wet=0.26, room=0.56, damp=0.48)
	return (fade_edges(l, 1.5, 30.0), fade_edges(r, 1.5, 30.0)), -2.5


def snd_turn():
	"""Конец хода: сдержанный благородный удар боевого гонга."""
	dur = 0.42
	gong = modal_hit([(196.0, 0.65, 1.9), (293.66, 0.4, 2.2), (415.0, 0.22, 2.7), (587.33, 0.12, 3.2)], dur, 0.2, 1100.0, 710)
	thump = drum_hit(115.0, 52.0, 0.18, slap=0.2, body_decay=2.5, seed=711)
	out = [0.0] * int(RATE * dur)
	mix_into(out, gong, 0, 0.8)
	mix_into(out, thump, 0, 0.65)
	l, r = reverb_stereo(out, wet=0.26, room=0.56, damp=0.4)
	return (fade_edges(l, 2.0, 28.0), fade_edges(r, 2.0, 28.0)), -4.5


def snd_heal():
	"""Лечение (привал, родник, карта): тёплый перебор лютни и чистое созвучие."""
	dur = 0.68
	n = int(RATE * dur)
	out_l = [0.0] * n
	out_r = [0.0] * n
	notes = [(0.0, 392.0, -0.3), (0.09, 493.88, -0.1), (0.18, 587.33, 0.1), (0.27, 783.99, 0.3)]
	for idx, (st, f, pan) in enumerate(notes):
		pl = ks_pluck(f, dur - st, brightness=0.52, decay=0.9965, pick_pos=0.28, seed=720 + idx)
		fl = flute_note(f * 2.0, max(0.25, dur - st - 0.04), breath=0.06, attack=0.06)
		mix_stereo(out_l, out_r, pl, int(RATE * st), 0.75, pan=pan)
		mix_stereo(out_l, out_r, fl, int(RATE * st), 0.18, pan=pan)
	l, r = reverb_stereo(out_l, out_r, wet=0.30, room=0.58, damp=0.35)
	return (fade_edges(l, 3.0, 35.0), fade_edges(r, 3.0, 35.0)), -4.5


def snd_coin():
	"""Золото и обереги: звон настоящих металлических монет."""
	dur = 0.42
	n = int(RATE * dur)
	out_l = [0.0] * n
	out_r = [0.0] * n
	c1 = modal_hit([(2217.46, 0.65, 2.4), (3322.44, 0.45, 2.9), (4978.0, 0.25, 3.6)], 0.32, 0.35, 5200.0, 730)
	c2 = modal_hit([(2637.02, 0.65, 2.3), (3951.07, 0.45, 2.8), (5890.0, 0.25, 3.5)], 0.32, 0.35, 5600.0, 731)
	mix_stereo(out_l, out_r, c1, 0, 0.85, pan=-0.2)
	mix_stereo(out_l, out_r, c2, int(RATE * 0.072), 0.95, pan=0.22)
	l, r = reverb_stereo(out_l, out_r, wet=0.20, room=0.42, damp=0.3)
	return (fade_edges(l, 1.0, 22.0), fade_edges(r, 1.0, 22.0)), -4.5


def snd_bell():
	"""Колокол Стражи: глубокий, торжественный, дрожащий медный благовест с богатым хвостом."""
	dur = 2.40
	n = int(RATE * dur)
	# Настоящие минорные обертоны церковного/крепостного колокола (G3)
	partials = [
		(98.00, 0.35, 1.15),   # гул-унтертон G2
		(196.00, 0.68, 1.30),  # основной G3
		(392.00, 0.50, 1.65),  # октава G4
		(466.16, 0.38, 1.95),  # малая терция Bb4 (характер колокола!)
		(587.33, 0.30, 2.35),  # квинта D5
		(784.00, 0.20, 3.00),  # двойная октава G5
		(1046.5, 0.11, 3.80),  # обертон C6
		(1318.5, 0.06, 4.60),  # обертон E6
	]
	out = [0.0] * n
	sin = math.sin
	for freq, amp, dec in partials:
		# Лёгкое биение пары чуть расстроенных мод литой бронзы
		w1 = TWO_PI * freq / RATE
		w2 = TWO_PI * (freq * 1.0018) / RATE
		for i in range(n):
			t = i / RATE
			e = env_ad(t, dur, 0.0025, dec)
			out[i] += amp * (0.68 * sin(w1 * i) + 0.32 * sin(w2 * i)) * e
	# Тяжёлый удар языка колокола по бронзе
	clapper = drum_hit(155.0, 58.0, 0.14, slap=0.5, body_decay=2.8, seed=740)
	mix_into(out, clapper, 0, 0.65)
	l, r = reverb_stereo(out, wet=0.34, room=0.76, damp=0.38, predelay_ms=18.0)
	return (fade_edges(l, 1.5, 80.0), fade_edges(r, 1.5, 80.0)), -1.5


def snd_door():
	"""Тяжёлая дверь Караульни: деревянный скрип петель и плотный щелчок засова."""
	dur = 0.42
	n = int(RATE * dur)
	out = [0.0] * n
	phase = 0.0
	for i in range(n):
		t = i / RATE
		if t < 0.28:
			# Неровный живой скрип дерева
			f = 128.0 + 38.0 * math.sin(TWO_PI * 11.0 * t) - 22.0 * (t / 0.28)
			phase = (phase + f / RATE) % 1.0
			raw = math.tanh((phase * 2.0 - 1.0) * 1.9)
			out[i] = raw * env_ad(t, 0.28, 0.02, 1.4) * 0.55
	out = biquad(out, "bp", 520.0, 1.4)
	latch = modal_hit([(220.0, 0.65, 3.2), (460.0, 0.45, 4.0), (880.0, 0.22, 4.8)], 0.14, 0.45, 1600.0, 745)
	mix_into(out, latch, int(RATE * 0.24), 0.9)
	l, r = reverb_stereo(out, wet=0.18, room=0.45, damp=0.45)
	return (fade_edges(l, 2.0, 22.0), fade_edges(r, 2.0, 22.0)), -4.5


def snd_victory():
	"""Победа в бою: светлый торжественный аккорд рогов Стражи и перезвон колокольчика на мотиве Д-дорийского лада."""
	dur = 1.65
	n = int(RATE * dur)
	out_l = [0.0] * n
	out_r = [0.0] * n
	bass = brass_note(146.83, dur, attack=0.10, bright=0.6)   # глубокая басовая опора D3
	mix_stereo(out_l, out_r, bass, 0, 0.52, pan=0.0)
	seq = [(0.0, 293.66, -0.35), (0.14, 349.23, -0.15), (0.28, 440.00, 0.15), (0.44, 587.33, 0.35)]
	for idx, (st, f, pan) in enumerate(seq):
		hrn = brass_note(f, dur - st, attack=0.08, bright=0.95)
		plk = ks_pluck(f, dur - st, brightness=0.72, decay=0.997, seed=750 + idx)
		mix_stereo(out_l, out_r, hrn, int(RATE * st), 0.42, pan=pan)
		mix_stereo(out_l, out_r, plk, int(RATE * st), 0.55, pan=-pan * 0.6)
	# Финальный чистый обертон колокола сверху
	bell_top = modal_hit([(587.33, 0.45, 1.5), (880.0, 0.3, 1.9), (1174.66, 0.2, 2.4)], 1.15, 0.1, 2400.0, 755)
	mix_stereo(out_l, out_r, bell_top, int(RATE * 0.44), 0.55, pan=0.0)
	l, r = reverb_stereo(out_l, out_r, wet=0.36, room=0.72, damp=0.34, predelay_ms=18.0)
	return (fade_edges(l, 3.0, 90.0), fade_edges(r, 3.0, 90.0)), -2.0


def snd_defeat():
	"""Поражение: низкий нисходящий рог и отдалённый скорбный удар Колокола."""
	dur = 1.75
	n = int(RATE * dur)
	out_l = [0.0] * n
	out_r = [0.0] * n
	seq = [(0.0, 220.00, 0.9), (0.28, 196.00, 0.8), (0.56, 164.81, 0.9), (0.84, 146.83, 0.9)]
	for idx, (st, f, ln) in enumerate(seq):
		horn = brass_note(f, min(ln, dur - st), attack=0.11, bright=0.45)
		mix_stereo(out_l, out_r, horn, int(RATE * st), 0.55, pan=-0.2 + idx * 0.12)
	low_bell = modal_hit([(146.83, 0.6, 1.4), (220.0, 0.35, 1.8), (293.66, 0.25, 2.2)], 1.35, 0.15, 900.0, 760)
	mix_stereo(out_l, out_r, low_bell, int(RATE * 0.56), 0.65, pan=0.0)
	l, r = reverb_stereo(out_l, out_r, wet=0.38, room=0.74, damp=0.48, predelay_ms=20.0)
	return (fade_edges(l, 4.0, 100.0), fade_edges(r, 4.0, 100.0)), -2.0


# ==============================================================================
# СБОРНИК ВСЕХ ЭФФЕКТОВ
# ==============================================================================

def _v(fn, *args):
	return lambda: fn(*args)


SOUNDS = {
	# Обратно совместимые имена (обновлены в 44100 Гц)
	"ui_click": _v(snd_ui_click, 1),
	"ui_click_2": _v(snd_ui_click, 2),
	"ui_hover": snd_ui_hover,
	"card_select": snd_card_select,
	"card_cancel": snd_card_cancel,
	"card_play": snd_card_play,
	"card_keep": snd_card_keep,
	"card_scrap": snd_card_scrap,
	"chain_up": snd_chain_up,

	"step": _v(snd_step_stone, 1),
	"step_stone_1": _v(snd_step_stone, 1),
	"step_stone_2": _v(snd_step_stone, 2),
	"step_stone_3": _v(snd_step_stone, 3),
	"step_wood_1": _v(snd_step_wood, 1),
	"step_wood_2": _v(snd_step_wood, 2),
	"step_wood_3": _v(snd_step_wood, 3),
	"step_moss_1": _v(snd_step_moss, 1),
	"step_moss_2": _v(snd_step_moss, 2),
	"step_moss_3": _v(snd_step_moss, 3),
	"step_water_1": _v(snd_step_water, 1),
	"step_water_2": _v(snd_step_water, 2),
	"step_water_3": _v(snd_step_water, 3),
	"step_swamp_1": _v(snd_step_swamp, 1),
	"step_swamp_2": _v(snd_step_swamp, 2),
	"step_swamp_3": _v(snd_step_swamp, 3),
	"sink": snd_sink,

	"hit": _v(snd_sword_hit, 1),
	"sword_swing_1": _v(snd_sword_swing, 1),
	"sword_swing_2": _v(snd_sword_swing, 2),
	"sword_hit_1": _v(snd_sword_hit, 1),
	"sword_hit_2": _v(snd_sword_hit, 2),
	"sword_hit_3": _v(snd_sword_hit, 3),
	"heavy_hit_1": _v(snd_heavy_hit, 1),
	"heavy_hit_2": _v(snd_heavy_hit, 2),
	"pincer_hit": snd_pincer_hit,
	"staff_hit_1": _v(snd_staff_hit, 1),
	"staff_hit_2": _v(snd_staff_hit, 2),
	"block": _v(snd_block, 1),
	"block_2": _v(snd_block, 2),
	"shield_break": snd_shield_break,
	"push": snd_push,
	"bump": snd_bump,

	"enemy_bite_1": _v(snd_enemy_bite, 1),
	"enemy_bite_2": _v(snd_enemy_bite, 2),
	"enemy_club_1": _v(snd_enemy_club, 1),
	"enemy_club_2": _v(snd_enemy_club, 2),
	"enemy_spit_1": _v(snd_enemy_spit, 1),
	"enemy_spit_2": _v(snd_enemy_spit, 2),
	"enemy_buff": snd_enemy_buff,

	"tree_creak": snd_tree_creak,
	"tree_crash": snd_tree_crash,
	"barrel_creak": snd_barrel_creak,
	"barrel_roll": snd_barrel_roll,
	"wood_break": snd_wood_break,
	"reeds_burn": snd_reeds_burn,
	"explosion": snd_explosion,

	"fire": snd_fire,
	"water": snd_water,
	"ice": snd_ice,
	"ice_break": snd_ice_break,
	"lightning": snd_lightning,
	"steam": snd_steam,
	"lava": snd_lava,
	"crust": snd_crust,
	"gas_cloud": snd_gas_cloud,
	"wind_gust": snd_wind_gust,
	"bog_cast": snd_bog_cast,
	"rune_cast": snd_rune_cast,
	"rune_trap": snd_rune_trap,
	"magic": snd_magic,
	"absorb_magic": snd_absorb_magic,
	"summon": snd_summon,
	"spirit_tame": snd_spirit_tame,

	"death": snd_death,
	"death_hero": snd_death_hero,
	"turn": snd_turn,
	"heal": snd_heal,
	"coin": snd_coin,
	"bell": snd_bell,
	"door": snd_door,
	"victory": snd_victory,
	"defeat": snd_defeat,
}


def main():
	args = [a for a in sys.argv[1:] if not a.startswith("-")]
	flags = [a for a in sys.argv[1:] if a.startswith("-")]
	out_dir = args[0] if args else os.path.join(SRC_DIR, "..")
	os.makedirs(out_dir, exist_ok=True)
	for name, builder in SOUNDS.items():
		channels, peak_db = builder()
		out_path = os.path.join(out_dir, name + ".wav")
		if len(channels) == 1:
			save_wav(out_path, channels[0], peak_db=peak_db)
		else:
			save_wav(out_path, channels[0], channels[1], peak_db=peak_db)
	print("SFX собрано:", len(SOUNDS))
	if "--all" in flags:
		import build_music
		build_music.main(out_dir)


if __name__ == "__main__":
	main()

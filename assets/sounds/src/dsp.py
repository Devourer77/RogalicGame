# Чистый DSP-инструментарий на стандартной библиотеке Python для сборки звуков и музыки игры.
# Формат: 44100 Гц, 16-бит PCM (моно и стерео). Никаких внешних зависимостей не нужно.
import math
import os
import random
import struct
import wave

RATE = 44100
TWO_PI = 2.0 * math.pi


def clamp(x, lo=-1.0, hi=1.0):
	return lo if x < lo else (hi if x > hi else x)


def db_to_lin(db):
	return 10.0 ** (db / 20.0)


def make_noise(n, seed=42):
	rng = random.Random(seed)
	rand = rng.uniform
	return [rand(-1.0, 1.0) for _ in range(n)]


def pink_noise(n, seed=42):
	"""Тёплый 1/f розовый шум (алгоритм Пола Келлетта) — база для ветра, огня, воды и дождя."""
	rng = random.Random(seed)
	rand = rng.uniform
	b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0
	out = [0.0] * n
	for i in range(n):
		white = rand(-1.0, 1.0)
		b0 = 0.99886 * b0 + white * 0.0555179
		b1 = 0.99332 * b1 + white * 0.0750759
		b2 = 0.96900 * b2 + white * 0.1538520
		b3 = 0.86650 * b3 + white * 0.3104856
		b4 = 0.55000 * b4 + white * 0.5329522
		b5 = -0.7616 * b5 - white * 0.0168980
		out[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11
		b6 = white * 0.115926
	return out


def env_adsr(t, dur, attack=0.008, decay=0.06, sustain=0.6, release=0.08, curve=1.5):
	"""Плавная ADSR-огибающая без щелчков."""
	if t < 0.0 or t >= dur:
		return 0.0
	if attack > 0.0 and t < attack:
		return t / attack
	rel_start = max(attack, dur - release)
	if t >= rel_start:
		base = sustain
		if t < attack + decay and decay > 0.0:
			base = 1.0 - (1.0 - sustain) * ((t - attack) / decay)
		rem = 1.0 - (t - rel_start) / max(dur - rel_start, 1e-5)
		return base * (max(0.0, rem) ** curve)
	if decay > 0.0 and t < attack + decay:
		return 1.0 - (1.0 - sustain) * ((t - attack) / decay)
	return sustain


def env_ad(t, dur, attack=0.004, decay_pow=1.8):
	"""Ударная огибающая Attack-Decay."""
	if t < 0.0 or t >= dur:
		return 0.0
	if attack > 0.0 and t < attack:
		return t / attack
	rem = 1.0 - (t - attack) / max(dur - attack, 1e-5)
	return max(0.0, rem) ** decay_pow


def _biquad_coeffs(kind, fc, q=0.707, gain_db=0.0):
	fc = max(20.0, min(fc, RATE * 0.46))
	w0 = TWO_PI * fc / RATE
	cw = math.cos(w0)
	sw = math.sin(w0)
	alpha = sw / (2.0 * max(q, 0.05))
	if kind == "lp":
		b0 = (1.0 - cw) * 0.5
		b1 = 1.0 - cw
		b2 = (1.0 - cw) * 0.5
		a0 = 1.0 + alpha
		a1 = -2.0 * cw
		a2 = 1.0 - alpha
	elif kind == "hp":
		b0 = (1.0 + cw) * 0.5
		b1 = -(1.0 + cw)
		b2 = (1.0 + cw) * 0.5
		a0 = 1.0 + alpha
		a1 = -2.0 * cw
		a2 = 1.0 - alpha
	elif kind == "bp":
		b0 = alpha
		b1 = 0.0
		b2 = -alpha
		a0 = 1.0 + alpha
		a1 = -2.0 * cw
		a2 = 1.0 - alpha
	elif kind == "peak":
		A = 10.0 ** (gain_db / 40.0)
		b0 = 1.0 + alpha * A
		b1 = -2.0 * cw
		b2 = 1.0 - alpha * A
		a0 = 1.0 + alpha / A
		a1 = -2.0 * cw
		a2 = 1.0 - alpha / A
	elif kind == "ls":
		A = 10.0 ** (gain_db / 40.0)
		sq = 2.0 * math.sqrt(A) * alpha
		b0 = A * ((A + 1.0) - (A - 1.0) * cw + sq)
		b1 = 2.0 * A * ((A - 1.0) - (A + 1.0) * cw)
		b2 = A * ((A + 1.0) - (A - 1.0) * cw - sq)
		a0 = (A + 1.0) + (A - 1.0) * cw + sq
		a1 = -2.0 * ((A - 1.0) + (A + 1.0) * cw)
		a2 = (A + 1.0) + (A - 1.0) * cw - sq
	else:  # hs
		A = 10.0 ** (gain_db / 40.0)
		sq = 2.0 * math.sqrt(A) * alpha
		b0 = A * ((A + 1.0) + (A - 1.0) * cw + sq)
		b1 = -2.0 * A * ((A - 1.0) + (A + 1.0) * cw)
		b2 = A * ((A + 1.0) + (A - 1.0) * cw - sq)
		a0 = (A + 1.0) - (A - 1.0) * cw + sq
		a1 = 2.0 * ((A - 1.0) - (A + 1.0) * cw)
		a2 = (A + 1.0) - (A - 1.0) * cw - sq
	inv = 1.0 / a0
	return b0 * inv, b1 * inv, b2 * inv, a1 * inv, a2 * inv


def biquad(samples, kind, fc, q=0.707, gain_db=0.0):
	"""Фильтр второго порядка (lp / hp / bp / peak / ls / hs)."""
	b0, b1, b2, a1, a2 = _biquad_coeffs(kind, fc, q, gain_db)
	x1 = x2 = y1 = y2 = 0.0
	out = [0.0] * len(samples)
	for i, x in enumerate(samples):
		y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		out[i] = y
	return out


def biquad_sweep(samples, kind, fc_fn, q=1.5):
	"""Динамический фильтр с плавающим срезом fc_fn(t) — идеален для свиста меча, ветра и топи."""
	n = len(samples)
	out = [0.0] * n
	x1 = x2 = y1 = y2 = 0.0
	b0 = b1 = b2 = a1 = a2 = 0.0
	inv_rate = 1.0 / RATE
	for i, x in enumerate(samples):
		if (i & 31) == 0:  # пересчитываем раз в ~0.7 мс: без слышимых ступенек и в 32 раза быстрее
			fc = fc_fn(i * inv_rate)
			b0, b1, b2, a1, a2 = _biquad_coeffs(kind, fc, q)
		y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		out[i] = y
	return out


def dc_block(samples):
	return biquad(samples, "hp", 22.0, 0.707)


def lowpass_1p(samples, fc):
	rc = 1.0 / (TWO_PI * max(20.0, fc))
	dt = 1.0 / RATE
	a = dt / (rc + dt)
	prev = 0.0
	out = [0.0] * len(samples)
	for i, x in enumerate(samples):
		prev += a * (x - prev)
		out[i] = prev
	return out


def mix_into(dst, src, offset=0, gain=1.0):
	"""Прибавляет моно-буфер src в dst со смещением offset (в семплах)."""
	n_dst = len(dst)
	for i, s in enumerate(src):
		j = offset + i
		if 0 <= j < n_dst:
			dst[j] += s * gain


def mix_stereo(dst_l, dst_r, src, offset=0, gain=1.0, pan=0.0):
	"""Кладёт моно-источник в стерео-пару с панорамой pan (-1..+1, закон постоянной мощности)."""
	angle = (clamp(pan, -1.0, 1.0) + 1.0) * (math.pi * 0.25)
	gl = gain * math.cos(angle)
	gr = gain * math.sin(angle)
	n_dst = len(dst_l)
	for i, s in enumerate(src):
		j = offset + i
		if 0 <= j < n_dst:
			dst_l[j] += s * gl
			dst_r[j] += s * gr


def add_stereo_pair(dst_l, dst_r, src_l, src_r, gain=1.0):
	n = min(len(dst_l), len(src_l))
	for i in range(n):
		dst_l[i] += src_l[i] * gain
		dst_r[i] += src_r[i] * gain


def saturate(samples, drive=1.5):
	"""Мягкая ламповая/ленточная сатурация — добавляет вес и сглаживает резкие пики."""
	if drive <= 0.0:
		return samples
	inv = 1.0 / math.tanh(drive)
	tanh = math.tanh
	return [tanh(x * drive) * inv for x in samples]


def soft_limit(samples, ceiling=0.95):
	"""Мягкий лимитер без жёсткого цифрового клиппинга."""
	out = [0.0] * len(samples)
	tanh = math.tanh
	for i, x in enumerate(samples):
		ax = abs(x)
		if ax <= ceiling * 0.8:
			out[i] = x
		else:
			over = (ax - ceiling * 0.8) / (ceiling * 0.2)
			val = ceiling * 0.8 + (ceiling * 0.2) * tanh(over)
			out[i] = val if x >= 0.0 else -val
	return out


def reverb_stereo(mono_or_l, src_r=None, wet=0.22, room=0.55, damp=0.45, predelay_ms=14.0):
	"""Быстрая стерео-реверберация Шредера/Moorer (4 демпфированных comb + 2 allpass, без вложенных циклов)."""
	if src_r is None:
		in_l = mono_or_l
		in_r = mono_or_l
	else:
		in_l = mono_or_l
		in_r = src_r
	n = len(in_l)
	fb = 0.72 + clamp(room, 0.0, 1.0) * 0.20
	pre = max(1, int(predelay_ms * 0.001 * RATE))
	damp1 = clamp(damp, 0.05, 0.85)
	damp2 = 1.0 - damp1

	comb_l_lens = (1557, 1617, 1491, 1422)
	comb_r_lens = (1580, 1640, 1514, 1445)

	def _process_channel(sig, lens):
		l0, l1, l2, l3 = lens
		c0 = [0.0] * l0
		c1 = [0.0] * l1
		c2 = [0.0] * l2
		c3 = [0.0] * l3
		i0 = i1 = i2 = i3 = 0
		f0 = f1 = f2 = f3 = 0.0
		a0_len, a1_len = 225, 556
		a0 = [0.0] * a0_len
		a1 = [0.0] * a1_len
		ai0 = ai1 = 0
		wet_buf = [0.0] * n
		for i in range(n):
			inp = sig[i - pre] if i >= pre else 0.0
			y0 = c0[i0]
			f0 = y0 * damp2 + f0 * damp1
			c0[i0] = inp + f0 * fb
			i0 += 1
			if i0 == l0:
				i0 = 0

			y1 = c1[i1]
			f1 = y1 * damp2 + f1 * damp1
			c1[i1] = inp + f1 * fb
			i1 += 1
			if i1 == l1:
				i1 = 0

			y2 = c2[i2]
			f2 = y2 * damp2 + f2 * damp1
			c2[i2] = inp + f2 * fb
			i2 += 1
			if i2 == l2:
				i2 = 0

			y3 = c3[i3]
			f3 = y3 * damp2 + f3 * damp1
			c3[i3] = inp + f3 * fb
			i3 += 1
			if i3 == l3:
				i3 = 0

			val = (y0 + y1 + y2 + y3) * 0.25
			b0 = a0[ai0]
			v0 = -val + b0
			a0[ai0] = val + b0 * 0.5
			ai0 += 1
			if ai0 == a0_len:
				ai0 = 0

			b1 = a1[ai1]
			v1 = -v0 + b1
			a1[ai1] = v0 + b1 * 0.5
			ai1 += 1
			if ai1 == a1_len:
				ai1 = 0
			wet_buf[i] = v1
		return wet_buf

	wl = _process_channel(in_l, comb_l_lens)
	wr = _process_channel(in_r, comb_r_lens)
	dry = 1.0 - wet * 0.45
	return [in_l[i] * dry + wl[i] * wet for i in range(n)], [in_r[i] * dry + wr[i] * wet for i in range(n)]


def wrap_loop(samples, loop_samples, xfade_ms=25.0):
	"""Переносит хвост [loop_samples:] в начало [0:] и сводит самый стык к нулевому разрыву."""
	n = len(samples)
	out = samples[:loop_samples]
	for i in range(loop_samples, n):
		out[(i - loop_samples) % loop_samples] += samples[i]
	# Сводим саму границу (последние ~4 мс → первый семпл), чтобы стык гарантированно не щёлкал
	bridge = min(int(0.004 * RATE), loop_samples // 16)
	if bridge > 2:
		end_val = out[loop_samples - 1]
		start_val = out[0]
		mid = (end_val + start_val) * 0.5
		for i in range(bridge):
			w = (i + 1) / bridge
			idx_end = loop_samples - bridge + i
			out[idx_end] = out[idx_end] * (1.0 - w * 0.5) + mid * (w * 0.5)
			idx_start = bridge - 1 - i
			out[idx_start] = out[idx_start] * (1.0 - w * 0.5) + mid * (w * 0.5)
	return out


def fade_edges(samples, fade_in_ms=2.0, fade_out_ms=6.0):
	n = len(samples)
	fi = min(n // 4, int(fade_in_ms * 0.001 * RATE))
	fo = min(n // 2, int(fade_out_ms * 0.001 * RATE))
	out = list(samples)
	for i in range(fi):
		out[i] *= i / max(1, fi)
	for i in range(fo):
		out[n - 1 - i] *= i / max(1, fo)
	return out


# ---------- Физический и музыкальный синтез инструментов ----------

def ks_pluck(freq, dur, brightness=0.55, decay=0.996, pick_pos=0.28, seed=1):
	"""Физическая модель щипковой струны Карплюса-Стронга (лютня, цитра, арфа)."""
	n = int(RATE * dur)
	period = max(2, int(round(RATE / max(40.0, freq))))
	rng = random.Random(seed)
	# Начальный щипок — шум + сдвинутый гребень позиции щипка (меняет тембр от мягкого до яркого)
	buf = [rng.uniform(-1.0, 1.0) for _ in range(period)]
	buf = lowpass_1p(buf, 1200.0 + brightness * 9000.0)
	comb_off = max(1, int(period * clamp(pick_pos, 0.05, 0.45)))
	buf = [buf[i] - 0.65 * buf[(i - comb_off) % period] for i in range(period)]
	# Выравниваем DC в буфере
	mean = sum(buf) / period
	buf = [x - mean for x in buf]

	out = [0.0] * n
	damp = 0.45 + 0.5 * clamp(brightness, 0.0, 1.0)  # больше damp -> ярче ВЧ
	idx = 0
	prev = buf[-1]
	# Тонкая подстройка высоты и затухания под длительность
	base_decay = min(0.9988, max(0.97, decay - 0.0018 * (freq / 440.0)))
	for i in range(n):
		cur = buf[idx]
		out[i] = cur
		# Лоупасс-фильтр в петле струны
		filt = damp * cur + (1.0 - damp) * prev
		prev = cur
		buf[idx] = filt * base_decay
		idx += 1
		if idx == period:
			idx = 0
	# Лёгкий резонанс деревянной деки (~180 Гц + 360 Гц) + мягкий спад в конце
	out = biquad(out, "peak", 195.0, 1.4, 3.5)
	fo = min(n // 4, int(0.03 * RATE))
	for i in range(fo):
		out[n - 1 - i] *= i / max(1, fo)
	return out


def bow_note(freq, dur, vib_rate=5.1, vib_depth=0.0055, bright=1.0, attack=0.14, release=0.22):
	"""Смычковая струна (виола/виолончель): пара расстроенных пил + канифоль + фильтр яркости + вибрато."""
	n = int(RATE * dur)
	out = [0.0] * n
	noise = biquad(make_noise(n, int(freq * 10)), "bp", min(4500.0, freq * 5.0), 1.8)
	p1 = p2 = p3 = 0.0
	sin = math.sin
	inv_r = TWO_PI / RATE
	for i in range(n):
		t = i / RATE
		env = env_adsr(t, dur, attack=attack, decay=0.12, sustain=0.82, release=release, curve=1.4)
		# Вибрато мягко нарастает после атаки
		vib_env = clamp((t - attack * 0.6) / 0.25, 0.0, 1.0)
		f = freq * (1.0 + vib_depth * vib_env * sin(TWO_PI * vib_rate * t))
		p1 = (p1 + f / RATE) % 1.0
		p2 = (p2 + f * 1.0032 / RATE) % 1.0
		p3 = (p3 + f * 0.9968 / RATE) % 1.0
		# Мягкие пилы (сумма скруглена синусом для теплоты без алиасинга на низах)
		saw = ((p1 * 2.0 - 1.0) * 0.45 + (p2 * 2.0 - 1.0) * 0.28 + (p3 * 2.0 - 1.0) * 0.28)
		rosin = noise[i] * 0.09 * env
		out[i] = (saw + rosin) * env
	# Живой смычковый фильтр: яркость открывается при атаке и мягко спадает
	fc_base = min(3800.0, freq * (3.2 + 2.8 * bright))
	out = biquad_sweep(out, "lp", lambda t: fc_base * (0.45 + 0.65 * clamp(t / max(0.05, attack * 1.4), 0.0, 1.0)), q=0.85)
	out = biquad(out, "peak", 320.0, 1.2, 3.0)
	return out


def flute_note(freq, dur, breath=0.14, attack=0.09, slide_from=None):
	"""Тёмная деревянная флейта / дудук: тёплый тон + воздух амбушюра + плавный въезд и вибрато."""
	n = int(RATE * dur)
	out = [0.0] * n
	air = biquad(pink_noise(n, int(freq * 7)), "bp", freq * 2.2, 2.2)
	phase = 0.0
	sin = math.sin
	for i in range(n):
		t = i / RATE
		env = env_adsr(t, dur, attack=attack, decay=0.1, sustain=0.85, release=0.14, curve=1.4)
		glide = 1.0
		if slide_from is not None and t < 0.09:
			g_t = t / 0.09
			glide = (slide_from / freq) * (1.0 - g_t) + g_t
		vib = 1.0 + 0.007 * clamp((t - 0.12) / 0.2, 0.0, 1.0) * sin(TWO_PI * 4.8 * t)
		f = freq * glide * vib
		phase += TWO_PI * f / RATE
		# Форма волны духовой трубки (чётные и нечётные гармоники в балансе)
		tone = 0.72 * sin(phase) + 0.24 * sin(phase * 2.0) + 0.08 * sin(phase * 3.0)
		breath_amp = breath * (1.7 if t < attack else 1.0)
		out[i] = (tone + air[i] * breath_amp) * env
	return out


def brass_note(freq, dur, attack=0.11, bright=1.0):
	"""Низкий медный рог Стражи: сочный блеск при раздуве фильтра и благородный сустейн."""
	n = int(RATE * dur)
	out = [0.0] * n
	p1 = p2 = 0.0
	sin = math.sin
	for i in range(n):
		t = i / RATE
		env = env_adsr(t, dur, attack=attack, decay=0.18, sustain=0.78, release=0.18, curve=1.5)
		pitch_dip = 1.0 - 0.018 * math.exp(-t * 32.0)
		f = freq * pitch_dip
		p1 = (p1 + f / RATE) % 1.0
		p2 = (p2 + f * 1.002 / RATE) % 1.0
		raw = ((p1 * 2.0 - 1.0) * 0.6 + (p2 * 2.0 - 1.0) * 0.4)
		# Примешиваем тёплую первую гармонику
		out[i] = (raw * 0.65 + 0.35 * sin(TWO_PI * p1)) * env
	max_fc = min(3200.0, freq * (4.2 + 2.5 * bright))
	out = biquad_sweep(out, "lp", lambda t: freq * 1.8 + (max_fc - freq * 1.8) * (clamp(t / max(0.04, attack * 1.6), 0.0, 1.0) ** 0.8), q=1.1)
	return out


def drum_hit(freq_start=125.0, freq_end=46.0, dur=0.38, slap=0.35, body_decay=2.1, seed=1):
	"""Рамочный или военный барабан: пробой кожи + спад тона мембраны + корпус."""
	n = int(RATE * dur)
	noise = biquad(make_noise(n, seed), "bp", 950.0, 1.2)
	out = [0.0] * n
	phase = 0.0
	sin = math.sin
	for i in range(n):
		t = i / RATE
		f = freq_end + (freq_start - freq_end) * math.exp(-t * 28.0)
		phase += TWO_PI * f / RATE
		body = math.tanh(sin(phase) * 1.65) * env_ad(t, dur, 0.002, body_decay)
		skin = noise[i] * slap * env_ad(t, 0.045, 0.001, 2.8)
		out[i] = body + skin
	return out


def modal_hit(partials, dur=0.8, click_gain=0.25, click_fc=2400.0, seed=1):
	"""Модальный синтез для металла, колоколов, льда, дерева и доспеха.
	partials — список (freq, amp, decay_pow)."""
	n = int(RATE * dur)
	click = biquad(make_noise(n, seed), "bp", click_fc, 1.6)
	out = [0.0] * n
	sin = math.sin
	for freq, amp, dec in partials:
		w = TWO_PI * freq / RATE
		for i in range(n):
			t = i / RATE
			out[i] += amp * sin(w * i) * env_ad(t, dur, 0.0015, dec)
	for i in range(min(n, int(0.06 * RATE))):
		t = i / RATE
		out[i] += click[i] * click_gain * env_ad(t, 0.04, 0.0005, 3.0)
	return out


def save_wav(path, left, right=None, peak_db=-1.0, limit=True, dc=True):
	"""Сохраняет моно или стерео WAV 44100 Гц, 16-бит PCM, с защитой от клиппинга и DC."""
	os.makedirs(os.path.dirname(path), exist_ok=True)
	target_peak = db_to_lin(peak_db)
	if right is None:
		clean = dc_block(left) if dc else list(left)
		if limit:
			clean = soft_limit(clean, 0.98)
		peak = max((abs(x) for x in clean), default=1.0)
		scale = (target_peak / peak) * 32767.0 if peak > 1e-6 else 0.0
		pcm = struct.pack("<%dh" % len(clean), *(int(clamp(x * scale, -32767.0, 32767.0)) for x in clean))
		ch = 1
	else:
		cl = dc_block(left) if dc else list(left)
		cr = dc_block(right) if dc else list(right)
		if limit:
			cl = soft_limit(cl, 0.98)
			cr = soft_limit(cr, 0.98)
		peak = max(max((abs(x) for x in cl), default=1.0), max((abs(x) for x in cr), default=1.0))
		scale = (target_peak / peak) * 32767.0 if peak > 1e-6 else 0.0
		interleaved = []
		for l, r in zip(cl, cr):
			interleaved.append(int(clamp(l * scale, -32767.0, 32767.0)))
			interleaved.append(int(clamp(r * scale, -32767.0, 32767.0)))
		pcm = struct.pack("<%dh" % len(interleaved), *interleaved)
		ch = 2
	with wave.open(path, "wb") as w:
		w.setnchannels(ch)
		w.setsampwidth(2)
		w.setframerate(RATE)
		w.writeframes(pcm)

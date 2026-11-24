# Генератор всей фоновой музыки (9 тем) и эмбиентов (6 атмосфер) 1-го акта «Гнилые топи» и хаба «Застава Колокола».
# Формат: 44100 Гц, 16-бит PCM стерео, бесшовное зацикливание (wrap_loop хвоста реверберации в начало).
# Запуск: python assets/sounds/src/build_music.py
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
	bow_note,
	brass_note,
	clamp,
	db_to_lin,
	dc_block,
	drum_hit,
	env_ad,
	env_adsr,
	flute_note,
	ks_pluck,
	make_noise,
	mix_into,
	mix_stereo,
	modal_hit,
	pink_noise,
	reverb_stereo,
	saturate,
	save_wav,
	wrap_loop,
)

# ---------- Нотная грамота ----------

NOTE_MAP = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6,
			"Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def m2f(note):
	"""Переводит 'D3', 'F#4' или целое MIDI в частоту (Гц)."""
	if isinstance(note, (int, float)):
		return 440.0 * (2.0 ** ((note - 69.0) / 12.0))
	name = note[:-1]
	octave = int(note[-1])
	midi = (octave + 1) * 12 + NOTE_MAP[name]
	return 440.0 * (2.0 ** ((midi - 69.0) / 12.0))


# ---------- Кеш-инструментарий для секвенсора ----------

class SynthBank:
	def __init__(self, seed=100):
		self._cache = {}
		self.rng = random.Random(seed)

	def pluck(self, note, dur, bright=0.55, decay=0.9965, pick=0.28):
		f = round(m2f(note), 2)
		key = ("pluck", f, round(dur, 3), round(bright, 2), round(decay, 4), round(pick, 2))
		if key not in self._cache:
			self._cache[key] = ks_pluck(f, dur, brightness=bright, decay=decay, pick_pos=pick, seed=int(f * 13) + 1)
		return self._cache[key]

	def bass_pluck(self, note, dur, lp=460.0):
		f = round(m2f(note), 2)
		key = ("bpluck", f, round(dur, 3), int(lp))
		if key not in self._cache:
			p = ks_pluck(f, dur, brightness=0.35, decay=0.9968, pick_pos=0.18, seed=int(f * 7) + 3)
			# Усилим фундаментал мягкой бочкообразной нижней опорой
			n = len(p)
			sin = math.sin
			w = TWO_PI * f / RATE
			sub = [sin(w * i) * env_ad(i / RATE, dur, 0.008, 1.8) * 0.42 for i in range(n)]
			p = biquad(p, "lp", lp, 0.8)
			self._cache[key] = [p[i] * 0.72 + sub[i] for i in range(n)]
		return self._cache[key]

	def bow(self, note, dur, bright=0.85, attack=0.12, release=0.22):
		f = round(m2f(note), 2)
		key = ("bow", f, round(dur, 3), round(bright, 2), round(attack, 2))
		if key not in self._cache:
			self._cache[key] = bow_note(f, dur, bright=bright, attack=attack, release=release)
		return self._cache[key]

	def flute(self, note, dur, breath=0.14, slide=None):
		f = round(m2f(note), 2)
		sf = round(m2f(slide), 2) if slide else None
		key = ("flute", f, round(dur, 3), round(breath, 2), sf)
		if key not in self._cache:
			self._cache[key] = flute_note(f, dur, breath=breath, attack=0.08, slide_from=sf)
		return self._cache[key]

	def horn(self, note, dur, bright=0.85, attack=0.10):
		f = round(m2f(note), 2)
		key = ("horn", f, round(dur, 3), round(bright, 2), round(attack, 2))
		if key not in self._cache:
			self._cache[key] = brass_note(f, dur, attack=attack, bright=bright)
		return self._cache[key]

	def pad(self, notes, dur, lp=1050.0, attack=0.45, release=0.65):
		freqs = tuple(round(m2f(n), 2) for n in notes)
		key = ("pad", freqs, round(dur, 3), int(lp))
		if key not in self._cache:
			n = int(RATE * dur)
			out = [0.0] * n
			sin = math.sin
			for idx, f in enumerate(freqs):
				w1 = TWO_PI * f / RATE
				w2 = TWO_PI * (f * 1.0024) / RATE
				w3 = TWO_PI * (f * 0.9976) / RATE
				# Теплое трио чуть расстроенных волн с мягкой 2-й и 3-й гармоникой
				for i in range(n):
					t = i / RATE
					e = env_adsr(t, dur, attack=attack, decay=0.2, sustain=0.82, release=release, curve=1.2)
					val = (0.5 * sin(w1 * i) + 0.25 * sin(w2 * i) + 0.25 * sin(w3 * i)
						   + 0.12 * sin(w1 * 2.0 * i) + 0.05 * sin(w1 * 3.0 * i))
					out[i] += val * e
			scale = 1.0 / max(1, len(freqs))
			out = biquad([x * scale for x in out], "lp", lp, 0.7)
			self._cache[key] = out
		return self._cache[key]

	def chime(self, note, dur=1.4, metallic=False):
		f = round(m2f(note), 2)
		key = ("chime", f, round(dur, 3), metallic)
		if key not in self._cache:
			if metallic:
				parts = [(f, 0.55, 1.5), (f * 2.0, 0.35, 1.9), (f * 2.756, 0.25, 2.3), (f * 4.0, 0.15, 2.9)]
			else:
				parts = [(f, 0.60, 1.6), (f * 2.0, 0.30, 2.1), (f * 3.0, 0.16, 2.6)]
			self._cache[key] = modal_hit(parts, dur, click_gain=0.06, click_fc=2600.0, seed=int(f) + 5)
		return self._cache[key]

	def guard_bell(self, note="G2", dur=2.6):
		f = round(m2f(note), 2)
		key = ("gbell", f, round(dur, 3))
		if key not in self._cache:
			parts = [
				(f, 0.55, 1.3),
				(f * 2.0, 0.45, 1.6),
				(f * 2.378, 0.30, 1.95),  # малая терция литого колокола
				(f * 3.0, 0.24, 2.3),
				(f * 4.0, 0.14, 2.9),
			]
			hit = modal_hit(parts, dur, click_gain=0.14, click_fc=1200.0, seed=777)
			thump = drum_hit(115.0, 48.0, 0.12, slap=0.25, body_decay=2.8, seed=778)
			mix_into(hit, thump, 0, 0.45)
			self._cache[key] = hit
		return self._cache[key]

	def drum(self, kind="frame"):
		key = ("drum", kind)
		if key not in self._cache:
			if kind == "frame":
				self._cache[key] = drum_hit(112.0, 44.0, 0.36, slap=0.32, body_decay=2.1, seed=801)
			elif kind == "war":
				self._cache[key] = saturate(drum_hit(118.0, 35.0, 0.48, slap=0.55, body_decay=1.65, seed=802), 1.35)
			elif kind == "tom":
				self._cache[key] = drum_hit(148.0, 68.0, 0.30, slap=0.30, body_decay=2.3, seed=803)
			elif kind == "wood":
				self._cache[key] = modal_hit([(460.0, 0.65, 4.2), (820.0, 0.4, 5.0)], 0.08, 0.28, 1800.0, 804)
			elif kind == "rim":
				self._cache[key] = modal_hit([(680.0, 0.5, 4.5), (1240.0, 0.35, 5.2), (1950.0, 0.2, 6.0)], 0.075, 0.35, 2400.0, 805)
			elif kind == "anvil":
				self._cache[key] = modal_hit([(620.0, 0.55, 2.2), (1185.0, 0.45, 2.6), (1940.0, 0.32, 3.1), (2890.0, 0.18, 3.8)], 0.45, 0.4, 3400.0, 806)
			elif kind == "shaker":
				n = int(RATE * 0.055)
				s = biquad(make_noise(n, 807), "bp", 4200.0, 1.4)
				self._cache[key] = [s[i] * env_ad(i / RATE, 0.055, 0.008, 2.4) for i in range(n)]
			elif kind == "tambur":
				n = int(RATE * 0.14)
				s = biquad(make_noise(n, 808), "bp", 3100.0, 1.5)
				b = drum_hit(195.0, 85.0, 0.09, slap=0.25, body_decay=3.0, seed=809)
				out = [s[i] * env_ad(i / RATE, 0.14, 0.004, 2.2) * 0.65 for i in range(n)]
				mix_into(out, b, 0, 0.55)
				self._cache[key] = out
		return self._cache[key]


class TrackBuilder:
	"""Стерео-секвенсор с отдельной шиной реверберации и бесшовной сшивкой петли."""
	def __init__(self, bpm, bars, beats_per_bar=4, tail_sec=3.2, seed=42):
		self.bpm = bpm
		self.bars = bars
		self.bpb = beats_per_bar
		self.beat_sec = 60.0 / bpm
		self.loop_sec = bars * beats_per_bar * self.beat_sec
		self.loop_n = int(round(self.loop_sec * RATE))
		self.total_n = self.loop_n + int(round(tail_sec * RATE))
		self.dry_l = [0.0] * self.total_n
		self.dry_r = [0.0] * self.total_n
		self.wet_l = [0.0] * self.total_n
		self.wet_r = [0.0] * self.total_n
		self.rng = random.Random(seed)

	def t_of(self, beat):
		return beat * self.beat_sec

	def place(self, beat, sig, gain=1.0, pan=0.0, rev=0.35, jitter_ms=4.0):
		jit = self.rng.uniform(-jitter_ms, jitter_ms) * 0.001 if jitter_ms > 0 else 0.0
		off = int(round((beat * self.beat_sec + jit) * RATE))
		# Для бесконечного цикла ноты, слегка ушедшие за 0 в минус, переносим в конец loop_n
		if off < 0:
			off += self.loop_n
		dry_g = gain * (1.0 - rev * 0.35)
		wet_g = gain * rev
		mix_stereo(self.dry_l, self.dry_r, sig, off, dry_g, pan)
		if wet_g > 0.01:
			mix_stereo(self.wet_l, self.wet_r, sig, off, wet_g, pan)

	def render(self, path, room=0.62, damp=0.42, wet_mix=0.42, target_rms_db=-16.5):
		rl, rr = reverb_stereo(self.wet_l, self.wet_r, wet=1.0, room=room, damp=damp, predelay_ms=16.0)
		full_l = [self.dry_l[i] + rl[i] * wet_mix for i in range(self.total_n)]
		full_r = [self.dry_r[i] + rr[i] * wet_mix for i in range(self.total_n)]
		full_l = dc_block(full_l)
		full_r = dc_block(full_r)
		# Заворачиваем хвост за границей loop_n прямо в начало для бесшовного цикла!
		l_loop = wrap_loop(full_l, self.loop_n, xfade_ms=8.0)
		r_loop = wrap_loop(full_r, self.loop_n, xfade_ms=8.0)
		# Мастеринг-баланс и мягкий лимитер: убираем лишний гул (<150 Гц) и открываем читаемость мелодии (~750 Гц)
		l_loop = biquad(l_loop, "hp", 34.0, 0.707)
		r_loop = biquad(r_loop, "hp", 34.0, 0.707)
		l_loop = biquad(l_loop, "peak", 135.0, 0.8, -3.8)
		r_loop = biquad(r_loop, "peak", 135.0, 0.8, -3.8)
		l_loop = biquad(l_loop, "peak", 780.0, 0.7, 3.2)
		r_loop = biquad(r_loop, "peak", 780.0, 0.7, 3.2)
		l_loop = saturate(l_loop, 1.15)
		r_loop = saturate(r_loop, 1.15)
		mono_ms = sum(((a + b) * 0.5) ** 2 for a, b in zip(l_loop, r_loop)) / len(l_loop)
		cur_rms_db = 10.0 * math.log10(max(mono_ms, 1e-12))
		gain = db_to_lin(target_rms_db - cur_rms_db)
		l_loop = [x * gain for x in l_loop]
		r_loop = [x * gain for x in r_loop]
		# Выравниваем самый край (0 и N-1) после фильтрации для абсолютно чистого стыка
		if len(l_loop) > 8:
			l_loop[-1] = (l_loop[-1] + l_loop[0]) * 0.5
			l_loop[0] = l_loop[-1]
			r_loop[-1] = (r_loop[-1] + r_loop[0]) * 0.5
			r_loop[0] = r_loop[-1]
		peak = max(max((abs(x) for x in l_loop), default=0.0), max((abs(x) for x in r_loop), default=0.0))
		peak_db = min(-1.2, 20.0 * math.log10(max(peak, 1e-12)))
		save_wav(path, l_loop, r_loop, peak_db=peak_db, limit=True, dc=False)


# Вспомогательные паттерны аккомпанемента
def _arp_bar(tb, bank, bar, chord, pattern, dur=1.45, gain=0.22, rev=0.42, bright=0.52, pan_spread=0.38):
	base_beat = bar * tb.bpb
	for idx, (sub_beat, ci) in enumerate(pattern):
		note = chord[ci]
		pan = -pan_spread + 2.0 * pan_spread * (idx / max(1, len(pattern) - 1))
		vel = gain * (1.05 if sub_beat % 1.0 == 0 else 0.85)
		tb.place(base_beat + sub_beat, bank.pluck(note, dur, bright=bright), gain=vel, pan=pan, rev=rev, jitter_ms=5.0)


def _play_melody(tb, bank, voice_fn, seq, pan=0.0, rev=0.45, gain=0.22):
	for item in seq:
		if len(item) == 3:
			beat, note, beats_dur = item
			slide = None
		else:
			beat, note, beats_dur, slide = item
		dur = beats_dur * tb.beat_sec
		tb.place(beat, voice_fn(note, dur, slide), gain=gain, pan=pan, rev=rev, jitter_ms=4.0)


# ==============================================================================
# КОМПОЗИЦИИ АКТА 1 (9 БЕСШОВНЫХ ТЕМ)
# ==============================================================================

def build_music_hub(bank, out_path):
	"""1. «Застава Колокола» — Главное меню и Хаб (D Дорийский, 68 BPM, 8 тактов = 28.24 с)."""
	tb = TrackBuilder(bpm=68.0, bars=8, beats_per_bar=4, seed=101)
	chords = [
		(["D3", "A3", "D4", "F4"], "D2", ["D3", "F3", "A3"]),
		(["C3", "G3", "C4", "E4"], "C2", ["C3", "E3", "G3"]),
		(["G2", "D3", "B3", "D4"], "G2", ["G3", "B3", "D4"]),
		(["D3", "A3", "D4", "F4"], "D2", ["D3", "F3", "A3"]),
		(["F3", "C4", "F4", "A4"], "F2", ["F3", "A3", "C4"]),
		(["C3", "G3", "C4", "E4"], "C2", ["C3", "E3", "G3"]),
		(["G2", "D3", "G3", "Bb3"], "G2", ["G3", "Bb3", "D4"]),
		(["A2", "E3", "A3", "C#4"], "A2", ["A2", "E3", "A3"]),
	]
	arp = [(0.0, 0), (0.5, 1), (1.0, 2), (1.5, 3), (2.0, 1), (2.5, 2), (3.0, 3), (3.5, 1)]
	for bar, (ch, bass, pad_n) in enumerate(chords):
		b0 = bar * 4.0
		tb.place(b0, bank.pad(pad_n, tb.beat_sec * 3.9, lp=880.0), gain=0.14, pan=0.0, rev=0.5, jitter_ms=0.0)
		tb.place(b0, bank.bass_pluck(bass, tb.beat_sec * 2.2), gain=0.30, pan=0.0, rev=0.12)
		tb.place(b0 + 2.0, bank.bass_pluck(bass, tb.beat_sec * 1.8), gain=0.22, pan=0.0, rev=0.12)
		_arp_bar(tb, bank, bar, ch, arp, dur=1.6, gain=0.20, rev=0.45, bright=0.50)
		# Спокойный тёплый бубен и отзвук Колокола в ключевых тактах
		tb.place(b0, bank.drum("frame"), gain=0.14, pan=-0.1, rev=0.35)
		tb.place(b0 + 2.5, bank.drum("tambur"), gain=0.07, pan=0.22, rev=0.45)
		if bar in (0, 4):
			tb.place(b0, bank.guard_bell("D2" if bar == 0 else "A2", 2.8), gain=0.12, pan=0.15, rev=0.65)

	# Певучая деревянная флейта с паузами, чтобы не утомлять
	melody = [
		(1.0, "A4", 1.5, "G4"), (2.5, "F4", 1.0), (3.5, "E4", 0.5),
		(4.0, "G4", 2.0), (6.5, "E4", 1.0),
		(8.0, "D4", 2.5, "E4"), (11.0, "F4", 1.0),
		(12.0, "A4", 2.5),
		(17.0, "C5", 1.5, "A4"), (18.5, "A4", 1.0), (19.5, "G4", 0.5),
		(20.0, "E4", 2.0), (22.5, "G4", 1.0),
		(24.0, "Bb4", 1.5), (25.5, "A4", 1.0), (26.5, "G4", 1.5),
		(28.0, "E4", 3.2, "D4"),
	]
	_play_melody(tb, bank, lambda n, d, s: bank.flute(n, d, breath=0.13, slide=s), melody, pan=-0.12, rev=0.52, gain=0.20)
	tb.render(out_path, room=0.64, damp=0.42, wet_mix=0.42, target_rms_db=-18.5)


def build_music_map(bank, out_path):
	"""2. «Гати Сумрака» — Карта пути, события, лавка, награда (E Минор, 72 BPM, 8 тактов = 26.67 с)."""
	tb = TrackBuilder(bpm=72.0, bars=8, beats_per_bar=4, seed=102)
	chords = [
		(["E3", "B3", "E4", "G4"], "E2", ["E3", "G3", "B3"]),
		(["C3", "G3", "B3", "E4"], "C2", ["C3", "E3", "B3"]),
		(["A2", "E3", "A3", "C4"], "A2", ["A2", "E3", "C4"]),
		(["B2", "F#3", "A3", "D#4"], "B2", ["B2", "F#3", "B3"]),
		(["E3", "B3", "E4", "G4"], "E2", ["E3", "G3", "B3"]),
		(["G3", "D4", "G4", "B4"], "G2", ["G3", "B3", "D4"]),
		(["F3", "C4", "F4", "A4"], "F2", ["F3", "A3", "C4"]),
		(["B2", "F#3", "B3", "D#4"], "B2", ["B2", "F#3", "D#4"]),
	]
	arp = [(0.0, 0), (0.75, 1), (1.5, 2), (2.25, 3), (3.0, 2), (3.5, 1)]
	for bar, (ch, bass, pad_n) in enumerate(chords):
		b0 = bar * 4.0
		tb.place(b0, bank.pad(pad_n, tb.beat_sec * 3.85, lp=920.0), gain=0.13, pan=0.0, rev=0.55, jitter_ms=0.0)
		for st in [0.0, 1.0, 2.0, 3.0]:
			tb.place(b0 + st, bank.bass_pluck(bass, 0.9, lp=360.0), gain=0.22 if st in (0.0, 2.0) else 0.14, pan=0.0, rev=0.15)
		_arp_bar(tb, bank, bar, ch, arp, dur=1.5, gain=0.19, rev=0.50, bright=0.60, pan_spread=0.45)
		tb.place(b0 + 1.5, bank.drum("shaker"), gain=0.09, pan=0.25, rev=0.4)
		tb.place(b0 + 3.5, bank.drum("shaker"), gain=0.08, pan=-0.25, rev=0.4)
		# Далёкие стеклянные капли Раскола
		if bar in (1, 3, 5, 7):
			tb.place(b0 + 2.5, bank.chime(ch[3], 1.3, metallic=True), gain=0.11, pan=0.35 if bar % 4 == 1 else -0.35, rev=0.68)

	viola = [
		(2.0, "B4", 1.8), (4.0, "G4", 1.5), (6.0, "F#4", 1.5),
		(8.0, "E4", 2.5), (12.0, "F#4", 2.5),
		(18.0, "B4", 1.5), (20.0, "D5", 2.0), (24.0, "C5", 2.0),
		(26.0, "A4", 1.5), (28.0, "F#4", 3.0),
	]
	_play_melody(tb, bank, lambda n, d, s: bank.bow(n, d, bright=0.72, attack=0.15), viola, pan=0.15, rev=0.55, gain=0.17)
	tb.render(out_path, room=0.68, damp=0.38, wet_mix=0.45, target_rms_db=-18.5)


def build_music_rest(bank, out_path):
	"""3. «Кочка у костра» — Привал (A Дорийский, 3/4, 62 BPM, 8 тактов = 23.23 с)."""
	tb = TrackBuilder(bpm=62.0, bars=8, beats_per_bar=3, seed=103)
	chords = [
		(["A2", "E3", "A3", "C4"], ["A2", "E3", "C4"]),
		(["G2", "D3", "G3", "B3"], ["G2", "D3", "B3"]),
		(["F2", "C3", "F3", "A3"], ["F2", "C3", "A3"]),
		(["E2", "B2", "E3", "G3"], ["E2", "B2", "G3"]),
		(["A2", "E3", "A3", "C4"], ["A2", "E3", "C4"]),
		(["D3", "A3", "D4", "F#4"], ["D3", "A3", "F#4"]),
		(["F2", "C3", "F3", "A3"], ["F2", "C3", "A3"]),
		(["E2", "B2", "E3", "G3"], ["E2", "B2", "G3"]),
	]
	arp = [(0.0, 0), (0.5, 1), (1.0, 2), (1.5, 3), (2.0, 2), (2.5, 1)]
	for bar, (ch, pad_n) in enumerate(chords):
		b0 = bar * 3.0
		tb.place(b0, bank.pad(pad_n, tb.beat_sec * 2.9, lp=780.0), gain=0.15, pan=0.0, rev=0.5, jitter_ms=0.0)
		_arp_bar(tb, bank, bar, ch, arp, dur=1.6, gain=0.22, rev=0.45, bright=0.45, pan_spread=0.32)

	flute = [
		(3.0, "E4", 1.5, "D4"), (4.5, "G4", 1.5), (6.0, "F4", 2.0), (9.0, "E4", 2.5),
		(13.0, "C5", 1.5, "A4"), (15.0, "A4", 1.5), (16.5, "F#4", 1.5), (18.0, "E4", 2.5), (21.0, "B3", 2.5),
	]
	_play_melody(tb, bank, lambda n, d, s: bank.flute(n, d, breath=0.12, slide=s), flute, pan=-0.1, rev=0.52, gain=0.19)
	tb.render(out_path, room=0.62, damp=0.44, wet_mix=0.42, target_rms_db=-19.0)


def build_music_bog(bank, out_path):
	"""4. «Гнилые топи» — Боевые арены gat («Старая гать») и reeds («Камышовая заводь»). C#m, 88 BPM, 12 тактов = 32.73 с."""
	tb = TrackBuilder(bpm=88.0, bars=12, beats_per_bar=4, seed=104)
	prog = [
		(["C#3", "G#3", "C#4", "E4"], "C#2", ["C#3", "G#3"]),
		(["C#3", "G#3", "C#4", "E4"], "C#2", ["C#3", "G#3"]),
		(["A2", "E3", "A3", "C#4"], "A1", ["A2", "E3"]),
		(["G#2", "D#3", "G#3", "B3"], "G#1", ["G#2", "D#3"]),
		(["C#3", "G#3", "C#4", "E4"], "C#2", ["C#3", "G#3"]),
		(["F#2", "C#3", "F#3", "A3"], "F#1", ["F#2", "C#3"]),
		(["A2", "E3", "B3", "E4"], "A1", ["A2", "E3"]),
		(["G#2", "D#3", "G#3", "C4"], "G#1", ["G#2", "D#3"]),
		(["E3", "B3", "E4", "G#4"], "E2", ["E3", "B3"]),
		(["F#2", "C#3", "F#3", "A3"], "F#1", ["F#2", "C#3"]),
		(["D3", "A3", "D4", "F#4"], "D2", ["D3", "A3"]),  # мрачный фригийский оттенок
		(["G#2", "D#3", "G#3", "C4"], "G#1", ["G#2", "D#3"]),
	]
	for bar, (ch, bass, drone_n) in enumerate(prog):
		b0 = bar * 4.0
		tb.place(b0, bank.pad(drone_n, tb.beat_sec * 3.8, lp=640.0), gain=0.14, pan=0.0, rev=0.45, jitter_ms=0.0)
		# Вязкая ритм-секция топей: рамочный барабан + костяшки/деревяшки на синкопах
		tb.place(b0 + 0.0, bank.drum("frame"), gain=0.28, pan=0.0, rev=0.25)
		tb.place(b0 + 1.5, bank.drum("frame"), gain=0.18, pan=-0.05, rev=0.25)
		tb.place(b0 + 2.5, bank.drum("frame"), gain=0.23, pan=0.05, rev=0.25)
		tb.place(b0 + 1.0, bank.drum("wood"), gain=0.15, pan=-0.32, rev=0.40)
		tb.place(b0 + 3.0, bank.drum("wood"), gain=0.17, pan=0.32, rev=0.40)
		if bar % 2 == 1:
			tb.place(b0 + 3.5, bank.drum("rim"), gain=0.12, pan=0.22, rev=0.45)

		# Пульсирующий бас-щипок
		for sb in [0.0, 1.5, 2.0, 3.0]:
			tb.place(b0 + sb, bank.bass_pluck(bass, 0.72, lp=380.0), gain=0.26 if sb in (0.0, 2.0) else 0.18, pan=0.0, rev=0.1)

		# Пиццикато-перебор струнных
		pat = [(0.0, 0), (0.5, 1), (1.0, 2), (2.0, 3), (2.5, 2), (3.0, 1), (3.5, 2)]
		_arp_bar(tb, bank, bar, ch, pat, dur=0.95, gain=0.18, rev=0.40, bright=0.48, pan_spread=0.42)

	# Напряжённая мелодия виолы и редкий дудук над водой
	viola = [
		(8.0, "G#4", 1.5), (9.5, "A4", 0.5), (10.0, "G#4", 1.5), (11.5, "E4", 0.5),
		(12.0, "D#4", 3.0),
		(16.0, "C#4", 1.5), (17.5, "E4", 1.0), (18.5, "F#4", 1.5), (20.0, "A4", 2.0), (22.0, "G#4", 2.0),
		(32.0, "B4", 1.5), (33.5, "C#5", 1.0), (34.5, "A4", 1.5),
		(36.0, "F#4", 2.0), (40.0, "A4", 2.0), (42.0, "G#4", 1.5), (44.0, "E4", 2.0), (46.0, "D#4", 1.8),
	]
	_play_melody(tb, bank, lambda n, d, s: bank.bow(n, d, bright=0.88, attack=0.10), viola, pan=-0.16, rev=0.52, gain=0.20)
	flute_echo = [(24.0, "C#5", 1.5, "B4"), (26.0, "G#4", 2.0), (28.0, "E4", 2.5)]
	_play_melody(tb, bank, lambda n, d, s: bank.flute(n, d, breath=0.15, slide=s), flute_echo, pan=0.24, rev=0.60, gain=0.16)
	tb.render(out_path, room=0.65, damp=0.42, wet_mix=0.42, target_rms_db=-16.5)


def build_music_grove(bank, out_path):
	"""5. «Мёртвая роща» — Арены grove и camp («Брошенная застава»). D Минор, 94 BPM, 12 тактов = 30.64 с."""
	tb = TrackBuilder(bpm=94.0, bars=12, beats_per_bar=4, seed=105)
	prog = [
		(["D3", "A3", "D4", "F4"], "D2", ["D3", "A3"]),
		(["C3", "G3", "C4", "E4"], "C2", ["C3", "G3"]),
		(["Bb2", "F3", "Bb3", "D4"], "Bb1", ["Bb2", "F3"]),
		(["A2", "E3", "A3", "C#4"], "A1", ["A2", "E3"]),
		(["D3", "A3", "D4", "F4"], "D2", ["D3", "A3"]),
		(["F3", "C4", "F4", "A4"], "F2", ["F3", "C4"]),
		(["G2", "D3", "G3", "Bb3"], "G1", ["G2", "D3"]),
		(["A2", "E3", "A3", "C#4"], "A1", ["A2", "E3"]),
		(["Bb2", "F3", "D4", "F4"], "Bb1", ["Bb2", "F3"]),
		(["C3", "G3", "C4", "E4"], "C2", ["C3", "G3"]),
		(["G2", "D3", "G3", "Bb3"], "G1", ["G2", "D3"]),
		(["A2", "E3", "A3", "C#4"], "A1", ["A2", "E3"]),
	]
	ost = [(0.0, 0), (0.5, 1), (1.0, 2), (1.5, 1), (2.0, 3), (2.5, 2), (3.0, 1), (3.5, 2)]
	for bar, (ch, bass, pad_n) in enumerate(prog):
		b0 = bar * 4.0
		tb.place(b0, bank.pad(pad_n, tb.beat_sec * 3.8, lp=780.0), gain=0.12, pan=0.0, rev=0.4, jitter_ms=0.0)
		# Чёткий тактический марш по доскам и камню
		tb.place(b0 + 0.0, bank.drum("war"), gain=0.25, pan=0.0, rev=0.22)
		tb.place(b0 + 1.0, bank.drum("rim"), gain=0.16, pan=0.22, rev=0.35)
		tb.place(b0 + 2.0, bank.drum("tom"), gain=0.22, pan=-0.1, rev=0.25)
		tb.place(b0 + 3.0, bank.drum("rim"), gain=0.17, pan=0.22, rev=0.35)
		tb.place(b0 + 3.5, bank.drum("tom"), gain=0.14, pan=-0.18, rev=0.30)
		for sb in [0.0, 1.0, 2.0, 3.0]:
			tb.place(b0 + sb, bank.bass_pluck(bass, 0.7, lp=420.0), gain=0.27 if sb % 2 == 0 else 0.19, pan=0.0, rev=0.1)
		_arp_bar(tb, bank, bar, ch, ost, dur=0.72, gain=0.19, rev=0.35, bright=0.62, pan_spread=0.40)

	horn_theme = [
		(16.0, "D4", 1.5), (17.5, "E4", 0.5), (18.0, "F4", 1.5), (19.5, "G4", 0.5),
		(20.0, "A4", 2.5), (23.0, "G4", 1.0),
		(24.0, "Bb4", 1.5), (25.5, "A4", 1.0), (26.5, "G4", 1.5),
		(28.0, "E4", 2.5),
	]
	_play_melody(tb, bank, lambda n, d, s: bank.horn(n, d, bright=0.82, attack=0.09), horn_theme, pan=0.14, rev=0.48, gain=0.18)
	viola_top = [
		(32.0, "D5", 1.5), (33.5, "C5", 0.5), (34.0, "Bb4", 1.5), (35.5, "A4", 0.5),
		(36.0, "G4", 2.0), (38.0, "C5", 2.0),
		(40.0, "Bb4", 1.5), (41.5, "A4", 1.0), (42.5, "G4", 1.5),
		(44.0, "E4", 2.0), (46.0, "A4", 1.8),
	]
	_play_melody(tb, bank, lambda n, d, s: bank.bow(n, d, bright=0.95, attack=0.08), viola_top, pan=-0.18, rev=0.45, gain=0.19)
	tb.render(out_path, room=0.58, damp=0.40, wet_mix=0.40, target_rms_db=-16.0)


def build_music_ruins(bank, out_path):
	"""6. «Затопленные руины» — Арена ruins (E Минор, гулкие своды и отблеск молний). 82 BPM, 12 тактов = 35.12 с."""
	tb = TrackBuilder(bpm=82.0, bars=12, beats_per_bar=4, seed=106)
	prog = [
		(["E3", "B3", "F#4", "G4"], "E2", ["E3", "B3", "G4"]),
		(["E3", "B3", "F#4", "G4"], "E2", ["E3", "B3", "G4"]),
		(["C3", "G3", "D4", "E4"], "C2", ["C3", "G3", "D4"]),
		(["A2", "E3", "B3", "C4"], "A1", ["A2", "E3", "C4"]),
		(["E3", "B3", "F#4", "G4"], "E2", ["E3", "B3", "G4"]),
		(["D3", "A3", "E4", "F#4"], "D2", ["D3", "A3", "F#4"]),
		(["C3", "G3", "B3", "E4"], "C2", ["C3", "G3", "E4"]),
		(["B2", "F#3", "A3", "D#4"], "B1", ["B2", "F#3", "D#4"]),
		(["G3", "D4", "A4", "B4"], "G2", ["G3", "D4", "B4"]),
		(["A2", "E3", "B3", "C4"], "A1", ["A2", "E3", "C4"]),
		(["F#2", "C#3", "A3", "E4"], "F#1", ["F#2", "C#3", "A3"]),
		(["B2", "F#3", "B3", "D#4"], "B1", ["B2", "F#3", "B3"]),
	]
	pat = [(0.0, 0), (0.75, 1), (1.5, 2), (2.25, 3), (3.0, 2), (3.5, 1)]
	for bar, (ch, bass, pad_n) in enumerate(prog):
		b0 = bar * 4.0
		tb.place(b0, bank.pad(pad_n, tb.beat_sec * 3.9, lp=980.0), gain=0.14, pan=0.0, rev=0.60, jitter_ms=0.0)
		tb.place(b0, bank.bass_pluck(bass, 2.0, lp=360.0), gain=0.25, pan=0.0, rev=0.18)
		_arp_bar(tb, bank, bar, ch, pat, dur=1.7, gain=0.18, rev=0.58, bright=0.68, pan_spread=0.5)
		# Глубокие удары грома по руинам + кристальные капли молнии
		if bar % 2 == 0:
			tb.place(b0 + 0.0, bank.drum("war"), gain=0.24, pan=-0.08, rev=0.45)
			tb.place(b0 + 2.5, bank.drum("tom"), gain=0.16, pan=0.14, rev=0.45)
		else:
			tb.place(b0 + 1.5, bank.drum("tom"), gain=0.18, pan=-0.12, rev=0.45)
			tb.place(b0 + 3.0, bank.chime(ch[3], 1.6, metallic=True), gain=0.13, pan=0.38, rev=0.72)

	lead = [
		(8.0, "E5", 2.0), (10.0, "D5", 1.5), (11.5, "B4", 0.5),
		(12.0, "C5", 2.5), (15.0, "A4", 1.0),
		(24.0, "B4", 1.5, "A4"), (25.5, "F#4", 1.5), (27.0, "G4", 1.0), (28.0, "B4", 3.0),
		(34.0, "G4", 1.5), (36.0, "A4", 2.0), (38.0, "E4", 2.0), (44.0, "F#4", 3.0),
	]
	_play_melody(tb, bank, lambda n, d, s: bank.flute(n, d, breath=0.14, slide=s), lead, pan=-0.14, rev=0.62, gain=0.24)
	tb.render(out_path, room=0.78, damp=0.34, wet_mix=0.52, target_rms_db=-16.5)


def build_music_cave(bank, out_path):
	"""7. «Тлеющая пещера» — Секретный бой с Жаровиком (A Фригийско-доминантный, 98 BPM, 12 тактов = 29.39 с)."""
	tb = TrackBuilder(bpm=98.0, bars=12, beats_per_bar=4, seed=107)
	prog = [
		(["A2", "E3", "A3", "C#4"], "A1", ["A2", "E3"]),
		(["Bb2", "F3", "Bb3", "D4"], "Bb1", ["Bb2", "F3"]),
		(["A2", "E3", "A3", "C#4"], "A1", ["A2", "E3"]),
		(["G2", "D3", "G3", "Bb3"], "G1", ["G2", "D3"]),
		(["A2", "E3", "A3", "C#4"], "A1", ["A2", "E3"]),
		(["D3", "A3", "D4", "F4"], "D2", ["D3", "A3"]),
		(["Bb2", "F3", "Bb3", "D4"], "Bb1", ["Bb2", "F3"]),
		(["A2", "E3", "G3", "C#4"], "A1", ["A2", "E3"]),
		(["F2", "C3", "F3", "A3"], "F1", ["F2", "C3"]),
		(["G2", "D3", "G3", "Bb3"], "G1", ["G2", "D3"]),
		(["Bb2", "F3", "Bb3", "D4"], "Bb1", ["Bb2", "F3"]),
		(["A2", "E3", "A3", "C#4"], "A1", ["A2", "E3"]),
	]
	ost = [(0.0, 0), (0.5, 1), (1.0, 2), (1.5, 3), (2.0, 2), (2.5, 1), (3.0, 3), (3.5, 2)]
	for bar, (ch, bass, pad_n) in enumerate(prog):
		b0 = bar * 4.0
		tb.place(b0, bank.pad(pad_n, tb.beat_sec * 3.8, lp=680.0), gain=0.14, pan=0.0, rev=0.45, jitter_ms=0.0)
		# Кузнечный подземный ритм + звон наковальни
		tb.place(b0 + 0.0, bank.drum("war"), gain=0.28, pan=0.0, rev=0.28)
		tb.place(b0 + 1.5, bank.drum("war"), gain=0.18, pan=0.0, rev=0.28)
		tb.place(b0 + 2.0, bank.drum("anvil"), gain=0.12 if bar % 2 == 0 else 0.08, pan=0.35, rev=0.60)
		tb.place(b0 + 3.0, bank.drum("tom"), gain=0.20, pan=-0.2, rev=0.35)
		for sb in [0.0, 0.5, 1.5, 2.0, 3.0]:
			tb.place(b0 + sb, bank.bass_pluck(bass, 0.55, lp=440.0), gain=0.25 if sb in (0.0, 2.0) else 0.16, pan=0.0, rev=0.1)
		_arp_bar(tb, bank, bar, ch, ost, dur=0.65, gain=0.18, rev=0.38, bright=0.66, pan_spread=0.38)

	# Острая огненно-фригийская тема дудки и виолы
	fire_lead = [
		(8.0, "A4", 1.5), (9.5, "Bb4", 0.5), (10.0, "C#5", 1.5), (11.5, "D5", 0.5),
		(12.0, "Bb4", 2.0), (14.0, "A4", 2.0),
		(16.0, "C#5", 1.0), (17.0, "Bb4", 1.0), (18.0, "A4", 1.0), (19.0, "G4", 1.0), (20.0, "F4", 2.5),
		(32.0, "A4", 1.0), (33.0, "C#5", 1.5), (34.5, "E5", 1.5),
		(36.0, "D5", 2.0), (38.0, "Bb4", 2.0), (40.0, "C#5", 1.5), (41.5, "Bb4", 1.0), (42.5, "G4", 1.5), (44.0, "A4", 3.2),
	]
	_play_melody(tb, bank, lambda n, d, s: bank.flute(n, d, breath=0.16, slide=s), fire_lead, pan=-0.12, rev=0.52, gain=0.19)
	tb.render(out_path, room=0.72, damp=0.45, wet_mix=0.44, target_rms_db=-16.0)


def build_music_elite(bank, out_path):
	"""8. «Зов глубин» — Элитные враги и Логова духов (C Минор, 102 BPM, 12 тактов = 28.24 с)."""
	tb = TrackBuilder(bpm=102.0, bars=12, beats_per_bar=4, seed=108)
	prog = [
		(["C3", "G3", "C4", "Eb4"], "C2", ["C3", "G3"]),
		(["Ab2", "Eb3", "Ab3", "C4"], "Ab1", ["Ab2", "Eb3"]),
		(["F2", "C3", "F3", "Ab3"], "F1", ["F2", "C3"]),
		(["G2", "D3", "G3", "B3"], "G1", ["G2", "D3"]),
		(["C3", "G3", "C4", "Eb4"], "C2", ["C3", "G3"]),
		(["Eb3", "Bb3", "Eb4", "G4"], "Eb2", ["Eb3", "Bb3"]),
		(["Ab2", "Eb3", "Bb3", "C4"], "Ab1", ["Ab2", "Eb3"]),
		(["G2", "D3", "G3", "B3"], "G1", ["G2", "D3"]),
		(["F2", "C3", "Ab3", "C4"], "F1", ["F2", "C3"]),
		(["G2", "D3", "Bb3", "D4"], "G1", ["G2", "D3"]),
		(["Ab2", "Eb3", "C4", "Eb4"], "Ab1", ["Ab2", "Eb3"]),
		(["G2", "D3", "G3", "B3"], "G1", ["G2", "D3"]),
	]
	ost = [(0.0, 0), (0.5, 1), (1.0, 2), (1.5, 3), (2.0, 1), (2.5, 2), (3.0, 3), (3.5, 2)]
	for bar, (ch, bass, pad_n) in enumerate(prog):
		b0 = bar * 4.0
		tb.place(b0, bank.pad(pad_n, tb.beat_sec * 3.8, lp=820.0), gain=0.13, pan=0.0, rev=0.42, jitter_ms=0.0)
		tb.place(b0 + 0.0, bank.drum("war"), gain=0.28, pan=0.0, rev=0.24)
		tb.place(b0 + 1.0, bank.drum("rim"), gain=0.16, pan=0.25, rev=0.35)
		tb.place(b0 + 1.5, bank.drum("tom"), gain=0.19, pan=-0.18, rev=0.28)
		tb.place(b0 + 2.5, bank.drum("war"), gain=0.22, pan=0.0, rev=0.24)
		tb.place(b0 + 3.0, bank.drum("rim"), gain=0.17, pan=-0.25, rev=0.35)
		for sb in [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5]:
			tb.place(b0 + sb, bank.bass_pluck(bass, 0.45, lp=460.0), gain=0.24 if sb % 1.0 == 0 else 0.14, pan=0.0, rev=0.08)
		_arp_bar(tb, bank, bar, ch, ost, dur=0.65, gain=0.18, rev=0.38, bright=0.65, pan_spread=0.45)

	horns = [
		(8.0, "G4", 1.5), (9.5, "Ab4", 0.5), (10.0, "G4", 1.5), (11.5, "Eb4", 0.5),
		(12.0, "D4", 2.5),
		(24.0, "C5", 1.5), (25.5, "Bb4", 1.0), (26.5, "Ab4", 1.5), (28.0, "G4", 3.0),
	]
	_play_melody(tb, bank, lambda n, d, s: bank.horn(n, d, bright=0.88, attack=0.08), horns, pan=0.18, rev=0.50, gain=0.20)
	viola = [
		(32.0, "Ab4", 1.5), (33.5, "C5", 1.0), (34.5, "Eb5", 1.5),
		(36.0, "D5", 2.0), (38.0, "Bb4", 2.0), (40.0, "C5", 2.0), (44.0, "B4", 3.2),
	]
	_play_melody(tb, bank, lambda n, d, s: bank.bow(n, d, bright=0.95, attack=0.07), viola, pan=-0.18, rev=0.46, gain=0.20)
	tb.render(out_path, room=0.62, damp=0.38, wet_mix=0.42, target_rms_db=-15.5)


def build_music_boss(bank, out_path):
	"""9. «Тень у Шпиля» — Боссы 1 акта (C Минор, 112 BPM, 16 тактов = 34.29 с): военный ритм + искажённая тема Колокола."""
	tb = TrackBuilder(bpm=112.0, bars=16, beats_per_bar=4, seed=109)
	prog = [
		(["C3", "G3", "C4", "Eb4"], "C2", ["C3", "G3"]),
		(["C3", "G3", "C4", "F#4"], "C2", ["C3", "F#3"]),   # тревожный тритон!
		(["Ab2", "Eb3", "Ab3", "C4"], "Ab1", ["Ab2", "Eb3"]),
		(["G2", "D3", "G3", "B3"], "G1", ["G2", "D3"]),
		(["C3", "G3", "C4", "Eb4"], "C2", ["C3", "G3"]),
		(["Eb3", "Bb3", "Eb4", "G4"], "Eb2", ["Eb3", "Bb3"]),
		(["F2", "C3", "Ab3", "C4"], "F1", ["F2", "C3"]),
		(["G2", "D3", "G3", "B3"], "G1", ["G2", "D3"]),

		(["Ab2", "Eb3", "C4", "Eb4"], "Ab1", ["Ab2", "Eb3"]),
		(["Bb2", "F3", "D4", "F4"], "Bb1", ["Bb2", "F3"]),
		(["C3", "G3", "Eb4", "G4"], "C2", ["C3", "G3"]),
		(["G2", "D3", "B3", "D4"], "G1", ["G2", "D3"]),
		(["Ab2", "Eb3", "C4", "Eb4"], "Ab1", ["Ab2", "Eb3"]),
		(["F2", "C3", "Ab3", "C4"], "F1", ["F2", "C3"]),
		(["D2", "Ab2", "F3", "C4"], "D2", ["D3", "Ab3"]),
		(["G2", "D3", "G3", "B3"], "G1", ["G2", "D3"]),
	]
	ost = [(0.0, 0), (0.5, 1), (1.0, 2), (1.5, 3), (2.0, 2), (2.5, 1), (3.0, 3), (3.5, 2)]
	for bar, (ch, bass, pad_n) in enumerate(prog):
		b0 = bar * 4.0
		tb.place(b0, bank.pad(pad_n, tb.beat_sec * 3.8, lp=880.0), gain=0.14, pan=0.0, rev=0.45, jitter_ms=0.0)
		# Двойной удар боевого барабана («бум-бум... ТЫЩ!»)
		tb.place(b0 + 0.0, bank.drum("war"), gain=0.34, pan=0.0, rev=0.25)
		tb.place(b0 + 0.5, bank.drum("war"), gain=0.22, pan=0.0, rev=0.25)
		tb.place(b0 + 1.5, bank.drum("tom"), gain=0.20, pan=-0.22, rev=0.3)
		tb.place(b0 + 2.0, bank.drum("war"), gain=0.28, pan=0.0, rev=0.25)
		tb.place(b0 + 2.0, bank.drum("rim"), gain=0.18, pan=0.25, rev=0.38)
		tb.place(b0 + 3.0, bank.drum("tom"), gain=0.22, pan=0.20, rev=0.3)
		if bar >= 8:
			tb.place(b0 + 3.5, bank.drum("anvil"), gain=0.08, pan=-0.35, rev=0.55)
		# Быстрая пульсирующая линия баса
		for sb in [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5]:
			tb.place(b0 + sb, bank.bass_pluck(bass, 0.42, lp=520.0), gain=0.27 if sb % 1.0 == 0 else 0.17, pan=0.0, rev=0.08)
		_arp_bar(tb, bank, bar, ch, ost, dur=0.56, gain=0.17, rev=0.36, bright=0.70, pan_spread=0.46)
		if bar in (0, 8, 12):
			tb.place(b0, bank.guard_bell("C2" if bar != 8 else "G2", 2.8), gain=0.18, pan=0.0, rev=0.62)

	# Грозная тема рогов Стражи (мотив Колокола в драматическом ключе)
	boss_horns = [
		(4.0, "C4", 1.5), (5.5, "Eb4", 0.5), (6.0, "F#4", 2.0),
		(8.0, "Ab4", 2.0), (10.0, "G4", 2.0), (12.0, "D4", 3.0),
		(20.0, "G4", 1.5), (21.5, "Ab4", 0.5), (22.0, "G4", 2.0), (24.0, "F4", 2.0), (28.0, "G4", 3.2),
	]
	_play_melody(tb, bank, lambda n, d, s: bank.horn(n, d, bright=0.95, attack=0.07), boss_horns, pan=0.16, rev=0.48, gain=0.25)
	# Кульминационный прорыв струнных во второй половине
	boss_viola = [
		(32.0, "Eb5", 2.0), (34.0, "C5", 2.0), (36.0, "D5", 2.0), (38.0, "F5", 2.0),
		(40.0, "G5", 3.0), (44.0, "D5", 2.5),
		(48.0, "Eb5", 2.0), (50.0, "C5", 1.5), (51.5, "Ab4", 0.5), (52.0, "F4", 2.5),
		(56.0, "Ab4", 2.0), (58.0, "F4", 1.5), (60.0, "G4", 3.5),
	]
	_play_melody(tb, bank, lambda n, d, s: bank.bow(n, d, bright=1.0, attack=0.06), boss_viola, pan=-0.16, rev=0.46, gain=0.26)
	tb.render(out_path, room=0.66, damp=0.40, wet_mix=0.42, target_rms_db=-15.0)


# ==============================================================================
# ЭМБИЕНТЫ АТМОСФЕРЫ (6 БЕСШОВНЫХ ФОНОВ)
# ==============================================================================

def _finalize_ambience(out_l, out_r, loop_n, path, target_rms_db=-24.0):
	full_l = dc_block(out_l)
	full_r = dc_block(out_r)
	l = wrap_loop(full_l, loop_n, xfade_ms=25.0)
	r = wrap_loop(full_r, loop_n, xfade_ms=25.0)
	mono_ms = sum(((a + b) * 0.5) ** 2 for a, b in zip(l, r)) / len(l)
	cur = 10.0 * math.log10(max(mono_ms, 1e-12))
	g = db_to_lin(target_rms_db - cur)
	l = [x * g for x in l]
	r = [x * g for x in r]
	if len(l) > 8:
		l[-1] = (l[-1] + l[0]) * 0.5
		l[0] = l[-1]
		r[-1] = (r[-1] + r[0]) * 0.5
		r[0] = r[-1]
	peak = max(max((abs(x) for x in l), default=0.0), max((abs(x) for x in r), default=0.0))
	save_wav(path, l, r, peak_db=min(-1.5, 20.0 * math.log10(max(peak, 1e-12))), limit=True, dc=False)


def build_amb_hub(out_path):
	"""Хаб и привал: уютное потрескивание костра + мягкий вечерний ветер заставы."""
	dur = 14.0
	loop_n = int(RATE * dur)
	tot = loop_n + int(RATE * 2.0)
	rng = random.Random(201)
	wind = biquad_sweep(pink_noise(tot, 202), "bp", lambda t: 310.0 + 160.0 * math.sin(TWO_PI * 0.14 * t), q=1.1)
	hearth = biquad(pink_noise(tot, 203), "bp", 380.0, 0.8)
	out_l = [wind[i] * 0.48 + hearth[i] * 0.45 for i in range(tot)]
	out_r = [wind[(i + 900) % tot] * 0.48 + hearth[i] * 0.45 for i in range(tot)]
	# Тёплые сухие щелчки углей и смолы (живой костёр!)
	for k in range(76):
		st = rng.uniform(0.05, dur - 0.1)
		pan = rng.uniform(-0.38, 0.38)
		fc = rng.uniform(1200.0, 4200.0)
		cn = int(RATE * 0.018)
		pop = biquad(make_noise(cn, 210 + k), "bp", fc, 1.8)
		amp = rng.uniform(0.45, 1.15)
		mix_stereo(out_l, out_r, [pop[j] * env_ad(j / RATE, 0.018, 0.0005, 2.8) for j in range(cn)], int(RATE * st), amp, pan=pan)
	_finalize_ambience(out_l, out_r, loop_n, out_path, target_rms_db=-24.5)


def build_amb_swamp(out_path):
	"""Болота (gat, reeds, lair): сквозняк в камыше и редкие гулкие пузыри трясины."""
	dur = 14.0
	loop_n = int(RATE * dur)
	tot = loop_n + int(RATE * 2.0)
	rng = random.Random(220)
	reed = biquad_sweep(pink_noise(tot, 221), "bp", lambda t: 620.0 + 340.0 * math.sin(TWO_PI * 0.21 * t), q=1.3)
	air_low = biquad(pink_noise(tot, 222), "lp", 210.0, 0.7)
	wet_l = [0.0] * tot
	wet_r = [0.0] * tot
	for k in range(14):
		st = rng.uniform(0.2, dur - 0.5)
		pan = rng.uniform(-0.7, 0.7)
		f0 = rng.uniform(160.0, 360.0)
		bdur = rng.uniform(0.07, 0.13)
		bn = int(RATE * bdur)
		phase = 0.0
		bub = [0.0] * bn
		for j in range(bn):
			bt = j / RATE
			phase += TWO_PI * (f0 + 250.0 * (bt / bdur)) / RATE
			bub[j] = math.sin(phase) * env_ad(bt, bdur, 0.006, 2.0) * 0.65
		mix_stereo(wet_l, wet_r, bub, int(RATE * st), 0.95, pan=pan)
	rl, rr = reverb_stereo(wet_l, wet_r, wet=0.35, room=0.55, damp=0.45)
	out_l = [reed[i] * 0.85 + air_low[i] * 0.35 + rl[i] for i in range(tot)]
	out_r = [reed[(i + 1200) % tot] * 0.85 + air_low[i] * 0.35 + rr[i] for i in range(tot)]
	_finalize_ambience(out_l, out_r, loop_n, out_path, target_rms_db=-24.5)


def build_amb_grove(out_path):
	"""Мёртвая роща и застава: порывистый ветер в ветвях и редкий скрип старого дерева."""
	dur = 14.0
	loop_n = int(RATE * dur)
	tot = loop_n + int(RATE * 2.0)
	rng = random.Random(240)
	wind_l = biquad_sweep(pink_noise(tot, 241), "bp", lambda t: 290.0 + 340.0 * (0.5 + 0.5 * math.sin(TWO_PI * 0.16 * t)), q=1.4)
	wind_r = biquad_sweep(pink_noise(tot, 242), "bp", lambda t: 310.0 + 320.0 * (0.5 + 0.5 * math.cos(TWO_PI * 0.16 * t)), q=1.4)
	wet_l = [0.0] * tot
	wet_r = [0.0] * tot
	for st, f0, pan in [(2.6, 185.0, -0.55), (8.9, 152.0, 0.60)]:
		cdur = 0.55
		cn = int(RATE * cdur)
		cr = [0.0] * cn
		phase = 0.0
		for j in range(cn):
			jt = j / RATE
			phase = (phase + (f0 + 18.0 * math.sin(TWO_PI * 9.0 * jt)) / RATE) % 1.0
			cr[j] = math.tanh((phase * 2.0 - 1.0) * 1.5) * math.sin(math.pi * jt / cdur)
		cr = biquad(cr, "bp", 480.0, 2.5)
		mix_stereo(wet_l, wet_r, cr, int(RATE * st), 0.35, pan=pan)
	rl, rr = reverb_stereo(wet_l, wet_r, wet=0.35, room=0.58, damp=0.45)
	out_l = [wind_l[i] * 0.8 + rl[i] for i in range(tot)]
	out_r = [wind_r[i] * 0.8 + rr[i] for i in range(tot)]
	_finalize_ambience(out_l, out_r, loop_n, out_path, target_rms_db=-24.5)


def build_amb_ruins(out_path):
	"""Затопленные руины: гулкий каменный сквозняк и далёкие капли воды с долгим эхом."""
	dur = 14.0
	loop_n = int(RATE * dur)
	tot = loop_n + int(RATE * 2.4)
	rng = random.Random(260)
	hollow = biquad(pink_noise(tot, 261), "bp", 190.0, 1.5)
	wet_l = [0.0] * tot
	wet_r = [0.0] * tot
	for k in range(14):
		st = rng.uniform(0.3, dur - 0.8)
		pan = rng.uniform(-0.75, 0.75)
		f0 = rng.uniform(750.0, 1850.0)
		dn = int(RATE * 0.04)
		drop = [math.sin(TWO_PI * (f0 + 480.0 * (j / dn)) * (j / RATE)) * env_ad(j / RATE, 0.04, 0.001, 2.4) * 0.5 for j in range(dn)]
		mix_stereo(wet_l, wet_r, drop, int(RATE * st), 0.55, pan=pan)
	rl, rr = reverb_stereo(wet_l, wet_r, wet=0.65, room=0.82, damp=0.30, predelay_ms=22.0)
	out_l = [hollow[i] * 0.65 + rl[i] for i in range(tot)]
	out_r = [hollow[(i + 1500) % tot] * 0.65 + rr[i] for i in range(tot)]
	_finalize_ambience(out_l, out_r, loop_n, out_path, target_rms_db=-24.0)


def build_amb_cave(out_path):
	"""Тлеющая пещера: низкий подземный рокот, жар лавы и редкое шипение пара."""
	dur = 12.0
	loop_n = int(RATE * dur)
	tot = loop_n + int(RATE * 2.0)
	rng = random.Random(280)
	rumble = biquad(pink_noise(tot, 281), "lp", 200.0, 0.85)
	glow = biquad(pink_noise(tot, 282), "bp", 480.0, 0.9)
	hiss_l = [0.0] * tot
	hiss_r = [0.0] * tot
	for k in range(11):
		st = rng.uniform(0.2, dur - 0.8)
		pan = rng.uniform(-0.7, 0.7)
		hdur = rng.uniform(0.35, 0.65)
		hn = int(RATE * hdur)
		jet = biquad_sweep(pink_noise(hn, 290 + k), "bp", lambda t: 2100.0 - 1050.0 * (t / hdur), q=1.3)
		mix_stereo(hiss_l, hiss_r, [jet[j] * math.sin(math.pi * j / hn) for j in range(hn)], int(RATE * st), 0.85, pan=pan)
	rl, rr = reverb_stereo(hiss_l, hiss_r, wet=0.45, room=0.72, damp=0.40)
	out_l = [rumble[i] * 0.48 + glow[i] * 0.35 + rl[i] for i in range(tot)]
	out_r = [rumble[(i + 1100) % tot] * 0.48 + glow[(i + 500) % tot] * 0.35 + rr[i] for i in range(tot)]
	_finalize_ambience(out_l, out_r, loop_n, out_path, target_rms_db=-24.0)


def build_amb_rain(out_path):
	"""Болотная морось поверх боя: мягкая многослойная пелена дождя + капли по воде."""
	dur = 12.0
	loop_n = int(RATE * dur)
	tot = loop_n + int(RATE * 1.5)
	rng = random.Random(300)
	rain_l = biquad(pink_noise(tot, 301), "bp", 1950.0, 0.55)
	rain_r = biquad(pink_noise(tot, 302), "bp", 2050.0, 0.55)
	body = biquad(pink_noise(tot, 303), "lp", 620.0, 0.7)
	out_l = [rain_l[i] * 0.55 + body[i] * 0.45 for i in range(tot)]
	out_r = [rain_r[i] * 0.55 + body[(i + 700) % tot] * 0.45 for i in range(tot)]
	for k in range(60):
		st = rng.uniform(0.05, dur - 0.1)
		pan = rng.uniform(-0.85, 0.85)
		dn = int(RATE * 0.022)
		drop = biquad(make_noise(dn, 310 + k), "bp", rng.uniform(2200.0, 5200.0), 2.2)
		mix_stereo(out_l, out_r, [drop[j] * env_ad(j / RATE, 0.022, 0.0008, 2.8) for j in range(dn)], int(RATE * st), 0.35, pan=pan)
	_finalize_ambience(out_l, out_r, loop_n, out_path, target_rms_db=-24.5)


def main(base_sound_dir=None):
	if base_sound_dir is None:
		base_sound_dir = os.path.join(SRC_DIR, "..")
	music_dir = os.path.join(base_sound_dir, "music")
	amb_dir = os.path.join(base_sound_dir, "ambience")
	os.makedirs(music_dir, exist_ok=True)
	os.makedirs(amb_dir, exist_ok=True)

	bank = SynthBank(seed=42)
	tracks = [
		("music_hub.wav", build_music_hub),
		("music_map.wav", build_music_map),
		("music_rest.wav", build_music_rest),
		("music_bog.wav", build_music_bog),
		("music_grove.wav", build_music_grove),
		("music_ruins.wav", build_music_ruins),
		("music_cave.wav", build_music_cave),
		("music_elite.wav", build_music_elite),
		("music_boss.wav", build_music_boss),
	]
	for fname, fn in tracks:
		fn(bank, os.path.join(music_dir, fname))
		print("  музыка:", fname)

	ambs = [
		("amb_hub.wav", build_amb_hub),
		("amb_swamp.wav", build_amb_swamp),
		("amb_grove.wav", build_amb_grove),
		("amb_ruins.wav", build_amb_ruins),
		("amb_cave.wav", build_amb_cave),
		("amb_rain.wav", build_amb_rain),
	]
	for fname, fn in ambs:
		fn(os.path.join(amb_dir, fname))
		print("  эмбиент:", fname)
	print("Готово: 9 тем и 6 атмосфер.")


if __name__ == "__main__":
	out = sys.argv[1] if len(sys.argv) > 1 else None
	main(out)

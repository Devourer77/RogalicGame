# Автоматический акустический инспектор сгенерированных WAV-файлов:
# проверяет пики, RMS-громкость, DC-смещение, 3-полосный баланс (низ/середина/верх)
# и бесшовность стыка петли для music_* и amb_*.
import glob
import math
import os
import struct
import sys
import wave

SRC_DIR = os.path.dirname(os.path.abspath(__file__))
if SRC_DIR not in sys.path:
	sys.path.insert(0, SRC_DIR)

import dsp


def _read_wav(path):
	with wave.open(path, "rb") as w:
		ch = w.getnchannels()
		rate = w.getframerate()
		nframes = w.getnframes()
		raw = w.readframes(nframes)
	ints = struct.unpack("<%dh" % (nframes * ch), raw)
	if ch == 1:
		mono = [x / 32768.0 for x in ints]
		return rate, ch, mono, mono
	l = [ints[i] / 32768.0 for i in range(0, len(ints), 2)]
	r = [ints[i + 1] / 32768.0 for i in range(0, len(ints), 2)]
	return rate, ch, l, r


def _rms_db(buf):
	if not buf:
		return -120.0
	ms = sum(x * x for x in buf) / len(buf)
	return 10.0 * math.log10(max(ms, 1e-12))


def inspect_dir(sound_dir):
	files = sorted(glob.glob(os.path.join(sound_dir, "**", "*.wav"), recursive=True))
	print(f"Всего WAV: {len(files)}")
	issues = []
	for p in files:
		rel = os.path.relpath(p, sound_dir)
		rate, ch, l, r = _read_wav(p)
		dur = len(l) / rate
		peak = max(max((abs(x) for x in l), default=0.0), max((abs(x) for x in r), default=0.0))
		peak_db = 20.0 * math.log10(max(peak, 1e-12))
		mono = [(a + b) * 0.5 for a, b in zip(l, r)] if ch == 2 else l
		rms_db = _rms_db(mono)
		dc = abs(sum(mono) / max(1, len(mono)))
		# Быстрая 3-полосная оценка (до 4 с для скорости)
		probe = mono[:min(len(mono), rate * 4)]
		low = _rms_db(dsp.biquad(probe, "lp", 250.0, 0.707))
		mid = _rms_db(dsp.biquad(probe, "bp", 1000.0, 0.707))
		high = _rms_db(dsp.biquad(probe, "hp", 3200.0, 0.707))

		loop_jump = 0.0
		is_loop = rel.startswith("music") or rel.startswith("ambience")
		if is_loop:
			loop_jump = max(abs(l[-1] - l[0]), abs(r[-1] - r[0]))

		flags = []
		if rate != 44100:
			flags.append(f"rate={rate}")
		if peak > 0.99:
			flags.append("CLIP")
		if rms_db < -42.0:
			flags.append("TOO_QUIET")
		if dc > 0.01:
			flags.append(f"DC={dc:.3f}")
		if is_loop and loop_jump > 0.03:
			flags.append(f"LOOP_SEAM={loop_jump:.3f}")
		if flags:
			issues.append((rel, flags))

		extra = f" | seam={loop_jump:.4f}" if is_loop else ""
		print(f"{rel:32s} | {ch}ch {dur:5.2f}s | pk {peak_db:5.1f}dB | rms {rms_db:5.1f}dB | L/M/H {low:5.1f}/{mid:5.1f}/{high:5.1f}{extra}" + (f" !! {flags}" if flags else ""))

	print("\nПроблем найдено:", len(issues))
	for rel, fl in issues:
		print("  !!", rel, fl)


if __name__ == "__main__":
	d = sys.argv[1] if len(sys.argv) > 1 else os.path.join(SRC_DIR, "..")
	inspect_dir(d)

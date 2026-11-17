#!/usr/bin/env python3
"""Synthèse procédurale de tout l'audio du jeu : SFX, ambiances, musiques.

Aucun sample externe : chaque son est fabriqué ici (oscillateurs, bruit filtré,
Karplus-Strong pour les cordes), donc libre de droits par construction.
Les boucles (musiques, ambiances) sont rendues de façon circulaire — les queues
de notes et de réverbe reviennent au début — pour boucler sans couture.

Dépendances : numpy + soundfile (libsndfile avec Vorbis).
    python3 -m venv /tmp/rio-audio && /tmp/rio-audio/bin/pip install numpy soundfile
    /tmp/rio-audio/bin/python tools/audio/synth_audio.py            # tout
    /tmp/rio-audio/bin/python tools/audio/synth_audio.py coin beach  # une sélection

Un fichier .ogg déposé à la main au même chemin remplace simplement la version
synthétique (AudioManager charge le chemin, peu importe d'où vient le fichier).
"""
import os
import sys

import numpy as np
import soundfile as sf

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUS_DIR = os.path.join(ROOT, "assets", "audio", "music")


# ───────────────────────────── utilitaires ─────────────────────────────

def ns(d):
	return max(1, int(round(d * SR)))


def secs(n):
	return np.arange(n) / SR


def db(x):
	return 10 ** (x / 20)


def fft_filter(x, gain_fn, circular=False):
	n = len(x)
	pad = 0 if circular else min(8192, max(1024, n // 2))
	y = np.concatenate([x, np.zeros(pad)]) if pad else x
	X = np.fft.rfft(y)
	f = np.fft.rfftfreq(len(y), 1 / SR)
	return np.fft.irfft(X * gain_fn(f), len(y))[:n]


def _edge(f, f0, width):
	return np.clip((f - f0) / max(width, 1e-6) + 0.5, 0.0, 1.0)


def bandpass(x, lo, hi, soft=0.4, circular=False):
	def g(f):
		a = _edge(f, lo, lo * soft) if lo > 0 else 1.0
		b = 1.0 - _edge(f, hi, hi * soft)
		return a * b
	return fft_filter(x, g, circular)


def lowpass(x, hi, soft=0.4, circular=False):
	return bandpass(x, 0, hi, soft, circular)


def highpass(x, lo, soft=0.4, circular=False):
	return bandpass(x, lo, SR, soft, circular)


def colored_noise(n, rng, power=0.0):
	w = rng.standard_normal(n)
	if power == 0:
		return w
	y = fft_filter(w, lambda f: 1.0 / np.maximum(f, 20.0) ** power, circular=True)
	return y / (np.std(y) + 1e-12)


def lfo(n, rate_hz, rng, lo=0.0, hi=1.0):
	"""Modulation lente aléatoire, circulaire (boucle sans saut)."""
	y = lowpass(rng.standard_normal(n), rate_hz, soft=0.8, circular=True)
	y = (y - y.min()) / (y.max() - y.min() + 1e-12)
	return lo + (hi - lo) * y


def env_perc(n, attack, decay):
	t = secs(n)
	a = np.minimum(t / max(attack, 1e-5), 1.0)
	return a * np.exp(-np.maximum(t - attack, 0.0) / max(decay, 1e-5))


def fade_tail(x, d=0.01):
	k = min(len(x), ns(d))
	x[-k:] *= np.linspace(1, 0, k)
	return x


def norm_peak(x, peak_db):
	p = np.max(np.abs(x)) + 1e-12
	return x * (db(peak_db) / p)


def sweep_phase(freq):
	return 2 * np.pi * np.cumsum(freq) / SR


# ───────────────────────────── instruments ─────────────────────────────

def surdo(rng, f=55.0, open_=True, vel=1.0):
	d = 0.9 if open_ else 0.2
	n = ns(d)
	t = secs(n)
	ph = sweep_phase(f * (1 + 0.6 * np.exp(-t / 0.04)))
	body = (np.sin(ph) + 0.25 * np.sin(2 * ph + 0.3)) * env_perc(n, 0.003, 0.45 if open_ else 0.06)
	beater = lowpass(rng.standard_normal(n), 900) * env_perc(n, 0.001, 0.012) * 0.5
	return vel * (body + beater)


def tamborim(rng, vel=1.0):
	n = ns(0.12)
	t = secs(n)
	tone = np.sin(2 * np.pi * 760 * t) * env_perc(n, 0.001, 0.03)
	snap = bandpass(rng.standard_normal(n), 1800, 7000) * env_perc(n, 0.0005, 0.02)
	return vel * (0.7 * tone + 0.5 * snap)


def shaker(rng, vel=1.0, dur=0.09):
	n = ns(dur)
	x = bandpass(rng.standard_normal(n), 3500, 12000)
	return vel * 0.5 * x * env_perc(n, 0.008, dur * 0.35)


def bell(freq, dur=0.9, vel=1.0, partials=((1, 1, 1), (2.76, 0.4, 0.5), (5.4, 0.2, 0.3))):
	n = ns(dur)
	t = secs(n)
	y = np.zeros(n)
	for r, a, dk in partials:
		y += a * np.sin(2 * np.pi * freq * r * t) * np.exp(-t / (dur * 0.35 * dk))
	y *= np.minimum(t / 0.002, 1)
	return vel * y


def chime(freq, dur=0.6, vel=1.0):
	"""Cloche douce, harmonique (UI, pièces)."""
	return bell(freq, dur, vel, ((1, 1, 1), (2.0, 0.35, 0.6), (3.0, 0.12, 0.4), (4.2, 0.08, 0.25)))


def agogo(high, vel=1.0):
	return bell(900 if high else 640, 0.45, vel * 0.5)


def caixa(rng, vel=1.0, dur=0.16, tone=190):
	n = ns(dur)
	t = secs(n)
	sn = bandpass(rng.standard_normal(n), 1500, 9000) * env_perc(n, 0.001, dur * 0.3)
	body = np.sin(2 * np.pi * tone * t) * env_perc(n, 0.001, 0.03)
	return vel * (0.55 * sn + 0.5 * body)


def rimshot(rng, vel=1.0):
	n = ns(0.08)
	t = secs(n)
	return vel * (0.6 * np.sin(2 * np.pi * 1700 * t) * env_perc(n, 0.0005, 0.008)
		+ 0.5 * bandpass(rng.standard_normal(n), 2000, 6000) * env_perc(n, 0.0005, 0.01)
		+ 0.4 * np.sin(2 * np.pi * 420 * t) * env_perc(n, 0.0005, 0.02))


def clap(rng, vel=1.0):
	n = ns(0.25)
	t = secs(n)
	x = bandpass(rng.standard_normal(n), 900, 5000)
	e = np.zeros(n)
	for k, off in enumerate((0.0, 0.011, 0.022)):
		e += np.where(t >= off, np.exp(-np.maximum(t - off, 0) / (0.008 if k < 2 else 0.08)), 0)
	return vel * 0.6 * x * e


def kick808(f=48.0, dur=0.7, vel=1.0):
	n = ns(dur)
	t = secs(n)
	ph = sweep_phase(f * (1 + 2.0 * np.exp(-t / 0.025)))
	return vel * np.tanh(1.6 * np.sin(ph)) * env_perc(n, 0.002, dur * 0.4)


def conga(rng, f=230.0, vel=1.0):
	n = ns(0.3)
	t = secs(n)
	ph = sweep_phase(f * (1 + 0.25 * np.exp(-t / 0.02)))
	slap = bandpass(rng.standard_normal(n), 1000, 5000) * env_perc(n, 0.0005, 0.008)
	return vel * (np.sin(ph) * env_perc(n, 0.001, 0.09) + 0.3 * slap)


def triangle_inst(rng, open_=True, vel=1.0):
	dur = 0.6 if open_ else 0.06
	n = ns(dur)
	t = secs(n)
	y = np.zeros(n)
	for fr, a in ((4200, 1), (5650, 0.6), (7300, 0.4), (9100, 0.25)):
		y += a * np.sin(2 * np.pi * fr * t + rng.uniform(0, 6))
	return vel * 0.16 * y * env_perc(n, 0.0008, dur * 0.4)


def stick(rng, vel=1.0):
	n = ns(0.05)
	t = secs(n)
	return vel * (0.5 * np.sin(2 * np.pi * 1200 * t) + 0.5 * bandpass(rng.standard_normal(n), 1500, 6000)) * env_perc(n, 0.0005, 0.01)


def pluck(freq, dur, rng, vel=1.0, bright=0.6, decay_s=1.2):
	"""Corde pincée Karplus-Strong, délai fractionnaire exact (accordée)."""
	D = SR / freq
	N = int(np.floor(D - 0.5))
	e = (D - 0.5) - N
	n = ns(dur)
	exc = rng.uniform(-1, 1, N)
	k = 1 + int((1 - bright) * 6)
	if k > 1:
		exc = np.convolve(exc, np.ones(k) / k, mode="same")
	exc -= exc.mean()
	g = db(-60 * (D / SR) / decay_s)
	w0, w1, w2 = 0.5 * (1 - e), 0.5, 0.5 * e
	total = n + N
	out = np.zeros(total)
	out[:N] = exc
	start = N
	while start < total:
		prev = out[start - N:start]
		p1 = np.empty(N)
		p1[0] = out[start - N - 1] if start - N - 1 >= 0 else 0.0
		p1[1:] = prev[:-1]
		p2 = np.empty(N)
		p2[0] = out[start - N - 2] if start - N - 2 >= 0 else 0.0
		p2[1] = out[start - N - 1] if start - N - 1 >= 0 else 0.0
		p2[2:] = prev[:-2]
		seg = g * (w0 * prev + w1 * p1 + w2 * p2)
		end = min(start + N, total)
		out[start:end] = seg[:end - start]
		start = end
	return fade_tail(vel * out[:n], 0.02)


def epiano(freq, dur, vel=1.0):
	n = ns(dur + 0.5)
	t = secs(n)
	index = 1.1 * np.exp(-t / 0.25)
	y = np.sin(2 * np.pi * freq * t + index * np.sin(2 * np.pi * freq * t))
	y += 0.12 * np.sin(2 * np.pi * freq * 4 * t) * np.exp(-t / 0.05)
	amp = np.minimum(t / 0.003, 1) * np.exp(-t / 1.6) * np.clip((dur + 0.5 - t) / 0.5, 0, 1)
	return vel * 0.5 * y * amp


def vibes(freq, dur, vel=1.0):
	n = ns(dur + 0.8)
	t = secs(n)
	trem = 1 - 0.3 * (0.5 + 0.5 * np.sin(2 * np.pi * 5.5 * t))
	y = np.sin(2 * np.pi * freq * t) + 0.2 * np.sin(2 * np.pi * freq * 4 * t) * np.exp(-t / 0.1)
	amp = np.minimum(t / 0.002, 1) * np.exp(-t / 1.2) * np.clip((dur + 0.8 - t) / 0.8, 0, 1)
	return vel * 0.5 * y * amp * trem


def flute(freq, dur, rng, vel=1.0):
	n = ns(dur + 0.15)
	t = secs(n)
	vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.12) / 0.2, 0, 1)
	ph = sweep_phase(freq * vib)
	y = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.06 * np.sin(3 * ph)
	breath = bandpass(rng.standard_normal(n), freq, freq * 4) * 0.06
	a = np.clip(t / 0.05, 0, 1) * np.clip((dur + 0.15 - t) / 0.15, 0, 1)
	return vel * 0.5 * (y + breath) * a


def reed(freq, dur, vel=1.0):
	"""Sanfona (accordéon) : deux anches légèrement désaccordées."""
	n = ns(dur + 0.08)
	t = secs(n)
	y = np.zeros(n)
	for det in (1.0, 1.0035):
		ph = 2 * np.pi * freq * det * t
		for k in range(1, 9):
			y += (1.0 / k) * (0.6 if k % 2 == 0 else 1.0) * np.sin(k * ph)
	a = np.clip(t / 0.03, 0, 1) * np.clip((dur + 0.08 - t) / 0.08, 0, 1)
	return vel * 0.18 * y * a


def brass(freq, dur, vel=1.0):
	n = ns(dur + 0.1)
	t = secs(n)
	vib = 1 + 0.005 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.2) / 0.2, 0, 1)
	ph = sweep_phase(freq * vib)
	y = np.zeros(n)
	for k in range(1, 12):
		bright = np.clip(t / (0.015 * k), 0, 1)
		y += (1.0 / k) * bright * np.sin(k * ph)
	a = np.clip(t / 0.02, 0, 1) * np.clip((dur + 0.1 - t) / 0.1, 0, 1)
	return vel * 0.3 * y * a


def pad(freq, dur, vel=1.0, attack=0.5, release=0.8):
	n = ns(dur + release)
	t = secs(n)
	y = np.zeros(n)
	for det in (0.997, 1.0, 1.003):
		ph = 2 * np.pi * freq * det * t
		for k in range(1, 6):
			y += (1.0 / k ** 1.5) * np.sin(k * ph + det * k)
	a = np.clip(t / attack, 0, 1) * np.clip((dur + release - t) / release, 0, 1)
	return vel * 0.12 * y * a


def bass(freq, dur, vel=1.0):
	n = ns(dur + 0.05)
	t = secs(n)
	y = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(4 * np.pi * freq * t) + 0.1 * np.sin(6 * np.pi * freq * t)
	a = np.clip(t / 0.005, 0, 1) * np.exp(-t / 0.8) * np.clip((dur + 0.05 - t) / 0.05, 0, 1)
	return vel * 0.6 * y * a


# ───────────────────────────── théorie ─────────────────────────────

PC = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
	"G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
QUAL = {"": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10],
	"m7b5": [0, 3, 6, 10], "7b9": [0, 4, 7, 10, 13], "9": [0, 4, 7, 10, 14], "13": [0, 4, 10, 14, 21],
	"maj9": [0, 4, 7, 11, 14], "m9": [0, 3, 7, 10, 14], "7#5": [0, 4, 8, 10], "6": [0, 4, 7, 9]}
MAJOR = [0, 2, 4, 5, 7, 9, 11]
MINOR = [0, 2, 3, 5, 7, 8, 10]
MIXO = [0, 2, 4, 5, 7, 9, 10]


def parse_chord(name, shift=0):
	root = name[0]
	rest = name[1:]
	if rest[:1] in ("#", "b") and not rest.startswith("b5") and not rest.startswith("b9"):
		root += rest[0]
		rest = rest[1:]
	return ((PC[root] + shift) % 12, QUAL[rest])


def mtof(m):
	return 440.0 * 2 ** ((m - 69) / 12)


def voicing(root_pc, ivs, low=52):
	src = ivs[1:] if len(ivs) > 3 else ivs
	notes = sorted({low + ((root_pc + iv - low) % 12) for iv in src})
	return notes


def bass_note(root_pc, offset=0):
	m = 36 + (root_pc + offset) % 12
	return m - 12 if m >= 45 else m


RHYTHMS = [
	[(0, 3), (3, 3), (6, 2), (8, 6)],
	[(2, 2), (4, 2), (6, 4), (10, 2), (12, 4)],
	[(0, 6), (6, 2), (8, 2), (10, 6)],
	[(3, 3), (6, 3), (9, 7)],
	[(0, 2), (2, 2), (4, 4), (10, 2), (12, 2), (14, 2)],
]


def gen_melody(chords, scale_root, scale, rng, bars, start_bar, low, high):
	scale_pcs = {(scale_root + s) % 12 for s in scale}
	notes = []
	prev = (low + high) // 2
	a, b, c = rng.choice(len(RHYTHMS), 3, replace=False)
	plan = [a, b, a, "E", c, b, a, "E"]
	direction = 1
	for bar in range(start_bar, bars):
		p = plan[(bar - start_bar) % 8]
		rhythm = [(0, 12)] if p == "E" else RHYTHMS[p]
		root, ivs = chords[bar % len(chords)]
		ctones = {(root + i) % 12 for i in ivs}
		for s, ln in rhythm:
			if p == "E":
				cands = [m for m in range(low, high + 1) if m % 12 == root]
			elif s % 4 == 0 or ln >= 4:
				cands = [m for m in range(low, high + 1) if m % 12 in ctones and m != prev]
			else:
				cands = [m for m in range(low, high + 1) if m % 12 in scale_pcs and 0 < abs(m - prev) <= 2]
				cands = [m for m in cands if (m - prev) * direction > 0] or cands
			if not cands:
				cands = [prev]
			cands.sort(key=lambda m: abs(m - prev))
			m = cands[0] if (rng.random() < 0.6 or len(cands) == 1) else cands[1]
			if m >= high - 2:
				direction = -1
			elif m <= low + 2:
				direction = 1
			elif rng.random() < 0.2:
				direction = -direction
			notes.append((bar, s, ln, m))
			prev = m
	return notes


# ───────────────────────────── séquenceur ─────────────────────────────

class Track:
	"""Tampon stéréo circulaire : ce qui dépasse la fin revient au début."""

	def __init__(self, length_s, seed=0):
		self.n = ns(length_s)
		self.buf = np.zeros((self.n, 2))
		self.rng = np.random.default_rng(seed)

	def add(self, x, at_s, gain=1.0, pan=0.0, jitter=0.0):
		if jitter:
			at_s += self.rng.normal(0, jitter)
		th = (np.clip(pan, -1, 1) + 1) * np.pi / 4
		lr = np.array([np.cos(th), np.sin(th)]) * gain
		i = int(round(at_s * SR)) % self.n
		pos = 0
		while pos < len(x):
			k = min(len(x) - pos, self.n - i)
			self.buf[i:i + k] += x[pos:pos + k, None] * lr[None, :]
			pos += k
			i = 0

	def add_moving(self, x, at_s, gain, pan_from, pan_to):
		pans = np.linspace(pan_from, pan_to, len(x))
		th = (pans + 1) * np.pi / 4
		st = np.stack([x * np.cos(th), x * np.sin(th)], axis=1) * gain
		i = int(round(at_s * SR)) % self.n
		pos = 0
		while pos < len(x):
			k = min(len(x) - pos, self.n - i)
			self.buf[i:i + k] += st[pos:pos + k]
			pos += k
			i = 0

	def add_stereo(self, st, gain=1.0):
		reps = int(np.ceil(self.n / len(st)))
		self.buf += np.tile(st, (reps, 1))[:self.n] * gain


def reverb(buf, rt=1.2, wet=0.2, seed=7, circular=True):
	rng = np.random.default_rng(seed)
	n = len(buf)
	ln = min(n, ns(rt * 1.2))
	out = buf.copy()
	pad = 0 if circular else ln
	for ch in range(2):
		ir = rng.standard_normal(ln) * np.exp(-secs(ln) / (rt / 6.9))
		ir = lowpass(ir, 5000)
		ir /= np.sqrt(np.sum(ir ** 2)) + 1e-12
		x = np.concatenate([buf[:, ch], np.zeros(pad)])
		irp = np.zeros(len(x))
		irp[:ln] = ir
		y = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(irp), len(x))
		if not circular:
			y = y[:n]
		out[:, ch] = buf[:, ch] + wet * y[:n]
	return out


def master(buf, rms_db=-17.0, peak_db=-1.0):
	rms = np.sqrt(np.mean(buf ** 2)) + 1e-12
	y = buf * (db(rms_db) / rms)
	y = np.tanh(y * 1.1) / 1.1
	p = np.max(np.abs(y))
	if p > db(peak_db):
		y *= db(peak_db) / p
	return y


def strum(tr, notes, at, dur, gain, pan, down=True, spread=0.012, decay=0.5, bright=0.6):
	seq = notes if down else list(reversed(notes))
	for k, m in enumerate(seq):
		tr.add(pluck(mtof(m), dur, tr.rng, 1.0, bright, decay), at + k * spread, gain, pan, 0.002)


def add_melody(tr, notes, step, bar_s, lead, gain, pan=0.1):
	for bar, s, ln, m in notes:
		at = bar * bar_s + s * step
		d = ln * step
		f = mtof(m)
		if lead == "flute":
			x = flute(f, d, tr.rng)
		elif lead == "epiano":
			x = epiano(f, d)
		elif lead == "vibes":
			x = vibes(f, d)
		elif lead == "reed":
			x = reed(f, d)
		elif lead == "brass":
			x = brass(f, d)
		else:
			x = pluck(f, d + 0.3, tr.rng, 1.0, 0.8, 1.0)
		tr.add(x, at, gain, pan, 0.004)


# ───────────────────────────── styles ─────────────────────────────

def render_samba(prog, shift, bpm, lead, seed, scale=MINOR, scale_root=9, bars=16, mel_start=8):
	step = 60.0 / bpm / 4
	bar_s = 16 * step
	tr = Track(bars * bar_s, seed)
	r = tr.rng
	chords = [parse_chord(c, shift) for c in prog]
	accents = [0.55, 0.3, 0.45, 0.85]
	tamb = [0, 2, 5, 7, 8, 10, 13]
	agog = [(0, 1), (2, 1), (3, 0), (6, 1), (8, 0), (10, 1), (11, 0), (14, 0)]
	cav = [(0, True), (3, False), (6, True), (10, False), (12, True)]
	bline = [(0, 0, 3), (4, 7, 3), (8, 0, 3), (12, 7, 2), (14, 0, 2)]
	for b in range(bars):
		t0 = b * bar_s
		root, ivs = chords[b % len(chords)]
		for half in (0, 8):
			tr.add(surdo(r, 60, False, 0.5), t0 + half * step, 0.8, -0.15, 0.002)
			tr.add(surdo(r, 55, True), t0 + (half + 4) * step, 0.9, 0.15, 0.002)
		for s in range(16):
			tr.add(shaker(r, accents[s % 4]), t0 + s * step, 0.35, 0.45, 0.003)
		for s in tamb:
			tr.add(tamborim(r, 0.8 if s % 4 else 1.0), t0 + s * step, 0.22, -0.5, 0.003)
		if b >= 4:
			for s, hi in agog:
				tr.add(agogo(hi), t0 + s * step, 0.22, 0.6, 0.003)
		v = voicing(root, ivs, 55)
		for s, down in cav:
			strum(tr, v, t0 + s * step, 0.6 if s == 0 else 0.3, 0.16, -0.3, down, decay=0.6 if s == 0 else 0.25)
		for s, off, ln in bline:
			tr.add(bass(mtof(bass_note(root, off)), ln * step), t0 + s * step, 0.55, 0.0, 0.002)
		if lead != "epiano":
			for m in v:
				tr.add(epiano(mtof(m + 12), bar_s * 0.9), t0, 0.07, 0.2)
	mel = gen_melody(chords, (scale_root + shift) % 12, scale, r, bars, mel_start, 69, 86)
	add_melody(tr, mel, step, bar_s, lead, 0.32 if lead == "flute" else 0.4)
	return master(reverb(tr.buf, 1.3, 0.18, seed))


def render_bossa(prog, shift, bpm, lead, seed, bars=16, mel_start=4, scale_root=0):
	step = 60.0 / bpm / 4
	bar_s = 16 * step
	tr = Track(bars * bar_s, seed)
	r = tr.rng
	chords = [parse_chord(c, shift) for c in prog]
	hits = ([0, 3, 6, 10, 13], [2, 6, 9, 12])
	rims = ([0, 6, 12], [4, 10])
	for b in range(bars):
		t0 = b * bar_s
		root, ivs = chords[b % len(chords)]
		v = voicing(root, ivs, 52)
		for s, off in ((0, 0), (6, 7), (8, 0), (14, 7)):
			f = mtof(bass_note(root, off))
			tr.add(pluck(f, 1.0, r, 1.0, 0.35, 1.4), t0 + s * step, 0.45, -0.1, 0.003)
			tr.add(bass(f, 3 * step), t0 + s * step, 0.35, 0.0)
		for s in hits[b % 2]:
			strum(tr, v, t0 + s * step, 0.5, 0.15, -0.25, True, 0.006, 0.4, 0.45)
		for s in rims[b % 2]:
			tr.add(rimshot(r, 0.8), t0 + s * step, 0.12, 0.35, 0.003)
		for s in range(16):
			tr.add(shaker(r, 0.6 if s % 2 else 0.35, 0.12), t0 + s * step, 0.18, 0.5, 0.004)
		for m in v:
			tr.add(pad(mtof(m + 12), bar_s * 0.95, 1.0, 0.6, 0.6), t0, 0.08, 0.3)
	mel = gen_melody(chords, (scale_root + shift) % 12, MAJOR, r, bars, mel_start, 67, 84)
	add_melody(tr, mel, step, bar_s, lead, 0.3 if lead == "flute" else 0.38)
	return master(reverb(tr.buf, 1.6, 0.22, seed))


def render_batucada(prog, shift, bpm, seed, bars=24, cavaco=True, melody="brass", crowd=0.0, mel_start=8):
	step = 60.0 / bpm / 4
	bar_s = 16 * step
	tr = Track(bars * bar_s, seed)
	r = tr.rng
	chords = [parse_chord(c, shift) for c in prog]
	caixa_acc = [1.0, 0.35, 0.6, 0.45]
	tamb = [0, 2, 5, 7, 8, 10, 13]
	agog = [(0, 1), (3, 0), (6, 1), (8, 0), (10, 1), (13, 0)]
	for b in range(bars):
		t0 = b * bar_s
		root, ivs = chords[b % len(chords)]
		for half in (0, 8):
			tr.add(surdo(r, 64, True, 0.7), t0 + half * step, 0.7, -0.3, 0.002)
			tr.add(surdo(r, 50, True, 1.0), t0 + (half + 4) * step, 0.95, 0.3, 0.002)
		for s in (2, 6, 7, 10, 14, 15):
			tr.add(surdo(r, 78, s % 4 != 3, 0.55), t0 + s * step, 0.45, 0.0, 0.003)
		for s in range(16):
			tr.add(caixa(r, caixa_acc[s % 4], 0.1, 210), t0 + s * step, 0.2, -0.4, 0.003)
			tr.add(shaker(r, 0.9 if s % 4 in (1, 3) else 0.5, 0.07), t0 + s * step, 0.3, 0.55, 0.003)
		for s in tamb:
			tr.add(tamborim(r), t0 + s * step, 0.25, -0.6, 0.002)
		for s, hi in agog:
			tr.add(agogo(hi), t0 + s * step, 0.2, 0.65, 0.003)
		if b % 4 == 3:
			for s in range(12, 16):
				for sub in (0, 0.5):
					tr.add(caixa(r, 0.6 + 0.1 * (s - 12), 0.08, 330), t0 + (s + sub) * step, 0.25, 0.2, 0.002)
		if cavaco:
			v = voicing(root, ivs, 62)
			for s in range(16):
				strum(tr, v, t0 + s * step, 0.15, 0.09 if s % 2 else 0.13, -0.2, s % 2 == 0, 0.004, 0.12, 0.8)
			tr.add(pluck(mtof(bass_note(root)), 0.6, r, 1.0, 0.4, 0.8), t0, 0.4, 0.0)
			tr.add(pluck(mtof(bass_note(root, 7)), 0.6, r, 1.0, 0.4, 0.8), t0 + 8 * step, 0.35, 0.0)
		if crowd:
			for s in (4, 12):
				tr.add(clap(r), t0 + s * step, crowd * 0.5, r.uniform(-0.5, 0.5), 0.006)
	if melody:
		mel = gen_melody(chords, (7 + shift) % 12, MAJOR, r, bars, mel_start, 67, 84)
		add_melody(tr, mel, step, bar_s, melody, 0.32)
	if crowd:
		tr.buf += crowd_bed(tr.n, r, 0.9) * crowd * 0.25
	return master(reverb(tr.buf, 1.4, 0.2, seed))


def render_forro(prog, shift, bpm, seed, bars=16):
	step = 60.0 / bpm / 4
	bar_s = 16 * step
	tr = Track(bars * bar_s, seed)
	r = tr.rng
	chords = [parse_chord(c, shift) for c in prog]
	for b in range(bars):
		t0 = b * bar_s
		root, ivs = chords[b % len(chords)]
		for s, v in ((0, 1.0), (3, 0.6), (8, 1.0), (11, 0.6)):
			tr.add(surdo(r, 68, s % 8 == 0, v), t0 + s * step, 0.75, -0.1, 0.003)
		for s in (2, 6, 10, 14):
			tr.add(stick(r, 0.8), t0 + s * step, 0.2, -0.35, 0.003)
		for s in range(16):
			tr.add(triangle_inst(r, s % 4 == 2, 0.9 if s % 4 == 2 else 0.5), t0 + s * step, 0.5, 0.5, 0.003)
		tr.add(reed(mtof(bass_note(root)), 3 * step), t0, 0.5, -0.1)
		tr.add(reed(mtof(bass_note(root, 7)), 3 * step), t0 + 8 * step, 0.45, -0.1)
		for s in (4, 12):
			for m in voicing(root, ivs, 55):
				tr.add(reed(mtof(m), 1.5 * step), t0 + s * step, 0.18, -0.2)
	mel = gen_melody(chords, (7 + shift) % 12, MIXO, r, bars, 2, 67, 84)
	add_melody(tr, mel, step, bar_s, "reed", 0.45, 0.15)
	return master(reverb(tr.buf, 1.0, 0.15, seed))


def render_funk(prog, shift, bpm, seed, bars=16):
	step = 60.0 / bpm / 4
	bar_s = 16 * step
	tr = Track(bars * bar_s, seed)
	r = tr.rng
	chords = [parse_chord(c, shift) for c in prog]
	for b in range(bars):
		t0 = b * bar_s
		root, ivs = chords[b % len(chords)]
		for s in (0, 3, 7, 10):
			tr.add(kick808(mtof(bass_note(root)) / 2 if s == 0 else 46), t0 + s * step, 0.8, 0.0)
		for s in (4, 12):
			tr.add(clap(r), t0 + s * step, 0.5, 0.1, 0.002)
		for s in range(0, 16, 2):
			tr.add(shaker(r, 0.8 if s % 4 else 0.5, 0.05), t0 + s * step, 0.3, 0.4, 0.002)
		for s, f in ((6, 230), (9, 310), (14, 230)):
			tr.add(conga(r, f), t0 + s * step, 0.35, -0.45, 0.003)
		v = voicing(root, ivs, 57)
		for m in v:
			tr.add(pad(mtof(m), bar_s * 0.9, 1.0, 0.3, 0.4), t0, 0.1, -0.2)
			for s in (2, 11):
				tr.add(epiano(mtof(m + 12), 2 * step), t0 + s * step, 0.12, 0.25)
	mel = gen_melody(chords, (9 + shift) % 12, MINOR, r, bars, 8, 69, 86)
	add_melody(tr, mel, step, bar_s, "vibes", 0.42)
	return master(reverb(tr.buf, 1.2, 0.18, seed))


def render_mpb(prog, shift, bpm, lead, seed, scale=MAJOR, scale_root=7, bars=16):
	step = 60.0 / bpm / 4
	bar_s = 16 * step
	tr = Track(bars * bar_s, seed)
	r = tr.rng
	chords = [parse_chord(c, shift) for c in prog]
	arp = [2, 4, 6, 10, 12, 14]
	for b in range(bars):
		t0 = b * bar_s
		root, ivs = chords[b % len(chords)]
		v = voicing(root, ivs, 57)
		for s, off in ((0, 0), (8, 7)):
			tr.add(pluck(mtof(bass_note(root, off)), 1.4, r, 1.0, 0.4, 1.6), t0 + s * step, 0.5, -0.1, 0.003)
		order = v + list(reversed(v[1:-1]))
		for k, s in enumerate(arp):
			m = order[k % len(order)]
			tr.add(pluck(mtof(m), 1.0, r, 1.0, 0.55, 1.2), t0 + s * step, 0.22, -0.3 + 0.1 * (k % 3), 0.004)
		for s in range(0, 16, 2):
			tr.add(shaker(r, 0.6 if s % 4 else 0.3, 0.1), t0 + s * step, 0.15, 0.5, 0.004)
		for m in v:
			tr.add(pad(mtof(m + 12), bar_s * 0.95, 1.0, 0.8, 0.8), t0, 0.06, 0.3)
	mel = gen_melody(chords, (scale_root + shift) % 12, scale, r, bars, 8, 67, 84)
	add_melody(tr, mel, step, bar_s, lead, 0.3 if lead == "flute" else 0.38)
	return master(reverb(tr.buf, 1.8, 0.24, seed))


def render_mystic(seed):
	tr = Track(32.0, seed)
	r = tr.rng
	prog = [parse_chord(c) for c in ("Dmaj9", "Bm9", "Gmaj9", "A13")]
	penta = [62, 64, 66, 69, 71, 74, 76, 78, 81, 83]
	for i in range(8):
		root, ivs = prog[i % 4]
		for m in voicing(root, ivs, 57):
			tr.add(pad(mtof(m), 4.2, 1.0, 1.5, 1.8), i * 4.0, 0.16, r.uniform(-0.5, 0.5))
			tr.add(pad(mtof(m + 12), 4.2, 1.0, 2.0, 2.0), i * 4.0, 0.06, r.uniform(-0.7, 0.7))
		tr.add(pad(mtof(bass_note(root)), 4.2, 1.0, 1.0, 1.5), i * 4.0, 0.2, 0.0)
	t = 0.5
	while t < 32.0:
		tr.add(bell(mtof(r.choice(penta)), 2.5, 0.5), t, 0.25, r.uniform(-0.8, 0.8))
		t += r.choice([1.0, 1.5, 2.0, 3.0])
	return master(reverb(tr.buf, 3.0, 0.4, seed), -19)


# ───────────────────────────── ambiances ─────────────────────────────

def crowd_bed(n, rng, density=1.0):
	"""Rumeur de foule : bandes de voyelles modulées au rythme syllabique."""
	out = np.zeros((n, 2))
	for ch in range(2):
		base = bandpass(colored_noise(n, rng, 0.5), 250, 3200, circular=True)
		out[:, ch] += base * lfo(n, 0.3, rng, 0.5, 1.0) * 0.5
		for lo, hi in ((300, 800), (700, 1300), (1800, 2800)):
			band = bandpass(rng.standard_normal(n), lo, hi, circular=True)
			out[:, ch] += band * lfo(n, 4.0, rng, 0.0, 1.0) * 0.3 * density
	return out / (np.std(out) + 1e-12)


def gull(rng):
	parts = []
	for _ in range(rng.integers(2, 4)):
		n = ns(0.32)
		t = secs(n)
		f = 1450 - 450 * (t / t[-1]) + 200 * np.exp(-t / 0.03)
		ph = sweep_phase(f)
		y = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)
		y *= np.clip(np.sin(np.pi * t / t[-1]), 0, 1) ** 0.7
		parts.append(y)
		parts.append(np.zeros(ns(rng.uniform(0.08, 0.2))))
	return bandpass(np.concatenate(parts), 600, 5000) * 0.3


def bird_chirp(rng, kind="sparrow"):
	if kind == "sparrow":
		parts = []
		for _ in range(rng.integers(3, 7)):
			n = ns(rng.uniform(0.04, 0.08))
			t = secs(n)
			f0 = rng.uniform(3500, 5500)
			ph = sweep_phase(f0 * (1 - 0.35 * t / t[-1]))
			parts.append(np.sin(ph) * np.sin(np.pi * t / t[-1]))
			parts.append(np.zeros(ns(rng.uniform(0.03, 0.09))))
		return np.concatenate(parts) * 0.3
	# sabiá : petites phrases sifflées
	parts = []
	for _ in range(rng.integers(3, 6)):
		n = ns(rng.uniform(0.12, 0.25))
		t = secs(n)
		f0 = rng.uniform(1800, 3200)
		ph = sweep_phase(f0 * (1 + rng.uniform(-0.15, 0.15) * t / t[-1]) * (1 + 0.01 * np.sin(2 * np.pi * 25 * t)))
		parts.append(np.sin(ph) * np.clip(np.sin(np.pi * t / t[-1]), 0, 1) ** 0.5)
		parts.append(np.zeros(ns(rng.uniform(0.05, 0.15))))
	return np.concatenate(parts) * 0.25


def dog_bark(rng):
	parts = []
	for _ in range(rng.integers(1, 4)):
		n = ns(0.16)
		t = secs(n)
		f0 = 380 * (1 - 0.3 * t / t[-1])
		ph = sweep_phase(f0)
		voiced = np.tanh(2 * np.sin(ph))
		x = bandpass(voiced + 0.4 * rng.standard_normal(n), 400, 2200) * env_perc(n, 0.01, 0.05)
		parts.append(x)
		parts.append(np.zeros(ns(rng.uniform(0.15, 0.35))))
	return np.concatenate(parts)


def car_pass(rng, dur=4.5):
	n = ns(dur)
	t = secs(n)
	x = bandpass(colored_noise(n, rng, 0.8), 70, 1400)
	hum = np.sin(sweep_phase(95 * (1.08 - 0.16 * t / t[-1])))
	return (x + 0.4 * hum) * np.exp(-((t - dur / 2) / (dur / 5)) ** 2)


def horn(rng):
	n = ns(0.4)
	t = secs(n)
	y = np.zeros(n)
	for f in (420, 525):
		for k in (1, 3, 5, 7):
			y += np.sin(2 * np.pi * f * k * t) / k
	return lowpass(y, 2500) * np.clip(t / 0.01, 0, 1) * np.clip((0.4 - t) / 0.05, 0, 1) * 0.3


def moto(rng):
	n = ns(3.0)
	t = secs(n)
	f = 70 + 60 * (t / t[-1]) + 8 * np.sin(2 * np.pi * 0.7 * t)
	ph = sweep_phase(f)
	y = sum(np.sin(k * ph) / k for k in range(1, 10)) * (0.7 + 0.3 * np.sin(2 * np.pi * 25 * t))
	return bandpass(y, 90, 2500) * np.sin(np.pi * t / t[-1]) ** 2 * 0.4


def scatter(tr, make, every, gain_rng, pan_rng, rng, start=0.5):
	t = start
	L = tr.n / SR
	while t < L - 0.5:
		tr.add(make(), t, rng.uniform(*gain_rng), rng.uniform(*pan_rng))
		t += rng.uniform(every * 0.5, every * 1.5)


def amb_waves(seed, L=40.0):
	tr = Track(L, seed)
	r = tr.rng
	n = tr.n
	for ch in range(2):
		wash = lowpass(colored_noise(n, r, 1.0), 900, circular=True) * 0.5
		tr.buf[:, ch] += wash * lfo(n, 0.08, r, 0.55, 1.0)
	# déferlantes : temps répartis sur la boucle (période ~7 s)
	k = int(L / 7)
	times = np.cumsum(r.uniform(0.7, 1.3, k))
	times = times / times[-1] * L
	for tc in times:
		d = r.uniform(4.5, 6.5)
		m = ns(d)
		t = secs(m)
		env = np.clip(t / 1.6, 0, 1) ** 2 * np.exp(-np.maximum(t - 1.6, 0) / 1.4)
		crash = lowpass(colored_noise(m, r, 0.6), 2500) * env
		fizz = bandpass(r.standard_normal(m), 2500, 9000) * np.exp(-np.maximum(t - 1.8, 0) / 1.0) * np.clip((t - 1.4) / 0.4, 0, 1) * 0.25
		tr.add(crash + fizz, tc, r.uniform(0.6, 0.9), r.uniform(-0.4, 0.4))
	scatter(tr, lambda: gull(r), 9.0, (0.12, 0.22), (-0.9, 0.9), r, 3.0)
	return master(reverb(tr.buf, 1.0, 0.1, seed), -21)


def amb_city(seed, L=40.0):
	tr = Track(L, seed)
	r = tr.rng
	n = tr.n
	for ch in range(2):
		tr.buf[:, ch] += lowpass(colored_noise(n, r, 1.0), 300, circular=True) * 0.6
		tr.buf[:, ch] += bandpass(colored_noise(n, r, 0.5), 300, 3000, circular=True) * 0.08
	t = 1.0
	while t < L - 1:
		side = r.choice([-1, 1])
		tr.add_moving(car_pass(r, r.uniform(3.5, 5.5)), t, r.uniform(0.35, 0.6), -0.8 * side, 0.8 * side)
		t += r.uniform(2.0, 5.5)
	for tc in r.uniform(3, L - 3, 2):
		tr.add(horn(r), tc, 0.25, r.uniform(-0.6, 0.6))
	scatter(tr, lambda: bird_chirp(r, "sparrow"), 8.0, (0.05, 0.1), (-0.8, 0.8), r)
	return master(reverb(tr.buf, 1.5, 0.2, seed), -22)


def amb_park(seed, L=40.0, forest=False):
	tr = Track(L, seed)
	r = tr.rng
	n = tr.n
	for ch in range(2):
		leaves = bandpass(r.standard_normal(n), 1200, 7000, circular=True) * 0.2
		tr.buf[:, ch] += leaves * lfo(n, 0.15, r, 0.15, 1.0)
		tr.buf[:, ch] += lowpass(colored_noise(n, r, 1.0), 250, circular=True) * (0.15 if forest else 0.3)
	scatter(tr, lambda: bird_chirp(r, "sparrow"), 3.0 if forest else 5.0, (0.15, 0.35), (-0.9, 0.9), r)
	scatter(tr, lambda: bird_chirp(r, "sabia"), 4.0 if forest else 9.0, (0.15, 0.3), (-0.9, 0.9), r, 2.0)
	if forest:
		for ch in range(2):
			buzz = bandpass(r.standard_normal(n), 4500, 7500, circular=True)
			am = 0.5 + 0.5 * np.sin(2 * np.pi * 140 * secs(n))
			tr.buf[:, ch] += buzz * am * lfo(n, 0.12, r, 0.0, 1.0) ** 2 * 0.25
	else:
		for ch in range(2):
			tr.buf[:, ch] += crowd_bed(n, r, 0.6)[:, ch] * 0.05
	return master(reverb(tr.buf, 2.0 if forest else 1.2, 0.2, seed), -22)


def amb_favela(seed):
	radio = render_forro(["G", "G", "F", "G", "C", "C", "D7", "G"], 0, 92, seed + 1, bars=16)
	L = len(radio) / SR
	tr = Track(L, seed)
	r = tr.rng
	n = tr.n
	tiny = np.stack([np.tanh(3 * bandpass(radio[:, ch], 380, 2600, circular=True)) for ch in range(2)], axis=1)
	tr.buf += tiny * np.array([0.12, 0.05])
	for ch in range(2):
		tr.buf[:, ch] += lowpass(colored_noise(n, r, 1.0), 350, circular=True) * 0.3
		tr.buf[:, ch] += crowd_bed(n, r, 0.8)[:, ch] * 0.05
	scatter(tr, lambda: dog_bark(r), 14.0, (0.12, 0.2), (-0.9, 0.9), r, 4.0)
	scatter(tr, lambda: bird_chirp(r, "sparrow"), 6.0, (0.08, 0.15), (-0.9, 0.9), r)
	tr.add_moving(moto(r), L * 0.6, 0.3, 0.7, -0.7)
	return master(reverb(tr.buf, 1.4, 0.18, seed), -22)


def amb_wind_high(seed, L=40.0):
	tr = Track(L, seed)
	r = tr.rng
	n = tr.n
	for ch in range(2):
		gust = lfo(n, 0.12, r, 0.1, 1.0) ** 1.5
		tr.buf[:, ch] += bandpass(colored_noise(n, r, 0.7), 150, 1600, circular=True) * gust
		tr.buf[:, ch] += bandpass(r.standard_normal(n), 820, 980, 0.1, circular=True) * gust ** 2 * 0.6
	scatter(tr, lambda: gull(r), 12.0, (0.05, 0.1), (-0.9, 0.9), r, 5.0)
	return master(tr.buf, -22)


def amb_stadium(seed, L=40.0):
	tr = Track(L, seed)
	r = tr.rng
	n = tr.n
	tr.buf += crowd_bed(n, r, 1.2) * lfo(n, 0.1, r, 0.5, 1.0)[:, None]
	beat = 0.5
	t = 4.0
	while t < 14.0:
		for k in range(3):
			for _ in range(6):
				tr.add(clap(r), t + k * beat + r.normal(0, 0.012), 0.35, r.uniform(-0.8, 0.8))
		t += 4 * beat
	drums = render_batucada(["G"], 0, 120, seed + 3, bars=4, cavaco=False, melody=None)
	tr.add_stereo(np.stack([lowpass(drums[:, c], 600, circular=True) for c in range(2)], axis=1), 0.35)
	return master(reverb(tr.buf, 2.5, 0.3, seed), -20)


def amb_airport(seed, L=40.0):
	tr = Track(L, seed)
	r = tr.rng
	n = tr.n
	t = secs(n)
	for ch in range(2):
		tr.buf[:, ch] += lowpass(colored_noise(n, r, 0.7), 1800, circular=True) * 0.25
		tr.buf[:, ch] += (np.sin(2 * np.pi * 120 * t) * 0.02)
		tr.buf[:, ch] += crowd_bed(n, r, 0.5)[:, ch] * 0.08
	for tc in (6.0, 26.0):
		tr.add(chime(mtof(79), 1.5, 0.6), tc, 0.3, 0.0)
		tr.add(chime(mtof(76), 1.8, 0.6), tc + 0.45, 0.3, 0.0)
	m = ns(9.0)
	jt = secs(m)
	jet = bandpass(colored_noise(m, r, 0.6), 200, 3500) * np.sin(np.pi * jt / jt[-1]) ** 2
	tr.add_moving(jet, 14.0, 0.25, -0.6, 0.6)
	return master(reverb(tr.buf, 2.2, 0.3, seed), -22)


def amb_carnaval_distant(seed):
	drums = render_batucada(["G", "G", "D7", "G"], 0, 140, seed + 5, bars=16, cavaco=True, melody=None)
	L = len(drums) / SR
	tr = Track(L, seed)
	r = tr.rng
	tr.add_stereo(np.stack([lowpass(drums[:, c], 450, circular=True) for c in range(2)], axis=1), 0.5)
	tr.buf += crowd_bed(tr.n, r, 1.0) * 0.12
	return master(reverb(tr.buf, 2.0, 0.3, seed), -21)


# ───────────────────────────── SFX ─────────────────────────────

def sfx_coin(r):
	x = np.zeros(ns(0.45))
	a = chime(988, 0.2)
	b = chime(1319, 0.38)
	x[:len(a)] += a
	o = ns(0.07)
	x[o:o + len(b)] += b[:len(x) - o]
	return norm_peak(x, -3)


def sfx_dialogue(r):
	n = ns(0.06)
	t = secs(n)
	x = np.sin(2 * np.pi * 1350 * t) * env_perc(n, 0.001, 0.012) + 0.3 * bandpass(r.standard_normal(n), 2000, 6000) * env_perc(n, 0.0005, 0.005)
	return norm_peak(fade_tail(x), -10)


def mix(parts, total):
	x = np.zeros(ns(total))
	for snd, at, g in parts:
		i = ns(at) if at > 0 else 0
		k = min(len(snd), len(x) - i)
		if k > 0:
			x[i:i + k] += snd[:k] * g
	return x


def room(x, rt=0.8, wet=0.15):
	st = np.stack([x, x], axis=1)
	return reverb(st, rt, wet, 3, circular=False)[:, 0]


def sfx_prompt_chime(r):
	x = mix([(chime(1568, 0.25), 0, 0.7), (chime(2093, 0.3), 0.06, 0.6)], 0.4)
	return norm_peak(fade_tail(x), -9)


def sfx_quest_accepted(r):
	notes = [72, 76, 79]
	parts = [(pluck(mtof(m), 0.6, r, 1.0, 0.8, 0.8), 0.07 * i, 0.8) for i, m in enumerate(notes)]
	parts.append((chime(mtof(84), 0.6), 0.21, 0.5))
	return norm_peak(fade_tail(room(mix(parts, 0.95))), -3)


def sfx_quest_complete(r):
	parts = []
	v = [67, 71, 74, 79]
	for at in (0.0, 0.12):
		for k, m in enumerate(v):
			parts.append((pluck(mtof(m), 0.5, r, 1.0, 0.8, 0.5), at + 0.008 * k, 0.4))
	for i, m in enumerate([79, 83, 86, 91]):
		parts.append((chime(mtof(m), 0.7), 0.28 + 0.08 * i, 0.4))
	parts.append((agogo(True), 0.28, 0.5))
	parts.append((agogo(False), 0.44, 0.5))
	parts.append((surdo(r, 55, True), 0.6, 0.9))
	for k, m in enumerate(v):
		parts.append((pluck(mtof(m), 0.9, r, 1.0, 0.8, 1.0), 0.6 + 0.01 * k, 0.45))
	return norm_peak(fade_tail(room(mix(parts, 1.6), 1.0, 0.18)), -2)


def sfx_quest_failed(r):
	parts = [(epiano(mtof(69), 0.25), 0, 0.8), (epiano(mtof(65), 0.45), 0.22, 0.8),
		(surdo(r, 48, False, 1.0), 0.22, 0.7)]
	return norm_peak(fade_tail(room(mix(parts, 0.9))), -4)


def sfx_act_stinger(r):
	parts = [(surdo(r, 50, True), 0, 1.0), (surdo(r, 50, True), 0.35, 0.8), (surdo(r, 64, False), 0.55, 0.7), (surdo(r, 64, False), 0.7, 0.7)]
	t = 0.75
	k = 0
	while t < 1.45:
		parts.append((caixa(r, 0.4 + 0.6 * (t - 0.75) / 0.7, 0.08, 330), t, 0.6))
		t += 0.035
		k += 1
	parts.append((surdo(r, 50, True), 1.5, 1.2))
	for m in (55, 59, 62, 67, 71):
		parts.append((brass(mtof(m), 1.1), 1.5, 0.35))
	parts.append((chime(mtof(91), 1.2), 1.5, 0.4))
	return norm_peak(fade_tail(room(mix(parts, 3.2), 1.6, 0.25), 0.3), -1)


def sfx_item_pickup(r):
	n = ns(0.09)
	t = secs(n)
	blip = np.sin(sweep_phase(600 + 900 * t / t[-1])) * env_perc(n, 0.003, 0.06)
	return norm_peak(fade_tail(mix([(blip, 0, 0.6), (chime(1760, 0.25), 0.06, 0.6)], 0.35)), -5)


def sfx_customer_cling(r):
	ching = bell(2637, 0.5, 1.0, ((1, 1, 1), (1.19, 0.6, 0.8), (2.4, 0.3, 0.5)))
	n = ns(0.15)
	drawer = lowpass(r.standard_normal(n), 700) * env_perc(n, 0.002, 0.04)
	return norm_peak(fade_tail(room(mix([(ching, 0, 0.7), (drawer, 0.12, 0.6)], 0.65), 0.6, 0.1)), -4)


def sfx_debt_paid(r):
	parts = []
	for i in range(14):
		at = (i / 14) ** 1.3 * 0.9
		parts.append((chime(r.uniform(1800, 3000), 0.25), at, 0.5 * (1 - i / 20)))
	for m in (79, 83, 86):
		parts.append((chime(mtof(m), 0.8), 0.95, 0.35))
	return norm_peak(fade_tail(room(mix(parts, 1.6))), -3)


def sfx_cart_lift(r):
	n = ns(0.38)
	t = secs(n)
	f = 150 + 35 * lfo(n, 12, r, -1, 1)
	ph = sweep_phase(f)
	creak = sum(np.sin(k * ph) / k for k in range(1, 12))
	creak *= (0.6 + 0.4 * (r.random(n) > 0.6)) * np.sin(np.pi * t / t[-1])
	creak = bandpass(creak, 300, 2600)
	knock = pluck(300, 0.15, r, 1.0, 0.3, 0.08)
	return norm_peak(fade_tail(mix([(creak, 0, 0.5), (knock, 0.38, 0.9)], 0.6)), -6)


def sfx_cart_drop(r):
	n = ns(0.3)
	t = secs(n)
	thud = np.sin(sweep_phase(85 * (1 + 0.5 * np.exp(-t / 0.02)))) * env_perc(n, 0.002, 0.1)
	dust = lowpass(r.standard_normal(n), 800) * env_perc(n, 0.001, 0.04)
	knock = pluck(240, 0.2, r, 1.0, 0.3, 0.1)
	rattle = pluck(520, 0.15, r, 1.0, 0.5, 0.06)
	return norm_peak(fade_tail(mix([(thud, 0, 1.0), (dust, 0, 0.4), (knock, 0.015, 0.6), (rattle, 0.07, 0.3)], 0.4)), -5)


def sfx_step(r, kind):
	if kind == "sand":
		n = ns(0.13)
		x = lowpass(r.standard_normal(n), 1100) * env_perc(n, 0.012, 0.035)
		return norm_peak(fade_tail(x), -16)
	if kind == "road":
		n = ns(0.08)
		t = secs(n)
		x = bandpass(r.standard_normal(n), 900, 5000) * env_perc(n, 0.001, 0.012) + 0.6 * np.sin(2 * np.pi * 110 * t) * env_perc(n, 0.001, 0.02)
		return norm_peak(fade_tail(x), -15)
	if kind == "grass":
		n = ns(0.14)
		grains = (r.random(n) > 0.92) * r.standard_normal(n)
		x = highpass(grains + 0.2 * r.standard_normal(n), 2200) * env_perc(n, 0.01, 0.045)
		return norm_peak(fade_tail(x), -17)
	n = ns(0.12)
	t = secs(n)
	x = (np.sin(2 * np.pi * 180 * t) * env_perc(n, 0.001, 0.045) + 0.5 * np.sin(2 * np.pi * 410 * t) * env_perc(n, 0.001, 0.02)
		+ 0.3 * bandpass(r.standard_normal(n), 500, 2000) * env_perc(n, 0.0005, 0.01))
	return norm_peak(fade_tail(x), -14)


def sfx_minigame_win(r):
	parts = [(tamborim(r), 0.09 * i, 0.6) for i in (0, 1, 3, 4, 5)]
	parts += [(agogo(True), 0.0, 0.4), (agogo(False), 0.27, 0.4)]
	for i, m in enumerate((72, 76, 79)):
		parts.append((brass(mtof(m), 0.12), 0.45 + 0.1 * i, 0.5))
	parts.append((brass(mtof(84), 0.55), 0.75, 0.6))
	parts.append((surdo(r, 55, True), 0.75, 0.8))
	return norm_peak(fade_tail(room(mix(parts, 1.5), 1.0, 0.18), 0.1), -2)


def sfx_minigame_lose(r):
	parts = []
	for i, m in enumerate((67, 66, 65)):
		parts.append((brass(mtof(m), 0.2) * 0.8, 0.24 * i, 0.5))
	n = ns(0.6)
	t = secs(n)
	f = mtof(64) * (1 + 0.012 * np.sin(2 * np.pi * 6 * t))
	ph = sweep_phase(f)
	last = sum(np.sin(k * ph) / k for k in range(1, 6)) * np.clip(t / 0.02, 0, 1) * np.clip((0.6 - t) / 0.15, 0, 1) * 0.3
	parts.append((last, 0.72, 0.6))
	return norm_peak(fade_tail(room(mix(parts, 1.45))), -4)


def sfx_whistle(r):
	n = ns(0.55)
	t = secs(n)
	roll = np.sin(2 * np.pi * 34 * t)
	ph = sweep_phase(2900 + 140 * roll)
	y = (np.sin(ph) + 0.15 * np.sin(2 * ph)) * (0.7 + 0.3 * roll)
	y += 0.15 * bandpass(r.standard_normal(n), 2000, 5000)
	y *= np.clip(t / 0.02, 0, 1) * np.clip((0.55 - t) / 0.06, 0, 1)
	return norm_peak(fade_tail(y), -5)


def sfx_basket_swish(r):
	n = ns(0.4)
	t = secs(n)
	parts = []
	for k, (lo, hi) in enumerate(((5000, 10000), (3000, 6000), (1500, 3500))):
		env = np.exp(-((t - 0.08 - 0.06 * k) / 0.06) ** 2)
		parts.append(bandpass(r.standard_normal(n), lo, hi) * env)
	return norm_peak(fade_tail(sum(parts)), -5)


def sfx_paddle(r):
	n = ns(0.45)
	t = secs(n)
	splash = lowpass(r.standard_normal(n), 3000) * env_perc(n, 0.015, 0.1)
	parts = [(splash, 0, 0.8)]
	for _ in range(6):
		m = ns(0.03)
		bt = secs(m)
		bub = np.sin(sweep_phase(r.uniform(400, 800) * (1 + 1.5 * bt / bt[-1]))) * np.sin(np.pi * bt / bt[-1])
		parts.append((bub, r.uniform(0.05, 0.3), 0.3))
	return norm_peak(fade_tail(mix(parts, 0.45)), -5)


def sfx_carnaval_drum(r):
	parts = [(surdo(r, 50, True), 0, 1.0), (surdo(r, 64, True), 0.43, 0.8)]
	t = 0.0
	while t < 0.85:
		parts.append((caixa(r, 0.3 + 0.7 * t / 0.85, 0.08, 220), t, 0.5))
		t += 0.053
	parts += [(tamborim(r), 0.0, 0.5), (tamborim(r), 0.21, 0.5), (tamborim(r), 0.32, 0.5)]
	parts.append((surdo(r, 50, True), 0.86, 1.2))
	return norm_peak(fade_tail(room(mix(parts, 1.8), 1.2, 0.2), 0.2), -2)


def sfx_ui_click(r):
	n = ns(0.05)
	t = secs(n)
	x = np.sin(2 * np.pi * 950 * t) * env_perc(n, 0.0008, 0.01) + 0.4 * np.sin(2 * np.pi * 2100 * t) * env_perc(n, 0.0005, 0.004)
	return norm_peak(fade_tail(x), -11)


def sfx_chase_escaped(r):
	parts = [(agogo(True), 0.0, 0.6), (agogo(False), 0.12, 0.6), (agogo(True), 0.24, 0.6)]
	parts += [(tamborim(r), 0.0, 0.5), (tamborim(r), 0.18, 0.5)]
	parts += [(brass(mtof(74), 0.1), 0.36, 0.5), (brass(mtof(79), 0.4), 0.48, 0.55)]
	return norm_peak(fade_tail(room(mix(parts, 1.1)), 0.1), -3)


# ───────────────────────────── catalogue ─────────────────────────────

SAMBA_PROG = ["Am7", "Am7", "D9", "D9", "Gmaj7", "Cmaj7", "Bm7b5", "E7b9"]
BOSSA_PROG = ["Cmaj9", "Cmaj9", "Am9", "Am9", "Dm9", "G13", "Em7", "A7b9",
	"Dm9", "Dm9", "G13", "G13", "Cmaj9", "A7b9", "Dm9", "G7b9"]

MUSIC = {
	"beach": lambda: render_samba(SAMBA_PROG, 0, 100, "flute", 11),
	"botafogo": lambda: render_samba(["Dmaj7", "Bm7", "Em9", "A13"], 0, 106, "epiano", 12, MAJOR, 2),
	"ipanema": lambda: render_bossa(BOSSA_PROG, 0, 68, "flute", 21),
	"sunset": lambda: render_bossa(BOSSA_PROG, -3, 60, "epiano", 22),
	"airport": lambda: render_bossa(BOSSA_PROG, 5, 64, "vibes", 23, mel_start=8),
	"carnaval": lambda: render_batucada(["G", "G", "E7", "Am", "D7", "D7", "G", "D7"], 0, 140, 31),
	"torcida": lambda: render_batucada(["G"], 0, 126, 32, bars=16, cavaco=False, melody=None, crowd=1.0),
	"favela": lambda: render_forro(["G", "G", "F", "G", "C", "C", "D7", "G"], 0, 92, 41),
	"barra": lambda: render_funk(["Am9", "Fmaj9", "Dm9", "E7#5"], 0, 128, 51),
	"corcovado": lambda: render_mystic(61),
	"aterro": lambda: render_mpb(["Gmaj7", "Em7", "Am7", "D9", "Bm7", "E7", "Am7", "D7"], 0, 84, "flute", 71),
	"niteroi": lambda: render_mpb(["Emaj9", "G#m7", "C#m9", "Amaj7", "F#m9", "B13", "Emaj9", "B7"], 0, 70, "epiano", 72, MAJOR, 4),
}

AMBIENT = {
	"waves": lambda: amb_waves(101),
	"ambient_city": lambda: amb_city(102),
	"ambient_park": lambda: amb_park(103),
	"ambient_forest": lambda: amb_park(104, forest=True),
	"ambient_favela": lambda: amb_favela(105),
	"ambient_wind_high": lambda: amb_wind_high(106),
	"ambient_stadium": lambda: amb_stadium(107),
	"ambient_airport": lambda: amb_airport(108),
	"ambient_carnaval_distant": lambda: amb_carnaval_distant(109),
}

SFX = {
	"coin": sfx_coin, "dialogue": sfx_dialogue, "prompt_chime": sfx_prompt_chime,
	"quest_accepted": sfx_quest_accepted, "quest_complete": sfx_quest_complete,
	"quest_failed": sfx_quest_failed, "act_stinger": sfx_act_stinger,
	"item_pickup": sfx_item_pickup, "customer_cling": sfx_customer_cling,
	"debt_paid": sfx_debt_paid, "cart_lift": sfx_cart_lift, "cart_drop": sfx_cart_drop,
	"step_sand": lambda r: sfx_step(r, "sand"), "step_road": lambda r: sfx_step(r, "road"),
	"step_grass": lambda r: sfx_step(r, "grass"), "step_wood": lambda r: sfx_step(r, "wood"),
	"minigame_win": sfx_minigame_win, "minigame_lose": sfx_minigame_lose,
	"whistle": sfx_whistle, "basket_swish": sfx_basket_swish, "paddle": sfx_paddle,
	"carnaval_drum": sfx_carnaval_drum, "ui_click": sfx_ui_click,
	"chase_escaped": sfx_chase_escaped,
}


def write(path, data):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	if not np.all(np.isfinite(data)):
		raise ValueError(f"{path} : échantillons non finis")
	data = np.clip(data, -1, 1).astype(np.float32)
	sf.write(path, data, SR, format="OGG", subtype="VORBIS")
	print(f"  {os.path.relpath(path, ROOT)}  {len(data) / SR:5.1f} s  {os.path.getsize(path) // 1024} Ko")


def main(only):
	for name, fn in SFX.items():
		if not only or name in only:
			write(os.path.join(SFX_DIR, name + ".ogg"), fn(np.random.default_rng(sum(map(ord, name)))))
	for name, fn in AMBIENT.items():
		if not only or name in only:
			write(os.path.join(SFX_DIR, name + ".ogg"), fn())
	for name, fn in MUSIC.items():
		if not only or name in only:
			write(os.path.join(MUS_DIR, name + ".ogg"), fn())


if __name__ == "__main__":
	main(set(sys.argv[1:]))

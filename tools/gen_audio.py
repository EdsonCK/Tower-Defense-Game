#!/usr/bin/env python3
"""Synthesizes every sound effect and music loop used by the game into audio/*.wav.

All audio is generated from code (no samples or downloaded assets), so it can be
regenerated or tweaked at any time:

    python3 tools/gen_audio.py

Requires numpy. Output: 22.05 kHz, 16-bit mono WAV. Music loops are rendered with
wrap-around so the end flows seamlessly into the start.
"""
import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
rng = np.random.default_rng(1234)


# --- primitives ------------------------------------------------------------------------------

def t_axis(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(n, attack=0.005, release=None, curve=4.0):
    """Fast attack, exponential decay envelope over n samples."""
    t = np.arange(n) / RATE
    length = n / RATE
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-curve * t / length)
    e = a * d
    if release:
        r = int(RATE * release)
        e[-r:] *= np.linspace(1, 0, r)
    return e


def sweep(f0, f1, seconds, shape="sine", curve=1.0):
    """Oscillator whose frequency glides from f0 to f1."""
    n = int(RATE * seconds)
    k = np.linspace(0, 1, n) ** curve
    freq = f0 + (f1 - f0) * k
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return osc(phase, shape)


def osc(phase, shape):
    if shape == "sine":
        return np.sin(phase)
    if shape == "square":
        return np.sign(np.sin(phase)) * 0.6
    if shape == "saw":
        return (((phase / (2 * np.pi)) % 1.0) * 2 - 1) * 0.7
    if shape == "tri":
        return (2 * np.abs(2 * ((phase / (2 * np.pi)) % 1.0) - 1) - 1)
    raise ValueError(shape)


def tone(freq, seconds, shape="sine", vibrato=0.0):
    t = t_axis(seconds)
    phase = 2 * np.pi * freq * t
    if vibrato:
        phase += vibrato * np.sin(2 * np.pi * 5.5 * t)
    return osc(phase, shape)


def noise(seconds):
    return rng.uniform(-1, 1, int(RATE * seconds))


def lowpass(x, cutoff):
    """One-pole low-pass filter."""
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(x, offset_s, total_s):
    out = np.zeros(int(RATE * total_s))
    i = int(RATE * offset_s)
    seg = x[: max(0, len(out) - i)]
    out[i: i + len(seg)] += seg
    return out


def note_hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def save(name, x, peak=0.9):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print(f"{path}  {len(x) / RATE:.2f}s")


# --- sound effects ---------------------------------------------------------------------------

def sfx():
    # Basic tower: a short bright "pew".
    s = sweep(1400, 520, 0.09, "square", 0.6) * env(int(RATE * 0.09), 0.002, curve=5)
    save("shot_basic", lowpass(s, 5000), 0.55)

    # Tesla: crackling electric zap.
    n = int(RATE * 0.2)
    buzz = tone(95, 0.2, "saw") * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 37 * t_axis(0.2))))
    crackle = highpass(noise(0.2), 2500) * (rng.random(n) < 0.35)
    zap = sweep(2400, 900, 0.2, "square", 0.4) * 0.35
    save("shot_tesla", (buzz * 0.5 + crackle * 0.9 + zap) * env(n, 0.002, curve=4.5), 0.6)

    # Cannon: deep thump with a noisy blast.
    n = int(RATE * 0.42)
    thump = sweep(150, 40, 0.42, "sine", 0.5) * env(n, 0.003, curve=5)
    blast = lowpass(noise(0.42), 900) * env(n, 0.001, curve=9) * 1.4
    save("shot_cannon", thump + blast, 0.8)

    # Enemy pop.
    n = int(RATE * 0.13)
    pop = sweep(700, 180, 0.13, "tri", 0.5) * env(n, 0.002, curve=6)
    puff = lowpass(noise(0.13), 2500) * env(n, 0.001, curve=12) * 0.6
    save("enemy_die", pop + puff, 0.5)

    # Boss death: long rumbling explosion with a falling tone.
    n = int(RATE * 1.6)
    rumble = lowpass(noise(1.6), 400) * env(n, 0.005, curve=3) * 2.0
    crack = highpass(noise(1.6), 1500) * env(n, 0.001, curve=14)
    fall = sweep(220, 35, 1.6, "saw", 0.7) * env(n, 0.01, curve=3) * 0.5
    save("boss_die", rumble + crack + lowpass(fall, 1200), 0.9)

    # Enemy reached the gate: low double warning buzz.
    part = lowpass(tone(110, 0.14, "saw") + tone(116, 0.14, "saw"), 1500) * env(int(RATE * 0.14), 0.005, curve=2)
    save("escape", mix(at(part, 0.0, 0.34), at(part, 0.18, 0.34)), 0.7)

    # Wave start: two-note horn.
    def horn(midi, length):
        x = mix(tone(note_hz(midi), length, "saw", 0.6), tone(note_hz(midi) * 1.005, length, "saw") * 0.6)
        return lowpass(x, 1800) * env(int(RATE * length), 0.03, curve=1.5)
    total = 0.75
    save("wave_start", mix(at(horn(57, 0.25), 0, total), at(horn(64, 0.5), 0.22, total)), 0.6)

    # Wave cleared: rising chime arpeggio.
    total = 1.0
    parts = []
    for i, m in enumerate([72, 76, 79, 84]):
        bell = (tone(note_hz(m), 0.6) + tone(note_hz(m) * 2.01, 0.6) * 0.3) * env(int(RATE * 0.6), 0.003, curve=5)
        parts.append(at(bell, i * 0.09, total))
    save("wave_clear", mix(*parts), 0.6)

    # Boss arrives: ominous gong and drone.
    n = int(RATE * 2.0)
    gong = sum(tone(55 * k, 2.0) * (0.8 / k) for k in [1, 2.4, 3.9, 5.3]) * env(n, 0.01, curve=2.5)
    drone = lowpass(tone(41.2, 2.0, "saw"), 300) * np.sin(np.linspace(0, np.pi, n)) * 0.8
    save("boss_spawn", gong + drone, 0.85)

    # Tower built: wooden thunk + click.
    n = int(RATE * 0.16)
    thunk = sweep(260, 90, 0.16, "sine", 0.4) * env(n, 0.002, curve=7)
    click = highpass(noise(0.16), 3000) * env(n, 0.0005, curve=40) * 0.6
    save("build", thunk + click, 0.6)

    # Upgrade: quick rising sparkle.
    total = 0.45
    parts = []
    for i, m in enumerate([76, 81, 88]):
        parts.append(at(tone(note_hz(m), 0.25, "tri") * env(int(RATE * 0.25), 0.002, curve=5), i * 0.07, total))
    parts.append(sweep(600, 1800, total, "sine", 1.5) * env(int(RATE * total), 0.01, curve=3) * 0.3)
    save("upgrade", mix(*parts), 0.55)

    # Sell: coin jingle.
    total = 0.4
    coin = lambda m: (tone(note_hz(m), 0.25, "square") * 0.5 + tone(note_hz(m) * 2, 0.25) * 0.3) * env(int(RATE * 0.25), 0.001, curve=6)
    save("sell", mix(at(coin(88), 0, total), at(coin(93), 0.08, total)), 0.45)

    # UI click.
    n = int(RATE * 0.035)
    save("click", tone(1800, 0.035, "sine") * env(n, 0.0005, curve=10), 0.3)

    # Error / not allowed.
    part = lowpass(tone(150, 0.1, "square"), 1200) * env(int(RATE * 0.1), 0.003, curve=2)
    save("error", mix(at(part, 0, 0.24), at(part, 0.12, 0.24)), 0.45)

    # Skill unlocked: shimmering major chord.
    total = 1.1
    parts = []
    for i, m in enumerate([67, 71, 74, 79, 83]):
        parts.append(at(tone(note_hz(m), 0.9, "sine", 0.4) * env(int(RATE * 0.9), 0.01, curve=3), i * 0.05, total))
    save("unlock", mix(*parts), 0.6)

    # Defeat: slow falling minor line.
    total = 2.2
    parts = []
    for i, m in enumerate([64, 62, 60, 57]):
        x = lowpass(tone(note_hz(m), 0.8, "saw", 0.5), 1400) * env(int(RATE * 0.8), 0.02, curve=2)
        parts.append(at(x, i * 0.42, total))
    save("defeat", mix(*parts), 0.6)


# --- music -----------------------------------------------------------------------------------

def render_loop(seconds, events):
    """events: list of (start_s, samples). Samples past the end wrap to the start."""
    n = int(RATE * seconds)
    out = np.zeros(n)
    for start, x in events:
        i = int(round(start * RATE)) % n
        for j in range(0, len(x), n):
            chunk = x[j: j + n]
            first = min(len(chunk), n - i)
            out[i: i + first] += chunk[:first]
            if first < len(chunk):
                out[: len(chunk) - first] += chunk[first:]
    return out


def pad_note(midi, length):
    f = note_hz(midi)
    x = tone(f, length, "saw") * 0.5 + tone(f * 1.003, length, "saw") * 0.5 + tone(f / 2, length, "tri") * 0.4
    n = len(x)
    e = np.minimum(1, np.arange(n) / (RATE * 0.6)) * np.minimum(1, (n - np.arange(n)) / (RATE * 0.8))
    return lowpass(x, 900) * e


def pluck(midi, length=0.35, bright=2600):
    f = note_hz(midi)
    x = tone(f, length, "square") * 0.5 + tone(f * 2, length, "tri") * 0.3
    return lowpass(x, bright) * env(len(x), 0.002, curve=6)


def bass_note(midi, length):
    x = tone(note_hz(midi), length, "tri") + tone(note_hz(midi) * 2, length, "sine") * 0.2
    return x * env(len(x), 0.01, curve=1.6)


def kick():
    return sweep(120, 40, 0.25, "sine", 0.4) * env(int(RATE * 0.25), 0.001, curve=7)


def hat(length=0.05):
    return highpass(noise(length), 6000) * env(int(RATE * length), 0.0005, curve=10)


def snare():
    return (lowpass(noise(0.18), 3500) * 0.8 + tone(190, 0.18, "tri") * 0.4) * env(int(RATE * 0.18), 0.001, curve=9)


def music_main():
    # 96 BPM, 12 bars of 4/4 in A minor, pads + a gentle arpeggio; drums enter at bar 5.
    beat = 60 / 96
    bar = beat * 4
    bars = 12
    total = bar * bars
    chords = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62],
              [57, 60, 64], [53, 57, 60], [50, 53, 57], [52, 56, 59],
              [57, 60, 64], [62, 65, 69], [53, 57, 60], [52, 56, 59]]
    pad, arp, bass, drums = [], [], [], []
    for b, chord in enumerate(chords):
        t0 = b * bar
        for m in chord:
            pad.append((t0, pad_note(m, bar + 0.4)))
        pattern = [0, 1, 2, 1, 0, 2, 1, 2]
        for k, idx in enumerate(pattern):
            octave = 24 if k % 4 != 3 else 12
            arp.append((t0 + k * beat / 2, pluck(chord[idx] + octave, 0.32)))
        bass.append((t0, bass_note(chord[0] - 12, beat * 1.5)))
        bass.append((t0 + beat * 2, bass_note(chord[0] - 12, beat * 1.0)))
        bass.append((t0 + beat * 3, bass_note(chord[0] - 5, beat * 0.9)))
        if b >= 4:  # soft percussion enters after the intro
            for k in range(4):
                drums.append((t0 + k * beat, kick() * (0.8 if k % 2 == 0 else 0.0)))
                drums.append((t0 + k * beat + beat / 2, hat() * 0.5))
    x = (render_loop(total, pad) * 0.28 + render_loop(total, arp) * 0.22
         + render_loop(total, bass) * 0.35 + render_loop(total, drums) * 0.3)
    save("music_main", x, 0.55)


def music_boss():
    # 132 BPM, 8 bars in D minor (phrygian flavor), driving bass and drums.
    beat = 60 / 132
    bar = beat * 4
    bars = 8
    total = bar * bars
    roots = [38, 38, 39, 38, 38, 38, 41, 39]
    bass, lead, drums, pad = [], [], [], []
    for b, root in enumerate(roots):
        t0 = b * bar
        for k in range(8):
            m = root + (12 if k in (3, 6) else 0)
            x = lowpass(tone(note_hz(m), beat / 2, "saw"), 700) * env(int(RATE * beat / 2), 0.003, curve=3)
            bass.append((t0 + k * beat / 2, x))
        pad.append((t0, pad_note(root + 24, bar + 0.3)))
        pad.append((t0, pad_note(root + 27, bar + 0.3)))
        for k in range(4):
            drums.append((t0 + k * beat, kick()))
            if k % 2 == 1:
                drums.append((t0 + k * beat, snare()))
            drums.append((t0 + k * beat + beat / 2, hat() * 0.6))
        if b % 2 == 1:
            for k, m in enumerate([62, 63, 65, 63, 62, 58, 57, 58]):
                lead.append((t0 + k * beat / 2, pluck(m + 12, 0.22, 3200)))
    x = (render_loop(total, bass) * 0.4 + render_loop(total, drums) * 0.45
         + render_loop(total, lead) * 0.2 + render_loop(total, pad) * 0.18)
    save("music_boss", x, 0.6)


if __name__ == "__main__":
    sfx()
    music_main()
    music_boss()

"""Synthesises Legio's ambient loops and a few one-shot sounds as WAV files.

Kenney's CC0 packs cover impacts and UI, but not nature ambience, so these
are generated: wind, birdsong, crickets, a town murmur, the barrow's
drips and drone, and the coast's surf and gulls. Each loop crossfades its tail into its head so it repeats
without a seam. Deterministic (fixed seeds), stdlib only.

    uv run tools/synth_ambience.py [output_dir]
"""

from __future__ import annotations

import math
import random
import struct
import sys
import wave
from pathlib import Path

RATE = 22050
LOOP_SECONDS = 30.0
FADE_SECONDS = 2.0
DEFAULT_OUT = (
    Path(__file__).resolve().parent.parent / "game" / "assets" / "audio" / "synth"
)


def silence(seconds: float) -> list[float]:
    return [0.0] * int(seconds * RATE)


def noise(n: int, rng: random.Random) -> list[float]:
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def lowpass(signal: list[float], cutoff: float) -> list[float]:
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for x in signal:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(signal: list[float], cutoff: float) -> list[float]:
    low = lowpass(signal, cutoff)
    return [x - l for x, l in zip(signal, low)]


def bandpass(signal: list[float], low: float, high: float) -> list[float]:
    return highpass(lowpass(signal, high), low)


def normalise(signal: list[float], peak: float) -> list[float]:
    top = max(abs(x) for x in signal) or 1.0
    return [x * peak / top for x in signal]


def mix_into(
    target: list[float], sound: list[float], at: int, gain: float = 1.0
) -> None:
    for i, x in enumerate(sound):
        j = at + i
        if 0 <= j < len(target):
            target[j] += x * gain


def slow_wobble(n: int, rng: random.Random, period: float, depth: float) -> list[float]:
    """A smooth random gain curve between 1 - depth and 1."""
    phase = rng.uniform(0, math.tau)
    phase2 = rng.uniform(0, math.tau)
    out = []
    for i in range(n):
        t = i / RATE
        w = (
            0.5
            + 0.3 * math.sin(math.tau * t / period + phase)
            + 0.2 * math.sin(math.tau * t / (period * 0.37) + phase2)
        )
        out.append(1.0 - depth * w)
    return out


def envelope(n: int, attack: float, release: float) -> list[float]:
    a, r = max(1, int(attack * RATE)), max(1, int(release * RATE))
    return [min(1.0, i / a) * min(1.0, (n - i) / r) for i in range(n)]


def wind(n: int, rng: random.Random, cutoff: float, depth: float) -> list[float]:
    base = lowpass(lowpass(noise(n, rng), cutoff), cutoff)
    gain = slow_wobble(n, rng, 9.0, depth)
    return normalise([x * g for x, g in zip(base, gain)], 1.0)


def chirp(rng: random.Random, f0: float, f1: float, seconds: float) -> list[float]:
    n = int(seconds * RATE)
    env = envelope(n, 0.008, seconds * 0.6)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * math.sin(t * math.pi * 0.5)
        phase += math.tau * f / RATE
        out.append(math.sin(phase) * env[i])
    return out


def birdsong(n: int, rng: random.Random, calls: int) -> list[float]:
    out = [0.0] * n
    species = [(2800, 4200), (3600, 2600), (2200, 3000)]
    for _ in range(calls):
        f0, f1 = rng.choice(species)
        at = rng.randrange(0, n - RATE)
        notes = rng.randint(2, 5)
        gain = rng.uniform(0.25, 0.6)
        for k in range(notes):
            jitter = rng.uniform(0.9, 1.1)
            mix_into(
                out,
                chirp(rng, f0 * jitter, f1 * jitter, rng.uniform(0.06, 0.14)),
                at + int(k * 0.16 * RATE),
                gain,
            )
    return out


def crickets(n: int, rng: random.Random) -> list[float]:
    out = [0.0] * n
    for carrier, rate, gain in [(4500, 2.1, 0.5), (5200, 1.7, 0.3)]:
        pulse = int(RATE / 30)
        t = rng.uniform(0, 1.0)
        while t * RATE < n - RATE:
            for k in range(3):
                start = int(t * RATE) + k * pulse
                tone = [
                    math.sin(math.tau * carrier * i / RATE) for i in range(pulse // 2)
                ]
                env = envelope(len(tone), 0.003, 0.01)
                mix_into(out, [x * e for x, e in zip(tone, env)], start, gain)
            t += 1.0 / rate * rng.uniform(0.95, 1.05)
    return out


def owl(rng: random.Random) -> list[float]:
    out: list[float] = []
    for seconds, f in [(0.35, 420), (0.15, 0), (0.6, 390)]:
        n = int(seconds * RATE)
        if f == 0:
            out += [0.0] * n
            continue
        env = envelope(n, 0.06, 0.2)
        out += [math.sin(math.tau * f * i / RATE) * env[i] for i in range(n)]
    return lowpass(out, 900)


def murmur(n: int, rng: random.Random) -> list[float]:
    voices = bandpass(noise(n, rng), 250, 1100)
    syllables = slow_wobble(n, rng, 0.45, 0.8)
    swell = slow_wobble(n, rng, 7.0, 0.5)
    return normalise([v * s * w for v, s, w in zip(voices, syllables, swell)], 1.0)


def clink(rng: random.Random) -> list[float]:
    n = int(0.5 * RATE)
    f = rng.uniform(1800, 2300)
    return [
        (
            math.sin(math.tau * f * i / RATE)
            + 0.4 * math.sin(math.tau * f * 2.7 * i / RATE)
        )
        * math.exp(-i / (0.07 * RATE))
        for i in range(n)
    ]


def drip(rng: random.Random) -> list[float]:
    n = int(0.12 * RATE)
    f0 = rng.uniform(700, 1000)
    out, phase = [], 0.0
    for i in range(n):
        f = f0 * (1.0 + 1.5 * i / n)
        phase += math.tau * f / RATE
        out.append(math.sin(phase) * math.exp(-i / (0.025 * RATE)))
    return out


def echo(signal: list[float], delays: list[tuple[float, float]]) -> list[float]:
    out = list(signal)
    for seconds, gain in delays:
        mix_into(out, signal, int(seconds * RATE), gain)
    return out


def drone(n: int, rng: random.Random) -> list[float]:
    out = []
    for i in range(n):
        t = i / RATE
        out.append(
            math.sin(math.tau * 55 * t)
            + 0.6 * math.sin(math.tau * 55.4 * t)
            + 0.35 * math.sin(math.tau * 82.5 * t + 1.0)
        )
    rumble = lowpass(lowpass(noise(n, rng), 120), 120)
    rumble = normalise(rumble, 1.0)
    return normalise([d * 0.6 + r * 0.5 for d, r in zip(out, rumble)], 1.0)


def scatter(
    n: int, rng: random.Random, make, count: int, gain: tuple[float, float]
) -> list[float]:
    out = [0.0] * n
    for _ in range(count):
        mix_into(out, make(rng), rng.randrange(0, n - RATE), rng.uniform(*gain))
    return out


def layer(*parts: tuple[list[float], float]) -> list[float]:
    n = len(parts[0][0])
    out = [0.0] * n
    for signal, gain in parts:
        for i in range(n):
            out[i] += signal[i] * gain
    return out


def make_loop(build, seed: int) -> list[float]:
    """Builds LOOP + FADE seconds, then folds the tail over the head."""
    rng = random.Random(seed)
    loop, fade = int(LOOP_SECONDS * RATE), int(FADE_SECONDS * RATE)
    raw = build(loop + fade, rng)
    out = raw[:loop]
    for i in range(fade):
        t = i / fade
        out[i] = raw[i] * math.sin(t * math.pi / 2) + raw[loop + i] * math.cos(
            t * math.pi / 2
        )
    return out


def day(n, rng):
    return layer(
        (wind(n, rng, 500, 0.7), 0.35),
        (highpass(wind(n, rng, 3000, 0.9), 1500), 0.08),
        (birdsong(n, rng, 16), 0.22),
    )


def night(n, rng):
    owls = scatter(n, rng, owl, 2, (0.3, 0.45))
    return layer((wind(n, rng, 350, 0.6), 0.25), (crickets(n, rng), 0.12), (owls, 1.0))


def town(n, rng):
    clinks = scatter(n, rng, clink, 9, (0.05, 0.12))
    return layer(
        (wind(n, rng, 450, 0.6), 0.2),
        (murmur(n, rng), 0.22),
        (clinks, 1.0),
        (birdsong(n, rng, 5), 0.12),
    )


def barrow(n, rng):
    drips = echo(
        scatter(n, rng, drip, 22, (0.15, 0.4)),
        [(0.11, 0.45), (0.23, 0.25), (0.41, 0.12)],
    )
    return layer((drone(n, rng), 0.3), (drips, 0.6), (wind(n, rng, 200, 0.8), 0.15))


def gull(rng: random.Random) -> list[float]:
    """A falling two-part cry with a rough edge."""
    out: list[float] = []
    for _ in range(rng.randint(2, 3)):
        f0 = rng.uniform(1700, 2100)
        part = chirp(rng, f0, f0 * 0.62, rng.uniform(0.18, 0.28))
        out += [x * (1.0 + 0.3 * math.sin(i * 0.9)) for i, x in enumerate(part)]
        out += [0.0] * int(0.06 * RATE)
    return out


def surf(n: int, rng: random.Random) -> list[float]:
    """Waves: slow swells of deep noise, with a hiss as each one breaks."""
    body = normalise(lowpass(lowpass(noise(n, rng), 260), 260), 1.0)
    hiss = normalise(highpass(noise(n, rng), 1800), 1.0)
    period = 7.0
    phase = rng.uniform(0, math.tau)
    out = []
    for i in range(n):
        t = i / RATE
        swell = 0.5 + 0.5 * math.sin(math.tau * t / period + phase)
        crest = max(0.0, math.sin(math.tau * t / period + phase - 0.6)) ** 6
        out.append(body[i] * (0.35 + 0.65 * swell) + hiss[i] * 0.5 * crest)
    return normalise(out, 1.0)


def coast(n, rng):
    gulls = scatter(n, rng, gull, 6, (0.12, 0.25))
    return layer((surf(n, rng), 0.55), (wind(n, rng, 600, 0.5), 0.15), (gulls, 1.0))


def howl(rng: random.Random) -> list[float]:
    """A distant wolf: a slow rise and fall with a little vibrato."""
    seconds = rng.uniform(2.2, 3.0)
    n = int(seconds * RATE)
    env = envelope(n, seconds * 0.25, seconds * 0.4)
    base = rng.uniform(360, 420)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        f = base * (1.0 + 0.45 * math.sin(t * math.pi) ** 0.7 - 0.12 * t)
        f *= 1.0 + 0.012 * math.sin(i / RATE * math.tau * 5.5)
        phase += math.tau * f / RATE
        out.append((math.sin(phase) + 0.25 * math.sin(phase * 2.0)) * env[i])
    return lowpass(out, 1400)


def caw(rng: random.Random) -> list[float]:
    """A raven: two or three harsh, buzzing croaks."""
    out: list[float] = []
    for _ in range(rng.randint(2, 3)):
        seconds = rng.uniform(0.16, 0.24)
        n = int(seconds * RATE)
        env = envelope(n, 0.01, seconds * 0.5)
        rough = bandpass(noise(n, rng), 500, 1800)
        f = rng.uniform(520, 640)
        out += [(math.sin(math.tau * f * i / RATE) * 0.6 + rough[i] * 3.0) * env[i] for i in range(n)]
        out += [0.0] * int(rng.uniform(0.12, 0.2) * RATE)
    return out


def frontier(n, rng):
    howls = echo(scatter(n, rng, howl, 2, (0.12, 0.2)), [(0.31, 0.3), (0.67, 0.15)])
    caws = scatter(n, rng, caw, 3, (0.06, 0.12))
    return layer(
        (wind(n, rng, 300, 0.85), 0.42),
        (highpass(wind(n, rng, 2200, 0.9), 1200), 0.1),
        (howls, 1.0),
        (caws, 1.0),
    )


def swish(seconds: float, low: float, high: float, seed: int) -> list[float]:
    rng = random.Random(seed)
    n = int(seconds * RATE)
    sweep = []
    src = noise(n, rng)
    y_lo = y_hi = 0.0
    for i, x in enumerate(src):
        t = i / n
        cutoff = low + (high - low) * math.sin(t * math.pi)
        a = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
        y_lo += a * (x - y_lo)
        y_hi += 0.02 * (y_lo - y_hi)
        sweep.append((y_lo - y_hi) * math.sin(t * math.pi) ** 2)
    return sweep


def write_wav(path: Path, signal: list[float], peak: float = 0.8) -> None:
    signal = normalise(signal, peak)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(
            b"".join(
                struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32767)) for x in signal
            )
        )


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUT
    loops = {
        "ambient_day": (day, 1),
        "ambient_night": (night, 2),
        "ambient_town": (town, 3),
        "ambient_barrow": (barrow, 4),
        "ambient_coast": (coast, 5),
        "ambient_frontier": (frontier, 6),
    }
    for name, (build, seed) in loops.items():
        write_wav(out / f"{name}.wav", make_loop(build, seed), 0.7)
        print(f"wrote {name}.wav")
    write_wav(out / "swish.wav", swish(0.28, 600, 4000, 10), 0.8)
    write_wav(out / "sling.wav", swish(0.4, 300, 1800, 11), 0.8)
    print("wrote swish.wav, sling.wav")


if __name__ == "__main__":
    main()

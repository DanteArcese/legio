"""Synthesises the instrument samples Legio's music is played with.

The music is composed live in the game (scripts/audio/music_composer.gd),
so only single notes are needed: a plucked lyre, a reed aulos, two frame
drums, and a low drone. Each pitched sample is a C (middle C for the lyre
and aulos, C3 for the drone), and the game repitches it. Deterministic
(fixed seeds), stdlib only, like synth_ambience.py, whose helpers it uses.

    uv run tools/synth_instruments.py [output_dir]
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from synth_ambience import RATE, envelope, lowpass, noise, write_wav

DEFAULT_OUT = (
    Path(__file__).resolve().parent.parent / "game" / "assets" / "audio" / "music"
)
C4 = 261.63
C3 = C4 / 2


def lyre(freq: float = C4, seconds: float = 3.0, seed: int = 1) -> list[float]:
    """A plucked string (Karplus-Strong), softened like a gut-strung lyre."""
    rng = random.Random(seed)
    size = round(RATE / freq)
    burst = lowpass(noise(size, rng), 3000)
    n = int(seconds * RATE)
    out: list[float] = []
    for i in range(n):
        if i < size:
            out.append(burst[i])
        else:
            prev = out[i - size - 1] if i > size else out[0]
            out.append(0.996 * 0.5 * (out[i - size] + prev))
    body = lowpass(out, 2400)
    env = envelope(n, 0.002, 0.4)
    return [x * e for x, e in zip(body, env)]


def aulos(freq: float = C4, seconds: float = 2.0) -> list[float]:
    """A double reed: odd harmonics stronger, a slow vibrato, a soft attack."""
    n = int(seconds * RATE)
    harmonics = [(1, 1.0), (2, 0.35), (3, 0.6), (4, 0.15), (5, 0.3), (7, 0.12)]
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        vibrato = 1.0 + 0.004 * math.sin(math.tau * 5.2 * t) * min(1.0, t / 0.4)
        phase += math.tau * freq * vibrato / RATE
        out.append(sum(g * math.sin(h * phase) for h, g in harmonics))
    out = lowpass(out, 2600)
    env = envelope(n, 0.07, 0.5)
    return [x * e for x, e in zip(out, env)]


def drum(base: float, seconds: float, seed: int) -> list[float]:
    """A frame drum (tympanum): a falling skin tone and a slap of noise."""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    out, phase = [], 0.0
    slap = lowpass(noise(n, rng), 1800)
    for i in range(n):
        t = i / RATE
        phase += math.tau * base * (1.0 + 0.6 * math.exp(-t * 30)) / RATE
        tone = math.sin(phase) * math.exp(-t * 7)
        out.append(tone + 0.5 * slap[i] * math.exp(-t * 40))
    return out


def drone(freq: float = C3, seconds: float = 8.0, fade: float = 1.5) -> list[float]:
    """Two soft reeds a fifth apart, folded into a seamless loop."""
    n, f = int(seconds * RATE), int(fade * RATE)
    total = n + f
    out = []
    for i in range(total):
        t = i / RATE
        swell = 0.8 + 0.2 * math.sin(math.tau * t / seconds)
        x = 0.0
        for mult, gain, detune in [
            (1.0, 1.0, 0.0),
            (1.5, 0.45, 0.3),
            (2.0, 0.25, -0.2),
        ]:
            p = math.tau * (freq * mult + detune) * t
            x += gain * (math.sin(p) + 0.3 * math.sin(3 * p))
        out.append(x * swell)
    out = lowpass(out, 900)
    loop = out[:n]
    for i in range(f):
        k = i / f
        loop[i] = out[i] * math.sin(k * math.pi / 2) + out[n + i] * math.cos(
            k * math.pi / 2
        )
    return loop


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUT
    write_wav(out / "lyre.wav", lyre(), 0.8)
    write_wav(out / "aulos.wav", aulos(), 0.7)
    write_wav(out / "drum_low.wav", drum(90, 0.7, 2), 0.8)
    write_wav(out / "drum_high.wav", drum(210, 0.35, 3), 0.6)
    write_wav(out / "drone.wav", drone(), 0.6)
    print("wrote lyre, aulos, drum_low, drum_high, drone")


if __name__ == "__main__":
    main()

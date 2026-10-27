"""Original arcade kart SFX: compact, buzzy engine with fast throttle response.

Uses procedural exhaust harmonics plus a little of the existing engine texture.
No samples from Mario Kart. Run with Python and NumPy.
"""

import json
import numpy as np

from build_kart_acceleration import SAMPLE_RATE, read_engine, engine_voice, write_wav


def smooth_curve(t, times, values):
    out = np.empty_like(t)
    for i in range(len(times) - 1):
        mask = (t >= times[i]) & (t <= times[i + 1])
        u = np.clip((t[mask] - times[i]) / (times[i + 1] - times[i]), 0, 1)
        u = u * u * (3 - 2 * u)
        out[mask] = values[i] + (values[i + 1] - values[i]) * u
    return out


def arcade_engine(t, revs, throttle):
    rng = np.random.default_rng(731)
    # Small correlated variations prevent a rigid musical or electronic tone.
    knots = np.arange(0, t[-1] + 0.08, 0.035)
    roughness = np.interp(t, knots, rng.normal(0, 1, len(knots)))
    revs = revs * (1 + 0.009 * roughness + 0.004 * np.sin(2 * np.pi * 11 * t))
    phase = 2 * np.pi * np.cumsum(revs) / SAMPLE_RATE
    exhaust = np.zeros_like(t)
    # A compact, raspy exhaust pulse, with chest and nasal formants rather
    # than an exposed pure oscillator. Harmonics remain below Nyquist.
    for k in range(1, 49):
        frequency = k * revs
        formant = (0.52 + 0.7 * np.exp(-((frequency - 390) / 300)**2)
                   + 0.9 * np.exp(-((frequency - 1250) / 850)**2))
        weight = formant * np.exp(-frequency / 3600) / k**0.82
        exhaust += weight * np.sin(k * phase + 0.18 * k + 0.06 * k**0.5)
    exhaust = np.tanh(exhaust * 1.15)
    exhaust *= 0.93 + 0.07 * np.sin(phase * 0.5 + 0.4)

    # Filtered exhaust turbulence follows combustion pulses and throttle load.
    noise = rng.normal(0, 1, len(t))
    frequencies = np.fft.rfftfreq(len(t), 1 / SAMPLE_RATE)
    band = frequencies**2 / (frequencies**2 + 420**2)
    band *= np.exp(-(frequencies / 3300)**4)
    noise = np.fft.irfft(np.fft.rfft(noise) * band, n=len(t))
    noise /= max(float(np.std(noise)), 1e-9)
    noise *= (0.35 + 0.65 * (0.5 + 0.5 * np.sin(phase + 0.8))**2)

    recorded = engine_voice(read_engine(), revs / 28.0, throttle)
    # Keep the engine in the foreground; mechanical whine is a quiet layer.
    mechanical = np.sin(phase * 3.07 + 0.35 * np.sin(phase))
    result = 0.68 * exhaust + 0.17 * recorded
    result += (0.045 + 0.025 * throttle) * noise + 0.025 * throttle * mechanical
    result *= 0.4 + 0.6 * throttle
    # Rounded top end: this should be a playful engine, not a harsh buzzer.
    pad = 4096
    padded = np.pad(result, pad, mode='reflect')
    frequencies = np.fft.rfftfreq(len(padded), 1 / SAMPLE_RATE)
    eq = frequencies**2 / (frequencies**2 + 55**2)
    eq *= 1 / np.sqrt(1 + (frequencies / 4200)**8)
    return np.fft.irfft(np.fft.rfft(padded) * eq, n=len(padded))[pad:-pad]


def main():
    t = np.arange(round(5.5 * SAMPLE_RATE)) / SAMPLE_RATE
    times = [0, 0.18, 0.55, 1.1, 1.9, 2.7, 3.65, 3.85, 4.4, 5.1, 5.5]
    revs = smooth_curve(t, times, [62, 65, 95, 132, 173, 185, 188, 166, 105, 62, 60])
    load = smooth_curve(t, times, [0.2, 0.35, 0.92, 1, 1, 1, 1, 0.25, 0.18, 0.14, 0.14])
    stats = [write_wav('engine_accelerate_arcade.wav', arcade_engine(t, revs, load))]
    lt = np.arange(round(4.08 * SAMPLE_RATE)) / SAMPLE_RATE
    stats.append(write_wav('engine_running_arcade_loop.wav',
                          arcade_engine(lt, np.full_like(lt, 185), np.ones_like(lt)), loop=True))
    print(json.dumps(stats, indent=2))


if __name__ == '__main__':
    main()

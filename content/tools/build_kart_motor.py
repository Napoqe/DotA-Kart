"""Original retro kart engine: acceleration, sustained revs and idle.

Uses only the project's engine_idle.wav and newly synthesized mechanical layers.
No Mario Kart sample is read or included. Python + NumPy, mono PCM16/44.1 kHz.
"""

import json
import struct
import wave

import numpy as np

from build_kart_acceleration import SAMPLE_RATE, ENGINE_DIR, read_engine, engine_voice


def bandpass(x, low, high):
    padded = np.pad(x, 4096, mode="reflect")
    f = np.fft.rfftfreq(len(padded), 1 / SAMPLE_RATE)
    eq = f**4 / (f**4 + low**4)
    eq *= 1 / np.sqrt(1 + (f / high)**8)
    return np.fft.irfft(np.fft.rfft(padded) * eq, n=len(padded))[4096:-4096]


def rms_normalize(x):
    return x / max(float(np.sqrt(np.mean(x*x))), 1e-9)


def motor(t, revs, idle=False):
    rng = np.random.default_rng(64011 if idle else 64117)
    knots = np.arange(0, t[-1] + 0.05, 0.02)
    uneven = np.interp(t, knots, rng.normal(0, 1, len(knots)))
    revs = revs * (1 + 0.003 * uneven + 0.0015 * np.sin(2*np.pi*6.7*t))
    phase = 2*np.pi*np.cumsum(revs) / SAMPLE_RATE

    # Recorded exhaust supplies the irregular, mechanical texture. Cut the
    # heavy sub-bass that made the earlier oscillator effect sound too rubbery.
    recorded = engine_voice(read_engine(), revs / 25, np.ones_like(t))
    recorded = rms_normalize(bandpass(recorded, 105 if idle else 165, 3700))

    # A smooth transmission whirr tracks RPM above the exhaust. Slightly
    # inharmonic partials avoid an exposed sawtooth/buzzer or a musical note.
    whirr = np.sin(2.02*phase + 0.48*np.sin(phase))
    whirr += 0.44*np.sin(4.035*phase + 0.26*np.sin(1.013*phase))
    whirr += 0.18*np.sin(6.09*phase + 0.15*np.sin(phase))
    whirr = rms_normalize(bandpass(whirr, 130, 3200))

    air = rms_normalize(bandpass(rng.normal(0, 1, len(t)), 650, 2800))
    air *= 0.75 + 0.25*np.sin(phase + 0.7)**2
    output = 0.76*recorded + (0.18 if idle else 0.34)*whirr + 0.025*air
    if idle:
        # Gentle irregular firing, rather than repeated throttle blips.
        output *= 0.96 + 0.025*np.sin(0.5*phase) + 0.015*uneven
    return bandpass(output, 85, 4200)


def write(name, x, loop=False):
    if loop:
        overlap = round(0.12*SAMPLE_RATE)
        blend = np.linspace(0, 1, overlap, endpoint=False)
        seam = x[-overlap:]*(1-blend) + x[:overlap]*blend
        x = np.concatenate((seam, x[overlap:-overlap]))
    else:
        x[:882] *= np.linspace(0, 1, 882)
        x[-441:] *= np.linspace(1, 0.92, 441)
    x -= x.mean()
    x *= min(0.21 / max(np.sqrt(np.mean(x*x)), 1e-9),
             0.86 / max(np.max(np.abs(x)), 1e-9))
    pcm = np.rint(x*32767).astype('<i2')
    path = ENGINE_DIR / name
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(pcm.tobytes())
    if loop:
        # Forward loop over all samples; Source 2 retains this as m_nLoopStart.
        metadata = struct.pack('<15I', 0, 0, round(1e9/SAMPLE_RATE), 60, 0,
                               0, 0, 1, 0, 0, 0, 0, len(pcm)-1, 0, 0)
        with path.open('r+b') as f:
            f.seek(0, 2)
            f.write(b'smpl' + struct.pack('<I', len(metadata)) + metadata)
            size = f.tell()
            f.seek(4)
            f.write(struct.pack('<I', size-8))
    return {'file': str(path), 'seconds': len(pcm)/SAMPLE_RATE, 'loop': loop,
            'peak_dbfs': round(20*np.log10(np.max(np.abs(x))), 2),
            'rms_dbfs': round(20*np.log10(np.sqrt(np.mean(x*x))), 2),
            'clipped_samples': int(np.sum(np.abs(pcm.astype(int)) >= 32767))}


def main():
    t = np.arange(round(1.8*SAMPLE_RATE))/SAMPLE_RATE
    # A prompt, smooth climb into the running-loop RPM; no copied melody,
    # Nintendo-logo pass-by, or artificial deceleration while holding throttle.
    rise = 1 - np.exp(-2.6*t)
    rise /= 1 - np.exp(-2.6*1.8)
    revs = 78 + (235-78)*rise
    results = [write('engine_accelerate_retro.wav', motor(t, revs))]
    t = np.arange(round(4.12*SAMPLE_RATE))/SAMPLE_RATE
    results.append(write('engine_running_retro_loop.wav',
                         motor(t, np.full_like(t, 235)), loop=True))
    t = np.arange(round(6.12*SAMPLE_RATE))/SAMPLE_RATE
    results.append(write('engine_idle_retro_loop.wav',
                         motor(t, np.full_like(t, 58), idle=True), loop=True))
    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()

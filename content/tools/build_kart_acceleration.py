"""Build acceleration SFX from the project's existing engine recording.

Run with Python and NumPy. Leaves engine_idle.wav unchanged.
Outputs mono PCM16 / 44.1 kHz WAV, suitable for spatial game audio.
"""

from pathlib import Path
import json
import wave

import numpy as np


SAMPLE_RATE = 44100
ENGINE_DIR = Path(__file__).resolve().parents[1] / "sounds" / "dotakart" / "kart engine"


def read_engine():
    with wave.open(str(ENGINE_DIR / "engine_idle.wav"), "rb") as source:
        if source.getsampwidth() != 2:
            raise ValueError("Expected PCM16 source")
        rate = source.getframerate()
        audio = np.frombuffer(source.readframes(source.getnframes()), dtype="<i2")
        audio = audio.reshape(-1, source.getnchannels()).mean(axis=1) / 32768.0
    audio -= audio.mean()
    if rate != SAMPLE_RATE:
        audio = np.interp(np.arange(round(len(audio) * SAMPLE_RATE / rate)) * rate / SAMPLE_RATE,
                          np.arange(len(audio)), audio)
    # Skip edge transients and blend the recording's wrap before changing RPM.
    audio = audio[round(0.2 * SAMPLE_RATE):-round(0.2 * SAMPLE_RATE)]
    overlap = round(0.14 * SAMPLE_RATE)
    fade = np.linspace(0.0, 1.0, overlap, endpoint=False)
    seam = audio[-overlap:] * (1.0 - fade) + audio[:overlap] * fade
    return np.concatenate([seam, audio[overlap:-overlap]])


def engine_voice(source, pitch, load):
    # Integrating playback rate keeps the waveform phase continuous as RPM rises.
    positions = np.cumsum(pitch) - pitch[0]
    positions = np.remainder(positions, len(source))
    lo = positions.astype(np.int64)
    fraction = positions - lo
    signal = source[lo] * (1.0 - fraction) + source[(lo + 1) % len(source)] * fraction
    # A loaded engine has stronger exhaust harmonics than the idle recording.
    driven = np.tanh(signal * 1.7) / np.tanh(1.7)
    signal = signal * (1.0 - 0.22 * load) + driven * (0.22 * load)
    # Trim subsonic energy and very high hiss without removing engine texture.
    pad = 8192
    extended = np.pad(signal, pad, mode="reflect")
    frequency = np.fft.rfftfreq(len(extended), 1.0 / SAMPLE_RATE)
    response = (frequency**2 / (frequency**2 + 32.0**2))
    response *= 1.0 / np.sqrt(1.0 + (frequency / 7500.0)**8)
    result = np.fft.irfft(np.fft.rfft(extended) * response, n=len(extended))
    return result[pad:-pad] * (0.48 + 0.52 * load)


def write_wav(name, audio, loop=False):
    audio = audio - audio.mean()
    if loop:
        # Crossfade the loop boundary with no silence at either end.
        overlap = round(0.08 * SAMPLE_RATE)
        fade = np.linspace(0.0, 1.0, overlap, endpoint=False)
        seam = audio[-overlap:] * (1.0 - fade) + audio[:overlap] * fade
        audio = np.concatenate([seam, audio[overlap:-overlap]])
    else:
        fade_in = round(0.03 * SAMPLE_RATE)
        fade_out = round(0.18 * SAMPLE_RATE)
        audio[:fade_in] *= np.linspace(0.0, 1.0, fade_in)
        audio[-fade_out:] *= np.linspace(1.0, 0.0, fade_out)
    peak = float(np.max(np.abs(audio)))
    audio *= 0.84 / max(peak, 1e-9)
    pcm = np.rint(audio * 32767.0).astype("<i2")
    path = ENGINE_DIR / name
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        if loop:
            # Standard WAV 'smpl' metadata: forward loop over the complete file.
            import struct
            loop_data = struct.pack("<15I", 0, 0, round(1e9 / SAMPLE_RATE), 60, 0,
                                    0, 0, 1, 0, 0, 0, 0, len(pcm) - 1, 0, 0)
            output.writeframes(pcm.tobytes())
        else:
            output.writeframes(pcm.tobytes())
    if loop:
        with path.open("r+b") as output:
            output.seek(0, 2)
            output.write(b"smpl" + struct.pack("<I", len(loop_data)) + loop_data)
            total = output.tell()
            output.seek(4)
            output.write(struct.pack("<I", total - 8))
    stats = {"file": str(path), "seconds": round(len(audio) / SAMPLE_RATE, 3),
             "sample_rate": SAMPLE_RATE, "channels": 1, "pcm_bits": 16,
             "peak_dbfs": round(20 * np.log10(np.max(np.abs(audio))), 2),
             "rms_dbfs": round(20 * np.log10(np.sqrt(np.mean(audio**2))), 2),
             "clipped_samples": int(np.sum(np.abs(pcm.astype(np.int32)) >= 32767)),
             "loop": loop}
    if loop:
        stats["seam_step"] = round(float(abs(audio[0] - audio[-1])), 6)
    return stats


def main():
    source = read_engine()
    t = np.arange(10 * SAMPLE_RATE) / SAMPLE_RATE
    # Idle -> smoothly loaded acceleration -> high RPM -> throttle release.
    times = [0.0, 0.6, 1.3, 2.5, 4.0, 5.4, 6.7, 7.1, 8.0, 9.1, 10.0]
    rates = [1.0, 1.0, 1.35, 1.95, 2.65, 3.25, 3.3, 3.0, 2.05, 1.1, 1.0]
    loads = [0.12, 0.2, 0.82, 0.96, 1.0, 1.0, 1.0, 0.28, 0.16, 0.12, 0.12]
    # Cosine interpolation prevents abrupt changes in rev slope and volume.
    pitch = np.empty_like(t)
    load = np.empty_like(t)
    for i in range(len(times) - 1):
        mask = (t >= times[i]) & (t < times[i + 1])
        u = (t[mask] - times[i]) / (times[i + 1] - times[i])
        blend = 0.5 - 0.5 * np.cos(np.pi * u)
        pitch[mask] = rates[i] + (rates[i + 1] - rates[i]) * blend
        load[mask] = loads[i] + (loads[i + 1] - loads[i]) * blend
    pitch *= 1.0 + 0.004 * np.sin(2 * np.pi * 8.3 * t)
    stats = [write_wav("engine_accelerate.wav", engine_voice(source, pitch, load))]
    lt = np.arange(round(4.08 * SAMPLE_RATE)) / SAMPLE_RATE
    lp = 3.25 * (1.0 + 0.004 * np.sin(2 * np.pi * 8.3 * lt))
    stats.append(write_wav("engine_running_loop.wav", engine_voice(source, lp, np.ones_like(lt)), loop=True))
    print(json.dumps(stats, indent=2))


if __name__ == "__main__":
    main()

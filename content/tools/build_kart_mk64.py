"""Prepare MK64 reference-based acceleration for audition.

Source: MK64 Nintendo logo 'Vroom!', submitted by Deezer at
https://themushroomkingdom.net/media/mk64/wav
https://themushroomkingdom.net/sounds/wav/mk64/mk64_nintendo_logo.wav

This version adapts an original Nintendo sound, rather than synthesizing one.
The original reference remains unchanged. No game event bindings are changed.
"""

from pathlib import Path
import json
import wave

import numpy as np

from build_kart_acceleration import SAMPLE_RATE, write_wav


def main():
    path = Path(__file__).with_name('mk64_nintendo_logo_reference.wav')
    with wave.open(str(path), 'rb') as w:
        if w.getsampwidth() != 2:
            raise ValueError('Expected 16-bit PCM reference')
        rate = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), '<i2')
        x = x.reshape(-1, w.getnchannels()).mean(axis=1) / 32768.0
    # Keep the genuine acceleration and throttle release, shorten the long
    # approach and distant tail of the logo recording.
    x = x[round(0.75 * rate):round(6.2 * rate)]
    x -= x.mean()
    t = np.arange(len(x)) / rate
    # Mild gain riding brings the initial low revs forward while retaining the
    # original waveform, exhaust texture and natural pitch rise.
    gain = np.interp(t, [0, 0.5, 1.4, 2.1, 2.6, 3.1, 4.0, 5.45],
                     [2.8, 2.8, 1.65, 1.0, 0.92, 1.35, 1.65, 1.9])
    x *= gain
    # Band-limited upsampling, with the source's original bandwidth preserved.
    output_n = round(len(x) * SAMPLE_RATE / rate)
    spectrum = np.fft.rfft(x)
    if len(x) % 2 == 0:
        spectrum[-1] *= 0.5
    x = np.fft.irfft(spectrum, n=output_n) * output_n / len(x)
    stats = write_wav('engine_accelerate_mk64.wav', x)
    print(json.dumps(stats, indent=2))


if __name__ == '__main__':
    main()

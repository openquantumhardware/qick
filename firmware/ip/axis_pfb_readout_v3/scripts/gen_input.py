import numpy as np
import matplotlib.pyplot as plt

# Number of lanes.
L = 4

# Number of channels.
N = 8

# Sampling frequency.
fclk = 100e6
fs = fclk * L
ts = 1 / fs

# Channel center.
fc = fs / N

# Channel bandwidth.
fb = fs / (N / 2)

# Input signal.
f0 = fb / 10
ff0 = 1 * fc + f0
w0 = 2 * np.pi * ff0 / fs
f1 = fb / 33
ff1 = 6 * fc + f1
w1 = 2 * np.pi * ff1 / fs
T = 1 / f1

M = round(100 * T / ts)
n = np.arange(M)
A0 = 0.75 * 2**15
A1 = 0.15 * 2**15

x = A0 * np.cos(w0 * n) + 1j * A0 * np.sin(w0 * n) + \
    A1 * np.cos(w1 * n) + 1j * A1 * np.sin(w1 * n)

x = x + 0.001 * np.random.randn(len(x))

# Note: Original MATLAB code has this line which overwrites the signal with noise
# Uncomment to restore the intended sinusoidal signal
# x = 0.9 * 2**16 * (np.random.random(len(x)) - 0.5)

# Write data into file.
with open('data_iq.txt', 'w') as fid:
    for i in range(M):
        a = x[i]
        fid.write(f"{int(np.real(x[i]))},{int(np.imag(x[i]))}\n")

# Spectrum.
hh = np.hanning(len(x))
X = np.abs(np.fft.fft(x * hh))
F = np.arange(len(X))
F = F / len(F)
plt.figure()
plt.plot(F * fs / 1000 / 1000, 20 * np.log10(X / np.max(X)))
plt.xlabel('Frequency (MHz)')
plt.ylabel('Magnitude (dB)')
plt.title('Spectrum')
plt.grid(True)
plt.show()
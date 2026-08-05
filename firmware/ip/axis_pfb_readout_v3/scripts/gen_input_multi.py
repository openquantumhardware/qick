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

# Frequency shift range.
fshift = fb / 3

# Input signal.
M = 50000
n = np.arange(M)
x = np.zeros(M, dtype=complex)
for k in range(N):
    f = fshift * (np.random.random() - 0.5)
    ff = k * fc + f
    w = 2 * np.pi * ff / fs
    x = x + np.cos(w * n) + 1j * np.sin(w * n)

x = 30000 * x / np.max(np.abs(x))
x = x + 0.001 * np.random.randn(len(x))

# Write data into file.
with open('data_iq.txt', 'w') as fid:
    for i in range(len(x)):
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
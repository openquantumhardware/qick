"""
kidsim_resonator — physics <-> register conversions and response analysis for
axis_kidsim_v3. Mapping derived from (and consistent with) the design note and
the xsim-verified per-clock pole decay.

Fixed point: coefficients are signed Q15 (value = reg/32768). FREQ is an
unsigned phase increment; f0 = FREQ/2**phase_bits * fs.

fs is the rate at which the resonator advances: one step per PROCESSED sample
(the sample punct selects in each frame), not per fabric clock. The DDS IP, the
IIR and the chirp ramp all move only on that sample's valid, so all rates are
per processed sample: fs = f_clk / (frame length) in a firmware with one punct
slot per frame, and fs = 1 gives everything in cycles per sample.
"""
import numpy as np

Q15 = 32768.0
G_UNITY = 0x7FFF  # 32767/32768 ~= 1.0


# --------------------------------------------------------------------------
# scalar conversions (real physical value <-> Q15 register int)
# --------------------------------------------------------------------------
def q15_to_real(reg):
    """signed Q15 register int -> real in [-1, 1)."""
    reg = int(reg) & 0xFFFF
    if reg >= 0x8000:
        reg -= 0x10000
    return reg / Q15


def real_to_q15(x):
    """real in [-1, 1) -> signed Q15 register int (unsigned 16-bit encoding)."""
    r = int(round(x * Q15))
    r = max(-0x8000, min(0x7FFF, r))
    return r & 0xFFFF


# --------------------------------------------------------------------------
# frequency
# --------------------------------------------------------------------------
def freq_reg_from_f0(f0_hz, fs_hz, phase_bits=16):
    """resonator centre frequency (Hz) -> FREQ_REG. f0 in [0, fs)."""
    frac = (f0_hz / fs_hz) % 1.0
    return int(round(frac * (1 << phase_bits))) & ((1 << phase_bits) - 1)


def f0_from_freq_reg(freq_reg, fs_hz, phase_bits=16):
    return (int(freq_reg) / (1 << phase_bits)) * fs_hz


# --------------------------------------------------------------------------
# pole C1 <-> linewidth / Q / ringdown time
#   field decay rate kappa/2 = (1-C1)*fs   (verified: |y1| ~ C1^n per processed sample)
#   kappa (energy/loaded linewidth) = 2*(1-C1)*fs
#   FWHM_Hz = kappa/(2*pi) = (1-C1)*fs/pi
#   Q_loaded = pi*f0 / ((1-C1)*fs)
#   tau_field = 1/((1-C1)*fs)
# --------------------------------------------------------------------------
def kappa_from_c1(c1, fs_hz, exact=True):
    """Loaded linewidth (energy decay rate). exact uses -ln(C1); the high-Q
    approximation (1-C1) matches it as C1->1 (design-note form)."""
    return (-2.0 * np.log(c1) * fs_hz) if exact else (2.0 * (1.0 - c1) * fs_hz)


def c1_from_kappa(kappa_hz, fs_hz, exact=True):
    return np.exp(-kappa_hz / (2.0 * fs_hz)) if exact else (1.0 - kappa_hz / (2.0 * fs_hz))


def q_from_c1(c1, f0_hz, fs_hz, exact=True):
    return 2.0 * np.pi * f0_hz / kappa_from_c1(c1, fs_hz, exact)


def c1_from_q(q_loaded, f0_hz, fs_hz, exact=True):
    kappa = 2.0 * np.pi * f0_hz / q_loaded
    return c1_from_kappa(kappa, fs_hz, exact)


def tau_field_from_c1(c1, fs_hz, exact=True):
    """1/e field-decay time. exact: |y1|~C1^n => tau = 1/(-ln(C1)*fs).
    high-Q approx: 1/((1-C1)*fs)."""
    return (1.0 / (-np.log(c1) * fs_hz)) if exact else (1.0 / ((1.0 - c1) * fs_hz))


# --------------------------------------------------------------------------
# full resonator (notch/hanger) -> (C0, C1, G) register triple
#   high-Q (narrowband, kappa << fs) mapping:
#     1 - C1 = kappa   /(2 fs)   with kappa = kappa_i + kappa_c   (total)
#     1 - C0 = kappa_i /(2 fs)                                    (internal)
#     C0 - C1 = kappa_c/(2 fs)                                    (coupling)
#   on-resonance |S21| ~ G*(1-C0)/(1-C1) = G*kappa_i/kappa   (notch depth)
#   off-resonance |S21| -> G  (set G=1 for a passive notch)
# --------------------------------------------------------------------------
def coeffs_from_resonator(f0_hz, kappa_i_hz, kappa_c_hz, fs_hz,
                          g=1.0, phase_bits=16):
    """Return dict of register ints for a notch resonator."""
    kappa = kappa_i_hz + kappa_c_hz
    c1 = 1.0 - kappa / (2.0 * fs_hz)
    c0 = 1.0 - kappa_i_hz / (2.0 * fs_hz)
    return {
        "FREQ": freq_reg_from_f0(f0_hz, fs_hz, phase_bits),
        "C0": real_to_q15(c0),
        "C1": real_to_q15(c1),
        "G": real_to_q15(g) if g < 1.0 else G_UNITY,
    }


def resonator_from_coeffs(regs, fs_hz, phase_bits=16):
    """Inverse: (C0,C1,G,FREQ) register ints -> physical parameters."""
    c0 = q15_to_real(regs["C0"])
    c1 = q15_to_real(regs["C1"])
    kappa = 2.0 * (1.0 - c1) * fs_hz
    kappa_i = 2.0 * (1.0 - c0) * fs_hz
    kappa_c = kappa - kappa_i
    f0 = f0_from_freq_reg(regs["FREQ"], fs_hz, phase_bits)
    return {
        "f0_hz": f0, "kappa_hz": kappa, "kappa_i_hz": kappa_i,
        "kappa_c_hz": kappa_c, "Q_loaded": (2.0 * np.pi * f0 / kappa) if f0 > 0 else np.inf,
        "notch_depth": (1.0 - c0) / (1.0 - c1),
    }


# --------------------------------------------------------------------------
# ideal notch S21 model (Khalil-style, unit off-resonance)
#   S21(f) = a*exp(i*phi) * (1 - (kappa_c/kappa) / (1 + 2i (f-f0)/kappa))
# --------------------------------------------------------------------------
def s21_notch(f, f0, kappa, kappa_c, a=1.0, phi=0.0):
    return a * np.exp(1j * phi) * (
        1.0 - (kappa_c / kappa) / (1.0 + 4j * np.pi * (f - f0) / kappa)
    )


# --------------------------------------------------------------------------
# fits
# --------------------------------------------------------------------------
def fit_notch(freqs, s21):
    """Fit complex S21 to the notch model. Returns (params dict, model_fn)."""
    from scipy.optimize import least_squares
    freqs = np.asarray(freqs, float)
    s21 = np.asarray(s21, complex)
    # initial guesses from the data
    mag = np.abs(s21)
    f0_0 = freqs[np.argmin(mag)]
    a_0 = np.median(mag[[0, -1]])
    span = np.ptp(freqs)
    # data-driven FWHM estimate: width of the dip at half its depth
    dip = a_0 - mag
    over = np.where(dip > dip.max() / 2.0)[0]
    fwhm_0 = (freqs[over[-1]] - freqs[over[0]]) if over.size > 1 else span / 10.0
    kappa_0 = 2.0 * np.pi * max(fwhm_0, span * 1e-3)   # kappa (energy rate) = 2*pi*FWHM
    depth_0 = 1.0 - mag.min() / max(a_0, 1e-9)
    kc_0 = max(depth_0, 0.05) * kappa_0

    def resid(p):
        f0, kappa, kc, a, phi = p
        m = s21_notch(freqs, f0, kappa, kc, a, phi)
        return np.concatenate([(m - s21).real, (m - s21).imag])

    p0 = [f0_0, kappa_0, kc_0, a_0, 0.0]
    lb = [freqs.min(), span * 1e-4, 0.0, 0.0, -np.pi]
    ub = [freqs.max(), span * 10, span * 10, a_0 * 5 + 1, np.pi]
    res = least_squares(resid, p0, bounds=(lb, ub))
    f0, kappa, kc, a, phi = res.x
    params = {
        "f0": f0, "kappa": kappa, "kappa_c": kc, "kappa_i": kappa - kc,
        "a": a, "phi": phi,
        "Q_loaded": 2.0 * np.pi * f0 / kappa,
        "notch_depth": kc / kappa,
    }
    return params, lambda f: s21_notch(f, f0, kappa, kc, a, phi)


def fit_ringdown(t, envelope):
    """Fit |env(t)| = A*exp(-t/tau) + c. Returns (A, tau, c)."""
    from scipy.optimize import curve_fit
    t = np.asarray(t, float)
    y = np.abs(np.asarray(envelope, float))
    A0 = y[0] - y[-1]
    tau0 = (t[-1] - t[0]) / 3.0
    c0 = y[-1]
    (A, tau, c), _ = curve_fit(
        lambda tt, A, tau, c: A * np.exp(-tt / tau) + c, t, y,
        p0=[A0, tau0, c0], maxfev=20000)
    return A, tau, c

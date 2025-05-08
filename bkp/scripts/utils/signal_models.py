from typing import List, Optional, Tuple, Union

import numpy as np
import numpy.typing as npt
from scipy import constants

C = constants.c
PI = constants.pi


def from_db(x):
    r"""
    $$
    x = 10^{x\;[dB] / 10}
    $$
    """
    return 10 ** (x / 10)


class Target:
    def __init__(
        self,
        r: float,
        vr: float,
        theta: float,
        rcs: Optional[float] = None,
        snr_db: Optional[float] = None,
        type: str = "target",
    ):
        self.r = r
        self.vr = vr
        self.theta = theta  # Given in radians
        self.rcs = rcs
        self.snr_db = snr_db
        self.type = type


def generate_cn_noise(sigma: float = 0, size: Union[int, Tuple[int, ...]] = 1, mu: float = 0) -> np.ndarray:
    """
    Generate complex additive white Gaussian noise (AWGN)

    Parameters
    ----------

    sigma: float, default 1
        Standard deviation of the distribution.
    size: int or tuple of ints, optional
        Output shape.
    mu: float, default 0
        Mean of the distribution.

    Returns
    -------

    noise_signal: ndarray or scalar
        Drawn samples from the parameterized complex normal distribution.

    """
    real_noise = np.random.normal(mu, sigma / np.sqrt(2), size)
    imag_noise = np.random.normal(mu, sigma / np.sqrt(2), size)
    noise_signal = real_noise + 1j * imag_noise
    return noise_signal


def chirp_iq(
    tau: float,
    ts: float,
    fc: float,
    beta: float,
    a: float = 1,
    phi_0: float = 0.0,
    symmetric: bool = False,
) -> npt.NDArray:
    r"""
    Generate a linear frequency modulated signal (also known as "chirp"), defined as

    $$
    X(t) = a e^{j (\pi \beta t^2 / 2 + \pi f_c t + \phi_0)}.
    $$

    Parameters
    ----------

    tau: float
        Pulse width.
    ts: float
        Sample rate.
    fc: float
        Carrier frequency.
    beta: float
        Bandwidth.
    a: float, default 1
        Amplitude.
    phi_0: float, default 0
        Initial phase.
    symmetric: bool, default False
        If True, chirp frequencies are centered at fc.

    Returns
    -------

    out: ndarray
        Generated chirp.
    """

    if symmetric:
        fc -= beta / 2

    # chirp signal
    t = np.arange(0, tau, ts)  # sampled times (sec)
    # chirp rate
    k = beta / tau
    # phase of the waveform
    phi = PI * k * t**2 + 2 * PI * fc * t + phi_0
    output = a * np.exp(1j * phi)
    return output


def generate_rx_input(
    tx_output: np.ndarray,
    lambda_: float,
    ts: float,
    tau: float,
    n_channels_rx: Optional[int] = None,
    d: Optional[float] = None,
    targets: List[Target] = [],
    noise_power: float = 1,
):
    """
    Parameters
    ----------
    tx_output: ndarray
        Output of the transmition chain. Array of dimensions (K, M, N), where K is the number of channels
        (antennas), M the number of pulses, and N the number of fast time samples.
    lambda_: float
        Radar wavelength [Hz].
    ts: float
        Sampling time [s].
    tau: float
        Pulse duration [s].
    d: float (optional)
        Antenna elements spacing.
    targets: list[Target]
        List of target parameters.
    noise_power: float, default 1
        Variance of the Gaussian noise.

    Returns
    -------
    rx_input: ndarray

    """

    if d is None:
        d = lambda_ / 2

    n_channels_tx, n_pul, n_ft = tx_output.shape
    tx_output = tx_output / n_channels_tx
    if n_channels_rx is None:
        n_channels_rx = n_channels_tx
    noise_sigma = np.sqrt(noise_power)
    rx_input = generate_cn_noise(sigma=noise_sigma, size=(n_channels_rx, n_pul, n_ft))
    for target in targets:
        omega_d = 4 * PI * target.vr / lambda_
        t_delay = 2 * target.r / C
        n_delay = round(t_delay / ts)
        snr_db_rx = target.snr_db
        target_amplitude = np.sqrt(from_db(snr_db_rx)) * noise_sigma
        rolled_tx_output = np.roll(tx_output, shift=n_delay, axis=-1)
        for i_rx in range(n_channels_rx):
            for i_tx in range(n_channels_tx):
                spatial_phase = -2 * PI * (i_rx + i_tx) * d * np.sin(target.theta) / lambda_
                for m in range(n_pul):
                    target_input = (
                        target_amplitude
                        * rolled_tx_output[i_tx, m]
                        * np.exp(1.0j * m * omega_d * tau)
                        * np.exp(1.0j * spatial_phase)
                    )
                    rx_input[i_rx, m] = rx_input[i_rx, m] + target_input
    return rx_input

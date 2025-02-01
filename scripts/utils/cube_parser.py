import numpy as np
import matplotlib.pyplot as plt

import os

N_FREQ_CHN = 2
N_BEAMS = 2
N_SWEEPS = 16
N_SAMPLES = 1808

import sys

# -h removes the first 16 bytes where the header should be
if ("-h" in sys.argv):
    offset = 16
else:
    offset = 0

# -r uses a cube difrectory to plot difference between cubes
if ("-r" in sys.argv):
    dirname = sys.argv[1]
    filelist = os.listdir(dirname)

    for fname in filelist[:2]:
        if os.path.isdir(fname):
            continue
        cube = np.fromfile(os.path.join(dirname,fname), offset=offset, dtype=np.int16)
        cube_array = cube.reshape(2,N_FREQ_CHN, N_BEAMS, -1, order='F')
        cube_array = cube_array.reshape(cube_array.shape[:-1] + (N_SWEEPS, N_SAMPLES))

        plt.plot(cube_array[0,0,0,0])
    plt.grid()
    plt.show()
else:
    fname = sys.argv[1]

    cube = np.fromfile(fname, offset=offset, dtype=np.int16)
    cube_array = cube.reshape(2,N_FREQ_CHN, N_BEAMS, -1, order='F')
    cube_array = cube_array.reshape(cube_array.shape[:-1] + (N_SWEEPS, N_SAMPLES))


    fig, axs = plt.subplots(nrows=N_SWEEPS, ncols=N_BEAMS*N_FREQ_CHN, layout='constrained', 
                            figsize=(1 * N_SWEEPS, 3.5 * N_BEAMS*N_FREQ_CHN))

    for i, axc in enumerate(axs):
        for j, axr in enumerate(axc):
            axr.axis("off")
            axr.plot(cube_array[0, j%N_FREQ_CHN, j//N_BEAMS, i])
            axr.set_title(f"Sweep:{i};Freq:{j%N_FREQ_CHN};Beam:{j//N_BEAMS}")

    fig, axs = plt.subplots(nrows=N_SWEEPS, ncols=N_BEAMS*N_FREQ_CHN, layout='constrained', 
                            figsize=(1 * N_SWEEPS, 3.5 * N_BEAMS*N_FREQ_CHN))

    for i, axc in enumerate(axs):
        for j, axr in enumerate(axc):
            axr.axis("off")
            axr.plot(cube_array[1, j%N_FREQ_CHN, j//N_BEAMS, i])
            axr.set_title(f"Sweep:{i};Freq:{j%N_FREQ_CHN};Beam:{j//N_BEAMS}")

    plt.figure()
    plt.title("Difference between sweeps")
    for i in range(16):
        plt.plot(cube_array[0,0,0,i])

    plt.show()

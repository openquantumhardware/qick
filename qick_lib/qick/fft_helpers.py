import numpy as np

def findPeak(x,y,xmin=-1,xmax=-1):
    if xmin == -1:
        xmin = np.min(x)        
    if xmax == -1:
        xmax = np.max(x)        

    imin = np.argwhere(x <= xmin)
    imin = imin[-1].item()
    imax = np.argwhere(x >= xmax)
    imax = imax[0].item()

    # Find max.
    idxmax = np.argmax(y[imin:imax]) + imin

    # x, y.
    Xmax = x[idxmax].item()
    Ymax = y[idxmax].item()

    return Xmax, Ymax        

# Sort FFT data. Output FFT is bit-reversed. Index is given by idx array.
def sort_br(x, idx):
    x_sort = np.zeros(len(x)) + 1j*np.zeros(len(x))
    for i in np.arange(len(x)):
        x_sort[idx[i]] = x[i]

    return x_sort    
        

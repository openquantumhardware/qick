import numpy as np


def get_bin(x, n=0): 
    """
    Get the binary representation of x. 
    
    Parameters
    ----------
    x : int 
    n : int 
        Minimum number of digits. If x needs less digits in binary, the rest is filled with zeros. 
        
    Returns
    -------
    str
    """
    
    return format(x,'b').zfill(n)

def adc_processing(x,nbit):
    """
    Pre processing of the data x read from the BRAM. 
    The BRAM interface to PYNQ is 32bit wide, thus two samples with 16bits are concatenated. 
    From the 16bits samples, 2 LSB bits are redundant filled for the AXI protocol and will be removed. 
    
    Parameters
    ----------
    x: list of elements with type "int"
    nbit: bit width of sample
    
    Returns
    -------
    x_out: list of elements with type "int"
    """
    
    x_split  = [0]*len(x)*2
    x_out    = [0]*len(x)*2
    
    for i in range(len(x)):
        x_bin = get_bin(x[i],32)                  # convert back to binary representation
          
        # split 32bit word to 2 samples à 16bits and remove the 2 redundant bits
        x_split[i*2+1]   = x_bin[0:nbit]          # MSB aligned sample is second sample
        x_split[i*2]     = x_bin[16:16+nbit]      # LSB aligned sample is first sample
        
    for i in range(len(x)*2):
        x_out[i] = int(x_split[i],2)                 # convert back to integer
        
        if x_out[i] >= 2**(nbit-1):                  # Adapt integer to signed twos complement
            x_out[i] = x_out[i]-2**nbit
            
    return x_out


def dac_processing(x):
    """
    Pre processing of the data written into the BRAM. 
    The BRAM interface to PYNQ is 32bit wide, thus two samples with 16bits are concatenated. 
    From the 16bits samples, 2bits are redundant filled for the AXI protocol and will be removed. 
    
    Parameters
    ----------
    x: signal as numpy array
    
    Returns
    -------
    x_write: list of elements with type "int"
    """
    
    if np.max(np.abs(x))>1:
        print('Warning: Signal exceeds +-1. Clipping occurs.')
        x[x<-1] = -1
        x[x>1]  = 1
    
    x               = np.round(x*2**(14-1))  # scale to 14bit resolution
    x[x==2**(14-1)] = 2**(14-1)-1            # replace 8192 by 8191
    x[x<0]          = x[x<0]+2**14                # convert to signed decimal representation

    x_write = [0]*int(len(x)/2)

    for i in range(len(x_write)): 
        x_bin_1    = get_bin(int(x[i*2]),14)
        x_bin_2    = get_bin(int(x[i*2+1]),14)
        x_bin_12   = x_bin_2 + '00' + x_bin_1 + '00'
        x_write[i] = int(x_bin_12,2)

    return x_write
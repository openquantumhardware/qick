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

def adc_processing(data,nbit):
    """
    Pre processing of the data read from the BRAM. 
    The BRAM interface to PYNQ is 32bit wide, thus two samples with 16bits are concatenated. 
    From the 16bits samples, 4bits are redundant filled for the AXI protocol and will be removed. 
    
    Parameters
    ----------
    data: list of elements with type "int"
    nbit: bit width of sample
    
    Returns
    -------
    data_out: list of elements with type "int"
    """
    
    data_bin    = [0]*len(data)
    data_split  = [0]*len(data)*2
    data_out    = [0]*len(data)*2
    
    for i in range(len(data)):
        data_bin[i] = get_bin(data[i],32)               # convert back to binary representation
          
        # split 32bit word to 2 samples à 16bits and remove the 4 redundant bits
        data_split[i*2+1]   = data_bin[i][0:nbit]       # MSB aligned sample is second sample
        data_split[i*2]     = data_bin[i][16:16+nbit]   # LSB aligned sample is first sample
        
    for i in range(len(data)*2):
        data_out[i] = int(data_split[i],2)              # convert back to integer
        
        if data_out[i] >= 2**(nbit-1):                  # Adapt integer to signed twos complement
            data_out[i] = data_out[i]-2**nbit
            
    return data_out


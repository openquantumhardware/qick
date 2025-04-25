import numpy as np
import matplotlib.pyplot as plt


def main():
    
    plt.close('all')
    print('Demonstration of Direct Digital Synthesizer')
    print('aleksei.rostov@protonmail.com')

# reading FPGA data

    dds_lut()
    fpga_data()
    plt.show()
    
    
# def psk(s, n_clocks):
    # N = int(s.size)
    # tmp = 1
    # psi = np.zeros((N, 1))
    # for i in range(N):
        # if(np.mod(i , n_clocks) == 0):
            # tmp = ~(tmp)
        # if(tmp == 1):    
            # s[i] = 1 * s[i]
        # else:
            # s[i] = -1 * s[i]
        # psi[i] = tmp
    # return s, psi
    
    
def fpga_data():


    s       = np.loadtxt('../files/simple.txt')
    N       = int(s.size / 2)
    s_new   = np.reshape(s, (N, 2))
    x_cmpx  = s_new[:, 0] + 1j*s_new[:, 1]
    XF      = np.fft.fft(x_cmpx, axis=0, norm=None)
    f_axis  = np.linspace(0, 100, N)

    plt.figure()
    plt.subplot(221)
    plt.title("sin and cos: time")
    plt.plot(np.real(x_cmpx), '.-r', label='real')
    plt.plot(np.imag(x_cmpx), '.-b', label='imag')
    plt.xlabel("time, bins")
    plt.grid()
    plt.legend()
    
    plt.subplot(223)
    plt.plot(f_axis, np.abs(XF), '.-b')
    plt.title("sin and cos: frequency")
    plt.xlabel("freq, MHz")
    plt.grid()
    

    s       = np.loadtxt('../files/psk.txt')
    N       = int(s.size / 2)
    s_new   = np.reshape(s, (N, 2))
    x_cmpx  = s_new[:, 0] + 1j*s_new[:, 1]
    XF      = np.fft.fft(x_cmpx, axis=0, norm=None)
    f_axis  = np.linspace(0, 100, N)

    plt.subplot(222)
    plt.title("PSK: time")
    plt.plot(np.real(x_cmpx), '.-r', label='real')
    plt.plot(np.imag(x_cmpx), '.-b', label='imag')
    plt.xlabel("time, bins")
    plt.grid()
    plt.legend()
    
    plt.subplot(224)
    plt.plot(f_axis, np.abs(XF), '.-b')
    plt.xlabel("freq, MHz")
    plt.title("PSK: frequency")
    plt.grid()
    
    plt.tight_layout()


    s       = np.loadtxt('../files/fsk.txt')
    N       = int(s.size / 2)
    s_new   = np.reshape(s, (N, 2))
    x_cmpx  = s_new[:, 0] + 1j*s_new[:, 1]
    XF      = np.fft.fft(x_cmpx, axis=0, norm=None)
    f_axis  = np.linspace(0, 100, N)

    plt.figure()
    plt.subplot(221)
    plt.title("FSK: time")
    plt.plot(np.real(x_cmpx), '.-r')
    plt.plot(np.imag(x_cmpx), '.-b')
    plt.xlabel("time, bins")
    plt.grid()
    
    plt.subplot(223)
    plt.plot(f_axis, np.abs(XF), '.-b')
    plt.title("FSK: frequency")
    plt.xlabel("freq, MHz")
    plt.grid()
    

    s       = np.loadtxt('../files/lfm.txt')
    N       = int(s.size / 2)
    s_new   = np.reshape(s, (N, 2))
    x_cmpx  = s_new[:, 0] + 1j*s_new[:, 1]
    XF      = np.fft.fft(x_cmpx, axis=0, norm=None)
    f_axis  = np.linspace(0, 100, N)

    plt.subplot(222)
    plt.title("LFM: time")
    plt.plot(np.real(x_cmpx), '.-r')
    plt.plot(np.imag(x_cmpx), '.-b')
    plt.xlabel("time, bins")
    plt.grid()
    
    plt.subplot(224)
    plt.plot(f_axis, np.abs(XF), '.-b')
    plt.xlabel("freq, MHz")
    plt.title("LFM: frequency")
    plt.grid()
    
    plt.tight_layout()
    
    
    return 0




def dds_lut():

    sinus_l = np.sin(2*np.pi*np.linspace(0, 1, 2**16))
    
    # phase increment
    incrm_t = 4
    incrm_k = 20
   
    
    sinus_t = np.zeros(2**16)
    sinus_k = np.zeros(2**16)
    
    phase_l = np.zeros(2**16)
    phase_t = np.zeros(2**16)
    phase_k = np.zeros(2**16)
    for n in range(0, 2**16):
    
        phase_l[n] = n
        
        phase_t[n] = (incrm_t*n) % 2**16
        sinus_t[n] = sinus_l[(incrm_t*n) % 2**16]
        
        phase_k[n] = ((n// 50)**2) % 2**16
        sinus_k[n] = sinus_l[((n // 50)**2) % 2**16]
        
        
    
    plt.figure()
    
    plt.subplot(311)
    plt.title('DDS output, phase increment is {}'.format(1))
    plt.plot(sinus_l, '.-b', label='signal')
    plt.plot(phase_l/2**16, '.-g', label='phase')
    plt.grid()
    plt.legend()
    
    plt.subplot(312)
    plt.title('DDS output, phase increment is {}'.format(incrm_t))
    plt.plot(sinus_t, '.-b', label='signal')
    plt.plot(phase_t/2**16, '.-g', label='phase')
    plt.grid()
    plt.legend()
    
    plt.subplot(313)
    plt.title('DDS output for LFM')
    plt.plot(sinus_k, '.-b', label='signal')
    plt.plot(phase_k/2**16, '.-g', label='phase')
    plt.grid()
    plt.legend()
    
    plt.tight_layout()
        
    

    return 0





if __name__ == "__main__":
    main()


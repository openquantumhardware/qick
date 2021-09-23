# Support functions.
def gauss(mu=0,si=25,length=100,maxv=30000):
    x = np.arange(0,length)
    y = 1/(2*np.pi*si**2)*np.exp(-(x-mu)**2/si**2)
    y = y/np.max(y)*maxv
    return y

def triang(length=100,maxv=30000):
    y1 = np.arange(0,length/2)
    y2 = np.flip(y1,0)
    y = np.concatenate((y1,y2))
    y = y/np.max(y)*maxv
    return y

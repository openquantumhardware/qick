import numpy as np
import matplotlib.pyplot as plt

def gauss(mu=0, si=0, length=100, maxv=30000):
	x = np.arange(0,length)
	y = 1/(2*np.pi*si**2)*np.exp(-(x-mu)**2/si**2)
	y = y/np.max(y)*maxv
	return y

yq = gauss(mu=300, si=120, length=512)
yi = np.zeros(len(yq))

yi = yi.astype(np.int16)
yq = yq.astype(np.int16)

for ii in range(len(yi)):
	print("%d,%d" %(yq[ii],yi[ii]))


import numpy as np
import matplotlib.pyplot as plt

def triang(length=100, maxv=30000):
	y1 = np.arange(0,length/2)
	y2 = np.flip(y1,0)
	y = np.concatenate((y1,y2))
	y = y/np.max(y)*maxv
	return y

yq = triang(length=512)
yi = yq

yi = yi.astype(np.int16)
yq = yq.astype(np.int16)

for ii in range(len(yi)):
	print("%d,%d" %(yq[ii],yi[ii]))


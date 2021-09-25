"""
Support functions.
"""
import numpy as np

def gauss(mu=0,si=25,length=100,maxv=30000):
    """
    Create a numpy array containing a Gaussian function

    :param mu: Mu (peak offset) of Gaussian
    :type mu: float
    :param sigma: Sigma (standard deviation) of Gaussian
    :type sigma: float
    :param length: Length of array
    :type length: int
    :param maxv: Maximum amplitude of Gaussian
    :type maxv: float
    :return: Numpy array containing a Gaussian function
    :rtype: array
    """
    x = np.arange(0,length)
    y = 1/(2*np.pi*si**2)*np.exp(-(x-mu)**2/si**2)
    y = y/np.max(y)*maxv
    return y

def triang(length=100,maxv=30000):
    """
    Create a numpy array containing a triangle function

    :param length: Length of array
    :type length: int
    :param maxv: Maximum amplitude of triangle function
    :type maxv: float
    :return: Numpy array containing a triangle function
    :rtype: array
    """
    y1 = np.arange(0,length/2)
    y2 = np.flip(y1,0)
    y = np.concatenate((y1,y2))
    y = y/np.max(y)*maxv
    return y

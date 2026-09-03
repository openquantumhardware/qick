clear all;
close all;

% Number of lanes.
L = 4;

% Number of channels.
N = 8;

% Sampling frequency.
fclk = 100e6;
fs = fclk*L;

% Channel center.
fc = fs/N;

% Channel bandwidth.
fb = fs/(N/2);

K = 7;
file = sprintf('dout_%d.csv', K);
data = csvread(file, 1, 0);

% Get only valid data.
idx = find(data(:,1) == 1);
xi = data(idx,2);
xq = data(idx,3);
x = double(xi) +1i*double(xq);

% Channel data.
%K = 2;
%xk = x(K+1:8:end);
xk = x;

% Time domain.
n = 0:length(xk)-1;
plot(n,real(xk),'r',n,imag(xk),'b')
legend('real','imag')

% Spectrum.
hh = hanning(length(xk));
X = abs(fftshift(fft(xk.*hh.')));
F = -length(xk)/2:length(xk)/2-1;
F = F/length(F);
figure; plot(F*fb/1000/1000,20*log10(X/max(X)))
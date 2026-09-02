clear all;
close all;

% Number of lanes.
L = 4;

% Number of channels.
N = 8;

% Sampling frequency.
fclk = 100e6;
fs = fclk*L;
ts = 1/fs;

% Channel center.
fc = fs/N;

% Channel bandwidth.
fb = fs/(N/2);

% Input signal.
f0 = fb/10;
ff0 = 1*fc + f0;
w0 = 2*pi*ff0/fs;
f1 = fb/33;
ff1 = 6*fc + f1;
w1 = 2*pi*ff1/fs;
T = 1/f1;

M = round(100*T/ts);
n = 0:M-1;
A0 = 0.75*2^15;
A1 = 0.15*2^15;

x = A0*cos(w0*n); + 1j*A0*sin(w0*n) + ...
    A1*cos(w1*n) + 1j*A1*sin(w1*n);

x = x + 0.001*rand(size(x));

x = 0.9*2^16*(rand(size(x))-0.5);

% Write data into file.
fid = fopen('data_iq.txt','w');
for i=1:M
    a = x(i);
    fprintf(fid,'%d,%d\n',fix(real(x(i))),fix(imag(x(i))));
end
fclose(fid);

% Spectrum.
hh = hanning(length(x));
X = abs(fft(x.*hh.'));
F = 0:length(X)-1;
F = F/length(F);
figure; plot(F*fs/1000/1000,20*log10(X/max(X)))
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

% Frequency shift range.
fshift = fb/3;

% Input signal.
M = 50000;
n = 0:M-1;
x = zeros(1,M);
for k=0:N-1
    f = fshift*(rand(1)-0.5);
    ff = k*fc + f;
    w = 2*pi*ff/fs;
    x = x + cos(w*n) + 1j*sin(w*n);
end

x = 30000*x/max(x);
x = x + 0.001*rand(1,length(x));

% Write data into file.
fid = fopen('data_iq.txt','w');
for i=1:length(x)
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
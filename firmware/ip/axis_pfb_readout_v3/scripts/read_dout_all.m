clear all
close all

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

% Input signal.
data = csvread('data_iq.txt', 0, 0);
xi = data(:,1);
xq = data(:,2);
x = double(xi) + 1i*double(xq);
x = x + 0.01*rand(size(x));
    
% Windowing.
w = hanning(length(x));
xw = x.*w;    
    
XF = fft(xw)/length(xw);
F = 0:length(XF)-1;
F = F/length(F)*fs;
plot(F/1000/1000,20*log10(abs(XF)/2^15))
xlim([-10 fs/1000/1000])
ylim([-200 10])

figure; hold on;
for kk=0:N-1
    file = sprintf('dout_%d.csv', kk);
    data = csvread(file, 1, 0);

    % Get only valid data.
    idx = find(data(:,1) == 1);
    xi = data(idx,2);
    xq = data(idx,3);
    x = double(xi) + 1i*double(xq);
    x = x + 0.01*rand(size(x));
    
    % Windowing.
    w = hanning(length(x));
    xw = x.*w;
    
    % Channel center frequency.
    CF = fc*kk;
    
    XF = fftshift(fft(xw))/length(xw);
    F = -length(XF)/2:length(XF)/2-1;
    F = F/length(F)*fb;
    plot((F+CF)/1000/1000,20*log10(abs(XF)/2^15))
    xlim([-10 fs/1000/1000])
    ylim([-200 10])
end

title('Output Channels side by side')
xlabel('f [Mhz]')
ylabel('Gain [dB]')

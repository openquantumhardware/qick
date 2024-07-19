clear all;
close all;

% Number of PFB channels and Decimation factor (50 % overlap).
N = 256;
M = N/2;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Sinc-Kaiser Analysis Nyquist Filter %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Sampling the sinc.
Nz = 4;
n = -(Nz-1/N):1/N:(Nz-1/N);
xn = sinc(n);
Ns = length(xn);

% Windowed with Kaiser.
w = kaiser(Ns, 8);
h0 = xn.*w';
h0 = [0 h0];

% Modulated filter (to simulate neighbor channels).
nc = 0:length(h0)-1;
c = exp(1j*2*pi/N*nc);
h1 = h0.*c;
h2 = h1.*c;

% Sum to check how good neighbor channels add to 1.
hs = h0 + h1 + h2;

% Spectrum.
Nfft = 10*Ns;
XN = fftshift(fft(xn,Nfft));
WW = fftshift(fft(w,Nfft));
H0 = fftshift(fft(h0,Nfft));
H1 = fftshift(fft(h1,Nfft));
H2 = fftshift(fft(h2,Nfft));
HS = fftshift(fft(hs,Nfft));
W = linspace(-pi,pi,length(XN));

% Plot sinc.
subplot(211);
plot(n,xn, 'm*', 'linewidth', 2);
grid;
title('Sampled Sinc');
xlabel('n');

% Plot frequency domain.
subplot(212);
plot(W/pi, abs(XN)/max(abs(XN)), 'linewidth' ,2, 'DisplayName', 'sinc'); hold on;
plot(W/pi, abs(WW)/max(abs(WW)), 'linewidth' ,2, 'DisplayName', 'kaiser');
plot(W/pi, abs(H0)/max(abs(H0)), 'linewidth' ,2, 'DisplayName', 'H_0');
plot([1/N 1/N], [0 1.2], 'r--', 'DisplayName', '\pi/N');
xlim([-1/M 1/M]);
grid;
legend show;
xlabel('Frequency [\theta/\phi]');
title('Spectrum');

% Plot neighbor channels.
figure;
subplot(211);
plot(W/pi, abs(H0)/max(abs(H0)), 'linewidth' ,2, 'DisplayName', 'H_0'); hold on;
plot(W/pi, abs(H1)/max(abs(H0)), 'linewidth' ,2, 'DisplayName', 'H_1');
plot(W/pi, abs(H2)/max(abs(H0)), 'linewidth' ,2, 'DisplayName', 'H_2');
plot(W/pi, abs(HS)/max(abs(HS)), 'linewidth' ,2, 'DisplayName', 'H_S');
grid;
legend show;
xlim([-1/M 4/M]);
ylim([0 1.2]);
xlabel('Frequency [\theta/\phi]');
title('Comparison of Neighbor Channels');

subplot(212);
plot(W/pi, 20*log10(abs(H0)/max(abs(H0))), 'linewidth' ,2, 'DisplayName', 'H_0'); hold on;
plot(W/pi, 20*log10(abs(H1)/max(abs(H0))), 'linewidth' ,2, 'DisplayName', 'H_1');
plot(W/pi, 20*log10(abs(H2)/max(abs(H0))), 'linewidth' ,2, 'DisplayName', 'H_2');
plot(W/pi, 20*log10(abs(HS)/max(abs(HS))), 'linewidth' ,2, 'DisplayName', 'H_S');
grid;
legend show;
xlim([-1/M 4/M]);
ylim([-100 10]);
xlabel('Frequency [\theta/\phi]');
title('Comparison of Neighbor Channels');

% Pass band detail.
figure;
maxy = 1.5*max(20*log10(abs(H0)));
plot(W/pi, 20*log10(abs(H0)), 'linewidth' ,2); grid;
xlim([-1/N 1/N]);
ylim([-maxy maxy]);
xlabel('Frequency [\theta/\pi');
ylabel('Amplitude [dB]');
title('Pass band ripple detail');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Synthesis Low-Pass Filter %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Modulated filter (to simulate interpolation by M replicas).
c = exp(1j*2*pi/M*nc);
h0_cM = h0.*c;

% Cut-off frequency.
wd = 0.8*pi/(4*M);
wp = pi/M-wd;
wst = pi/M+wd;

% Design filter.
%f = fdesign.lowpass('Fp,Fst,Ap,Ast', wp/pi, wst/pi, 0.1, 70);
Nf = 8*N - 2;
f = fdesign.lowpass('N,Fp,Fst,Ap', Nf, wp/pi, wst/pi, 0.1);
h0_s = design(f, 'equiripple');
h0_s = h0_s.Numerator;
h0_s = [0 h0_s];

% Modulated synthesis filter (to simulate neighbor channels).
nc = 0:length(h0_s)-1;
c = exp(1j*2*pi/N*nc);
h0_s_cN = h0_s.*c;

% Spectrum.
H0_CM   = fftshift(fft(h0_cM,Nfft));
H0_S    = fftshift(fft(h0_s,Nfft));
H0_S_CN = fftshift(fft(h0_s_cN,Nfft));

% Plot replicas of Analysis filter with Synthesis filter.
figure;
plot(W/pi, 20*log10(abs(H0)/max(abs(H0))), 'linewidth' ,2, 'DisplayName', 'H_0'); hold on;
plot(W/pi, 20*log10(abs(H0_CM)/max(abs(H0))), 'linewidth' ,2, 'DisplayName', 'H_0_C_M');
plot(W/pi, 20*log10(abs(H0_S)), 'linewidth' ,2, 'DisplayName', 'H_0_S');
plot([1/M 1/M], [-60 10], 'r--', 'DisplayName', '\pi/M');
plot([wp wp]/pi, [-60 10], 'r--', 'DisplayName', 'w_p');
plot([wst wst]/pi, [-60 10], 'r--', 'DisplayName', 'w_s_t');
grid;
legend show;
xlim([-1/M 4/M]);
xlabel('Frequency [\theta/\phi]');
title('Replicas of Analysis Filter with Synthesis Filter');

% Plot replicas of Synthesis filter.
figure;
plot(W/pi, 20*log10(abs(H0_S)), 'linewidth' ,2, 'DisplayName', 'H_0_S'); hold on;
plot(W/pi, 20*log10(abs(H0_S_CN)), 'linewidth' ,2, 'DisplayName', 'H_0_S_C_N');
plot([1/M 1/M], [-60 10], 'r--', 'DisplayName', '\pi/M');
plot([1/N 1/N], [-60 10], 'b--', 'DisplayName', '\pi/N');
grid;
legend show;
xlim([-1/M 4/M]);
xlabel('Frequency [\theta/\phi]');
title('Replicas of Synthesis Filter');

% Rename filters.
ha = h0;
hs = h0_s;

save filters.mat N ha hs

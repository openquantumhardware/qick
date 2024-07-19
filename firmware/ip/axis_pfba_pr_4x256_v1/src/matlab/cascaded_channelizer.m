clear all;
close all;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Load filters from file %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
load filters.mat

% Decimation.
M = N/2;

disp('Loaded filters:');
disp(['  N  : ' num2str(N) ' channels']);
disp(' ');

disp(['  ha : ' num2str(length(ha)) ' coefficients']);
disp(['  ha : ' num2str(length(ha)/N) ' coefficients per path']);
disp(' ');
disp(['  hs : ' num2str(length(hs)) ' coefficients']);
disp(['  hs : ' num2str(length(hs)/N) ' coefficients per path']);
disp(' ');

%%%%%%%%%%%%%%%%%%%%
%%% Input Signal %%%
%%%%%%%%%%%%%%%%%%%%
n = 0:5000*N-1;
%x = exp(1j*2*pi/N*n) + 0.100*randn(1,length(n));
x = zeros(1,length(n));
%x = 0.1*randn(1,length(n));
x(1) = 1;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Polyphase Filter Bank (Analysis) %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Commutator (older samples go into lower row).
xz    = [zeros(1,N-1),x];
xap   = zeros(N,length(x));
xap_m = zeros(N,length(x)/M);
for ii=0:N-1
    xx = xz(N-1-ii + 1:end-ii);
    xap(ii+1,:)   = xx;
    xap_m(ii+1,:) = downsample(xx,M);   
end

% Polyphase decomposition of filter.
Nf = length(ha);
hap_ = reshape(ha,N,Nf/N);

% Interpolate filter.
hap = zeros(N,Nf/M);
for i=0:N-1
    hap(i+1,:) = upsample(hap_(i+1,:),N/M);
end

% Apply Channel Filters.
wap   = zeros(N,length(xap_m)+length(hap(1,:))-1);    
for ii=0:N-1
    wap(ii+1,:) = conv(xap_m(ii+1,:),hap(ii+1,:));
end
    
% Compute fft.
xak = zeros(N,length(wap(1,:)));
for ii=0:length(wap(1,:))-1
    xx = wap(:,ii+1);        
    xak(:,ii+1) = N*ifft(xx);
end 

% -1^n;
nn = 0:length(xak(1,:))-1;
pm = -1*ones(1,length(nn));
pm = pm.^nn;
xk = xak;
for k=0:N-1
   if mod(k,2) ~= 0
       xk(k+1,:) = xk(k+1,:).*pm;
   end
end

% Apply mask.
mask = zeros(1,N);
mask(10:30) = 1;
mask(43:50) = 1;

xkm = xk;
for ii=0: N-1
   xkm(ii+1,:) = mask(ii+1)*xk(ii+1,:); 
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Polyphase Filter Bank (Synthesis) %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% -1^n;
nn = 0:length(xkm(1,:))-1;
pm = -1*ones(1,length(nn));
pm = pm.^nn;
xsk = xkm;
for k=0:N-1
   if mod(k,2) ~= 0
       xsk(k+1,:) = xsk(k+1,:).*pm;
   end
end

% Polyphase decomposition of filter.
Nf = length(hs);
hsp_ = reshape(hs,N,Nf/N);

% Interpolate filter.
hsp = zeros(N,Nf/M);
for i=0:N-1
    hsp(i+1,:) = upsample(hsp_(i+1,:),N/M);
end

% Compute fft.
wsp = zeros(N,length(xsk(1,:)));
for ii=0:length(xsk(1,:))-1
    ww = xsk(:,ii+1);
    wsp(:,ii+1) = ifft(ww);
end
       
% Apply Channel Filters.
xsp = zeros(N,length(wsp(1,:))+length(hsp(1,:))-1);    
for ii=0:N-1
    xsp(ii+1,:) = conv(wsp(ii+1,:),hsp(ii+1,:));
end

% Commutator (lower row are older samples).
xsp_m = zeros(N,M*length(xsp(1,:))+N-1);
for ii=0:N-1
    Nz_b = ii;
    Nz_a = N - 1 - ii;
    xx = M*upsample(xsp(ii+1,:),M);
    xsp_m(ii+1,:) = [zeros(1,Nz_b) xx zeros(1,Nz_a)];
end
y = sum(xsp_m, 1);

%%%%%%%%%%%%%%%
%%% Results %%%
%%%%%%%%%%%%%%%
figure;
Nfft = 4096;

% Plot spectrum of output.
Y = fft(y,Nfft);
W = linspace(0,1,Nfft);

plot(W,20*log10(abs(Y)));
xlim([-0.2 1]);
grid;
title('Spectrum of output signal');



clear all
close all

% Base filter.
load '../filters.mat'

% Number of channels, decimation factor and lanes.
M = N/2;
L = 4;

% Sampling frequency.
fs = 1;
ts = 1/fs;

% Polyphase decomposition:
% N-branch polyphase decomposition of the filter. Then, M times decimation.
% This should lead to filters with N/M-1 zeros between coefficients. I can
% use a interpolated filter in vivado, to avoid those zero coefficients and
% save resources.

% The decomposition takes the first set of coefficients into the first
% filter, and so on. This is because the commutator model used inside the
% FIR filter compiler moves down on every clock (model with z^-1 and
% interpolators). Also, if the filter is multiplied by a complex exponential,
% this model ends up being followed by an IFFT instead of a FFT.

% The decomposition uses N sub-filters. With L lanes that gives N/L
% sub-filters per lane. Using 2 FIR cores per lane gives N/(2*L)
% sub-filter per FIR core, with a delay of M/L on the first core of each 
% lane. 

% Synthesis Filter.
h = hs;

% Polyphase Decomposition.
hp = zeros(N,length(h)/N);
for kk=0:N-1
   hh = h(kk+1:end);
   hh = downsample(hh,N);
   hp(kk+1,:) = hh;
end

% Put together sub-filters for FIR compiler.
% It's implemented in L lanes. The first lane will have sub-filters h0, hL,
% h2L, ... Lane 1 will have sub-filters h1, hL+1, h2L+1, ... In general,
% lane m-esime will have sub-filters hm, hL+m, h2L+m, ...
% As the FIR compiler cannot implement a commutator with different number
% of branches and decimation factor, for 50 % overlap the numer of branches
% per lane is such that filter are implemented with 2 FIR cores. These two
% cores implement half the branch sub-filters each.
hp_fir = zeros(size(hp));
for jj=0:L-1
    for kk=0:N/L-1
        idx0 = jj*N/L + kk;
        idx1 = kk*L + jj;
        hp_fir(idx0+1,:) = hp(idx1+1,:);
        %disp(['idx0 = ' num2str(idx0) ', idx1 = ' num2str(idx1)])
    end
end

% Quantization.
hp_fir = fi(hp_fir);

%%%%%%%%%%%%%%%%%%%%
% write .coe files %
%%%%%%%%%%%%%%%%%%%%
hp_lane = zeros(N/L,length(hp_fir(1,:)));
for jj=0:L-1
    % Lane sub-filters.
    idx0 = jj*N/L;
    idx1 = idx0 + N/L/2-1;
    idx2 = idx1 + 1;
    idx3 = idx2 + N/L/2-1;
    hp_lane_0 = hp_fir(idx0+1:idx1+1,:);
    hp_lane_0 = reshape(hp_lane_0',1,[]);
    hp_lane_1 = hp_fir(idx2+1:idx3+1,:);
    hp_lane_1 = reshape(hp_lane_1',1,[]);
    
    idx = 2*jj;
    fn0 = sprintf('./synthesis/fir_%d.coe',idx);
    fn1 = sprintf('./synthesis/fir_%d.coe',idx+1);
    
    % Write files.
    fid = fopen(fn0,'w');
    fprintf(fid,'Radix = 10;\n');
    fprintf(fid,'CoefData = ');
    cc = hp_lane_0(1:end-1);
    fprintf(fid,'%d,',cc.int);
    cc = hp_lane_0(end);
    fprintf(fid,'%d',cc.int);
    fclose(fid);
    
    fid = fopen(fn1,'w');
    fprintf(fid,'Radix = 10;\n');
    fprintf(fid,'CoefData = ');
    cc = hp_lane_1(1:end-1);
    fprintf(fid,'%d,',cc.int);
    cc = hp_lane_1(end);
    fprintf(fid,'%d',cc.int);
    fclose(fid);
end

% Quantization parameters.
WL = hp_fir.WordLength;
FL = hp_fir.FractionLength;

disp(' ')
disp(['Number of channels per FIR core: ' num2str(N/(2*L))])
disp(['Delay on first core: ' num2str(M/L)])
disp(' ')
disp(['Coeff WL = ' num2str(WL) ', FL = ' num2str(FL)])


%% STO采样时间偏移
SF=9;
M=2^SF;
aa=M/2;%randi([0 M-1]);
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M));
SNR = -10;
xk = awgn(xk,SNR,'measured');
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
%% STO
L_sto = M/4;lamda_sto = 0;
STO_fr = exp(1j*2*pi*lamda_sto*k/M);
STO_fr = circshift(STO_fr, M-L_sto+1);
xk_sto = xk .* exp(1j*2*pi*L_sto*k/M) .* STO_fr;
rk1 = xk_sto;
%% 解调
payload_dechirp=rk1.*xk0;
Yq_sto=real(fft(payload_dechirp))/M;
% Yq_sto=abs(fft(payload_dechirp))/M;
% figure;
subplot(2,1,1);stem(0:M-1,Yq_sto,"Marker","none","LineWidth",1.5);
xlabel('Frequency bin, q');ylabel('Re(X_q)/M')
xlim([0 M-1]);
title('相干解调');hold on
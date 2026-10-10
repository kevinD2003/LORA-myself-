SF=9;
M=2^SF;
a=M/2; %randi([0 M-1]);
B=250e3;
f_CFO = 1*B/4;
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(a/M-1/2+k/2/M+f_CFO/B));
SNR = -10;
xk = awgn(xk,SNR,'measured');
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
figure;
subplot(2,1,1);
plot(k,real(xk));
xlim([0 M-1]);
xlabel('k');ylabel('\Re[x_a(k)]');title('LoRa信号的实部')
% figure;
subplot(2,1,2);
plot(k,imag(xk));
xlim([0 M-1]);
xlabel('k');ylabel('\Im[x_a(k)]');title('LoRa信号的虚部')
y_ncoh=abs(fft(xk.*xk0)/M);
y_coh=real(fft(xk.*xk0)/M);



figure;
subplot(2,1,1);
stem(0:M-1,y_coh,'Marker','none','LineWidth',1.5);
ylabel('Re(X_q)/M');xlabel('Frequency bin, q');
xlim([0 M-1]);
title('相干解调');
subplot(2,1,2);
stem(0:M-1,y_ncoh,'Marker','none','LineWidth',1.5);
ylabel('|X_q|/M');xlabel('Frequency bin, q');
xlim([0 M-1]);
title('非相干解调');
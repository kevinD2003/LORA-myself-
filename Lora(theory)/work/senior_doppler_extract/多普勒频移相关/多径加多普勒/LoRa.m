SF=10;
M=2^SF;
a=randi([0 M-1]);
k=0:1:M-1;
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));%LoRa基信号的共轭
xk=exp(1j*2*pi*k.*(a/M-1/2+k/2/M));%直达径信号
rk=xk;
Yq=abs(fft(rk.*xk0)/M);%非相干解调
figure;plot(0:M-1,Yq);
xlabel('q');ylabel('|Yq|/M')
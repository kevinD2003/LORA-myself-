%% 画图；解调域信号示意图
B=125e3;
SF=7;
M=2^SF;
k=0:1:M-1;
aa=60;
fd=0.6*B/M;
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/M/2+fd/B));%带频偏的调制公式
xk0=exp(-1j*2*pi*k.*(-1/2+k/M/2));
y=abs(fft(xk.*xk0))/M;
% figure;
f4=stem(0:M-1,y,'Marker','none');hold on
xlim([0 M-1]);
SF=7;
M=2^SF;
a=M/2;
k=0:1:M-1;
epsilon=[0.3 0.3];
ui=[0 M/8];%时延,0表示直达径，8/M表示多径
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));%LoRa基信号的共轭
rkm=zeros(1,M);
xk=exp(1j*2*pi*k.*(a/M-1/2+k/2/M));%直达径信号
for i=2:length(ui)
    xkm=exp(1j*2*pi*k.*(a/M-1/2+k/2/M));
    xk_tem=[zeros(1,ui(i)) xkm(1:M-ui(i))];
    rkm=rkm+xk_tem;
end
rk=xk+rkm;
Yq=abs(fft(rk.*xk0)/M);
figure;
stem(0:M-1,Yq,'Marker','none','Linewidth',1.5);hold on;
ylim([0 1]);xlim([0 M-1])
Yq_2=fft(xk_tem.*xk0);


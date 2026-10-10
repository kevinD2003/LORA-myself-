%% 多径+多普勒的LoRa计算误码率；
B=250e3;
%% 两径信道
% hi=[sqrt(0.8) sqrt(0.2)];%
% % hi=[1 0.8];
hi=[sqrt(0.8) sqrt(0.2)];
epsilon2=[0.5 0.5];
epsilon1=[0 0];
ui=[0 1];
%% 
SF=7;
M=2^SF;
a=M/2;
k=0:1:M-1;
%% 多径
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));%LoRa基信号的共轭
xk1=hi(1)*exp(1j*2*pi*k.*(a/M-1/2+k/2/M+epsilon2(1)/M));
%% 多径
rkm1=zeros(1,M);
% for i=2:length(ui)
%     xkm=hi(i)*exp(1j*2*pi*k.*(a/M-1/2+k/2/M+epsilon1(i)/M));
%     xk_tem=[zeros(1,ui(i)) xkm(1:M-ui(i))];
%     rkm1=rkm1+xk_tem;
% end
rk1=xk1+rkm1;
Yq1=abs(fft(rk1.*xk0)/M);%非相干解调

figure;
subplot(2,1,1);stem(0:M-1,Yq1,'Marker','none','LineWidth',1.2);
xlabel('Frequency bin , q');ylabel('|Y_q|/M');
xlim([0 M-1]);ylim([0 1]);
hold on;

%% 多普勒（有扩散的情况）
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));%LoRa基信号的共轭
xk2=hi(1)*exp(1j*2*pi*k.*(a/M-1/2+k/2/M+epsilon2(1)/M));
%% 多径
rkm=zeros(1,M);
for i=2:length(ui)
    xkm=hi(i)*exp(1j*2*pi*k.*(a/M-1/2+k/2/M+epsilon2(i)/M));
    xk_tem=[zeros(1,ui(i)) xkm(1:M-ui(i))];
    rkm=rkm+xk_tem;
end
rk2=xk2+rkm;
Yq2=abs(fft(rk2.*xk0)/M);%非相干解调
subplot(2,1,2);stem(0:M-1,Yq2,'Marker','none','LineWidth',1.2);
xlabel('Frequency bin , q');ylabel('|Y_q|/M');
xlim([0 M-1]);ylim([0 1]);
hold on;
